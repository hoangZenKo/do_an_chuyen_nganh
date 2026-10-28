import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { AdminMfaService } from '../../src/auth/admin-mfa.service';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { OperationsHealthService } from '../../src/health/operations-health.service';
import { PlatformNotificationService } from '../../src/support/platform-notification.service';
import { SupportSlaService } from '../../src/support/support-sla.service';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin operations release E2E', () => {
  let harness: E2eHarness;
  const reason = 'Review operational evidence for this support case';
  beforeEach(async () => {
    process.env.ADMIN_MFA_REQUIRED = 'false';
    process.env.ADMIN_STEP_UP_REQUIRED = 'false';
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    process.env.ADMIN_STEP_UP_REQUIRED = 'false';
    jest.restoreAllMocks();
    if (harness) await closeE2eHarness(harness);
  });
  const api = (path: string, token?: string, body?: unknown, method = 'GET', headers?: Record<string, string>) => requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method, headers });
  async function admin(preset = 'super_admin') {
    const created = await createAdmin(harness.prisma, 'ops-release');
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { email: created.email } });
    await harness.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { id: user.id, email: created.email, ...await login(harness.baseUrl, created.email) };
  }
  async function ticket(token: string) {
    const response = await api('/support/tickets', token, { subject: 'Operations release case', category: 'GENERAL', body: 'Please investigate this operational support case.' }, 'POST');
    expect(response.status).toBe(201);
    return response.json.data;
  }
  const policy = (version = 0) => ({ version, reason, enabled: true, timezone: 'UTC', weekdays: [1, 2, 3, 4, 5, 6, 7], startMinute: 0, endMinute: 1440, holidays: [], pauseWaiting: true,
    responseMinutes: { LOW: 1, NORMAL: 1, HIGH: 1, URGENT: 1 }, resolutionMinutes: { LOW: 2, NORMAL: 2, HIGH: 2, URGENT: 2 }, escalationMinutes: [0, 1, 2] });

  it('enforces live permissions and role boundaries for the release routes', async () => {
    const root = await admin(), support = await admin('support'), owner = await registerLandlord(harness.baseUrl, 'ops-owner');
    const paths = ['/admin/permission-catalog', '/admin/access-reviews', `/admin/admins/${root.id}/lifecycle`, '/admin/operations/incidents', '/admin/support-sla-policy'];
    for (const path of paths) {
      expect((await api(path)).status).toBe(401);
      expect((await api(path, owner.accessToken)).status).toBe(403);
      expect((await api(path, support.accessToken)).status).toBe(403);
      expect((await api(path, root.accessToken)).status).toBe(200);
    }
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view'] } });
    for (const path of paths) expect((await api(path, root.accessToken)).status).toBe(403);
  });

  it('revokes an admin target session with version protection and preserves self protection', async () => {
    const root = await admin(), target = await admin();
    const lifecycle = await api(`/admin/admins/${target.id}/lifecycle`, root.accessToken);
    expect(lifecycle.status).toBe(200);
    expect(lifecycle.json.data.activeSessions).toBeGreaterThan(0);
    const self = await api(`/admin/admins/${root.id}/revoke-sessions`, root.accessToken, { version: lifecycle.json.data.version, reason }, 'POST');
    expect(self.status).toBe(403);
    const stale = await api(`/admin/admins/${target.id}/revoke-sessions`, root.accessToken, { version: lifecycle.json.data.version + 1, reason }, 'POST');
    expect(stale.status).toBe(409);
    const revoked = await api(`/admin/admins/${target.id}/revoke-sessions`, root.accessToken, { version: lifecycle.json.data.version, reason }, 'POST');
    expect(revoked.status).toBe(201);
    expect((await api('/auth/me', target.accessToken)).status).toBe(401);
  });

  it('returns a permission-scoped workspace action summary and paginates attention items', async () => {
    const root = await admin(), support = await admin('support');
    const rootSummary = await api('/admin/workspace/summary', root.accessToken);
    expect(rootSummary.status).toBe(200);
    expect(rootSummary.json.data.items.map((item: any) => item.key)).toEqual(expect.arrayContaining([
      'incidents', 'support_overdue', 'moderation', 'finance', 'notifications',
    ]));
    expect(rootSummary.json.data.items.every((item: any) => item.permission)).toBe(true);
    const supportSummary = await api('/admin/workspace/summary', support.accessToken);
    expect(supportSummary.status).toBe(200);
    expect(supportSummary.json.data.items.map((item: any) => item.key)).toEqual(expect.arrayContaining([
      'support_overdue', 'support_due_soon', 'notifications',
    ]));
    expect(supportSummary.json.data.items.map((item: any) => item.key)).not.toContain('finance');
    const page = await api('/admin/workspace/action-items?limit=1&sort=count', root.accessToken);
    expect(page.status).toBe(200);
    expect(page.json.meta.limit).toBe(1);
    expect(page.json.data.length).toBeLessThanOrEqual(1);
  });

  it('binds a single-use step-up to session, action and exact payload, and rejects expired/revoked grants', async () => {
    const root = await admin(), other = await admin(), owner = await registerLandlord(harness.baseUrl, 'stepup-owner');
    process.env.ADMIN_STEP_UP_REQUIRED = 'true';
    const verify = jest.spyOn(harness.app.get(AdminMfaService), 'verify').mockResolvedValue([]);
    const path = `/admin/accounts/${owner.user.id}/reveal`;
    const payload = { reason };
    expect((await api(path, root.accessToken, payload, 'POST')).json.error.code).toBe('ADMIN_STEP_UP_REQUIRED');
    expect((await api(path.toUpperCase(), root.accessToken, payload, 'POST')).json.error.code).toBe('ADMIN_STEP_UP_REQUIRED');
    const issue = async () => {
      const response = await api('/admin/me/security/step-up', root.accessToken, { method: 'POST', path, payload, code: '654321', reason }, 'POST');
      expect(response.status).toBe(201);
      return response.json.data.token as string;
    };
    const grant = await issue();
    expect(verify).toHaveBeenCalledWith(root.id, '654321');
    const header = { 'x-admin-step-up': grant };
    expect((await api(path, other.accessToken, payload, 'POST', header)).status).toBe(403);
    expect((await api(path, root.accessToken, { reason: `${reason} changed` }, 'POST', header)).status).toBe(403);
    expect((await api(`/admin/accounts/${owner.user.id}/suspend`, root.accessToken, { ...payload, version: 0 }, 'POST', header)).status).toBe(403);
    expect((await harness.prisma.adminStepUpGrant.findFirstOrThrow()).consumedAt).toBeNull();
    const competing = await Promise.all([1, 2].map(() => api(path, root.accessToken, payload, 'POST', header)));
    expect(competing.map(response => response.status).sort()).toEqual([201, 403]);
    expect(await harness.prisma.auditLog.count({ where: { action: 'admin.pii_reveal' } })).toBe(1);
    const stored = await harness.prisma.adminStepUpGrant.findFirstOrThrow();
    expect(stored.tokenHash).not.toBe(grant);
    const expired = await issue();
    await harness.prisma.adminStepUpGrant.updateMany({ where: { consumedAt: null }, data: { expiresAt: new Date(0) } });
    expect((await api(path, root.accessToken, payload, 'POST', { 'x-admin-step-up': expired })).status).toBe(403);
    const revoked = await issue();
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view'] } });
    expect((await api(path, root.accessToken, payload, 'POST', { 'x-admin-step-up': revoked })).status).toBe(403);
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: [...ADMIN_PRESETS.super_admin] } });
    await harness.prisma.authSession.updateMany({ where: { userId: root.id }, data: { revokedAt: new Date() } });
    expect((await api(path, root.accessToken, payload, 'POST', { 'x-admin-step-up': revoked })).status).toBe(401);
  });

  it('records independent access reviews with masking, audit and optimistic versions', async () => {
    const root = await admin(), target = await admin('support');
    const list = await api('/admin/access-reviews', root.accessToken);
    expect(list.text).not.toContain(target.email);
    expect(list.text).not.toContain('passwordHash');
    expect(list.text).not.toContain('recoveryHashes');
    const body = { version: 1, nextReviewAt: new Date(Date.now() + 30 * 86400000).toISOString(), reason };
    expect((await api(`/admin/access-reviews/${root.id}`, root.accessToken, body, 'POST')).status).toBe(403);
    const competing = await Promise.all([1, 2].map(() => api(`/admin/access-reviews/${target.id}`, root.accessToken, body, 'POST')));
    expect(competing.map(response => response.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.auditLog.count({ where: { action: 'admin.access_review_completed', resourceId: target.id } })).toBe(1);
  });

  it('protects the legacy landlord status route with the same single-use step-up', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl, 'legacy-stepup');
    process.env.ADMIN_STEP_UP_REQUIRED = 'true';
    jest.spyOn(harness.app.get(AdminMfaService), 'verify').mockResolvedValue([]);
    const path = `/admin/landlords/${owner.user.id}/status`;
    const payload = { isActive: false, version: 0, reason };
    expect((await api(path, root.accessToken, payload, 'PATCH')).json.error.code).toBe('ADMIN_STEP_UP_REQUIRED');
    const issued = await api('/admin/me/security/step-up', root.accessToken,
      { method: 'PATCH', path, payload, code: '654321', reason }, 'POST');
    expect(issued.status).toBe(201);
    const headers = { 'x-admin-step-up': issued.json.data.token };
    expect((await api(path, root.accessToken, payload, 'PATCH', headers)).status).toBe(200);
    expect((await api('/auth/me', owner.accessToken)).status).toBe(401);
    expect((await api(path, root.accessToken, payload, 'PATCH', headers)).status).toBe(403);
    expect(await harness.prisma.auditLog.count({ where: { action: 'admin.account_suspend' } })).toBe(1);
  });

  it('assigns, snoozes, wakes, recovers and reopens incidents without hiding active conditions', async () => {
    const root = await admin(), other = await admin(), support = await admin('support');
    let incident = await harness.prisma.operationsIncident.create({ data: { key: 'LOGIN_FAILURES', title: 'Login failures detected', severity: 'WARNING' } });
    const action = (body: object) => api(`/admin/operations/incidents/${incident.id}/actions`, root.accessToken, { version: incident.version, reason, ...body }, 'POST');
    expect((await action({ action: 'RESOLVE' })).status).toBe(409);
    expect((await action({ action: 'ASSIGN', ownerId: support.id })).status).toBe(400);
    const competing = await Promise.all([root, other].map(user => action({ action: 'ASSIGN', ownerId: user.id })));
    expect(competing.map(response => response.status).sort()).toEqual([201, 409]);
    incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { id: incident.id } });
    expect((await action({ action: 'SNOOZE', snoozedUntil: new Date(Date.now() + 60000).toISOString() })).status).toBe(201);
    await harness.prisma.operationsMetric.create({ data: { minute: new Date(), loginFailures: 25 } });
    await harness.app.get(OperationsHealthService).evaluate();
    incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { id: incident.id } });
    expect(incident.status).toBe('SNOOZED');
    await harness.prisma.operationsIncident.update({ where: { id: incident.id }, data: { snoozedUntil: new Date(0) } });
    await harness.app.get(OperationsHealthService).evaluate();
    incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { id: incident.id } });
    expect(incident.status).toBe('OPEN');
    await harness.prisma.operationsMetric.deleteMany();
    await harness.app.get(OperationsHealthService).evaluate();
    incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { id: incident.id } });
    expect(incident.status).toBe('RESOLVED'); expect(incident.conditionActive).toBe(false);
    expect((await action({ action: 'REOPEN' })).status).toBe(201);
    incident = await harness.prisma.operationsIncident.findUniqueOrThrow({ where: { id: incident.id } });
    expect((await action({ action: 'RESOLVE' })).status).toBe(201);
    const detail = await api(`/admin/operations/incidents/${incident.id}`, root.accessToken);
    expect(detail.json.data.history.length).toBeGreaterThan(4);
    expect(detail.json.data.runbook).toBeTruthy();
  });

  it('preserves SLA snapshots, pause/resume budgets and overdue time on reopen', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl, 'sla-owner');
    const saved = await api('/admin/support-sla-policy', root.accessToken, policy(), 'PATCH');
    expect(saved.status).toBe(200);
    const created = await ticket(owner.accessToken);
    expect(created.slaSnapshot.version).toBe(1);
    expect((await api('/admin/support-sla-policy', root.accessToken, policy(), 'PATCH')).status).toBe(409);
    expect((await api('/admin/support-sla-policy', root.accessToken, { ...policy(1), timezone: 'Not/A_Zone' }, 'PATCH')).status).toBe(400);
    expect((await api('/admin/support-sla-policy', root.accessToken, { ...policy(1), holidays: ['2026-02-30'] }, 'PATCH')).status).toBe(400);
    await api('/admin/support-sla-policy', root.accessToken, { ...policy(1), enabled: false }, 'PATCH');
    expect((await harness.prisma.supportTicket.findUniqueOrThrow({ where: { id: created.id } })).slaSnapshot).toEqual(created.slaSnapshot);
    const overdue = new Date(Date.now() - 60000);
    await harness.prisma.supportTicket.update({ where: { id: created.id }, data: { resolutionDueAt: overdue } });
    const reply = await api(`/support/tickets/${created.id}/replies`, root.accessToken, { version: created.version, body: 'Please provide the remaining details.' }, 'POST');
    expect(reply.status).toBe(201); expect(reply.json.data.slaPausedAt).toBeTruthy();
    const returned = await api(`/support/tickets/${created.id}/replies`, owner.accessToken, { version: reply.json.data.version, body: 'Here are the requested details.' }, 'POST');
    expect(returned.status).toBe(201); expect(returned.json.data.slaPausedAt).toBeNull();
    expect(returned.json.data.resolutionDueAt).toBe(overdue.toISOString());
    const resolved = await api(`/support/tickets/${created.id}/status`, root.accessToken, { version: returned.json.data.version, status: 'RESOLVED', reason }, 'PATCH');
    expect(resolved.status).toBe(200);
    const reopened = await api(`/support/tickets/${created.id}/replies`, owner.accessToken, { version: resolved.json.data.version, body: 'This case still needs investigation.' }, 'POST');
    expect(reopened.status).toBe(201); expect(reopened.json.data.resolutionDueAt).toBe(overdue.toISOString());
    expect((await ticket(owner.accessToken)).slaSnapshot).toBeNull();
  });

  it('deduplicates multi-level SLA escalation across competing workers and stops after resolution', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl, 'escalation-owner');
    expect((await api('/admin/support-sla-policy', root.accessToken, policy(), 'PATCH')).status).toBe(200);
    const created = await ticket(owner.accessToken);
    const now = new Date();
    await harness.prisma.supportTicket.update({ where: { id: created.id }, data: { firstResponseDueAt: new Date(now.getTime() - 5 * 60000), resolutionDueAt: new Date(now.getTime() - 4 * 60000) } });
    const worker = harness.app.get(SupportSlaService);
    const otherWorker = new SupportSlaService(harness.prisma, harness.app.get(ConfigService), harness.app.get(PlatformNotificationService));
    await Promise.all([worker.run(now), otherWorker.run(now)]);
    expect(await harness.prisma.supportEscalation.count()).toBe(6);
    expect(await harness.prisma.platformNotification.count({ where: { kind: 'SUPPORT_SLA' } })).toBe(6);
    await worker.run(now);
    expect(await harness.prisma.supportEscalation.count()).toBe(6);
    expect((await harness.prisma.workerHeartbeat.findUniqueOrThrow({ where: { name: 'support-sla' } })).status).toBe('OK');
    await harness.prisma.supportTicket.update({ where: { id: created.id }, data: { status: 'RESOLVED' } });
    await worker.run(new Date(now.getTime() + 3600000));
    expect(await harness.prisma.supportEscalation.count()).toBe(6);
  });

  it('keeps case links requester-scoped and filters timeline resources after permission revocation', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl, 'case-owner'), other = await registerLandlord(harness.baseUrl, 'case-other');
    const property = await createProperty(harness.baseUrl, owner.accessToken), foreign = await createProperty(harness.baseUrl, other.accessToken);
    const room = await createRoom(harness.baseUrl, owner.accessToken, property.id), tenant = await createTenant(harness.baseUrl, owner.accessToken);
    const lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const invoice = await harness.prisma.invoice.create({ data: { leaseId: lease.id, tenantId: tenant.id, roomId: room.id, billingMonth: new Date('2026-10-01Z'), rentAmount: 1234, totalAmount: 1234 } });
    const created = await ticket(owner.accessToken);
    const link = (kind: string, targetId: string, version: number) => api(`/admin/support-cases/${created.id}/links`, root.accessToken, { kind, targetId, version, reason }, 'POST');
    expect((await link('PROPERTY', foreign.id, created.version)).status).toBe(404);
    expect((await link('PROPERTY', property.id, created.version)).status).toBe(201);
    expect((await link('INVOICE', invoice.id, created.version + 1)).status).toBe(201);
    const path = `/admin/support-cases/${created.id}/timeline`;
    const full = await api(path, root.accessToken, { reason }, 'POST');
    expect(full.response.headers.get('cache-control')).toBe('private, no-store');
    expect(full.json.data.links).toHaveLength(2); expect(full.text).not.toContain(owner.email);
    expect((await api(path, owner.accessToken, { reason }, 'POST')).status).toBe(403);
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ADMIN_PRESETS.super_admin.filter(permission => permission !== 'admin.finance.read') } });
    const restricted = await api(path, root.accessToken, { reason }, 'POST');
    expect(restricted.json.data.links).toHaveLength(1);
    expect(restricted.text).not.toContain('totalAmount');
    expect((await api(`/admin/support-cases/${randomUUID()}/timeline`, root.accessToken, { reason }, 'POST')).status).toBe(404);
    const requester = await api(`/support/tickets/${created.id}`, owner.accessToken);
    expect(requester.text).not.toContain('caseLinks');
  });
});
