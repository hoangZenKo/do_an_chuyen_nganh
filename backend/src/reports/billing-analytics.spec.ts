import { billingAnalytics } from './billing-analytics';

describe('billing analytics read model', () => {
  const now = new Date('2026-10-26T00:00:00Z');

  it('computes MRR, collection, occupancy and overdue days with explicit definitions', () => {
    const result = billingAnalytics(
      [{ monthlyRent: 3000000 }, { monthlyRent: 2500000 }],
      [{ id: 'room-1' }, { id: 'room-2' }, { id: 'room-3' }],
      [{ roomId: 'room-1' }, { roomId: 'room-2' }],
      [{ totalAmount: 1000, paidAmount: 500, dueDate: new Date('2026-10-26Z') }],
      [
        { totalAmount: 1000, paidAmount: 500, dueDate: new Date('2026-10-20Z') },
        { totalAmount: 1000, paidAmount: 1000, dueDate: new Date('2026-10-01Z') },
      ],
      now,
    );
    expect(result.monthlyRecurringRevenue).toBe(5500000);
    expect(result.collectionRate).toBe(0.5);
    expect(result.occupancyRate).toBeCloseTo(2 / 3);
    expect(result.overdueInvoiceCount).toBe(1);
    expect(result.averageOverdueDays).toBe(6);
    expect(result.definitions).toHaveProperty('collectionRate');
  });

  it('returns null rates when there is no denominator', () => {
    const result = billingAnalytics([], [], [], [], [], now);
    expect(result.collectionRate).toBeNull();
    expect(result.occupancyRate).toBeNull();
    expect(result.averageOverdueDays).toBeNull();
  });
});
