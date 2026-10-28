import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { PrismaService } from '../prisma/prisma.service';

import {
  proratedSettlementRent,
  settlementMoney,
  LeaseSettlementsService,
} from './settlements.service';

const actor = { userId: 'owner', email: 'owner@example.test', role: AuthRole.LANDLORD };
const input = { moveOutDate: '2026-08-15', lines: [], note: 'Move-out settlement' };

function harness() {
  const lease = {
    id: 'lease', roomId: 'room', status: 'ACTIVE', monthlyRent: 3_100_000,
    startDate: new Date('2026-08-01'), updatedAt: new Date('2026-08-01'),
    handover: { id: 'handover', electricity: 100, water: 10 },
    settlement: null as Record<string, unknown> | null,
    depositTransactions: [{ id: 'collected', type: 'COLLECTED', amount: 2_000_000 }],
  };
  const tx = {
    $queryRaw: jest.fn().mockResolvedValue([]),
    lease: {
      findFirst: jest.fn(async () => lease), update: jest.fn(),
      count: jest.fn().mockResolvedValue(0),
    },
    invoice: { findMany: jest.fn().mockResolvedValue([]) },
    meterReading: { findFirst: jest.fn().mockResolvedValue(null) },
    leaseSettlement: {
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn(async ({ data }) => {
        lease.settlement = { ...data, id: 'settlement', version: 1, lines: data.lines.create };
        return lease.settlement;
      }),
      update: jest.fn(async ({ data }) => {
        lease.settlement = { ...lease.settlement, ...data, version: 2 };
        return lease.settlement;
      }),
    },
    depositTransaction: { create: jest.fn(async ({ data }) => {
      const entry = { id: `entry-${lease.depositTransactions.length}`, ...data };
      lease.depositTransactions.push(entry);
      return entry;
    }) },
    roomTurnover: { findFirst: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'turnover' }) },
    room: { findUniqueOrThrow: jest.fn().mockResolvedValue({ propertyId: 'property' }), update: jest.fn() },
    roomListing: { updateMany: jest.fn() },
    auditLog: { create: jest.fn() },
  };
  const prisma = { ...tx, $transaction: jest.fn(async operation => operation(tx)) };
  const service = new LeaseSettlementsService(prisma as unknown as PrismaService);
  return { service, prisma, tx, lease };
}

