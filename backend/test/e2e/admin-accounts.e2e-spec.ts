import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';
import { AdminMfaService, tokenHash } from '../../src/auth/admin-mfa.service';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, createProperty, createTenant, login, registerLandlord, resetDatabase, uniqueEmail } from './e2e-fixtures';

describe('Admin accounts database acceptance', () => {
  let harness: E2eHarness | undefined;
  const reason = 'Verified account acceptance request';

  beforeEach(async () => {
    const target = new URL(process.env.DATABASE_URL ?? '');
    if (process.env.NODE_ENV !== 'test' ||
        !['localhost', '127.0.0.1', '[::1]'].includes(target.hostname) ||
        !/^\/rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(target.pathname)) {
      throw new Error('Use npm run test:admin-accounts:e2e with a disposable database.');
    }
    harness = await createE2eHarness();
    const database = await harness.prisma.$queryRaw<Array<{ name: string }>>`SELECT current_database() AS name`;
    if (database[0].name !== target.pathname.slice(1)) throw new Error('Connected database does not match disposable target.');
    await resetDatabase(harness.prisma);
  });

  afterEach(async () => {
    jest.restoreAllMocks();
    if (harness) await closeE2eHarness(harness);
    harness = undefined;
  });

  const api = (path: string, token?: string, body?: object, method?: string) =>
    requestJson<any>(harness!.baseUrl, `/api/v1${path}`, { token, body, method: method ?? (body ? 'POST' : 'GET') });

  async function operator(preset = 'super_admin') {
    const created = await createAdmin(harness!.prisma, 'account-acceptance');
    const user = await harness!.prisma.user.findUniqueOrThrow({ where: { email: created.email } });
    await harness!.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset, permissions: [...ADMIN_PRESETS[preset]] } });
    return { id: user.id, ...await login(harness!.baseUrl, created.email) };
  }

  async function staff(ownerId: string) {
    const owner = await harness!.prisma.user.findUniqueOrThrow({ where: { id: ownerId } });
    const user = await harness!.prisma.user.create({ data: {
      email: uniqueEmail('acceptance-staff'), fullName: 'Dependent staff', role: 'STAFF', passwordHash: owner.passwordHash,
      staffProfile: { create: { landlordId: ownerId, fullName: 'Dependent staff' } },
    } });
    return { id: user.id, ...await login(harness!.baseUrl, user.email) };
  }

  it('combines trimmed search, role, status and inclusive Vietnam dates with stable pagination', async () => {
    const root = await operator();
    const from = '2026-10-25T17:00:00.000Z';
    const to = '2026-10-26T16:59:59.999Z';
    const rows = [
      { role: 'LANDLORD' as const, isActive: true, createdAt: from },
      { role: 'LANDLORD' as const, isActive: true, createdAt: to },
      { role: 'LANDLORD' as const, isActive: true, createdAt: '2026-10-25T16:59:59.999Z' },
      { role: 'LANDLORD' as const, isActive: true, createdAt: '2026-10-26T17:00:00.000Z' },
      { role: 'LANDLORD' as const, isActive: false, createdAt: from },
      { role: 'TENANT' as const, isActive: true, createdAt: from },
    ];
    const users = [];
    for (const row of rows) users.push(await harness!.prisma.user.create({ data: {
      ...row, createdAt: new Date(row.createdAt), email: uniqueEmail('boundary'),
      fullName: 'Boundary Account', phone: '+84901112222', passwordHash: 'not-for-login',
    } }));
    const query = new URLSearchParams({ search: '  bOuNdArY aCcOuNt  ', role: 'LANDLORD', status: 'active', from, to, limit: '1' });
    const first = await api(`/admin/accounts?${query}`, root.accessToken);
    const second = await api(`/admin/accounts?${query}&page=2`, root.accessToken);
    expect(first.status).toBe(200);
    expect(first.response.headers.get('cache-control')).toBe('private, no-store');
    expect(first.json.meta).toEqual({ page: 1, limit: 1, total: 2, pages: 2 });
    expect([first.json.data[0].id, second.json.data[0].id]).toEqual([users[1].id, users[0].id]);
    expect(first.json.data[0]).toMatchObject({ version: 0, email: expect.stringContaining('***'), phone: '***222' });
    expect(first.text).not.toContain(users[1].email);
    expect(first.text).not.toContain('passwordHash');
    expect((await api(`/admin/accounts?${query}&page=3`, root.accessToken)).json.data).toEqual([]);
    expect((await api(`/admin/accounts?from=${to}&to=${from}`, root.accessToken)).status).toBe(400);
    for (const invalid of ['role=ADMIN', 'limit=101', 'page=0', 'from=invalid', `search=${'x'.repeat(121)}`]) {
      expect((await api(`/admin/accounts?${invalid}`, root.accessToken)).status).toBe(invalid === 'role=ADMIN' ? 403 : 400);
    }
  });

  it('returns masked detail, real counts/history and enforces live permission and target boundaries', async () => {
    const root = await operator(), support = await operator('support');
    const owner = await registerLandlord(harness!.baseUrl);
    await createProperty(harness!.baseUrl, owner.accessToken);
    await createTenant(harness!.baseUrl, owner.accessToken);
    expect((await api(`/admin/accounts/${owner.user.id}/suspend`, root.accessToken, { reason, version: 0 })).status).toBe(201);
    const detail = await api(`/admin/accounts/${owner.user.id}`, support.accessToken);
    expect(detail.status).toBe(200);
    expect(detail.response.headers.get('cache-control')).toBe('private, no-store');
    expect(detail.json.data).toMatchObject({ id: owner.user.id, version: 1, isActive: false,
      counts: { properties: 1, tenants: 1 }, history: [expect.objectContaining({ action: 'admin.account_suspend', summary: reason })] });
    expect(detail.text).not.toContain(owner.email);
    expect(detail.text).not.toContain('passwordHash');
    expect((await api(`/admin/accounts/${owner.user.id}`)).status).toBe(401);
    expect((await api(`/admin/accounts/${root.id}`, root.accessToken)).status).toBe(404);
    expect((await api(`/admin/accounts/${randomUUID()}`, root.accessToken)).status).toBe(404);
    expect((await api('/admin/accounts/not-a-uuid', root.accessToken)).status).toBe(400);
    for (const action of ['suspend', 'restore', 'revoke-sessions', 'reveal', 'reset-password']) {
      const payload = ['suspend', 'restore'].includes(action) ? { reason, version: 0 } : { reason };
      expect((await api(`/admin/accounts/${owner.user.id}/${action}`, support.accessToken, payload)).status).toBe(403);
      expect((await api(`/admin/accounts/${root.id}/${action}`, root.accessToken, payload)).status).toBe(404);
    }
    await harness!.prisma.adminProfile.update({ where: { userId: support.id }, data: { permissions: ['admin.dashboard.view'] } });
    expect((await api(`/admin/accounts/${owner.user.id}`, support.accessToken)).status).toBe(403);
    expect((await api('/admin/accounts', support.accessToken)).status).toBe(403);
  });

  it('physically revokes landlord and dependent staff sessions without restoring old tokens', async () => {
    const root = await operator(), owner = await registerLandlord(harness!.baseUrl);
    const worker = await staff(owner.user.id), unrelated = await registerLandlord(harness!.baseUrl);
    const token = await harness!.prisma.accountAccessToken.create({ data: { userId: owner.user.id,
      purpose: 'PASSWORD_RESET', tokenHash: tokenHash(randomUUID()), expiresAt: new Date(Date.now() + 60000) } });
    const result = await api(`/admin/accounts/${owner.user.id}/suspend`, root.accessToken, { reason, version: 0 });
    expect(result.status).toBe(201);
    for (const userId of [owner.user.id, worker.id]) {
      expect(await harness!.prisma.authSession.count({ where: { userId, revokedAt: null } })).toBe(0);
      expect(await harness!.prisma.refreshToken.count({ where: { userId, revokedAt: null } })).toBe(0);
      expect((await harness!.prisma.user.findUniqueOrThrow({ where: { id: userId } })).sessionVersion).toBe(1);
    }
    expect((await harness!.prisma.accountAccessToken.findUniqueOrThrow({ where: { id: token.id } })).consumedAt).not.toBeNull();
    expect((await api('/auth/me', unrelated.accessToken)).status).toBe(200);
    const dormant = await harness!.prisma.authSession.create({ data: { userId: owner.user.id, userVersion: 1, expiresAt: new Date(Date.now() + 60000) } });
    expect((await api(`/admin/accounts/${owner.user.id}/restore`, root.accessToken, { reason, version: 1 })).status).toBe(201);
    expect((await harness!.prisma.authSession.findUniqueOrThrow({ where: { id: dormant.id } })).revokedAt).not.toBeNull();
    for (const previous of [owner, worker]) {
      expect((await api('/auth/me', previous.accessToken)).status).toBe(401);
      expect((await api('/auth/refresh', undefined, { refreshToken: previous.refreshToken })).status).toBe(401);
    }
    expect((await api('/auth/me', (await login(harness!.baseUrl, owner.email)).accessToken)).status).toBe(200);
    expect((await api('/auth/me', (await login(harness!.baseUrl, worker.user.email)).accessToken)).status).toBe(200);
    const audit = await harness!.prisma.auditLog.findFirstOrThrow({ where: { resourceId: owner.user.id, action: 'admin.account_restore' } });
    expect(audit.metadata).toMatchObject({ before: { isActive: false, version: 1 }, after: { isActive: true, version: 2 } });
  });

  it('counts only newly revoked session rows, including expired rows, and audits each version', async () => {
    const root = await operator(), owner = await registerLandlord(harness!.baseUrl);
    await login(harness!.baseUrl, owner.email);
    await harness!.prisma.authSession.createMany({ data: [
      { userId: owner.user.id, userVersion: 0, expiresAt: new Date(0) },
      { userId: owner.user.id, userVersion: 0, expiresAt: new Date(0), revokedAt: new Date(0) },
    ] });
    expect((await api(`/admin/accounts/${owner.user.id}/revoke-sessions`, root.accessToken, { reason })).json.data)
      .toEqual({ revoked: true, revokedSessions: 3 });
    const audit = await harness!.prisma.auditLog.findFirstOrThrow({ where: { resourceId: owner.user.id, action: 'admin.account_revoke_sessions' } });
    expect(audit.metadata).toEqual({ before: { version: 0 }, after: { version: 1 }, revokedSessions: 3 });
    expect((await api(`/admin/accounts/${owner.user.id}/revoke-sessions`, root.accessToken, { reason })).json.data)
      .toEqual({ revoked: true, revokedSessions: 0 });
    expect((await api('/auth/me', owner.accessToken)).status).toBe(401);
    expect((await api('/auth/refresh', undefined, { refreshToken: owner.refreshToken })).status).toBe(401);
  });

  it('rolls back status, dependent sessions and tokens, and fails closed on PII when audit insertion fails', async () => {
    const root = await operator(), owner = await registerLandlord(harness!.baseUrl), worker = await staff(owner.user.id);
    await harness!.prisma.$executeRawUnsafe(`CREATE FUNCTION account_acceptance_reject_audit() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.action IN ('admin.account_suspend', 'admin.account_revoke_sessions', 'admin.pii_reveal')
      THEN RAISE EXCEPTION 'Simulated account audit failure'; END IF; RETURN NEW; END $$`);
    await harness!.prisma.$executeRawUnsafe(`CREATE TRIGGER account_acceptance_audit_failure BEFORE INSERT ON "AuditLog"
      FOR EACH ROW EXECUTE FUNCTION account_acceptance_reject_audit()`);
    try {
      for (const action of ['suspend', 'revoke-sessions', 'reveal']) {
        const payload = action === 'suspend' ? { reason, version: 0 } : { reason };
        const result = await api(`/admin/accounts/${owner.user.id}/${action}`, root.accessToken, payload);
        expect(result.status).toBe(500);
        expect(result.text).not.toContain(owner.email);
      }
      for (const userId of [owner.user.id, worker.id]) {
        expect((await harness!.prisma.user.findUniqueOrThrow({ where: { id: userId } }))).toMatchObject({ isActive: true, sessionVersion: 0 });
        expect(await harness!.prisma.authSession.count({ where: { userId, revokedAt: null } })).toBe(1);
        expect(await harness!.prisma.refreshToken.count({ where: { userId, revokedAt: null } })).toBe(1);
      }
      expect((await api('/auth/me', owner.accessToken)).status).toBe(200);
      expect((await api('/auth/me', worker.accessToken)).status).toBe(200);
      expect(await harness!.prisma.auditLog.count({ where: { resourceId: owner.user.id, action: { startsWith: 'admin.' } } })).toBe(0);
    } finally {
      await harness!.prisma.$executeRawUnsafe('DROP TRIGGER account_acceptance_audit_failure ON "AuditLog"');
      await harness!.prisma.$executeRawUnsafe('DROP FUNCTION account_acceptance_reject_audit()');
    }
  });

  it('reports missing recovery delivery truthfully and only acknowledges a persisted encrypted queue job', async () => {
    const root = await operator(), owner = await registerLandlord(harness!.baseUrl);
    expect((await api(`/admin/accounts/${owner.user.id}/reset-password`, root.accessToken, { reason })).status).toBe(503);
    expect((await api('/admin/account-invites', root.accessToken, { reason, role: 'LANDLORD', fullName: 'Invited account', email: uniqueEmail('invite') })).status).toBe(503);
    expect(await harness!.prisma.accountAccessToken.count()).toBe(0);
    expect(await harness!.prisma.deliveryJob.count()).toBe(0);
    expect(await harness!.prisma.auditLog.count({ where: { action: { in: ['admin.account_reset_requested', 'admin.account_invite'] } } })).toBe(0);
    const config = harness!.app.get(ConfigService);
    const settings: Record<string, string> = { AUTH_DELIVERY_WEBHOOK_URL: 'https://delivery.example.invalid/events',
      AUTH_PUBLIC_APP_URL: 'https://app.example.invalid', DELIVERY_ENCRYPTION_KEY: Buffer.alloc(32, 9).toString('base64') };
    const original = config.get.bind(config);
    jest.spyOn(config, 'get').mockImplementation((key: string, fallback?: any) => settings[key] ?? original(key, fallback));
    const queued = await api(`/admin/accounts/${owner.user.id}/reset-password`, root.accessToken, { reason });
    expect(queued.status).toBe(201);
    expect(queued.json.data).toEqual({ queued: true });
    const job = await harness!.prisma.deliveryJob.findFirstOrThrow({ include: { token: true } });
    expect(job).toMatchObject({ status: 'PENDING', attempts: 0, token: { userId: owner.user.id, purpose: 'PASSWORD_RESET' } });
    expect(job.payload).not.toContain(owner.email);
    expect(job.payload).not.toContain('https://');
    expect((await api(`/admin/accounts/${owner.user.id}/reset-password`, root.accessToken, { reason })).status).toBe(429);
    expect(await harness!.prisma.deliveryJob.count()).toBe(1);
    expect(await harness!.prisma.auditLog.count({ where: { action: 'admin.account_reset_requested' } })).toBe(1);
  });

  it('preserves MFA, self-change, stale-version and last-super-admin protections on the real database', async () => {
    const root = await operator(), target = await operator();
    const payload = { reason, version: 0, preset: 'support', isActive: false, mfaCode: '654321' };
    expect((await api(`/admin/admins/${target.id}`, root.accessToken, payload, 'PATCH')).status).toBe(401);
    jest.spyOn(harness!.app.get(AdminMfaService), 'verify').mockResolvedValue([]);
    expect((await api(`/admin/admins/${root.id}`, root.accessToken, payload, 'PATCH')).status).toBe(403);
    expect((await api(`/admin/admins/${target.id}`, root.accessToken, { ...payload, version: 1 }, 'PATCH')).status).toBe(409);
    await harness!.prisma.adminProfile.update({ where: { userId: root.id }, data: { preset: 'support' } });
    expect((await api(`/admin/admins/${target.id}`, root.accessToken, payload, 'PATCH')).status).toBe(409);
    expect((await harness!.prisma.user.findUniqueOrThrow({ where: { id: target.id } }))).toMatchObject({ isActive: true, sessionVersion: 0 });
    await harness!.prisma.adminProfile.update({ where: { userId: root.id }, data: { preset: 'super_admin' } });
    expect((await api(`/admin/admins/${target.id}`, root.accessToken, payload, 'PATCH')).status).toBe(200);
    expect((await api('/auth/me', target.accessToken)).status).toBe(401);
    expect(await harness!.prisma.authSession.count({ where: { userId: target.id, revokedAt: null } })).toBe(0);
    const audit = await harness!.prisma.auditLog.findFirstOrThrow({ where: { resourceId: target.id, action: 'admin.profile_update' } });
    expect(audit.metadata).toMatchObject({ before: { preset: 'super_admin', version: 0 }, after: { preset: 'support', version: 1 } });
  });

  it('reads and explicitly grants capabilities with validation, session revocation and no self-escalation', async () => {
    const root = await operator(), target = await operator('support');
    const route = `/admin/admins/${target.id}`;
    const detail = await api(`${route}/access`, root.accessToken);
    expect(detail.status).toBe(200);
    expect(detail.response.headers.get('cache-control')).toBe('private, no-store');
    expect(detail.json.data).toMatchObject({ id: target.id, version: 0, preset: 'support',
      permissions: ADMIN_PRESETS.support, canCustomizePermissions: true });
    expect(detail.text).not.toContain('passwordHash');
    expect(detail.text).not.toContain('mfaSecret');
    expect((await api(`${route}/access`, target.accessToken)).status).toBe(403);

    const permissions = [...ADMIN_PRESETS.support, 'admin.plans.view', 'admin.verifications.view'];
    const payload = { preset: 'support', isActive: true, version: 0, reason, mfaCode: '654321', permissions };
    expect((await api(route, root.accessToken, { ...payload, permissions: null }, 'PATCH')).status).toBe(400);
    expect((await api(route, root.accessToken, payload, 'PATCH')).status).toBe(401);
    jest.spyOn(harness!.app.get(AdminMfaService), 'verify').mockResolvedValue([]);
    expect((await api(`/admin/admins/${root.id}`, root.accessToken, payload, 'PATCH')).status).toBe(403);
    expect((await api(route, root.accessToken, payload, 'PATCH')).status).toBe(200);
    const profile = await harness!.prisma.adminProfile.findUniqueOrThrow({ where: { userId: target.id } });
    expect(profile.permissions).toEqual(permissions);
    expect(profile.accessReviewedAt).toBeNull();
    expect((await api('/auth/me', target.accessToken)).status).toBe(401);
    expect((await api(route, root.accessToken, payload, 'PATCH')).status).toBe(409);
    const audit = await harness!.prisma.auditLog.findFirstOrThrow({ where: { resourceId: target.id, action: 'admin.profile_update' } });
    expect(audit.metadata).toMatchObject({ before: { permissions: ADMIN_PRESETS.support, version: 0 }, after: { permissions, version: 1 } });
  });
});
