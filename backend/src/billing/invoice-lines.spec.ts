import { UtilityType } from '@prisma/client';

import { buildInvoiceLines, serializeInvoiceLines } from './invoice-lines';

describe('invoice line snapshots', () => {
  it('calculates totals and preserves tariff provenance', () => {
    const result = buildInvoiceLines(
      { id: 'lease-1', monthlyRent: 3_000_000 },
      [{ id: 'meter-1', utilityType: UtilityType.ELECTRICITY, usage: 10, unitPrice: 3_500, amount: 35_000 } as never],
      [{ id: 'fee-1', roomId: 'room-1', name: 'Internet', unit: 'thang', amount: 100_000, tariffVersionId: 'tariff-1', tariffVersion: 3 }],
      20_000,
    );
    expect(result.totalAmount).toBe(3_155_000);
    expect(result.otherAmount).toBe(120_000);
    expect(result.lines).toEqual(expect.arrayContaining([
      expect.objectContaining({ source: 'SERVICE_TARIFF', tariffVersion: 3, amount: 100_000 }),
      expect.objectContaining({ source: 'MANUAL', amount: 20_000 }),
    ]));
  });

  it('serializes legacy invoices without inventing tariff data', () => {
    const lines = serializeInvoiceLines({
      id: 'invoice-1', rentAmount: 3_000_000, electricityAmount: 0, waterAmount: 0, otherAmount: 25_000,
    });
    expect(lines).toHaveLength(2);
    expect(lines[1]).toMatchObject({ source: 'legacy', tariffVersionId: null, amount: 25_000 });
  });

  it('rejects overflowing totals rather than persisting partial invoice data', () => {
    expect(() => buildInvoiceLines({ id: 'lease', monthlyRent: 2_147_483_647 }, [], [], 1)).toThrow();
  });

  it('rejects utility amounts inconsistent with quantity times price', () => {
    expect(() => buildInvoiceLines({ id: 'lease', monthlyRent: 1 }, [
      { utilityType: UtilityType.WATER, usage: 10, unitPrice: 100, amount: 999 } as never,
    ], [])).toThrow();
  });

  it('copies tariff values rather than keeping references to mutable fee inputs', () => {
    const fee = { id: 'fee', roomId: 'room', name: 'Internet', unit: 'thang', amount: 100, tariffVersionId: 'v1', tariffVersion: 1 };
    const snapshot = buildInvoiceLines({ id: 'lease', monthlyRent: 1000 }, [], [fee]);
    fee.amount = 200;
    fee.name = 'New name';
    expect(snapshot.lines[1]).toMatchObject({ description: 'Internet', unitPrice: 100, amount: 100, tariffVersion: 1 });
    expect(snapshot.totalAmount).toBe(1100);
  });
});
