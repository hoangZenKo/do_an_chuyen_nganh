import 'reflect-metadata';
import { ForbiddenException } from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AuthRole } from '../common/auth-role';
import { AdminOverviewAnalyticsService, AdminOverviewQuery, overviewGrowth, overviewPeriod } from './admin-overview-analytics.service';

describe('admin overview analytics', () => {
  const actor = { userId: 'admin', email: 'admin@example.test', role: AuthRole.ADMIN, permissions: ['admin.dashboard.view', 'admin.properties.view', 'admin.finance.read'] };
  const setup = () => {
    const tx = {
      user: { groupBy: jest.fn().mockResolvedValue([
        { role: 'ADMIN', isActive: true, _count: 2 },
        { role: 'LANDLORD', isActive: true, _count: 3 },
        { role: 'TENANT', isActive: false, _count: 4 },
        { role: 'STAFF', isActive: true, _count: 1 },
      ]), count: jest.fn().mockResolvedValueOnce(6).mockResolvedValueOnce(3) },
      property: { groupBy: jest.fn().mockResolvedValue([{ isArchived: false, _count: 3 }, { isArchived: true, _count: 1 }]), count: jest.fn().mockResolvedValue(1) },
      room: { groupBy: jest.fn().mockResolvedValue([{ status: 'OCCUPIED', _count: 6 }, { status: 'VACANT', _count: 3 }, { status: 'MAINTENANCE', _count: 1 }]), count: jest.fn().mockResolvedValueOnce(2).mockResolvedValueOnce(2).mockResolvedValueOnce(14) },
      payment: { aggregate: jest.fn().mockResolvedValueOnce({ _sum: { amount: 1000 } }).mockResolvedValueOnce({ _sum: { amount: -1200 } }).mockResolvedValueOnce({ _sum: { amount: 100 } }).mockResolvedValueOnce({ _sum: { amount: 0 } }) },
      expense: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount: 40 } }) },
      invoice: { aggregate: jest.fn().mockResolvedValue({ _sum: { totalAmount: 1000, paidAmount: 400 } }) },
      paymentLink: { count: jest.fn().mockResolvedValue(2) },
      $queryRaw: jest.fn().mockResolvedValue([{ day: '2026-10-27', accounts: 0n, properties: 0n, rooms: 0n, listings: 0n, rentalCollected: 1000n, rentalReversed: 1200n }]),
    };
    const prisma = { $transaction: jest.fn(async callback => callback(tx)) };
    return { tx, prisma, service: new AdminOverviewAnalyticsService(prisma as any) };
  };

  it.each([7, 30, 90, 180])('validates and defaults the %s-day calendar range', async days => {
    expect(await validate(plainToInstance(AdminOverviewQuery, { days: String(days) }))).toHaveLength(0);
    const period = overviewPeriod(days, new Date('2026-10-27T18:30:00Z'));
    expect(period.from.getUTCHours()).toBe(17);
    expect(period.previousTo).toEqual(period.from);
    expect(period.from.getTime() - period.previousFrom.getTime()).toBe(days * 86400000);
    expect(period.to.toISOString()).toBe('2026-10-27T18:30:00.000Z');
  });

  it('rejects unsupported ranges and correctly crosses midnight in Vietnam', async () => {
    expect(plainToInstance(AdminOverviewQuery, {}).days).toBe(30);
    for (const days of [0, -1, 8, 365, 7.5, 'invalid']) {
      expect((await validate(plainToInstance(AdminOverviewQuery, { days }))).length).toBeGreaterThan(0);
    }
    expect(overviewPeriod(7, new Date('2026-10-27T17:00:00Z')).from.toISOString()).toBe('2026-10-21T17:00:00.000Z');
    expect(overviewPeriod(7, new Date('2026-10-27T16:59:59Z')).from.toISOString()).toBe('2026-10-20T17:00:00.000Z');
  });

  it('does not invent growth from a zero baseline and handles negative net cash', () => {
    expect(overviewGrowth(3, 0).changePercent).toBeNull();
    expect(overviewGrowth(0, 0).changePercent).toBeNull();
    expect(overviewGrowth(30, 20).changePercent).toBe(50);
    expect(overviewGrowth(-50, -100).changePercent).toBe(50);
  });

  it('aggregates all roles, room statuses and true rental reversals in one snapshot', async () => {
    const { service, tx, prisma } = setup();
    const { data } = await service.overview(actor, { days: 30 });
    expect(data.accounts).toEqual({ total: 10, active: 6, inactive: 4, landlords: 3, tenants: 4, staff: 1, admins: 2 });
    expect(data.rooms).toEqual({ total: 14, active: 10, occupied: 6, vacant: 3, maintenance: 1, occupancyRate: .6 });
    expect(data.properties).toEqual({ total: 4, active: 3, archived: 1 });
    expect(data.growth.accounts.changePercent).toBe(100);
    expect(data.finance).toMatchObject({ rentalCollected: 1000, rentalReversed: 1200, rentalNet: -200, outstandingSnapshot: 600, platformRevenue: { available: false, amount: null } });
    expect(data.trends[0]).toMatchObject({ accounts: 0, rentalNet: -200 });
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
    expect(tx.room.groupBy).toHaveBeenCalledWith(expect.objectContaining({ where: { isActive: true, property: { isArchived: false } } }));
    for (const [call] of tx.payment.aggregate.mock.calls) expect(call.where.invoice).toEqual({ isDemo: false });
    expect(tx.paymentLink.count).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ invoice: { isDemo: false } }) }));
    const sql = tx.$queryRaw.mock.calls[0][0].sql;
    expect(sql).toContain('generate_series');
    expect(sql).toContain("AT TIME ZONE 'Asia/Ho_Chi_Minh'");
    expect(sql).toContain('i."isDemo" = false');
  });

  it('omits sensitive fields and never queries finance without capability', async () => {
    const { service, tx } = setup();
    const { data } = await service.overview({ ...actor, permissions: ['admin.dashboard.view'] }, { days: 7 });
    expect(data).not.toHaveProperty('finance');
    expect(data.rooms).toEqual({ total: 14, active: 10 });
    expect(data.trends[0]).not.toHaveProperty('rentalNet');
    expect(data.trends[0]).not.toHaveProperty('rentalCollected');
    expect(tx.payment.aggregate).not.toHaveBeenCalled();
    expect(tx.invoice.aggregate).not.toHaveBeenCalled();
    expect(tx.expense.aggregate).not.toHaveBeenCalled();
    expect(tx.paymentLink.count).not.toHaveBeenCalled();
    expect(tx.$queryRaw.mock.calls[0][0].sql).not.toContain('"Payment"');
  });

  it('returns an unavailable occupancy ratio for an empty inventory', async () => {
    const { service, tx } = setup();
    tx.room.groupBy.mockResolvedValue([]);
    expect((await service.overview(actor, { days: 7 })).data.rooms.occupancyRate).toBeNull();
  });

  it('rejects missing dashboard rights or a non-admin before reading the database', async () => {
    const { service, prisma } = setup();
    await expect(service.overview({ ...actor, role: AuthRole.LANDLORD }, { days: 30 })).rejects.toThrow(ForbiddenException);
    await expect(service.overview({ ...actor, permissions: [] }, { days: 30 })).rejects.toThrow(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});
