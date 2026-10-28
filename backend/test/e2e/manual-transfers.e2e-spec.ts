import { randomUUID } from 'node:crypto';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Manual transfer: recipient, tenant proof and landlord confirmation', () => {
  let harness: E2eHarness;
  let ownerToken: string;
  let strangerToken: string;
  let tenantToken: string;
  let otherTenantToken: string;
  let propertyId: string;
  let invoice: any;
  let ownerId: string;
  let tenantUserId: string;
  const account = { version: 0, enabled: true, bankName: 'Bank test', accountName: 'TEST OWNER', accountNumber: '0012345678' };
  const call = (path: string, token: string, method = 'GET', body?: unknown) => requestJson(harness.baseUrl, `/api/v1${path}`, { method, token, body });
  const accountPath = () => `/properties/${propertyId}/transfer-account`;
  const instructions = () => `/tenant/invoices/${invoice.id}/transfer-instructions`;
  const proof = (amount = 10000) => call(`/tenant/invoices/${invoice.id}/payment-proofs`, tenantToken, 'POST', {
    requestKey: randomUUID(), amount, method: 'bank_transfer', note: 'Bank receipt for test', proofImageUrls: [],
  });

  beforeAll(async () => {
    if (process.env.NODE_ENV !== 'test' || !/^rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(new URL(process.env.DATABASE_URL!).pathname.slice(1))) {
      throw new Error('Use the disposable manual transfer runner.');
    }
  });
  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const owner = await registerLandlord(harness.baseUrl, 'transfer-owner');
    ownerToken = owner.accessToken;
    strangerToken = (await registerLandlord(harness.baseUrl, 'transfer-stranger')).accessToken;
    ownerId = (await harness.prisma.user.findUniqueOrThrow({ where: { email: owner.user.email } })).id;
    propertyId = (await createProperty(harness.baseUrl, ownerToken)).id;
    const room = await createRoom(harness.baseUrl, ownerToken, propertyId);
    const tenant = await createTenant(harness.baseUrl, ownerToken);
    const lease = await createLease(harness.baseUrl, ownerToken, room.id, tenant.id);
    const jwt = new JwtService({ secret: harness.app.get(ConfigService).getOrThrow('JWT_ACCESS_SECRET') });
    const user = await harness.prisma.user.create({ data: { email: `${randomUUID()}@example.test`, fullName: 'Transfer tenant', passwordHash: 'unused', role: 'TENANT' } });
    tenantUserId = user.id;
    await harness.prisma.tenant.update({ where: { id: tenant.id }, data: { userId: user.id } });
    tenantToken = jwt.sign({ sub: user.id, typ: 'access', ver: 0 });
    const other = await harness.prisma.user.create({ data: { email: `${randomUUID()}@example.test`, fullName: 'Other tenant', passwordHash: 'unused', role: 'TENANT' } });
    otherTenantToken = jwt.sign({ sub: other.id, typ: 'access', ver: 0 });
    invoice = await harness.prisma.invoice.create({ data: { leaseId: lease.id, roomId: room.id, tenantId: tenant.id,
      billingMonth: new Date('2032-01-01Z'), rentAmount: 10000, totalAmount: 10000 } });
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); });

  it('binds account updates to the landlord and rejects stale versions and malformed inputs', async () => {
    expect((await call(accountPath(), strangerToken, 'PUT', account)).status).toBe(404);
    expect((await call(accountPath(), tenantToken, 'PUT', account)).status).toBe(403);
    expect((await call(accountPath(), ownerToken, 'PUT', { ...account, accountNumber: 'not-a-bank-account' })).status).toBe(400);
    const saved = await call(accountPath(), ownerToken, 'PUT', account);
    expect(saved.status).toBe(200);
    expect(saved.json!.data).toMatchObject({ version: 1, accountNumber: '0012345678' });
    expect(saved.response.headers.get('cache-control')).toContain('no-store');
    expect((await call(accountPath(), ownerToken, 'PUT', account)).status).toBe(409);
    const log = await harness.prisma.auditLog.findFirstOrThrow({ where: { action: 'billing.transfer_account.update' } });
    expect(JSON.stringify(log)).not.toContain(account.accountNumber);
  });

  it('shows only owned payable invoice instructions; never creates a payment or demo session', async () => {
    await call(accountPath(), ownerToken, 'PUT', account);
    expect((await call(instructions(), otherTenantToken)).status).toBe(404);
    const result = await call(instructions(), tenantToken);
    expect(result.response.headers.get('cache-control')).toContain('no-store');
    expect(result.json!.data).toMatchObject({ mode: 'MANUAL_BANK_TRANSFER', canSubmit: true, availableAmount: 10000,
      account: { accountNumber: '0012345678' } });
    expect(await harness.prisma.payment.count()).toBe(0);
    expect(await harness.prisma.demoCheckoutSession.count()).toBe(0);
    await harness.prisma.invoice.update({ where: { id: invoice.id }, data: { isDemo: true } });
    expect((await call(instructions(), tenantToken)).json!.data).toMatchObject({ canSubmit: false, account: null });
    expect((await proof()).status).toBe(409);
  });

  it('reserves pending proofs without reducing debt, then records exactly one receipt on confirmation', async () => {
    await call(accountPath(), ownerToken, 'PUT', account);
    const form = new FormData();
    form.append('purpose', 'PRIVATE');
    form.append('file', new Blob([Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a3ioAAAAASUVORK5CYII=', 'base64')], { type: 'image/png' }), 'receipt.png');
    const upload = await fetch(`${harness.baseUrl}/api/v1/uploads`, { method: 'POST', headers: { authorization: `Bearer ${tenantToken}` }, body: form });
    expect(upload.status).toBe(201);
    const uploaded = await upload.json() as { data: { url: string } };
    const request = await call(`/tenant/invoices/${invoice.id}/payment-proofs`, tenantToken, 'POST', {
      requestKey: randomUUID(), amount: 10000, method: 'bank_transfer', proofImageUrls: [uploaded.data.url],
    });
    expect(request.status).toBe(201);
    const proofFile = uploaded.data.url.split('/').pop();
    expect((await call(`/uploads/${proofFile}/access`, ownerToken)).status).toBe(200);
    expect((await call(`/uploads/${proofFile}/access`, strangerToken)).status).toBe(404);
    const proofId = request.json!.data.id;
    expect((await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).paidAmount).toBe(0);
    expect((await call(instructions(), tenantToken)).json!.data).toMatchObject({ pendingAmount: 10000, availableAmount: 0, canSubmit: false });
    expect((await proof()).status).toBe(409);
    const reviewPath = `/billing/payment-proofs/${proofId}/review`;
    expect((await call(reviewPath, strangerToken, 'POST', { status: 'approved' })).status).toBe(404);
    expect((await call(reviewPath, tenantToken, 'POST', { status: 'approved' })).status).toBe(403);
    const approvals = await Promise.all([call(reviewPath, ownerToken, 'POST', { status: 'approved', note: 'Checked bank receipt' }),
      call(reviewPath, ownerToken, 'POST', { status: 'approved', note: 'Checked bank receipt' })]);
    expect(approvals.map(result => result.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(1);
    expect(await harness.prisma.billingReceipt.count()).toBe(1);
    expect(await harness.prisma.paymentAllocation.count()).toBe(1);
    expect(await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).toMatchObject({ paidAmount: 10000, status: 'PAID' });
  });

  it('rejection leaves the ledger unchanged and permits a corrected proof', async () => {
    await call(accountPath(), ownerToken, 'PUT', account);
    const submitted = await proof();
    const rejected = await call(`/billing/payment-proofs/${submitted.json!.data.id}/review`, ownerToken, 'POST', { status: 'rejected', note: 'Funds not received' });
    expect(rejected.status).toBe(201);
    expect(await harness.prisma.payment.count()).toBe(0);
    expect((await call(instructions(), tenantToken)).json!.data).toMatchObject({ pendingAmount: 0, availableAmount: 10000, canSubmit: true });
    expect((await proof()).status).toBe(201);
  });

  it('preserves partial balance and replays a proof request without duplicate receipt creation', async () => {
    await call(accountPath(), ownerToken, 'PUT', account);
    const path = `/tenant/invoices/${invoice.id}/payment-proofs`;
    const payload = { requestKey: randomUUID(), amount: 4000, method: 'bank_transfer' };
    const first = await call(path, tenantToken, 'POST', payload);
    const replay = await call(path, tenantToken, 'POST', payload);
    expect(replay.json!.data.id).toBe(first.json!.data.id);
    await call(`/billing/payment-proofs/${first.json!.data.id}/review`, ownerToken, 'POST', { status: 'approved' });
    expect((await call(instructions(), tenantToken)).json!.data).toMatchObject({ remainingAmount: 6000, pendingAmount: 0, availableAmount: 6000 });
    expect(await harness.prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } })).toMatchObject({ paidAmount: 4000, status: 'PARTIAL' });
    expect(await harness.prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(1);
  });

  it('grants private QR access only to the recipient owner and related tenants while enabled', async () => {
    const filename = `${randomUUID()}.png`;
    await harness.prisma.uploadedFile.create({ data: { filename, ownerId, mimeType: 'image/png', purpose: 'PRIVATE' } });
    expect((await call(accountPath(), ownerToken, 'PUT', { ...account, qrImagePath: `/uploads/${filename}` })).status).toBe(200);
    expect((await call(`/uploads/${filename}/access`, tenantToken)).status).toBe(200);
    expect((await call(`/uploads/${filename}/access`, otherTenantToken)).status).toBe(404);
    expect((await call(`/uploads/${filename}/access`, strangerToken)).status).toBe(404);
    const alien = `${randomUUID()}.png`;
    await harness.prisma.uploadedFile.create({ data: { filename: alien, ownerId: tenantUserId, mimeType: 'image/png', purpose: 'PRIVATE' } });
    expect((await call(accountPath(), ownerToken, 'PUT', { ...account, version: 1, qrImagePath: `/uploads/${alien}` })).status).toBe(400);
    await call(accountPath(), ownerToken, 'PUT', { ...account, version: 1, enabled: false });
    expect((await call(`/uploads/${filename}/access`, tenantToken)).status).toBe(404);
    expect((await call(instructions(), tenantToken)).json!.data).toMatchObject({ account: null, canSubmit: false });
  });
});
