import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createProperty, createRoom, login, registerLandlord, resetDatabase, testPassword } from './e2e-fixtures';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { totp, tokenHash } from '../../src/auth/admin-mfa.service';
import { randomBytes } from 'node:crypto';

describe('Admin Console MVP', () => {
  let harness: E2eHarness;
  const oldKey = process.env.ADMIN_MFA_ENCRYPTION_KEY;
  const oldRequired = process.env.ADMIN_MFA_REQUIRED;
  beforeEach(async () => {
    process.env.ADMIN_MFA_ENCRYPTION_KEY = Buffer.alloc(32, 7).toString('base64');
    process.env.ADMIN_MFA_REQUIRED = 'false';
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
  });
  afterEach(async () => {
    await closeE2eHarness(harness);
    if (oldKey === undefined) delete process.env.ADMIN_MFA_ENCRYPTION_KEY; else process.env.ADMIN_MFA_ENCRYPTION_KEY = oldKey;
    if (oldRequired === undefined) delete process.env.ADMIN_MFA_REQUIRED; else process.env.ADMIN_MFA_REQUIRED = oldRequired;
  });
  async function operator(preset = 'super_admin') {
    const { email } = await createAdmin(harness.prisma);
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { email } });
    await harness.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { ...await login(harness.baseUrl, email), id: user.id, email };
  }
  async function pendingListing() {
    const owner = await registerLandlord(harness.baseUrl);
    const property = await createProperty(harness.baseUrl, owner.accessToken);
    const room = await createRoom(harness.baseUrl, owner.accessToken, property.id);
    const listing = await harness.prisma.roomListing.create({ data: { roomId: room.id, title: 'Pending test listing', description: 'A listing for moderation integration tests', city: 'HCM', district: 'District 1', publicAddress: 'Public address', monthlyRent: 3000000, areaSqm: 20, imageUrls: [], amenities: [], status: 'PENDING' } });
    return { owner, property, room, listing };
  }
  const call = (path: string, token?: string, body?: unknown, method?: string) => requestJson<any>(harness.baseUrl, `/api/v1${path}`, { token, body, method: method ?? (body ? 'POST' : 'GET') });

  it('fails closed for missing profiles and separates moderator, support and analyst', async () => {
    const moderator = await operator('moderator');
    expect((await call('/admin/accounts', moderator.accessToken)).status).toBe(403);
    expect((await call('/admin/audit-logs', moderator.accessToken)).status).toBe(403);
    expect((await call('/admin/listings', moderator.accessToken)).status).toBe(200);
    const support = await operator('support');
    expect((await call('/admin/listings', support.accessToken)).status).toBe(403);
    expect((await call('/admin/accounts', support.accessToken)).status).toBe(200);
    expect((await call('/admin/landlords', support.accessToken)).status).toBe(403);
    const overview = await call('/admin/overview', support.accessToken);
    expect(overview.json.data.recentLandlords).toEqual([]);
    const analyst = await operator('analyst');
    expect((await call('/admin/moderation/queue', analyst.accessToken)).status).toBe(403);
    await harness.prisma.adminProfile.delete({ where: { userId: analyst.id } });
    expect((await call('/admin/overview', analyst.accessToken)).status).toBe(403);
  });

  it('paginates accounts and legacy resources with stable metadata and masking', async () => {
    const admin = await operator();
    await registerLandlord(harness.baseUrl, 'page-first'); await registerLandlord(harness.baseUrl, 'page-second');
    const response = await call('/admin/accounts?limit=1&page=2&role=LANDLORD', admin.accessToken);
    expect(response.status).toBe(200); expect(response.json.meta).toMatchObject({ total: 2, page: 2, limit: 1, pages: 2 });
    expect(response.json.data[0].email).toContain('***'); expect(response.json.data[0].phone).toContain('***');
    expect(response.json.data[0].passwordHash).toBeUndefined();
    const landlords = await call('/admin/landlords?limit=1', admin.accessToken);
    expect(landlords.json.meta.total).toBe(2); expect(landlords.json.data).toHaveLength(1);
    expect((await call('/admin/accounts?limit=1000', admin.accessToken)).status).toBe(400);
  });

  it('suspends and restores without reviving access or refresh tokens; records reasons atomically', async () => {
    const admin = await operator(), owner = await registerLandlord(harness.baseUrl);
    const suspended = await call(`/admin/accounts/${owner.user.id}/suspend`, admin.accessToken, { reason: 'Verified support case ABC-123', version: 0 });
    expect(suspended.status).toBe(201);
    expect((await call('/properties', owner.accessToken)).status).toBe(401);
    expect((await call(`/admin/accounts/${owner.user.id}/restore`, admin.accessToken, { reason: 'Verified account recovery ABC-123', version: 0 })).status).toBe(409);
    expect((await call(`/admin/accounts/${owner.user.id}/restore`, admin.accessToken, { reason: 'Verified account recovery ABC-123', version: 1 })).status).toBe(201);
    expect((await call('/properties', owner.accessToken)).status).toBe(401);
    expect((await call('/auth/refresh', undefined, { refreshToken: owner.refreshToken })).status).toBe(401);
    const audit = await harness.prisma.auditLog.findMany({ where: { resourceId: owner.user.id, action: { in: ['admin.account_suspend', 'admin.account_restore'] } } });
    expect(audit).toHaveLength(2); expect(audit[0].summary).toContain('ABC-123');
  });

  it('allows only one of two concurrent account status mutations', async () => {
    const admin = await operator(), owner = await registerLandlord(harness.baseUrl);
    const results = await Promise.all([1, 2].map(() => call(`/admin/accounts/${owner.user.id}/suspend`, admin.accessToken, { reason: 'Concurrent account moderation', version: 0 })));
    expect(results.map(response => response.status).sort()).toEqual([201, 409]);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: owner.user.id, action: 'admin.account_suspend' } })).toBe(1);
  });

  it('revokes sessions without changing account activation or deleting resources', async () => {
    const admin = await operator(), owner = await registerLandlord(harness.baseUrl);
    const property = await createProperty(harness.baseUrl, owner.accessToken);
    expect((await call(`/admin/accounts/${owner.user.id}/revoke-sessions`, admin.accessToken, { reason: 'Reported lost personal device' })).status).toBe(201);
    expect((await call('/properties', owner.accessToken)).status).toBe(401);
    expect((await harness.prisma.user.findUniqueOrThrow({ where: { id: owner.user.id } })).isActive).toBe(true);
    expect(await harness.prisma.property.count({ where: { id: property.id } })).toBe(1);
  });

  it('audits support reads and PII reveal without leaking password, documents or financial mutations', async () => {
    const admin = await operator(), support = await operator('support'), owner = await registerLandlord(harness.baseUrl);
    const context = await call('/admin/support-context', support.accessToken, { kind: 'account', id: owner.user.id, reason: 'Support case ACCT-987 opened' });
    expect(context.status).toBe(201); expect(context.json.data.email).toContain('***');
    expect(context.json.data.passwordHash).toBeUndefined(); expect(context.response.headers.get('cache-control')).toContain('no-store');
    expect((await call(`/admin/accounts/${owner.user.id}/reveal`, support.accessToken, { reason: 'Support case ACCT-987 opened' })).status).toBe(403);
    const reveal = await call(`/admin/accounts/${owner.user.id}/reveal`, admin.accessToken, { reason: 'Verified need for ACCT-987' });
    expect(reveal.json.data.email).toBe(owner.email);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: owner.user.id, action: 'admin.pii_reveal' } })).toBe(1);
    expect((await call('/admin/support-context', support.accessToken, { kind: 'account', id: owner.user.id, reason: 'short' })).status).toBe(400);
    expect((await call('/admin/accounts?role=ADMIN', support.accessToken)).status).toBe(403);
  });

  it('keeps queue counts, assignments and decisions consistent under concurrent admins', async () => {
    const first = await operator('moderator'), second = await operator('moderator');
    const { listing } = await pendingListing();
    const queue = await call('/admin/moderation/queue?kind=LISTING', first.accessToken);
    expect(queue.status).toBe(200); expect(queue.json.meta.total).toBe(1);
    const data = { kind: 'LISTING', targetId: listing.id, version: 0, priority: 'HIGH', dueAt: new Date(Date.now() + 3600000).toISOString(), note: 'Internal note only', reason: 'Claim for content inspection' };
    const claims = await Promise.all([call('/admin/moderation/work', first.accessToken, { ...data, assigneeId: first.id }), call('/admin/moderation/work', second.accessToken, { ...data, assigneeId: second.id })]);
    expect(claims.map(response => response.status).sort()).toEqual([201, 409]);
    const winner = claims[0].status === 201 ? first : second, loser = claims[0].status === 201 ? second : first;
    expect((await call(`/admin/listings/${listing.id}/review`, loser.accessToken, { version: 1, decision: 'REJECT', note: '[POLICY] Incorrect content verified' })).status).toBe(403);
    expect((await call(`/admin/listings/${listing.id}/review`, winner.accessToken, { version: 1, decision: 'REJECT', note: '[POLICY] Incorrect content verified' })).status).toBe(201);
    expect((await call('/admin/moderation/queue?kind=LISTING', winner.accessToken)).json.meta.total).toBe(0);
    expect((await call('/admin/analytics/summary?days=7', winner.accessToken)).json.data.queue).toEqual([]);
    expect((await call(`/admin/listings/${listing.id}/review`, winner.accessToken, { version: 1, decision: 'PUBLISH', note: '[CONTENT_CHECK] Duplicate action blocked' })).status).toBe(409);
  });

  it('rejects invalid assignees and exposes a permission-filtered dashboard', async () => {
    const admin = await operator(), analyst = await operator('analyst'), { listing, owner } = await pendingListing();
    expect((await call('/admin/moderation/work', admin.accessToken, { kind: 'LISTING', targetId: listing.id, version: 0, assigneeId: owner.user.id, priority: 'NORMAL', dueAt: new Date().toISOString(), note: '', reason: 'Invalid assignee rejected' })).status).toBe(400);
    const summary = await call('/admin/analytics/summary?days=7', analyst.accessToken);
    expect(summary.status).toBe(200); expect(summary.json.data.queue).toEqual([]); expect(summary.json.data.trends.length).toBeGreaterThan(0);
    expect((await call('/admin/analytics/summary?days=3650', admin.accessToken)).status).toBe(400);
  });

  it('enforces MFA, blocks TOTP replay and consumes recovery codes once across refresh', async () => {
    const admin = await operator();
    process.env.ADMIN_MFA_REQUIRED = 'true';
    expect((await call('/admin/overview', admin.accessToken)).status).toBe(403);
    const enroll = await call('/admin/me/security/enroll', admin.accessToken, {});
    expect(enroll.status).toBe(201); expect(enroll.json.data.secret).toBeTruthy();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; let bits = '', values: number[] = [];
    for (const character of enroll.json.data.secret as string) bits += alphabet.indexOf(character).toString(2).padStart(5, '0');
    for (let index = 0; index + 8 <= bits.length; index += 8) values.push(Number.parseInt(bits.slice(index, index + 8), 2));
    const code = totp(Buffer.from(values), BigInt(Math.floor(Date.now() / 30000)));
    const confirm = await call('/admin/me/security/confirm', admin.accessToken, { code });
    expect(confirm.status).toBe(201); expect(confirm.json.data.recoveryCodes).toHaveLength(8);
    expect((await call('/admin/overview', admin.accessToken)).status).toBe(401);
    expect((await call('/auth/login', undefined, { email: admin.email, password: testPassword })).json.error.code).toBe('MFA_REQUIRED');
    expect((await call('/auth/login', undefined, { email: admin.email, password: testPassword, mfaCode: code })).status).toBe(401);
    const recovery = confirm.json.data.recoveryCodes[0];
    const signed = await call('/auth/login', undefined, { email: admin.email, password: testPassword, mfaCode: recovery });
    expect(signed.status).toBe(201); expect(signed.json.data.user.adminMfaVerified).toBe(true);
    expect((await call('/admin/overview', signed.json.data.accessToken)).status).toBe(200);
    expect((await call('/auth/login', undefined, { email: admin.email, password: testPassword, mfaCode: recovery })).status).toBe(401);
    const refreshed = await call('/auth/refresh', undefined, { refreshToken: signed.json.data.refreshToken });
    expect(refreshed.json.data.user.adminMfaVerified).toBe(true);
    expect((await call('/admin/overview', refreshed.json.data.accessToken)).status).toBe(200);
  });

  it('consumes reset tokens once and never returns a token through public recovery', async () => {
    const owner = await registerLandlord(harness.baseUrl);
    const raw = randomBytes(32).toString('base64url');
    await harness.prisma.accountAccessToken.create({ data: { userId: owner.user.id, tokenHash: tokenHash(raw), purpose: 'PASSWORD_RESET', expiresAt: new Date(Date.now() + 60000) } });
    const results = await Promise.all([1, 2].map(() => call('/auth/account-access/redeem', undefined, { token: raw, password: 'NewSecurePassword!12345' })));
    expect(results.map(response => response.status).sort()).toEqual([201, 401]);
    expect((await call('/properties', owner.accessToken)).status).toBe(401);
    const exists = await call('/auth/account-access/forgot', undefined, { email: owner.email });
    const absent = await call('/auth/account-access/forgot', undefined, { email: 'missing@example.com' });
    expect(exists.json).toEqual(absent.json); expect(JSON.stringify(exists.json)).not.toContain(raw);
  });
});
