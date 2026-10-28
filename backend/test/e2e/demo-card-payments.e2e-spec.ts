import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';
import { OnlinePaymentsService } from '../../src/billing/online-payments.service';

describe('Internal demo card checkout E2E', () => {
  let harness: E2eHarness;
  let owner: Awaited<ReturnType<typeof registerLandlord>>;
  let lease: any;
  let tenant: any;
  let token: string;
  let otherToken: string;
  let month = 0;
  const original = { ...process.env };
  const card = { cardNumber: '4242 4242 4242 4242', expiry: '12/99', cvc: '123' };
  const api = (path: string, init: { method?: string; token?: string; body?: unknown; headers?: Record<string, string> } = {}) => requestJson(harness.baseUrl, `/api/v1${path}`, { token, ...init });
  const fixture = (isDemo = true, paidAmount = 0, status: 'UNPAID' | 'PARTIAL' | 'PAID' | 'CANCELLED' = 'UNPAID') => harness.prisma.invoice.create({ data: {
    roomId: lease.roomId, leaseId: lease.id, tenantId: tenant.id,
    billingMonth: new Date(Date.UTC(2030, month++, 1)), isDemo, rentAmount: 10000, totalAmount: 10000, paidAmount, status,
  } });
  const create = async (invoiceId: string) => {
    const result = await api(`/tenant/invoices/${invoiceId}/payment-link`, { method: 'POST' });
    expect(result.status).toBe(201);
    return result.json!.data;
  };
  const pathOf = (link: any) => new URL(link.checkoutUrl).pathname.replace('/api/v1', '');

  beforeAll(async () => {
    process.env.DEMO_PAYMENTS_ENABLED = 'true';
    process.env.DEMO_CHECKOUT_SECRET = 'e2e-only-demo-checkout-signing-key-not-real';
    process.env.DEMO_PAYMENT_BASE_URL = 'http://localhost:3000';
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    owner = await registerLandlord(harness.baseUrl, 'demo-card-owner');
    const property = await createProperty(harness.baseUrl, owner.accessToken);
    const room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    tenant = await createTenant(harness.baseUrl, owner.accessToken);
    lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const jwt = new JwtService({ secret: harness.app.get(ConfigService).getOrThrow('JWT_ACCESS_SECRET') });
    const user = await harness.prisma.user.create({ data: { email: `${randomUUID()}@example.com`, fullName: 'Demo tenant', passwordHash: 'unused', role: 'TENANT' } });
    await harness.prisma.tenant.update({ where: { id: tenant.id }, data: { userId: user.id } });
    token = jwt.sign({ sub: user.id, typ: 'access', ver: 0 });
    const other = await harness.prisma.user.create({ data: { email: `${randomUUID()}@example.com`, fullName: 'Other tenant', passwordHash: 'unused', role: 'TENANT' } });
    otherToken = jwt.sign({ sub: other.id, typ: 'access', ver: 0 });
  });
  afterAll(async () => {
    if (harness) await closeE2eHarness(harness);
    process.env = original;
  });

  it('exposes status without creating a session', async () => {
    const invoice = await fixture();
    const response = await api(`/tenant/invoices/${invoice.id}/payment-link`);
    expect(response.json!.data).toMatchObject({ provider: 'DEMO_CARD', demo: true, status: 'NOT_CREATED', canCreateLink: true, canPay: false });
    expect(await harness.prisma.demoCheckoutSession.count()).toBe(0);
  });
  it('enforces invoice ownership and never accepts demo payment for a real invoice', async () => {
    const invoice = await fixture(false);
    expect((await api(`/tenant/invoices/${invoice.id}/payment-link`, { token: otherToken, method: 'POST' })).status).toBe(404);
    expect((await api(`/tenant/invoices/${invoice.id}/payment-link`, { method: 'POST' })).status).toBe(409);
    expect((await api(`/tenant/invoices/${invoice.id}/demo-invoice`, { token: otherToken, method: 'POST' })).status).toBe(404);
    const source = await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } });
    const copy = await api(`/tenant/invoices/${invoice.id}/demo-invoice`, { method: 'POST' });
    expect(copy.status).toBe(201);
    expect(copy.json!.data).toMatchObject({ isDemo: true });
    expect(copy.json!.data.id).not.toBe(invoice.id);
    expect(await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).toEqual(source);
  });
  it('requires opt in and blocks production even if configured', async () => {
    const invoice = await fixture();
    for (const mode of ['disabled', 'production']) {
      if (mode === 'disabled') process.env.DEMO_PAYMENTS_ENABLED = 'false';
      else { process.env.DEMO_PAYMENTS_ENABLED = 'true'; process.env.NODE_ENV = 'production'; }
      try { expect((await api(`/tenant/invoices/${invoice.id}/payment-link`, { method: 'POST' })).status).toBe(503); }
      finally { process.env.DEMO_PAYMENTS_ENABLED = 'true'; process.env.NODE_ENV = 'test'; }
    }
  });
  it('creates one reusable session without storing the bearer token or bank details', async () => {
    const invoice = await fixture();
    const [first, second] = await Promise.all([create(invoice.id), create(invoice.id)]);
    expect(first.checkoutUrl).toBe(second.checkoutUrl);
    expect(first.qrCode).toBe(first.checkoutUrl);
    const saved = await harness.prisma.paymentLink.findUniqueOrThrow({ where: { id: first.id }, include: { demoSession: true } });
    expect(saved.demoSession!.tokenHash).toHaveLength(64);
    expect(saved.checkoutUrl).toBeNull();
    expect(saved.qrCode).toBeNull();
    expect(JSON.stringify(saved)).not.toContain(new URL(first.checkoutUrl).pathname.split('/').pop());
  });
  it('GET checkout cannot settle an invoice from query parameters and needs no inline script', async () => {
    const invoice = await fixture();
    const link = await create(invoice.id);
    const response = await api(`${pathOf(link)}?status=PAID&amount=1`);
    expect(response.status).toBe(200);
    expect(response.text).toContain('Môi trường kiểm thử — không thu tiền thật.');
    expect(response.text).toContain('method="post"');
    expect(response.text).not.toContain('<script');
    expect(response.response.headers.get('cache-control')).toBe('no-store');
    expect(response.response.headers.get('referrer-policy')).toBe('no-referrer');
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(0);
  });
  it('rejects invalid cards, expired dates, arbitrary tokens and cross-origin browser submissions', async () => {
    const invoice = await fixture();
    const link = await create(invoice.id);
    const confirm = `${pathOf(link)}/confirm`;
    expect((await api(confirm, { method: 'POST', body: { ...card, cardNumber: '5555555555554444' } })).status).toBe(400);
    expect((await api(confirm, { method: 'POST', body: { ...card, expiry: '01/20' } })).status).toBe(400);
    expect((await api(confirm, { method: 'POST', body: card, headers: { origin: 'https://evil.example', 'sec-fetch-site': 'cross-site' } })).status).toBe(403);
    expect((await api(confirm, { method: 'POST', body: card, headers: { origin: 'null', 'sec-fetch-site': 'cross-site' } })).status).toBe(403);
    expect((await api(confirm, { method: 'POST', body: card, headers: { origin: 'not-a-url' } })).status).toBe(403);
    expect((await api(`/payments/demo/checkout/${'x'.repeat(43)}/confirm`, { method: 'POST', body: card })).status).toBe(404);
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(0);
  });
  it('concurrent confirmations settle once and store only Visa last4', async () => {
    const invoice = await fixture();
    const link = await create(invoice.id);
    const results = await Promise.all([1, 2, 3].map(() => api(`${pathOf(link)}/confirm`, { method: 'POST', body: card })));
    expect(results.map(result => result.status)).toEqual([200, 200, 200]);
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(1);
    expect(await harness.prisma.paymentWebhookEvent.count({ where: { paymentLinkId: link.id } })).toBe(1);
    const session = await harness.prisma.demoCheckoutSession.findUniqueOrThrow({ where: { paymentLinkId: link.id } });
    expect(session).toMatchObject({ status: 'PAID', cardBrand: 'VISA', cardLast4: '4242' });
    expect(JSON.stringify(session)).not.toContain('4242424242424242');
    const state = (await api(`/tenant/invoices/${invoice.id}/payment-link`)).json!.data;
    expect(state).toMatchObject({ status: 'PAID', canPay: false, canCreateLink: false, invoice: { remainingAmount: 0, status: 'PAID' } });
    expect((await api(`/tenant/invoices/${invoice.id}/payment-link`, { method: 'POST' })).status).toBe(409);
  });
  it('supports no-referrer native form POST with an opaque Origin and no browser JavaScript', async () => {
    const invoice = await fixture();
    const link = await create(invoice.id);
    const response = await fetch(new URL(`${pathOf(link)}/confirm`.replace(/^/, '/api/v1'), harness.baseUrl), {
      method: 'POST', body: new URLSearchParams(card), headers: { 'content-type': 'application/x-www-form-urlencoded', origin: 'null' },
    });
    expect(response.status).toBe(200);
    expect(await response.text()).toContain('Thanh toán đã hoàn tất');
  });
  it('rejects stale balances, cancelled and expired sessions even without prior polling', async () => {
    for (const reason of ['balance', 'cancelled', 'expired']) {
      const invoice = await fixture();
      const link = await create(invoice.id);
      if (reason === 'balance') await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { paidAmount: 1000, status: 'PARTIAL' } });
      if (reason === 'cancelled') await harness.prisma.paymentLink.update({ where: { id: link.id }, data: { status: 'CANCELLED' } });
      if (reason === 'expired') await harness.prisma.demoCheckoutSession.update({ where: { paymentLinkId: link.id }, data: { expiresAt: new Date(0) } });
      const checkoutToken = new URL(link.checkoutUrl).pathname.split('/').pop()!;
      await expect(harness.app.get(OnlinePaymentsService).confirmDemo(checkoutToken, card)).rejects.toThrow();
      expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(0);
    }
  });
  it('expires a stale QR, shows the remaining balance and does not recreate a paid invoice', async () => {
    const invoice = await fixture(true, 4000, 'PARTIAL');
    const link = await create(invoice.id);
    expect(link.amount).toBe(6000);
    await harness.prisma.paymentLink.update({ where: { id: link.id }, data: { expiresAt: new Date(0) } });
    const state = (await api(`/tenant/invoices/${invoice.id}/payment-link`)).json!.data;
    expect(state).toMatchObject({ status: 'EXPIRED', canPay: false, canCreateLink: true, invoice: { remainingAmount: 6000 } });
  });
  it('isolates simulated balances from landlord financial reports', async () => {
    const now = new Date();
    const period = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
    const stable = (value: unknown): unknown => {
      if (Array.isArray(value)) return value.map(stable);
      if (!value || typeof value !== 'object') return value;
      return Object.fromEntries(Object.entries(value as Record<string, unknown>)
        .filter(([key]) => key !== 'generatedAt')
        .map(([key, child]) => [key, stable(child)]));
    };
    const snapshots = async () => {
      const [report, dashboard, tenantDashboard, reminders, tenantNotifications, collection] = await Promise.all([
        api(`/reports/monthly?month=${period}`, { token: owner.accessToken }),
        api('/dashboard/metrics', { token: owner.accessToken }),
        api('/tenant/dashboard'),
        api('/billing/reminders', { token: owner.accessToken }),
        api('/tenant/notifications'),
        api('/billing/invoices', { token: owner.accessToken }),
      ]);
      for (const result of [report, dashboard, tenantDashboard, reminders, tenantNotifications, collection]) expect(result.status).toBe(200);
      const { count, ...financialSummary } = collection.json!.summary;
      return stable({ report: report.json!.data.summary, dashboard: dashboard.json, tenantDashboard: tenantDashboard.json,
        reminders: reminders.json, tenantNotifications: tenantNotifications.json, financialSummary });
    };
    const before = await snapshots();
    const invoice = await fixture();
    await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { billingMonth: new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)), dueDate: new Date(0) } });
    expect(await snapshots()).toEqual(before);
    const link = await create(invoice.id);
    const checkoutToken = new URL(link.checkoutUrl).pathname.split('/').pop()!;
    await harness.app.get(OnlinePaymentsService).confirmDemo(checkoutToken, card);
    expect(await snapshots()).toEqual(before);
  });
  it('keeps real billing available for the same lease and month as a demo invoice', async () => {
    const demo = await fixture();
    const real = await harness.prisma.invoice.create({ data: {
      leaseId: demo.leaseId, tenantId: demo.tenantId, roomId: demo.roomId,
      billingMonth: demo.billingMonth, rentAmount: 50000, totalAmount: 50000,
    } });
    expect(real.isDemo).toBe(false);
    expect((await api(`/billing/invoices/${demo.id}/payments`, { token: owner.accessToken, method: 'POST', body: { amount: 1000, method: 'cash' } })).status).toBe(409);
    expect((await api(`/tenant/invoices/${demo.id}/payment-proofs`, { method: 'POST', body: { amount: 1000, method: 'bank_transfer' } })).status).toBe(409);
    expect(await harness.prisma.payment.count({ where: { invoiceId: demo.id } })).toBe(0);
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: real.id } })).paidAmount).toBe(0);
  });
});
