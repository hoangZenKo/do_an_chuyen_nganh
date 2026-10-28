import { NotFoundException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { propertyScopeContext } from '../common/property-scope';
import { PrismaService } from '../prisma/prisma.service';
import { businessMonth } from '../rooms/service-tariff';
import { BillingCommandsService } from './billing-commands.service';
import { BillingTariffsService } from './billing-tariffs.service';

const actor: AuthUser = { userId: 'owner', email: 'owner@example.test', role: AuthRole.LANDLORD };

function fixture() {
  const tariff = {
    id: 'proposal', landlordId: 'owner', propertyId: 'property', roomId: null,
    scopeKey: 'property:property', serviceKey: 'internet', kind: 'SERVICE',
    state: 'PROPOSED', effectiveFrom: businessMonth(), version: 2,
  };
  const prisma = {
    billingTariffVersion: {
      findFirst: jest.fn().mockResolvedValueOnce(tariff).mockResolvedValueOnce(null).mockResolvedValueOnce(null),
      findMany: jest.fn().mockResolvedValue([]),
    },
    room: { findMany: jest.fn().mockResolvedValue([{ id: 'room-a', name: 'A101' }, { id: 'room-b', name: 'A102' }]) },
    invoice: { count: jest.fn().mockResolvedValue(0) },
    billingPeriodLock: { count: jest.fn().mockResolvedValue(0) },
  };
  const service = new BillingTariffsService(prisma as unknown as PrismaService, {} as BillingCommandsService);
  return { service, prisma, tariff };
}

describe('Billing tariff impact preview', () => {
  it('rejects an omitted property filter before any unscoped tariff read', async () => {
    const { service, prisma } = fixture();
    await expect(service.list(actor, undefined as unknown as string)).rejects.toThrow();
    await expect(service.list(actor, ' ')).rejects.toThrow();
    expect(prisma.billingTariffVersion.findMany).not.toHaveBeenCalled();
  });

  it('compares to another approved version, not the viewed document itself', async () => {
    const { service, prisma } = fixture();
    const result = await service.impact(actor, 'proposal');
    expect(result.data.canApprove).toBe(true);
    expect(prisma.billingTariffVersion.findFirst.mock.calls[1][0].where).toMatchObject({
      id: { not: 'proposal' }, scopeKey: 'property:property', state: 'APPROVED',
    });
    expect(prisma.billingTariffVersion.findFirst.mock.calls[1][0].orderBy).toEqual([{ effectiveFrom: 'desc' }, { version: 'desc' }]);
  });

  it('separates overridden rooms while preserving conservative issued-period guards', async () => {
    const { service, prisma } = fixture();
    prisma.billingTariffVersion.findMany.mockResolvedValue([{ roomId: 'room-b' }]);
    prisma.invoice.count.mockResolvedValue(1);
    const result = await service.impact(actor, 'proposal');
    expect(result.data.rooms).toEqual([{ id: 'room-a', name: 'A101' }]);
    expect(result.data.overriddenRooms).toEqual([{ id: 'room-b', name: 'A102' }]);
    expect(result.data.blockingReasons).toContain('ISSUED_INVOICES');
    expect(result.data.canApprove).toBe(false);
    expect(prisma.billingTariffVersion.findMany.mock.calls[0][0].where).toMatchObject({
      propertyId: 'property', serviceKey: 'internet', state: 'APPROVED', roomId: { not: null },
    });
  });

  it.each(['same', 'later'])('blocks %s effective month against latest approved version', async (offset) => {
    const { service, prisma, tariff } = fixture();
    const approvedMonth = new Date(tariff.effectiveFrom);
    if (offset === 'later') approvedMonth.setUTCMonth(approvedMonth.getUTCMonth() + 1);
    prisma.billingTariffVersion.findFirst.mockReset()
      .mockResolvedValueOnce(tariff).mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'approved', effectiveFrom: approvedMonth });
    const result = await service.impact(actor, 'proposal');
    expect(result.data.canApprove).toBe(false);
    expect(result.data.blockingReasons).toContain('EFFECTIVE_ORDER');
  });

  it('returns closed, stale and already-reviewed reasons without offering approval', async () => {
    const { service, prisma, tariff } = fixture();
    tariff.state = 'APPROVED';
    tariff.effectiveFrom.setUTCMonth(tariff.effectiveFrom.getUTCMonth() - 1);
    prisma.billingPeriodLock.count.mockResolvedValue(2);
    const result = await service.impact(actor, 'proposal');
    expect(result.data.blockingReasons).toEqual(expect.arrayContaining(['ALREADY_REVIEWED', 'BACKDATED', 'LOCKED_PERIODS']));
    expect(result.data.canApprove).toBe(false);
  });

  it('keeps landlord and staff property scope checks on direct IDs', async () => {
    const { service, prisma } = fixture();
    const staff: AuthUser = { ...actor, userId: 'staff', landlordId: 'owner', role: AuthRole.STAFF, propertyIds: ['property'] };
    await propertyScopeContext.run(staff, () => service.impact(staff, 'proposal'));
    expect(prisma.billingTariffVersion.findFirst.mock.calls[0][0].where).toEqual({
      id: 'proposal', landlordId: 'owner', propertyId: { in: ['property'] },
    });
    prisma.billingTariffVersion.findFirst.mockResolvedValue(null);
    await expect(service.impact(actor, 'foreign')).rejects.toBeInstanceOf(NotFoundException);
  });
});
