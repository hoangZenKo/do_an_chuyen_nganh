import { AuthService } from '../../src/auth/auth.service';
import { SavedSearchesService } from '../../src/listings/saved-searches.service';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createTenant, resetDatabase, testPassword, uniqueEmail } from './e2e-fixtures';

describe('Security and discovery regressions', () => {
  let harness: E2eHarness;
  let owner: string, ownerId: string, student: string, studentId: string, other: string, admin: string;
  let roomId: string, propertyId: string;
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64');
  const content = {
    title: 'Regression room for students', description: 'Synthetic room listing for isolated automated tests.',
    imageUrls: ['https://example.test/room.jpg'], city: 'Test city', district: 'Test district', publicAddress: 'Public test address',
    monthlyRent: 1000000, deposit: 1000000, electricityPrice: 3500, waterPrice: 15000, serviceFee: 100000,
    parkingFee: 100000, areaSqm: 20, amenities: [],
  };
  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => {
    await resetDatabase(harness.prisma);
    const auth = harness.app.get(AuthService);
    const input = (name: string) => ({ fullName: name, email: uniqueEmail(name), phone: '+84901234567', password: testPassword });
    const landlord = (await auth.register(input('owner'))).data;
    owner = landlord.accessToken; ownerId = landlord.user.id;
    const seeker = (await auth.registerSeeker(input('student'))).data;
    student = seeker.accessToken; studentId = seeker.user.id;
    other = (await auth.registerSeeker(input('other'))).data.accessToken;
    const account = await createAdmin(harness.prisma);
    admin = (await auth.login({ email: account.email, password: testPassword })).data.accessToken;
    propertyId = (await harness.prisma.property.create({ data: { landlordId: ownerId, name: 'Regression property', address: 'Private address' } })).id;
    roomId = (await harness.prisma.room.create({ data: { propertyId, name: 'Regression room', basePrice: 1000000 } })).id;
  });
  const call = (path: string, token?: string, body?: unknown, method = body === undefined ? 'GET' : 'POST') =>
    requestJson(harness.baseUrl, '/api/v1' + path, { token, body, method });
  async function upload(token: string, bytes = png, purpose = 'PRIVATE') {
    const form = new FormData(); form.append('file', new Blob([new Uint8Array(bytes)], { type: 'image/png' }), 'fixture.png'); form.append('purpose', purpose);
    const response = await fetch(harness.baseUrl + '/api/v1/uploads', { method: 'POST', headers: { authorization: 'Bearer ' + token }, body: form });
    return { status: response.status, json: await response.json() as any };
  }
  async function leaseFixture() {
    const tenant = await createTenant(harness.baseUrl, owner, 'Regression tenant');
    await harness.prisma.tenant.update({ where: { id: tenant.id }, data: { userId: studentId } });
    const lease = await createLease(harness.baseUrl, owner, roomId, tenant.id, 1000000);
    const invoice = await call('/billing/invoices', owner, { leaseId: lease.id, billingMonth: '2026-10-01T00:00:00.000Z' });
    expect(invoice.status).toBe(201);
    return { tenant, lease, invoice: invoice.json.data };
  }
  async function publish() {
    return harness.prisma.roomListing.create({ data: { ...content, roomId, status: 'PUBLISHED', publishedAt: new Date(), availabilityConfirmedAt: new Date() } });
  }
  it('serializes duplicate proof approvals and competing refunds', async () => {
    const { invoice, tenant, lease } = await leaseFixture();
    const proof = await harness.prisma.paymentProof.create({ data: { invoiceId: invoice.id, tenantId: tenant.id, amount: 100000 } });
    const approvals = await Promise.all([1, 2].map(() => call(`/billing/payment-proofs/${proof.id}/review`, owner, { status: 'approved' })));
    expect(approvals.map(result => result.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(1);
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).paidAmount).toBe(100000);
    expect((await call(`/leases/${lease.id}/deposits`, owner, { type: 'refunded', amount: 1500000 })).status).toBe(409);
    const refunds = await Promise.all([1, 2].map(() => call(`/leases/${lease.id}/deposits`, owner, { type: 'refunded', amount: 600000 })));
    expect(refunds.map(result => result.status).sort()).toEqual([201, 409]);
    const balances = await call(`/rooms/${roomId}/leases`, owner);
    expect(balances.json.data[0].depositBalance).toBe(400000);
  });
  it('keeps receipts private, validates bytes and permits only authorized sharing', async () => {
    const { invoice } = await leaseFixture();
    const file = await upload(student); expect(file.status).toBe(201);
    const url = file.json.data.url;
    expect((await fetch(harness.baseUrl + url)).status).toBe(404);
    expect((await call(`/uploads/${file.json.data.fileName}/access`, other)).status).toBe(404);
    expect((await call(`/uploads/${file.json.data.fileName}/access`, owner)).status).toBe(404);
    expect((await call(`/tenant/invoices/${invoice.id}/payment-proofs`, student, { amount: 100000, proofImageUrls: [url] })).status).toBe(201);
    const access = await call(`/uploads/${file.json.data.fileName}/access`, owner);
    expect(access.status).toBe(200);
    const response = await fetch(harness.baseUrl + access.json.data.url);
    expect(response.status).toBe(200);
    expect(response.headers.get('x-content-type-options')).toBe('nosniff');
    expect(response.headers.get('cache-control')).toContain('no-store');
    expect((await fetch(harness.baseUrl + access.json.data.url + 'tampered')).status).toBe(404);
    const signed = new URL(access.json.data.url, harness.baseUrl).searchParams.get('access')!;
    const payload = JSON.parse(Buffer.from(signed.split('.')[0], 'base64url').toString());
    payload.exp = Date.now() - 1000;
    const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = createHmac('sha256', harness.app.get(ConfigService).getOrThrow<string>('JWT_ACCESS_SECRET')).update('upload-access:' + body).digest('base64url');
    expect((await fetch(`${harness.baseUrl}${url}?access=${body}.${signature}`)).status).toBe(404);
    const account = await harness.prisma.user.findUniqueOrThrow({ where: { id: ownerId } });
    const staff = await harness.prisma.user.create({ data: { fullName: 'Scoped staff', email: uniqueEmail('staff'), passwordHash: account.passwordHash, role: 'STAFF',
      staffProfile: { create: { landlordId: ownerId, fullName: 'Scoped staff', permissions: ['room.view'] } } } });
    const staffToken = (await harness.app.get(AuthService).issueSession(staff)).data.accessToken;
    expect((await call(`/uploads/${file.json.data.fileName}/access`, staffToken)).status).toBe(404);
    await harness.prisma.staffProfile.update({ where: { userId: staff.id }, data: { permissions: ['billing.view'] } });
    expect((await call(`/uploads/${file.json.data.fileName}/access`, staffToken)).status).toBe(200);
    const stolen = await upload(other);
    expect((await call(`/tenant/invoices/${invoice.id}/payment-proofs`, student, { amount: 100000, proofImageUrls: [stolen.json.data.url] })).status).toBe(400);
    expect((await upload(student, Buffer.from('<html>not an image</html>'))).status).toBe(400);
    expect((await upload(student, png, 'PUBLIC_LISTING')).status).toBe(400);
    const photo = await upload(owner, png, 'PUBLIC_LISTING');
    expect((await fetch(harness.baseUrl + photo.json.data.url)).status).toBe(200);
  });
  it('revokes other sessions, refresh tokens and private file links on password change', async () => {
    const auth = harness.app.get(AuthService);
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { id: studentId } });
    const second = (await auth.login({ email: user.email, password: testPassword })).data;
    const file = await upload(student);
    const access = await call(`/uploads/${file.json.data.fileName}/access`, second.accessToken);
    expect((await call('/auth/change-password', student, { currentPassword: testPassword, newPassword: 'NewSecurePassword!456' })).status).toBe(204);
    expect((await call('/auth/me', second.accessToken)).status).toBe(401);
    expect((await call('/auth/refresh', undefined, { refreshToken: second.refreshToken })).status).toBe(401);
    expect((await fetch(harness.baseUrl + access.json.data.url)).status).toBe(404);
    expect((await auth.login({ email: user.email, password: 'NewSecurePassword!456' })).data.accessToken).toBeTruthy();
  });
  it('returns validation errors rather than server errors for invalid dates', async () => {
    const tenant = await createTenant(harness.baseUrl, owner, 'Date fixture');
    expect((await call('/reports/monthly?month=not-a-date', owner)).status).toBe(400);
    expect((await call('/leases', owner, { roomId, tenantId: tenant.id, monthlyRent: 1000000, startDate: 'not-a-date' })).status).toBe(400);
  });
  it('filters by full estimated budget and availability freshness', async () => {
    const listing = await publish();
    const included = await call('/public/listings?maxBudget=1420000');
    expect(included.json.meta.total).toBe(1);
    expect(included.json.data[0].estimatedMonthlyCost).toBe(1420000);
    expect((await call('/public/listings?maxBudget=1419999')).json.meta.total).toBe(0);
    expect((await call('/public/listings?maxBudget=1200000&electricityKwh=0&waterM3=0')).json.meta.total).toBe(1);
    expect((await call('/public/listings?electricityKwh=-1')).status).toBe(400);
    expect((await call('/public/listings?freshOnly=true')).json.meta.total).toBe(1);
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { availabilityConfirmedAt: new Date(Date.now() - 15 * 86400000) } });
    expect((await call('/public/listings?freshOnly=true')).json.meta.total).toBe(0);
    expect((await call('/listings', owner)).json.data[0].needsAvailabilityConfirmation).toBe(true);
    expect((await call(`/listings/${listing.id}/confirm-availability`, owner, { version: listing.version })).status).toBe(201);
    expect((await call('/public/listings?freshOnly=true')).json.meta.total).toBe(1);
  });
  it('allows only admins to manage real campus coordinates and active state', async () => {
    const campus = { name: 'Test school', campus: 'Main campus', city: 'Test city', address: 'Test street', latitude: 21, longitude: 105, sourceUrl: 'https://example.test/campus' };
    expect((await call('/admin/campuses', owner, campus)).status).toBe(403);
    const created = await call('/admin/campuses', admin, campus);
    expect(created.status).toBe(201); expect(created.json.data.isDemo).toBe(false);
    const id = created.json.data.id;
    expect((await call(`/admin/campuses/${id}`, admin, { ...campus, latitude: 100, isActive: true }, 'PATCH')).status).toBe(400);
    expect((await call(`/admin/campuses/${id}`, admin, { ...campus, isActive: false }, 'PATCH')).status).toBe(200);
    expect((await call('/public/campuses')).json.data.some((item: any) => item.id === id)).toBe(false);
    expect((await call('/admin/campuses', admin)).json.data.some((item: any) => item.id === id)).toBe(true);
  });
  it('saves filters, sends deduplicated in-app alerts and enforces account boundaries', async () => {
    expect((await call('/student/searches', student, { name: 'Missing filters' })).status).toBe(400);
    const saved = await call('/student/searches', student, { name: 'Student budget', filters: { maxBudget: 1500000 } });
    expect(saved.status).toBe(201);
    expect((await call('/student/searches/alerts', student)).json.meta.total).toBe(0);
    const listing = await publish();
    const alerts = await call('/student/searches/alerts', student);
    expect(alerts.json.meta.total).toBe(1); expect(alerts.json.meta.unread).toBe(1);
    expect(alerts.json.data[0].listing.id).toBe(listing.id);
    expect((await call('/student/searches/alerts', student)).json.meta.total).toBe(1);
    const id = saved.json.data.id, alertId = alerts.json.data[0].id;
    expect((await call(`/student/searches/alerts/${alertId}/read`, other, {})).status).toBe(404);
    expect((await call(`/student/searches/${id}`, other, { enabled: false }, 'PATCH')).status).toBe(404);
    expect((await call(`/student/searches/alerts/${alertId}/read`, student, {})).status).toBe(201);
    expect((await call('/student/searches/alerts', student)).json.meta.unread).toBe(0);
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { status: 'HIDDEN' } });
    expect((await call('/student/searches/alerts', student)).json.meta.total).toBe(0);
    expect((await call(`/student/searches/${id}`, student, undefined, 'DELETE')).status).toBe(200);
  });
  it('does not alert for historical listings, paused searches or more than ten saved searches', async () => {
    await publish();
    const saved = await call('/student/searches', student, { name: 'Historical filter', filters: {} });
    expect((await call('/student/searches/alerts', student)).json.meta.total).toBe(0);
    await call(`/student/searches/${saved.json.data.id}`, student, { enabled: false }, 'PATCH');
    await harness.prisma.roomListing.updateMany({ data: { publishedAt: new Date() } });
    expect((await call('/student/searches/alerts', student)).json.meta.total).toBe(0);
    for (let index = 1; index < 10; index++) expect((await call('/student/searches', student, { name: `Filter ${index}`, filters: {} })).status).toBe(201);
    expect((await call('/student/searches', student, { name: 'Too many filters', filters: {} })).status).toBe(409);
  });
  it('scans all matching pages without truncating notifications at fifty', async () => {
    await call('/student/searches', student, { name: 'Many new rooms', filters: {} });
    await new Promise(resolve => setTimeout(resolve, 5));
    const publishedAt = new Date();
    for (let index = 0; index < 55; index++) {
      const room = await harness.prisma.room.create({ data: { propertyId, name: `Room ${index}`, basePrice: 1000000 } });
      await harness.prisma.roomListing.create({ data: { ...content, roomId: room.id, status: 'PUBLISHED', publishedAt } });
    }
    await harness.app.get(SavedSearchesService).scanAll(studentId);
    const alerts = await call('/student/searches/alerts', student);
    expect(alerts.json.meta.total).toBe(55); expect(alerts.json.data).toHaveLength(20);
    expect((await call('/student/searches/alerts?page=3', student)).json.data).toHaveLength(15);
    expect(await harness.prisma.savedSearchMatch.count()).toBe(55);
  });
});
