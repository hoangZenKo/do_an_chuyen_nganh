import { ConflictException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { AuthRole } from '../common/auth-role';
import { AdminPropertyReviewService } from './admin-property-review.service';

const actor = { userId: 'admin', email: 'admin@example.test', role: AuthRole.ADMIN };
describe('property review safety', () => {
  function setup() {
    const property = { id: 'property', landlordId: 'owner', name: 'Building', address: 'Address', isArchived: false };
    const before = { id: 'review', propertyId: property.id, version: 1, status: 'PENDING', snapshotHash: createHash('sha256').update(JSON.stringify(property)).digest('hex'), property };
    const tx = { $queryRaw: jest.fn(), property: { findUnique: jest.fn(async () => property) },
      propertyApprovalReview: { findUnique: jest.fn(async () => before), updateMany: jest.fn(async () => ({ count: 1 })),
        update: jest.fn(async () => ({ id: 'review', version: 2, status: 'PENDING' })) }, auditLog: { create: jest.fn() } };
    return { property, before, tx, service: new AdminPropertyReviewService({ $transaction: jest.fn(work => work(tx)) } as never) };
  }
  it('approves a matching snapshot and audits in the same transaction', async () => {
    const { service, tx } = setup();
    expect((await service.review(actor, 'review', { version: 1, status: 'APPROVED', reason: 'Reviewed current information' })).data.status).toBe('APPROVED');
    expect(tx.auditLog.create).toHaveBeenCalledTimes(1);
  });
  it('refuses changed information, archived properties and stale versions', async () => {
    const { service, property, tx } = setup();
    property.address = 'Changed address';
    await expect(service.review(actor, 'review', { version: 1, status: 'APPROVED', reason: 'Reviewed current information' })).rejects.toThrow(ConflictException);
    property.isArchived = true;
    await expect(service.review(actor, 'review', { version: 2, status: 'REJECTED', reason: 'Reviewed current information' })).rejects.toThrow(ConflictException);
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });
  it('allows a changed pending snapshot to be resubmitted without approval', async () => {
    const { service, property, tx } = setup();
    property.name = 'Updated building';
    await service.submit(actor, 'property', { version: 1, reason: 'Resubmit changed information' });
    expect(tx.propertyApprovalReview.update).toHaveBeenCalled();
  });
});
