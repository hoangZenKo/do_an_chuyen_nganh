import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { ManualTransferService } from './manual-transfer.service';

describe('Manual transfer recipient configuration', () => {
  const owner = { userId: 'owner', email: 'owner@example.test', role: AuthRole.LANDLORD };
  const input = { version: 0, enabled: true, bankName: 'Bank test', accountName: 'NGUYEN VAN A', accountNumber: '0012345678' };
  let tx: any;
  let service: ManualTransferService;
  beforeEach(() => {
    tx = { $queryRaw: jest.fn(), property: { findFirst: jest.fn().mockResolvedValue({ id: 'property' }) },
      propertyPaymentAccount: { findUnique: jest.fn().mockResolvedValue(null), upsert: jest.fn().mockResolvedValue({ ...input, version: 1 }) },
      uploadedFile: { findFirst: jest.fn() }, auditLog: { create: jest.fn() },
      invoice: { findFirst: jest.fn().mockResolvedValue({ id: 'invoice', isDemo: false, status: 'UNPAID', totalAmount: 10000, paidAmount: 2000,
        room: { property: { isArchived: false, paymentAccount: { ...input, enabled: true, version: 1, qrImagePath: null } } } }) },
      paymentProof: { aggregate: jest.fn().mockResolvedValue({ _sum: { amount: 3000 } }) } };
    service = new ManualTransferService({ ...tx, $transaction: jest.fn(async work => work(tx)) } as any);
  });
  it('stores a versioned account and audits only safe metadata', async () => {
    await service.save(owner, 'property', input);
    expect(tx.propertyPaymentAccount.upsert).toHaveBeenCalledWith(expect.objectContaining({
      create: expect.objectContaining({ accountNumber: '0012345678', version: 1 }),
      update: expect.objectContaining({ version: { increment: 1 } }),
    }));
    expect(JSON.stringify(tx.auditLog.create.mock.calls)).not.toContain('0012345678');
  });
  it('rejects stale versions and properties not owned by the requester', async () => {
    tx.propertyPaymentAccount.findUnique.mockResolvedValue({ version: 2 });
    await expect(service.save(owner, 'property', input)).rejects.toThrow(ConflictException);
    tx.property.findFirst.mockResolvedValue(null);
    await expect(service.save(owner, 'property', input)).rejects.toThrow(NotFoundException);
    expect(tx.propertyPaymentAccount.upsert).not.toHaveBeenCalled();
  });
  it('never grants staff authority to change the bank recipient', async () => {
    await expect(service.save({ ...owner, role: AuthRole.STAFF, landlordId: owner.userId }, 'property', input)).rejects.toThrow(ForbiddenException);
  });
  it('rejects unknown QR uploads and accepts only private images belonging to the owner', async () => {
    await expect(service.save(owner, 'property', { ...input, qrImagePath: 'https://external.test/qr.png' })).rejects.toThrow(BadRequestException);
    await expect(service.save(owner, 'property', { ...input, qrImagePath: '/uploads/qr.png' })).rejects.toThrow(BadRequestException);
    tx.uploadedFile.findFirst.mockResolvedValue({ filename: 'qr.png' });
    await service.save(owner, 'property', { ...input, qrImagePath: '/uploads/qr.png' });
    expect(tx.uploadedFile.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ ownerId: owner.userId, purpose: 'PRIVATE' }) }));
  });
  it('returns only owned invoice instructions and reserves amounts already pending review', async () => {
    const result = await service.instructions('tenant-user', 'invoice');
    expect(result.data).toMatchObject({ mode: 'MANUAL_BANK_TRANSFER', remainingAmount: 8000, pendingAmount: 3000, availableAmount: 5000, canSubmit: true });
    expect(tx.invoice.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'invoice', tenant: { userId: 'tenant-user' } } }));
    expect(tx.propertyPaymentAccount.upsert).not.toHaveBeenCalled();
  });
  it('does not offer transfer instructions for demo, cancelled or fully paid invoices', async () => {
    const invoice = await tx.invoice.findFirst();
    for (const changes of [{ isDemo: true }, { status: 'CANCELLED' }, { paidAmount: 10000 }]) {
      tx.invoice.findFirst.mockResolvedValue({ ...invoice, ...changes });
      expect((await service.instructions('tenant-user', 'invoice')).data.canSubmit).toBe(false);
      expect((await service.instructions('tenant-user', 'invoice')).data.account).toBeNull();
    }
  });
  it('returns no recipient when configuration is missing or disabled', async () => {
    const invoice = await tx.invoice.findFirst();
    invoice.room.property.paymentAccount.enabled = false;
    const result = await service.instructions('tenant-user', 'invoice');
    expect(result.data).toMatchObject({ account: null, canSubmit: false });
  });
});
