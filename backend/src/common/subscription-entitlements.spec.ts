import { ConflictException } from '@nestjs/common';
import { assertInventoryGrowth } from './subscription-entitlements';

describe('subscription entitlement enforcement', () => {
  function setup() {
    return { $queryRaw: jest.fn(), landlordSubscription: { findUnique: jest.fn(async () => ({
      endsAt: null as Date | null, planSnapshot: { maxProperties: 2, maxRooms: 5 },
    })) }, property: { count: jest.fn(async () => 1) }, room: { count: jest.fn(async () => 5) } };
  }
  it('serializes owner inventory changes and rejects growth beyond snapshot limits', async () => {
    const tx = setup();
    await assertInventoryGrowth(tx as never, 'owner', 'property');
    expect(tx.$queryRaw).toHaveBeenCalled();
    await expect(assertInventoryGrowth(tx as never, 'owner', 'room')).rejects.toThrow(ConflictException);
  });
  it('denies growth after expiry but never deletes existing inventory', async () => {
    const tx = setup();
    tx.landlordSubscription.findUnique.mockResolvedValue({ endsAt: new Date(0), planSnapshot: { maxProperties: 2, maxRooms: 5 } });
    await expect(assertInventoryGrowth(tx as never, 'owner', 'property')).rejects.toThrow(ConflictException);
    expect(tx.property.count).not.toHaveBeenCalled();
  });
});
