import { AuthService } from '../../src/auth/auth.service';
import { HousingService } from '../../src/housing/housing.service';
import { unlink } from 'node:fs/promises';
import { basename, join } from 'node:path';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, resetDatabase, testPassword, uniqueEmail } from './e2e-fixtures';

describe('Student housing journey E2E', () => {
  let harness: E2eHarness;
  let owner: string, otherOwner: string, student: string, otherStudent: string, admin: string;
  let studentId: string, ownerId: string, otherOwnerId: string, listingId: string, roomId: string;
  const pilotArea = process.env.RENTAL_PILOT_AREA;
  const uploadedPaths: string[] = [];
  afterEach(async () => {
    for (const path of uploadedPaths.splice(0)) await unlink(path);
  });
  beforeAll(async () => {
    process.env.RENTAL_PILOT_AREA = 'Test district';
    harness = await createE2eHarness();
  });
  afterAll(async () => {
    if (pilotArea === undefined) delete process.env.RENTAL_PILOT_AREA;
    else process.env.RENTAL_PILOT_AREA = pilotArea;
    await closeE2eHarness(harness);
  });
  beforeEach(async () => {
    await resetDatabase(harness.prisma);
    const auth = harness.app.get(AuthService);
    const input = (prefix: string) => ({ fullName: prefix, email: uniqueEmail(prefix), password: testPassword, phone: '+84901234567' });
    const landlord = (await auth.register(input('owner'))).data;
    owner = landlord.accessToken; ownerId = landlord.user.id;
    const secondOwner = (await auth.register(input('other-owner'))).data;
    otherOwner = secondOwner.accessToken; otherOwnerId = secondOwner.user.id;
    const seeker = (await auth.registerSeeker(input('student'))).data;
    student = seeker.accessToken; studentId = seeker.user.id;
    otherStudent = (await auth.registerSeeker(input('other-student'))).data.accessToken;
    const adminUser = await createAdmin(harness.prisma);
    admin = (await auth.login({ email: adminUser.email, password: testPassword })).data.accessToken;
    const property = await harness.prisma.property.create({ data: { landlordId: ownerId, name: 'Test property', address: 'Private' } });
    const room = await harness.prisma.room.create({ data: { propertyId: property.id, name: 'Test room', basePrice: 2500000 } });
    roomId = room.id;
    const listing = await harness.prisma.roomListing.create({ data: {
      roomId, title: 'Test listing', description: 'Test description', imageUrls: [], city: 'Test', district: 'Test district',
      publicAddress: 'Public road', monthlyRent: 2500000, deposit: 2000000, areaSqm: 25, amenities: [], status: 'PUBLISHED', publishedAt: new Date(),
    } });
    listingId = listing.id;
  });
  const request = (path: string, token?: string, body?: unknown, method = 'POST') =>
    requestJson(harness.baseUrl, `/api/v1${path}`, { token, body, method });
  const get = (path: string, token?: string) => request(path, token, undefined, 'GET');
  const book = (token = student) => request('/housing/viewings', token, {
    listingId, scheduledAt: new Date(Date.now() + 86400000).toISOString(), note: 'Please confirm',
  });
  const change = (id: string, version: number, status: string, token = owner) =>
    request(`/housing/viewings/${id}`, token, { version, status }, 'PATCH');
  const leaseBody = (version = 3) => ({ version, startDate: new Date().toISOString(), monthlyRent: 2500000, deposit: 2000000 });
  const completed = async () => {
    const booking = await book();
    expect(booking.status).toBe(201);
    const id = booking.json.data.id;
    expect((await change(id, 1, 'CONFIRMED')).status).toBe(200);
    await harness.prisma.roomViewing.update({ where: { id }, data: { scheduledAt: new Date(Date.now() - 60000) } });
    expect((await change(id, 2, 'COMPLETED')).status).toBe(200);
    return id;
  };

  it('persists favorites idempotently per account, retains unavailable markers and supports removal', async () => {
    expect((await request(`/housing/favorites/${listingId}`, undefined, undefined, 'PUT')).status).toBe(401);
    expect((await request(`/housing/favorites/${listingId}`, owner, undefined, 'PUT')).status).toBe(403);
    expect((await request(`/housing/favorites/${listingId}`, student, undefined, 'PUT')).status).toBe(200);
    await request(`/housing/favorites/${listingId}`, student, undefined, 'PUT');
    const favorites = await get('/housing/favorites', student);
    expect(favorites.json.meta.total).toBe(1);
    expect(favorites.json.data[0].available).toBe(true);
    expect((await get('/housing/favorites', otherStudent)).json.data).toHaveLength(0);
    await harness.prisma.roomListing.update({ where: { id: listingId }, data: { status: 'HIDDEN' } });
    expect((await get('/housing/favorites', student)).json.data[0].available).toBe(false);
    expect((await get(`/housing/favorites/${listingId}`, student)).json.data.saved).toBe(true);
    expect((await request(`/housing/favorites/${listingId}`, student, undefined, 'DELETE')).status).toBe(200);
    expect((await get('/housing/favorites', student)).json.meta.total).toBe(0);
  });

  it('validates dates, timezone, pagination, ownership and unavailable rooms', async () => {
    for (const scheduledAt of [new Date().toISOString(), new Date(Date.now() + 100 * 86400000).toISOString(), '2026-12-01', 'not-a-date']) {
      expect((await request('/housing/viewings', student, { listingId, scheduledAt })).status).toBe(400);
    }
    expect((await get('/housing/viewings?page=0', student)).status).toBe(400);
    expect((await book(owner)).status).toBe(403);
    await harness.prisma.room.update({ where: { id: roomId }, data: { status: 'OCCUPIED' } });
    expect((await book()).status).toBe(404);
  });

  it('prevents duplicate concurrent booking and scopes schedules and notifications to participants', async () => {
    const results = await Promise.all([book(), book()]);
    expect(results.map((result) => result.status).sort()).toEqual([201, 409]);
    const created = results.find((result) => result.status === 201)!.json.data;
    expect((await get(`/housing/viewings/${created.id}`, student)).json.data.id).toBe(created.id);
    expect((await get(`/housing/viewings/${created.id}`, owner)).status).toBe(200);
    expect((await get(`/housing/viewings/${created.id}`, otherStudent)).status).toBe(404);
    expect((await get(`/housing/viewings/${created.id}`, otherOwner)).status).toBe(404);
    expect(created.student).toEqual({ fullName: 'student' });
    expect(created.listing.room.property).toEqual({ name: 'Test property' });
    expect((await get('/housing/viewings', otherOwner)).json.data).toHaveLength(0);
    expect((await get('/housing/viewings', otherStudent)).json.data).toHaveLength(0);
    expect((await change(created.id, 1, 'CONFIRMED', otherOwner)).status).toBe(404);
    expect((await change(created.id, 1, 'CONFIRMED', student)).status).toBe(409);
    expect((await get('/housing/notifications', owner)).json.unreadCount).toBe(1);
    const notice = (await get('/housing/notifications', owner)).json.data[0];
    await request(`/housing/notifications/${notice.id}/read`, otherOwner);
    expect((await get('/housing/notifications', owner)).json.unreadCount).toBe(1);
    await request(`/housing/notifications/${notice.id}/read`, owner);
    expect((await get('/housing/notifications', owner)).json.unreadCount).toBe(0);
  });

  it('rejects stale updates and premature lease creation; cancellation allows rebooking', async () => {
    const id = (await book()).json.data.id;
    expect((await change(id, 1, 'CONFIRMED')).status).toBe(200);
    expect((await change(id, 1, 'CANCELLED', student)).status).toBe(409);
    expect((await request(`/housing/viewings/${id}/lease`, owner, leaseBody(2))).status).toBe(409);
    expect((await change(id, 2, 'CANCELLED', student)).status).toBe(200);
    expect((await book()).status).toBe(201);
    expect((await get('/housing/notifications', student)).json.data[0].message).toContain('xác nhận');
  });

  it('lets only the owning landlord complete a confirmed visit before its scheduled time', async () => {
    const created = (await book()).json.data;
    expect((await change(created.id, 1, 'COMPLETED')).status).toBe(409);
    expect((await change(created.id, 1, 'CONFIRMED')).status).toBe(200);
    expect((await change(created.id, 2, 'COMPLETED', student)).status).toBe(409);
    expect((await change(created.id, 2, 'COMPLETED', otherOwner)).status).toBe(404);
    expect((await change(created.id, 1, 'COMPLETED')).status).toBe(409);

    const result = await change(created.id, 2, 'COMPLETED');
    expect(result.status).toBe(200);
    expect(result.json.data.status).toBe('COMPLETED');
    expect(result.json.data.version).toBe(3);
    expect(new Date(result.json.data.scheduledAt).getTime()).toBeGreaterThan(Date.now());
    expect((await change(created.id, 3, 'COMPLETED')).status).toBe(409);
    expect(await harness.prisma.lease.count({ where: { roomId } })).toBe(0);
    expect(await harness.prisma.depositTransaction.count()).toBe(0);
    expect((await request(`/housing/viewings/${created.id}/lease`, owner, leaseBody())).status).toBe(201);
  });

  it('atomically converts a completed visit into a linked lease without inventing a deposit payment', async () => {
    const id = await completed();
    await book(otherStudent);
    expect((await request(`/housing/viewings/${id}/lease`, student, leaseBody())).status).toBe(403);
    const result = await request(`/housing/viewings/${id}/lease`, owner, leaseBody());
    expect(result.status).toBe(201);
    expect((await request(`/housing/viewings/${id}/lease`, owner, leaseBody())).status).toBe(409);
    expect(await harness.prisma.lease.count({ where: { roomId } })).toBe(1);
    expect(await harness.prisma.depositTransaction.count()).toBe(0);
    expect((await harness.prisma.room.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('OCCUPIED');
    expect((await harness.prisma.tenant.findUniqueOrThrow({ where: { userId: studentId } })).landlordId).toBe(ownerId);
    const profile = await get('/tenant/me', student);
    expect(profile.status).toBe(200);
    expect(profile.json.data.activeLease.id).toBe(result.json.data.leaseId);
    const leases = (await get('/tenant/leases', student)).json.data;
    expect(leases[0].deposit).toBe(2000000);
    expect(leases[0].depositBalance).toBe(0);
    expect(leases[0].depositTransactions).toEqual([]);
    expect((await request(`/leases/${result.json.data.leaseId}/deposits`, owner,
      { type: 'collected', amount: 1000000, note: 'Actual partial deposit received' })).status).toBe(201);
    expect((await request(`/leases/${result.json.data.leaseId}/deposits`, owner,
      { type: 'refunded', amount: 250000, note: 'Actual partial deposit refunded' })).status).toBe(201);
    const ledger = (await get('/tenant/leases', student)).json.data[0];
    expect(ledger.depositBalance).toBe(750000);
    expect(ledger.depositTransactions).toHaveLength(2);
    expect(ledger.depositTransactions.map((entry: { type: string }) => entry.type).sort()).toEqual(['collected', 'refunded']);
    expect((await get('/tenant/leases', otherStudent)).status).toBe(404);
    expect((await get(`/public/listings/${listingId}`)).status).toBe(404);
    expect((await get('/housing/viewings', otherStudent)).json.data[0].status).toBe('CANCELLED');
    expect((await get('/housing/notifications', otherStudent)).json.data[0].message).toContain('đã có người thuê');
    expect((await get('/tenant/me', otherStudent)).status).toBe(404);
  });

  it('serializes concurrent lease conversions and rolls back when room availability changes', async () => {
    const id = await completed();
    const responses = await Promise.all([
      request(`/housing/viewings/${id}/lease`, owner, leaseBody()),
      request(`/housing/viewings/${id}/lease`, owner, leaseBody()),
    ]);
    expect(responses.map((result) => result.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.lease.count()).toBe(1);
  });

  it('continues from the new lease into invoices, uploaded payment proof, approval and maintenance', async () => {
    const id = await completed();
    const leaseId = (await request(`/housing/viewings/${id}/lease`, owner, leaseBody())).json.data.leaseId;
    const invoice = await request('/billing/invoices', owner, { leaseId, billingMonth: new Date().toISOString() });
    expect(invoice.status).toBe(201);
    const invoiceId = invoice.json.data.id;
    expect((await get('/tenant/invoices', student)).json.data.map((item: { id: string }) => item.id)).toContain(invoiceId);
    const form = new FormData();
    const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64');
    form.append('file', new Blob([png], { type: 'image/png' }), 'housing-test-proof.png');
    const upload = await fetch(new URL('/api/v1/uploads', harness.baseUrl), {
      method: 'POST', headers: { authorization: `Bearer ${student}` }, body: form,
    });
    expect(upload.status).toBe(201);
    const proofUrl = (await upload.json() as { data: { url: string } }).data.url;
    uploadedPaths.push(join(harness.uploadDirectory, basename(proofUrl)));
    const proof = await request(`/tenant/invoices/${invoiceId}/payment-proofs`, student, {
      amount: invoice.json.data.totalAmount, method: 'bank_transfer', note: 'Test receipt, not a real payment', proofImageUrls: [proofUrl],
    });
    expect(proof.status).toBe(201);
    expect((await get(`/tenant/invoices/${invoiceId}`, student)).json.data.paymentProofs[0].status).toBe('pending');
    expect((await request(`/billing/payment-proofs/${proof.json.data.id}/review`, owner, { status: 'approved' })).status).toBe(201);
    expect((await get(`/tenant/invoices/${invoiceId}`, student)).json.data.status).toBe('paid');
    expect((await get(`/tenant/invoices/${invoiceId}`, otherStudent)).status).toBe(404);
    const ticket = await request('/tenant/maintenance', student, {
      title: 'Test tap repair', description: 'Test request after moving in', priority: 'medium', imageUrls: [proofUrl],
    });
    expect(ticket.status).toBe(201);
    const comment = await request(`/tenant/maintenance/${ticket.json.data.id}/comments`, student,
      { body: 'Additional test attachment', imageUrls: [proofUrl] });
    expect(comment.status).toBe(201);
    expect((await get('/tenant/maintenance', student)).json.data.map((item: { id: string }) => item.id)).toContain(ticket.json.data.id);
    expect((await request('/tenant/maintenance', otherStudent, { title: 'Not linked' })).status).toBe(404);
  });

  it('does not link a tenant or create a lease if the room became inactive', async () => {
    const id = await completed();
    await harness.prisma.room.update({ where: { id: roomId }, data: { isActive: false } });
    expect((await request(`/housing/viewings/${id}/lease`, owner, leaseBody())).status).toBe(409);
    expect(await harness.prisma.lease.count()).toBe(0);
    expect(await harness.prisma.tenant.count({ where: { userId: studentId } })).toBe(0);
    expect((await harness.prisma.roomViewing.findUniqueOrThrow({ where: { id } })).status).toBe('COMPLETED');
  });
  it('does not expose viewings or notifications to staff/admin accounts', async () => {
    expect((await get('/housing/viewings', admin)).status).toBe(403);
    expect((await get('/housing/notifications', admin)).status).toBe(403);
    expect((await get('/housing/favorites', admin)).status).toBe(403);
  });

  const future = (hours: number) => new Date(Date.now() + hours * 3600000).toISOString();
  const slot = (startsAt: string) => request(`/housing/listings/${listingId}/slots`, owner,
    { startsAt, endsAt: new Date(new Date(startsAt).getTime() + 1800000).toISOString() });

  it('publishes landlord-only slots and serializes two students competing for the same time', async () => {
    const startsAt = future(4);
    expect((await request(`/housing/listings/${listingId}/slots`, otherOwner,
      { startsAt, endsAt: future(5) })).status).toBe(404);
    expect((await request(`/housing/listings/${listingId}/slots`, student,
      { startsAt, endsAt: future(5) })).status).toBe(403);
    const opened = await slot(startsAt);
    expect(opened.status).toBe(201);
    expect((await slot(startsAt)).status).toBe(409);
    expect((await book()).status).toBe(409);
    const body = { listingId, scheduledAt: startsAt, slotId: opened.json.data.id };
    const results = await Promise.all([request('/housing/viewings', student, body), request('/housing/viewings', otherStudent, body)]);
    expect(results.map((item) => item.status).sort()).toEqual([201, 409]);
    const availability = await get(`/housing/listings/${listingId}/slots`, student);
    expect(availability.json.required).toBe(true);
    expect(availability.json.data[0].available).toBe(false);
    expect((await request(`/housing/slots/${opened.json.data.id}`, owner, undefined, 'DELETE')).status).toBe(409);
  });

  it('keeps slot-only mode when the landlord deletes all openings and permits adjacent slots', async () => {
    const startsAt = future(4);
    const opened = await slot(startsAt);
    expect((await slot(opened.json.data.endsAt)).status).toBe(201);
    expect((await request(`/housing/slots/${opened.json.data.id}`, otherOwner, undefined, 'DELETE')).status).toBe(404);
    expect((await request(`/housing/slots/${opened.json.data.id}`, owner, undefined, 'DELETE')).status).toBe(200);
    const rows = (await get(`/housing/listings/${listingId}/slots`, owner)).json.data;
    await request(`/housing/slots/${rows[0].id}`, owner, undefined, 'DELETE');
    expect((await get(`/housing/listings/${listingId}/slots`, student)).json).toEqual({ required: true, data: [] });
    expect((await book()).status).toBe(409);
  });

  it('rejects invalid slot lengths and bookings that do not match the actual opening', async () => {
    expect((await request(`/housing/listings/${listingId}/slots`, owner,
      { startsAt: future(4), endsAt: future(3) })).status).toBe(400);
    expect((await request(`/housing/listings/${listingId}/slots`, owner,
      { startsAt: future(4), endsAt: future(7) })).status).toBe(400);
    const opened = await slot(future(4));
    expect((await request('/housing/viewings', student,
      { listingId, scheduledAt: future(5), slotId: opened.json.data.id })).status).toBe(409);
    expect(await harness.prisma.roomViewing.count()).toBe(0);
  });

  it('serializes overlapping student bookings across different landlords', async () => {
    const property = await harness.prisma.property.create({ data: { landlordId: otherOwnerId, name: 'Other property', address: 'Private' } });
    const room = await harness.prisma.room.create({ data: { propertyId: property.id, name: 'Other room', basePrice: 2500000 } });
    const { id: _id, roomId: _room, ...data } = await harness.prisma.roomListing.findUniqueOrThrow({ where: { id: listingId } });
    const second = await harness.prisma.roomListing.create({ data: { ...data, roomId: room.id } });
    const scheduledAt = future(4);
    const results = await Promise.all([listingId, second.id].map((id) => request('/housing/viewings', student, { listingId: id, scheduledAt })));
    expect(results.map((item) => item.status).sort()).toEqual([201, 409]);
  });

  it('reschedules atomically, clears confirmation, rejects stale/foreign edits and shows cancellation reasons', async () => {
    const booking = await book();
    const id = booking.json.data.id;
    await change(id, 1, 'CONFIRMED');
    const body = { version: 2, listingId, scheduledAt: future(4), note: 'Changed study schedule' };
    expect((await request(`/housing/viewings/${id}/reschedule`, otherStudent, body, 'PATCH')).status).toBe(404);
    expect((await request(`/housing/viewings/${id}/reschedule`, owner, body, 'PATCH')).status).toBe(403);
    expect((await request(`/housing/viewings/${id}/reschedule`, student, { ...body, version: 1 }, 'PATCH')).status).toBe(409);
    const changed = await request(`/housing/viewings/${id}/reschedule`, student, body, 'PATCH');
    expect(changed.status).toBe(200);
    expect(changed.json.data).toMatchObject({ status: 'REQUESTED', version: 3, responseNote: '', reminderSentAt: null });
    expect(new Date(changed.json.data.endsAt).getTime() - new Date(body.scheduledAt).getTime()).toBe(1800000);
    const reason = 'The student has changed their plans.';
    expect((await request(`/housing/viewings/${id}`, student, { version: 3, status: 'CANCELLED', note: reason }, 'PATCH')).status).toBe(200);
    expect((await get(`/housing/viewings/${id}`, owner)).json.data.cancellationReason).toBe(reason);
    expect((await get('/housing/notifications', owner)).json.data[0].message).toContain(reason);
  });

  it('rejects cross-listing landlord overlaps and leaves the old appointment intact on failed rescheduling', async () => {
    const first = await book();
    const listing = await harness.prisma.roomListing.findUniqueOrThrow({ where: { id: listingId } });
    const newRoom = await harness.prisma.room.create({ data: { propertyId: (await harness.prisma.room.findUniqueOrThrow({ where: { id: roomId } })).propertyId,
      name: 'Other room', basePrice: 2500000 } });
    const { id: _id, roomId: _room, ...data } = listing;
    const second = await harness.prisma.roomListing.create({ data: { ...data, roomId: newRoom.id } });
    expect((await request('/housing/viewings', otherStudent, { listingId: second.id,
      scheduledAt: first.json.data.scheduledAt })).status).toBe(409);
    const occupied = future(4);
    expect((await request('/housing/viewings', otherStudent, { listingId: second.id, scheduledAt: occupied })).status).toBe(201);
    expect((await request(`/housing/viewings/${first.json.data.id}/reschedule`, student,
      { listingId, version: 1, scheduledAt: occupied }, 'PATCH')).status).toBe(409);
    expect((await get(`/housing/viewings/${first.json.data.id}`, student)).json.data).toMatchObject({ version: 1,
      scheduledAt: first.json.data.scheduledAt, status: 'REQUESTED' });
  });

  it('sends one in-app reminder per confirmed appointment to both parties, even with competing workers', async () => {
    const booking = await request('/housing/viewings', student, { listingId, scheduledAt: future(4) });
    const id = booking.json.data.id;
    const housing = harness.app.get(HousingService);
    await housing.sendViewingReminders();
    expect(await harness.prisma.housingNotification.count()).toBe(1);
    await change(id, 1, 'CONFIRMED');
    await Promise.all([housing.sendViewingReminders(), housing.sendViewingReminders()]);
    expect(await harness.prisma.housingNotification.count({ where: { message: { startsWith: 'Nhắc lịch:' } } })).toBe(2);
    await request(`/housing/viewings/${id}/reschedule`, student, { listingId, version: 2, scheduledAt: future(6) }, 'PATCH');
    await housing.sendViewingReminders();
    expect(await harness.prisma.housingNotification.count({ where: { message: { startsWith: 'Nhắc lịch:' } } })).toBe(2);
    await change(id, 3, 'CONFIRMED');
    await housing.sendViewingReminders();
    expect(await harness.prisma.housingNotification.count({ where: { message: { startsWith: 'Nhắc lịch:' } } })).toBe(4);
  });

  const handoverBody = (version = 0) => ({ version, electricity: 1234, water: 89,
    condition: 'Clean room, existing scratch on the door.', imageUrls: [] as string[] });

  it('hands over with private photos, scopes participants and separates agreed deposit from actual transactions', async () => {
    const id = await completed();
    const leaseId = (await request(`/housing/viewings/${id}/lease`, owner, leaseBody())).json.data.leaseId;
    const path = `/housing/leases/${leaseId}/handover`;
    expect((await get(path, otherOwner)).status).toBe(404);
    expect((await get(path, otherStudent)).status).toBe(404);
    expect((await request(`${path}/accept`, student, { version: 1 })).status).toBe(409);
    expect((await request(path, student, handoverBody(), 'PUT')).status).toBe(403);
    const form = new FormData();
    form.append('file', new Blob([Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64')], { type: 'image/png' }), 'handover.png');
    const upload = await fetch(new URL('/api/v1/uploads', harness.baseUrl), { method: 'POST', headers: { authorization: `Bearer ${owner}` }, body: form });
    const url = (await upload.json() as { data: { url: string } }).data.url;
    const filename = basename(url);
    uploadedPaths.push(join(harness.uploadDirectory, filename));
    expect((await get(`/uploads/${filename}/access`, student)).status).toBe(404);
    expect((await request(path, owner, { ...handoverBody(), imageUrls: [url] }, 'PUT')).status).toBe(200);
    expect((await get(`/uploads/${filename}/access`, student)).status).toBe(200);
    expect((await get(`/uploads/${filename}/access`, otherStudent)).status).toBe(404);
    const detail = (await get(path, student)).json.data;
    expect(detail.handover).toMatchObject({ version: 1, electricity: 1234, water: 89, imageUrls: [url], acceptedAt: null });
    expect(detail.deposit).toEqual({ agreed: 2000000, collected: 0, refunded: 0, deducted: 0, adjustment: 0, balance: 0 });
    await request(`/leases/${leaseId}/deposits`, owner, { type: 'collected', amount: 1000000 });
    await request(`/leases/${leaseId}/deposits`, owner, { type: 'refunded', amount: 200000 });
    await request(`/leases/${leaseId}/deposits`, owner, { type: 'deducted', amount: 100000 });
    expect((await get(path, student)).json.data.deposit).toEqual({ agreed: 2000000, collected: 1000000,
      refunded: 200000, deducted: 100000, adjustment: 0, balance: 700000 });
    expect((await request(path, owner, handoverBody(), 'PUT')).status).toBe(409);
    const results = await Promise.all([request(`${path}/accept`, student, { version: 1 }), request(`${path}/accept`, student, { version: 1 })]);
    expect(results.map((item) => item.status).sort()).toEqual([201, 409]);
    expect((await get(path, owner)).json.data.handover.acceptedAt).not.toBeNull();
    const profile = (await get('/tenant/me', student)).json.data;
    expect(profile.activeLease.requiresHandover).toBe(true);
    expect(profile.activeLease.handedOverAt).not.toBeNull();
    expect((await request(path, owner, handoverBody(2), 'PUT')).status).toBe(409);
    expect(await harness.prisma.depositTransaction.count()).toBe(3);
  });

  it('rejects invalid handover readings, external/public/unowned photos and premature move-in confirmation', async () => {
    const id = await completed();
    const leaseId = (await request(`/housing/viewings/${id}/lease`, owner, leaseBody())).json.data.leaseId;
    const path = `/housing/leases/${leaseId}/handover`;
    expect((await request(path, owner, { ...handoverBody(), electricity: -1 }, 'PUT')).status).toBe(400);
    expect((await request(path, owner, { ...handoverBody(), water: 2147483648 }, 'PUT')).status).toBe(400);
    expect((await request(path, owner, { ...handoverBody(), imageUrls: ['https://example.com/photo.jpg'] }, 'PUT')).status).toBe(400);
    expect((await request(path, owner, { ...handoverBody(), imageUrls: ['/uploads/missing.png'] }, 'PUT')).status).toBe(400);
    await harness.prisma.uploadedFile.createMany({ data: [
      { filename: 'handover-public.png', ownerId, mimeType: 'image/png', purpose: 'PUBLIC_LISTING' },
      { filename: 'handover-unowned.png', ownerId: otherOwnerId, mimeType: 'image/png', purpose: 'PRIVATE' },
      { filename: 'handover-pdf.pdf', ownerId, mimeType: 'application/pdf', purpose: 'PRIVATE' },
    ] });
    for (const filename of ['handover-public.png', 'handover-unowned.png', 'handover-pdf.pdf']) {
      expect((await request(path, owner, { ...handoverBody(), imageUrls: [`/uploads/${filename}`] }, 'PUT')).status).toBe(400);
    }
    await request(path, owner, handoverBody(), 'PUT');
    await harness.prisma.lease.update({ where: { id: leaseId }, data: { startDate: new Date(Date.now() + 86400000) } });
    expect((await request(`${path}/accept`, student, { version: 1 })).status).toBe(409);
    expect((await request(`${path}/accept`, owner, { version: 1 })).status).toBe(403);
  });

  it('rejects booking and saving illustrative listings', async () => {
    await harness.prisma.roomListing.update({ where: { id: listingId }, data: { description: '[explore-preview] Demonstration' } });
    expect((await book()).status).toBe(404);
    expect((await request(`/housing/favorites/${listingId}`, student, undefined, 'PUT')).status).toBe(404);
  });

  it('collects pilot feedback only in the configured area and limits review to administrators', async () => {
    const pilot = await get('/housing/pilot', student);
    expect(pilot.json.data).toEqual({ enabled: true, area: 'Test district' });
    const body = { area: 'Test district', stage: 'viewing', rating: 4, detail: 'The appointment workflow is clear.' };
    expect((await request('/housing/feedback', student, { ...body, area: 'Other area' })).status).toBe(400);
    expect((await request('/housing/feedback', student, { ...body, rating: 6 })).status).toBe(400);
    expect((await request('/housing/feedback', student, body)).status).toBe(201);
    expect((await get('/housing/feedback', owner)).status).toBe(403);
    const result = await get('/housing/feedback', admin);
    expect(result.json.meta.total).toBe(1);
    expect(result.json.summary[0]._avg.rating).toBe(4);
    process.env.RENTAL_PILOT_AREA = '';
    try {
      expect((await get('/housing/pilot', student)).json.data.enabled).toBe(false);
      expect((await request('/housing/feedback', student, body)).status).toBe(400);
    } finally { process.env.RENTAL_PILOT_AREA = 'Test district'; }
  });
});
