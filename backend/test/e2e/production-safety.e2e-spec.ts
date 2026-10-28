import { randomUUID } from 'node:crypto';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { resolve } from 'node:path';
import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, login, registerLandlord, resetDatabase } from './e2e-fixtures';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { AccountAccessService } from '../../src/auth/account-access.service';
import { DeliveryService } from '../../src/delivery/delivery.service';
import { RuntimeMetricsService } from '../../src/health/runtime-metrics.service';
import { OperationsHealthService } from '../../src/health/operations-health.service';

describe('Production safety', () => {
  let harness: E2eHarness;
  const envKeys = ['ADMIN_MFA_REQUIRED', 'DELIVERY_ENCRYPTION_KEY', 'AUTH_PUBLIC_APP_URL', 'AUTH_DELIVERY_WEBHOOK_URL', 'AUTH_DELIVERY_WEBHOOK_SECRET', 'OPERATIONS_ALERT_WEBHOOK_URL', 'OPERATIONS_ALERT_WEBHOOK_SECRET'];
  const previous = Object.fromEntries(envKeys.map(key => [key, process.env[key]]));
  beforeEach(async () => {
    process.env.ADMIN_MFA_REQUIRED = 'false';
    process.env.DELIVERY_ENCRYPTION_KEY = Buffer.alloc(32, 8).toString('base64');
    process.env.AUTH_PUBLIC_APP_URL = 'https://app.example.test';
    process.env.AUTH_DELIVERY_WEBHOOK_URL = 'https://notify.example.test/events';
    process.env.AUTH_DELIVERY_WEBHOOK_SECRET = 'test-webhook-secret';
    delete process.env.OPERATIONS_ALERT_WEBHOOK_URL;
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    jest.restoreAllMocks();
    await closeE2eHarness(harness);
    for (const key of envKeys) previous[key] === undefined ? delete process.env[key] : process.env[key] = previous[key];
  });
  async function admin(preset = 'super_admin') {
    const user = await createAdmin(harness.prisma);
    const record = await harness.prisma.user.findUniqueOrThrow({ where: { email: user.email } });
    await harness.prisma.adminProfile.update({ where: { userId: record.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { id: record.id, ...await login(harness.baseUrl, user.email) };
  }
  const call = (path: string, token?: string, body?: unknown, headers?: Record<string, string>) => requestJson<any>(harness.baseUrl, `/api/v1${path}`, { token, body, headers, method: body ? 'POST' : 'GET' });

  it('runs the read-only staging smoke CLI against the isolated local API', async () => {
    const root = await admin(), support = await admin('support');
    const owner = await registerLandlord(harness.baseUrl);
    const { stdout } = await promisify(execFile)(process.execPath,
      [resolve(__dirname, '../../scripts/staging-admin-smoke.mjs')], {
        env: { ...process.env, STAGING_API_URL: harness.baseUrl,
          STAGING_ADMIN_TOKEN: root.accessToken, STAGING_SUPPORT_TOKEN: support.accessToken,
          STAGING_LANDLORD_TOKEN: owner.accessToken }, timeout: 30000,
      });
    expect(stdout.match(/^PASS /gm)).toHaveLength(16);
    expect(stdout).not.toContain('FAIL');
  });

  it('protects operations data and correlates sensitive admin audit requests', async () => {
    const root = await admin(), support = await admin('support'), owner = await registerLandlord(harness.baseUrl);
    expect((await call('/health/live')).status).toBe(200);
    expect((await call('/health/ready')).status).toBe(200);
    expect((await call('/admin/operations/health')).status).toBe(401);
    expect((await call('/admin/operations/health', support.accessToken)).status).toBe(403);
    expect((await call('/admin/operations/health', owner.accessToken)).status).toBe(403);
    const response = await call('/admin/operations/health', root.accessToken);
    expect(response.status).toBe(200);
    expect(response.response.headers.get('cache-control')).toContain('no-store');
    expect(response.json.data.database).toBe('ok');
    expect(response.text).not.toContain('test-webhook-secret');
    const requestId = randomUUID();
    await call(`/admin/accounts/${owner.user.id}/revoke-sessions`, root.accessToken, { reason: 'Security smoke session revoke' }, { 'x-request-id': requestId });
    const audit = await call(`/admin/audit-logs?requestId=${requestId}`, root.accessToken);
    expect(audit.json.data).toHaveLength(1);
    expect(audit.json.data[0].requestId).toBe(requestId);
  });

  it('exports bounded, injection-safe CSV and exposes only redacted detail', async () => {
    const root = await admin(), support = await admin('support');
    const row = await harness.prisma.auditLog.create({ data: { actorRole: 'ADMIN', actorId: root.id, action: 'test.export', resourceType: 'account', summary: '=HYPERLINK("unsafe")', metadata: { before: { email: 'private@example.com', isActive: true }, accessToken: 'never-show' } } });
    const detail = await call(`/admin/audit-logs/${row.id}`, root.accessToken);
    expect(detail.status).toBe(200);
    expect(detail.text).not.toContain('private@example.com'); expect(detail.text).not.toContain('never-show');
    const range = { from: new Date(Date.now() - 86400000).toISOString(), to: new Date(Date.now() + 10000).toISOString(), reason: 'Review security audit for staging', action: 'test.export' };
    const csv = await call('/admin/audit-logs/export', root.accessToken, range);
    expect(csv.status).toBe(201); expect(csv.response.headers.get('content-type')).toContain('text/csv');
    expect(csv.text).toContain('"\'=HYPERLINK');
    expect((await call('/admin/audit-logs/export', support.accessToken, range)).status).toBe(403);
    expect((await call('/admin/audit-logs/export', root.accessToken, { ...range, from: '2025-01-01T00:00:00Z' })).status).toBe(400);
    expect((await call('/admin/audit-logs?from=2026-10-25&to=2026-10-01', root.accessToken)).status).toBe(400);
    expect(await harness.prisma.auditLog.count({ where: { action: 'admin.audit_export' } })).toBe(1);
  });

  it('persists retries without raw tokens, uses the same idempotency key and serializes competing workers', async () => {
    const owner = await registerLandlord(harness.baseUrl);
    const access = harness.app.get(AccountAccessService), delivery = harness.app.get(DeliveryService);
    const queued = await access.send(owner.user.id, 'PASSWORD_RESET');
    const job = await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: queued.deliveryId } });
    expect(job.payload).not.toContain(owner.email); expect(job.payload).not.toContain('actionUrl');
    const request = jest.spyOn(global, 'fetch').mockResolvedValueOnce(new Response('', { status: 503 })).mockResolvedValue(new Response('', { status: 200 }));
    await delivery.deliver(job.id);
    let state = await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: job.id }, include: { token: true } });
    expect(state.status).toBe('PENDING'); expect(state.attempts).toBe(1); expect(state.token?.consumedAt).toBeNull();
    await harness.prisma.deliveryJob.update({ where: { id: job.id }, data: { availableAt: new Date(0) } });
    await Promise.all([delivery.deliver(job.id), delivery.deliver(job.id)]);
    state = await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: job.id }, include: { token: true } });
    expect(state.status).toBe('SENT'); expect(state.payload).toBeNull(); expect(request).toHaveBeenCalledTimes(2);
    for (const [, options] of request.mock.calls) expect((options?.headers as Record<string, string>)['idempotency-key']).toBe(job.id);
  });

  it('cancels superseded and expired jobs, and stops retrying permanent provider failures', async () => {
    const owner = await registerLandlord(harness.baseUrl);
    const access = harness.app.get(AccountAccessService), delivery = harness.app.get(DeliveryService);
    const old = await access.send(owner.user.id, 'PASSWORD_RESET');
    const current = await access.send(owner.user.id, 'PASSWORD_RESET');
    const request = jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 400 }));
    await delivery.deliver(old.deliveryId); expect(request).not.toHaveBeenCalled();
    await delivery.deliver(current.deliveryId);
    const permanent = await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: current.deliveryId }, include: { token: true } });
    expect(permanent.status).toBe('DEAD'); expect(permanent.payload).toBeNull(); expect(permanent.token?.consumedAt).toBeTruthy();
    const expired = await access.send(owner.user.id, 'PASSWORD_RESET');
    await harness.prisma.deliveryJob.update({ where: { id: expired.deliveryId }, data: { expiresAt: new Date(0) } });
    await delivery.deliver(expired.deliveryId); expect(request).toHaveBeenCalledTimes(1);
    expect((await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: expired.deliveryId } })).status).toBe('CANCELLED');
  });

  it('deduplicates alerts, acknowledges with a version, and auto-resolves recovered conditions', async () => {
    process.env.OPERATIONS_ALERT_WEBHOOK_URL = 'https://notify.example.test/incidents';
    process.env.OPERATIONS_ALERT_WEBHOOK_SECRET = 'test-alert-secret';
    const root = await admin();
    const metrics = harness.app.get(RuntimeMetricsService);
    for (let index = 0; index < 20; index++) metrics.record('POST', '/api/v1/auth/login', 401, 10);
    await metrics.flush();
    const monitor = harness.app.get(OperationsHealthService);
    await monitor.evaluate(); await monitor.evaluate();
    const incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { key: 'LOGIN_FAILURES' } });
    expect(await harness.prisma.operationsIncident.count({ where: { key: 'LOGIN_FAILURES' } })).toBe(1);
    const alerts = await harness.prisma.deliveryJob.findMany({ where: { kind: 'INCIDENT_ALERT' } });
    expect(alerts).toHaveLength(1);
    expect(alerts[0].payload).not.toContain('LOGIN_FAILURES');
    const request = jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 200 }));
    await harness.app.get(DeliveryService).deliver(alerts[0].id);
    const [, options] = request.mock.calls[0];
    expect(JSON.parse(options?.body as string).key).toBe('LOGIN_FAILURES');
    expect((options?.headers as Record<string, string>).authorization).toBe('Bearer test-alert-secret');
    request.mockRestore();
    const responses = await Promise.all([1, 2].map(() => call(`/admin/operations/incidents/${incident.id}/acknowledge`, root.accessToken, { version: incident.version, reason: 'Investigating staging login failures' })));
    expect(responses.map(response => response.status).sort()).toEqual([201, 409]);
    await harness.prisma.operationsMetric.deleteMany();
    await monitor.evaluate();
    expect((await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { key: 'LOGIN_FAILURES' } })).status).toBe('RESOLVED');
    for (let index = 0; index < 20; index++) metrics.record('POST', '/api/v1/auth/login', 401, 10);
    await monitor.evaluate(); await monitor.evaluate();
    expect(await harness.prisma.deliveryJob.count({ where: { kind: 'INCIDENT_ALERT' } })).toBe(2);
    expect((await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { key: 'LOGIN_FAILURES' } })).status).toBe('OPEN');
  });

  it('does not keep delivery incidents open for historical dead jobs', async () => {
    const historical = new Date(Date.now() - 3600000);
    const job = await harness.prisma.deliveryJob.create({ data: { kind: 'ACCOUNT_ACCESS', status: 'DEAD', expiresAt: historical, updatedAt: historical } });
    const monitor = harness.app.get(OperationsHealthService);
    await monitor.evaluate();
    expect(await harness.prisma.operationsIncident.count({ where: { key: 'DELIVERY_FAILURES' } })).toBe(0);
    await harness.prisma.deliveryJob.update({ where: { id: job.id }, data: { updatedAt: new Date() } });
    await monitor.evaluate();
    expect((await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { key: 'DELIVERY_FAILURES' } })).status).toBe('OPEN');
    await harness.prisma.deliveryJob.update({ where: { id: job.id }, data: { updatedAt: historical } });
    await monitor.evaluate();
    expect((await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { key: 'DELIVERY_FAILURES' } })).status).toBe('RESOLVED');
    expect((await monitor.summary()).data.deliveries).toContainEqual({ status: 'DEAD', total: 1 });
  });
});
