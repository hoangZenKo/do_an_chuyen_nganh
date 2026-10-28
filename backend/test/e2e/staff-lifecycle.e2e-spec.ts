import { randomUUID } from 'node:crypto';
import { AuthService } from '../../src/auth/auth.service';
import { BillingOutboxService } from '../../src/billing/billing-outbox.service';
import { BillingRemindersService } from '../../src/billing/billing-reminders.service';
import { businessDay } from '../../src/billing/billing-rules';
import { STAFF_PERMISSIONS } from '../../src/common/permissions.constants';
import { businessMonth } from '../../src/rooms/service-tariff';
import { E2eHarness, closeE2eHarness, createE2eHarness, requestJson } from './e2e-app';
import { createLease, createProperty, createRoom, createTenant, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Staff property scope and tenant lifecycle (disposable database)', () => {
  let harness: E2eHarness;
  let ownerId: string, ownerToken: string, staffId: string, staffToken: string, tenantToken: string;
  let propertyId: string, otherPropertyId: string, roomId: string, otherRoomId: string, tenantId: string, otherTenantId: string, leaseId: string, otherLeaseId: string;
  const call = (path: string, token = ownerToken, method = 'GET', body?: unknown) => requestJson(harness.baseUrl, `/api/v1/${path}`, { token, method, body });

  beforeAll(async () => {
    if (process.env.NODE_ENV !== 'test' || !/^rental_billing_test_\d+_[a-f0-9]+$/.test(new URL(process.env.DATABASE_URL!).pathname.slice(1))) throw new Error('Use the disposable billing production runner.');
  });
  afterEach(async () => { if (harness) await closeE2eHarness(harness); });
  beforeEach(async () => {
    harness = await createE2eHarness();
    await resetDatabase(harness.prisma);
    const owner = await registerLandlord(harness.baseUrl, 'scope-lifecycle-owner');
    ownerToken = owner.accessToken; ownerId = owner.user.id;
    propertyId = (await createProperty(harness.baseUrl, ownerToken)).id;
    otherPropertyId = (await createProperty(harness.baseUrl, ownerToken, 'Unassigned property')).id;
    roomId = (await createRoom(harness.baseUrl, ownerToken, propertyId)).id;
    otherRoomId = (await createRoom(harness.baseUrl, ownerToken, otherPropertyId)).id;
    tenantId = (await createTenant(harness.baseUrl, ownerToken)).id;
    otherTenantId = (await createTenant(harness.baseUrl, ownerToken, 'Unassigned tenant')).id;
    leaseId = (await createLease(harness.baseUrl, ownerToken, roomId, tenantId)).id;
    otherLeaseId = (await createLease(harness.baseUrl, ownerToken, otherRoomId, otherTenantId)).id;
    const worker = await harness.prisma.user.create({ data: { fullName: 'Scoped staff', email: `${randomUUID()}@example.test`, passwordHash: 'not-for-login', role: 'STAFF' } });
    const staff = await harness.prisma.staffProfile.create({ data: { userId: worker.id, landlordId: ownerId, fullName: worker.fullName, permissions: [...STAFF_PERMISSIONS], propertyScopes: { create: { propertyId, landlordId: ownerId } } } });
    staffId = staff.id;
    staffToken = (await harness.app.get(AuthService).issueSession(worker)).data.accessToken;
    const user = await harness.prisma.user.create({ data: { fullName: 'Portal tenant', email: `${randomUUID()}@example.test`, passwordHash: 'not-for-login', role: 'TENANT' } });
    await harness.prisma.tenant.update({ where: { id: tenantId }, data: { userId: user.id } });
    tenantToken = (await harness.app.get(AuthService).issueSession(user)).data.accessToken;
  });

  it('isolates collections and direct IDs across property, room, tenant, invoice, maintenance, reports and dashboard', async () => {
    const invoices = [];
    for (const current of [leaseId, otherLeaseId]) {
      const response = await call('billing/invoices', ownerToken, 'POST', { leaseId: current, billingMonth: businessMonth().toISOString() });
      expect(response.status).toBe(201); invoices.push(response.json!.data);
    }
    for (const [property, room] of [[propertyId, roomId], [otherPropertyId, otherRoomId]]) expect((await call('maintenance', ownerToken, 'POST', { propertyId: property, roomId: room, title: 'Scoped maintenance' })).status).toBe(201);
    expect((await call('properties', staffToken)).json!.data.map((item: any) => item.id)).toEqual([propertyId]);
    expect((await call(`properties/${otherPropertyId}`, staffToken)).status).toBe(404);
    expect((await call(`rooms/${otherRoomId}`, staffToken)).status).toBe(404);
    expect((await call(`tenants/${otherTenantId}/overview`, staffToken)).status).toBe(404);
    expect((await call('tenants', staffToken)).json!.data.map((item: any) => item.id)).toEqual([tenantId]);
    expect((await call('billing/invoices', staffToken)).json!.data.map((item: any) => item.id)).toEqual([invoices[0].id]);
    expect((await call(`billing/invoices/${invoices[1].id}`, staffToken)).status).toBe(404);
    expect((await call('billing/invoices', staffToken, 'POST', { leaseId: otherLeaseId, billingMonth: '2026-11-01' })).status).toBe(404);
    expect((await call('maintenance', staffToken)).json!.data.map((item: any) => item.propertyId)).toEqual([propertyId]);
    expect((await call(`reports/monthly?propertyId=${otherPropertyId}`, staffToken)).status).toBe(404);
    expect((await call(`dashboard/metrics?propertyId=${otherPropertyId}`, staffToken)).status).toBe(404);
    expect((await call('billing/reminder-policy', staffToken, 'PUT', { requestKey: randomUUID(), expectedVersion: 0, enabled: false, beforeDays: [], onDueDate: false, overdueDays: [], channels: [] })).status).toBe(403);
    expect((await call('operations/options', staffToken)).status).toBe(403);
  });

  it('requires an explicit authorized property when staff browse tariff history', async () => {
    expect((await call('billing/tariffs', staffToken)).status).toBe(400);
    expect((await call(`billing/tariffs?propertyId=${otherPropertyId}`, staffToken)).status).toBe(404);
    expect((await call(`billing/tariffs?propertyId=${propertyId}`, staffToken)).status).toBe(200);
  });

  it('requires staff to propose tariffs rather than activating legacy room fees directly', async () => {
    const base = `rooms/${roomId}/service-fees`;
    const fee = await call(base, ownerToken, 'POST', { name: 'Internet', amount: 100000, effectiveFrom: businessMonth().toISOString() });
    expect(fee.status).toBe(201);
    expect((await call(base, staffToken, 'POST', { name: 'Other', amount: 1 })).status).toBe(403);
    expect((await call(`${base}/${fee.json!.data.id}`, staffToken, 'PATCH', { amount: 1 })).status).toBe(403);
    expect((await call(`${base}/${fee.json!.data.id}`, staffToken, 'DELETE')).status).toBe(403);
    const proposal = await call('billing/tariffs/proposals', staffToken, 'POST', {
      requestKey: randomUUID(), propertyId, roomId, kind: 'SERVICE', serviceKey: 'internet', name: 'Internet',
      unit: 'thang', amount: 120000, tiers: [], isActive: true, reason: 'Proposed increase', effectiveFrom: businessMonth().toISOString(),
    });
    expect(proposal.status).toBe(201);
    expect(proposal.json!.data.state).toBe('PROPOSED');
    expect((await call(`billing/tariffs/${proposal.json!.data.id}/review`, staffToken, 'POST', {
      requestKey: randomUUID(), decision: 'APPROVED', reason: 'Cannot self activate',
    })).status).toBe(403);
  });

  it('revokes scopes on existing tokens, records scope audit atomically and cannot self-escalate', async () => {
    expect((await call(`staff/${staffId}`, staffToken, 'PATCH', { propertyIds: [otherPropertyId] })).status).toBe(403);
    const simulated = await call(`staff/${staffId}/simulate`, ownerToken, 'POST', { propertyId: otherPropertyId, permission: 'billing.view' });
    expect(simulated.json!.data).toMatchObject({ allowed: false, reasons: ['PROPERTY_NOT_ASSIGNED'] });
    const revoked = await call(`staff/${staffId}`, ownerToken, 'PATCH', { propertyIds: [] });
    expect(revoked.status).toBe(200);
    expect(revoked.json!.data.propertyIds).toEqual([]);
    expect((await call('properties', staffToken)).json!.data).toEqual([]);
    expect((await call(`rooms/${roomId}`, staffToken)).status).toBe(404);
    expect(await harness.prisma.auditLog.count({ where: { action: 'staff.property_scope.update', resourceId: staffId } })).toBe(1);
    const stranger = await registerLandlord(harness.baseUrl, 'scope-stranger');
    const foreignProperty = await createProperty(harness.baseUrl, stranger.accessToken);
    expect((await call(`staff/${staffId}`, ownerToken, 'PATCH', { propertyIds: [foreignProperty.id] })).status).toBe(404);
  });

  it('does not expose shared tenant financial history or receipts outside the assigned scope', async () => {
    const extraRoom = await createRoom(harness.baseUrl, ownerToken, otherPropertyId, 'Old shared tenant room');
    await createLease(harness.baseUrl, ownerToken, extraRoom.id, tenantId);
    expect((await call(`tenants/${tenantId}/overview`, staffToken)).status).toBe(404);
    expect((await call(`tenants/${tenantId}/leases`, staffToken)).status).toBe(404);
    const receipt = await call('billing/receipts', ownerToken, 'POST', { requestKey: randomUUID(), tenantId, amount: 100000, method: 'CASH', reference: 'Unallocated shared tenant credit', allocations: [] });
    expect(receipt.status).toBe(201);
    expect((await call('billing/receipts', staffToken)).json!.data).toEqual([]);
    expect((await call(`billing/receipts/${receipt.json!.data.id}/refund`, staffToken, 'POST', { requestKey: randomUUID(), amount: 1, reason: 'No authorization', reference: 'R-1' })).status).toBe(404);
  });

  it('creates and reviews tenant requests without silently modifying leases or settlement balances', async () => {
    const input = { type: 'RENEWAL', leaseId, requestedEnd: '2028-12-31', note: 'Please extend the lease' };
    const attempts = await Promise.all([1, 2].map(() => call('tenant/lifecycle-requests', tenantToken, 'POST', input)));
    expect(attempts.map((result) => result.status).sort()).toEqual([201, 409]);
    const request = attempts.find((result) => result.status === 201)!.json!.data;
    expect((await call('tenant/lifecycle-requests', tenantToken, 'POST', { ...input, leaseId: otherLeaseId })).status).toBe(404);
    const before = await harness.prisma.lease.findUniqueOrThrow({ where: { id: leaseId } });
    expect((await call(`tenant-lifecycle/requests/${request.id}/review`, ownerToken, 'POST', { status: 'APPROVED', reason: '  ' })).status).toBe(400);
    const approved = await call(`tenant-lifecycle/requests/${request.id}/review`, ownerToken, 'POST', { status: 'APPROVED', reason: 'Proceed to lease renewal' });
    expect(approved.status).toBe(201);
    expect(approved.json).toMatchObject({ requiresLeaseAction: true, data: { status: 'APPROVED', reviewedById: ownerId } });
    expect((await harness.prisma.lease.findUniqueOrThrow({ where: { id: leaseId } })).endDate).toEqual(before.endDate);
    expect((await call(`tenant/lifecycle-requests/${request.id}/cancel`, tenantToken, 'POST')).status).toBe(409);
    expect(await harness.prisma.auditLog.count({ where: { resourceId: request.id } })).toBe(2);
  });

  it('validates target rooms, supports cancellation and scopes lifecycle review to the staff property', async () => {
    const available = await createRoom(harness.baseUrl, ownerToken, otherPropertyId, 'Transfer target');
    const transferred = await call('tenant/lifecycle-requests', tenantToken, 'POST', { type: 'TRANSFER_ROOM', leaseId, requestedRoomId: available.id, requestedStart: '2027-01-01', note: 'Move to larger room' });
    expect(transferred.status).toBe(201);
    expect((await call(`tenant-lifecycle/requests/${transferred.json!.data.id}/review`, staffToken, 'POST', { status: 'APPROVED', reason: 'Not authorized for target' })).status).toBe(409);
    expect((await call('tenant-lifecycle/requests', staffToken)).json!.data).toEqual([]);
    expect((await call(`tenant/lifecycle-requests/${transferred.json!.data.id}/cancel`, tenantToken, 'POST')).json!.data.status).toBe('CANCELLED');
    expect((await call('tenant/lifecycle-requests', tenantToken, 'POST', { type: 'CHECKOUT', leaseId, requestedStart: '2027-01-01', note: 'Return room' })).status).toBe(201);
  });

  it('enforces co-occupant room capacity under concurrency and never returns identity numbers', async () => {
    await harness.prisma.room.update({ where: { id: roomId }, data: { capacity: 2 } });
    const path = `tenant-lifecycle/leases/${leaseId}/occupants`;
    const results = await Promise.all([1, 2].map((number) => call(path, ownerToken, 'POST', { fullName: `Occupant ${number}`, idNumber: 'private-identity' })));
    expect(results.map((result) => result.status).sort()).toEqual([201, 409]);
    const created = results.find((result) => result.status === 201)!.json!.data;
    expect(created.idNumber).toBeUndefined();
    const visible = await call(`tenant/occupants?leaseId=${leaseId}`, tenantToken);
    expect(visible.json!.data).toHaveLength(1);
    expect(visible.text).not.toContain('private-identity');
    expect((await call(`tenant-lifecycle/leases/${otherLeaseId}/occupants`, staffToken, 'POST', { fullName: 'Not allowed' })).status).toBe(404);
    expect((await call(`${path}/${created.id}`, ownerToken, 'DELETE')).status).toBe(200);
    expect(await harness.prisma.auditLog.count({ where: { resourceType: 'tenant_occupant' } })).toBe(2);
  });

  it('checks tenant channel opt-out both before enqueue and again immediately before delivery', async () => {
    expect((await call('tenant/notification-preferences', tenantToken)).json!.data).toMatchObject({ enabled: true, channels: ['APP'] });
    const dueDate = businessDay(new Date());
    expect((await call('billing/invoices', ownerToken, 'POST', { leaseId, billingMonth: businessMonth().toISOString(), dueDate })).status).toBe(201);
    expect((await call('billing/reminder-policy', ownerToken, 'PUT', { requestKey: randomUUID(), expectedVersion: 0, enabled: true, beforeDays: [], onDueDate: true, overdueDays: [1], channels: ['APP', 'EMAIL', 'ZALO'] })).status).toBe(200);
    const reminders = harness.app.get(BillingRemindersService);
    await reminders.enqueue(new Date(), ownerId);
    expect(await harness.prisma.billingOutboxEvent.count({ where: { type: 'invoice.reminder' } })).toBe(1);
    expect((await call('tenant/notification-preferences', tenantToken, 'PUT', { enabled: false, channels: [] })).status).toBe(200);
    const job = await harness.prisma.billingOutboxEvent.findFirstOrThrow({ where: { type: 'invoice.reminder' } });
    await harness.app.get(BillingOutboxService).deliver(job.id);
    expect((await harness.prisma.billingOutboxEvent.findUniqueOrThrow({ where: { id: job.id } })).lastError).toBe('TENANT_CHANNEL_DISABLED');
    expect(await harness.prisma.billingNotification.count()).toBe(0);
    expect((await call('tenant/notification-preferences', tenantToken, 'PUT', { enabled: true, channels: [] })).status).toBe(400);
    expect((await call('tenant/notification-preferences', tenantToken, 'PUT', { enabled: true, channels: ['SMS'] })).status).toBe(400);
    await reminders.enqueue(new Date(), ownerId);
    expect(await harness.prisma.billingOutboxEvent.count({ where: { type: 'invoice.reminder' } })).toBe(1);
  });
});
