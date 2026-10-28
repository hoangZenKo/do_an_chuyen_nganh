import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule, JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { Test } from '@nestjs/testing';
import { AddressInfo } from 'node:net';
import { JwtStrategy } from '../auth/jwt.strategy';
import { AdminMfaService } from '../auth/admin-mfa.service';
import { RolesGuard } from '../common/roles.guard';
import { PrismaService } from '../prisma/prisma.service';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

describe('Admin inventory HTTP read boundaries', () => {
  let app: INestApplication, jwt: JwtService, origin: string;
  let permissions: string[];
  const id = '70f42f45-f8ec-47ad-9567-b4a36c8e032b';
  const inventory = { listProperties: jest.fn(async query => ({ data: [], meta: query })),
    getProperty: jest.fn(async () => ({ data: { id } })), rooms: jest.fn(async query => ({ data: [], meta: query })),
    createProperty: jest.fn(), updateProperty: jest.fn() };
  beforeAll(async () => {
    const module = await Test.createTestingModule({
      imports: [PassportModule, JwtModule.register({ secret: 'inventory-test-only-secret' })],
      controllers: [AdminController], providers: [JwtStrategy, RolesGuard,
        { provide: ConfigService, useValue: { getOrThrow: () => 'inventory-test-only-secret' } },
        { provide: AdminMfaService, useValue: { required: () => false } },
        { provide: AdminService, useValue: inventory },
        { provide: PrismaService, useValue: { user: { findUnique: jest.fn(async ({ where }) => ({ id: where.id,
          email: 'operator@example.test', role: where.id.toUpperCase(), isActive: true, sessionVersion: 0,
          adminProfile: { permissions }, staffProfile: { isActive: true, landlordId: 'owner', permissions: [], propertyScopes: [] } })) } } },
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
  beforeEach(() => { permissions = ['admin.properties.view']; jest.clearAllMocks(); });
  async function request(path: string, actor?: string, method = 'GET') {
    const token = actor ? jwt.sign({ sub: actor, typ: 'access', ver: 0 }) : null;
    const response = await fetch(`${origin}/api/v1/admin${path}`, { method, headers: token ? { authorization: `Bearer ${token}` } : {} });
    return { status: response.status, cache: response.headers.get('cache-control'), body: await response.json() };
  }

  it('allows property viewers without write permission and returns no-store responses', async () => {
    for (const path of ['/properties', `/properties/${id}`, '/rooms']) {
      expect((await request(path)).status).toBe(401);
      expect((await request(path, 'landlord')).status).toBe(403);
      const result = await request(path, 'admin');
      expect(result.status).toBe(200);
      expect(result.cache).toBe('private, no-store');
    }
    expect((await request('/properties', 'admin', 'POST')).status).toBe(403);
    expect((await request(`/properties/${id}`, 'admin', 'PATCH')).status).toBe(403);
    permissions = [];
    expect((await request('/rooms', 'admin')).status).toBe(403);
  });

  it('validates pagination, UUIDs, price filters and enums before dispatch', async () => {
    const result = await request(`/rooms?page=2&limit=10&propertyId=${id}&status=VACANT&activity=active&minPrice=0&maxPrice=4000000&listingStatus=NONE`, 'admin');
    expect(result.status).toBe(200);
    expect(result.body.meta).toMatchObject({ page: 2, limit: 10, propertyId: id, status: 'VACANT', minPrice: 0 });
    for (const query of ['page=0', 'limit=101', 'propertyId=bad', 'status=active', 'activity=deleted',
      'minPrice=-1', 'maxPrice=2147483648', 'minPrice=1.1', 'listingStatus=UNKNOWN', 'unknown=true']) {
      expect((await request(`/rooms?${query}`, 'admin')).status).toBe(400);
    }
    expect((await request('/properties/not-a-uuid', 'admin')).status).toBe(400);
    expect(inventory.rooms).toHaveBeenCalledTimes(1);
  });
});
