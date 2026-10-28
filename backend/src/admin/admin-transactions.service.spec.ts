import { BadRequestException } from '@nestjs/common';
import { AdminTransactionsService, AdminTransactionsQuery } from './admin-transactions.service';
import { AuthRole } from '../common/auth-role';

describe('admin transaction investigation', () => {
  it('uses bounded safe projections and transactional access auditing', async () => {
    const tx = { paymentLink: { findMany: jest.fn(async (_query: { select: object }) => []), count: jest.fn(async () => 0) }, auditLog: { create: jest.fn() } };
    const service = new AdminTransactionsService({ $transaction: jest.fn(work => work(tx)) } as never);
    await service.list({ userId: 'admin', email: 'private@example.test', role: AuthRole.ADMIN }, Object.assign(new AdminTransactionsQuery(), { kind: 'LINK', status: 'FAILED' }));
    const query = tx.paymentLink.findMany.mock.calls[0][0];
    expect(query).toMatchObject({ take: 20, skip: 0, where: { status: 'FAILED' } });
    for (const secret of ['checkoutUrl', 'qrCode', 'accountNumber', 'accountName', 'description', 'tokenHash']) expect(query.select).not.toHaveProperty(secret);
    expect(tx.auditLog.create).toHaveBeenCalled();
  });
  it('refuses unbounded ranges and mismatched type/status filters', async () => {
    const service = new AdminTransactionsService({} as never);
    const actor = { userId: 'admin', email: 'private@example.test', role: AuthRole.ADMIN };
    await expect(service.list(actor, Object.assign(new AdminTransactionsQuery(), { from: '2020-01-01T00:00:00Z', to: '2026-01-01T00:00:00Z' }))).rejects.toThrow(BadRequestException);
    await expect(service.list(actor, Object.assign(new AdminTransactionsQuery(), { kind: 'PAYMENT', status: 'FAILED' }))).rejects.toThrow(BadRequestException);
  });
});
