import { ConflictException, ForbiddenException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AccountAccessService } from '../auth/account-access.service';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from './admin-audit';
import { AdminStatusDto } from './admin-console.dto';

@Injectable()
export class AdminLifecycleService {
  constructor(private readonly prisma: PrismaService, private readonly access: AccountAccessService) {}

  private async invitation(tx: Prisma.TransactionClient, id: string) {
    const latest = await tx.accountAccessToken.findFirst({ where: { userId: id, purpose: 'INVITE' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], select: { createdAt: true, expiresAt: true, consumedAt: true } });
    const activated = await tx.auditLog.findFirst({ where: { resourceType: 'user', resourceId: id, action: 'auth.access_token_redeemed' },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], select: { createdAt: true } });
    return { status: activated ? 'ACTIVATED' : !latest ? 'NOT_INVITED' : latest.consumedAt ? 'INVALIDATED' : latest.expiresAt <= new Date() ? 'EXPIRED' : 'PENDING',
      issuedAt: latest?.createdAt ?? null, expiresAt: latest?.expiresAt ?? null, activatedAt: activated?.createdAt ?? null };
  }

  async detail(id: string) {
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findFirst({ where: { id, role: 'ADMIN' }, select: { id: true, isActive: true, sessionVersion: true } });
      if (!user) throw new NotFoundException();
      const now = new Date();
      const sessionWhere = { userId: id, userVersion: user.sessionVersion, revokedAt: null, expiresAt: { gt: now } };
      const [invitation, activeSessions, lastSession, history] = await Promise.all([
        this.invitation(tx, id), user.isActive ? tx.authSession.count({ where: sessionWhere }) : Promise.resolve(0),
        tx.authSession.findFirst({ where: { userId: id }, orderBy: [{ lastSeenAt: 'desc' }, { id: 'desc' }], select: { lastSeenAt: true } }),
        tx.auditLog.findMany({ where: { resourceId: id, action: { in: ['admin.account_invite', 'admin.admin_invite_resent', 'admin.profile_update', 'admin.admin_sessions_revoked', 'admin.access_review_completed', 'auth.access_token_redeemed'] } },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 30, select: { id: true, actorId: true, action: true, summary: true, createdAt: true } }),
      ]);
      return { data: { id, isActive: user.isActive, version: user.sessionVersion, invitation, activeSessions, lastActiveAt: lastSession?.lastSeenAt ?? null, history, generatedAt: now } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  private async target(tx: Prisma.TransactionClient, actor: AuthUser, id: string, version: number) {
    if (actor.userId === id) throw new ForbiddenException('Use your own security settings to manage your sessions.');
    await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id} FOR UPDATE`;
    const user = await tx.user.findFirst({ where: { id, role: 'ADMIN' }, select: { id: true, isActive: true, sessionVersion: true } });
    if (!user) throw new NotFoundException();
    if (user.sessionVersion !== version) throw new ConflictException('Admin changed. Reload before continuing.');
    return user;
  }

  async resend(actor: AuthUser, id: string, input: AdminStatusDto) {
    if (!this.access.ready()) throw new ServiceUnavailableException('Account invitation delivery is not configured.');
    return this.prisma.$transaction(async tx => {
      const user = await this.target(tx, actor, id, input.version);
      const before = await this.invitation(tx, id);
      if (!user.isActive || !['PENDING', 'EXPIRED', 'INVALIDATED'].includes(before.status)) throw new ConflictException('Only an active, unactivated invitation can be resent.');
      if (before.issuedAt && Date.now() - before.issuedAt.getTime() < 60000) throw new ConflictException('Wait at least 60 seconds before resending this invitation.');
      await this.access.enqueue(tx, id, 'INVITE');
      await tx.user.update({ where: { id }, data: { sessionVersion: { increment: 1 } } });
      const after = await this.invitation(tx, id);
      await adminAudit(tx, actor, 'admin.admin_invite_resent', 'user', id, input.reason, {
        before: { status: before.status, version: user.sessionVersion, expiresAt: before.expiresAt?.toISOString() ?? null },
        after: { status: after.status, version: user.sessionVersion + 1, expiresAt: after.expiresAt?.toISOString() ?? null },
      });
      return { data: { queued: true, version: user.sessionVersion + 1, invitation: after } };
    });
  }

  async revoke(actor: AuthUser, id: string, input: AdminStatusDto) {
    return this.prisma.$transaction(async tx => {
      const user = await this.target(tx, actor, id, input.version);
      const now = new Date();
      const sessions = await tx.authSession.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: now } });
      await tx.refreshToken.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: now } });
      await tx.user.update({ where: { id }, data: { sessionVersion: { increment: 1 } } });
      await adminAudit(tx, actor, 'admin.admin_sessions_revoked', 'user', id, input.reason, {
        before: { version: user.sessionVersion }, after: { version: user.sessionVersion + 1, activeSessions: 0 }, revokedSessions: sessions.count,
      });
      return { data: { revoked: true, version: user.sessionVersion + 1 } };
    });
  }
}
