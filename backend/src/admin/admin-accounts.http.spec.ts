import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import { createHash } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { AdminMfaService } from '../auth/admin-mfa.service';
import { adminRequestFingerprint } from '../auth/admin-step-up.policy';
import { AdminStepUpService } from '../auth/admin-step-up.service';
import { JwtStrategy } from '../auth/jwt.strategy';
import { RolesGuard } from '../common/roles.guard';
import { OperationsHealthService } from '../health/operations-health.service';
import { PrismaService } from '../prisma/prisma.service';
import { AdminAuditQueryService } from './admin-audit-query.service';
import { AdminConsoleController } from './admin-console.controller';
import { AdminConsoleService } from './admin-console.service';

describe('Admin accounts HTTP contract (mock persistence)', () => {
  let app: INestApplication;
  let origin: string;
  let jwt: JwtService;
  let permissions: string[];
  let active = true;
  let consumed = false;
  const id = '70f42f45-f8ec-47ad-9567-b4a36c8e032b';
  const path = `/api/v1/admin/accounts/${id}/suspend`;
  const payload = { reason: 'Verified support request ACCT-123', version: 7 };
  const grant = 'B'.repeat(43);
  const accounts = { accounts: jest.fn(async query => ({ data: [], meta: query })),
    account: jest.fn(async () => ({ data: { id } })), status: jest.fn(async () => ({ data: { id, isActive: false, version: 8 } })),
    revoke: jest.fn(), reset: jest.fn(), reveal: jest.fn() };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [PassportModule, JwtModule.register({ secret: 'accounts-http-test-secret' })],
      controllers: [AdminConsoleController],
      providers: [JwtStrategy, RolesGuard, AdminStepUpService,
        { provide: ConfigService, useValue: { getOrThrow: () => 'accounts-http-test-secret',
          get: (key: string) => ({ NODE_ENV: 'test', ADMIN_STEP_UP_REQUIRED: 'true' }[key]) } },
        { provide: AdminMfaService, useValue: { required: () => true } },
        { provide: AdminConsoleService, useValue: accounts },
        { provide: AdminAuditQueryService, useValue: {} },
        { provide: OperationsHealthService, useValue: {} },
        { provide: PrismaService, useValue: {
          user: { findUnique: jest.fn(async ({ where }) => ({ id: where.id, email: 'operator@example.test',
            role: where.id.toUpperCase(), isActive: active, sessionVersion: 0,
            adminProfile: { permissions, mfaEnabled: true },
            staffProfile: { isActive: true, landlordId: 'landlord', permissions: [], propertyScopes: [] } })) },
          authSession: { findFirst: jest.fn(async () => active ? { id: 'session' } : null) },
          adminStepUpGrant: { updateMany: jest.fn(async ({ where }) => {
            if (consumed || where.tokenHash !== createHash('sha256').update(grant).digest('hex') ||
              where.fingerprint !== adminRequestFingerprint('POST', path, payload)) return { count: 0 };
            consumed = true;
            return { count: 1 };
          }) },
        } },
      ],
    }).compile();
    app = module.createNestApplication({ logger: false });
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
    await app.listen(0, '127.0.0.1');
    origin = `http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}`;
    jwt = app.get(JwtService);
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => { permissions = ['admin.accounts.view', 'admin.accounts.suspend']; active = true; consumed = false; jest.clearAllMocks(); });

  async function request(resource = '/api/v1/admin/accounts', actor?: string, body?: object, stepUp?: string) {
    const token = actor ? jwt.sign({ sub: actor, typ: 'access', ver: 0, sid: 'session', mfa: true }) : null;
    const response = await fetch(`${origin}${resource}`, { method: body ? 'POST' : 'GET', headers: {
      ...(token ? { authorization: `Bearer ${token}` } : {}), ...(body ? { 'content-type': 'application/json' } : {}),
      ...(stepUp ? { 'x-admin-step-up': stepUp } : {}) }, body: body ? JSON.stringify(body) : undefined });
    return { status: response.status, cache: response.headers.get('cache-control'), body: await response.json() };
  }

  it('fails closed for anonymous, customer roles, revoked capability and session', async () => {
    expect((await request()).status).toBe(401);
    for (const role of ['landlord', 'tenant', 'staff']) expect((await request(undefined, role)).status).toBe(403);
    permissions = [];
    expect((await request(undefined, 'admin')).status).toBe(403);
    active = false;
    expect((await request(undefined, 'admin')).status).toBe(401);
    expect(accounts.accounts).not.toHaveBeenCalled();
  });

  it('transforms bounded query, trims search and disables list/detail caching', async () => {
    const result = await request('/api/v1/admin/accounts?page=2&limit=20&role=TENANT&status=inactive&search=%20Customer%20', 'admin');
    expect(result).toMatchObject({ status: 200, cache: 'private, no-store', body: { meta: {
      page: 2, limit: 20, role: 'TENANT', status: 'inactive', search: 'Customer' } } });
    expect((await request(`/api/v1/admin/accounts/${id}`, 'admin')).cache).toBe('private, no-store');
    for (const query of ['limit=101', 'page=0', 'role=ROOT', 'status=deleted', 'from=invalid', 'unknown=true']) {
      expect((await request(`/api/v1/admin/accounts?${query}`, 'admin')).status).toBe(400);
    }
    expect((await request('/api/v1/admin/accounts/not-a-uuid', 'admin')).status).toBe(400);
    expect(accounts.accounts).toHaveBeenCalledTimes(1);
  });

  it('requires a single-use step-up bound to the exact suspension version/reason', async () => {
    expect((await request(path, 'admin', payload)).status).toBe(403);
    expect((await request(path, 'admin', { ...payload, version: 6 }, grant)).status).toBe(403);
    expect((await request(path, 'admin', payload, grant)).status).toBe(201);
    expect((await request(path, 'admin', payload, grant)).status).toBe(403);
    expect(accounts.status).toHaveBeenCalledTimes(1);
  });

  it('requires action-specific capabilities, not just account read permission', async () => {
    permissions = ['admin.accounts.view'];
    for (const action of ['suspend', 'restore', 'revoke-sessions', 'reveal', 'reset-password']) {
      expect((await request(`/api/v1/admin/accounts/${id}/${action}`, 'admin', payload)).status).toBe(403);
    }
    expect(accounts.status).not.toHaveBeenCalled();
    expect(accounts.revoke).not.toHaveBeenCalled();
    expect(accounts.reveal).not.toHaveBeenCalled();
  });
});
