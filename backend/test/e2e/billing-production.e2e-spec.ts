import { randomUUID } from 'node:crypto';
import { BillingRemindersService } from '../../src/billing/billing-reminders.service';
import { BillingOutboxService } from '../../src/billing/billing-outbox.service';
import { FinanceReconciliationService } from '../../src/platform/finance-reconciliation.service';
import { MaintenanceSlaService } from '../../src/maintenance/maintenance-sla.service';
import { SchemaReadinessService } from '../../src/health/schema-readiness.service';
import { AuthRole } from '../../src/common/auth-role';
import { AuthUser } from '../../src/common/current-user.decorator';
import { businessMonth } from '../../src/rooms/service-tariff';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Production billing ledger (disposable database)', () => {
  let harness: E2eHarness;
  let token: string;
  let landlordId: string;
  let propertyId: string;
  let roomId: string;
  let tenantId: string;
  let leaseId: string;
  const month = (offset = 0) => { const date = businessMonth(); return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + offset, 1)).toISOString().slice(0, 10); };
  const key = () => randomUUID();
  const call = (path: string, method = 'GET', body?: unknown, accessToken = token) => requestJson(harness.baseUrl, `/api/v1/billing/${path}`, { method, body, token: accessToken });
  const invoice = async (offset = 0) => { const result = await call('invoices', 'POST', { leaseId, billingMonth: month(offset), dueDate: '2026-10-26' }); expect(result.status).toBe(201); return result.json!.data; };
  const receiptInput = (amount: number, allocations: { invoiceId: string; amount: number }[] = []) => ({ requestKey: key(), tenantId, amount, allocations, method: 'BANK_TRANSFER', reference: 'bank-reference-1' });
  const maintenance = (path: string, method = 'GET', body?: unknown) => requestJson(harness.baseUrl, `/api/v1/maintenance${path}`, { method, body, token });
  async function financeActor(): Promise<AuthUser> {
    const created = await createAdmin(harness.prisma, 'billing-finance');
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { email: created.email } });
    return { userId: user.id, email: user.email, role: AuthRole.ADMIN, permissions: ['admin.finance.read', 'admin.finance.reconcile'] };
  }
  const propose = async (overrides = {}) => {
    const result = await call('tariffs/proposals', 'POST', { requestKey: key(), propertyId, kind: 'SERVICE', serviceKey: 'internet', name: 'Internet', unit: 'thang', amount: 100000, isActive: true, tiers: [], effectiveFrom: month(), reason: 'New tariff', ...overrides });
    expect(result.status).toBe(201); return result.json!.data;
  };
  beforeAll(async () => {
    if (process.env.NODE_ENV !== 'test' || !/^rental_billing_test_\d+_[a-f0-9]+$/.test(new URL(process.env.DATABASE_URL!).pathname.slice(1))) throw new Error('Use the disposable billing production runner.');
  });
  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const user = await registerLandlord(harness.baseUrl, 'production-billing');
    token = user.accessToken;
    landlordId = (await harness.prisma.user.findFirstOrThrow()).id;
    propertyId = (await createProperty(harness.baseUrl, token)).id;
    roomId = (await createRoom(harness.baseUrl, token, propertyId)).id;
    tenantId = (await createTenant(harness.baseUrl, token)).id;
    leaseId = (await createLease(harness.baseUrl, token, roomId, tenantId)).id;
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); });

  it('cancels only with a reason and replaces using a new immutable revision', async () => {
    const original = await invoice();
    expect((await call(`invoices/${original.id}/cancel`, 'POST', { note: '   ' })).status).toBe(400);
    const payload = { requestKey: key(), reason: 'Wrong rent', lines: [{ kind: 'RENT', description: 'Corrected rent', quantity: 1, unit: 'thang', unitPrice: 2000000 }] };
    const replacement = await call(`invoices/${original.id}/replacement`, 'POST', payload);
    expect(replacement.status).toBe(201);
    expect(replacement.json!.data).toMatchObject({ revision: 2, replacesInvoiceId: original.id, totalAmount: 2000000 });
    expect((await call(`invoices/${original.id}`)).json!.data).toMatchObject({ status: 'cancelled', replacementInvoiceId: replacement.json!.data.id });
    expect((await call(`invoices/${original.id}/replacement`, 'POST', payload)).json!.data.id).toBe(replacement.json!.data.id);
    await expect(harness.prisma.invoiceLineItem.update({ where: { id: original.lineItems[0].id }, data: { amount: 1 } })).rejects.toThrow();
  });

  it('appends credit/debit notes, preserves original lines and audits retries once', async () => {
    const original = await invoice();
    const payload = { requestKey: key(), kind: 'CREDIT', category: 'DISCOUNT', basisPoints: 1000, reason: 'Tenant loyalty' };
    const adjusted = await call(`invoices/${original.id}/adjustments`, 'POST', payload);
    expect(adjusted.status).toBe(201);
    expect(adjusted.json!.data.totalAmount).toBe(original.totalAmount * 0.9);
    expect(adjusted.json!.data.lineItems.slice(0, original.lineItems.length)).toEqual(original.lineItems);
    expect(adjusted.json!.data.lineItems.at(-1)).toMatchObject({ kind: 'credit_note', amount: -original.totalAmount * 0.1 });
    await call(`invoices/${original.id}/adjustments`, 'POST', payload);
    expect(await harness.prisma.invoiceAdjustment.count()).toBe(1);
    expect(await harness.prisma.auditLog.count({ where: { action: 'billing.invoice.adjust' } })).toBe(1);
    expect((await call(`invoices/${original.id}/adjustments`, 'POST', { ...payload, amount: 1, basisPoints: undefined })).status).toBe(409);
    const debit = await call(`invoices/${original.id}/adjustments`, 'POST', { requestKey: key(), kind: 'DEBIT', category: 'SURCHARGE', amount: 50000, reason: 'Additional service' });
    expect(debit.json!.data.totalAmount).toBe(adjusted.json!.data.totalAmount + 50000);
  });

  it('allocates one receipt across invoices, retains credit, releases and refunds with full history', async () => {
    const first = await invoice(); const second = await invoice(1);
    const payload = receiptInput(first.totalAmount + second.totalAmount + 50000, [{ invoiceId: first.id, amount: first.totalAmount }, { invoiceId: second.id, amount: second.totalAmount }]);
    const response = await call('receipts', 'POST', payload);
    expect(response.status).toBe(201);
    expect(response.json!.data.availableAmount).toBe(50000);
    expect(response.json!.data.allocations).toHaveLength(2);
    expect((await call('receipts', 'POST', payload)).json!.data.id).toBe(response.json!.data.id);
    const receiptId = response.json!.data.id;
    const allocation = response.json!.data.allocations[0];
    expect((await call(`invoices/${allocation.payment.invoiceId}/payments/${allocation.paymentId}/reverse`, 'POST', { note: 'wrong allocation' })).status).toBe(409);
    expect((await call(`receipts/${receiptId}/allocations/${allocation.id}/release`, 'POST', { requestKey: key(), reason: 'Wrong invoice' })).status).toBe(201);
    const refunded = await call(`receipts/${receiptId}/refunds`, 'POST', { requestKey: key(), amount: 50000, reference: 'refund-reference', reason: 'Return excess' });
    expect(refunded.status).toBe(201);
    expect(refunded.json!.data.refundedAmount).toBe(50000);
    expect((await call('aging')).json!.data.summary.total).toBe(allocation.amount);
  });

  it('rejects cross-landlord, cross-tenant, over-allocation and concurrent over-refund', async () => {
    const original = await invoice();
    const otherTenant = await createTenant(harness.baseUrl, token);
    expect((await call('receipts', 'POST', { ...receiptInput(original.totalAmount, [{ invoiceId: original.id, amount: 1 }]), tenantId: otherTenant.id })).status).toBe(400);
    expect((await call('receipts', 'POST', receiptInput(original.totalAmount + 1, [{ invoiceId: original.id, amount: original.totalAmount + 1 }]))).status).toBe(409);
    const stranger = (await registerLandlord(harness.baseUrl, 'stranger')).accessToken;
    expect((await call(`invoices/${original.id}/adjustments`, 'POST', { requestKey: key(), kind: 'DEBIT', category: 'SURCHARGE', amount: 1, reason: 'invalid scope' }, stranger)).status).toBe(404);
    const receipt = (await call('receipts', 'POST', receiptInput(100000))).json!.data;
    const results = await Promise.all([1, 2].map(() => call(`receipts/${receipt.id}/refunds`, 'POST', { requestKey: key(), amount: 75000, reference: 'refund-ref', reason: 'Return credit' })));
    expect(results.map((result) => result.status).sort()).toEqual([201, 409]);
    expect((await harness.prisma.billingReceipt.findUniqueOrThrow({ where: { id: receipt.id } })).availableAmount).toBe(25000);
  });

  it('serializes concurrent allocations so invoices cannot be overpaid', async () => {
    const original = await invoice();
    const payload = () => receiptInput(original.totalAmount, [{ invoiceId: original.id, amount: original.totalAmount }]);
    const result = await Promise.all([call('receipts', 'POST', payload()), call('receipts', 'POST', payload())]);
    expect(result.map((item) => item.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.billingReceipt.count()).toBe(1);
  });

  it('deduplicates reminders and skips delivery when payment was received', async () => {
    const original = await invoice();
    const policy = await call('reminder-policy', 'PUT', { requestKey: key(), expectedVersion: 0, enabled: true, beforeDays: [1], onDueDate: true, overdueDays: [1, 7], channels: ['APP'] });
    expect(policy.status).toBe(200);
    const now = new Date();
    const reminders = harness.app.get(BillingRemindersService);
    await Promise.all([reminders.enqueue(now, landlordId), reminders.enqueue(now, landlordId)]);
    expect(await harness.prisma.billingOutboxEvent.count({ where: { type: 'invoice.reminder' } })).toBe(1);
    const job = await harness.prisma.billingOutboxEvent.findFirstOrThrow({ where: { type: 'invoice.reminder' } });
    await harness.app.get(BillingOutboxService).deliver(job.id, now);
    expect(await harness.prisma.billingNotification.count()).toBe(1);
    await harness.app.get(BillingOutboxService).deliver(job.id, now);
    expect(await harness.prisma.billingNotification.count()).toBe(1);
    const paid = await call('receipts', 'POST', receiptInput(original.totalAmount, [{ invoiceId: original.id, amount: original.totalAmount }]));
    expect(paid.status).toBe(201);
    await reminders.enqueue(new Date('2026-10-27T03:00:00Z'), landlordId);
    expect(await harness.prisma.billingOutboxEvent.count({ where: { type: 'invoice.reminder' } })).toBe(1);
  });

  it('applies approved property service and tiered utility prices to preview and issue', async () => {
    const service = await propose();
    expect((await call(`tariffs/${service.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Approved by owner' })).status).toBe(201);
    const utility = await propose({ kind: 'ELECTRICITY', serviceKey: 'electricity', name: 'Electricity', unit: 'kWh', amount: 0, tiers: [{ upTo: 100, unitPrice: 2000 }, { upTo: null, unitPrice: 3000 }] });
    expect((await call(`tariffs/${utility.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Approved utility tariff' })).status).toBe(201);
    await harness.prisma.meterReading.create({ data: { roomId, utilityType: 'ELECTRICITY', billingMonth: new Date(month()), previousReading: 0, currentReading: 150, usage: 150, unitPrice: 1, amount: 150 } });
    const preview = await call('invoices/preview', 'POST', { leaseId, billingMonth: month() });
    expect(preview.status).toBe(201);
    expect(preview.json!.data.electricityAmount).toBe(350000);
    expect(preview.json!.data.otherAmount).toBe(100000);
    const issued = await invoice();
    expect(issued.totalAmount).toBe(preview.json!.data.totalAmount);
    expect(issued.lineItems.filter((line: { kind: string }) => line.kind === 'electricity')).toHaveLength(2);
    const later = await propose({ amount: 200000 });
    expect((await call(`tariffs/${later.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Too late' })).status).toBe(409);
  });

  it('deduplicates concurrent tariff proposals and serializes competing decisions', async () => {
    const requestKey = key();
    const [first, retry] = await Promise.all([propose({ requestKey }), propose({ requestKey })]);
    expect(first.id).toBe(retry.id);
    expect(await harness.prisma.billingTariffVersion.count({ where: { propertyId } })).toBe(1);
    const decisions = await Promise.all([
      call(`tariffs/${first.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Checked current rate' }),
      call(`tariffs/${first.id}/review`, 'POST', { requestKey: key(), decision: 'REJECTED', reason: 'Competing decision' }),
    ]);
    expect(decisions.map((result) => result.status).sort()).toEqual([201, 409]);
    const impact = await call(`tariffs/${first.id}/impact`);
    expect(impact.json!.data.canApprove).toBe(false);
    expect(impact.json!.data.blockingReasons).toContain('ALREADY_REVIEWED');
  });

  it('discloses room override exclusions and compares approved tariffs to their predecessor', async () => {
    const roomTariff = await propose({ roomId, amount: 175000 });
    expect((await call(`tariffs/${roomTariff.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Approved room rate' })).status).toBe(201);
    const propertyTariff = await propose();
    const impact = await call(`tariffs/${propertyTariff.id}/impact`);
    expect(impact.json!.data.rooms).toEqual([]);
    expect(impact.json!.data.overriddenRooms).toEqual([expect.objectContaining({ id: roomId })]);
    expect(impact.json!.data.canApprove).toBe(true);
    expect((await call(`tariffs/${propertyTariff.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Approved default rate' })).status).toBe(201);
    expect((await call(`tariffs/${propertyTariff.id}/impact`)).json!.data.previous).toBeNull();
    const next = await propose({ amount: 125000, effectiveFrom: month(1) });
    const nextImpact = await call(`tariffs/${next.id}/impact`);
    expect(nextImpact.json!.data.previous.id).toBe(propertyTariff.id);
    const preview = await call('invoices/preview', 'POST', { leaseId, billingMonth: month() });
    expect(preview.json!.data.lines).toEqual(expect.arrayContaining([
      expect.objectContaining({ kind: 'SERVICE', amount: 175000, source: 'ROOM_TARIFF' }),
    ]));
  });

  it('blocks stale effective-order previews without weakening the live review guard', async () => {
    const stale = await propose();
    const newer = await propose({ effectiveFrom: month(1) });
    expect((await call(`tariffs/${newer.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Approved future rate' })).status).toBe(201);
    const impact = await call(`tariffs/${stale.id}/impact`);
    expect(impact.json!.data.canApprove).toBe(false);
    expect(impact.json!.data.blockingReasons).toContain('EFFECTIVE_ORDER');
    expect((await call(`tariffs/${stale.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Stale browser attempt' })).status).toBe(409);
  });

  it('blocks invoice issuance and tariff activation for locked periods', async () => {
    const proposal = await propose();
    expect((await call('period-locks', 'POST', { requestKey: key(), propertyId, month: month(), reason: 'Period close' })).status).toBe(201);
    expect((await call(`tariffs/${proposal.id}/review`, 'POST', { requestKey: key(), decision: 'APPROVED', reason: 'Locked period' })).status).toBe(409);
    expect((await call('invoices', 'POST', { leaseId, billingMonth: month() })).status).toBe(409);
  });

  it('reconciles a bank transfer to its full receipt, not the individual invoice allocations', async () => {
    const first = await invoice(), second = await invoice(-1);
    const amount = first.totalAmount + second.totalAmount + 50000;
    const created = await call('receipts', 'POST', receiptInput(amount, [{ invoiceId: first.id, amount: first.totalAmount }, { invoiceId: second.id, amount: second.totalAmount }]));
    expect(created.status).toBe(201);
    const receipt = created.json!.data;
    const actor = await financeActor();
    const finance = harness.app.get(FinanceReconciliationService);
    const input = { propertyId, accountKey: 'billing-account', importKey: key(), reason: 'Verified bank transfer receipt', lines: [{ externalId: key(), amount, occurredAt: receipt.paidAt, reference: receipt.id }] };
    expect((await finance.importStatement(actor, input)).data).toMatchObject({ matched: 1, unmatched: 0 });
    expect((await finance.importStatement(actor, input)).data.duplicate).toBe(true);
    const line = await harness.prisma.financeStatementLine.findFirstOrThrow();
    expect(line.receiptId).toBe(receipt.id);
    expect(line.paymentId).toBeNull();
    expect(await harness.prisma.payment.count()).toBe(2);
    const partial = await finance.importStatement(actor, { ...input, importKey: key(), lines: [{ externalId: key(), amount: first.totalAmount, occurredAt: receipt.paidAt, reference: receipt.allocations[0].paymentId }] });
    expect(partial.data).toMatchObject({ matched: 0, unmatched: 1 });
    const original = await harness.prisma.billingReceipt.findUniqueOrThrow({ where: { id: receipt.id } });
    expect(original.availableAmount).toBe(50000);
  });

  it('requires a separate checker and revalidates receipt uniqueness during reconciliation approval', async () => {
    const created = await call('receipts', 'POST', receiptInput(100000));
    expect(created.status).toBe(201);
    const receipt = created.json!.data;
    const maker = await financeActor(), checker = await financeActor();
    const finance = harness.app.get(FinanceReconciliationService);
    await finance.importStatement(maker, { propertyId, accountKey: 'manual-account', importKey: key(), reason: 'Manual bank receipt review', lines: [1, 2].map(() => ({ externalId: key(), amount: 100000, occurredAt: receipt.paidAt, reference: 'Manual review' })) });
    const lines = await harness.prisma.financeStatementLine.findMany();
    const first = await finance.propose(maker, lines[0].id, { action: 'MATCH_RECEIPT', lineVersion: 1, receiptId: receipt.id, reason: 'Receipt identity confirmed' });
    const second = await finance.propose(maker, lines[1].id, { action: 'MATCH_RECEIPT', lineVersion: 1, receiptId: receipt.id, reason: 'Competing receipt proposal' });
    await expect(finance.review(maker, first.data.id, { version: 1, reason: 'Self approval must fail' }, true)).rejects.toThrow('Maker cannot approve own proposal.');
    const approved = await finance.review(checker, first.data.id, { version: 1, reason: 'Checked against bank statement' }, true);
    expect(approved.data).toHaveProperty('line.receiptId', receipt.id);
    await expect(finance.review(checker, second.data.id, { version: 1, reason: 'Already matched elsewhere' }, true)).rejects.toThrow('already matched');
    const unmatch = await finance.propose(maker, lines[0].id, { action: 'UNMATCH', lineVersion: 2, reason: 'Correct the bank line association' });
    await finance.review(checker, unmatch.data.id, { version: 2, reason: 'Association correction approved' }, true);
    expect((await harness.prisma.financeStatementLine.findUniqueOrThrow({ where: { id: lines[0].id } })).receiptId).toBeNull();
    expect(await harness.prisma.billingReceipt.count()).toBe(1);
  });

  it('assigns only active landlord staff and keeps a custom SLA when editing unchanged priority', async () => {
    const worker = await harness.prisma.user.create({ data: { fullName: 'Maintenance staff', email: `${key()}@example.test`, passwordHash: 'not-for-login', role: 'STAFF' } });
    const staff = await harness.prisma.staffProfile.create({ data: { userId: worker.id, landlordId, fullName: 'Maintenance staff', permissions: ['maintenance.manage'], propertyScopes: { create: { landlordId, propertyId } } } });
    const dueAt = '2026-12-01T10:00:00.000Z';
    const result = await maintenance('', 'POST', { propertyId, roomId, title: 'Repair water leak', priority: 'urgent', assigneeStaffProfileId: staff.id, dueAt });
    expect(result.status).toBe(201);
    expect(result.json!.data).toMatchObject({ assigneeStaffProfileId: staff.id, assigneeName: staff.fullName, dueAt });
    expect((await maintenance(`/${result.json!.data.id}`, 'PATCH', { priority: 'urgent', note: 'Same deadline' })).json!.data.dueAt).toBe(dueAt);
    await harness.prisma.staffProfile.update({ where: { id: staff.id }, data: { isActive: false } });
    expect((await maintenance(`/${result.json!.data.id}`, 'PATCH', { assigneeStaffProfileId: staff.id })).status).toBe(404);
  });

  it('defaults SLA by priority and escalates each overdue deadline once under concurrency', async () => {
    const reportedAt = '2026-01-01T00:00:00Z';
    for (const [priority, hours] of [['urgent', 4], ['medium', 48], ['low', 168]] as const) {
      const created = await maintenance('', 'POST', { propertyId, roomId, title: `Repair ${priority}`, priority, reportedAt });
      expect(created.status).toBe(201);
      expect(new Date(created.json!.data.dueAt).getTime()).toBe(new Date(reportedAt).getTime() + hours * 3600000);
    }
    const sla = harness.app.get(MaintenanceSlaService);
    await Promise.all([sla.escalate(landlordId), sla.escalate(landlordId)]);
    expect(await harness.prisma.auditLog.count({ where: { action: 'maintenance.sla_escalated' } })).toBe(3);
    expect((await sla.escalate(landlordId)).data.escalated).toBe(0);
  });

  it('links exactly one repair expense when completion is retried concurrently', async () => {
    const created = await maintenance('', 'POST', { propertyId, roomId, title: 'Fix drain' });
    expect(created.status).toBe(201);
    const id = created.json!.data.id;
    const results = await Promise.all([1, 2].map(() => maintenance(`/${id}/complete`, 'POST', { actualCost: 250000, createExpense: true })));
    expect(results.map(result => result.status)).toEqual([201, 201]);
    expect(await harness.prisma.expense.count({ where: { landlordId } })).toBe(1);
    expect(results[0].json!.data.expenseId).toBe(results[1].json!.data.expenseId);
    expect((await maintenance(`/${id}`, 'PATCH', { actualCost: 500000 })).status).toBe(409);
  });

  it('passes the release readiness gate with the actual migrated columns and immutable/SLA triggers', async () => {
    const readiness = await harness.app.get(SchemaReadinessService).inspect();
    expect(readiness).toMatchObject({ ready: true, authSchemaReady: true, billingSchemaReady: true, missing: [], drifted: [], failed: [], unexpected: [] });
  });
});
