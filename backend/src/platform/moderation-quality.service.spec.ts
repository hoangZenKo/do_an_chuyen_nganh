import { ConflictException, ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { ModerationQualityReviewDto, ModerationSampleQuery, qualityWindow } from './moderation-quality.dto';
import { ModerationQualityService } from './moderation-quality.service';

describe('ModerationQualityService', () => {
  const actor: AuthUser = { userId: 'reviewer-1', email: 'reviewer@example.test', role: AuthRole.ADMIN, permissions: ['admin.moderation.reports', 'admin.listings.moderate'] };
  it('samples deterministically within an explicit bounded window and excludes the actor own decisions', async () => {
    const prisma = { $queryRaw: jest.fn().mockResolvedValue([{ id: 'decision-1', kind: 'LISTING', actorId: 'moderator-2', createdAt: new Date(), outcome: null }]) };
    const service = new ModerationQualityService(prisma as never);
    const query = Object.assign(new ModerationSampleQuery(), { from: '2026-10-01T00:00:00+07:00', to: '2026-10-20T00:00:00+07:00', timezone: 'Asia/Ho_Chi_Minh', state: 'PENDING', page: 1, limit: 10 });
    const response = await service.samples(actor, query);
    expect(prisma.$queryRaw).toHaveBeenCalled();
    expect(response.meta).toMatchObject({ timezone: 'Asia/Ho_Chi_Minh', sampling: 'deterministic-hash-order', independentReviewer: true });
    expect(response.data).toHaveLength(1);
  });
  it('rejects invalid/future windows and self-review', async () => {
    expect(() => qualityWindow(Object.assign(new ModerationSampleQuery(), { from: '2026-10-01', to: '2026-10-02' }), new Date('2026-10-03T00:00:00Z'))).toThrow('INVALID_WINDOW');
    const tx = { moderationDecision: { findUnique: jest.fn().mockResolvedValue({ id: 'd-1', kind: 'LISTING', actorId: actor.userId, version: 1, qualityReview: null }) }, $queryRaw: jest.fn() };
    const prisma = { $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)) };
    await expect(new ModerationQualityService(prisma as never).review(actor, 'd-1', Object.assign(new ModerationQualityReviewDto(), { version: 1, outcome: 'AGREE', reason: 'Independent review' }))).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('uses version conflict and atomic audit for one QA review', async () => {
    const tx = {
      moderationDecision: { findUnique: jest.fn().mockResolvedValue({ id: 'd-1', kind: 'LISTING', actorId: 'moderator-2', version: 2, qualityReview: null }) },
      moderationQualityReview: { create: jest.fn().mockResolvedValue({ id: 'qa-1', outcome: 'DISAGREE' }) },
      auditLog: { create: jest.fn().mockResolvedValue({ id: 'audit-1' }) },
      $queryRaw: jest.fn(),
    };
    const prisma = { $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)) };
    const service = new ModerationQualityService(prisma as never);
    const input = Object.assign(new ModerationQualityReviewDto(), { version: 2, outcome: 'DISAGREE', reason: 'Evidence differs' });
    await expect(service.review(actor, 'd-1', input)).resolves.toMatchObject({ meta: { enforcementUnchanged: true } });
    tx.moderationDecision.findUnique.mockResolvedValueOnce({ id: 'd-1', kind: 'LISTING', actorId: 'moderator-2', version: 3, qualityReview: null });
    await expect(service.review(actor, 'd-1', input)).rejects.toBeInstanceOf(ConflictException);
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: 'admin.moderation_quality_reviewed' }) });
  });
});
