import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import { AddressInfo } from 'node:net';
import { AdminMfaService } from '../auth/admin-mfa.service';
import { JwtStrategy } from '../auth/jwt.strategy';
import { RolesGuard } from '../common/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AdminOverviewAnalyticsController } from './admin-overview-analytics.controller';
import { AdminOverviewAnalyticsService } from './admin-overview-analytics.service';

describe('overview analytics HTTP authorization and validation', () => {
  let app: INestApplication;
  let origin: string;
  let jwt: JwtService;
  let permissions = ['admin.dashboard.view'];
  let active = true;
  const analytics = { overview: jest.fn(async (_, query) => ({ data: { days: query.days } })) };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [PassportModule, JwtModule.register({ secret: 'overview-test-only-secret' })],
      controllers: [AdminOverviewAnalyticsController],
      providers: [JwtStrategy, RolesGuard,
        { provide: ConfigService, useValue: { getOrThrow: () => 'overview-test-only-secret' } },
        { provide: AdminMfaService, useValue: { required: () => true } },
        { provide: AdminOverviewAnalyticsService, useValue: analytics },
        { provide: PrismaService, useValue: {
          user: { findUnique: jest.fn(async ({ where }) => ({
            id: where.id, email: 'masked@example.test', role: where.id.toUpperCase(),
            isActive: active, sessionVersion: 0,
            adminProfile: { permissions, mfaEnabled: true },
            staffProfile: { isActive: true, landlordId: 'landlord', permissions: [], propertyScopes: [] },
          })) },
          authSession: { findFirst: jest.fn(async () => active ? { id: 'session' } : null) },
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
  beforeEach(() => { permissions = ['admin.dashboard.view']; active = true; jest.clearAllMocks(); });

  async function get(query = '', actor?: string, mfa = true) {
    const token = actor ? jwt.sign({ sub: actor, typ: 'access', ver: 0, sid: 'session', mfa }) : null;
    const response = await fetch(`${origin}/api/v1/admin/analytics/overview${query}`, {
      headers: token ? { authorization: `Bearer ${token}` } : {},
    });
    const body = await response.json();
    return { status: response.status, body, cache: response.headers.get('cache-control') };
  }

  it('requires an authenticated admin with dashboard rights and MFA', async () => {
    expect((await get()).status).toBe(401);
    for (const actor of ['landlord', 'tenant', 'staff']) expect((await get('', actor)).status).toBe(403);
    expect((await get('', 'admin', false)).status).toBe(403);
    permissions = [];
    expect((await get('', 'admin')).status).toBe(403);
    expect(analytics.overview).not.toHaveBeenCalled();
  });

  it('defaults to 30 days and forbids shared caching', async () => {
    const result = await get('', 'admin');
    expect(result).toMatchObject({ status: 200, body: { data: { days: 30 } } });
    expect(result.cache).toBe('private, no-store');
  });

  it('accepts only supported periods and rejects unknown query parameters', async () => {
    for (const days of [7, 30, 90, 180]) {
      expect((await get(`?days=${days}`, 'admin')).body).toEqual({ data: { days } });
    }
    for (const query of ['?days=0', '?days=365', '?days=abc', '?days=7.5', '?days=7&finance=true']) {
      expect((await get(query, 'admin')).status).toBe(400);
    }
    expect(analytics.overview).toHaveBeenCalledTimes(4);
  });

  it('rejects a disabled or expired actor before analytics executes', async () => {
    active = false;
    expect((await get('', 'admin')).status).toBe(401);
    expect(analytics.overview).not.toHaveBeenCalled();
  });
});
