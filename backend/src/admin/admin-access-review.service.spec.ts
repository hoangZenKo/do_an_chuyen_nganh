import { ConflictException, ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AdminAccessReviewService } from './admin-access-review.service';

describe('Access review lifecycle signals', () => {
  it('uses historical activity, not just unrevoked sessions; masks PII and flags overdue/unreviewed/inactive admins', async () => {
    const lastActiveAt = new Date(Date.now() - 100 * 86400000);
    const user = { id: 'target', email: 'private@example.test', isActive: true, createdAt: lastActiveAt,
      adminProfile: { nextAccessReviewAt: new Date(0), accessReviewedAt: lastActiveAt }, authSessions: [{ lastSeenAt: lastActiveAt }] };
    const prisma = { user: { count: jest.fn().mockResolvedValue(1), findMany: jest.fn().mockResolvedValue([user]) },
      $transaction: (queries: Promise<unknown>[]) => Promise.all(queries) };
    const service = new AdminAccessReviewService(prisma as never);
    expect((await service.list(1, 20)).data[0]).toMatchObject({ email: 'p***@example.test', lastActiveAt, reviewOverdue: true, reviewRequired: false, inactiveWarning: true });
    const query = prisma.user.findMany.mock.calls[0][0];
    expect(query.select.authSessions).toMatchObject({ take: 1, select: { lastSeenAt: true } });
    expect(query.select.authSessions).not.toHaveProperty('where');
    expect(query.take).toBe(20);
    user.isActive = false;
    expect((await service.list(1, 20)).data[0].inactiveWarning).toBe(false);
  });

  it('blocks self approval and stale reviewVersion, and audits before/after in the mutation transaction', async () => {
    const actor = { userId: 'reviewer', email: 'masked@example.test', role: AuthRole.ADMIN };
    const profile = { user: { role: 'ADMIN', isActive: true }, preset: 'support', permissions: ['admin.dashboard.view'], reviewVersion: 3, accessReviewedAt: null, accessReviewedBy: null, nextAccessReviewAt: null };
    const tx = { $queryRaw: jest.fn(), adminProfile: { findUnique: jest.fn().mockResolvedValue(profile), updateMany: jest.fn().mockResolvedValue({ count: 1 }) }, auditLog: { create: jest.fn() } };
    const prisma = { $transaction: jest.fn((work: (client: typeof tx) => unknown) => work(tx)) };
    const service = new AdminAccessReviewService(prisma as never);
    const input = { version: 3, reason: 'Independent quarterly access review', nextReviewAt: new Date(Date.now() + 86400000).toISOString() };
    await expect(service.review(actor, actor.userId, input)).rejects.toThrow(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
    await service.review(actor, 'target', input);
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ metadata: expect.objectContaining({ before: expect.objectContaining({ version: 3 }), after: expect.objectContaining({ version: 4, reviewedBy: 'reviewer' }) }) }) });
    tx.adminProfile.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.review(actor, 'target', input)).rejects.toThrow(ConflictException);
    expect(tx.auditLog.create).toHaveBeenCalledTimes(1);
  });
});
