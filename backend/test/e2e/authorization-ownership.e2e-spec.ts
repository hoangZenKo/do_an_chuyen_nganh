import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import {
  createAdmin,
  createProperty,
  createRoom,
  createTenant,
  login,
  registerLandlord,
  resetDatabase,
} from './e2e-fixtures';

describe('Authorization and ownership E2E', () => {
  let harness: E2eHarness;

  beforeAll(async () => {
    harness = await createE2eHarness();
  });

  afterAll(async () => {
    await closeE2eHarness(harness);
  });

  beforeEach(async () => {
    await resetDatabase(harness.prisma);
  });

  it('protects landlord resources and keeps cross-owner resources hidden', async () => {
    const landlordA = await registerLandlord(harness.baseUrl, 'owner-a');
    const landlordB = await registerLandlord(harness.baseUrl, 'owner-b');
    const admin = await createAdmin(harness.prisma, 'owner-admin');

    const propertyA = await createProperty(harness.baseUrl, landlordA.accessToken, 'Khu A');
    const roomA = await createRoom(harness.baseUrl, landlordA.accessToken, propertyA.id, 'P.101');
    const tenantA = await createTenant(harness.baseUrl, landlordA.accessToken, 'Tenant A');

    const noToken = await requestJson(harness.baseUrl, '/api/v1/properties');
    expect(noToken.status).toBe(401);

    const adminSession = await login(harness.baseUrl, admin.email);
    const adminMetrics = await requestJson(harness.baseUrl, '/api/v1/dashboard/metrics', {
      token: adminSession.accessToken,
    });
    expect(adminMetrics.status).toBe(403);

    const landlordList = await requestJson<any>(harness.baseUrl, '/api/v1/properties', {
      token: landlordA.accessToken,
    });
    expect(landlordList.status).toBe(200);
    expect(landlordList.json?.data).toHaveLength(1);

    const propertyById = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${propertyA.id}`,
      { token: landlordA.accessToken },
    );
    expect(propertyById.status).toBe(200);
    expect(propertyById.json?.data.id).toBe(propertyA.id);

    const foreignProperty = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${propertyA.id}`,
      { token: landlordB.accessToken },
    );
    expect(foreignProperty.status).toBe(404);
    expect(foreignProperty.json?.error.code).toBe('PROPERTY_NOT_FOUND');

    const foreignRoom = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/rooms/${roomA.id}`,
      { token: landlordB.accessToken },
    );
    expect(foreignRoom.status).toBe(404);
    expect(foreignRoom.json?.error.code).toBe('ROOM_NOT_FOUND');

    const foreignTenant = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenants/${tenantA.id}`,
      { token: landlordB.accessToken },
    );
    expect(foreignTenant.status).toBe(404);
    expect(foreignTenant.json?.error.code).toBe('TENANT_NOT_FOUND');

    const propertyRooms = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${propertyA.id}/rooms`,
      { token: landlordA.accessToken },
    );
    expect(propertyRooms.status).toBe(200);
    expect(propertyRooms.json?.data).toHaveLength(1);

    const createForeignRoom = await requestJson(harness.baseUrl, `/api/v1/properties/${propertyA.id}/rooms`, {
      method: 'POST',
      token: landlordB.accessToken,
      body: {
        name: 'P.202',
        status: 'vacant',
        basePrice: 3000000,
      },
    });
    expect(createForeignRoom.status).toBe(404);

    const createForeignTenant = await requestJson(harness.baseUrl, '/api/v1/tenants', {
      method: 'POST',
      token: landlordB.accessToken,
      body: {
        fullName: 'Tenant B',
        phone: '+84909990000',
      },
    });
    expect(createForeignTenant.status).toBe(201);

    const lease = await requestJson<any>(harness.baseUrl, '/api/v1/leases', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        roomId: roomA.id,
        tenantId: tenantA.id,
        monthlyRent: 3500000,
      },
    });
    expect(lease.status).toBe(201);
    expect(lease.json?.data.status).toBe('active');

    const foreignLease = await requestJson(harness.baseUrl, '/api/v1/leases', {
      method: 'POST',
      token: landlordB.accessToken,
      body: {
        roomId: roomA.id,
        tenantId: tenantA.id,
        monthlyRent: 3500000,
      },
    });
    expect(foreignLease.status).toBe(404);
    expect(foreignLease.json?.error.code).toBe('ROOM_NOT_FOUND');

    const validationError = await requestJson(harness.baseUrl, '/api/v1/properties', {
      method: 'POST',
      token: landlordA.accessToken,
      body: { name: 'Invalid', unknownField: true },
    });
    expect(validationError.status).toBe(400);
  });
});
