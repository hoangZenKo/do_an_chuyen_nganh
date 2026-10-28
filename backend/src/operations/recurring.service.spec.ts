import { nextOccurrence } from './recurring.service';

describe('Vietnam recurring operation calendar', () => {
  test('clamps end of month and restores the original local anchor day', () => {
    const january = new Date('2026-01-30T17:00:00Z');
    const february = nextOccurrence(january, 'MONTHLY', 1, 31);
    expect(february.toISOString()).toBe('2026-02-27T17:00:00.000Z');
    expect(nextOccurrence(february, 'MONTHLY', 1, 31).toISOString()).toBe('2026-03-30T17:00:00.000Z');
  });
  test('handles leap years, quarters, intervals and year boundaries', () => {
    expect(nextOccurrence(new Date('2027-01-30T17:00:00Z'), 'MONTHLY', 13, 31).toISOString()).toBe('2028-02-28T17:00:00.000Z');
    expect(nextOccurrence(new Date('2026-10-30T17:00:00Z'), 'QUARTERLY', 1, 31).toISOString()).toBe('2027-01-30T17:00:00.000Z');
    expect(nextOccurrence(new Date('2026-12-30T23:00:00Z'), 'DAILY', 2, 31).toISOString()).toBe('2027-01-01T23:00:00.000Z');
    expect(nextOccurrence(new Date('2026-10-24T02:15:00Z'), 'WEEKLY', 2, 24).toISOString()).toBe('2026-11-07T02:15:00.000Z');
  });
});
