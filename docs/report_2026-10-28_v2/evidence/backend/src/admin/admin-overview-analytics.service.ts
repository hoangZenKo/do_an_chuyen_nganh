import { ForbiddenException, Injectable } from '@nestjs/common';
import { Type } from 'class-transformer';
import { IsIn } from 'class-validator';
import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';

export class AdminOverviewQuery {
  @Type(() => Number) @IsIn([7, 30, 90, 180]) days = 30;
}

const DAY = 86400000;
const VN_OFFSET = 7 * 3600000;

export function overviewPeriod(days: number, now = new Date()) {
  const local = new Date(now.getTime() + VN_OFFSET);
  const today = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - VN_OFFSET;
  const from = new Date(today - (days - 1) * DAY);
  return { from, to: now, previousFrom: new Date(from.getTime() - days * DAY), previousTo: from };
}

export function overviewGrowth(current: number, previous: number) {
  return { current, previous, changePercent: previous !== 0 ? (current - previous) / Math.abs(previous) * 100 : null };
}

type TrendRow = { day: string; accounts: bigint; properties: bigint; rooms: bigint; listings: bigint; rentalCollected?: bigint; rentalReversed?: bigint };

@Injectable()
export class AdminOverviewAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(actor: AuthUser, query: AdminOverviewQuery) {
    if (actor.role !== AuthRole.ADMIN || !actor.permissions?.includes('admin.dashboard.view')) throw new ForbiddenException();
    const period = overviewPeriod(query.days);
    const current = { gte: period.from, lte: period.to };
    const previous = { gte: period.previousFrom, lt: period.previousTo };
    const canRooms = actor.permissions.includes('admin.properties.view');
    const canFinance = actor.permissions.includes('admin.finance.read');
    return this.prisma.$transaction(async tx => {
      const [accounts, properties, rooms, newAccounts, priorAccounts, newProperties, priorProperties, newRooms, priorRooms, allRooms] = await Promise.all([
        tx.user.groupBy({ by: ['role', 'isActive'], _count: true }),
        tx.property.groupBy({ by: ['isArchived'], _count: true }),
        tx.room.groupBy({ by: ['status'], where: { isActive: true, property: { isArchived: false } }, _count: true }),
        tx.user.count({ where: { createdAt: current } }), tx.user.count({ where: { createdAt: previous } }),
        tx.property.count({ where: { createdAt: current } }), tx.property.count({ where: { createdAt: previous } }),
        tx.room.count({ where: { createdAt: current } }), tx.room.count({ where: { createdAt: previous } }),
        tx.room.count(),
      ]);
      const accountTotal = accounts.reduce((sum, row) => sum + row._count, 0);
      const roleCount = (role: string) => accounts.filter(row => row.role === role).reduce((sum, row) => sum + row._count, 0);
      const roomCount = (status: string) => rooms.filter(row => row.status === status).reduce((sum, row) => sum + row._count, 0);
      const roomTotal = rooms.reduce((sum, row) => sum + row._count, 0);
      const activeProperties = properties.filter(row => !row.isArchived).reduce((sum, row) => sum + row._count, 0);

      const financeColumns = canFinance ? Prisma.sql`,
        COALESCE(p.collected, 0) AS "rentalCollected", COALESCE(p.reversed, 0) AS "rentalReversed"` : Prisma.empty;
      const financeJoin = canFinance ? Prisma.sql`
        LEFT JOIN (
          SELECT (p."paidAt" + interval '7 hours')::date AS day,
            COALESCE(SUM(p.amount) FILTER (WHERE p.type = 'PAYMENT'), 0)::bigint AS collected,
            COALESCE(-SUM(p.amount) FILTER (WHERE p.type = 'REVERSAL'), 0)::bigint AS reversed
          FROM "Payment" p JOIN "Invoice" i ON i.id = p."invoiceId"
          WHERE i."isDemo" = false AND p."paidAt" >= ${period.from} AND p."paidAt" <= ${period.to}
          GROUP BY 1
        ) p ON p.day = d.day` : Prisma.empty;
      const rows = await tx.$queryRaw<TrendRow[]>(Prisma.sql`
        WITH days AS (
          SELECT generate_series((${period.from}::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,
            (${period.to}::timestamptz AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, interval '1 day')::date AS day
        ), users_by_day AS (
          SELECT ("createdAt" + interval '7 hours')::date AS day, COUNT(*) AS total FROM "User"
          WHERE "createdAt" >= ${period.from} AND "createdAt" <= ${period.to} GROUP BY 1
        ), properties_by_day AS (
          SELECT ("createdAt" + interval '7 hours')::date AS day, COUNT(*) AS total FROM "Property"
          WHERE "createdAt" >= ${period.from} AND "createdAt" <= ${period.to} GROUP BY 1
        ), rooms_by_day AS (
          SELECT ("createdAt" + interval '7 hours')::date AS day, COUNT(*) AS total FROM "Room"
          WHERE "createdAt" >= ${period.from} AND "createdAt" <= ${period.to} GROUP BY 1
        ), listings_by_day AS (
          SELECT ("createdAt" + interval '7 hours')::date AS day, COUNT(*) AS total FROM "RoomListing"
          WHERE "createdAt" >= ${period.from} AND "createdAt" <= ${period.to} GROUP BY 1
        )
        SELECT to_char(d.day, 'YYYY-MM-DD') AS day, COALESCE(u.total, 0) AS accounts,
          COALESCE(b.total, 0) AS properties, COALESCE(r.total, 0) AS rooms, COALESCE(l.total, 0) AS listings
          ${financeColumns}
        FROM days d LEFT JOIN users_by_day u ON u.day = d.day
          LEFT JOIN properties_by_day b ON b.day = d.day LEFT JOIN rooms_by_day r ON r.day = d.day
          LEFT JOIN listings_by_day l ON l.day = d.day ${financeJoin} ORDER BY d.day`);

      const trends = rows.map(row => ({ day: row.day, accounts: Number(row.accounts), properties: Number(row.properties),
        rooms: Number(row.rooms), listings: Number(row.listings), ...(canFinance ? {
          rentalCollected: Number(row.rentalCollected ?? 0), rentalReversed: Number(row.rentalReversed ?? 0),
          rentalNet: Number(row.rentalCollected ?? 0) - Number(row.rentalReversed ?? 0),
        } : {}) }));
      let finance;
      if (canFinance) {
        const sum = async (type: 'PAYMENT' | 'REVERSAL', paidAt: typeof current | typeof previous) => {
          const result = await tx.payment.aggregate({ where: { type, paidAt, invoice: { isDemo: false } }, _sum: { amount: true } });
          return result._sum.amount ?? 0;
        };
        const [collected, reversals, priorCollected, priorReversals, expenses, balance, failedPayments] = await Promise.all([
          sum('PAYMENT', current), sum('REVERSAL', current), sum('PAYMENT', previous), sum('REVERSAL', previous),
          tx.expense.aggregate({ where: { expenseDate: current }, _sum: { amount: true } }),
          tx.invoice.aggregate({ where: { isDemo: false, status: { in: ['UNPAID', 'PARTIAL'] } }, _sum: { totalAmount: true, paidAmount: true } }),
          tx.paymentLink.count({ where: { status: 'FAILED', updatedAt: current, invoice: { isDemo: false } } }),
        ]);
        finance = {
          currency: 'VND', rentalCollected: collected, rentalReversed: -reversals, rentalNet: collected + reversals,
          rentalGrowth: overviewGrowth(collected + reversals, priorCollected + priorReversals),
          expenses: expenses._sum.amount ?? 0,
          outstandingSnapshot: (balance._sum.totalAmount ?? 0) - (balance._sum.paidAmount ?? 0),
          failedPayments,
          platformRevenue: { available: false, amount: null, reason: 'SUBSCRIPTION_BILLING_NOT_IMPLEMENTED' },
        };
      }
      return { data: {
        generatedAt: period.to.toISOString(), timezone: 'Asia/Ho_Chi_Minh', days: query.days,
        period: { from: period.from.toISOString(), to: period.to.toISOString(),
          previousFrom: period.previousFrom.toISOString(), previousTo: period.previousTo.toISOString(), comparison: 'PREVIOUS_FULL_PERIOD' },
        accounts: { total: accountTotal, active: accounts.filter(row => row.isActive).reduce((sum, row) => sum + row._count, 0),
          inactive: accounts.filter(row => !row.isActive).reduce((sum, row) => sum + row._count, 0),
          landlords: roleCount('LANDLORD'), tenants: roleCount('TENANT'), staff: roleCount('STAFF'), admins: roleCount('ADMIN') },
        properties: { total: properties.reduce((sum, row) => sum + row._count, 0), active: activeProperties,
          archived: properties.filter(row => row.isArchived).reduce((sum, row) => sum + row._count, 0) },
        rooms: { total: allRooms, active: roomTotal, ...(canRooms ? { occupied: roomCount('OCCUPIED'), vacant: roomCount('VACANT'),
          maintenance: roomCount('MAINTENANCE'), occupancyRate: roomTotal ? roomCount('OCCUPIED') / roomTotal : null } : {}) },
        growth: { accounts: overviewGrowth(newAccounts, priorAccounts), properties: overviewGrowth(newProperties, priorProperties),
          rooms: overviewGrowth(newRooms, priorRooms) },
        ...(finance ? { finance } : {}), trends,
      } };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }
}
