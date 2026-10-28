import { BadRequestException } from '@nestjs/common';

export interface BusinessCalendar {
  timezone: string;
  weekdays: number[];
  startMinute: number;
  endMinute: number;
  holidays: string[];
}
export interface SupportSlaSnapshot extends BusinessCalendar {
  version: number;
  pauseWaiting: boolean;
  responseMinutes: Record<string, number>;
  resolutionMinutes: Record<string, number>;
  escalationMinutes: number[];
}

export function calendarFormatter(timezone: string) {
  try { return new Intl.DateTimeFormat('en-GB', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }); }
  catch { throw new BadRequestException('Invalid IANA support timezone.'); }
}

function localWall(formatter: Intl.DateTimeFormat, epoch: number) {
  const parts = Object.fromEntries(formatter.formatToParts(new Date(epoch)).filter(part => part.type !== 'literal').map(part => [part.type, Number(part.value)]));
  return Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute);
}

function boundary(formatter: Intl.DateTimeFormat, wall: number, last: boolean): number | null {
  const offsets = new Set<number>();
  for (const hours of [-36, -12, 0, 12, 36]) {
    const sample = wall + hours * 3600000;
    offsets.add(localWall(formatter, sample) - sample);
  }
  for (let gap = 0; gap <= 180; gap++) {
    const desired = wall + gap * 60000;
    const candidates = [...offsets].map(offset => desired - offset).filter(epoch => localWall(formatter, epoch) === desired);
    if (candidates.length) return last ? Math.max(...candidates) : Math.min(...candidates);
  }
  return null;
}

function* windows(reference: Date, calendar: BusinessCalendar, until?: Date) {
  const formatter = calendarFormatter(calendar.timezone);
  const wall = new Date(localWall(formatter, reference.getTime()));
  wall.setUTCHours(0, 0, 0, 0);
  const holidays = new Set(calendar.holidays);
  for (let day = 0; day < 1100; day++) {
    if (!until || wall.getTime() < until.getTime() + 2 * 86400000) {
      if (calendar.weekdays.includes(wall.getUTCDay() || 7) && !holidays.has(wall.toISOString().slice(0, 10))) {
        const start = boundary(formatter, wall.getTime() + calendar.startMinute * 60000, false);
        const end = boundary(formatter, wall.getTime() + calendar.endMinute * 60000, true);
        if (start !== null && end !== null && end > start) yield { start, end };
      }
    } else return;
    wall.setUTCDate(wall.getUTCDate() + 1);
  }
}

export function addWorkingMilliseconds(reference: Date, amount: number, calendar?: BusinessCalendar | null) {
  if (!calendar) return new Date(reference.getTime() + amount);
  if (!Number.isFinite(amount) || amount < 0) throw new BadRequestException('Invalid SLA duration.');
  if (!amount) return new Date(reference);
  let remaining = amount;
  for (const window of windows(reference, calendar)) {
    const start = Math.max(window.start, reference.getTime());
    const available = Math.max(0, window.end - start);
    if (available && remaining <= available) return new Date(start + remaining);
    remaining -= available;
  }
  throw new BadRequestException('SLA exceeds the supported calendar horizon.');
}

export function workingMilliseconds(from: Date, to: Date, calendar?: BusinessCalendar | null) {
  if (to <= from) return 0;
  if (!calendar) return to.getTime() - from.getTime();
  let total = 0;
  for (const window of windows(from, calendar, to)) total += Math.max(0, Math.min(window.end, to.getTime()) - Math.max(window.start, from.getTime()));
  return total;
}

export function resumeSlaDeadline(deadline: Date, pausedAt: Date, now: Date, calendar?: BusinessCalendar | null) {
  if (deadline <= pausedAt) return deadline;
  const remaining = workingMilliseconds(pausedAt, deadline, calendar);
  return addWorkingMilliseconds(now, remaining, calendar);
}

export function slaDeadlines(priority: string, now: Date, snapshot?: SupportSlaSnapshot | null) {
  const response = snapshot?.responseMinutes[priority] ?? ({ URGENT: 60, HIGH: 240, NORMAL: 1440, LOW: 2880 } as Record<string, number>)[priority] ?? 1440;
  const resolution = snapshot?.resolutionMinutes[priority] ?? ({ URGENT: 720, HIGH: 1440, NORMAL: 4320, LOW: 7200 } as Record<string, number>)[priority] ?? 4320;
  return { firstResponseDueAt: addWorkingMilliseconds(now, response * 60000, snapshot), resolutionDueAt: addWorkingMilliseconds(now, resolution * 60000, snapshot) };
}

export function slaClockTransition(ticket: { slaSnapshot: unknown; slaPausedAt: Date | null; resolutionDueAt: Date }, nextStatus: string, now = new Date()) {
  const snapshot = ticket.slaSnapshot as SupportSlaSnapshot | null;
  const stopped = ['RESOLVED', 'CLOSED'].includes(nextStatus) || (nextStatus === 'WAITING_FOR_USER' && snapshot?.pauseWaiting === true);
  return { slaPausedAt: stopped ? ticket.slaPausedAt ?? now : null,
    resolutionDueAt: !stopped && ticket.slaPausedAt ? resumeSlaDeadline(ticket.resolutionDueAt, ticket.slaPausedAt, now, snapshot) : ticket.resolutionDueAt };
}
