import { randomUUID } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import * as argon2 from 'argon2';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { assertE2eDatabase, createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase, testPassword } from './e2e-fixtures';

describe('Maintenance audit (isolated database)', () => {
  let harness: E2eHarness;
  let ownerToken: string, ownerId: string, tenantToken: string, tenantId: string;
  let propertyId: string, roomId: string, leaseId: string;
  const call = (path: string, token = ownerToken, method = 'GET', body?: unknown) =>
    requestJson(harness.baseUrl, `/api/v1/${path}`, { token, method, body });
  const create = async (body: Record<string, unknown> = {}) => {
    const response = await call('maintenance', ownerToken, 'POST', { propertyId, roomId, title: 'QA repair', ...body });
    expect(response.status).toBe(201);
    return response.json!.data;
  };
  beforeAll(async () => {
    assertE2eDatabase();
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const owner = await registerLandlord(harness.baseUrl, 'repair-audit');
    ownerToken = owner.accessToken; ownerId = owner.user.id;
    propertyId = (await createProperty(harness.baseUrl, ownerToken)).id;
    roomId = (await createRoom(harness.baseUrl, ownerToken, propertyId)).id;
    tenantId = (await createTenant(harness.baseUrl, ownerToken)).id;
    leaseId = (await createLease(harness.baseUrl, ownerToken, roomId, tenantId)).id;
    const email = `${randomUUID()}@repair.test`;
    const user = await harness.prisma.user.create({ data: { fullName: 'Repair tenant QA', email, role: 'TENANT', passwordHash: await argon2.hash(testPassword) } });
    await harness.prisma.tenant.update({ where: { id: tenantId }, data: { userId: user.id } });
    tenantToken = (await login(harness.baseUrl, email)).accessToken;
  });
  afterAll(async () => { if (harness) await closeE2eHarness(harness); });

  it('rejects blank titles and comments after trimming, for both roles', async () => {
    const ticket = await create();
    for (const token of [ownerToken, tenantToken]) {
      const prefix = token === ownerToken ? 'maintenance' : 'tenant/maintenance';
      expect((await call(prefix, token, 'POST', { ...(token === ownerToken ? { propertyId, roomId } : {}), title: '   ' })).status).toBe(400);
      expect((await call(`${prefix}/${ticket.id}/comments`, token, 'POST', { body: '   ' })).status).toBe(400);
    }
    expect((await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { title: '   ' })).status).toBe(400);
  });
  it('rejects null patch strings rather than throwing HTTP 500', async () => {
    const ticket = await create();
    for (const field of ['title', 'description', 'note', 'imageUrls', 'actualCost']) {
      expect((await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { [field]: null })).status).toBe(400);
    }
  });
  it('does not return landlord internal notes in tenant list or dashboard', async () => {
    const ticket = await create({ note: 'PRIVATE-LANDLORD-NOTE' });
    expect((await call('maintenance')).text).toContain('PRIVATE-LANDLORD-NOTE');
    expect((await call('tenant/maintenance', tenantToken)).text).not.toContain('PRIVATE-LANDLORD-NOTE');
    expect((await call('tenant/dashboard', tenantToken)).text).not.toContain('PRIVATE-LANDLORD-NOTE');
    expect((await call(`tenant/maintenance/${ticket.id}/comments`, tenantToken, 'POST', { body: 'Tenant reply' })).status).toBe(201);
  });
  it('cannot read or comment on tickets before the current tenancy', async () => {
    const old = await create();
    await harness.prisma.maintenanceTicket.update({ where: { id: old.id }, data: { createdAt: new Date('2020-01-01') } });
    const list = await call('tenant/maintenance', tenantToken);
    expect(list.json!.data.map((ticket: { id: string }) => ticket.id)).not.toContain(old.id);
    expect((await call(`tenant/maintenance/${old.id}/comments`, tenantToken, 'POST', { body: 'Not my tenancy' })).status).toBe(404);
  });
  it('creates only one expense when completion is retried concurrently', async () => {
    const ticket = await create();
    const results = await Promise.all([1, 2].map(() => call(`maintenance/${ticket.id}/complete`, ownerToken, 'POST', { actualCost: 125000, createExpense: true })));
    expect(results.map(result => result.status)).toEqual([201, 201]);
    expect(results[0].json!.data.expenseId).toBe(results[1].json!.data.expenseId);
    expect((await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { actualCost: 1 })).status).toBe(409);
  });
  it('records lifecycle timestamps when status is changed through the edit endpoint', async () => {
    const ticket = await create();
    const started = await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { status: 'in_progress' });
    expect(started.status).toBe(200);
    expect(started.json!.data.startedAt).toEqual(expect.any(String));
    const done = await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { status: 'done' });
    expect(done.status).toBe(200);
    expect(done.json!.data.completedAt).toEqual(expect.any(String));
    const edited = await call(`maintenance/${ticket.id}`, ownerToken, 'PATCH', { title: 'Edited completed repair' });
    expect(edited.json!.data.completedAt).toBe(done.json!.data.completedAt);
  });
  it('denies cross-landlord tickets and platform admin writes', async () => {
    const ticket = await create();
    const stranger = await registerLandlord(harness.baseUrl, 'repair-stranger');
    expect((await call(`maintenance/${ticket.id}`, stranger.accessToken)).status).toBe(404);
    expect((await call(`maintenance/${ticket.id}/comments`, stranger.accessToken, 'POST', { body: 'No access' })).status).toBe(404);
    const admin = await createAdmin(harness.prisma, 'repairs-admin');
    const adminSession = await login(harness.baseUrl, admin.email);
    expect((await call('maintenance', adminSession.accessToken)).status).toBe(403);
    expect((await call(`maintenance/${ticket.id}/complete`, adminSession.accessToken, 'POST', {})).status).toBe(403);
  });
  it('keeps staff authorship and does not bypass complete permission with PATCH', async () => {
    const email = `${randomUUID()}@repair-staff.test`;
    await harness.prisma.user.create({ data: { email, fullName: 'Repair staff', role: 'STAFF', passwordHash: await argon2.hash(testPassword), staffProfile: { create: {
      landlordId: ownerId, fullName: 'Repair staff', permissions: ['maintenance.view', 'maintenance.manage'], propertyScopes: { create: { propertyId, landlordId: ownerId } },
    } } } });
    const token = (await login(harness.baseUrl, email)).accessToken;
    const ticket = await create();
    const comment = await call(`maintenance/${ticket.id}/comments`, token, 'POST', { body: 'Staff reply' });
    expect(comment.status).toBe(201);
    expect(comment.json!.data.authorRole).toBe('staff');
    expect((await call(`maintenance/${ticket.id}`, token, 'PATCH', { status: 'done' })).status).toBe(403);
    expect((await call(`maintenance/${ticket.id}/status`, token, 'POST', { status: 'done' })).status).toBe(403);
    const filename = `${randomUUID()}.png`;
    await harness.prisma.uploadedFile.create({ data: { filename, ownerId, mimeType: 'image/png', purpose: 'PRIVATE' } });
    await writeFile(join(harness.uploadDirectory, filename), Buffer.from('89504e470d0a1a0a00000000', 'hex'));
    await harness.prisma.maintenanceTicket.update({ where: { id: ticket.id }, data: { imageUrls: [`http://localhost:3000/uploads/${filename}`] } });
    const access = await call(`uploads/${filename}/access`, token);
    expect(access.status).toBe(200);
    expect((await fetch(new URL(access.json!.data.url, harness.baseUrl))).status).toBe(200);
    const foreignProperty = await createProperty(harness.baseUrl, ownerToken, 'Unassigned repairs property');
    const foreignRoom = await createRoom(harness.baseUrl, ownerToken, foreignProperty.id);
    await harness.prisma.maintenanceTicket.update({ where: { id: ticket.id }, data: { propertyId: foreignProperty.id, roomId: foreignRoom.id } });
    expect((await call(`uploads/${filename}/access`, token)).status).toBe(404);
    expect((await fetch(new URL(access.json!.data.url, harness.baseUrl))).status).toBe(404);
  });
  it('does not expose maintenance after the lease ends', async () => {
    const ticket = await create();
    await harness.prisma.lease.update({ where: { id: leaseId }, data: { status: 'ENDED', endDate: new Date() } });
    expect((await call('tenant/maintenance', tenantToken)).json!.data).toEqual([]);
    expect((await call(`tenant/maintenance/${ticket.id}/comments`, tenantToken, 'POST', { body: 'No longer renting' })).status).toBe(404);
  });
});
