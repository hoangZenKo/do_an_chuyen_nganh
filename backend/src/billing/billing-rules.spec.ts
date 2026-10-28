import { agingBucket, businessDay, commandHash, requiredReason } from './billing-rules';
import { reminderMatches } from './billing-reminders.service';
import { retryDelay } from './billing-outbox.service';
import { utilityCharges, validateTiers } from './utility-pricing';

describe('Production billing rules', () => {
  const now = new Date('2026-10-25T18:00:00Z');
  it('uses Vietnam calendar days at the UTC day boundary', () => {
    expect(businessDay(now)).toBe('2026-10-26');
    expect(agingBucket(new Date('2026-10-26Z'), now)).toBe('notDue');
  });
  it.each([['2026-10-25', 'overdue1To7'], ['2026-10-19', 'overdue1To7'], ['2026-10-18', 'overdue8To30'], ['2026-09-26', 'overdue8To30'], ['2026-09-25', 'overdueOver30']])('buckets %s as %s', (due, bucket) => {
    expect(agingBucket(new Date(due), now)).toBe(bucket);
  });
  it('keeps undated debt visible instead of silently dropping it', () => expect(agingBucket(null, now)).toBe('undated'));
  it('rejects a whitespace-only cancellation reason', () => expect(() => requiredReason('  ')).toThrow());
  it('canonicalizes object key order for retry hashes', () => expect(commandHash({ amount: 10, key: 'a' })).toBe(commandHash({ key: 'a', amount: 10 })));
  it('matches the exact scheduled reminder offsets', () => {
    const policy = { enabled: true, beforeDays: [3], onDueDate: true, overdueDays: [1, 7] };
    expect(reminderMatches(policy, new Date('2026-10-29Z'), now)).toBe(true);
    expect(reminderMatches(policy, new Date('2026-10-28Z'), now)).toBe(false);
    expect(reminderMatches(policy, new Date('2026-10-26Z'), now)).toBe(true);
    expect(reminderMatches({ ...policy, enabled: false }, new Date('2026-10-26Z'), now)).toBe(false);
  });
  it('calculates progressive utility tiers without repricing the lower band', () => {
    expect(utilityCharges(150, 0, [{ upTo: 100, unitPrice: 2000 }, { upTo: null, unitPrice: 3000 }])).toEqual([{ quantity: 100, unitPrice: 2000, amount: 200000 }, { quantity: 50, unitPrice: 3000, amount: 150000 }]);
  });
  it('rejects overlapping and capped final tiers and monetary overflow', () => {
    expect(() => validateTiers([{ upTo: 100, unitPrice: 1 }, { upTo: 50, unitPrice: 2 }, { unitPrice: 3 }])).toThrow();
    expect(() => validateTiers([{ upTo: 100, unitPrice: 1 }])).toThrow();
    expect(() => utilityCharges(2147483647, 2, [])).toThrow();
  });
  it('bounds exponential retry backoff', () => {
    expect(retryDelay(1)).toBe(15000); expect(retryDelay(3)).toBe(60000); expect(retryDelay(100)).toBe(3600000);
  });
});
