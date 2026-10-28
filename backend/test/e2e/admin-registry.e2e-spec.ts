import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createLease, createProperty, createRoom, createTenant, login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin registry acceptance', () => {
  let harness: E2eHarness | undefined;
  beforeEach(async () => {
    const target = new URL(process.env.DATABASE_URL ?? '');
    if (process.env.NODE_ENV !== 'test' || !/^\/rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(target.pathname)) throw new Error('Use the disposable admin E2E runner.');
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); harness = undefined; });
  async function operator() {
    const { email } = await createAdmin(harness!.prisma);
    const user = await harness!.prisma.user.findUniqueOrThrow({ where: { email } });
    await harness!.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset: 'super_admin', permissions: [...ADMIN_PRESETS.super_admin] } });
    return login(harness!.baseUrl, email);
  }
  const api = (path: string, token: string, body?: object) => requestJson<any>(harness!.baseUrl, `/api/v1/admin${path}`, { token, body, method: body ? 'POST' : 'GET' });

  it('keeps plan administration non-financial and protects stale revisions', async () => {
    const admin = await operator();
    const created = await api('/service-plans', admin.accessToken, { code: 'FREE', name: 'Free', price: 0, maxProperties: 1, maxRooms: 5, isActive: true, version: 0, reason: 'Create initial free plan' });
    expect(created.status).toBe(201);
    expect(created.json.data.version).toBe(1);
    expect(created.json).not.toHaveProperty('revenue');
    const stale = await api('/service-plans', admin.accessToken, { code: 'FREE', name: 'Free v2', price: 0, maxProperties: 2, maxRooms: 5, isActive: true, version: 0, reason: 'Attempt stale update' });
    expect(stale.status).toBe(409);
    expect((await api('/service-plans', admin.accessToken)).json.billingMode).toBe('ADMINISTRATIVE_ENTITLEMENTS');
  });

  it('assigns a snapshot only to an active landlord', async () => {
    const admin = await operator();
    const owner = await registerLandlord(harness!.baseUrl);
    const plan = await api('/service-plans', admin.accessToken, { code: 'PRO', name: 'Pro', price: 100000, maxProperties: 2, maxRooms: 10, isActive: true, version: 0, reason: 'Create pro plan' });
    const result = await api(`/landlords/${owner.user.id}/subscription`, admin.accessToken, { planId: plan.json.data.id, planVersion: 1, version: 0, reason: 'Assign pilot entitlement' });
    expect(result.status).toBe(201);
    expect(result.json.data.planSnapshot).toMatchObject({ code: 'PRO', maxRooms: 10 });
    expect(await api(`/subscriptions/${result.json.data.id}/events`, admin.accessToken)).toMatchObject({ status: 200 });
    const property = await createProperty(harness!.baseUrl, owner.accessToken, 'Preserved on cancellation');
    const cancelled = await api(`/subscriptions/${result.json.data.id}/cancel`, admin.accessToken, { version: 1, reason: 'Cancel pilot entitlement safely' });
    expect(cancelled.status).toBe(201);
    expect((await api(`/subscriptions/${result.json.data.id}/cancel`, admin.accessToken, { version: 1, reason: 'Stale cancellation attempt' })).status).toBe(409);
    const history = await api(`/subscriptions/${result.json.data.id}/events`, admin.accessToken);
    expect(history.json.data.map((event: any) => event.action)).toEqual(['CANCELLED', 'ASSIGNED']);
    expect(await harness!.prisma.property.findUnique({ where: { id: property.id } })).not.toBeNull();
    expect(await harness!.prisma.payment.count()).toBe(0);
    expect((await requestJson(harness!.baseUrl, '/api/v1/properties', { token: owner.accessToken, method: 'POST', body: { name: 'Blocked growth', address: '' } })).status).toBe(409);
  });

  it('owner verification is private, requires scanned evidence and has versioned audited decisions', async () => {
    const admin = await operator();
    const owner = await registerLandlord(harness!.baseUrl);
    const other = await registerLandlord(harness!.baseUrl);
    const ticket = await harness!.prisma.supportTicket.create({ data: { requesterId: owner.user.id, subject: 'Verification evidence', category: 'ACCOUNT',
      firstResponseDueAt: new Date(), resolutionDueAt: new Date() } });
    const ownerApi = (token: string, body?: object) => requestJson<any>(harness!.baseUrl, '/api/v1/landlord-verification', { token, body, method: body ? 'POST' : 'GET' });
    const input = { ticketId: ticket.id, version: 0, reason: 'Submit landlord verification' };
    expect((await ownerApi(owner.accessToken, input)).status).toBe(400);
    await harness!.prisma.uploadedFile.create({ data: { filename: 'verification-e2e.pdf', ownerId: owner.user.id, mimeType: 'application/pdf', purpose: 'SUPPORT_CLEAN' } });
    await harness!.prisma.supportAttachment.create({ data: { ticketId: ticket.id, filename: 'verification-e2e.pdf', sha256: 'test-hash', size: 10 } });
    const submitted = await ownerApi(owner.accessToken, input);
    expect(submitted.status).toBe(201);
    expect((await ownerApi(other.accessToken)).json.data).toBeNull();
    expect((await ownerApi(other.accessToken, input)).status).toBe(400);
    const reviewed = await api(`/landlord-verifications/${submitted.json.data.id}/review`, admin.accessToken, { version: 1, status: 'APPROVED', reason: 'Identity documents verified' });
    expect(reviewed.status).toBe(201);
    expect((await ownerApi(owner.accessToken)).json.data.status).toBe('APPROVED');
    expect((await api(`/landlord-verifications/${submitted.json.data.id}/review`, admin.accessToken, { version: 1, status: 'REJECTED', reason: 'Stale decision attempt' })).status).toBe(409);
    const audit = await harness!.prisma.auditLog.findFirstOrThrow({ where: { resourceId: submitted.json.data.id, action: 'admin.verification_review' } });
    expect(audit.actorId).toBeTruthy();
  });

  it('exposes current property approval separately from archival and detects edited snapshots', async () => {
    const admin = await operator();
    const owner = await registerLandlord(harness!.baseUrl);
    const property = await createProperty(harness!.baseUrl, owner.accessToken, 'Review building');
    const submitted = await api(`/properties/${property.id}/submit-review`, admin.accessToken, { version: 0, reason: 'Review current property information' });
    expect(submitted.status).toBe(201);
    const reviewed = await api(`/property-reviews/${submitted.json.data.id}/review`, admin.accessToken, { version: 1, status: 'APPROVED', reason: 'Reviewed property information' });
    expect(reviewed.status).toBe(201);
    expect((await api(`/properties/${property.id}`, admin.accessToken)).json.data.approval.status).toBe('APPROVED');
    await harness!.prisma.property.update({ where: { id: property.id }, data: { address: 'Changed after approval' } });
    expect((await api(`/properties/${property.id}`, admin.accessToken)).json.data.approval.status).toBe('NEEDS_INFO');
    expect((await api('/property-reviews', admin.accessToken)).json.data[0].informationChanged).toBe(true);
    const removal = await requestJson(harness!.baseUrl, `/api/v1/properties/${property.id}`, { token: owner.accessToken, method: 'DELETE' });
    expect(removal.status).toBe(409);
    expect(removal.json).toMatchObject({ error: { code: 'PROPERTY_HAS_REVIEW_HISTORY' } });
    expect(await harness!.prisma.propertyApprovalReview.count({ where: { propertyId: property.id } })).toBe(1);
  });

  it('restricts transaction investigation and redacts payment secrets without ledger mutation', async () => {
    const admin = await operator();
    const owner = await registerLandlord(harness!.baseUrl);
    const property = await createProperty(harness!.baseUrl, owner.accessToken);
    const room = await createRoom(harness!.baseUrl, owner.accessToken, property.id);
    const tenant = await createTenant(harness!.baseUrl, owner.accessToken);
    const lease = await createLease(harness!.baseUrl, owner.accessToken, room.id, tenant.id);
    const invoice = await harness!.prisma.invoice.create({ data: { leaseId: lease.id, roomId: room.id, tenantId: tenant.id,
      billingMonth: new Date('2026-10-01T00:00:00Z'), rentAmount: 3500000, totalAmount: 3500000 } });
    const link = await harness!.prisma.paymentLink.create({ data: { landlordId: owner.user.id, propertyId: property.id, invoiceId: invoice.id, tenantId: tenant.id,
      amount: 3500000, status: 'FAILED', checkoutUrl: 'https://example.test/private-token', accountNumber: 'private-bank-account', qrCode: 'private-qr',
      expiresAt: new Date(Date.now() + 3600000) } });
    await harness!.prisma.paymentWebhookEvent.create({ data: { landlordId: owner.user.id, paymentLinkId: link.id,
      reference: 'private-provider-reference', amount: 3500000, status: 'RECONCILED', reason: 'private-provider-payload' } });
    expect((await api('/finance/transactions?kind=LINK', owner.accessToken)).status).toBe(403);
    const links = await api(`/finance/transactions?kind=LINK&status=FAILED&search=${link.id}`, admin.accessToken);
    expect(links.status).toBe(200);
    expect(links.json.meta).toMatchObject({ readOnly: true, platformRevenue: false, total: 1 });
    expect(links.json.data[0]).toMatchObject({ id: link.id, status: 'FAILED' });
    for (const secret of ['checkoutUrl', 'accountNumber', 'qrCode', 'reason', 'reference']) expect(JSON.stringify(links.json)).not.toContain(`"${secret}"`);
    const events = await api('/finance/transactions?kind=EVENT&search=private-provider-reference', admin.accessToken);
    expect(events.json.meta.total).toBe(1);
    expect(events.json.data[0]).not.toHaveProperty('reference');
    expect(events.json.data[0]).not.toHaveProperty('reason');
    expect((await api('/finance/transactions?kind=PAYMENT&status=FAILED', admin.accessToken)).status).toBe(400);
    const adminUser = await harness!.prisma.user.findUniqueOrThrow({ where: { id: admin.user.id } });
    await harness!.prisma.adminProfile.update({ where: { userId: adminUser.id }, data: { permissions: ['admin.dashboard.view'] } });
    expect((await api('/finance/transactions?kind=LINK', admin.accessToken)).status).toBe(403);
    expect(await harness!.prisma.payment.count()).toBe(0);
    expect((await harness!.prisma.paymentLink.findUniqueOrThrow({ where: { id: link.id } })).status).toBe('FAILED');
  });

  it('serializes concurrent inventory growth against assigned quotas', async () => {
    const admin = await operator();
    const owner = await registerLandlord(harness!.baseUrl);
    const plan = await api('/service-plans', admin.accessToken, { code: 'FREE', name: 'Free', price: 0, maxProperties: 1, maxRooms: 1, isActive: true, version: 0, reason: 'Create limited free plan' });
    await api(`/landlords/${owner.user.id}/subscription`, admin.accessToken, { planId: plan.json.data.id, planVersion: 1, version: 0, reason: 'Assign limited pilot entitlement' });
    const results = await Promise.all(['First', 'Second'].map(name => requestJson<any>(harness!.baseUrl, '/api/v1/properties', { token: owner.accessToken, method: 'POST', body: { name, address: '' } })));
    expect(results.map(result => result.status).sort()).toEqual([201, 409]);
    expect(await harness!.prisma.property.count({ where: { landlordId: owner.user.id } })).toBe(1);
  });
});
