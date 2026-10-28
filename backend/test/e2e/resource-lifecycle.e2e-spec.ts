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
} from './e2e-fixtures';

describe('Resource lifecycle E2E', () => {
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

  it('guards lifecycle actions, hides inactive resources and allows unused deletes', async () => {
    const landlordA = await registerLandlord(harness.baseUrl, 'lifecycle-a');
    const landlordB = await registerLandlord(harness.baseUrl, 'lifecycle-b');
    const admin = await createAdmin(harness.prisma, 'lifecycle-admin');
    const adminSession = await login(harness.baseUrl, admin.email);

    const property = await createProperty(
      harness.baseUrl,
      landlordA.accessToken,
      'Lifecycle Property',
    );
    const room = await createRoom(
      harness.baseUrl,
      landlordA.accessToken,
      property.id,
      'Lifecycle Room',
    );
    const tenant = await createTenant(
      harness.baseUrl,
      landlordA.accessToken,
      'Lifecycle Tenant',
    );
    const lease = await createLease(
      harness.baseUrl,
      landlordA.accessToken,
      room.id,
      tenant.id,
    );

    const unauthenticatedArchive = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      { method: 'PATCH', body: { isArchived: true } },
    );
    expect(unauthenticatedArchive.status).toBe(401);

    const adminArchive = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: adminSession.accessToken,
        body: { isArchived: true },
      },
    );
    expect(adminArchive.status).toBe(403);

    const foreignArchive = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordB.accessToken,
        body: { isArchived: true },
      },
    );
    expect(foreignArchive.status).toBe(404);
    expect(foreignArchive.json?.error.code).toBe('PROPERTY_NOT_FOUND');

    const blockedPropertyArchive = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isArchived: true },
      },
    );
    expect(blockedPropertyArchive.status).toBe(409);
    expect(blockedPropertyArchive.json?.error.code).toBe('PROPERTY_HAS_ACTIVE_LEASE');

    const blockedPropertyDelete = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(blockedPropertyDelete.status).toBe(409);
    expect(blockedPropertyDelete.json?.error.code).toBe('PROPERTY_HAS_ACTIVE_LEASE');

    const blockedRoomDeactivate = await requestJson(
      harness.baseUrl,
      `/api/v1/rooms/${room.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: false },
      },
    );
    expect(blockedRoomDeactivate.status).toBe(409);
    expect(blockedRoomDeactivate.json?.error.code).toBe('ROOM_HAS_ACTIVE_LEASE');

    const blockedRoomDelete = await requestJson(
      harness.baseUrl,
      `/api/v1/rooms/${room.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(blockedRoomDelete.status).toBe(409);
    expect(blockedRoomDelete.json?.error.code).toBe('ROOM_HAS_ACTIVE_LEASE');

    const blockedTenantDeactivate = await requestJson(
      harness.baseUrl,
      `/api/v1/tenants/${tenant.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: false },
      },
    );
    expect(blockedTenantDeactivate.status).toBe(409);
    expect(blockedTenantDeactivate.json?.error.code).toBe('TENANT_HAS_ACTIVE_LEASE');

    const blockedTenantDelete = await requestJson(
      harness.baseUrl,
      `/api/v1/tenants/${tenant.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(blockedTenantDelete.status).toBe(409);
    expect(blockedTenantDelete.json?.error.code).toBe('TENANT_HAS_ACTIVE_LEASE');

    const endedLease = await requestJson(
      harness.baseUrl,
      `/api/v1/leases/${lease.id}/end`,
      { method: 'POST', token: landlordA.accessToken },
    );
    expect(endedLease.status).toBe(201);

    const turnovers = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/operations/turnovers?roomId=${room.id}`,
      { token: landlordA.accessToken },
    );
    expect(turnovers.status).toBe(200);
    let turnover = turnovers.json!.data[0];
    for (const stage of ['RETURNED', 'INSPECTION', 'REPAIR', 'CLEANING']) {
      expect(turnover.stage).toBe(stage);
      const advanced = await requestJson<any>(
        harness.baseUrl,
        `/api/v1/operations/turnovers/${turnover.id}/advance`,
        {
          method: 'POST',
          token: landlordA.accessToken,
          body: { stage, version: turnover.version, note: 'Lifecycle room ready' },
        },
      );
      expect(advanced.status).toBe(201);
      turnover = advanced.json!.data;
    }
    expect(turnover.status).toBe('COMPLETED');

    const archivedProperty = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isArchived: true },
      },
    );
    expect(archivedProperty.status).toBe(200);
    expect(archivedProperty.json?.data.isArchived).toBe(true);

    const activeProperties = await requestJson<any>(harness.baseUrl, '/api/v1/properties', {
      token: landlordA.accessToken,
    });
    expect(activeProperties.status).toBe(200);
    expect(activeProperties.json?.data.some((item: any) => item.id === property.id)).toBe(false);

    const archivedProperties = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/properties?lifecycle=archived',
      { token: landlordA.accessToken },
    );
    expect(archivedProperties.status).toBe(200);
    expect(archivedProperties.json?.data.some((item: any) => item.id === property.id)).toBe(true);

    const restoreProperty = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isArchived: false },
      },
    );
    expect(restoreProperty.status).toBe(200);

    const inactiveRoom = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/rooms/${room.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: false },
      },
    );
    expect(inactiveRoom.status).toBe(200);
    expect(inactiveRoom.json?.data.isActive).toBe(false);

    const activeRooms = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/rooms`,
      { token: landlordA.accessToken },
    );
    expect(activeRooms.status).toBe(200);
    expect(activeRooms.json?.data.some((item: any) => item.id === room.id)).toBe(false);

    const inactiveRooms = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/rooms?lifecycle=inactive`,
      { token: landlordA.accessToken },
    );
    expect(inactiveRooms.status).toBe(200);
    expect(inactiveRooms.json?.data.some((item: any) => item.id === room.id)).toBe(true);

    const leaseInactiveRoom = await requestJson(
      harness.baseUrl,
      '/api/v1/leases',
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: {
          roomId: room.id,
          tenantId: tenant.id,
          monthlyRent: 3500000,
        },
      },
    );
    expect(leaseInactiveRoom.status).toBe(409);
    expect(leaseInactiveRoom.json?.error.code).toBe('ROOM_INACTIVE');

    const restoreRoom = await requestJson(
      harness.baseUrl,
      `/api/v1/rooms/${room.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: true },
      },
    );
    expect(restoreRoom.status).toBe(200);

    const inactiveTenant = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenants/${tenant.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: false },
      },
    );
    expect(inactiveTenant.status).toBe(200);
    expect(inactiveTenant.json?.data.isActive).toBe(false);

    const activeTenants = await requestJson<any>(harness.baseUrl, '/api/v1/tenants', {
      token: landlordA.accessToken,
    });
    expect(activeTenants.status).toBe(200);
    expect(activeTenants.json?.data.some((item: any) => item.id === tenant.id)).toBe(false);

    const inactiveTenants = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenants?lifecycle=inactive',
      { token: landlordA.accessToken },
    );
    expect(inactiveTenants.status).toBe(200);
    expect(inactiveTenants.json?.data.some((item: any) => item.id === tenant.id)).toBe(true);

    const leaseInactiveTenant = await requestJson(
      harness.baseUrl,
      '/api/v1/leases',
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: {
          roomId: room.id,
          tenantId: tenant.id,
          monthlyRent: 3500000,
        },
      },
    );
    expect(leaseInactiveTenant.status).toBe(409);
    expect(leaseInactiveTenant.json?.error.code).toBe('TENANT_INACTIVE');

    const restoreTenant = await requestJson(
      harness.baseUrl,
      `/api/v1/tenants/${tenant.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isActive: true },
      },
    );
    expect(restoreTenant.status).toBe(200);

    const rearchiveProperty = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isArchived: true },
      },
    );
    expect(rearchiveProperty.status).toBe(200);

    const leaseArchivedProperty = await requestJson(
      harness.baseUrl,
      '/api/v1/leases',
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: {
          roomId: room.id,
          tenantId: tenant.id,
          monthlyRent: 3500000,
        },
      },
    );
    expect(leaseArchivedProperty.status).toBe(409);
    expect(leaseArchivedProperty.json?.error.code).toBe('PROPERTY_ARCHIVED');

    const finalRestoreProperty = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${property.id}/status`,
      {
        method: 'PATCH',
        token: landlordA.accessToken,
        body: { isArchived: false },
      },
    );
    expect(finalRestoreProperty.status).toBe(200);

    const deleteRoomWithHistory = await requestJson(
      harness.baseUrl,
      `/api/v1/rooms/${room.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(deleteRoomWithHistory.status).toBe(409);
    expect(deleteRoomWithHistory.json?.error.code).toBe('ROOM_HAS_HISTORY');

    const deleteTenantWithHistory = await requestJson(
      harness.baseUrl,
      `/api/v1/tenants/${tenant.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(deleteTenantWithHistory.status).toBe(409);
    expect(deleteTenantWithHistory.json?.error.code).toBe('TENANT_HAS_HISTORY');

    const unusedProperty = await createProperty(
      harness.baseUrl,
      landlordA.accessToken,
      'Unused Property',
    );
    const deleteUnusedProperty = await requestJson(
      harness.baseUrl,
      `/api/v1/properties/${unusedProperty.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(deleteUnusedProperty.status).toBe(204);

    const unusedRoom = await createRoom(
      harness.baseUrl,
      landlordA.accessToken,
      property.id,
      'Unused Room',
    );
    const deleteUnusedRoom = await requestJson(
      harness.baseUrl,
      `/api/v1/rooms/${unusedRoom.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(deleteUnusedRoom.status).toBe(204);

    const unusedTenant = await createTenant(
      harness.baseUrl,
      landlordA.accessToken,
      'Unused Tenant',
    );
    const deleteUnusedTenant = await requestJson(
      harness.baseUrl,
      `/api/v1/tenants/${unusedTenant.id}`,
      { method: 'DELETE', token: landlordA.accessToken },
    );
    expect(deleteUnusedTenant.status).toBe(204);
  });
});
