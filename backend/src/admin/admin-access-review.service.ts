import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { ADMIN_PERMISSIONS, ADMIN_PRESETS } from '../common/admin-permissions';
import { SENSITIVE_ADMIN_ACTIONS } from '../auth/admin-step-up.policy';
import { adminAudit, maskedEmail } from './admin-audit';

@Injectable()
export class AdminAccessReviewService {
  constructor(private readonly prisma: PrismaService) {}

  catalog() {
    return { data: { permissions: ADMIN_PERMISSIONS, presets: ADMIN_PRESETS,
      sensitiveActions: SENSITIVE_ADMIN_ACTIONS.map(rule => ({ action: rule.action, method: rule.method, permissions: rule.permissions })) } };
  }

  async list(page: number, limit: number) {
    const where = { role: 'ADMIN' as const };
    const [total, users] = await this.prisma.$transaction([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({ where, select: { id: true, fullName: true, email: true, isActive: true,
        adminProfile: { select: { preset: true, permissions: true, mfaEnabled: true, reviewVersion: true, accessReviewedAt: true, accessReviewedBy: true, nextAccessReviewAt: true } },
        createdAt: true,
        authSessions: { orderBy: { lastSeenAt: 'desc' }, take: 1, select: { lastSeenAt: true } },
        adminTeamMemberships: { select: { role: true, team: { select: { id: true, name: true, isActive: true } } } },
      }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }], skip: (page - 1) * limit, take: limit }),
    ], { isolationLevel: 'RepeatableRead' });
    const now = Date.now();
    return { data: users.map(({ email, authSessions, ...user }) => {
      const nextReviewAt = user.adminProfile?.nextAccessReviewAt ?? null;
      return { ...user, email: maskedEmail(email), lastActiveAt: authSessions[0]?.lastSeenAt ?? null,
        reviewOverdue: !!nextReviewAt && nextReviewAt.getTime() <= now,
        reviewRequired: !user.adminProfile?.accessReviewedAt,
        inactiveWarning: user.isActive && now - (authSessions[0]?.lastSeenAt ?? user.createdAt).getTime() >= 90 * 86400000,
      };
    }), meta: { page, limit, total, inactiveWarningDays: 90 } };
  }

  async review(actor: AuthUser, id: string, input: { version: number; nextReviewAt: string; reason: string }) {
    if (id === actor.userId) throw new ForbiddenException('Không tự duyệt quyền của chính mình.');
    const now = new Date(), next = new Date(input.nextReviewAt);
    if (!Number.isFinite(next.getTime()) || next <= now || next.getTime() > now.getTime() + 366 * 86400000) throw new BadRequestException('Ngày rà soát tiếp theo phải trong vòng 366 ngày.');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "userId" FROM "AdminProfile" WHERE "userId" = ${id} FOR UPDATE`;
      const profile = await tx.adminProfile.findUnique({ where: { userId: id }, include: { user: { select: { role: true, isActive: true } } } });
      if (!profile || profile.user.role !== 'ADMIN') throw new NotFoundException();
      const changed = await tx.adminProfile.updateMany({ where: { userId: id, reviewVersion: input.version }, data: { accessReviewedAt: now, accessReviewedBy: actor.userId, nextAccessReviewAt: next, reviewVersion: { increment: 1 } } });
      if (!changed.count) throw new ConflictException('Hồ sơ quyền đã thay đổi. Tải lại trước khi duyệt.');
      await adminAudit(tx, actor, 'admin.access_review_completed', 'admin', id, input.reason, {
        before: { reviewedAt: profile.accessReviewedAt?.toISOString() ?? null, reviewedBy: profile.accessReviewedBy, nextReviewAt: profile.nextAccessReviewAt?.toISOString() ?? null, version: profile.reviewVersion },
        after: { reviewedAt: now.toISOString(), reviewedBy: actor.userId, nextReviewAt: next.toISOString(), version: input.version + 1 },
        preset: profile.preset, permissions: profile.permissions,
      });
      return { data: { reviewed: true, nextReviewAt: next, version: input.version + 1 } };
    });
  }
}
