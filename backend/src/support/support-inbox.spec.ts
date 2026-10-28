import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { FeatureFlagsService } from '../platform/feature-flags.service';
import { PlatformNotificationService } from './platform-notification.service';
import { SupportWorkflowService } from './support-workflow.service';
import { SupportSlaService } from './support-sla.service';
import { SupportService } from './support.service';
import { SupportPageDto } from './support.dto';
import { supportSlaWhere } from './support-inbox';

describe('Support inbox filtering', () => {
  const now = new Date('2026-10-26T00:00:00Z');
  const actor: AuthUser = { userId: 'support-admin', email: 'support@example.test', role: AuthRole.ADMIN, permissions: ['admin.support.read'] };
  const prisma = { supportTicket: { count: jest.fn().mockResolvedValue(0), findMany: jest.fn().mockResolvedValue([]) },
    $transaction: jest.fn((queries: Promise<unknown>[]) => Promise.all(queries)) };
  const service = new SupportService(prisma as unknown as PrismaService, {} as PlatformNotificationService, {} as FeatureFlagsService,
    {} as SupportWorkflowService, {} as SupportSlaService);
  beforeEach(() => { jest.clearAllMocks(); jest.useFakeTimers().setSystemTime(now); });
  afterEach(() => jest.useRealTimers());
  it('pauses resolution but still tracks a missing first response', () => {
    expect(supportSlaWhere('overdue', now)).toEqual({ AND: [
      { status: { notIn: ['RESOLVED', 'CLOSED'] }, mergedIntoId: null },
      { OR: [{ slaPausedAt: null, resolutionDueAt: { lt: now } }, { firstRespondedAt: null, firstResponseDueAt: { lt: now } }] },
    ] });
  });
  it('uses a disjoint one-hour due-soon window', () => {
    const where = supportSlaWhere('due_soon', now);
    expect(where.AND).toEqual([
      expect.objectContaining({ mergedIntoId: null }),
      { NOT: (supportSlaWhere('overdue', now).AND as Prisma.SupportTicketWhereInput[])[1] },
      { OR: [{ slaPausedAt: null, resolutionDueAt: { gte: now, lte: new Date(now.getTime() + 3600000) } },
        { firstRespondedAt: null, firstResponseDueAt: { gte: now, lte: new Date(now.getTime() + 3600000) } }] },
    ]);
  });
  it('intersects explicit status, ownership, priority and SLA filters', async () => {
    await service.list(actor, Object.assign(new SupportPageDto(), { status: 'CLOSED', assignment: 'mine', priority: 'HIGH', sla: 'overdue', sort: 'oldest' }));
    expect(prisma.supportTicket.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ status: 'CLOSED', assigneeId: actor.userId, AND: expect.arrayContaining([
        { mergedIntoId: null }, { priority: 'HIGH' }, supportSlaWhere('overdue', now),
      ]) }), orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    }));
    expect(prisma.supportTicket.count.mock.calls[0][0].where).toEqual(prisma.supportTicket.findMany.mock.calls[0][0].where);
  });
  it('scopes requester searches and does not search internal messages', async () => {
    const requester = { ...actor, role: AuthRole.LANDLORD, permissions: [] };
    await service.list(requester, Object.assign(new SupportPageDto(), { search: 'private note', teamId: 'ignored', assigneeId: 'ignored', label: 'ignored' }));
    const where = prisma.supportTicket.findMany.mock.calls[0][0].where;
    expect(where.requesterId).toBe(actor.userId);
    expect(where.AND).toEqual(expect.arrayContaining([{ OR: [
      { subject: { contains: 'private note', mode: 'insensitive' } },
      { messages: { some: { body: { contains: 'private note', mode: 'insensitive' }, internal: false } } },
    ] }]));
    expect(JSON.stringify(where)).not.toContain('ignored');
  });
});
