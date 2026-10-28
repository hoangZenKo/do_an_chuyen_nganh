import { businessDay, dueDays } from '../billing/billing-rules';

type Balance = { totalAmount: number; paidAmount: number; dueDate: Date | null };

export function billingAnalytics(
  leases: { monthlyRent: number }[], rooms: { id: string }[],
  activeLeases: { roomId: string }[], cohort: Balance[], outstanding: Balance[],
  now = new Date(),
) {
  const billedAmount = cohort.reduce((sum, invoice) => sum + invoice.totalAmount, 0);
  const collectedAmount = cohort.reduce((sum, invoice) => sum + Math.min(Math.max(invoice.paidAmount, 0), invoice.totalAmount), 0);
  const activeRoomIds = new Set(activeLeases.map((lease) => lease.roomId));
  const occupiedRooms = rooms.filter((room) => activeRoomIds.has(room.id)).length;
  const days = outstanding.filter((invoice) => invoice.dueDate && invoice.totalAmount > invoice.paidAmount)
    .map((invoice) => dueDays(invoice.dueDate!, now)).filter((value) => value > 0);
  return {
    asOf: now.toISOString(), businessDay: businessDay(now), timezone: 'Asia/Ho_Chi_Minh', rateUnit: 'ratio',
    monthlyRecurringRevenue: leases.reduce((sum, lease) => sum + lease.monthlyRent, 0),
    billedAmount, collectedAmount,
    collectionRate: billedAmount ? collectedAmount / billedAmount : null,
    totalRooms: rooms.length, occupiedRooms,
    occupancyRate: rooms.length ? occupiedRooms / rooms.length : null,
    overdueInvoiceCount: days.length,
    averageOverdueDays: days.length ? days.reduce((sum, value) => sum + value, 0) / days.length : null,
    definitions: {
      monthlyRecurringRevenue: 'Current active lease rent only; excludes variable utilities, deposits and one-off adjustments.',
      collectionRate: 'Current allocated balance on the selected billing-month cohort / issued total, net of reversals and notes. Not cash received during the month.',
      occupancyRate: 'Active rooms with a current active lease / all active rooms in non-archived properties.',
      averageOverdueDays: 'Unweighted mean over currently outstanding overdue invoices across all billing months, using Vietnam business dates.',
    },
  };
}
