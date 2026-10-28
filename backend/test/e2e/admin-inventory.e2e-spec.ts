import { randomUUID } from 'node:crypto';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createProperty, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin inventory database acceptance', () => {
  let harness: E2eHarness | undefined;
  beforeEach(async () => {
    const target = new URL(process.env.DATABASE_URL ?? '');
    if (process.env.NODE_ENV !== 'test' || !['localhost', '127.0.0.1', '[::1]'].includes(target.hostname) ||
        !/^\/rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(target.pathname)) {
      throw new Error('Use npm run test:admin-inventory:e2e with a disposable database.');
    }
    harness = await createE2eHarness();
    const database = await harness.prisma.$queryRaw<Array<{ name: string }>>`SELECT current_database() AS name`;
    if (database[0].name !== target.pathname.slice(1)) throw new Error('Connected database does not match disposable target.');
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    if (harness) await closeE2eHarness(harness);
    harness = undefined;
  });
  const api = (path: string, token?: string, body?: object, method?: string) =>
    requestJson<any>(harness!.baseUrl, `/api/v1/admin${path}`, { token, body, method: method ?? (body ? 'POST' : 'GET') });
  async function operator(preset = 'super_admin') {
    const { email } = await createAdmin(harness!.prisma);
    const user = await harness!.prisma.user.findUniqueOrThrow({ where: { email } });
    await harness!.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { ...await login(harness!.baseUrl, email), id: user.id };
  }
  async function inventory() {
    const owner = await registerLandlord(harness!.baseUrl);
    const property = await createProperty(harness!.baseUrl, owner.accessToken, 'Inventory Building');
    await harness!.prisma.room.createMany({ data: Array.from({ length: 25 }, (_, index) => ({
      propertyId: property.id, name: `R${String(index + 1).padStart(2, '0')}`, floor: 2, areaSqm: 24,
      basePrice: 3000000, isActive: index !== 24,
      status: index < 10 ? 'OCCUPIED' : index === 24 ? 'MAINTENANCE' : 'VACANT',
      tenantName: 'PRIVATE_TENANT_NAME', note: 'PRIVATE_ROOM_NOTE',
    })) });
    const room = await harness!.prisma.room.findFirstOrThrow({ where: { propertyId: property.id, name: 'R11' } });
    const listing = await pendingListing(room.id);
    return { owner, property, room, listing };
  }
  async function pendingListing(roomId: string, title = 'Pending inventory listing') {
    return harness!.prisma.roomListing.create({ data: { roomId, title,
      description: 'Listing acceptance test', city: 'HCM', district: 'Thu Duc', publicAddress: 'Public address',
      monthlyRent: 4000000, areaSqm: 24, imageUrls: [], amenities: [], status: 'PENDING' } });
  }
  function expectSafe(text: string, email: string) {
    for (const secret of [email, 'PRIVATE_ROOM_NOTE', 'PRIVATE_TENANT_NAME', 'passwordHash', 'leases', 'invoices']) {
      expect(text).not.toContain(secret);
    }
  }

  it('separates viewers from writers and validates reads without caching private data', async () => {
    const support = await operator('support'), moderator = await operator('moderator'), { owner, property } = await inventory();
    for (const path of ['/properties', `/properties/${property.id}`, '/rooms']) {
      expect((await api(path)).status).toBe(401);
      expect((await api(path, owner.accessToken)).status).toBe(403);
      expect((await api(path, moderator.accessToken)).status).toBe(403);
      const result = await api(path, support.accessToken);
      expect(result.status).toBe(200);
      expect(result.response.headers.get('cache-control')).toBe('private, no-store');
      expectSafe(result.text, owner.email);
    }
    expect((await api('/properties', support.accessToken, { landlordId: owner.user.id, name: 'Forbidden', address: '' })).status).toBe(403);
    expect((await api(`/properties/${property.id}`, support.accessToken, { name: 'Forbidden' }, 'PATCH')).status).toBe(403);
    expect((await api(`/properties/${randomUUID()}`, support.accessToken)).status).toBe(404);
    for (const query of ['page=0', 'limit=101', 'status=bad', 'activity=deleted', 'propertyId=bad', 'minPrice=-1',
      'minPrice=3.2', 'maxPrice=2147483648', 'minPrice=2&maxPrice=1', 'listingStatus=bad', 'private=true']) {
      expect((await api(`/rooms?${query}`, support.accessToken)).status).toBe(400);
    }
  });

  it('keeps property metadata and full occupancy counts while bounding the preview to twenty rooms', async () => {
    const viewer = await operator('support'), { owner, property } = await inventory();
    const archived = await createProperty(harness!.baseUrl, owner.accessToken, 'Archived Building');
    await harness!.prisma.property.update({ where: { id: archived.id }, data: { isArchived: true } });
    const page = await api('/properties?page=2&limit=1', viewer.accessToken);
    expect(page.json.meta).toEqual({ page: 2, limit: 1, total: 2, pages: 2 });
    const filtered = await api(`/properties?archived=archived&landlordId=${owner.user.id}`, viewer.accessToken);
    expect(filtered.json.data.map((row: { id: string }) => row.id)).toEqual([archived.id]);
    expect(filtered.json.data[0].isArchived).toBe(true);
    const detail = await api(`/properties/${property.id}`, viewer.accessToken);
    expect(detail.json.data).toMatchObject({ roomCount: 25, occupiedCount: 10, vacantCount: 14, isArchived: false });
    expect(detail.json.data.rooms).toHaveLength(20);
    expect(detail.json.data.rooms[10]).toMatchObject({ name: 'R11', basePrice: 3000000,
      listing: { status: 'PENDING', monthlyRent: 4000000, version: 1 } });
    expectSafe(detail.text, owner.email);
    await harness!.prisma.user.update({ where: { id: owner.user.id }, data: { isActive: false } });
    expect((await api('/properties?ownerStatus=inactive', viewer.accessToken)).json.meta.total).toBe(2);
    expect((await api('/properties?ownerStatus=active', viewer.accessToken)).json.meta.total).toBe(0);
  });

  it('paginates every room and combines internal price, occupancy, activity, owner and listing filters', async () => {
    const viewer = await operator('support'), { owner, property, room } = await inventory();
    const second = await api(`/rooms?propertyId=${property.id}&page=2&limit=20`, viewer.accessToken);
    expect(second.json.meta).toEqual({ page: 2, limit: 20, total: 25, pages: 2 });
    expect(second.json.data).toHaveLength(5);
    const targeted = await api(`/rooms?search=Inventory&propertyId=${property.id}&landlordId=${owner.user.id}&status=VACANT&activity=active&listingStatus=PENDING&minPrice=3000000&maxPrice=3000000`, viewer.accessToken);
    expect(targeted.json.data.map((row: { id: string }) => row.id)).toEqual([room.id]);
    expect(targeted.json.data[0]).toMatchObject({ basePrice: 3000000, listing: { monthlyRent: 4000000 }, property: { id: property.id } });
    expectSafe(targeted.text, owner.email);
    expect((await api('/rooms?listingStatus=NONE', viewer.accessToken)).json.meta.total).toBe(24);
    expect((await api('/rooms?minPrice=4000000', viewer.accessToken)).json.meta.total).toBe(0);
    expect((await api('/rooms?activity=inactive&status=MAINTENANCE', viewer.accessToken)).json.meta.total).toBe(1);
  });

  it('opens exactly the UUID queue target and reuses claimed/versioned review without mutating room accounting', async () => {
    const admin = await operator(), { property, room, listing } = await inventory();
    const other = await harness!.prisma.room.findFirstOrThrow({ where: { propertyId: property.id, name: 'R12' } });
    await pendingListing(other.id, `Decoy title containing ${listing.id}`);
    expect((await api('/moderation/queue?kind=LISTING&search=Pending', admin.accessToken)).json.meta.total).toBe(1);
    const targetPath = `/moderation/queue?kind=LISTING&search=${listing.id}`;
    const queue = await api(targetPath, admin.accessToken);
    expect(queue.json.meta.total).toBe(1);
    expect(queue.json.data[0].id).toBe(listing.id);
    expect((await api(`/moderation/queue?kind=LISTING&search=${listing.id.toUpperCase()}`, admin.accessToken)).json.meta.total).toBe(1);
    expect((await api('/moderation/work', admin.accessToken, { kind: 'LISTING', targetId: listing.id, version: 0,
      assigneeId: admin.id, priority: 'NORMAL', dueAt: new Date(Date.now() + 3600000).toISOString(), note: '', reason: 'Inventory review assignment' })).status).toBe(201);
    const review = { version: 1, decision: 'REJECT', note: '[POLICY] Inventory content checked' };
    expect((await api(`/listings/${listing.id}/review`, admin.accessToken, review)).status).toBe(201);
    expect((await api(`/listings/${listing.id}/review`, admin.accessToken, review)).status).toBe(409);
    expect((await api(targetPath, admin.accessToken)).json.meta.total).toBe(0);
    const rooms = await api(`/rooms?propertyId=${property.id}&listingStatus=REJECTED`, admin.accessToken);
    expect(rooms.json.data[0]).toMatchObject({ id: room.id, status: 'VACANT', basePrice: 3000000,
      listing: { id: listing.id, status: 'REJECTED', version: 2, monthlyRent: 4000000 } });
    expect(await harness!.prisma.auditLog.count({ where: { resourceId: listing.id } })).toBeGreaterThan(0);
    expect((await harness!.prisma.room.findUniqueOrThrow({ where: { id: room.id } })).note).toBe('PRIVATE_ROOM_NOTE');
  });

  it('preserves authorized property creation/update with audit and masked bounded detail', async () => {
    const admin = await operator(), owner = await registerLandlord(harness!.baseUrl);
    const created = await api('/properties', admin.accessToken, { landlordId: owner.user.id, name: 'Created by admin', address: 'Admin address' });
    expect(created.status).toBe(201);
    expect(created.json.data).toMatchObject({ name: 'Created by admin', roomCount: 0, isArchived: false });
    const id = created.json.data.id;
    const updated = await api(`/properties/${id}`, admin.accessToken, { name: 'Updated by admin', address: 'Updated address' }, 'PATCH');
    expect(updated.status).toBe(200);
    expect(updated.json.data).toMatchObject({ id, name: 'Updated by admin', address: 'Updated address', rooms: [], roomCount: 0 });
    expectSafe(updated.text, owner.email);
    expect(await harness!.prisma.auditLog.count({ where: { resourceId: id, action: { in: ['admin.property_create', 'admin.property_update'] } } })).toBe(2);
  });
});
