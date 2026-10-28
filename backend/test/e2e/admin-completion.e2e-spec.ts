import { BadRequestException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase } from './e2e-fixtures';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { MalwareScannerService } from '../../src/uploads/malware-scanner.service';
import { NotificationDeliveryService } from '../../src/support/notification-delivery.service';
import { AdminReportWorkerService } from '../../src/platform/admin-report-worker.service';
import { ReportObjectStorageService } from '../../src/platform/report-object-storage.service';

describe('Admin completion E2E', () => {
  let harness: E2eHarness;
  const reason = 'Verified support and finance workflow';
  beforeAll(async () => {
    process.env.DELIVERY_ENCRYPTION_KEY = Buffer.alloc(32, 7).toString('base64');
    process.env.ADMIN_MFA_REQUIRED = 'false';
    process.env.NOTIFICATION_EMAIL_WEBHOOK_URL = 'https://notifications.example.test/email';
    process.env.NOTIFICATION_EMAIL_WEBHOOK_SECRET = 'notification-test-secret';
    harness = await createE2eHarness();
  });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });
  afterEach(() => jest.restoreAllMocks());
  const api = (path: string, token: string, body?: unknown, method = 'POST') => requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method });
  async function admin(preset = 'super_admin') {
    const created = await createAdmin(harness.prisma, 'completion');
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { email: created.email } });
    await harness.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { id: user.id, ...await login(harness.baseUrl, created.email) };
  }
  async function ticket(token: string) {
    const result = await api('/support/tickets', token, { subject: 'Support workflow', body: 'Please help with the support workflow.', category: 'GENERAL' });
    expect(result.status).toBe(201); return result.json.data;
  }
  async function attachment(id: string, token: string, version: number, internal = false, mime = 'image/png') {
    const form = new FormData();
    form.append('file', new Blob([new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3])], { type: mime }), 'test.png');
    form.append('version', `${version}`); form.append('internal', `${internal}`);
    const response = await fetch(`${harness.baseUrl}/api/v1/support/tickets/${id}/attachments`, { method: 'POST', headers: { authorization: `Bearer ${token}` }, body: form });
    return { status: response.status, json: await response.json() as any };
  }

  it('isolates saved views by owner and enforces optimistic versions', async () => {
    const first = await admin('support'), other = await admin('support');
    const saved = await api('/support/views', first.accessToken, { name: 'My open tickets', filters: { status: 'OPEN', assignment: 'mine' } });
    expect(saved.status).toBe(201);
    const id = saved.json.data.id;
    expect((await api('/support/views', other.accessToken, undefined, 'GET')).json.data).toHaveLength(0);
    expect((await api(`/support/views/${id}`, other.accessToken, { name: 'Stolen view', filters: {}, version: 1 }, 'PATCH')).status).toBe(404);
    expect((await api(`/support/views/${id}`, first.accessToken, { name: 'Renamed view', filters: { status: 'OPEN' }, version: 1 }, 'PATCH')).status).toBe(200);
    expect((await api(`/support/views/${id}`, first.accessToken, { name: 'Stale view', filters: {}, version: 1 }, 'PATCH')).status).toBe(409);
    expect((await api(`/support/views/${id}?version=2`, first.accessToken, undefined, 'DELETE')).status).toBe(200);
  });

  it('auto-assigns only eligible agents and respects global open-ticket capacity', async () => {
    const manager = await admin(), agent = await admin('support'), owner = await registerLandlord(harness.baseUrl, 'completion-owner');
    expect((await api(`/support/skills/${agent.id}`, manager.accessToken, { categories: ['GENERAL'], maxOpen: 1, reason }, 'PATCH')).status).toBe(200);
    const first = await ticket(owner.accessToken), second = await ticket(owner.accessToken);
    expect(first.assigneeId).toBe(agent.id); expect(first.version).toBe(2);
    expect(second.assigneeId).toBeNull();
    expect((await api(`/support/tickets/${second.id}/auto-assign`, manager.accessToken, { version: 1, reason })).status).toBe(409);
    expect((await api(`/support/skills/${agent.id}`, agent.accessToken, { categories: ['GENERAL'], maxOpen: 5, reason }, 'PATCH')).status).toBe(403);
  });

  it('fails closed on unsafe attachments and keeps internal evidence private', async () => {
    const manager = await admin(), owner = await registerLandlord(harness.baseUrl, 'file-owner'), stranger = await registerLandlord(harness.baseUrl, 'file-stranger');
    const created = await ticket(owner.accessToken);
    const scanner = jest.spyOn(harness.app.get(MalwareScannerService), 'scan');
    scanner.mockRejectedValue(new BadRequestException('Infected attachment'));
    expect((await attachment(created.id, owner.accessToken, 1)).status).toBe(400);
    expect(await harness.prisma.supportAttachment.count()).toBe(0);
    scanner.mockImplementation(async bytes => createHash('sha256').update(bytes).digest('hex'));
    expect((await attachment(created.id, stranger.accessToken, 1)).status).toBe(404);
    expect((await attachment(created.id, owner.accessToken, 1, true)).status).toBe(404);
    expect((await attachment(created.id, owner.accessToken, 1, false, 'application/pdf')).status).toBe(400);
    const uploaded = await attachment(created.id, manager.accessToken, 1, true);
    expect(uploaded.status).toBe(201);
    const filename = uploaded.json.data.filename;
    const requesterDetail = await api(`/support/tickets/${created.id}`, owner.accessToken, undefined, 'GET');
    expect(requesterDetail.json.data.attachments).toHaveLength(0);
    expect((await api(`/uploads/${filename}/access`, owner.accessToken, undefined, 'GET')).status).toBe(404);
    const signed = await api(`/uploads/${filename}/access`, manager.accessToken, undefined, 'GET');
    expect(signed.status).toBe(200);
    expect((await fetch(new URL(signed.json.data.url, harness.baseUrl))).status).toBe(200);
    await harness.prisma.adminProfile.update({ where: { userId: manager.id }, data: { permissions: ['admin.dashboard.view'] } });
    expect((await fetch(new URL(signed.json.data.url, harness.baseUrl))).status).toBe(404);
  });

  it('imports safely, auto-matches references and requires an independent reconciliation checker', async () => {
    const maker = await admin(), checker = await admin(), analyst = await admin('analyst');
    const owner = await registerLandlord(harness.baseUrl, 'finance-owner');
    const property = await createProperty(harness.baseUrl, owner.accessToken);
    const room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    const tenant = await createTenant(harness.baseUrl, owner.accessToken);
    const lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const invoice = await harness.prisma.invoice.create({ data: { roomId: room.id, tenantId: tenant.id, leaseId: lease.id, billingMonth: new Date('2026-10-01Z'), rentAmount: 1000, totalAmount: 1000, paidAmount: 1000, status: 'PAID' } });
    const payment = await harness.prisma.payment.create({ data: { invoiceId: invoice.id, amount: 1000, method: 'BANK_TRANSFER' } });
    const body = { propertyId: property.id, accountKey: 'property-bank-alias', importKey: 'batch-1', reason, lines: [{ externalId: 'bank-1', amount: 1000, occurredAt: new Date().toISOString(), reference: payment.id }] };
    expect((await api('/admin/finance/statements', analyst.accessToken, body)).status).toBe(403);
    const imported = await api('/admin/finance/statements', maker.accessToken, body);
    expect(imported.status).toBe(201); expect(imported.json.data.matched).toBe(1);
    expect((await api('/admin/finance/statements', maker.accessToken, body)).json.data.duplicate).toBe(true);
    expect((await api('/admin/finance/statements', maker.accessToken, { ...body, lines: [{ ...body.lines[0], amount: 999 }] })).status).toBe(409);
    const line = await harness.prisma.financeStatementLine.findFirstOrThrow();
    const proposal = await api(`/admin/finance/statement-lines/${line.id}/proposals`, maker.accessToken, { action: 'UNMATCH', lineVersion: line.version, reason });
    expect(proposal.status).toBe(201);
    expect((await api(`/admin/finance/reconciliation-proposals/${proposal.json.data.id}/approve`, maker.accessToken, { version: line.version, reason })).status).toBe(403);
    const results = await Promise.all([true, true].map(() => api(`/admin/finance/reconciliation-proposals/${proposal.json.data.id}/approve`, checker.accessToken, { version: line.version, reason })));
    expect(results.map(result => result.status).sort()).toEqual([201, 409]);
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).paidAmount).toBe(1000);
    expect(await harness.prisma.payment.count()).toBe(1);
    expect((await harness.prisma.financeStatementLine.findUniqueOrThrow({ where: { id: line.id } })).status).toBe('UNMATCHED');
  });

  it('persists channel jobs once, retries provider errors and honours preference opt-out', async () => {
    const owner = await registerLandlord(harness.baseUrl, 'notify-owner');
    expect((await api('/notification-center/preferences', owner.accessToken, { email: true, push: false }, 'PATCH')).status).toBe(200);
    const note = await harness.prisma.platformNotification.create({ data: { userId: owner.user.id, eventKey: 'completion-event', kind: 'SUPPORT_REPLY', title: 'Private title', body: 'Secret support body', actionPath: '/support-center' } });
    const delivery = harness.app.get(NotificationDeliveryService);
    await Promise.all([delivery.enqueue(), delivery.enqueue()]);
    expect(await harness.prisma.platformNotificationDelivery.count()).toBe(1);
    const job = await harness.prisma.platformNotificationDelivery.findFirstOrThrow({ where: { notificationId: note.id } });
    const provider = jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 503 }));
    await delivery.deliver(job.id);
    expect((await harness.prisma.platformNotificationDelivery.findUniqueOrThrow({ where: { id: job.id } })).status).toBe('PENDING');
    expect(String(provider.mock.calls[0][1]?.body)).not.toContain('Secret support body');
    expect(provider.mock.calls[0][1]?.headers).toMatchObject({ 'idempotency-key': job.id });
    provider.mockRestore();
    await api('/notification-center/preferences', owner.accessToken, { email: false, push: false }, 'PATCH');
    await harness.prisma.platformNotificationDelivery.update({ where: { id: job.id }, data: { availableAt: new Date(0) } });
    await delivery.deliver(job.id);
    expect((await harness.prisma.platformNotificationDelivery.findUniqueOrThrow({ where: { id: job.id } })).status).toBe('CANCELLED');
  });

  it('uses owner-bound signed report links and object storage with retryable failures', async () => {
    const manager = await admin(), other = await admin();
    const created = await api('/admin/report-schedules', manager.accessToken, { name: 'Morning SLA', kind: 'SUPPORT_SLA', cadence: 'DAILY', hourUtc: 8, timezone: 'Asia/Ho_Chi_Minh', reason });
    expect(created.status).toBe(201); expect(created.json.data.timezone).toBe('Asia/Ho_Chi_Minh');
    const run = await api(`/admin/report-schedules/${created.json.data.id}/run`, manager.accessToken, {});
    const worker = harness.app.get(AdminReportWorkerService), storage = harness.app.get(ReportObjectStorageService);
    jest.spyOn(storage, 'ready').mockReturnValue(true);
    const put = jest.spyOn(storage, 'put').mockResolvedValue();
    await worker.process(run.json.data.id);
    const completed = await harness.prisma.adminReportRun.findUniqueOrThrow({ where: { id: run.json.data.id } });
    expect(completed.status).toBe('COMPLETED'); expect(completed.payload).toBeNull(); expect(put).toHaveBeenCalledTimes(1);
    jest.spyOn(storage, 'get').mockResolvedValue(put.mock.calls[0][1]);
    const link = await api(`/admin/report-runs/${completed.id}/download-link`, manager.accessToken, {});
    expect(link.status).toBe(201);
    expect((await api(link.json.data.path, manager.accessToken, undefined, 'GET')).status).toBe(200);
    expect((await api(link.json.data.path, other.accessToken, undefined, 'GET')).status).toBe(404);
    expect((await api(link.json.data.path.replace(/signature=[^&]+/, 'signature=bad'), manager.accessToken, undefined, 'GET')).status).toBe(404);
    await harness.prisma.adminReportRun.update({ where: { id: completed.id }, data: { status: 'FAILED' } });
    expect((await api(`/admin/report-runs/${completed.id}/retry`, other.accessToken, { reason })).status).toBe(409);
    expect((await api(`/admin/report-runs/${completed.id}/retry`, manager.accessToken, { reason })).status).toBe(201);
  });
});
