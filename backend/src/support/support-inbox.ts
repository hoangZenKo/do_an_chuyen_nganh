import { Prisma } from '@prisma/client';

export type SupportSlaFilter = 'all' | 'overdue' | 'due_soon' | 'paused';

export function supportSlaWhere(filter: SupportSlaFilter, now: Date): Prisma.SupportTicketWhereInput {
  if (filter === 'all') return {};
  const active: Prisma.SupportTicketWhereInput = {
    status: { notIn: ['RESOLVED', 'CLOSED'] }, mergedIntoId: null,
  };
  const overdue: Prisma.SupportTicketWhereInput = { OR: [
    { slaPausedAt: null, resolutionDueAt: { lt: now } },
    { firstRespondedAt: null, firstResponseDueAt: { lt: now } },
  ] };
  if (filter === 'overdue') return { AND: [active, overdue] };
  if (filter === 'paused') return { AND: [active, { slaPausedAt: { not: null } }] };
  const soon = new Date(now.getTime() + 3600000);
  return { AND: [active, { NOT: overdue }, { OR: [
    { slaPausedAt: null, resolutionDueAt: { gte: now, lte: soon } },
    { firstRespondedAt: null, firstResponseDueAt: { gte: now, lte: soon } },
  ] }] };
}
