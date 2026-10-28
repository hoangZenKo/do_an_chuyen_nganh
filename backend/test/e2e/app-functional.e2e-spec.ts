import { randomUUID } from 'node:crypto';
import { AuthService } from '../../src/auth/auth.service';
import { businessDay } from '../../src/billing/billing-rules';
import { DeliveryCryptoService } from '../../src/delivery/delivery-crypto.service';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('App functional milestone (disposable database)', () => {
  let harness: E2eHarness;
  let ownerId: string, ownerToken: string, tenantToken: string, tenantUserId: string;
  let propertyId: string, roomId: string, tenantId: string, leaseId: string;
  const api = (path: string, token = ownerToken, method = 'GET', body?: unknown) =>
    requestJson(harness.baseUrl, `/api/v1/${path}`, { token, method, body });
  beforeAll(async () => {
    if (!/^\/rental_functional_test_\d+_[a-f0-9]+$/.test(new URL(process.env.DATABASE_URL!).pathname)) throw new Error('Use run-app-functional-e2e.mjs.');
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); });
  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const owner = await registerLandlord(harness.baseUrl, 'functional-owner');
    ownerToken = owner.accessToken; ownerId = owner.user.id;
    propertyId = (await createProperty(harness.baseUrl, ownerToken)).id;
    roomId = (await createRoom(harness.baseUrl, ownerToken, propertyId)).id;
    tenantId = (await createTenant(harness.baseUrl, ownerToken)).id;
    leaseId = (await createLease(harness.baseUrl, ownerToken, roomId, tenantId)).id;
    const user = await harness.prisma.user.create({ data: { fullName: 'Functional tenant', email: `${randomUUID()}@example.test`, passwordHash: 'not-for-login', role: 'TENANT' } });
    tenantUserId = user.id;
    await harness.prisma.tenant.update({ where: { id: tenantId }, data: { userId: user.id } });
    tenantToken = (await harness.app.get(AuthService).issueSession(user)).data.accessToken;
  });
  async function request(type = 'RENEWAL', extra = {}) {
    const result = await api('tenant/lifecycle-requests', tenantToken, 'POST', { type, leaseId, note: 'Please process request',
      ...(type === 'RENEWAL' ? { requestedEnd: '2030-12-31' } : { requestedStart: businessDay() }), ...extra });
    expect(result.status).toBe(201);
    return result.json!.data;
  }
  async function approve(id: string) {
    const result = await api(`tenant-lifecycle/requests/${id}/review`, ownerToken, 'POST', { status: 'APPROVED', reason: 'Approved after review' });
    expect(result.status).toBe(201);
    return result.json!.data;
  }
  async function settle() {
    const input = { moveOutDate: businessDay(), lines: [] };
    const preview = await api(`leases/${leaseId}/settlement/preview`, ownerToken, 'POST', input);
    expect(preview.status).toBe(201);
    const result = await api(`leases/${leaseId}/settlement/confirm`, ownerToken, 'POST', { ...input, previewFingerprint: preview.json!.data.previewFingerprint, idempotencyKey: randomUUID() });
    expect(result.status).toBe(201);
    return result.json!.data;
  }
  it('rejects duplicate submissions, stale reviews and stale cancellation; concurrent reviewers have one winner', async () => {
    const body = { type: 'RENEWAL', leaseId, requestedEnd: '2030-12-31', note: 'Renew please' };
    const attempts = await Promise.all([api('tenant/lifecycle-requests', tenantToken, 'POST', body), api('tenant/lifecycle-requests', tenantToken, 'POST', body)]);
    expect(attempts.map(result => result.status).sort()).toEqual([201, 409]);
    const pending = attempts.find(result => result.status === 201)!.json!.data;
    const stale = { expectedUpdatedAt: '2000-01-01T00:00:00.000Z' };
    expect((await api(`tenant/lifecycle-requests/${pending.id}/cancel`, tenantToken, 'POST', stale)).status).toBe(409);
    expect((await api(`tenant-lifecycle/requests/${pending.id}/review`, ownerToken, 'POST', { ...stale, status: 'APPROVED', reason: 'Stale view' })).status).toBe(409);
    const results = await Promise.all(['APPROVED', 'REJECTED'].map(status => api(`tenant-lifecycle/requests/${pending.id}/review`, ownerToken, 'POST', { status, reason: 'Concurrent decision', expectedUpdatedAt: pending.updatedAt })));
    expect(results.map(result => result.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: pending.id, action: 'tenant.lifecycle.review' } })).toBe(1);
  });
  it('executes renewal once and preserves deposit ledger and lease history', async () => {
    const pending = await request(); await approve(pending.id);
    const listed = (await api(`tenant-lifecycle/requests?leaseId=${leaseId}`)).json!.data[0];
    const input = { requestKey: randomUUID(), expectedUpdatedAt: listed.updatedAt, expectedLeaseUpdatedAt: listed.lease.updatedAt };
    const attempts = await Promise.all([1, 2].map(() => api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', input)));
    expect(attempts.map(result => result.status)).toEqual([201, 201]);
    expect(attempts.map(result => result.json!.idempotent).sort()).toEqual([false, true]);
    expect((await harness.prisma.lease.findUniqueOrThrow({ where: { id: leaseId } })).endDate?.toISOString()).toBe('2030-12-31T00:00:00.000Z');
    expect(await harness.prisma.leaseChange.count({ where: { leaseId, changeType: 'renew' } })).toBe(1);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId } })).toBe(1);
    expect((await api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', { requestKey: randomUUID() })).status).toBe(409);
    expect((await api(`tenant-lifecycle/requests/${pending.id}/execute`, tenantToken, 'POST', input)).status).toBe(403);
  });
  it('requires canonical settlement for checkout and exposes only the tenants own settlement', async () => {
    const pending = await request('CHECKOUT'); await approve(pending.id);
    expect((await api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', { requestKey: randomUUID() })).status).toBe(409);
    const settlement = await settle();
    const result = await api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', { requestKey: randomUUID() });
    expect(result.status).toBe(201);
    expect((await api(`tenant/leases/${leaseId}/settlement`, tenantToken)).json!.data).toMatchObject({ id: settlement.id, refundStatus: 'NOT_DUE' });
    expect((await api(`tenant/leases/${leaseId}/settlement`, tenantToken)).json!.data).not.toHaveProperty('requestKey');
    const otherUser = await harness.prisma.user.create({ data: { fullName: 'Other tenant', email: `${randomUUID()}@example.test`, passwordHash: 'not-for-login', role: 'TENANT' } });
    const otherToken = (await harness.app.get(AuthService).issueSession(otherUser)).data.accessToken;
    expect((await api(`tenant/leases/${leaseId}/settlement`, otherToken)).status).toBe(404);
    expect((await harness.prisma.room.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('MAINTENANCE');
    expect((await harness.prisma.lease.findUniqueOrThrow({ where: { id: leaseId } })).status).toBe('ENDED');
  });
  it('transfers only after settlement, copies co-occupants without erasing history and never invents a new deposit', async () => {
    const target = await createRoom(harness.baseUrl, ownerToken, propertyId, 'Transfer available');
    await harness.prisma.room.update({ where: { id: target.id }, data: { capacity: 3 } });
    expect((await api(`tenant-lifecycle/leases/${leaseId}/occupants`, ownerToken, 'POST', { fullName: 'Co-occupant' })).status).toBe(201);
    const rooms = await api(`tenant/transfer-rooms?leaseId=${leaseId}&search=Transfer&limit=1`, tenantToken);
    expect(rooms.json!.data.map((room: any) => room.id)).toEqual([target.id]);
    expect(rooms.json!.data[0]).not.toHaveProperty('tenantName');
    const pending = await request('TRANSFER_ROOM', { requestedRoomId: target.id }); await approve(pending.id);
    await settle();
    const body = { requestKey: randomUUID(), monthlyRent: 4200000 };
    const attempts = await Promise.all([1, 2].map(() => api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', body)));
    expect(attempts.map(result => result.status)).toEqual([201, 201]);
    const resultLeaseId = attempts[0].json!.data.resultLeaseId;
    expect(await harness.prisma.lease.count({ where: { roomId: target.id, status: 'ACTIVE' } })).toBe(1);
    expect(await harness.prisma.tenantOccupant.count({ where: { leaseId: resultLeaseId } })).toBe(1);
    expect(await harness.prisma.tenantOccupant.count({ where: { leaseId } })).toBe(1);
    expect(await harness.prisma.depositTransaction.count({ where: { leaseId: resultLeaseId } })).toBe(0);
    expect((await harness.prisma.room.findUniqueOrThrow({ where: { id: target.id } })).status).toBe('OCCUPIED');
  });
  it('rejects execution against a changed lease and filters lifecycle history by lease and status', async () => {
    const pending = await request(); await approve(pending.id);
    const listed = (await api(`tenant-lifecycle/requests?leaseId=${leaseId}&status=APPROVED&limit=1`)).json!.data[0];
    expect(listed.lease.updatedAt).toBeDefined();
    await harness.prisma.lease.update({ where: { id: leaseId }, data: { monthlyRent: 4500000 } });
    expect((await api(`tenant-lifecycle/requests/${pending.id}/execute`, ownerToken, 'POST', { requestKey: randomUUID(), expectedUpdatedAt: listed.updatedAt, expectedLeaseUpdatedAt: listed.lease.updatedAt })).status).toBe(409);
    expect(await harness.prisma.tenantLifecycleExecution.count()).toBe(0);
    expect((await api(`tenant/lifecycle-requests?leaseId=${leaseId}&status=PENDING`, tenantToken)).json!.data).toEqual([]);
  });

  it('queues one recovery token under resend limits, redeems once and revokes existing sessions', async () => {
    const owner = await harness.prisma.user.findUniqueOrThrow({ where: { id: ownerId } });
    const issued = await harness.app.get(AuthService).issueSession(owner);
    const known = await api('auth/account-access/forgot', '', 'POST', { email: owner.email });
    expect(known.status).toBe(201);
    expect((await api('auth/account-access/forgot', '', 'POST', { email: 'missing@example.test' })).json).toEqual(known.json);
    await api('auth/account-access/forgot', '', 'POST', { email: owner.email });
    expect(await harness.prisma.accountAccessToken.count({ where: { userId: owner.id } })).toBe(1);
    const job = await harness.prisma.deliveryJob.findFirstOrThrow({ where: { token: { userId: owner.id } } });
    const delivery = JSON.parse(harness.app.get(DeliveryCryptoService).decrypt(job.payload!));
    const raw = new URL(delivery.actionUrl).hash.slice('#token='.length);
    const token = await harness.prisma.accountAccessToken.findFirstOrThrow({ where: { userId: owner.id } });
    expect(token.tokenHash === raw).toBe(false);
    const body = { token: raw, password: 'NewStrongPassword!123' };
    const results = await Promise.all([1, 2].map(() => api('auth/account-access/redeem', '', 'POST', body)));
    expect(results.map(result => result.status).sort()).toEqual([201, 401]);
    expect((await api('auth/me', issued.data.accessToken)).status).toBe(401);
    expect((await api('auth/refresh', '', 'POST', { refreshToken: issued.data.refreshToken })).status).toBe(401);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: owner.id, action: 'auth.access_token_redeemed' } })).toBe(1);
    expect((await harness.prisma.deliveryJob.findUniqueOrThrow({ where: { id: job.id } })).payload).toBeNull();
  });

  it('rejects expired recovery tokens without changing the password or consuming a session', async () => {
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { id: tenantUserId } });
    await api('auth/account-access/forgot', '', 'POST', { email: user.email });
    const job = await harness.prisma.deliveryJob.findFirstOrThrow({ where: { token: { userId: user.id } } });
    const payload = JSON.parse(harness.app.get(DeliveryCryptoService).decrypt(job.payload!));
    await harness.prisma.accountAccessToken.update({ where: { id: job.tokenId! }, data: { expiresAt: new Date(Date.now() - 1) } });
    expect((await api('auth/account-access/redeem', '', 'POST', { token: new URL(payload.actionUrl).hash.slice(7), password: 'NewStrongPassword!123' })).status).toBe(401);
    expect((await harness.prisma.user.findUniqueOrThrow({ where: { id: user.id } })).passwordHash).toBe(user.passwordHash);
  });

  it('limits tenant invite resends, invalidates the previous link and consumes activation exactly once', async () => {
    const tenant = await createTenant(harness.baseUrl, ownerToken, 'Invited tenant');
    const email = `${randomUUID()}@example.test`;
    const first = await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email });
    expect(first.status).toBe(201);
    expect((await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email })).status).toBe(429);
    await harness.prisma.tenantInvite.update({ where: { id: first.json!.data.id }, data: { createdAt: new Date(Date.now() - 61_000) } });
    const second = await api(`tenants/${tenant.id}/invite`, ownerToken, 'POST', { email });
    expect(second.status).toBe(201);
    expect((await api('tenant-invites/accept', '', 'POST', { inviteCode: first.json!.data.inviteCode, password: 'StrongPassword!123' })).status).toBe(401);
    const results = await Promise.all([1, 2].map(() => api('tenant-invites/accept', '', 'POST', { inviteCode: second.json!.data.inviteCode, password: 'StrongPassword!123' })));
    expect(results.map(result => result.status).sort()).toEqual([201, 401]);
    expect(await harness.prisma.user.count({ where: { email } })).toBe(1);
  });

  it('staff activation is one-time, property scoped and rejects expired invites', async () => {
    const input = { fullName: 'Invited staff', email: `${randomUUID()}@example.test`, preset: 'viewer', propertyIds: [propertyId] };
    const invitation = await api('staff/invites', ownerToken, 'POST', input);
    expect(invitation.status).toBe(201);
    expect((await api('staff/invites', ownerToken, 'POST', input)).status).toBe(429);
    const results = await Promise.all([1, 2].map(() => api('staff/invites/accept', '', 'POST', { inviteCode: invitation.json!.data.inviteCode, password: 'StrongPassword!123' })));
    expect(results.map(result => result.status).sort()).toEqual([201, 401]);
    const session = results.find(result => result.status === 201)!.json!.data;
    expect((await api('properties', session.accessToken)).json!.data.map((property: any) => property.id)).toEqual([propertyId]);
    const expired = await api('staff/invites', ownerToken, 'POST', { ...input, email: `${randomUUID()}@example.test` });
    await harness.prisma.staffInvite.update({ where: { id: expired.json!.data.id }, data: { expiresAt: new Date(Date.now() - 1) } });
    expect((await api('staff/invites/accept', '', 'POST', { inviteCode: expired.json!.data.inviteCode, password: 'StrongPassword!123' })).status).toBe(401);
  });

  it('keeps uploaded proof pending, then records the canonical receipt allocation only after approval', async () => {
    const invoice = await api('billing/invoices', ownerToken, 'POST', { leaseId, billingMonth: '2030-12-01' });
    expect(invoice.status).toBe(201);
    const proof = await api(`tenant/invoices/${invoice.json!.data.id}/payment-proofs`, tenantToken, 'POST', { amount: 100000, method: 'bank_transfer', proofImageUrls: [] });
    expect(proof.status).toBe(201);
    expect((await harness.prisma.payment.count({ where: { invoiceId: invoice.json!.data.id } }))).toBe(0);
    expect((await harness.prisma.billingReceipt.count({ where: { tenantId } }))).toBe(0);
    expect((await api('billing/payment-proofs?status=pending', ownerToken)).json!.data.map((item: any) => item.id)).toContain(proof.json!.data.id);
    const rejected = await api(`billing/payment-proofs/${proof.json!.data.id}/review`, ownerToken, 'POST', { status: 'rejected', note: 'Ảnh không đủ rõ' });
    expect(rejected.status).toBe(201);
    expect((await harness.prisma.paymentProof.findUniqueOrThrow({ where: { id: proof.json!.data.id } })).reviewNote).toBe('Ảnh không đủ rõ');
    const second = await api(`tenant/invoices/${invoice.json!.data.id}/payment-proofs`, tenantToken, 'POST', { amount: 100000, method: 'bank_transfer', proofImageUrls: [] });
    expect(second.status).toBe(201);
    const approved = await api(`billing/payment-proofs/${second.json!.data.id}/review`, ownerToken, 'POST', { status: 'approved', note: 'Đã đối soát sao kê' });
    expect(approved.status).toBe(201);
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.json!.data.id } })).toBe(1);
    expect(await harness.prisma.paymentAllocation.count()).toBe(1);
    expect(await harness.prisma.billingReceipt.count({ where: { tenantId } })).toBe(1);
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.json!.data.id } })).paidAmount).toBe(100000);
    const duplicate = await api(`billing/payment-proofs/${second.json!.data.id}/review`, ownerToken, 'POST', { status: 'approved' });
    expect(duplicate.status).toBe(409);
  });
});
