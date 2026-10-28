import * as argon2 from 'argon2';

import { businessMonth } from '../../src/rooms/service-tariff';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase, testPassword, uniqueEmail } from './e2e-fixtures';

describe('Invoice lines and service tariffs (disposable database)', () => {
  let harness: E2eHarness;
  let token: string;
  let roomId: string;
  let tenantId: string;
  let propertyId: string;
  let leaseId: string;
  const month = (offset = 0) => {
    const current = businessMonth();
    return new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth() + offset, 1)).toISOString().slice(0, 10);
  };
  const fees = () => `/api/v1/rooms/${roomId}/service-fees`;
  const call = (path: string, method = 'GET', body?: unknown, accessToken = token) => requestJson(harness.baseUrl, path, { method, body, token: accessToken });
  const addFee = async (effectiveFrom = month()) => {
    const response = await call(fees(), 'POST', { name: 'Internet', amount: 100_000, unit: 'thang', effectiveFrom });
    expect(response.status).toBe(201);
    return response.json!.data;
  };
  const invoice = async (billingMonth = month()) => {
    const response = await call('/api/v1/billing/invoices', 'POST', { leaseId, billingMonth });
    expect(response.status).toBe(201);
    return response.json!.data;
  };

  beforeAll(async () => {
    const name = new URL(process.env.DATABASE_URL!).pathname.slice(1);
    if (process.env.NODE_ENV !== 'test' || !/^rental_(invoice|billing)_test_\d+_[a-f0-9]+$/.test(name)) {
      throw new Error('Use scripts/run-invoice-tariffs-e2e.mjs with its disposable database.');
    }
  });
  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    token = (await registerLandlord(harness.baseUrl, 'invoice-tariffs')).accessToken;
    propertyId = (await createProperty(harness.baseUrl, token)).id;
    roomId = (await createRoom(harness.baseUrl, token, propertyId)).id;
    tenantId = (await createTenant(harness.baseUrl, token)).id;
    leaseId = (await createLease(harness.baseUrl, token, roomId, tenantId)).id;
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); });

  it('stores atomic line snapshots and never reprices issued invoices', async () => {
    const fee = await addFee();
    const created = await call('/api/v1/billing/invoices', 'POST', {
      leaseId, billingMonth: month(), otherAmount: 20_000,
      meterReadings: [{ utilityType: 'electricity', previousReading: 10, currentReading: 30, unitPrice: 3_500 }],
    });
    expect(created.status).toBe(201);
    const original = created.json!.data;
    expect(original.lineItems).toHaveLength(4);
    expect(original.totalAmount).toBe(3_690_000);
    expect(original.lineItems.reduce((sum: number, line: { amount: number }) => sum + line.amount, 0)).toBe(original.totalAmount);
    expect(original.lineItems.find((line: { kind: string }) => line.kind === 'electricity')).toMatchObject({ quantity: 20, unitPrice: 3_500, amount: 70_000 });
    const update = await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 150_000, effectiveFrom: month(1), expectedVersion: 1 });
    expect(update.status).toBe(200);
    expect(update.json!.data.version).toBe(2);
    const unchanged = await call(`/api/v1/billing/invoices/${original.id}`);
    expect(unchanged.json!.data.lineItems).toEqual(original.lineItems);
    const next = await invoice(month(1));
    expect(next.lineItems.find((line: { kind: string }) => line.kind === 'service')).toMatchObject({ amount: 150_000, tariffVersion: 2 });
    const history = await call(`${fees()}/${fee.id}/versions`);
    expect(history.json!.data).toHaveLength(2);
  });

  it('uses the same effective tariffs in preflight, bulk and single creation, including retries', async () => {
    const fee = await addFee(month(1));
    const current = await call('/api/v1/billing/invoices/bulk/preflight', 'POST', { propertyId, billingMonth: month() });
    expect(current.json!.data.items[0].fixedFeeAmount).toBe(0);
    const next = await call('/api/v1/billing/invoices/bulk/preflight', 'POST', { propertyId, billingMonth: month(1) });
    expect(next.json!.data.items[0].fixedFeeAmount).toBe(100_000);
    expect((await call(`/api/v1/billing/active-leases?month=${month()}`)).json!.data[0].fixedFeeAmount).toBe(0);
    expect((await call(`/api/v1/billing/active-leases?month=${month(1)}`)).json!.data[0].fixedFeeAmount).toBe(100_000);
    const single = await invoice();
    expect(single.lineItems.some((line: { kind: string }) => line.kind === 'service')).toBe(false);
    const bulk = await call('/api/v1/billing/invoices/bulk', 'POST', { propertyId, billingMonth: month(1) });
    expect(bulk.status).toBe(201);
    expect(bulk.json!.data.results[0].invoice.lineItems.find((line: { kind: string }) => line.kind === 'service')).toMatchObject({ sourceId: fee.id, tariffVersion: 1, amount: 100_000 });
    const retry = await call('/api/v1/billing/invoices/bulk', 'POST', { propertyId, billingMonth: month(1) });
    expect(retry.json!.data.existingCount).toBe(1);
    expect(await harness.prisma.invoice.count()).toBe(2);
  });

  it('schedules fee retirement without deleting historical charges', async () => {
    const fee = await addFee();
    expect((await call(`${fees()}/${fee.id}`, 'DELETE')).status).toBe(204);
    const current = await invoice();
    const next = await invoice(month(1));
    expect(current.otherAmount).toBe(100_000);
    expect(next.otherAmount).toBe(0);
    expect(await harness.prisma.serviceTariffVersion.count({ where: { serviceFeeId: fee.id } })).toBe(2);
  });

  it('rejects retroactive, duplicate, stale, blank and already-invoiced changes', async () => {
    expect((await call(fees(), 'POST', { name: 'Past', amount: 1, effectiveFrom: month(-1) })).status).toBe(400);
    expect((await call(fees(), 'POST', { name: '   ', amount: 1 })).status).toBe(400);
    const fee = await addFee();
    expect((await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 2, effectiveFrom: month() })).status).toBe(409);
    expect((await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 2, expectedVersion: 5 })).status).toBe(409);
    await invoice(month(1));
    const blocked = await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 2, effectiveFrom: month(1) });
    expect(blocked.status).toBe(409);
    expect(blocked.json!.error.code).toBe('TARIFF_PERIOD_INVOICED');
    expect((await call(fees(), 'POST', { name: 'New', amount: 2, effectiveFrom: month() })).status).toBe(409);
    expect(await harness.prisma.serviceTariffVersion.count()).toBe(1);
  });

  it('serializes concurrent tariff edits and rejects stale versions', async () => {
    const fee = await addFee();
    const responses = await Promise.all([120_000, 150_000].map((amount) => call(`${fees()}/${fee.id}`, 'PATCH', { amount, effectiveFrom: month(1), expectedVersion: 1 })));
    expect(responses.map((response) => response.status).sort()).toEqual([200, 409]);
    expect(await harness.prisma.serviceTariffVersion.count()).toBe(2);
  });

  it('blocks legacy tariff creation and version changes across a locked period', async () => {
    const fee = await addFee();
    await harness.prisma.billingPeriodLock.create({ data: { propertyId, month: new Date(month(1)), actorId: (await harness.prisma.property.findUniqueOrThrow({ where: { id: propertyId } })).landlordId, reason: 'Closed period' } });
    for (const [path, method, input] of [
      [fees(), 'POST', { name: 'Water service', amount: 1, effectiveFrom: month(1) }],
      [`${fees()}/${fee.id}`, 'PATCH', { amount: 2, effectiveFrom: month(1), expectedVersion: 1 }],
    ] as const) {
      const response = await call(path, method, input);
      expect(response.status).toBe(409);
      expect(response.json!.error.code).toBe('TARIFF_PERIOD_CLOSED');
    }
    expect(await harness.prisma.serviceTariffVersion.count()).toBe(1);
    expect((await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 2, effectiveFrom: month(2), expectedVersion: 1 })).status).toBe(200);
  });

  it('enforces ownership and exposes identical line snapshots to the tenant', async () => {
    const fee = await addFee();
    const created = await invoice();
    const foreignUser = await harness.prisma.user.create({ data: { fullName: 'Foreign', email: uniqueEmail('foreign-tariff'), passwordHash: await argon2.hash(testPassword), role: 'LANDLORD' } });
    const foreign = await login(harness.baseUrl, foreignUser.email);
    expect((await call(`${fees()}/${fee.id}/versions`, 'GET', undefined, foreign.accessToken)).status).toBe(404);
    expect((await call(`${fees()}/${fee.id}`, 'PATCH', { amount: 1 }, foreign.accessToken)).status).toBe(404);
    const user = await harness.prisma.user.create({ data: { fullName: 'Tenant', email: uniqueEmail('tariff-tenant'), passwordHash: await argon2.hash(testPassword), role: 'TENANT' } });
    await harness.prisma.tenant.update({ where: { id: tenantId }, data: { userId: user.id } });
    const tenant = await login(harness.baseUrl, user.email);
    const visible = await call(`/api/v1/tenant/invoices/${created.id}`, 'GET', undefined, tenant.accessToken);
    expect(visible.status).toBe(200);
    expect(visible.json!.data.lineItems).toEqual(created.lineItems);
    expect((await call(fees(), 'GET', undefined, tenant.accessToken)).status).toBe(403);
  });

  it('rejects database-level mutations of published snapshots', async () => {
    const fee = await addFee();
    const created = await invoice();
    await expect(harness.prisma.serviceTariffVersion.update({ where: { id: fee.versions[0].id }, data: { amount: 1 } })).rejects.toThrow('immutable');
    await expect(harness.prisma.invoiceLineItem.update({ where: { id: created.lineItems[0].id }, data: { amount: 1, unitPrice: 1 } })).rejects.toThrow('immutable');
    const metadata = await call(`/api/v1/billing/invoices/${created.id}`, 'PATCH', { note: 'Confirmed delivery' });
    expect(metadata.status).toBe(200);
    expect(metadata.json!.data.lineItems).toEqual(created.lineItems);
  });
});
