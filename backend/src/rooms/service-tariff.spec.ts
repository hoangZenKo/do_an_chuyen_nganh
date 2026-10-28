import { RoomServiceFee, ServiceTariffVersion } from '@prisma/client';

import { businessMonth, effectiveFee, tariffMonth } from './service-tariff';

const fee = (overrides: Partial<RoomServiceFee> = {}, versions: ServiceTariffVersion[] = []) => ({
  id: 'fee-1', roomId: 'room-1', name: 'Internet', amount: 100_000, isActive: true, note: null,
  createdAt: new Date(), updatedAt: new Date(), versions, ...overrides,
});

const version = (overrides: Partial<ServiceTariffVersion> = {}) => ({
  id: 'version-1', serviceFeeId: 'fee-1', version: 1, name: 'Internet', unit: 'thang', amount: 100_000,
  isActive: true, effectiveFrom: new Date('2026-10-01T00:00:00Z'), note: null, createdAt: new Date(), ...overrides,
});

describe('versioned service tariff selection', () => {
  it('selects the latest version effective for the billing month', () => {
    const selected = effectiveFee(fee({}, [version(), version({ id: 'version-2', version: 2, amount: 120_000, effectiveFrom: new Date('2026-11-01T00:00:00Z') })]), new Date('2026-11-01T00:00:00Z'));
    expect(selected).toMatchObject({ amount: 120_000, tariffVersion: 2 });
  });

  it('does not use a future version for an earlier invoice', () => {
    const selected = effectiveFee(fee({}, [version(), version({ id: 'version-2', version: 2, amount: 120_000, effectiveFrom: new Date('2026-11-01T00:00:00Z') })]), new Date('2026-10-01T00:00:00Z'));
    expect(selected).toMatchObject({ amount: 100_000, tariffVersion: 1 });
  });

  it('falls back to legacy mutable fee records', () => {
    expect(effectiveFee(fee(), businessMonth())).toMatchObject({ amount: 100_000, tariffVersionId: null });
  });

  it('uses historical activity, not the mutable latest projection, for earlier months', () => {
    const scheduledStop = version({ id: 'stop', version: 2, isActive: false, effectiveFrom: new Date('2026-11-01Z') });
    const history = fee({ isActive: false }, [scheduledStop, version()]);
    expect(effectiveFee(history, new Date('2026-10-01Z'))).toMatchObject({ tariffVersion: 1, amount: 100_000 });
    expect(effectiveFee(history, new Date('2026-11-01Z'))).toBeNull();
  });

  it('does not charge a fee before its first effective period', () => {
    expect(effectiveFee(fee({}, [version()]), new Date('2026-09-01Z'))).toBeNull();
  });

  it('uses the Vietnamese billing month at the UTC month boundary', () => {
    expect(businessMonth(new Date('2026-10-31T18:00:00Z')).toISOString()).toBe('2026-11-01T00:00:00.000Z');
  });

  it.each(['2026-13-01', '2026-11-15', '2026-11-01T07:00:00+07:00'])('rejects noncanonical effective dates: %s', (date) => {
    expect(() => tariffMonth(date, businessMonth())).toThrow();
  });
});