describe('LeaseSettlementsService', () => {
  it.each([AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN])('denies %s before querying any data', async role => {
    const { service, prisma } = harness();
    const unauthorized = { ...actor, role };
    await expect(service.get(unauthorized, 'lease')).rejects.toThrow(ForbiddenException);
    await expect(service.preview(unauthorized, 'lease', input)).rejects.toThrow(ForbiddenException);
    await expect(service.confirm(unauthorized, 'lease', { ...input, previewFingerprint: '0'.repeat(64), idempotencyKey: 'request' })).rejects.toThrow(ForbiddenException);
    await expect(service.recordRefund(unauthorized, 'lease', { version: 1, reference: 'receipt', reason: 'Refund received', idempotencyKey: 'refund' })).rejects.toThrow(ForbiddenException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
    expect(prisma.lease.findFirst).not.toHaveBeenCalled();
  });

  it('scopes ownership and returns 404 for another landlord', async () => {
    const { service, tx } = harness();
    tx.lease.findFirst.mockResolvedValueOnce(null!);
    await expect(service.get(actor, 'other-lease')).rejects.toThrow(NotFoundException);
    expect(tx.lease.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'other-lease', room: { property: { landlordId: actor.userId } } },
    }));
  });

  it('combines ledger entries, prorated rent and utility charges without mutating data', async () => {
    const { service, tx, lease } = harness();
    lease.depositTransactions.push(
      { id: 'adjusted', type: 'ADJUSTMENT', amount: 100_000 },
      { id: 'deducted', type: 'DEDUCTED', amount: 50_000 },
      { id: 'refunded', type: 'REFUNDED', amount: 50_000 },
    );
    const { data } = await service.preview(actor, 'lease', {
      ...input, finalElectricity: 110, electricityUnitPrice: 3_000,
      finalWater: 12, waterUnitPrice: 10_000,
      lines: [{ kind: 'CLEANING', description: 'Cleaning', amount: 50_000 }],
    });
    expect(data).toMatchObject({ rentAmount: 1_500_000, electricityAmount: 30_000, waterAmount: 20_000,
      totalCharges: 1_600_000, depositBalance: 2_000_000, depositApplied: 1_600_000, refundAmount: 400_000, balanceDue: 0 });
    expect(data.previewFingerprint).toMatch(/^[a-f0-9]{64}$/);
    expect(tx.leaseSettlement.create).not.toHaveBeenCalled();
    expect(tx.depositTransaction.create).not.toHaveBeenCalled();
  });

  it('keeps existing invoices separate and never bills rent twice', async () => {
    const { service, tx } = harness();
    tx.invoice.findMany.mockResolvedValue([{ id: 'invoice', billingMonth: new Date('2026-08-01'),
      totalAmount: 3_100_000, paidAmount: 100_000, status: 'PARTIALLY_PAID', updatedAt: new Date('2026-08-01') }]);
    const { data } = await service.preview(actor, 'lease', input);
    expect(data).toMatchObject({ monthAlreadyBilled: true, rentAmount: 0, depositApplied: 0,
      refundAmount: 2_000_000, outstandingInvoiceAmount: 3_000_000, totalOutstanding: 3_000_000 });
  });

  it('leaves an explicit amount due when charges exceed the deposit', async () => {
    const { service } = harness();
    const { data } = await service.preview(actor, 'lease', {
      ...input, lines: [{ kind: 'DAMAGE', description: 'Broken door', amount: 1_000_000 }],
    });
    expect(data).toMatchObject({ totalCharges: 2_500_000, depositApplied: 2_000_000, refundAmount: 0, balanceDue: 500_000 });
  });

  it.each(['2026-02-30', '2099-01-01', '2026-07-31'])('rejects invalid move-out date %s', async moveOutDate => {
    const { service } = harness();
    await expect(service.preview(actor, 'lease', { ...input, moveOutDate })).rejects.toThrow(BadRequestException);
  });

  it('rejects final readings below the current meter baseline', async () => {
    const { service, tx } = harness();
    tx.meterReading.findFirst.mockResolvedValue({ id: 'meter', billingMonth: new Date('2026-08-01'), currentReading: 120, unitPrice: 3_000 });
    await expect(service.preview(actor, 'lease', { ...input, finalElectricity: 110 })).rejects.toThrow(BadRequestException);
  });

  it('rejects unpriced utility usage and future invoices', async () => {
    const { service, tx } = harness();
    await expect(service.preview(actor, 'lease', { ...input, finalWater: 12 })).rejects.toThrow(BadRequestException);
    tx.invoice.findMany.mockResolvedValue([{ billingMonth: new Date('2026-09-01') }]);
    await expect(service.preview(actor, 'lease', input)).rejects.toThrow(ConflictException);
  });

  it('rejects stale fingerprints before creating a settlement or ledger entry', async () => {
    const { service, tx, lease } = harness();
    const { data } = await service.preview(actor, 'lease', input);
    lease.depositTransactions.push({ id: 'new-entry', type: 'COLLECTED', amount: 1 });
    await expect(service.confirm(actor, 'lease', { ...input, previewFingerprint: data.previewFingerprint, idempotencyKey: 'request' })).rejects.toThrow(ConflictException);
    expect(tx.leaseSettlement.create).not.toHaveBeenCalled();
    expect(tx.depositTransaction.create).not.toHaveBeenCalled();
  });

  it('confirms atomically and returns the same settlement for an identical retry', async () => {
    const { service, prisma, tx } = harness();
    const preview = await service.preview(actor, 'lease', input);
    const confirmation = { ...input, previewFingerprint: preview.data.previewFingerprint, idempotencyKey: 'request' };
    const first = await service.confirm(actor, 'lease', confirmation);
    const retry = await service.confirm(actor, 'lease', confirmation);
    expect(first.idempotent).toBe(false);
    expect(retry.idempotent).toBe(true);
    expect(retry.data).toEqual(first.data);
    expect(first.data).not.toHaveProperty('requestKey');
    expect(first.data).not.toHaveProperty('requestHash');
    expect(tx.leaseSettlement.create).toHaveBeenCalledTimes(1);
    expect(tx.depositTransaction.create).toHaveBeenCalledTimes(1);
    expect(tx.lease.update).toHaveBeenCalledWith({ where: { id: 'lease' }, data: { status: 'ENDED', endDate: new Date('2026-08-15') } });
    expect(tx.room.update).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'MAINTENANCE', tenantName: null } }));
    expect(tx.roomListing.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: { status: 'HIDDEN' } }));
    expect(prisma.$transaction).toHaveBeenLastCalledWith(expect.any(Function), { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
    await expect(service.confirm(actor, 'lease', { ...confirmation, note: 'Different intent' })).rejects.toThrow(ConflictException);
  });

  it('records a refund only once, preserving the settlement version', async () => {
    const { service, tx } = harness();
    const preview = await service.preview(actor, 'lease', input);
    await service.confirm(actor, 'lease', { ...input, previewFingerprint: preview.data.previewFingerprint, idempotencyKey: 'request' });
    const refund = { version: 1, reference: 'bank-receipt-123', reason: 'Tenant received the refund', idempotencyKey: 'refund' };
    expect((await service.recordRefund(actor, 'lease', refund)).data).toMatchObject({ refundStatus: 'PAID', version: 2, refundAmount: 500_000 });
    expect((await service.recordRefund(actor, 'lease', refund)).idempotent).toBe(true);
    expect(tx.depositTransaction.create).toHaveBeenCalledTimes(2);
    expect(tx.leaseSettlement.update).toHaveBeenCalledTimes(1);
    await expect(service.recordRefund(actor, 'lease', { ...refund, idempotencyKey: 'another-refund' })).rejects.toThrow(ConflictException);
  });

  it('rejects stale refund versions and a changed deposit balance', async () => {
    const { service, tx, lease } = harness();
    const preview = await service.preview(actor, 'lease', input);
    await service.confirm(actor, 'lease', { ...input, previewFingerprint: preview.data.previewFingerprint, idempotencyKey: 'request' });
    const refund = { version: 2, reference: 'receipt', reason: 'Refund to the tenant', idempotencyKey: 'refund' };
    await expect(service.recordRefund(actor, 'lease', refund)).rejects.toThrow(ConflictException);
    lease.depositTransactions.push({ id: 'external-deduction', type: 'DEDUCTED', amount: 1 });
    await expect(service.recordRefund(actor, 'lease', { ...refund, version: 1 })).rejects.toThrow(ConflictException);
    expect(tx.leaseSettlement.update).not.toHaveBeenCalled();
  });
});

