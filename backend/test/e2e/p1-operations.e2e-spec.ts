import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';
import { RecurringService } from '../../src/operations/recurring.service';
import { AnnouncementsService } from '../../src/notifications/announcements.service';

describe('P1 operations and online payments E2E', () => {
  let harness: E2eHarness;
  let owner: Awaited<ReturnType<typeof registerLandlord>>;
  let other: Awaited<ReturnType<typeof registerLandlord>>;
  let property: any;
  let room: any;
  let tenant: any;
  let lease: any;
  let invoice: any;
  let tenantToken: string;
  let staffToken: string;
  let otherTenantToken: string;
  let foreignTenant: any;
  const api = (path: string, init: { method?: string; token?: string; body?: unknown } = {}) => requestJson(harness.baseUrl, `/api/v1${path}`, { token: owner.accessToken, ...init });

  beforeAll(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    owner = await registerLandlord(harness.baseUrl, 'p1-owner');
    other = await registerLandlord(harness.baseUrl, 'p1-other');
    property = await createProperty(harness.baseUrl, owner.accessToken);
    room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    tenant = await createTenant(harness.baseUrl, owner.accessToken);
    lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const jwt = new JwtService({ secret: harness.app.get(ConfigService).getOrThrow('JWT_ACCESS_SECRET') });
    const makeUser = async (role: 'TENANT' | 'STAFF') => harness.prisma.user.create({ data: { fullName: 'P1 test account', email: `${randomUUID()}@example.com`, passwordHash: 'not-used-by-jwt-tests', role } });
    const tenantUser = await makeUser('TENANT');
    await harness.prisma.tenant.update({ where: { id: tenant.id }, data: { userId: tenantUser.id } });
    tenantToken = jwt.sign({ sub: tenantUser.id, typ: 'access', ver: 0 });
    const staffUser = await makeUser('STAFF');
    await harness.prisma.staffProfile.create({ data: { userId: staffUser.id, landlordId: owner.user.id, fullName: 'Read only', permissions: ['room.view', 'operation.view', 'notification.view', 'billing.view'] } });
    staffToken = jwt.sign({ sub: staffUser.id, typ: 'access', ver: 0 });
    const otherTenantUser = await makeUser('TENANT');
    foreignTenant = await harness.prisma.tenant.create({ data: { userId: otherTenantUser.id, landlordId: other.user.id, fullName: 'Other landlord tenant' } });
    otherTenantToken = jwt.sign({ sub: otherTenantUser.id, typ: 'access', ver: 0 });
  });
  afterAll(async () => {
    jest.restoreAllMocks();
    if (harness) await closeE2eHarness(harness);
  });

  test('ending a lease creates exactly one turnover and keeps the room unavailable', async () => {
    const ended = await api(`/leases/${lease.id}/end`, { method: 'POST' });
    expect(ended.status).toBe(201);
    expect((await api(`/leases/${lease.id}/end`, { method: 'POST' })).status).toBe(201);
    expect(await harness.prisma.roomTurnover.count({ where: { roomId: room.id } })).toBe(1);
    expect((await harness.prisma.room.findUniqueOrThrow({ where: { id: room.id } })).status).toBe('MAINTENANCE');
    expect((await api(`/rooms/${room.id}`, { method: 'PATCH', body: { status: 'vacant' } })).status).toBe(409);
    expect((await api('/leases', { method: 'POST', body: { roomId: room.id, tenantId: tenant.id, monthlyRent: 3500000 } })).status).toBe(409);
  });

  test('turnover scopes, version checks and ordered completion prevent skipping steps', async () => {
    const feed = await api('/operations/turnovers');
    let current = feed.json!.data[0];
    expect(current.steps).toHaveLength(4);
    expect((await api(`/operations/turnovers/${current.id}/advance`, { token: other.accessToken, method: 'POST', body: { version: current.version, stage: current.stage, note: 'Done' } })).status).toBe(404);
    expect((await api(`/operations/turnovers/${current.id}/advance`, { token: staffToken, method: 'POST', body: { version: current.version, stage: current.stage, note: 'Done' } })).status).toBe(403);
    expect((await api(`/operations/turnovers/${current.id}/advance`, { method: 'POST', body: { version: current.version, stage: 'CLEANING', note: 'Skip' } })).status).toBe(409);
    for (const stage of ['RETURNED', 'INSPECTION', 'REPAIR', 'CLEANING']) {
      expect(current.stage).toBe(stage);
      const result = await api(`/operations/turnovers/${current.id}/advance`, { method: 'POST', body: { version: current.version, stage, note: `${stage} completed` } });
      expect(result.status).toBe(201);
      current = result.json!.data;
    }
    expect(current.stage).toBe('READY');
    expect(current.status).toBe('COMPLETED');
    expect(current.steps.every((step: any) => step.completedAt && step.completedBy)).toBe(true);
    expect((await harness.prisma.room.findUniqueOrThrow({ where: { id: room.id } })).status).toBe('VACANT');
    lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    invoice = await harness.prisma.invoice.create({ data: { roomId: room.id, tenantId: tenant.id, leaseId: lease.id, billingMonth: new Date('2026-10-01'), rentAmount: 3500000, totalAmount: 3500000 } });
  });

  test('recurrence generates occurrences once and protects concurrent checklist updates', async () => {
    const result = await api('/operations/recurring', { method: 'POST', body: { propertyId: property.id, roomId: room.id, title: 'Meter readings', kind: 'meter_reading', frequency: 'MONTHLY', interval: 1, nextRunAt: new Date(Date.now() - 1000).toISOString(), checklist: ['Electricity', 'Water'] } });
    expect(result.status).toBe(201);
    const recurring = harness.app.get(RecurringService);
    await Promise.all([recurring.generateDue(), recurring.generateDue()]);
    const tasks = await api('/operations/tasks');
    expect(tasks.json!.total).toBe(1);
    const task = tasks.json!.data[0];
    const results = await Promise.all([0, 1].map(index => api(`/operations/tasks/${task.id}/checklist`, { method: 'PATCH', body: { version: task.version, index, done: true } })));
    expect(results.map(value => value.status).sort()).toEqual([200, 409]);
    const updated = await harness.prisma.operationTask.findUniqueOrThrow({ where: { id: task.id } });
    const items = updated.checklist as { done: boolean }[];
    expect(items.filter(item => item.done)).toHaveLength(1);
    const final = await api(`/operations/tasks/${task.id}/checklist`, { method: 'PATCH', body: { version: updated.version, index: items.findIndex(item => !item.done), done: true } });
    expect(final.json!.data.status).toBe('COMPLETED');
    expect(final.json!.data.completedBy).toBe(owner.user.id);
    expect((await api(`/operations/recurring/${result.json!.data.id}`, { method: 'PATCH', body: { isEnabled: false } })).status).toBe(200);
    expect((await api('/operations/recurring', { method: 'POST', token: staffToken, body: {} })).status).toBe(403);
  });

  test('announcements support templates, groups, immutable recipient snapshots and read receipts', async () => {
    const group = await api('/announcements/groups', { method: 'POST', body: { name: 'Residents', tenantIds: [tenant.id] } });
    expect(group.status).toBe(201);
    expect((await api('/announcements/templates', { method: 'POST', body: { name: 'Water', title: 'Water outage', body: 'Water supply returns tomorrow.' } })).status).toBe(201);
    const sendAt = new Date(Date.now() + 60000);
    const result = await api('/announcements', { method: 'POST', body: { audience: 'GROUP', groupId: group.json!.data.id, title: 'Scheduled notice', body: 'Content', sendAt: sendAt.toISOString() } });
    expect(result.status).toBe(201);
    expect((await api('/tenant/announcements', { token: tenantToken })).json!.data).toHaveLength(0);
    expect((await api(`/tenant/announcements/${result.json!.data.id}/read`, { method: 'POST', token: tenantToken })).status).toBe(404);
    await harness.app.get(AnnouncementsService).sendDue(new Date(sendAt.getTime() + 1000));
    const announcements = await api('/tenant/announcements', { token: tenantToken });
    expect(announcements.json!.data).toHaveLength(1);
    expect(announcements.json!.data[0].tenantIds).toBeUndefined();
    expect((await api(`/tenant/announcements/${result.json!.data.id}/read`, { token: otherTenantToken, method: 'POST' })).status).toBe(404);
    const read = await api(`/tenant/announcements/${result.json!.data.id}/read`, { token: tenantToken, method: 'POST' });
    expect(read.status).toBe(201);
    expect((await api(`/tenant/announcements/${result.json!.data.id}/read`, { token: tenantToken, method: 'POST' })).json!.data.readAt).toBe(read.json!.data.readAt);
    const receipts = await api(`/announcements/${result.json!.data.id}/receipts`);
    expect(receipts.json!.data[0].tenant.fullName).toBe(tenant.fullName);
    expect(receipts.json!.data[0].readAt).not.toBeNull();
    expect((await api('/announcements', { method: 'POST', body: { audience: 'TENANTS', tenantIds: [foreignTenant.id], title: 'Cross landlord', body: 'Not allowed' } })).status).toBe(400);
    const cancelled = await api('/announcements', { method: 'POST', body: { audience: 'ROOM', propertyId: property.id, roomId: room.id, title: 'Cancelled notice', body: 'Not sent', sendAt: new Date(Date.now() + 600000).toISOString() } });
    expect((await api(`/announcements/${cancelled.json!.data.id}/cancel`, { method: 'POST' })).status).toBe(201);
    expect((await api('/announcements', { method: 'POST', token: staffToken, body: {} })).status).toBe(403);
  });

});
