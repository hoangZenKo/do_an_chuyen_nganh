import { BadRequestException, ConflictException, ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AdminVerificationService } from './admin-verification.service';
import { AdminPlansService } from './admin-plans.service';

const actor = { userId: 'admin', email: 'admin@example.test', role: AuthRole.ADMIN };

describe('admin verification transitions', () => {
  function setup() {
    const tx = {
      $queryRaw: jest.fn(),
      landlordVerification: {
        findUnique: jest.fn().mockResolvedValue({ id: 'verification', landlordId: 'landlord', status: 'PENDING', version: 1,
          ticketId: 'ticket', landlord: { isActive: true }, ticket: { requesterId: 'landlord', mergedIntoId: null,
            attachments: [{ id: 'attachment', sha256: 'hash', file: { purpose: 'SUPPORT_CLEAN' } }] } }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      auditLog: { create: jest.fn() },
    };
    const prisma = { $transaction: jest.fn(work => work(tx)) };
    return { tx, service: new AdminVerificationService(prisma as never) };
  }

  it('reviews the expected version and audits without leaking documents', async () => {
    const { service, tx } = setup();
    const result = await service.review(actor, 'verification', { status: 'APPROVED', version: 1, reason: 'Evidence reviewed' });
    expect(result.data).toMatchObject({ id: 'verification', status: 'APPROVED', version: 2 });
    expect(tx.landlordVerification.updateMany).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'verification', version: 1, status: 'PENDING' } }));
    expect(JSON.stringify(result)).not.toContain('SUPPORT_CLEAN');
    expect(tx.auditLog.create).toHaveBeenCalled();
  });

  it('refuses stale versions, terminal decisions and concurrent updates', async () => {
    const { service, tx } = setup();
    await expect(service.review(actor, 'verification', { status: 'APPROVED', version: 2, reason: 'Evidence reviewed' })).rejects.toThrow(ConflictException);
    tx.landlordVerification.findUnique.mockResolvedValue({ id: 'verification', landlordId: 'landlord', status: 'APPROVED', version: 1 });
    await expect(service.review(actor, 'verification', { status: 'REJECTED', version: 1, reason: 'Evidence reviewed' })).rejects.toThrow(ConflictException);
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });

  it('will not approve inactive owners or unscanned/mismatched evidence', async () => {
    const { service, tx } = setup();
    const row = await tx.landlordVerification.findUnique();
    row.ticket.attachments[0].file.purpose = 'PRIVATE';
    await expect(service.review(actor, 'verification', { status: 'APPROVED', version: 1, reason: 'Evidence reviewed' })).rejects.toThrow(BadRequestException);
    expect(tx.landlordVerification.updateMany).not.toHaveBeenCalled();
  });

  it('blocks reviewing your own verification request', async () => {
    const { service } = setup();
    await expect(service.review({ ...actor, userId: 'landlord' }, 'verification', { status: 'APPROVED', version: 1, reason: 'Evidence reviewed' })).rejects.toThrow(ForbiddenException);
  });
});

describe('service plans and subscription administration', () => {
  function setup() {
    const tx = {
      user: { findFirst: jest.fn().mockResolvedValue({ id: 'landlord' }) },
      servicePlan: { findUnique: jest.fn().mockResolvedValue({ id: 'plan', code: 'PRO', name: 'Pro', price: 100000, maxProperties: 5, maxRooms: 50, isActive: true, version: 2 }) },
      landlordSubscription: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn().mockImplementation(({ data }) => ({ id: 'subscription', version: 1, ...data })) },
      subscriptionEvent: { create: jest.fn() },
      property: { count: jest.fn().mockResolvedValue(1) },
      room: { count: jest.fn().mockResolvedValue(10) },
      auditLog: { create: jest.fn() },
      $queryRaw: jest.fn(),
    };
    return { tx, service: new AdminPlansService({ $transaction: jest.fn(work => work(tx)) } as never) };
  }

  it('snapshots terms and records assignment as non-financial history', async () => {
    const { service, tx } = setup();
    const result = await service.assign(actor, 'landlord', { planId: 'plan', planVersion: 2, version: 0,
      endsAt: new Date(Date.now() + 86400000).toISOString(), reason: 'Pilot entitlement assignment' });
    expect(result.data.planSnapshot).toMatchObject({ code: 'PRO', maxRooms: 50, price: 100000 });
    expect(tx.subscriptionEvent.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ action: 'ASSIGNED' }) }));
    expect(result).not.toHaveProperty('revenue');
  });

  it('rejects stale plan revisions and unsafe downgrades', async () => {
    const { service, tx } = setup();
    const input = { planId: 'plan', planVersion: 1, version: 0, endsAt: new Date(Date.now() + 86400000).toISOString(), reason: 'Pilot entitlement assignment' };
    await expect(service.assign(actor, 'landlord', input)).rejects.toThrow(ConflictException);
    tx.room.count.mockResolvedValue(100);
    await expect(service.assign(actor, 'landlord', { ...input, planVersion: 2 })).rejects.toThrow(ConflictException);
    expect(tx.landlordSubscription.create).not.toHaveBeenCalled();
  });

  it('cancels current entitlement without refunds or deleting inventory', async () => {
    const tx = { $queryRaw: jest.fn(), landlordSubscription: {
      findUnique: jest.fn(async () => ({ id: 'subscription', landlordId: 'owner', version: 2, endsAt: null })),
      updateMany: jest.fn(async () => ({ count: 1 })),
      findUniqueOrThrow: jest.fn(async () => ({ id: 'subscription', version: 3, endsAt: new Date() })),
    }, subscriptionEvent: { create: jest.fn() }, auditLog: { create: jest.fn() } };
    const service = new AdminPlansService({ $transaction: jest.fn(work => work(tx)) } as never);
    expect((await service.cancel(actor, 'subscription', { version: 2, reason: 'Cancel pilot entitlement' })).data.version).toBe(3);
    expect(tx.subscriptionEvent.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ action: 'CANCELLED' }) }));
  });
});
