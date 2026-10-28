import { Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { ADMIN_PRESETS } from '../common/admin-permissions';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { AdminWorkspaceQuery } from './admin-workspace.dto';
import { AdminWorkspaceService } from './admin-workspace.service';

describe('AdminWorkspaceService', () => {
  const actor = (permissions: string[]): AuthUser => ({ userId: 'admin-1', email: 'admin@example.com', role: AuthRole.ADMIN, permissions });
  const countModel = () => ({ count: jest.fn().mockResolvedValue(2) });
  const prisma = {
    operationsIncident: countModel(), supportTicket: countModel(),
    platformNotificationDelivery: countModel(), adminReportRun: countModel(),
    financeStatementLine: countModel(), platformNotification: countModel(),
    $queryRaw: jest.fn().mockResolvedValue([{ total: 3n }]),
  };
  const service = new AdminWorkspaceService(prisma as unknown as PrismaService);
  beforeEach(() => {
    jest.clearAllMocks();
    for (const model of Object.values(prisma)) {
      if ('count' in model) model.count.mockResolvedValue(2);
    }
  });

  it('never queries unauthorized sources', async () => {
    const { data } = await service.summary(actor(['admin.dashboard.view']));
    expect(data.items).toEqual([]);
    expect(data.pendingCount).toBe(0);
    expect(data.unreadNotificationCount).toBeNull();
    for (const model of Object.values(prisma)) {
      if ('count' in model) expect(model.count).not.toHaveBeenCalled();
    }
    expect(prisma.$queryRaw).not.toHaveBeenCalled();
  });

  it('sums only action buckets and scopes unread notifications to the actor', async () => {
    const { data } = await service.summary(actor([...ADMIN_PRESETS.super_admin]));
    expect(data.items).toHaveLength(8);
    expect(data.pendingCount).toBe(15);
    expect(data.unreadNotificationCount).toBe(2);
    expect(data.dataFreshness).toBe('LIVE');
    expect(Number.isNaN(Date.parse(data.lastUpdatedAt))).toBe(false);
    expect(prisma.platformNotification.count).toHaveBeenCalledWith({ where: { userId: 'admin-1', readAt: null } });
  });

  it('keeps successful sources when one source fails and never substitutes zero', async () => {
    const warn = jest.spyOn(Logger.prototype, 'warn').mockImplementation();
    prisma.operationsIncident.count.mockRejectedValueOnce(new Error('sensitive database diagnostics'));
    const { data } = await service.summary(actor([...ADMIN_PRESETS.super_admin]));
    expect(data.dataFreshness).toBe('PARTIAL');
    expect(data.items.find(item => item.key === 'incidents')).toMatchObject({ status: 'UNAVAILABLE', pendingCount: null, lastUpdatedAt: null });
    expect(data.items.find(item => item.key === 'finance')?.pendingCount).toBe(2);
    expect(JSON.stringify(data)).not.toContain('sensitive database diagnostics');
    expect(warn).toHaveBeenCalledWith('Workspace source unavailable: incidents');
    warn.mockRestore();
  });

  it('preserves report ownership, expiry and per-kind capabilities', async () => {
    await service.summary(actor(['admin.dashboard.view', 'admin.reports.manage', 'admin.support.read']));
    expect(prisma.adminReportRun.count).toHaveBeenCalledWith({ where: {
      status: 'FAILED', expiresAt: { gt: expect.any(Date) }, kind: { in: ['SUPPORT_SLA'] }, schedule: { ownerId: 'admin-1' },
    } });
  });

  it('excludes merged and closed tickets and separates due-soon from overdue', async () => {
    await service.summary(actor(['admin.dashboard.view', 'admin.support.read']));
    const [overdueQuery, soonQuery] = prisma.supportTicket.count.mock.calls.map(call => call[0].where);
    expect(overdueQuery.AND[0]).toMatchObject({ mergedIntoId: null, status: { notIn: ['RESOLVED', 'CLOSED'] } });
    expect(soonQuery.AND[1]).toEqual({ NOT: overdueQuery.AND[1] });
    expect(soonQuery.AND[2].OR[0].resolutionDueAt.lte.getTime() - soonQuery.AND[2].OR[0].resolutionDueAt.gte.getTime()).toBe(3600000);
  });

  it('queries moderation only for the actor permitted kinds', async () => {
    await service.summary(actor(['admin.dashboard.view', 'admin.reviews.moderate']));
    const parameters = prisma.$queryRaw.mock.calls[0].slice(1).flatMap((value: Prisma.Sql | Date) => 'values' in value ? value.values : [value]);
    expect(parameters).toEqual(expect.arrayContaining(['REVIEW', 'REPLY']));
    expect(parameters).not.toContain('LISTING');
    expect(parameters).not.toContain('REPORT');
  });

  it('paginates group buckets without including notification counts as tasks', async () => {
    const user = actor([...ADMIN_PRESETS.super_admin]);
    const first = await service.actionItems(user, Object.assign(new AdminWorkspaceQuery(), { limit: 1 }));
    expect(first.data.map(item => item.key)).toEqual(['incidents']);
    expect(first.meta.nextCursor).toBe('incidents');
    const second = await service.actionItems(user, Object.assign(new AdminWorkspaceQuery(), { limit: 10, cursor: first.meta.nextCursor }));
    expect(second.data).toHaveLength(6);
    expect(second.data.map(item => item.key)).not.toContain('notifications');
    expect(second.meta.nextCursor).toBeNull();
  });

  it('rejects a cursor outside the current permission scope', async () => {
    await expect(service.actionItems(actor(['admin.dashboard.view']), Object.assign(new AdminWorkspaceQuery(), { cursor: 'finance' }))).rejects.toThrow('Cursor');
  });
});
