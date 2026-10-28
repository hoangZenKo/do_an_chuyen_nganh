import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { ModerationPolicyService } from './moderation-policy.service';
import { ModerationQualityQuery, qualityWindow } from './moderation-quality.dto';

describe('Moderation quality read model', () => {
  const actor: AuthUser = { userId: 'analyst', email: 'analyst@example.test', role: AuthRole.ADMIN, permissions: ['admin.moderation.reports'] };
  const query = Object.assign(new ModerationQualityQuery(), { from: '2026-10-01T00:00:00+07:00', to: '2026-10-20T00:00:00+07:00', timezone: 'Asia/Ho_Chi_Minh' });
  function setup() {
    const tx = {
      moderationDecision: { groupBy: jest.fn().mockResolvedValue([{ actorId: 'moderator', kind: 'LISTING', _count: 8 }]) },
      moderationAppeal: { groupBy: jest.fn().mockResolvedValue([{ status: 'UPHELD', _count: 3 }, { status: 'REOPENED', _count: 1 }, { status: 'SUPERSEDED', _count: 20 }]) },
      moderationQualityReview: { groupBy: jest.fn().mockResolvedValue([{ outcome: 'AGREE', _count: 1 }, { outcome: 'DISAGREE', _count: 1 }, { outcome: 'NEEDS_DISCUSSION', _count: 2 }]) },
      supportTicket: { aggregate: jest.fn().mockResolvedValue({ _count: { feedbackRating: 2 }, _avg: { feedbackRating: 4 } }) },
    };
    const prisma = { $transaction: jest.fn(async (callback: (client: typeof tx) => unknown) => callback(tx)) };
    return { tx, prisma, service: new ModerationPolicyService(prisma as never) };
  }

  it('uses event-time bounds for each metric, and does not mislabel reopen as an overturn', async () => {
    const { service, tx } = setup();
    const { data } = await service.quality(actor, query);
    expect(data).toMatchObject({ from: '2026-09-30T17:00:00.000Z', to: '2026-10-19T17:00:00.000Z', timezone: 'Asia/Ho_Chi_Minh', appealReopenRate: 0.25, appealOverturnRate: null, qa: { disagreementRate: 0.25 } });
    const range = { gte: new Date(query.from!), lt: new Date(query.to!) };
    expect(tx.moderationDecision.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: { createdAt: range } }));
    expect(tx.moderationAppeal.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: { resolvedAt: range } }));
    expect(tx.moderationQualityReview.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: { createdAt: range } }));
    expect(tx.supportTicket.aggregate).not.toHaveBeenCalled();
    expect(data.supportFeedback).toBeNull();
  });

  it('only includes CSAT with support read permission', async () => {
    const { service, tx } = setup();
    const result = await service.quality({ ...actor, permissions: [...actor.permissions!, 'admin.support.read'] }, query);
    expect(result.data.supportFeedback).toEqual({ responses: 2, average: 4 });
    expect(tx.supportTicket.aggregate).toHaveBeenCalledWith(expect.objectContaining({ where: { feedbackAt: { gte: new Date(query.from!), lt: new Date(query.to!) } } }));
  });

  it('rejects unsupported windows/timezones and does not query for revoked permissions', async () => {
    const { service, prisma } = setup();
    await expect(service.quality({ ...actor, permissions: [] }, query)).rejects.toThrow(ForbiddenException);
    await expect(service.quality(actor, { ...query, timezone: 'invalid-zone' })).rejects.toThrow(BadRequestException);
    await expect(service.quality(actor, { ...query, from: '2025-01-01T00:00:00Z' })).rejects.toThrow(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('renders the same explicit instant using the requested timezone, including DST', () => {
    const reference = new Date('2026-11-02T12:00:00Z');
    const range = { from: '2026-11-01T05:30:00Z', to: '2026-11-01T06:30:00Z' };
    const utc = qualityWindow({ ...range, timezone: 'UTC' }, reference);
    const local = qualityWindow({ ...range, timezone: 'America/New_York' }, reference);
    expect(local.from).toEqual(utc.from);
    expect(local.displayFrom).not.toEqual(utc.displayFrom);
    expect(local.displayFrom).not.toEqual(local.displayTo);
  });
});
