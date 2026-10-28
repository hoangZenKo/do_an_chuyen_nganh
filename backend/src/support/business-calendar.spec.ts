import { addWorkingMilliseconds, BusinessCalendar, resumeSlaDeadline, slaClockTransition, slaDeadlines, SupportSlaSnapshot, workingMilliseconds } from './business-calendar';

describe('support business calendar', () => {
  const minute = 60000;
  const calendar: BusinessCalendar = { timezone: 'UTC', weekdays: [1, 2, 3, 4, 5], startMinute: 540, endMinute: 1020, holidays: [] };
  const snapshot: SupportSlaSnapshot = { ...calendar, version: 1, pauseWaiting: true, responseMinutes: { NORMAL: 60 }, resolutionMinutes: { NORMAL: 120 }, escalationMinutes: [0, 60] };

  it('skips weekends without rounding away seconds', () => {
    expect(addWorkingMilliseconds(new Date('2026-10-23T16:30:20Z'), 120 * minute, calendar).toISOString()).toBe('2026-10-26T10:30:20.000Z');
  });
  it('skips configured holidays', () => {
    expect(addWorkingMilliseconds(new Date('2026-10-23T16:30Z'), 120 * minute, { ...calendar, holidays: ['2026-10-26'] }).toISOString()).toBe('2026-10-27T10:30:00.000Z');
  });
  it('does not count closed hours in elapsed work', () => {
    expect(workingMilliseconds(new Date('2026-10-23T16:00Z'), new Date('2026-10-26T10:00Z'), calendar)).toBe(120 * minute);
  });
  it('honours IANA offsets rather than the host timezone', () => {
    expect(addWorkingMilliseconds(new Date('2026-10-26T01:00Z'), 60 * minute, { ...calendar, timezone: 'Asia/Ho_Chi_Minh' }).toISOString()).toBe('2026-10-26T03:00:00.000Z');
  });
  it('counts actual work through the spring DST gap', () => {
    const sunday = { ...calendar, timezone: 'America/New_York', weekdays: [7], startMinute: 60, endMinute: 240 };
    expect(addWorkingMilliseconds(new Date('2026-03-08T06:00Z'), 120 * minute, sunday).toISOString()).toBe('2026-03-08T08:00:00.000Z');
  });
  it('counts the repeated fall DST hour once in real elapsed time', () => {
    const sunday = { ...calendar, timezone: 'America/New_York', weekdays: [7], startMinute: 60, endMinute: 240 };
    expect(addWorkingMilliseconds(new Date('2026-11-01T05:00Z'), 180 * minute, sunday).toISOString()).toBe('2026-11-01T08:00:00.000Z');
  });
  it('clamps a nonexistent opening time to the next valid wall time', () => {
    const sunday = { ...calendar, timezone: 'America/New_York', weekdays: [7], startMinute: 150, endMinute: 240 };
    expect(addWorkingMilliseconds(new Date('2026-03-08T06:00Z'), 30 * minute, sunday).toISOString()).toBe('2026-03-08T07:30:00.000Z');
  });
  it('preserves already overdue deadlines on resume', () => {
    const due = new Date('2026-10-23T15:00Z');
    expect(resumeSlaDeadline(due, new Date('2026-10-23T16:00Z'), new Date('2026-10-26T10:00Z'), calendar)).toEqual(due);
  });
  it('preserves only the remaining work budget on resume', () => {
    expect(resumeSlaDeadline(new Date('2026-10-23T17:00Z'), new Date('2026-10-23T16:00Z'), new Date('2026-10-24T10:00Z'), calendar).toISOString()).toBe('2026-10-26T10:00:00.000Z');
  });
  it('does not restart a paused clock on reassignment or repeated pause', () => {
    const ticket = { slaSnapshot: snapshot, slaPausedAt: new Date('2026-10-23T16:00Z'), resolutionDueAt: new Date('2026-10-23T17:00Z') };
    expect(slaClockTransition(ticket, 'WAITING_FOR_USER', new Date('2026-10-26T10:00Z')).slaPausedAt).toEqual(ticket.slaPausedAt);
    expect(slaClockTransition(ticket, 'IN_PROGRESS', new Date('2026-10-26T10:00Z')).resolutionDueAt.toISOString()).toBe('2026-10-26T11:00:00.000Z');
  });
  it('keeps legacy elapsed-hour deadlines when business policy is disabled', () => {
    expect(slaDeadlines('NORMAL', new Date('2026-10-23T16:00Z')).firstResponseDueAt.toISOString()).toBe('2026-10-24T16:00:00.000Z');
  });
});
