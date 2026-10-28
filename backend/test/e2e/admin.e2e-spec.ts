import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import {
  createAdmin,
  createLease,
  createProperty,
  createRoom,
  createTenant,
  login,
  registerLandlord,
  resetDatabase,
  testPassword,
} from './e2e-fixtures';

describe('Admin E2E', () => {
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

  it('guards admin endpoints and keeps landlord endpoints landlord-only', async () => {
    const landlord = await registerLandlord(harness.baseUrl, 'admin-guard-landlord');
    const admin = await createAdmin(harness.prisma, 'admin-guard-admin');
    const adminSession = await login(harness.baseUrl, admin.email);

    const noToken = await requestJson(harness.baseUrl, '/api/v1/admin/overview');
    expect(noToken.status).toBe(401);

    const landlordAdminRequest = await requestJson(harness.baseUrl, '/api/v1/admin/overview', {
      token: landlord.accessToken,
    });
    expect(landlordAdminRequest.status).toBe(403);

    const adminLandlordResourceRequest = await requestJson(harness.baseUrl, '/api/v1/properties', {
      token: adminSession.accessToken,
    });
    expect(adminLandlordResourceRequest.status).toBe(403);
  });

  it('manages landlords and platform properties', async () => {
    const admin = await createAdmin(harness.prisma, 'admin-flow-admin');
    const adminSession = await login(harness.baseUrl, admin.email);
    const landlord = await registerLandlord(harness.baseUrl, 'admin-flow-landlord');
    const existingProperty = await createProperty(
      harness.baseUrl,
      landlord.accessToken,
      'Existing Admin Flow Property',
    );
    const room = await createRoom(harness.baseUrl, landlord.accessToken, existingProperty.id, 'A.101');
    const tenant = await createTenant(harness.baseUrl, landlord.accessToken, 'Admin Flow Tenant');
    await createLease(harness.baseUrl, landlord.accessToken, room.id, tenant.id);

    const overview = await requestJson<any>(harness.baseUrl, '/api/v1/admin/overview', {
      token: adminSession.accessToken,
    });
    expect(overview.status).toBe(200);
    expect(overview.json?.data.landlords.total).toBe(1);
    expect(overview.json?.data.properties.total).toBe(1);
    expect(overview.json?.data.leases.active).toBe(1);

    const createLandlord = await requestJson<any>(harness.baseUrl, '/api/v1/admin/landlords', {
      method: 'POST',
      token: adminSession.accessToken,
      body: {
        fullName: 'Admin Created Landlord',
        email: 'admin-created-landlord@example.com',
        phone: '+84901110000',
        password: testPassword,
      },
    });
    expect(createLandlord.status).toBe(201);
    expect(createLandlord.json?.data.role).toBe('landlord');
    expect(createLandlord.json?.data.isActive).toBe(true);

    const duplicateLandlord = await requestJson<any>(harness.baseUrl, '/api/v1/admin/landlords', {
      method: 'POST',
      token: adminSession.accessToken,
      body: {
        fullName: 'Duplicate Landlord',
        email: 'admin-created-landlord@example.com',
        phone: '+84901110001',
        password: testPassword,
      },
    });
    expect(duplicateLandlord.status).toBe(409);
    expect(duplicateLandlord.json?.error.code).toBe('LANDLORD_EMAIL_ALREADY_REGISTERED');

    const landlords = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/admin/landlords?search=Admin%20Created&status=active',
      { token: adminSession.accessToken },
    );
    expect(landlords.status).toBe(200);
    expect(landlords.json?.data).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ email: 'a***@example.com' }),
      ]),
    );

    const createdLandlordId = createLandlord.json!.data.id as string;
    const landlordDetail = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/landlords/${createdLandlordId}`,
      { token: adminSession.accessToken },
    );
    expect(landlordDetail.status).toBe(200);
    expect(landlordDetail.json?.data.propertyCount).toBe(0);

    const updatedLandlord = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/landlords/${createdLandlordId}`,
      {
        method: 'PATCH',
        token: adminSession.accessToken,
        body: { fullName: 'Updated Admin Landlord', phone: '+84902220000' },
      },
    );
    expect(updatedLandlord.status).toBe(200);
    expect(updatedLandlord.json?.data.fullName).toBe('Updated Admin Landlord');

    const deactivate = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/landlords/${landlord.user.id}/status`,
      {
        method: 'PATCH',
        token: adminSession.accessToken,
        body: { isActive: false },
      },
    );
    expect(deactivate.status).toBe(200);
    expect(deactivate.json?.data.isActive).toBe(false);

    const inactiveLandlordRequest = await requestJson(harness.baseUrl, '/api/v1/properties', {
      token: landlord.accessToken,
    });
    expect(inactiveLandlordRequest.status).toBe(401);

    const reactivate = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/landlords/${landlord.user.id}/status`,
      {
        method: 'PATCH',
        token: adminSession.accessToken,
        body: { isActive: true },
      },
    );
    expect(reactivate.status).toBe(200);
    expect(reactivate.json?.data.isActive).toBe(true);

    const createPropertyAsAdmin = await requestJson<any>(harness.baseUrl, '/api/v1/admin/properties', {
      method: 'POST',
      token: adminSession.accessToken,
      body: {
        landlordId: createdLandlordId,
        name: 'Admin Created Property',
        address: '456 Admin Street',
      },
    });
    expect(createPropertyAsAdmin.status).toBe(201);
    expect(createPropertyAsAdmin.json?.data.landlord.id).toBe(createdLandlordId);

    const createdPropertyId = createPropertyAsAdmin.json!.data.id as string;
    const properties = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/properties?landlordId=${createdLandlordId}`,
      { token: adminSession.accessToken },
    );
    expect(properties.status).toBe(200);
    expect(properties.json?.data).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: createdPropertyId, name: 'Admin Created Property' }),
      ]),
    );

    const propertyDetail = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/properties/${existingProperty.id}`,
      { token: adminSession.accessToken },
    );
    expect(propertyDetail.status).toBe(200);
    expect(propertyDetail.json?.data.rooms).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ id: room.id, name: 'A.101', status: 'occupied' }),
      ]),
    );

    const updateProperty = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/admin/properties/${createdPropertyId}`,
      {
        method: 'PATCH',
        token: adminSession.accessToken,
        body: { name: 'Updated Admin Property', address: '789 Admin Street' },
      },
    );
    expect(updateProperty.status).toBe(200);
    expect(updateProperty.json?.data.name).toBe('Updated Admin Property');
  });
});
