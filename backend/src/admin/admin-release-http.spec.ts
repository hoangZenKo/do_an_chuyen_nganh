import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import { createHash } from 'node:crypto';
import { AddressInfo } from 'node:net';
import { AdminMfaService } from '../auth/admin-mfa.service';
import { AdminStepUpService } from '../auth/admin-step-up.service';
import { adminRequestFingerprint } from '../auth/admin-step-up.policy';
import { JwtStrategy } from '../auth/jwt.strategy';
import { RolesGuard } from '../common/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AdminLifecycleController } from './admin-lifecycle.controller';
import { AdminLifecycleService } from './admin-lifecycle.service';

describe('Admin lifecycle HTTP release gate (mock persistence, no database/reset)', () => {
  let app: INestApplication;
  let origin: string;
  let jwt: JwtService;
  const targetId = '70f42f45-f8ec-47ad-9567-b4a36c8e032b';
  const path = `/api/v1/admin/admins/${targetId}/revoke-sessions`;
  const reason = 'Security release verification with evidence';
  const permissions = ['admin.admins.manage', 'admin.sessions.revoke'];
  const admin = { id: 'admin', role: 'ADMIN', email: 'masked@example.test', isActive: true, sessionVersion: 0, adminProfile: { permissions: [...permissions], mfaEnabled: true } };
  let sessionActive = true;
  let consumed = false;
  const grant = 'A'.repeat(43);
  const lifecycle = { detail: jest.fn().mockResolvedValue({ data: { id: targetId } }), revoke: jest.fn().mockResolvedValue({ data: { revoked: true } }), resend: jest.fn() };

  beforeAll(async () => {
    const config = { getOrThrow: () => 'test-only-http-secret', get: (key: string) => ({ NODE_ENV: 'test', ADMIN_STEP_UP_REQUIRED: 'true' }[key]) };
    const prisma = {
      user: { findUnique: jest.fn(async ({ where }: { where: { id: string } }) => where.id === admin.id ? admin : {
        id: where.id, email: 'masked@example.test', role: where.id.toUpperCase(), isActive: true, sessionVersion: 0,
        staffProfile: { isActive: true, landlordId: 'landlord', permissions: [], propertyScopes: [] },
      }) },
      authSession: { findFirst: jest.fn(async ({ where }: { where: { userVersion: number } }) => sessionActive && where.userVersion === 0 ? { id: 'session' } : null) },
      adminStepUpGrant: { updateMany: jest.fn(async ({ where }: { where: { tokenHash: string; fingerprint: string } }) => {
        if (consumed || where.tokenHash !== createHash('sha256').update(grant).digest('hex') || where.fingerprint !== adminRequestFingerprint('POST', path, { version: 0, reason })) return { count: 0 };
        consumed = true;
        return { count: 1 };
      }) },
    };
    const module = await Test.createTestingModule({ imports: [PassportModule, JwtModule.register({ secret: 'test-only-http-secret' })], controllers: [AdminLifecycleController],
      providers: [JwtStrategy, RolesGuard, AdminStepUpService, { provide: ConfigService, useValue: config }, { provide: PrismaService, useValue: prisma },
        { provide: AdminMfaService, useValue: { required: () => true } }, { provide: AdminLifecycleService, useValue: lifecycle }] }).compile();
    app = module.createNestApplication({ logger: false });
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    await app.listen(0, '127.0.0.1');
    origin = `http://127.0.0.1:${(app.getHttpServer().address() as AddressInfo).port}`;
    jwt = app.get(JwtService);
  });
  afterAll(async () => { await app?.close(); });
  beforeEach(() => { admin.adminProfile.permissions = [...permissions]; admin.sessionVersion = 0; sessionActive = true; consumed = false; jest.clearAllMocks(); });

  async function request(resource: string, actor?: string, body?: object, stepUp?: string) {
    const token = actor ? jwt.sign({ sub: actor, typ: 'access', ver: 0, sid: 'session', mfa: true }) : null;
    const response = await fetch(`${origin}${resource}`, { method: body ? 'POST' : 'GET', headers: { ...(token ? { authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'content-type': 'application/json' } : {}), ...(stepUp ? { 'x-admin-step-up': stepUp } : {}) }, body: body ? JSON.stringify(body) : undefined });
    await response.body?.cancel();
    return response;
  }

  it('rejects anonymous, staff, landlord and tenant HTTP calls, not just hidden menus', async () => {
    const resource = `/api/v1/admin/admins/${targetId}/lifecycle`;
    expect((await request(resource)).status).toBe(401);
    for (const actor of ['staff', 'landlord', 'tenant']) expect((await request(resource, actor)).status).toBe(403);
    const response = await request(resource, 'admin');
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toContain('no-store');
  });

  it('loads permissions at the next request and rejects revoked sessions or changed userVersion', async () => {
    const resource = `/api/v1/admin/admins/${targetId}/lifecycle`;
    expect((await request(resource, 'admin')).status).toBe(200);
    admin.adminProfile.permissions = [];
    expect((await request(resource, 'admin')).status).toBe(403);
    admin.adminProfile.permissions = [...permissions];
    sessionActive = false;
    expect((await request(resource, 'admin')).status).toBe(401);
    sessionActive = true;
    admin.sessionVersion++;
    expect((await request(resource, 'admin')).status).toBe(401);
  });

  it('requires fresh single-use step-up with an exact payload and both revoke capabilities', async () => {
    const body = { version: 0, reason };
    expect((await request(path, 'admin', body)).status).toBe(403);
    admin.adminProfile.permissions = ['admin.admins.manage'];
    expect((await request(path, 'admin', body, grant)).status).toBe(403);
    admin.adminProfile.permissions = [...permissions];
    expect((await request(path, 'admin', { ...body, version: 1 }, grant)).status).toBe(403);
    expect((await request(path, 'admin', body, grant)).status).toBe(201);
    expect((await request(path, 'admin', body, grant)).status).toBe(403);
    expect(lifecycle.revoke).toHaveBeenCalledTimes(1);
  });
});
