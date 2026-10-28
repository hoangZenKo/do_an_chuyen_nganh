import { randomUUID } from 'node:crypto';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase } from './e2e-fixtures';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { AdminReportWorkerService } from '../../src/platform/admin-report-worker.service';
import { OperationsHealthService } from '../../src/health/operations-health.service';

describe('Admin support, moderation v2 and governance', () => {
  let harness: E2eHarness;
  const keys = ['ADMIN_MFA_REQUIRED', 'DELIVERY_ENCRYPTION_KEY'];
  const saved = Object.fromEntries(keys.map(key => [key, process.env[key]]));
  beforeEach(async () => {
    process.env.ADMIN_MFA_REQUIRED = 'false';
    process.env.DELIVERY_ENCRYPTION_KEY = Buffer.alloc(32, 4).toString('base64');
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    await closeE2eHarness(harness);
    for (const key of keys) saved[key] === undefined ? delete process.env[key] : process.env[key] = saved[key];
  });
  const call = (path: string, token?: string, body?: unknown, method = body ? 'POST' : 'GET') => requestJson<any>(harness.baseUrl, `/api/v1${path}`, { token, body, method });
  async function admin(preset = 'super_admin') {
    const user = await createAdmin(harness.prisma);
    const record = await harness.prisma.user.findUniqueOrThrow({ where: { email: user.email } });
    await harness.prisma.adminProfile.update({ where: { userId: record.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { id: record.id, ...await login(harness.baseUrl, user.email) };
  }
  async function ticket(token: string) {
    const result = await call('/support/tickets', token, { subject: 'Cần hỗ trợ hợp đồng', body: 'Hợp đồng của tôi có nội dung cần hỗ trợ.', category: 'LEASE', priority: 'URGENT' });
    expect(result.status).toBe(201);
    return result.json.data;
  }

  it('scopes tickets and notifications to owners and hides internal notes', async () => {
    const owner = await registerLandlord(harness.baseUrl), other = await registerLandlord(harness.baseUrl), support = await admin('support');
    const row = await ticket(owner.accessToken);
    expect(row.priority).toBe('NORMAL');
    expect((await call(`/support/tickets/${row.id}`, other.accessToken)).status).toBe(404);
    expect((await call('/support/tickets', other.accessToken)).json.data).toEqual([]);
    const note = await call(`/support/tickets/${row.id}/notes`, support.accessToken, { body: 'Nội bộ không công khai', version: 1 });
    expect(note.status).toBe(201);
    const detail = await call(`/support/tickets/${row.id}`, owner.accessToken);
    expect(detail.text).not.toContain('Nội bộ không công khai');
    expect((await call(`/support/tickets/${row.id}`, support.accessToken)).text).toContain('Nội bộ không công khai');
    expect((await call(`/support/tickets/${row.id}/notes`, owner.accessToken, { body: 'Không được phép', version: 2 })).status).toBe(403);
    expect((await call(`/support/tickets/${row.id}/replies`, owner.accessToken, { body: 'Phản hồi cũ', version: 1 })).status).toBe(409);
    expect((await call(`/support/tickets/${row.id}/replies`, support.accessToken, { body: 'Chúng tôi đã xem nội dung.', version: 2 })).status).toBe(201);
    const notifications = await call('/support/notifications', owner.accessToken);
    expect(notifications.json.summary.unread).toBe(1);
    const notificationId = notifications.json.data[0].id;
    expect((await call(`/support/notifications/${notificationId}/read`, other.accessToken, {})).status).toBe(404);
    expect((await call(`/support/notifications/${notificationId}/read`, owner.accessToken, {})).status).toBe(201);
  });

  it('checks assignee capabilities, optimistic versions and ticket transitions', async () => {
    const owner = await registerLandlord(harness.baseUrl), root = await admin(), support = await admin('support'), analyst = await admin('analyst');
    const row = await ticket(owner.accessToken);
    const assignment = { version: 1, priority: 'HIGH', assigneeId: analyst.id, reason: 'Phân công người có quyền hỗ trợ' };
    expect((await call(`/support/tickets/${row.id}/assignment`, root.accessToken, assignment, 'PATCH')).status).toBe(409);
    expect((await call(`/support/tickets/${row.id}/assignment`, root.accessToken, { ...assignment, assigneeId: support.id }, 'PATCH')).status).toBe(200);
    const state = await harness.prisma.supportTicket.findUniqueOrThrow({ where: { id: row.id } });
    expect(state.status).toBe('IN_PROGRESS');
    expect(state.firstResponseDueAt.getTime()).toBeLessThan(new Date(row.firstResponseDueAt).getTime());
    expect((await call(`/support/tickets/${row.id}/status`, support.accessToken, { version: 2, status: 'RESOLVED', reason: 'Đã xử lý đầy đủ yêu cầu' }, 'PATCH')).status).toBe(200);
    expect((await call(`/support/tickets/${row.id}/replies`, owner.accessToken, { version: 3, body: 'Tôi cần hỗ trợ thêm nội dung.' })).status).toBe(201);
    expect((await harness.prisma.supportTicket.findUniqueOrThrow({ where: { id: row.id } })).resolvedAt).toBeNull();
  });

  async function adverseDecision(ownerId: string, actorId: string) {
    return harness.prisma.moderationDecision.create({ data: { kind: 'LISTING', targetId: randomUUID(), ownerId, actorId, version: 2, fromStatus: 'PENDING', toStatus: 'REJECTED', reason: 'Nội dung không đáp ứng quy định' } });
  }
  async function pendingListing(ownerId: string) {
    const property = await harness.prisma.property.create({ data: { landlordId: ownerId, name: 'Khu kiểm thử' } });
    const room = await harness.prisma.room.create({ data: { propertyId: property.id, name: 'P101', basePrice: 3000000 } });
    return harness.prisma.roomListing.create({ data: { roomId: room.id, title: 'Phòng kiểm thử', description: 'Nội dung kiểm thử danh sách đang chờ.', imageUrls: ['https://example.test/room.jpg'], city: 'HCM', district: 'Bình Thạnh', publicAddress: 'Đường kiểm thử', monthlyRent: 3000000, areaSqm: 20, amenities: [], status: 'PENDING' } });
  }

  it('requires independent appeal reviewers and forbids cross-owner appeals', async () => {
    const owner = await registerLandlord(harness.baseUrl), other = await registerLandlord(harness.baseUrl), moderator = await admin('moderator'), reviewer = await admin('moderator');
    const decision = await adverseDecision(owner.user.id, moderator.id);
    const input = { decisionId: decision.id, reason: 'Tôi có bằng chứng cần xem xét lại.' };
    expect((await call('/moderation/appeals', other.accessToken, input)).status).toBe(404);
    const created = await call('/moderation/appeals', owner.accessToken, input);
    expect(created.status).toBe(201);
    expect((await call('/moderation/appeals', owner.accessToken, input)).status).toBe(409);
    const id = created.json.data.id;
    const resolution = { outcome: 'UPHELD', version: 1, reason: 'Đã kiểm tra độc lập đủ bằng chứng' };
    expect((await call(`/admin/moderation-v2/appeals/${id}/resolve`, moderator.accessToken, resolution)).status).toBe(403);
    expect((await call(`/admin/moderation-v2/appeals/${id}/resolve`, reviewer.accessToken, resolution)).status).toBe(201);
    expect((await call(`/admin/moderation-v2/appeals/${id}/resolve`, reviewer.accessToken, resolution)).status).toBe(409);
    expect((await call('/moderation/appeals', owner.accessToken)).json.data[0].status).toBe('UPHELD');
    expect((await call('/admin/moderation-v2/reports', reviewer.accessToken)).json.data.appeals).toEqual([{ status: 'UPHELD', total: 1 }]);
  });

  it('guards stale appeal reopens without changing the appeal', async () => {
    const owner = await registerLandlord(harness.baseUrl), original = await admin('moderator'), reviewer = await admin('moderator');
    const decision = await adverseDecision(owner.user.id, original.id);
    const appeal = await harness.prisma.moderationAppeal.create({ data: { decisionId: decision.id, requesterId: owner.user.id, reason: 'Xem lại quyết định kiểm duyệt', dueAt: new Date() } });
    expect((await call(`/admin/moderation-v2/appeals/${appeal.id}/resolve`, reviewer.accessToken, { version: 1, outcome: 'REOPENED', reason: 'Xem xét lại nội dung trong hàng đợi' })).status).toBe(409);
    expect((await harness.prisma.moderationAppeal.findUniqueOrThrow({ where: { id: appeal.id } })).status).toBe('OPEN');
  });

  it('returns per-item bulk failures, rejects duplicate and oversized batches', async () => {
    const root = await admin(), support = await admin('support');
    const item = { kind: 'LISTING', id: randomUUID(), version: 1, decision: 'REJECT' };
    const input = { reason: 'Xử lý danh sách vi phạm quy định', items: [item] };
    const result = await call('/admin/moderation-v2/bulk', root.accessToken, input);
    expect(result.status).toBe(201);
    expect(result.json.summary).toEqual({ succeeded: 0, failed: 1 });
    expect(result.json.data[0].status).toBe(404);
    expect((await call('/admin/moderation-v2/bulk', support.accessToken, input)).status).toBe(403);
    expect((await call('/admin/moderation-v2/bulk', root.accessToken, { ...input, items: [item, item] })).status).toBe(400);
    expect((await call('/admin/moderation-v2/bulk', root.accessToken, { ...input, items: Array.from({ length: 26 }, () => ({ ...item, id: randomUUID() })) })).status).toBe(400);
  });

  it('escalates overdue work once across repeated monitor evaluations', async () => {
    const root = await admin();
    const owner = await registerLandlord(harness.baseUrl);
    const listing = await pendingListing(owner.user.id);
    await harness.prisma.moderationWorkItem.create({ data: { kind: 'LISTING', targetId: listing.id, assigneeId: root.id, dueAt: new Date(Date.now() - 3600000) } });
    const monitor = harness.app.get(OperationsHealthService);
    await monitor.evaluate(); await monitor.evaluate();
    expect(await harness.prisma.slaEscalation.count()).toBe(1);
    expect(await harness.prisma.platformNotification.count({ where: { kind: 'MODERATION_SLA' } })).toBe(1);
  });

  it('escalates unassigned default deadlines, open appeals and support SLA without duplicate notifications', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl);
    const listing = await pendingListing(owner.user.id);
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { updatedAt: new Date(Date.now() - 72 * 3600000) } });
    const decision = await adverseDecision(owner.user.id, root.id);
    await harness.prisma.moderationAppeal.create({ data: { decisionId: decision.id, requesterId: owner.user.id, reason: 'Kiểm tra quá hạn xét khiếu nại', dueAt: new Date(0) } });
    await admin('moderator');
    await harness.prisma.supportTicket.create({ data: { requesterId: owner.user.id, subject: 'Ticket quá hạn', category: 'GENERAL', firstResponseDueAt: new Date(0), resolutionDueAt: new Date(0) } });
    const monitor = harness.app.get(OperationsHealthService);
    await monitor.evaluate();
    expect(await harness.prisma.slaEscalation.count()).toBe(4);
    const notifications = await harness.prisma.platformNotification.count();
    expect(notifications).toBeGreaterThan(0);
    await monitor.evaluate();
    expect(await harness.prisma.platformNotification.count()).toBe(notifications);
  });

  it('persists successful bulk decisions alongside version conflicts and supports real appeal reopen', async () => {
    const root = await admin(), reviewer = await admin('moderator'), owner = await registerLandlord(harness.baseUrl);
    const first = await pendingListing(owner.user.id), second = await pendingListing(owner.user.id);
    const response = await call('/admin/moderation-v2/bulk', root.accessToken, { reason: 'Danh sách nội dung cần kiểm tra lại', items: [
      { kind: 'LISTING', id: first.id, version: 1, decision: 'REJECT' }, { kind: 'LISTING', id: second.id, version: 5, decision: 'REJECT' },
    ] });
    expect(response.json.summary).toEqual({ succeeded: 1, failed: 1 });
    expect(response.json.data[1].status).toBe(409);
    const decision = await harness.prisma.moderationDecision.findFirstOrThrow({ where: { targetId: first.id } });
    expect(decision.source).toBe('BULK');
    const appeal = await call('/moderation/appeals', owner.accessToken, { decisionId: decision.id, reason: 'Cần xem xét lại đầy đủ thông tin.' });
    const result = await call(`/admin/moderation-v2/appeals/${appeal.json.data.id}/resolve`, reviewer.accessToken, { version: 1, outcome: 'REOPENED', reason: 'Bằng chứng mới yêu cầu kiểm duyệt lại.' });
    expect(result.status).toBe(201);
    expect((await harness.prisma.roomListing.findUniqueOrThrow({ where: { id: first.id } })).status).toBe('PENDING');
    expect(await harness.prisma.moderationDecision.count({ where: { targetId: first.id, source: 'APPEAL' } })).toBe(1);
  });

  it('feature flags are versioned, audited, gated and cannot alter security controls', async () => {
    const root = await admin(), support = await admin('support'), owner = await registerLandlord(harness.baseUrl);
    const flag = { enabled: false, rollout: 100, roles: [], version: 0, reason: 'Tạm dừng tạo ticket khi bảo trì' };
    expect((await call('/admin/feature-flags/support.user_tickets', support.accessToken, flag, 'PATCH')).status).toBe(403);
    expect((await call('/admin/feature-flags/support.user_tickets', root.accessToken, flag, 'PATCH')).status).toBe(200);
    expect((await call('/admin/feature-flags/support.user_tickets', root.accessToken, flag, 'PATCH')).status).toBe(409);
    expect((await call('/support/tickets', owner.accessToken, { subject: 'Cần hỗ trợ', body: 'Một nội dung cần được xử lý.' })).status).toBe(503);
    expect((await call('/admin/feature-flags/security.mfa', root.accessToken, flag, 'PATCH')).status).toBe(409);
  });

  it('simulates permissions without granting them and supports team membership', async () => {
    const root = await admin(), support = await admin('support');
    const simulation = await call('/admin/permissions/simulate', root.accessToken, { preset: 'support', action: 'admin.finance.read' });
    expect(simulation.json.data.allowed).toBe(false);
    const unknown = await call('/admin/permissions/simulate', root.accessToken, { preset: 'super_admin', route: '/unknown' });
    expect(unknown.json.data.allowed).toBe(false);
    const team = await call('/admin/teams', root.accessToken, { name: 'Support HCM', reason: 'Thiết lập đội hỗ trợ khu vực' });
    expect(team.status).toBe(201);
    expect((await call(`/admin/teams/${team.json.data.id}/members`, root.accessToken, { userId: support.id, role: 'LEAD', reason: 'Bổ sung trưởng nhóm hỗ trợ' })).status).toBe(201);
    expect((await call('/admin/teams', support.accessToken)).status).toBe(403);
    expect((await call('/admin/teams', root.accessToken)).json.data[0].members).toHaveLength(1);
  });

  it('finance reconciliation is read-only and capability gated', async () => {
    const analyst = await admin('analyst'), support = await admin('support');
    const path = '/admin/finance/reconciliation?from=2026-01-01T00:00:00Z&to=2026-10-26T00:00:00Z';
    const response = await call(path, analyst.accessToken);
    expect(response.status).toBe(200); expect(response.json.data.readOnly).toBe(true);
    expect((await call(path, support.accessToken)).status).toBe(403);
    expect((await call('/admin/finance/reconciliation', analyst.accessToken, {})).status).toBe(404);
  });

  it('reconciles lifetime signed payments without confusing refunds with deposit deductions', async () => {
    const root = await admin(), owner = await registerLandlord(harness.baseUrl);
    const property = await createProperty(harness.baseUrl, owner.accessToken);
    const room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    const tenant = await createTenant(harness.baseUrl, owner.accessToken);
    const lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const invoice = await harness.prisma.invoice.create({ data: { roomId: room.id, tenantId: tenant.id, leaseId: lease.id, issuedAt: new Date('2026-10-05'), billingMonth: new Date('2026-10-01'), rentAmount: 1000, totalAmount: 1000, paidAmount: 800 } });
    const payment = await harness.prisma.payment.create({ data: { invoiceId: invoice.id, amount: 1000, paidAt: new Date('2026-09-30') } });
    await harness.prisma.payment.create({ data: { invoiceId: invoice.id, amount: -200, type: 'REVERSAL', reversalOfPaymentId: payment.id, paidAt: new Date('2026-10-10') } });
    await harness.prisma.depositTransaction.createMany({ data: [
      { leaseId: lease.id, landlordId: owner.user.id, amount: 300, type: 'REFUNDED', occurredAt: new Date('2026-10-10') },
      { leaseId: lease.id, landlordId: owner.user.id, amount: 200, type: 'DEDUCTED', occurredAt: new Date('2026-10-10') },
    ] });
    const path = '/admin/finance/reconciliation?from=2026-10-01T00:00:00Z&to=2026-11-01T00:00:00Z';
    const result = await call(path, root.accessToken);
    expect(result.status).toBe(200);
    expect(result.json.data.totals).toMatchObject({ invoicePaidSnapshot: 800, paymentEvents: -200, depositsReturned: 300, depositsDeducted: 200 });
    expect(result.json.data.mismatches).toEqual([]);
    await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { paidAmount: 700 } });
    expect((await call(path, root.accessToken)).json.data.mismatches).toEqual([{ invoiceId: invoice.id, invoicePaid: 700, paymentEvents: 800 }]);
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).paidAmount).toBe(700);
  });

  it('automatically enqueues due schedules once and cancels exports when owner permission is revoked', async () => {
    const root = await admin();
    const schedule = await harness.prisma.adminReportSchedule.create({ data: { ownerId: root.id, name: 'Lịch tự động', kind: 'MODERATION', cadence: 'WEEKLY', hourUtc: 1, nextRunAt: new Date(Date.now() - 3600000) } });
    const worker = harness.app.get(AdminReportWorkerService);
    await Promise.all([worker.enqueueDue(), worker.enqueueDue()]);
    expect(await harness.prisma.adminReportRun.count({ where: { scheduleId: schedule.id } })).toBe(1);
    const updated = await harness.prisma.adminReportSchedule.findUniqueOrThrow({ where: { id: schedule.id } });
    expect(updated.nextRunAt.getTime()).toBeGreaterThan(Date.now());
    expect(updated.version).toBe(2);
    const run = await harness.prisma.adminReportRun.findFirstOrThrow({ where: { scheduleId: schedule.id } });
    await harness.prisma.adminProfile.update({ where: { userId: root.id }, data: { permissions: ['admin.dashboard.view'] } });
    await worker.process(run.id);
    expect((await harness.prisma.adminReportRun.findUniqueOrThrow({ where: { id: run.id } })).status).toBe('CANCELLED');
  });

  it('runs scheduled exports idempotently, encrypts payloads, scopes downloads and expires artifacts', async () => {
    const root = await admin(), other = await admin();
    const input = { name: 'Báo cáo kiểm duyệt', kind: 'MODERATION', cadence: 'DAILY', hourUtc: 10, reason: 'Theo dõi hiệu quả công tác kiểm duyệt' };
    const schedule = await call('/admin/report-schedules', root.accessToken, input);
    expect(schedule.status).toBe(201);
    const id = schedule.json.data.id;
    const first = await call(`/admin/report-schedules/${id}/run`, root.accessToken, {});
    const second = await call(`/admin/report-schedules/${id}/run`, root.accessToken, {});
    expect(first.status).toBe(201); expect(second.json.data.id).toBe(first.json.data.id);
    const worker = harness.app.get(AdminReportWorkerService);
    await Promise.all([worker.process(first.json.data.id), worker.process(first.json.data.id)]);
    const run = await harness.prisma.adminReportRun.findUniqueOrThrow({ where: { id: first.json.data.id } });
    expect(run.status).toBe('COMPLETED'); expect(run.attempts).toBe(1); expect(run.payload).not.toContain('MODERATION');
    expect((await call(`/admin/report-runs/${run.id}/download`, other.accessToken)).status).toBe(404);
    const csv = await call(`/admin/report-runs/${run.id}/download`, root.accessToken);
    expect(csv.status).toBe(200); expect(csv.text).toContain('MODERATION');
    await harness.prisma.adminReportRun.update({ where: { id: run.id }, data: { expiresAt: new Date(0) } });
    await worker.tick();
    expect((await call(`/admin/report-runs/${run.id}/download`, root.accessToken)).status).toBe(409);
    expect((await harness.prisma.adminReportRun.findUniqueOrThrow({ where: { id: run.id } })).payload).toBeNull();
  });
});
