import { ListingStatus, RoomStatus } from '@prisma/client';
import { AuthService } from '../../src/auth/auth.service';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, resetDatabase, testPassword, uniqueEmail } from './e2e-fixtures';

const content = {
  title: 'Phòng An Bình có ban công', description: 'Phòng sạch thoáng, có cửa sổ và khu vực để xe riêng.',
  imageUrls: ['https://example.com/room.jpg'], city: 'Hồ Chí Minh', district: 'Bình Thạnh',
  publicAddress: 'Đường D2', monthlyRent: 2500000, deposit: 2500000,
  electricityPrice: 3500, waterPrice: 15000, serviceFee: 100000, areaSqm: 25,
  amenities: ['Máy lạnh', 'WC riêng'],
};

describe('Room listings E2E', () => {
  let harness: E2eHarness;
  let owner: string;
  let other: string;
  let admin: string;
  let seeker: string;
  let ownerId: string;
  let roomId: string;
  let propertyId: string;

  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => {
    await resetDatabase(harness.prisma);
    const auth = harness.app.get(AuthService);
    const register = (prefix: string) => auth.register({ fullName: prefix, email: uniqueEmail(prefix), phone: '+84901234567', password: testPassword });
    const first = await register('owner');
    owner = first.data.accessToken;
    ownerId = first.data.user.id;
    other = (await register('other')).data.accessToken;
    seeker = (await auth.registerSeeker({ fullName: 'Seeker', email: uniqueEmail('seeker'), phone: '+84901234567', password: testPassword })).data.accessToken;
    const adminUser = await createAdmin(harness.prisma);
    admin = (await auth.login({ email: adminUser.email, password: testPassword })).data.accessToken;
    const property = await harness.prisma.property.create({ data: { landlordId: ownerId, name: 'Khu trọ An Bình', address: 'Private address' } });
    propertyId = property.id;
    const room = await harness.prisma.room.create({ data: { propertyId, name: 'P.101', status: RoomStatus.VACANT,
      basePrice: 2500000, tenantName: 'Private tenant', note: 'Private note' } });
    roomId = room.id;
  });

  const request = (path: string, token?: string, body?: unknown, method = 'POST') =>
    requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method });
  const get = (path: string, token?: string) => request(path, token, undefined, 'GET');
  const create = async () => {
    const result = await request('/listings', owner, { ...content, roomId });
    expect(result.status).toBe(201);
    return result.json.data;
  };
  const publish = async () => {
    const listing = await create();
    const submitted = await request(`/listings/${listing.id}/submit`, owner, { version: 1 });
    expect(submitted.status).toBe(201);
    const approved = await request(`/admin/listings/${listing.id}/review`, admin, { version: 2, decision: 'PUBLISH' });
    expect(approved.status).toBe(201);
    return approved.json.data;
  };

  it('registers a seeker without a rental profile and does not expose private portal data', async () => {
    const result = await request('/auth/register-seeker', undefined, { fullName: 'New seeker', email: uniqueEmail('new'), phone: '+84901234567', password: testPassword });
    expect(result.status).toBe(201);
    expect(result.json.data.user.role).toBe('tenant');
    expect(await harness.prisma.tenant.count({ where: { userId: result.json.data.user.id } })).toBe(0);
    const profile = await get('/tenant/me', result.json.data.accessToken);
    expect(profile.status).toBe(404);
    expect(profile.json.error.code).toBe('TENANT_PROFILE_NOT_FOUND');
    expect((await request('/auth/register-seeker', undefined, { fullName: 'Attack', email: uniqueEmail('attack'), phone: '+84901234567', password: testPassword, role: 'admin' })).status).toBe(400);
  });

  it('publishes only reviewed listings using an explicit public projection', async () => {
    const listing = await create();
    expect((await get('/public/listings')).json.meta.total).toBe(0);
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 1, decision: 'PUBLISH' })).status).toBe(409);
    expect((await request(`/listings/${listing.id}/submit`, owner, { version: 1 })).status).toBe(201);
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 2, decision: 'PUBLISH' })).status).toBe(201);
    const result = await get(`/public/listings/${listing.id}`);
    expect(result.json.data.propertyName).toBe('Khu trọ An Bình');
    for (const field of ['room', 'roomId', 'landlordId', 'tenantName', 'note', 'email', 'reviewNote']) expect(result.json.data).not.toHaveProperty(field);
    expect(JSON.stringify(result.json)).not.toContain('Private');
    expect(await harness.prisma.auditLog.count({ where: { resourceId: listing.id } })).toBe(3);
  });

  it('enforces role and owner isolation and rejects duplicate listings', async () => {
    const listing = await create();
    expect((await request('/listings', other, { ...content, roomId })).status).toBe(404);
    expect((await request('/listings', owner, { ...content, roomId })).status).toBe(409);
    expect((await get('/listings', other)).json.meta.total).toBe(0);
    expect((await request(`/listings/${listing.id}`, other, { ...content, version: 1 }, 'PATCH')).status).toBe(404);
    expect((await get('/admin/listings', seeker)).status).toBe(403);
    expect((await get('/admin/listings', owner)).status).toBe(403);
    expect((await get('/admin/listings')).status).toBe(401);
    expect((await get('/listings', seeker)).status).toBe(403);
    expect((await request('/listings', seeker, { ...content, roomId })).status).toBe(403);
  });

  it('handles rejection, resubmission, stale versions and withdraws edited content', async () => {
    const listing = await create();
    await request(`/listings/${listing.id}/submit`, owner, { version: 1 });
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 2, decision: 'REJECT' })).status).toBe(400);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 2, decision: 'REJECT', note: 'Cần ảnh rõ hơn' })).status).toBe(201);
    expect((await request(`/listings/${listing.id}/submit`, owner, { version: 3 })).status).toBe(201);
    const approvals = await Promise.all([1, 2].map(() => request(`/admin/listings/${listing.id}/review`, admin, { version: 4, decision: 'PUBLISH' })));
    expect(approvals.map((result) => result.status).sort()).toEqual([201, 409]);
    expect((await request(`/listings/${listing.id}`, owner, { ...content, title: 'Nội dung đã sửa', version: 5 }, 'PATCH')).status).toBe(200);
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    expect((await get('/listings', owner)).json.data[0].status).toBe(ListingStatus.DRAFT);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 5, decision: 'PUBLISH' })).status).toBe(409);
  });

  it('immediately stops exposing occupied/inactive rooms, archived properties and disabled landlords', async () => {
    const listing = await publish();
    await harness.prisma.room.update({ where: { id: roomId }, data: { status: RoomStatus.OCCUPIED } });
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    expect((await get('/public/listings')).json.meta.total).toBe(0);
    await harness.prisma.room.update({ where: { id: roomId }, data: { status: RoomStatus.VACANT, isActive: false } });
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    await harness.prisma.room.update({ where: { id: roomId }, data: { isActive: true } });
    await harness.prisma.property.update({ where: { id: propertyId }, data: { isArchived: true } });
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    await harness.prisma.property.update({ where: { id: propertyId }, data: { isArchived: false } });
    await harness.prisma.user.update({ where: { id: ownerId }, data: { isActive: false } });
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
  });

  it('validates filters/content and supports filtering and pagination', async () => {
    await publish();
    expect((await get('/public/listings?minPrice=3000000')).json.meta.total).toBe(0);
    expect((await get('/public/listings?minArea=30')).json.meta.total).toBe(0);
    expect((await get('/public/listings?amenity=Wifi')).json.meta.total).toBe(0);
    const result = await get(`/public/listings?search=${encodeURIComponent('ban công')}&minPrice=1000000&maxPrice=3000000&limit=1&sort=price_asc`);
    expect(result.json.data).toHaveLength(1);
    expect(result.json.meta).toEqual({ total: 1, limit: 1, page: 1 });
    expect((await get('/public/listings?page=2&limit=1')).json.data).toHaveLength(0);
    for (const query of ['minPrice=-1', 'page=0', 'limit=1000', 'minPrice=5&maxPrice=1', 'status=DRAFT']) {
      expect((await get(`/public/listings?${query}`)).status).toBe(400);
    }
    expect((await request(`/listings/${(await get('/listings', owner)).json.data[0].id}`, owner,
      { ...content, version: 3, imageUrls: ['javascript:alert(1)'] }, 'PATCH')).status).toBe(400);
  });

  it('withdraws publications through landlord or admin controls with an audit reason', async () => {
    const listing = await publish();
    expect((await request(`/listings/${listing.id}/hide`, owner, { version: 3 })).status).toBe(201);
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    expect((await request(`/listings/${listing.id}/submit`, owner, { version: 4 })).status).toBe(201);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 5, decision: 'PUBLISH' })).status).toBe(201);
    expect((await request(`/admin/listings/${listing.id}/review`, admin, { version: 6, decision: 'HIDE', note: 'Ảnh không đúng phòng' })).status).toBe(201);
    expect((await get(`/public/listings/${listing.id}`)).status).toBe(404);
    const audit = await harness.prisma.auditLog.findFirst({ where: { resourceId: listing.id, action: 'listing.hide', actorId: { not: ownerId } } });
    expect(audit?.metadata).toEqual({ version: 7, reviewNote: 'Ảnh không đúng phòng' });
  });

  it('filters real coordinate distances before pagination and excludes missing coordinates', async () => {
    const listing = await publish();
    const campus = await harness.prisma.schoolCampus.create({ data: {
      name: 'Test university', campus: 'North campus', city: 'Test city', address: 'Test address', latitude: 21, longitude: 105,
    } });
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { latitude: 21.01, longitude: 105 } });
    expect((await get('/public/campuses')).status).toBe(200);
    const near = await get(`/public/listings?campusId=${campus.id}&radiusKm=3`);
    expect(near.status).toBe(200);
    expect(near.json.meta.total).toBe(1);
    expect(near.json.data[0].distanceKm).toBeGreaterThan(1);
    expect(near.json.data[0].distanceKm).toBeLessThan(1.2);
    expect((await get(`/public/listings?campusId=${campus.id}&radiusKm=1`)).json.meta.total).toBe(0);
    expect((await get(`/public/listings?campusId=${campus.id}&radiusKm=3&page=2&limit=1`)).json.data).toHaveLength(0);
    await harness.prisma.roomListing.update({ where: { id: listing.id }, data: { latitude: null, longitude: null } });
    expect((await get(`/public/listings?campusId=${campus.id}`)).json.meta.total).toBe(0);
    expect((await get('/public/listings?radiusKm=3')).status).toBe(400);
    expect((await get(`/public/listings?campusId=${campus.id}&radiusKm=100`)).status).toBe(400);
    expect((await request('/admin/campuses', owner, { name: 'Forged' })).status).toBe(403);
  });

  it('persists student reports, rejects duplicate reports and protects moderation', async () => {
    const listing = await publish();
    const payload = { reason: 'wrong_price', detail: 'The actual price is different from the advertised price.' };
    expect((await request(`/student/listings/${listing.id}/reports`, undefined, payload)).status).toBe(401);
    expect((await request(`/student/listings/${listing.id}/reports`, owner, payload)).status).toBe(403);
    const created = await request(`/student/listings/${listing.id}/reports`, seeker, payload);
    expect(created.status).toBe(201);
    expect((await request(`/student/listings/${listing.id}/reports`, seeker, payload)).status).toBe(409);
    expect((await get('/admin/listings/reports', seeker)).status).toBe(403);
    const reports = await get('/admin/listings/reports', admin);
    expect(reports.json.data[0].id).toBe(created.json.data.id);
    const review = { status: 'RESOLVED', note: 'Checked and corrected with owner.' };
    expect((await request(`/admin/listings/reports/${created.json.data.id}/review`, seeker, review)).status).toBe(403);
    expect((await request(`/admin/listings/reports/${created.json.data.id}/review`, admin, review)).status).toBe(201);
    expect((await request(`/admin/listings/reports/${created.json.data.id}/review`, admin, review)).status).toBe(409);
    const publicListing = (await get(`/public/listings/${listing.id}`)).json.data;
    expect(publicListing.reports).toBeUndefined();
    expect(publicListing.reporterId).toBeUndefined();
  });

  it('records truthful verification and invalidates it when listing content changes', async () => {
    const listing = await publish();
    const proof = { version: 3, landlordVerified: true, roomInspected: true, note: 'Checked ownership and visited room with the owner.' };
    expect((await request(`/admin/listings/${listing.id}/verification`, owner, proof)).status).toBe(403);
    expect((await request(`/admin/listings/${listing.id}/verification`, admin, { ...proof, note: 'short' })).status).toBe(400);
    expect((await request(`/admin/listings/${listing.id}/verification`, admin, proof)).status).toBe(201);
    const verified = (await get(`/public/listings/${listing.id}`)).json.data;
    expect(verified.landlordVerifiedAt).not.toBeNull();
    expect(verified.inspectedAt).not.toBeNull();
    expect((await request(`/listings/${listing.id}/confirm-availability`, other, { version: 4 })).status).toBe(404);
    expect((await request(`/listings/${listing.id}/confirm-availability`, owner, { version: 4 })).status).toBe(201);
    expect((await request(`/listings/${listing.id}`, owner, { ...content, version: 5 }, 'PATCH')).status).toBe(200);
    const changed = await harness.prisma.roomListing.findUniqueOrThrow({ where: { id: listing.id } });
    expect(changed.inspectedAt).toBeNull();
    expect(changed.landlordVerifiedAt).toBeNull();
    expect(changed.availabilityConfirmedAt).toBeNull();
  });

  it('validates coordinate pairs and prevents forged verification in landlord content', async () => {
    for (const extra of [{ latitude: 21 }, { latitude: 91, longitude: 105 }, { parkingFee: -1 }, { parkingFee: null }, { inspectedAt: new Date().toISOString() }]) {
      expect((await request('/listings', owner, { ...content, roomId, ...extra })).status).toBe(400);
    }
  });
});
