import { ForbiddenException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { AdminSearchService } from './admin-search.service';
import { AdminSearchQuery } from './admin-search.dto';

describe('AdminSearchService', () => {
  const actor: AuthUser = { userId: 'admin-1', email: 'admin@example.test', role: AuthRole.ADMIN, permissions: ['admin.dashboard.view', 'admin.finance.read'] };
  function setup() {
    const tx = {
      payment: { findMany: jest.fn().mockResolvedValue([{ id: 'p-1', invoiceId: 'i-1', amount: 100, type: 'PAYMENT', method: 'CASH', paidAt: new Date() }]), count: jest.fn().mockResolvedValue(11) },
      auditLog: { create: jest.fn().mockResolvedValue({ id: 'audit-1' }) },
    };
    const prisma = { $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)) };
    return { service: new AdminSearchService(prisma as never), tx, prisma };
  }
  it('paginates payment search, returns metadata and atomically audits sensitive reads', async () => {
    const { service, tx, prisma } = setup();
    const query = Object.assign(new AdminSearchQuery(), { search: 'invoice', kind: 'PAYMENT', page: 2, limit: 10 });
    const response = await service.search(actor, query);
    expect(prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
    expect(tx.payment.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 10, take: 10 }));
    expect(response).toMatchObject({ meta: { page: 2, limit: 10, perKindPagination: true }, data: [{ kind: 'PAYMENT', meta: { total: 11, hasMore: false } }] });
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ action: 'admin.search_sensitive_access', resourceId: 'global' }) });
  });
  it('fails closed when a caller requests a kind outside its permission set', async () => {
    const { service } = setup();
    const query = Object.assign(new AdminSearchQuery(), { search: 'tenant', kind: 'TENANT' });
    await expect(service.search(actor, query)).rejects.toBeInstanceOf(ForbiddenException);
  });
});
