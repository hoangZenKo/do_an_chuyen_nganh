import { AuthService } from '../../src/auth/auth.service';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, resetDatabase, testPassword, uniqueEmail } from './e2e-fixtures';

describe('Verified room reviews E2E', () => {
  let harness: E2eHarness;
  let owner: string, otherOwner: string, student: string, otherStudent: string, admin: string;
  let ownerId: string, studentId: string, roomId: string, leaseId: string, listingId: string;
  const content = { roomRating: 5, costRating: 3, landlordRating: 4, areaRating: 4,
    body: 'A real stay with clear costs and a comfortable room.' };
  const request = (path: string, token?: string, body?: unknown, method = 'POST') =>
    requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method });
  const get = (path: string, token?: string) => request(path, token, undefined, 'GET');
  const create = () => request(`/reviews/leases/${leaseId}`, student, content);
  const publicPage = () => get(`/public/listings/${listingId}/reviews`);
  const moderate = (id: string, version: number, status = 'APPROVED', reply = false) =>
    request(`/admin/room-reviews/${id}/${reply ? 'reply/' : ''}moderate`, admin,
      { version, status, note: 'Checked against moderation policy.' });
  const approved = async () => {
    const result = await create();
    expect(result.status).toBe(201);
    const review = result.json.data;
    const approval = await moderate(review.id, review.version);
    expect(approval.status).toBe(201);
    return approval.json.data;
  };

  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => {
    await resetDatabase(harness.prisma);
    const auth = harness.app.get(AuthService);
    const input = (prefix: string) => ({ fullName: prefix, email: uniqueEmail(prefix),
      phone: '+84901234567', password: testPassword });
    const landlord = (await auth.register(input('review-owner'))).data;
    owner = landlord.accessToken; ownerId = landlord.user.id;
    otherOwner = (await auth.register(input('review-other-owner'))).data.accessToken;
    const tenantUser = (await auth.registerSeeker(input('review-student'))).data;
    student = tenantUser.accessToken; studentId = tenantUser.user.id;
    otherStudent = (await auth.registerSeeker(input('review-other-student'))).data.accessToken;
    const adminUser = await createAdmin(harness.prisma);
    admin = (await auth.login({ email: adminUser.email, password: testPassword })).data.accessToken;
    const property = await harness.prisma.property.create({ data: {
      landlordId: ownerId, name: 'Review property', address: 'Private address',
    } });
    const room = await harness.prisma.room.create({ data: {
      propertyId: property.id, name: 'Review room', basePrice: 2500000,
    } });
    roomId = room.id;
    const tenant = await harness.prisma.tenant.create({ data: {
      landlordId: ownerId, userId: studentId, fullName: 'Verified tenant',
    } });
    const lease = await harness.prisma.lease.create({ data: {
      tenantId: tenant.id, roomId, monthlyRent: 2500000,
      startDate: new Date(Date.now() - 7 * 86400000),
      handover: { create: { electricity: 100, water: 20, condition: 'Good condition',
        imageUrls: [], acceptedAt: new Date(Date.now() - 6 * 86400000) } },
    } });
    leaseId = lease.id;
    const listing = await harness.prisma.roomListing.create({ data: {
      roomId, title: 'Available again after this stay', description: 'A real listing for review tests.',
      imageUrls: [], city: 'Test', district: 'Test district', publicAddress: 'Public road',
      monthlyRent: 2500000, deposit: 2000000, areaSqm: 25, amenities: [],
      status: 'PUBLISHED', publishedAt: new Date(),
    } });
    listingId = listing.id;
  });

  it('accepts only verified tenants and keeps new reviews private until approval', async () => {
    expect((await get(`/reviews/leases/${leaseId}`, student)).json.data.eligible).toBe(true);
    const result = await create();
    expect(result.status).toBe(201);
    expect(result.json.data).toMatchObject({ status: 'PENDING', version: 1, ...content });
    expect((await publicPage()).json.summary).toMatchObject({ count: 0, overall: null });
    const queue = await get('/admin/room-reviews', admin);
    expect(queue.json.data).toHaveLength(1);
    expect(queue.json.data[0]).toMatchObject({ roomName: 'Review room', propertyName: 'Review property' });
    expect((await moderate(result.json.data.id, 1)).status).toBe(201);
    const visible = (await publicPage()).json;
    expect(visible.summary).toMatchObject({ count: 1, overall: 4, roomRating: 5, costRating: 3 });
    expect(visible.data[0]).not.toHaveProperty('authorId');
    expect(visible.data[0]).not.toHaveProperty('leaseId');
    expect(visible.data[0]).not.toHaveProperty('moderationNote');
  });

  it('requires accepted handover or an ended legacy stay of at least a day', async () => {
    await harness.prisma.leaseHandover.update({ where: { leaseId }, data: { acceptedAt: null } });
    expect((await get(`/reviews/leases/${leaseId}`, student)).json.data.eligible).toBe(false);
    expect((await create()).status).toBe(409);
    await harness.prisma.lease.update({ where: { id: leaseId }, data: {
      status: 'ENDED', endDate: new Date(Date.now() - 86400000),
    } });
    expect((await create()).json.data.verificationSource).toBe('COMPLETED_LEASE');
  });

  it('rejects future and short legacy leases', async () => {
    await harness.prisma.lease.update({ where: { id: leaseId }, data: { startDate: new Date(Date.now() + 86400000) } });
    expect((await create()).status).toBe(409);
    await harness.prisma.leaseHandover.delete({ where: { leaseId } });
    await harness.prisma.lease.update({ where: { id: leaseId }, data: {
      status: 'ENDED', startDate: new Date(Date.now() - 3600000), endDate: new Date(Date.now() - 60000),
    } });
    expect((await create()).status).toBe(409);
  });

  it('enforces authentication, roles and tenant/landlord ownership', async () => {
    expect((await get(`/reviews/leases/${leaseId}`)).status).toBe(401);
    expect((await get(`/reviews/leases/${leaseId}`, owner)).status).toBe(403);
    expect((await get(`/reviews/leases/${leaseId}`, otherStudent)).status).toBe(404);
    const review = await approved();
    expect((await request(`/reviews/${review.id}`, otherStudent, { ...content, version: review.version }, 'PATCH')).status).toBe(404);
    expect((await request(`/reviews/${review.id}/reply`, otherOwner, { version: review.version, body: 'Not my tenant' })).status).toBe(404);
    expect((await get('/reviews/landlord', otherOwner)).json.data).toEqual([]);
    expect((await get('/admin/room-reviews', owner)).status).toBe(403);
    expect((await get('/reviews/landlord', student)).status).toBe(403);
  });

  it('validates scores, body, versions and moderation notes', async () => {
    for (const invalid of [{ roomRating: 6 }, { costRating: 0 }, { areaRating: 1.5 },
      { landlordRating: '5' }, { body: 'tiny' }, { body: ' '.repeat(30) }, { body: 'x'.repeat(3001) }]) {
      expect((await request(`/reviews/leases/${leaseId}`, student, { ...content, ...invalid })).status).toBe(400);
    }
    const result = await create();
    const id = result.json.data.id;
    expect((await request(`/admin/room-reviews/${id}/moderate`, admin,
      { version: 1, status: 'APPROVED', note: ' ' })).status).toBe(400);
    expect((await request(`/reviews/${id}`, student, { ...content, version: 0 }, 'PATCH')).status).toBe(400);
    expect((await get('/admin/room-reviews?target=invalid', admin)).status).toBe(400);
    expect((await get(`/public/listings/${listingId}/reviews?page=0`)).status).toBe(400);
  });

  it('allows only one review per tenant, room and landlord across leases', async () => {
    expect((await create()).status).toBe(201);
    expect((await create()).status).toBe(409);
    const original = await harness.prisma.lease.findUniqueOrThrow({ where: { id: leaseId } });
    const nextLease = await harness.prisma.lease.create({ data: {
      tenantId: original.tenantId, roomId, monthlyRent: 2500000, status: 'ENDED',
      startDate: new Date(Date.now() - 4 * 86400000), endDate: new Date(Date.now() - 86400000),
    } });
    expect((await request(`/reviews/leases/${nextLease.id}`, student, content)).status).toBe(409);
    expect((await get(`/reviews/leases/${nextLease.id}`, student)).json.data.review.leaseId).toBe(leaseId);
  });

  it('moderates landlord replies separately and clears old replies after tenant edits', async () => {
    const pending = (await create()).json.data;
    expect((await request(`/reviews/${pending.id}/reply`, owner, { version: 1, body: 'Thank you for the feedback.' })).status).toBe(409);
    let review = (await moderate(pending.id, 1)).json.data;
    review = (await request(`/reviews/${review.id}/reply`, owner,
      { version: review.version, body: 'Thank you for the feedback.' })).json.data;
    expect(review.replyStatus).toBe('PENDING');
    expect((await publicPage()).json.data[0].reply).toBeNull();
    expect((await get(`/reviews/leases/${leaseId}`, student)).json.data.review.replyBody).toBeNull();
    expect((await get('/admin/room-reviews?target=reply', admin)).json.data).toHaveLength(1);
    review = (await moderate(review.id, review.version, 'APPROVED', true)).json.data;
    expect((await publicPage()).json.data[0].reply.body).toBe('Thank you for the feedback.');
    const edit = await request(`/reviews/${review.id}`, student, { ...content, body: 'Updated experience after staying longer in this room.', version: review.version }, 'PATCH');
    expect(edit.status).toBe(200);
    expect(edit.json.data).toMatchObject({ status: 'PENDING', replyBody: null, replyStatus: null });
    expect((await publicPage()).json.summary.count).toBe(0);
    review = (await moderate(review.id, edit.json.data.version)).json.data;
    expect((await publicPage()).json.data[0].reply).toBeNull();
    expect((await moderate(review.id, review.version, 'APPROVED', true)).status).toBe(409);
  });

  it('hides rejected reviews and replies and removes withdrawn scores from aggregates', async () => {
    let review = await approved();
    review = (await request(`/reviews/${review.id}/reply`, owner, { version: review.version, body: 'A response requiring review.' })).json.data;
    review = (await moderate(review.id, review.version, 'REJECTED', true)).json.data;
    expect((await publicPage()).json.data[0].reply).toBeNull();
    review = (await moderate(review.id, review.version, 'HIDDEN')).json.data;
    expect((await publicPage()).json.data).toEqual([]);
    review = (await moderate(review.id, review.version)).json.data;
    expect((await request(`/reviews/${review.id}`, student, { version: review.version }, 'DELETE')).status).toBe(200);
    expect((await publicPage()).json.summary).toMatchObject({ count: 0, overall: null });
    expect((await get('/admin/room-reviews?status=HIDDEN', admin)).json.data).toEqual([]);
    expect((await moderate(review.id, review.version + 1)).status).toBe(409);
    const restore = await request(`/reviews/${review.id}`, student, { ...content, version: review.version + 1 }, 'PATCH');
    expect(restore.status).toBe(200);
    expect(restore.json.data).toMatchObject({ status: 'PENDING', withdrawnAt: null });
  });

  it('rejects stale versions and serializes concurrent edit/moderation operations', async () => {
    const review = await approved();
    const results = await Promise.all([
      request(`/reviews/${review.id}`, student, { ...content, version: review.version }, 'PATCH'),
      moderate(review.id, review.version, 'HIDDEN'),
    ]);
    expect(results.filter(result => result.status === 409)).toHaveLength(1);
    expect(results.filter(result => [200, 201].includes(result.status))).toHaveLength(1);
    const current = await harness.prisma.roomReview.findUniqueOrThrow({ where: { id: review.id } });
    expect(current.version).toBe(review.version + 1);
    expect((await request(`/reviews/${review.id}`, student, { ...content, version: review.version }, 'PATCH')).status).toBe(409);
  });

  it('rejects unpublished or demo listings and bounds pagination', async () => {
    await approved();
    const page = await get(`/public/listings/${listingId}/reviews?page=2&limit=1`);
    expect(page.json.meta).toMatchObject({ total: 1, page: 2, limit: 1 });
    expect(page.json.data).toEqual([]);
    await harness.prisma.roomListing.update({ where: { id: listingId }, data: { status: 'HIDDEN' } });
    expect((await publicPage()).status).toBe(404);
    await harness.prisma.roomListing.update({ where: { id: listingId }, data: { status: 'PUBLISHED', description: '[explore-preview]' } });
    expect((await publicPage()).status).toBe(404);
  });
});
