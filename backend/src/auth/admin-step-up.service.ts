import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'node:crypto';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from '../admin/admin-audit';
import { AdminMfaService } from './admin-mfa.service';
import { adminRequestFingerprint, sensitiveAdminAction } from './admin-step-up.policy';

@Injectable()
export class AdminStepUpService {
  constructor(private readonly prisma: PrismaService, private readonly mfa: AdminMfaService, private readonly config: ConfigService) {}

  required(method: string, path: string) {
    return (this.config.get('NODE_ENV') === 'production' || this.config.get('ADMIN_STEP_UP_REQUIRED') === 'true') && !!sensitiveAdminAction(method, path);
  }

  async issue(actor: AuthUser, input: { method: string; path: string; payload: Record<string, unknown>; code: string; reason: string }) {
    const rule = sensitiveAdminAction(input.method, input.path);
    if (!rule || JSON.stringify(input.payload).length > 65536) throw new BadRequestException('Unsupported or oversized step-up request.');
    if (actor.role !== AuthRole.ADMIN || !actor.sessionId || !rule.permissions.every(permission => actor.permissions?.includes(permission))) throw new ForbiddenException();
    await this.mfa.verify(actor.userId, input.code);
    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + 5 * 60000);
    await this.prisma.$transaction(async tx => {
      const session = await tx.authSession.findFirst({ where: { id: actor.sessionId, userId: actor.userId, revokedAt: null, expiresAt: { gt: new Date() }, user: { isActive: true, role: 'ADMIN', adminProfile: { permissions: { hasEvery: rule.permissions } } } }, include: { user: { select: { sessionVersion: true } } } });
      if (!session || session.userVersion !== session.user.sessionVersion) throw new ForbiddenException();
      await tx.adminStepUpGrant.deleteMany({ where: { expiresAt: { lt: new Date() } } });
      const grant = await tx.adminStepUpGrant.create({ data: { tokenHash: createHash('sha256').update(token).digest('hex'), sessionId: actor.sessionId!, userId: actor.userId, action: rule.action, fingerprint: adminRequestFingerprint(input.method, input.path, input.payload), expiresAt } });
      await adminAudit(tx, actor, 'admin.step_up_issued', 'admin_step_up', grant.id, input.reason, { action: rule.action, expiresAt: expiresAt.toISOString() });
    });
    return { data: { token, expiresAt, action: rule.action, singleUse: true } };
  }

  async consume(actor: AuthUser, method: string, path: string, payload: unknown, token?: string) {
    const rule = sensitiveAdminAction(method, path);
    const fail = () => new ForbiddenException({ error: { code: 'ADMIN_STEP_UP_REQUIRED', message: 'Xác thực MFA mới để thực hiện thao tác này.' } });
    if (!rule || !token || !/^[A-Za-z0-9_-]{43}$/.test(token) || !actor.sessionId) throw fail();
    const now = new Date();
    const changed = await this.prisma.adminStepUpGrant.updateMany({ where: {
      tokenHash: createHash('sha256').update(token).digest('hex'), userId: actor.userId, sessionId: actor.sessionId,
      action: rule.action, fingerprint: adminRequestFingerprint(method, path, payload), consumedAt: null, expiresAt: { gt: now },
      session: { revokedAt: null, expiresAt: { gt: now }, user: { isActive: true, role: 'ADMIN', adminProfile: { permissions: { hasEvery: rule.permissions } } } },
    }, data: { consumedAt: now } });
    if (!changed.count) throw fail();
    return true;
  }
}
