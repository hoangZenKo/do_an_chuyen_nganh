import { ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { ListingsService } from '../listings/listings.service';
import { ReviewsService } from '../reviews/reviews.service';
import { FeatureFlagsService } from './feature-flags.service';
import { ModerationV2Service } from './moderation-v2.service';
import { ModerationBulkDto } from './moderation-v2.dto';

describe('Read-only bulk moderation preview', () => {
  const actor: AuthUser = { userId: 'admin', email: 'admin@example.test', role: AuthRole.ADMIN,
    permissions: ['admin.moderation.bulk', 'admin.listings.moderate', 'admin.reviews.moderate'] };
  const readModel = () => ({ findUnique: jest.fn(), findFirst: jest.fn() });
  const tx = { moderationWorkItem: readModel(), roomListing: readModel(), listingReport: readModel(), roomReview: readModel() };
  const prisma = { $transaction: jest.fn(async (run: (client: typeof tx) => unknown) => run(tx)) };
  const flags = { require: jest.fn() };
  const listings = { review: jest.fn(), reviewReport: jest.fn() };
  const reviews = { moderate: jest.fn() };
  const service = new ModerationV2Service(prisma as unknown as PrismaService, flags as unknown as FeatureFlagsService,
    listings as unknown as ListingsService, reviews as unknown as ReviewsService);
  const batch = (changes: Partial<ModerationBulkDto['items'][number]> = {}): ModerationBulkDto => ({
    reason: 'Review policy violation before execution', items: [{ kind: 'LISTING', id: 'listing-1', version: 1, decision: 'PUBLISH', ...changes }],
  });
  beforeEach(() => {
    jest.clearAllMocks();
    flags.require.mockResolvedValue(undefined);
    tx.moderationWorkItem.findUnique.mockResolvedValue(null);
    tx.roomListing.findUnique.mockResolvedValue({ id: 'listing-1', status: 'PENDING', version: 1 });
    tx.roomListing.findFirst.mockResolvedValue({ id: 'listing-1' });
    tx.roomReview.findUnique.mockResolvedValue({ id: 'review-1', status: 'PENDING', version: 1, withdrawnAt: null });
  });
  afterEach(() => {
    expect(listings.review).not.toHaveBeenCalled();
    expect(listings.reviewReport).not.toHaveBeenCalled();
    expect(reviews.moderate).not.toHaveBeenCalled();
  });
  it('returns ready items without invoking mutation services', async () => {
    const result = await service.preview(actor, batch());
    expect(result.summary).toEqual({ total: 1, ready: 1, blocked: 0 });
    expect(result.data[0]).toMatchObject({ ready: true, currentStatus: 'PENDING', currentVersion: 1 });
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
  });
  it('checks the feature flag before opening any transaction', async () => {
    flags.require.mockRejectedValueOnce(new ForbiddenException());
    await expect(service.preview(actor, batch())).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('never reads targets or assignment without kind permission', async () => {
    const result = await service.preview({ ...actor, permissions: ['admin.moderation.bulk'] }, batch());
    expect(result.summary.blocked).toBe(1);
    expect(tx.roomListing.findUnique).not.toHaveBeenCalled();
    expect(tx.moderationWorkItem.findUnique).not.toHaveBeenCalled();
  });
  it('rejects duplicate targets before querying', async () => {
    const input = batch();
    input.items.push(input.items[0]);
    await expect(service.preview(actor, input)).rejects.toThrow('batch');
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
  it('blocks a stale version and does not run availability queries', async () => {
    const result = await service.preview(actor, batch({ version: 2 }));
    expect(result.data[0]).toMatchObject({ ready: false, currentVersion: 1 });
    expect(tx.roomListing.findFirst).not.toHaveBeenCalled();
  });
  it('blocks publishing an unavailable room and rechecks all availability predicates', async () => {
    tx.roomListing.findFirst.mockResolvedValueOnce(null);
    expect((await service.preview(actor, batch())).summary.blocked).toBe(1);
    expect(tx.roomListing.findFirst).toHaveBeenCalledWith({ where: { id: 'listing-1', room: {
      isActive: true, status: 'VACANT', property: { isArchived: false, landlord: { isActive: true } },
    } }, select: { id: true } });
  });
  it('does not disclose a target assigned to another moderator', async () => {
    tx.moderationWorkItem.findUnique.mockResolvedValueOnce({ assigneeId: 'other-admin' });
    expect((await service.preview(actor, batch())).summary.blocked).toBe(1);
    expect(tx.roomListing.findUnique).not.toHaveBeenCalled();
  });
  it('rejects withdrawn reviews and replies without approved parent content', async () => {
    tx.roomReview.findUnique.mockResolvedValueOnce({ id: 'review-1', status: 'PENDING', version: 1, withdrawnAt: new Date() });
    expect((await service.preview(actor, batch({ kind: 'REVIEW', decision: 'APPROVED' }))).summary.blocked).toBe(1);
    tx.roomReview.findUnique.mockResolvedValueOnce({ id: 'review-1', status: 'HIDDEN', replyStatus: 'PENDING', replyBody: 'Reply', version: 1 });
    expect((await service.preview(actor, batch({ kind: 'REPLY', decision: 'APPROVED' }))).summary.blocked).toBe(1);
  });
  it('propagates database failures rather than presenting partial readiness', async () => {
    tx.roomListing.findUnique.mockRejectedValueOnce(new Error('database unavailable'));
    await expect(service.preview(actor, batch())).rejects.toThrow('database unavailable');
  });
});
