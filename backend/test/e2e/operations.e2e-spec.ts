import { randomUUID } from 'node:crypto';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Landlord operations E2E', () => {
  let harness: E2eHarness;
  let owner: Awaited<ReturnType<typeof registerLandlord>>;
  let other: Awaited<ReturnType<typeof registerLandlord>>;
  let property: any;
  let secondProperty: any;
  let room: any;
  let tenant: any;
  let lease: any;
  let viewing: any;
  let invoice: any;
  let ticket: any;
  let proof: any;
  let inspection: any;
  let jwt: JwtService;

  beforeAll(async () => {
    harness = await createE2eHarness();
    jwt = new JwtService({ secret: harness.app.get(ConfigService).getOrThrow('JWT_ACCESS_SECRET') });
    await resetDatabase(harness.prisma);
    owner = await registerLandlord(harness.baseUrl, 'operations-owner');
    other = await registerLandlord(harness.baseUrl, 'operations-other');
    property = await createProperty(harness.baseUrl, owner.accessToken);
    secondProperty = await createProperty(harness.baseUrl, owner.accessToken, 'Second property');
    room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    tenant = await createTenant(harness.baseUrl, owner.accessToken);
    lease = await createLease(harness.baseUrl, owner.accessToken, room.id, tenant.id);
    const now = new Date();
    const offset = (days: number) => new Date(now.getTime() + days * 86400000);
    await harness.prisma.lease.update({ where: { id: lease.id }, data: { endDate: offset(14) } });
    const listing = await harness.prisma.roomListing.create({ data: {
      roomId: room.id, title: 'Operations listing', description: 'Private operational fixture',
      imageUrls: [], amenities: [], city: 'HCM', district: 'District 1', publicAddress: 'Test',
      monthlyRent: 3500000, areaSqm: 25,
    } });
    viewing = await harness.prisma.roomViewing.create({ data: {
      listingId: listing.id, landlordId: owner.user.id, studentId: other.user.id,
      scheduledAt: offset(1), endsAt: new Date(offset(1).getTime() + 3600000),
    } });
    invoice = await harness.prisma.invoice.create({ data: {
      leaseId: lease.id, roomId: room.id, tenantId: tenant.id, billingMonth: offset(-30),
      rentAmount: 3500000, totalAmount: 3500000, dueDate: offset(-2),
    } });
    proof = await harness.prisma.paymentProof.create({ data: {
      invoiceId: invoice.id, tenantId: tenant.id, amount: 3500000,
    } });
    ticket = await harness.prisma.maintenanceTicket.create({ data: {
      landlordId: owner.user.id, propertyId: property.id, roomId: room.id,
      title: 'Water leak', priority: 'URGENT',
    } });
    inspection = await harness.prisma.roomInspection.create({ data: {
      roomId: room.id, title: 'Electrical safety', dueAt: offset(2),
    } });
    const secondRoom = await createRoom(harness.baseUrl, owner.accessToken, secondProperty.id);
    await harness.prisma.maintenanceTicket.create({ data: {
      landlordId: owner.user.id, propertyId: secondProperty.id, roomId: secondRoom.id,
      title: 'Door repair', priority: 'MEDIUM',
    } });
  });

  afterAll(async () => { if (harness) await closeE2eHarness(harness); });

  function get(query = '', token = owner.accessToken) {
    return requestJson<any>(harness.baseUrl, `/api/v1/operations/action-items${query}`, { token });
  }

  it('aggregates all categories with truthful counts, dates and exact destinations', async () => {
    const result = await get();
    expect(result.status).toBe(200);
    expect(result.json!.data.summary).toMatchObject({
      total: 7, unread: 7, pendingViewings: 1, overdueInvoices: 1, pendingPaymentProofs: 1,
      dueSoonInvoices: 0, urgentMaintenance: 1, openMaintenance: 2, expiringLeases: 1, dueInspections: 1,
    });
    const items = result.json!.data.items;
    expect(new Set(items.map((item: any) => item.id)).size).toBe(7);
    expect(items.find((item: any) => item.resourceId === viewing.id).actionRoute).toBe(`/housing/viewings?viewingId=${viewing.id}`);
    expect(items.find((item: any) => item.resourceId === proof.id).actionRoute).toBe(`/billing/${invoice.id}?proofId=${proof.id}`);
    expect(items.find((item: any) => item.resourceId === ticket.id).actionRoute).toBe(`/maintenance?ticketId=${ticket.id}`);
    expect(items.find((item: any) => item.resourceId === lease.id).actionRoute).toBe(`/tenants/${tenant.id}`);
    expect(items.find((item: any) => item.resourceId === inspection.id).actionRoute).toBe(`/rooms/${room.id}?tab=inspections`);
    expect(items.every((item: any) => !Number.isNaN(Date.parse(item.createdAt)))).toBe(true);
    expect(items.filter((item: any) => item.severity === 'danger').length).toBe(2);
    expect(items[0].severity).toBe('danger');
    expect(result.json!.meta).toEqual({ total: 7, page: 1, limit: 20 });
  });

  it('filters by category without losing global summary counts', async () => {
    const result = await get('?category=maintenance&limit=1&page=2');
    expect(result.status).toBe(200);
    expect(result.json!.data.items).toHaveLength(1);
    expect(result.json!.data.items[0].category).toBe('maintenance');
    expect(result.json!.data.summary.total).toBe(7);
    expect(result.json!.meta).toEqual({ total: 2, page: 2, limit: 1 });
  });

  it('scopes property filters and rejects foreign properties', async () => {
    const result = await get(`?propertyId=${secondProperty.id}`);
    expect(result.status).toBe(200);
    expect(result.json!.data.items).toHaveLength(1);
    expect(result.json!.data.summary.total).toBe(1);
    expect((await get(`?propertyId=${property.id}`, other.accessToken)).status).toBe(404);
    expect((await get(`?propertyId=${randomUUID()}`)).status).toBe(404);
  });

  it('never reveals another landlord actions', async () => {
    const result = await get('', other.accessToken);
    expect(result.status).toBe(200);
    expect(result.json!.data.items).toEqual([]);
    expect(result.json!.data.summary.total).toBe(0);
  });

  it.each(['page=0', 'page=1.5', 'limit=51', 'limit=0', 'category=unknown', 'propertyId=invalid'])(
    'validates query %s', async query => { expect((await get(`?${query}`)).status).toBe(400); },
  );

  it('paginates deterministically with no duplicate or missing items', async () => {
    const first = (await get('?limit=3')).json!;
    const second = (await get('?limit=3&page=2')).json!;
    const third = (await get('?limit=3&page=3')).json!;
    expect(new Set([...first.data.items, ...second.data.items, ...third.data.items].map(item => item.id)).size).toBe(7);
    expect((await get('?limit=3&page=4')).json!.data.items).toEqual([]);
  });

  it('supports existing notification read records and idempotent action reads', async () => {
    const id = `viewing-pending-${viewing.id}`;
    const read = () => requestJson(harness.baseUrl, `/api/v1/operations/action-items/${id}/read`, {
      token: owner.accessToken, method: 'POST',
    });
    expect((await read()).status).toBe(201);
    expect((await read()).status).toBe(201);
    const legacyId = `invoice-overdue-${invoice.id}`;
    expect((await requestJson(harness.baseUrl, `/api/v1/notifications/${legacyId}/read`, {
      token: owner.accessToken, method: 'POST',
    })).status).toBe(201);
    const result = await get();
    expect(result.json!.data.summary.unread).toBe(5);
    expect(result.json!.data.items.find((item: any) => item.id === id).isRead).toBe(true);
    expect((await requestJson(harness.baseUrl, `/api/v1/operations/action-items/${id}/read`, {
      token: other.accessToken, method: 'POST',
    })).status).toBe(404);
  });

  async function staffToken(permissions: string[]) {
    const user = await harness.prisma.user.create({ data: {
      fullName: 'Operations staff', email: `${randomUUID()}@test.com`, role: 'STAFF',
      passwordHash: 'unused', staffProfile: { create: {
        landlordId: owner.user.id, fullName: 'Operations staff', permissions,
      } },
    } });
    return jwt.sign({ sub: user.id, typ: 'access' });
  }

  it('filters staff counts and rows by resource permissions, without notification permission', async () => {
    const token = await staffToken(['operation.view', 'maintenance.view']);
    const result = await get('', token);
    expect(result.status).toBe(200);
    expect(result.json!.data.summary).toMatchObject({ total: 2, pendingViewings: 0, overdueInvoices: 0, openMaintenance: 2 });
    expect(result.json!.data.categories).toEqual(['maintenance']);
    expect((await get('?category=invoice', token)).status).toBe(403);
    expect((await requestJson(harness.baseUrl, `/api/v1/operations/action-items/maintenance-urgent-${ticket.id}/read`, {
      token, method: 'POST',
    })).status).toBe(201);
    expect((await get('', token)).json!.data.summary.unread).toBe(1);
    expect((await requestJson(harness.baseUrl, `/api/v1/operations/action-items/viewing-pending-${viewing.id}/read`, {
      token, method: 'POST',
    })).status).toBe(404);
  });

  it('requires operation permission and returns no inaccessible resources', async () => {
    expect((await get('', await staffToken(['maintenance.view']))).status).toBe(403);
    const empty = await get('', await staffToken(['operation.view']));
    expect(empty.status).toBe(200);
    expect(empty.json!.data.items).toEqual([]);
    expect(empty.json!.data.summary.total).toBe(0);
  });

  it('rejects anonymous, tenant and admin callers', async () => {
    expect((await get('', '')).status).toBe(401);
    const admin = await createAdmin(harness.prisma, 'operations-admin');
    expect((await get('', (await login(harness.baseUrl, admin.email)).accessToken)).status).toBe(403);
    const user = await harness.prisma.user.create({ data: {
      email: `${randomUUID()}@test.com`, fullName: 'Tenant', role: 'TENANT', passwordHash: 'unused',
    } });
    const token = jwt.sign({ sub: user.id, typ: 'access' });
    expect((await get('', token)).status).toBe(403);
  });

  it('removes resolved tasks and distinguishes due-soon, nonurgent and expired tasks', async () => {
    const now = new Date();
    await harness.prisma.roomViewing.update({ where: { id: viewing.id }, data: { status: 'CONFIRMED' } });
    await harness.prisma.paymentProof.update({ where: { id: proof.id }, data: { status: 'APPROVED' } });
    await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { status: 'PAID', paidAmount: 3500000 } });
    await harness.prisma.maintenanceTicket.update({ where: { id: ticket.id }, data: { status: 'DONE' } });
    await harness.prisma.roomInspection.update({ where: { id: inspection.id }, data: { completedAt: now } });
    await harness.prisma.lease.update({ where: { id: lease.id }, data: { endDate: new Date(now.getTime() - 86400000) } });
    let result = await get();
    expect(result.json!.data.summary).toMatchObject({ total: 2, pendingViewings: 0, pendingPaymentProofs: 0, overdueInvoices: 0, urgentMaintenance: 0, dueInspections: 0 });
    expect(result.json!.data.items.find((item: any) => item.resourceId === lease.id).severity).toBe('danger');
    await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { status: 'PARTIAL', paidAmount: 1000000, dueDate: new Date(now.getTime() + 2 * 86400000) } });
    result = await get('?category=invoice');
    expect(result.json!.data.summary.dueSoonInvoices).toBe(1);
    expect(result.json!.data.items[0].body).toContain('2.500.000');
  });
});
