import { FinanceReconciliationService } from './finance-reconciliation.service';

describe('FinanceReconciliationService', () => {
  it('requires a separate checker for maker-checker approval', async () => {
    const service = new FinanceReconciliationService({} as never);
    const actor = { userId: 'maker', role: 'admin', permissions: ['admin.finance.reconcile'] } as any;
    const prisma = {
      $transaction: async (callback: any) => callback({
        $queryRaw: jest.fn(),
        financeReconciliationProposal: { findUnique: jest.fn().mockResolvedValue({ status: 'PENDING', makerId: 'maker', lineVersion: 1, line: { version: 1 } }) },
      }),
    } as never;
    const checkerService = new FinanceReconciliationService(prisma);
    await expect(checkerService.review(actor, 'proposal', { version: 1, reason: 'review' }, true)).rejects.toThrow('Maker cannot approve own proposal.');
  });
});
