import { randomUUID } from 'node:crypto';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Move-out settlement E2E (isolated database only)', () => {
  let harness: E2eHarness;
  let token: string;
  let leaseId: string;
  let roomId: string;

  const input = {
    moveOutDate: '2026-08-15', finalElectricity: 110, electricityUnitPrice: 3_000,
    finalWater: 12, waterUnitPrice: 10_000,
    lines: [{ kind: 'CLEANING', description: 'Move-out cleaning', amount: 50_000 }],
    note: 'Tenant move-out and final deposit reconciliation',
  };

  beforeAll(async () => {
    const name = decodeURIComponent(new URL(process.env.DATABASE_URL!).pathname.slice(1));
    if (process.env.NODE_ENV !== 'test' || !/^rental_settlement_test_\d+_[a-f0-9]+$/.test(name)) {
      throw new Error('Use scripts/run-settlement-e2e.mjs with its disposable database.');
    }
  });

  afterEach(async () => {
    if (harness) await closeE2eHarness(harness);
  });

  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const landlord = await registerLandlord(harness.baseUrl, 'settlement');
    token = landlord.accessToken;
    const property = await createProperty(harness.baseUrl, token);
    const room = await createRoom(harness.baseUrl, token, property.id);
    const tenant = await createTenant(harness.baseUrl, token);
    const lease = await createLease(harness.baseUrl, token, room.id, tenant.id, 1_550_000);
    leaseId = lease.id;
    roomId = room.id;
    await harness.prisma.leaseHandover.create({ data: {
      leaseId, electricity: 100, water: 10, condition: 'Good condition', imageUrls: [],
    } });
  });

  const request = (action: string, body?: unknown, auth?: string) => requestJson(
    harness.baseUrl, `/api/v1/leases/${leaseId}/settlement${action ? `/${action}` : ''}`,
    { method: body === undefined ? 'GET' : 'POST', token: auth ?? token, body },
  );

  async function confirm() {
    const preview = await request('preview', input);
    expect(preview.status).toBe(201);
    const confirmation = { ...input, previewFingerprint: preview.json!.data.previewFingerprint, idempotencyKey: randomUUID() };
    const result = await request('confirm', confirmation);
    expect(result.status).toBe(201);
    return { confirmation, result };
  }

  it('settles a lease, starts turnover, and records the actual refund exactly once', async () => {
    expect((await request('')).json!.data).toBeNull();
    const { confirmation, result } = await confirm();
    expect(result.json!.data).toMatchObject({ rentAmount: 750_000, electricityAmount: 30_000,
      waterAmount: 20_000, otherCharges: 50_000, totalCharges: 850_000,
      depositBalance: 1_000_000, depositApplied: 850_000, refundAmount: 150_000,
      balanceDue: 0, refundStatus: 'PENDING', version: 1 });
    expect(result.json!.data).not.toHaveProperty('requestKey');
    expect(await harness.prisma.lease.findUnique({ where: { id: leaseId } })).toMatchObject({ status: 'ENDED' });
    expect(await harness.prisma.room.findUnique({ where: { id: roomId } })).toMatchObject({ status: 'MAINTENANCE' });
    expect(await harness.prisma.roomTurnover.count({ where: { roomId, leaseId, status: 'ACTIVE' } })).toBe(1);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId, type: 'DEDUCTED' } })).toBe(1);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId, type: 'REFUNDED' } })).toBe(0);

    const repeated = await request('confirm', confirmation);
    expect(repeated.status).toBe(201);
    expect(repeated.json!.idempotent).toBe(true);
    expect(repeated.json!.data.id).toBe(result.json!.data.id);
    expect((await request('confirm', { ...confirmation, note: 'Changed intent must not be accepted' })).status).toBe(409);

    const refund = { version: 1, idempotencyKey: randomUUID(), reference: 'BANK-RECEIPT-123', reason: 'Tenant confirmed receipt of refund' };
    expect((await request('refund', { ...refund, version: 2 })).status).toBe(409);
    const recorded = await request('refund', refund);
    expect(recorded.status).toBe(201);
    expect(recorded.json!.data).toMatchObject({ refundStatus: 'PAID', version: 2, refundReference: refund.reference });
    expect((await request('refund', refund)).json!.idempotent).toBe(true);
    expect((await request('refund', { ...refund, idempotencyKey: randomUUID() })).status).toBe(409);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId, type: 'REFUNDED' } })).toBe(1);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: leaseId, action: 'lease.settlement_confirm' } })).toBe(1);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: leaseId, action: 'lease.settlement_refund_recorded' } })).toBe(1);
  });

  it('rejects a stale preview without persisting any settlement or turnover', async () => {
    const preview = await request('preview', input);
    const extraDeposit = await requestJson(harness.baseUrl, `/api/v1/leases/${leaseId}/deposits`, {
      token, method: 'POST', body: { type: 'collected', amount: 100_000 },
    });
    expect(extraDeposit.status).toBe(201);
    const result = await request('confirm', { ...input, previewFingerprint: preview.json!.data.previewFingerprint, idempotencyKey: randomUUID() });
    expect(result.status).toBe(409);
    expect(await harness.prisma.leaseSettlement.count()).toBe(0);
    expect(await harness.prisma.roomTurnover.count()).toBe(0);
    expect(await harness.prisma.lease.findUnique({ where: { id: leaseId } })).toMatchObject({ status: 'ACTIVE' });
  });

  it('prevents post-settlement edits, renewals and manual deposit changes', async () => {
    await confirm();
    const calls = [
      { path: '', method: 'PATCH', body: { monthlyRent: 2_000_000 } },
      { path: '/renew', method: 'POST', body: { endDate: '2027-08-01', note: 'Renew after settlement' } },
      { path: '/deposits', method: 'POST', body: { type: 'refunded', amount: 1 } },
    ];
    for (const call of calls) {
      const response = await requestJson(harness.baseUrl, `/api/v1/leases/${leaseId}${call.path}`, { token, ...call });
      expect(response.status).toBe(409);
    }
  });

  it('does not charge rent already present on a non-demo invoice', async () => {
    const invoice = await requestJson(harness.baseUrl, '/api/v1/billing/invoices', {
      token, method: 'POST', body: { leaseId, billingMonth: '2026-08-01', otherAmount: 0 },
    });
    expect(invoice.status).toBe(201);
    const preview = await request('preview', input);
    expect(preview.status).toBe(201);
    expect(preview.json!.data).toMatchObject({ monthAlreadyBilled: true, rentAmount: 0,
      outstandingInvoiceAmount: 1_550_000, depositApplied: 100_000, refundAmount: 900_000 });
  });

  it('rolls back settlement and deposit deductions if turnover creation fails', async () => {
    const room = await harness.prisma.room.findUniqueOrThrow({ where: { id: roomId }, include: { property: true } });
    await harness.prisma.roomTurnover.create({ data: { landlordId: room.property.landlordId, propertyId: room.propertyId, roomId, leaseId } });
    const preview = await request('preview', input);
    const result = await request('confirm', { ...input, previewFingerprint: preview.json!.data.previewFingerprint, idempotencyKey: randomUUID() });
    expect(result.status).toBe(409);
    expect(await harness.prisma.leaseSettlement.count()).toBe(0);
    expect(await harness.prisma.depositTransaction.count({ where: { type: 'DEDUCTED' } })).toBe(0);
    expect(await harness.prisma.lease.findUnique({ where: { id: leaseId } })).toMatchObject({ status: 'ACTIVE' });
  });

  it('enforces ownership and DTO validation over HTTP', async () => {
    const other = await registerLandlord(harness.baseUrl, 'other-owner');
    expect((await request('', undefined, other.accessToken)).status).toBe(404);
    expect((await request('preview', input, other.accessToken)).status).toBe(404);
    expect((await request('preview', { ...input, finalWater: -1 })).status).toBe(400);
    expect((await request('confirm', { ...input, idempotencyKey: 'bad', previewFingerprint: 'bad' })).status).toBe(400);
    expect((await request('refund', { version: 1, idempotencyKey: randomUUID(), reference: '   ', reason: '          ' })).status).toBe(400);
  });

  it('cannot create an invoice from stale lease state during settlement', async () => {
    const preview = await request('preview', input);
    const confirmation = { ...input, previewFingerprint: preview.json!.data.previewFingerprint, idempotencyKey: randomUUID() };
    const responses = await Promise.all([
      request('confirm', confirmation),
      requestJson(harness.baseUrl, '/api/v1/billing/invoices', {
        token, method: 'POST', body: { leaseId, billingMonth: '2026-08-01' },
      }),
    ]);
    const statuses = responses.map(response => response.status);
    expect(statuses.filter((status) => status === 201)).toHaveLength(1);
    expect(statuses.filter((status) => status === 409)).toHaveLength(1);
    const settlements = await harness.prisma.leaseSettlement.count({ where: { leaseId } });
    const invoices = await harness.prisma.invoice.count({ where: { leaseId } });
    expect(settlements + invoices).toBe(1);
  });

  it('cannot double-record concurrent refunds', async () => {
    await confirm();
    const refund = { version: 1, idempotencyKey: randomUUID(), reference: 'BANK-CONCURRENT', reason: 'Tenant received this refund' };
    const responses = await Promise.all([request('refund', refund), request('refund', refund)]);
    expect(responses.some(response => response.status === 201)).toBe(true);
    expect(responses.every(response => [201, 409].includes(response.status))).toBe(true);
    const retried = await request('refund', refund);
    expect(retried.status).toBe(201);
    expect(retried.json!.idempotent).toBe(true);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId, type: 'REFUNDED' } })).toBe(1);
  });
});