describe('lease settlement calculations', () => {
  it('calculates rent inclusively for a partial month', () => {
    const result = proratedSettlementRent(
      3_100_000,
      new Date('2026-02-10T00:00:00.000Z'),
      new Date('2026-02-28T00:00:00.000Z'),
    );

    expect(result).toEqual({
      amount: 2_103_571,
      occupiedDays: 19,
      daysInMonth: 28,
    });
  });

  it('uses the lease start date when it begins inside the move-out month', () => {
    const result = proratedSettlementRent(
      3_000_000,
      new Date('2026-04-01T12:00:00.000Z'),
      new Date('2026-04-30T00:00:00.000Z'),
    );

    expect(result).toEqual({
      amount: 3_000_000,
      occupiedDays: 30,
      daysInMonth: 30,
    });
  });

  it('rejects a move-out date before the occupied period', () => {
    expect(() =>
      proratedSettlementRent(
        3_000_000,
        new Date('2026-05-10T00:00:00.000Z'),
        new Date('2026-05-09T00:00:00.000Z'),
      ),
    ).toThrow(BadRequestException);
  });

  it('rejects unsafe or negative money values', () => {
    expect(() => settlementMoney(-1)).toThrow(BadRequestException);
    expect(() => settlementMoney(2_147_483_648)).toThrow(BadRequestException);
    expect(settlementMoney(0)).toBe(0);
  });
});
