import { randomUUID } from 'node:crypto';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin workspace foundation E2E', () => {
  let harness: E2eHarness;
  beforeEach(async () => {
    process.env.ADMIN_MFA_REQUIRED = 'false';
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    jest.restoreAllMocks();
    if (harness) await closeE2eHarness(harness);
  });
  const api = (path: string, token?: string) => requestJson(harness.baseUrl, `/api/v1${path}`, { token });
  async function admin() {
    const created = await createAdmin(harness.prisma, 'workspace');
    const session = await login(harness.baseUrl, created.email);
    return { id: session.user.id as string, token: session.accessToken };
  }

  it('enforces roles, live dashboard permission, no-store and query validation', async () => {
    const root = await admin();
    const owner = await registerLandlord(harness.baseUrl, 'workspace-owner');
    for (const path of ['/admin/workspace/summary', '/admin/workspace/action-items']) {
      expect((await api(path)).status).toBe(401);
      expect((await api(path, owner.accessToken)).status).toBe(403);
      const response = await api(path, root.token);
      expect(response.status).toBe(200);
      expect(response.response.headers.get('cache-control')).toBe('private, no-store');
    }
    for (const query of ['limit=0', 'limit=21', 'sort=rawSql', 'group=secret', 'cursor=unknown']) {
      expect((await api(`/admin/workspace/action-items?${query}`, root.token)).status).toBe(400);
    }
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.support.read'] } });
    expect((await api('/admin/workspace/summary', root.token)).status).toBe(403);
    expect((await api('/admin/workspace/action-items', root.token)).status).toBe(403);
  });

  it('counts distinct support deadline buckets, pauses resolution only and scopes unread notifications', async () => {
    const root = await admin(), other = await admin();
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view', 'admin.support.read', 'admin.notifications.view'] } });
    const now = Date.now();
    const past = new Date(now - 600000), soon = new Date(now + 1800000), later = new Date(now + 86400000);
    const base = { requesterId: other.id, subject: 'Private support subject', category: 'GENERAL', firstResponseDueAt: later, resolutionDueAt: later };
    await harness.prisma.supportTicket.createMany({ data: [
      { ...base, firstResponseDueAt: past, resolutionDueAt: past },
      { ...base, firstResponseDueAt: soon },
      { ...base, firstResponseDueAt: past, slaPausedAt: new Date() },
      { ...base, firstResponseDueAt: past, status: 'CLOSED' },
      { ...base, firstResponseDueAt: past, mergedIntoId: randomUUID() },
      { ...base, firstResponseDueAt: past, firstRespondedAt: new Date() },
    ] });
    await harness.prisma.platformNotification.createMany({ data: [
      { userId: root.id, eventKey: 'own-unread', kind: 'SUPPORT', title: 'Private notification', body: 'Internal detail', actionPath: '/admin' },
      { userId: root.id, eventKey: 'own-read', kind: 'SUPPORT', title: 'Read', body: 'Internal detail', actionPath: '/admin', readAt: new Date() },
      { userId: other.id, eventKey: 'other-unread', kind: 'SUPPORT', title: 'Other', body: 'Internal detail', actionPath: '/admin' },
    ] });
    const response = await api('/admin/workspace/summary', root.token);
    expect(response.status).toBe(200);
    const data = response.json.data;
    expect(data.dataFreshness).toBe('LIVE');
    expect(data.pendingCount).toBe(3);
    expect(data.unreadNotificationCount).toBe(1);
    expect(data.items.map((item: any) => [item.key, item.pendingCount])).toEqual([
      ['support_overdue', 2], ['support_due_soon', 1], ['notifications', 1],
    ]);
    expect(response.text).not.toContain('Private support subject');
    expect(response.text).not.toContain('Internal detail');
  });

  it('restricts failed reports to owned, unexpired runs with a permitted report kind', async () => {
    const root = await admin(), other = await admin();
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view', 'admin.reports.manage', 'admin.support.read'] } });
    for (const [ownerId, kind, expired] of [
      [root.id, 'SUPPORT_SLA', false], [root.id, 'SUPPORT_SLA', true],
      [root.id, 'MONTHLY_FINANCE', false], [other.id, 'SUPPORT_SLA', false],
    ] as const) {
      const schedule = await harness.prisma.adminReportSchedule.create({ data: {
        ownerId, name: 'Private report schedule', kind, cadence: 'DAILY', hourUtc: 1, nextRunAt: new Date(),
      } });
      await harness.prisma.adminReportRun.create({ data: {
        scheduleId: schedule.id, kind, scheduleVersion: 1, scheduledFor: new Date(), status: 'FAILED',
        expiresAt: new Date(Date.now() + (expired ? -60000 : 86400000)),
      } });
    }
    const response = await api('/admin/workspace/summary', root.token);
    expect(response.status).toBe(200);
    expect(response.json.data.items.find((item: any) => item.key === 'reports').pendingCount).toBe(1);
    expect(response.text).not.toContain('Private report schedule');
  });

  it('returns partial data and unknown counts rather than a false zero when a source fails', async () => {
    const root = await admin();
    jest.spyOn(harness.prisma.operationsIncident, 'count').mockRejectedValueOnce(new Error('Do not expose database internals'));
    const response = await api('/admin/workspace/summary', root.token);
    expect(response.status).toBe(200);
    expect(response.json.data.dataFreshness).toBe('PARTIAL');
    expect(response.json.data.items.find((item: any) => item.key === 'incidents')).toMatchObject({
      status: 'UNAVAILABLE', pendingCount: null, lastUpdatedAt: null,
    });
    expect(response.json.data.items.find((item: any) => item.key === 'finance').status).toBe('OK');
    expect(response.text).not.toContain('Do not expose database internals');
  });

  it('filters and paginates bounded group buckets with no duplicate page entries', async () => {
    const root = await admin();
    const first = await api('/admin/workspace/action-items?view=all&sort=priority&limit=2', root.token);
    expect(first.status).toBe(200);
    expect(first.json.data).toHaveLength(2);
    expect(first.json.meta.total).toBe(7);
    const cursor = first.json.meta.nextCursor;
    const second = await api(`/admin/workspace/action-items?view=all&sort=priority&limit=2&cursor=${cursor}`, root.token);
    expect(second.status).toBe(200);
    const keys = [...first.json.data, ...second.json.data].map((item: any) => item.key);
    expect(new Set(keys).size).toBe(4);
    expect(keys).not.toContain('notifications');
    const filtered = await api('/admin/workspace/action-items?view=all&group=finance', root.token);
    expect(filtered.json.data.map((item: any) => item.key)).toEqual(['finance']);
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view', 'admin.support.read'] } });
    expect((await api('/admin/workspace/action-items?view=all&group=finance', root.token)).json.data).toEqual([]);
    expect((await api('/admin/workspace/action-items?view=all&cursor=finance', root.token)).status).toBe(400);
  });
});
