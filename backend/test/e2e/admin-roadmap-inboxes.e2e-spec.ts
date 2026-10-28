import { randomUUID } from 'node:crypto';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin roadmap inboxes and preview', () => {
  let harness: E2eHarness;
  const previousMfa = process.env.ADMIN_MFA_REQUIRED;
  beforeEach(async () => {
    process.env.ADMIN_MFA_REQUIRED = 'false';
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    if (harness) await closeE2eHarness(harness);
    if (previousMfa === undefined) delete process.env.ADMIN_MFA_REQUIRED;
    else process.env.ADMIN_MFA_REQUIRED = previousMfa;
  });
  const call = (path: string, token?: string, body?: unknown) => requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method: body ? 'POST' : 'GET' });
  async function admin() {
    const created = await createAdmin(harness.prisma, 'roadmap');
    return login(harness.baseUrl, created.email);
  }

  it('intersects incident ownership, search and time window and paginates on the server', async () => {
    const root = await admin();
    const other = await admin();
    const base = { severity: 'WARNING', title: 'Queue backlog', status: 'OPEN' };
    const now = new Date();
    await harness.prisma.operationsIncident.createMany({ data: [
      { ...base, key: 'QUEUE_TEST_A', ownerId: root.user.id, lastSeenAt: now },
      { ...base, key: 'QUEUE_TEST_B', ownerId: root.user.id, lastSeenAt: now },
      { ...base, key: 'QUEUE_TEST_OTHER', ownerId: other.user.id, lastSeenAt: now },
      { ...base, key: 'QUEUE_TEST_OLD', ownerId: root.user.id, lastSeenAt: new Date(Date.now() - 3 * 86400000) },
    ] });
    const query = '/admin/operations/incidents?assignment=mine&status=OPEN&window=24h&search=backlog&limit=1';
    const first = await call(query, root.accessToken);
    const second = await call(`${query}&page=2`, root.accessToken);
    expect(first.status).toBe(200);
    expect(first.json.meta.total).toBe(2);
    expect(first.json.data).toHaveLength(1);
    expect(first.json.data[0].id).not.toBe(second.json.data[0].id);
    expect(first.json.data[0].ownerId).toBe(root.user.id);
    expect((await call(`${query}&ownerId=${other.user.id}`, root.accessToken)).json.meta.total).toBe(0);
    expect((await call('/admin/operations/incidents?window=invalid', root.accessToken)).status).toBe(400);
    expect((await call(query)).status).toBe(401);
  });

  it('keeps SLA list counts equal to summary, intersects status and persists SLA saved views', async () => {
    const root = await admin();
    const later = new Date(Date.now() + 86400000);
    const past = new Date(Date.now() - 3600000);
    const soon = new Date(Date.now() + 1800000);
    const base = { requesterId: root.user.id, subject: 'Inbox ticket', category: 'GENERAL', firstResponseDueAt: later, resolutionDueAt: later };
    await harness.prisma.supportTicket.createMany({ data: [
      { ...base, resolutionDueAt: past, firstRespondedAt: new Date() },
      { ...base, resolutionDueAt: past, firstRespondedAt: new Date(), slaPausedAt: new Date() },
      { ...base, firstResponseDueAt: past, slaPausedAt: new Date() },
      { ...base, firstResponseDueAt: soon },
      { ...base, firstResponseDueAt: past, mergedIntoId: randomUUID() },
      { ...base, firstResponseDueAt: past, status: 'CLOSED' },
    ] });
    const summary = await call('/admin/workspace/summary', root.accessToken);
    for (const [sla, count] of [['overdue', 2], ['due_soon', 1]] as const) {
      const response = await call(`/support/tickets?sla=${sla}`, root.accessToken);
      expect(response.status).toBe(200);
      expect(response.json.meta.total).toBe(count);
      expect(summary.json.data.items.find((item: { key: string }) => item.key === `support_${sla}`).pendingCount).toBe(count);
    }
    expect((await call('/support/tickets?sla=overdue&status=CLOSED', root.accessToken)).json.meta.total).toBe(0);
    expect((await call('/support/tickets?sla=paused', root.accessToken)).json.meta.total).toBe(2);
    const saved = await call('/support/views', root.accessToken, { name: 'Due soon', filters: { sla: 'due_soon', category: 'GENERAL', sort: 'resolution_due' } });
    expect(saved.status).toBe(201);
    expect(saved.json.data.filters).toMatchObject({ sla: 'due_soon', category: 'GENERAL', sort: 'resolution_due' });
    expect((await call('/support/tickets?sla=invalid', root.accessToken)).status).toBe(400);
  });

  it('previews real listing state without writing decisions, then blocks stale versions and revoked permissions', async () => {
    const root = await admin();
    const property = await harness.prisma.property.create({ data: { landlordId: root.user.id, name: 'Test property' } });
    const room = await harness.prisma.room.create({ data: { propertyId: property.id, name: 'P101', basePrice: 3000000 } });
    const listing = await harness.prisma.roomListing.create({ data: { roomId: room.id, title: 'Test listing', description: 'Preview-only fixture',
      imageUrls: [], city: 'HCM', district: 'Test district', publicAddress: 'Test address', monthlyRent: 3000000, areaSqm: 20, amenities: [], status: 'PENDING' } });
    const input = { reason: 'Preview-only policy verification', items: [{ kind: 'LISTING', id: listing.id, version: listing.version, decision: 'PUBLISH' }] };
    const decisionsBefore = await harness.prisma.moderationDecision.count();
    const auditsBefore = await harness.prisma.auditLog.count();
    const ready = await call('/admin/moderation-v2/bulk/preview', root.accessToken, input);
    expect(ready.status).toBe(201);
    expect(ready.json.summary).toEqual({ total: 1, ready: 1, blocked: 0 });
    expect(await harness.prisma.moderationDecision.count()).toBe(decisionsBefore);
    expect(await harness.prisma.auditLog.count()).toBe(auditsBefore);
    expect(await harness.prisma.roomListing.findUnique({ where: { id: listing.id } })).toMatchObject({ version: listing.version, status: 'PENDING' });
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { version: { increment: 1 } } });
    expect((await call('/admin/moderation-v2/bulk/preview', root.accessToken, input)).json.summary.blocked).toBe(1);
    await harness.prisma.adminProfile.update({ where: { userId: root.user.id }, data: { permissions: ['admin.dashboard.view'] } });
    expect((await call('/admin/moderation-v2/bulk/preview', root.accessToken, input)).status).toBe(403);
  });
});
