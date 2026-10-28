import { nextReportAt } from './report-schedule';
import { flagEnabled } from './feature-flags.service';
import { reportCsv } from './admin-report-worker.service';
import { supportDeadlines } from '../support/support.service';

describe('Platform rules', () => {
  it.each([['URGENT', 1, 12], ['HIGH', 4, 24], ['NORMAL', 24, 72], ['LOW', 48, 120]])('sets %s response and resolution SLA', (priority, responseHours, resolutionHours) => {
    const deadlines = supportDeadlines(priority as string, 0);
    expect(deadlines.firstResponseDueAt.getTime()).toBe(Number(responseHours) * 3600000);
    expect(deadlines.resolutionDueAt.getTime()).toBe(Number(resolutionHours) * 3600000);
  });
  it('calculates initial UTC run today or tomorrow without modifying reference', () => {
    const reference = new Date('2026-10-25T08:30:00Z');
    expect(nextReportAt(reference, 'DAILY', 9, true).toISOString()).toBe('2026-10-25T09:00:00.000Z');
    expect(nextReportAt(reference, 'DAILY', 8, true).toISOString()).toBe('2026-10-26T08:00:00.000Z');
    expect(reference.toISOString()).toBe('2026-10-25T08:30:00.000Z');
  });
  it.each([['DAILY', '2026-10-26T08:00:00.000Z'], ['WEEKLY', '2026-11-01T08:00:00.000Z'], ['MONTHLY', '2026-11-25T08:00:00.000Z']])('advances %s in UTC', (cadence, expected) => {
    expect(nextReportAt(new Date('2026-10-25T08:00:00Z'), cadence, 8).toISOString()).toBe(expected);
  });
  it('clamps monthly runs to the last valid day, including leap years', () => {
    expect(nextReportAt(new Date('2026-01-31T08:00:00Z'), 'MONTHLY', 8).toISOString()).toBe('2026-02-28T08:00:00.000Z');
    expect(nextReportAt(new Date('2028-01-31T08:00:00Z'), 'MONTHLY', 8).toISOString()).toBe('2028-02-29T08:00:00.000Z');
  });
  it('enforces enabled, role allowlists and zero/full rollout', () => {
    expect(flagEnabled({ enabled: false, roles: [], rollout: 100 }, 'support.user_tickets', 'user-1', 'tenant')).toBe(false);
    expect(flagEnabled({ enabled: true, roles: ['admin'], rollout: 100 }, 'support.user_tickets', 'user-1', 'tenant')).toBe(false);
    expect(flagEnabled({ enabled: true, roles: [], rollout: 0 }, 'support.user_tickets', 'user-1', 'tenant')).toBe(false);
    expect(flagEnabled({ enabled: true, roles: [], rollout: 100 }, 'support.user_tickets', 'user-1', 'tenant')).toBe(true);
  });
  it('schedules local business hours in Vietnam and quarter-hour timezones', () => {
    expect(nextReportAt(new Date('2026-10-26T00:00:00Z'), 'DAILY', 8, true, 'Asia/Ho_Chi_Minh').toISOString()).toBe('2026-10-26T01:00:00.000Z');
    expect(nextReportAt(new Date('2026-10-26T00:00:00Z'), 'DAILY', 8, true, 'Asia/Kathmandu').toISOString()).toBe('2026-10-26T02:15:00.000Z');
  });
  it('skips nonexistent DST hours and selects the earliest future ambiguous hour', () => {
    expect(nextReportAt(new Date('2026-03-08T05:00:00Z'), 'DAILY', 2, true, 'America/New_York').toISOString()).toBe('2026-03-09T06:00:00.000Z');
    expect(nextReportAt(new Date('2026-11-01T04:00:00Z'), 'DAILY', 1, true, 'America/New_York').toISOString()).toBe('2026-11-01T05:00:00.000Z');
    expect(() => nextReportAt(new Date(), 'DAILY', 8, true, 'Invalid/Zone')).toThrow('Invalid IANA');
  });
  it('makes percentage rollout deterministic and monotonic', () => {
    const users = Array.from({ length: 1000 }, (_, index) => `user-${index}`);
    const low = users.filter(id => flagEnabled({ enabled: true, roles: [], rollout: 10 }, 'moderation.bulk', id, 'admin'));
    const high = users.filter(id => flagEnabled({ enabled: true, roles: [], rollout: 50 }, 'moderation.bulk', id, 'admin'));
    expect(low.length).toBeGreaterThan(50); expect(low.length).toBeLessThan(150);
    expect(low.every(id => high.includes(id))).toBe(true);
    expect(high).toEqual(users.filter(id => flagEnabled({ enabled: true, roles: [], rollout: 50 }, 'moderation.bulk', id, 'admin')));
  });
  it('escapes CSV formulas, commas, quotes and newlines', () => {
    const csv = reportCsv([{ title: '=HYPERLINK("unsafe")', text: 'a,b\nsecond', total: 3 }, { title: ' @SUM(A1)', total: -2 }]);
    expect(csv).toContain('"\'=HYPERLINK(""unsafe"")"');
    expect(csv).toContain('"\' @SUM(A1)"');
    expect(csv).toContain('"a,b\nsecond"');
  });
});
