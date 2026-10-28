import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';
import { AdminConsoleService } from './admin-console.service';
import { AdminPageQuery } from './admin-console.dto';
import { AuthUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';

describe('Admin account management', () => {
  const actor: AuthUser = { userId: 'operator', role: AuthRole.ADMIN, email: 'operator@example.test' };
  const customer = { id: 'customer', fullName: 'Customer', email: 'customer@example.test',
    phone: '0912345678', role: 'LANDLORD', isActive: true, sessionVersion: 7, createdAt: new Date() };
  let tx: any;
  let service: AdminConsoleService;

  beforeEach(() => {
    tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      user: { findFirst: jest.fn().mockResolvedValue(customer), findUnique: jest.fn().mockResolvedValue(customer),
        findMany: jest.fn().mockResolvedValue([customer]), count: jest.fn().mockResolvedValue(21),
        update: jest.fn().mockResolvedValue({ ...customer, isActive: false, sessionVersion: 8 }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      authSession: { updateMany: jest.fn().mockResolvedValue({ count: 2 }) },
      refreshToken: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      accountAccessToken: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      staffProfile: { findMany: jest.fn().mockResolvedValue([{ userId: 'staff' }]) },
      auditLog: { create: jest.fn().mockResolvedValue({ id: 'audit' }), findMany: jest.fn().mockResolvedValue([]) },
    };
    const prisma = { ...tx, $transaction: jest.fn((operation: any) =>
      typeof operation === 'function' ? operation(tx) : Promise.all(operation)) };
    service = new AdminConsoleService(prisma as any, {} as any, {} as any);
  });

  it('rejects reversed account creation ranges before querying persistence', async () => {
    const query = Object.assign(new AdminPageQuery(), { from: '2026-10-27T00:00:00Z', to: '2026-10-01T00:00:00Z' });
    await expect(service.accounts(query)).rejects.toThrow(BadRequestException);
    expect(tx.user.findMany).not.toHaveBeenCalled();
  });

  it('masks contacts, keeps version/metadata and bounds server pagination', async () => {
    const query = Object.assign(new AdminPageQuery(), { page: 2, role: 'LANDLORD', status: 'inactive',
      search: 'Customer', from: '2026-10-01T00:00:00+07:00', to: '2026-10-27T23:59:59+07:00' });
    const response = await service.accounts(query);
    expect(response.meta).toEqual({ page: 2, limit: 20, total: 21, pages: 2 });
    expect(response.data[0]).toMatchObject({ email: 'c***@example.test', phone: '***678', version: 7 });
    expect(tx.user.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 20, take: 20,
      where: expect.objectContaining({ role: 'LANDLORD', isActive: false,
        createdAt: { gte: new Date(query.from!), lte: new Date(query.to!) } }) }));
  });

  it('suspends customer and dependent staff sessions, auditing both versions atomically', async () => {
    await service.status(actor, customer.id, { version: 7, reason: 'Verified support request' }, false);
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({ where: { userId: 'customer', revokedAt: null },
      data: { revokedAt: expect.any(Date) } });
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({ where: { userId: { in: ['staff'] }, revokedAt: null },
      data: { revokedAt: expect.any(Date) } });
    expect(tx.auditLog.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({
      action: 'admin.account_suspend', summary: 'Verified support request',
      metadata: expect.objectContaining({ before: { isActive: true, version: 7 }, after: { isActive: false, version: 8 } }) }) }));
  });

  it('rejects a stale status version without token, session or audit writes', async () => {
    await expect(service.status(actor, customer.id, { version: 6, reason: 'Verified support request' }, false)).rejects.toThrow(ConflictException);
    expect(tx.user.update).not.toHaveBeenCalled();
    expect(tx.authSession.updateMany).not.toHaveBeenCalled();
    expect(tx.auditLog.create).not.toHaveBeenCalled();
  });

  it('revoke reports the number of revoked sessions and records it in audit', async () => {
    const response = await service.revoke(actor, customer.id, 'Reported lost device');
    expect(response.data).toEqual({ revoked: true, revokedSessions: 2 });
    expect(tx.auditLog.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({
      metadata: { before: { version: 7 }, after: { version: 8 }, revokedSessions: 2 } }) }));
  });

  it('keeps administrator accounts outside customer session revoke', async () => {
    tx.user.findUnique.mockResolvedValue({ ...customer, role: 'ADMIN' });
    await expect(service.revoke(actor, customer.id, 'Reported lost device')).rejects.toThrow(NotFoundException);
    expect(tx.user.update).not.toHaveBeenCalled();
  });
});
