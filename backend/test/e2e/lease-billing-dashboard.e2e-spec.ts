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

describe('Lease, billing and dashboard E2E', () => {
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

  it('covers lease transitions, billing flows and dashboard scoping', async () => {
    const landlordA = await registerLandlord(harness.baseUrl, 'flow-a');
    const landlordB = await registerLandlord(harness.baseUrl, 'flow-b');
    const admin = await createAdmin(harness.prisma, 'flow-admin');
    const adminSession = await login(harness.baseUrl, admin.email);

    const propertyA = await createProperty(harness.baseUrl, landlordA.accessToken, 'Khu Flow A');
    const roomA = await createRoom(harness.baseUrl, landlordA.accessToken, propertyA.id, 'P.201');
    const tenantA = await createTenant(harness.baseUrl, landlordA.accessToken, 'Tenant Flow A');

    const lease = await createLease(
      harness.baseUrl,
      landlordA.accessToken,
      roomA.id,
      tenantA.id,
      4200000,
    );
    expect(lease.status).toBe('active');

    const roomAfterLease = await requestJson<any>(harness.baseUrl, `/api/v1/rooms/${roomA.id}`, {
      token: landlordA.accessToken,
    });
    expect(roomAfterLease.status).toBe(200);
    expect(roomAfterLease.json?.data.status).toBe('occupied');
    expect(roomAfterLease.json?.data.tenantName).toBe('Tenant Flow A');

    const duplicateLease = await requestJson(harness.baseUrl, '/api/v1/leases', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        roomId: roomA.id,
        tenantId: tenantA.id,
        monthlyRent: 4200000,
      },
    });
    expect(duplicateLease.status).toBe(409);
    expect(duplicateLease.json?.error.code).toBe('ROOM_ALREADY_LEASED');

    const activeLeases = await requestJson<any>(harness.baseUrl, '/api/v1/billing/active-leases', {
      token: landlordA.accessToken,
    });
    expect(activeLeases.status).toBe(200);
    expect(activeLeases.json?.data).toHaveLength(1);

    const meterReading = await requestJson<any>(harness.baseUrl, '/api/v1/billing/meter-readings', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        roomId: roomA.id,
        utilityType: 'electricity',
        billingMonth: '2026-07-15T00:00:00.000Z',
        previousReading: 100,
        currentReading: 140,
        unitPrice: 3500,
      },
    });
    expect(meterReading.status).toBe(201);
    expect(meterReading.json?.data.usage).toBe(40);
    expect(meterReading.json?.data.amount).toBe(140000);

    const invalidReading = await requestJson(harness.baseUrl, '/api/v1/billing/meter-readings', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        roomId: roomA.id,
        utilityType: 'water',
        billingMonth: '2026-08-15T00:00:00.000Z',
        previousReading: 200,
        currentReading: 100,
        unitPrice: 1000,
      },
    });
    expect(invalidReading.status).toBe(400);
    expect(invalidReading.json?.error.code).toBe('INVALID_METER_READING');

    const invoice = await requestJson<any>(harness.baseUrl, '/api/v1/billing/invoices', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        leaseId: lease.id,
        billingMonth: '2026-08-01T00:00:00.000Z',
        otherAmount: 500000,
        meterReadings: [
          {
            utilityType: 'electricity',
            previousReading: 140,
            currentReading: 180,
            unitPrice: 3500,
          },
          {
            utilityType: 'water',
            previousReading: 30,
            currentReading: 40,
            unitPrice: 12000,
          },
        ],
      },
    });
    expect(invoice.status).toBe(201);
    expect(invoice.json?.data.totalAmount).toBeGreaterThan(0);

    const duplicateInvoice = await requestJson(harness.baseUrl, '/api/v1/billing/invoices', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        leaseId: lease.id,
        billingMonth: '2026-08-01T00:00:00.000Z',
      },
    });
    expect(duplicateInvoice.status).toBe(409);
    expect(duplicateInvoice.json?.error.code).toBe('INVOICE_EXISTS');

    const partialPayment = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: {
          amount: 1000000,
          method: 'cash',
        },
      },
    );
    expect(partialPayment.status).toBe(201);
    expect(partialPayment.json?.data.status).toBe('partial');

    const fullPayment = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: {
          amount: invoice.json!.data.totalAmount - 1000000,
          method: 'bank_transfer',
        },
      },
    );
    expect(fullPayment.status).toBe(201);
    expect(fullPayment.json?.data.status).toBe('paid');

    const dashboardA = await requestJson<any>(harness.baseUrl, '/api/v1/dashboard/metrics?months=2', {
      token: landlordA.accessToken,
    });
    expect(dashboardA.status).toBe(200);
    expect(dashboardA.json?.data.leaseStats.active).toBe(1);
    const invoiceMonth = new Date(invoice.json!.data.billingMonth);
    const now = new Date();
    expect(dashboardA.json?.data.currentMonth.invoiceCount).toBe(
      invoiceMonth.getUTCFullYear() === now.getUTCFullYear() && invoiceMonth.getUTCMonth() === now.getUTCMonth() ? 1 : 0,
    );

    const dashboardB = await requestJson<any>(harness.baseUrl, '/api/v1/dashboard/metrics?months=2', {
      token: landlordB.accessToken,
    });
    expect(dashboardB.status).toBe(200);
    expect(dashboardB.json?.data.leaseStats.active).toBe(0);

    const foreignPropertyMetrics = await requestJson(
      harness.baseUrl,
      `/api/v1/dashboard/metrics?propertyId=${propertyA.id}`,
      { token: landlordB.accessToken },
    );
    expect(foreignPropertyMetrics.status).toBe(404);
    expect(foreignPropertyMetrics.json?.error.code).toBe('PROPERTY_NOT_FOUND');

    const reminderRun = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/reminders/run?propertyId=${propertyA.id}&dueSoonDays=14`,
      {
        method: 'POST',
        token: landlordA.accessToken,
      },
    );
    expect(reminderRun.status).toBe(201);
    expect(reminderRun.json?.data.total).toBe(0);
    expect(reminderRun.json?.data.sent).toBe(0);
    expect(reminderRun.json?.data.failed).toBe(0);
    expect(reminderRun.json?.data.skipped).toBe(0);

    const reminderList = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/reminders?propertyId=${propertyA.id}&dueSoonDays=14`,
      {
        token: landlordA.accessToken,
      },
    );
    expect(reminderList.status).toBe(200);
    expect(reminderList.json?.data).toHaveLength(0);

    const adminDashboard = await requestJson(harness.baseUrl, '/api/v1/dashboard/metrics', {
      token: adminSession.accessToken,
    });
    expect(adminDashboard.status).toBe(403);

    const foreignPayment = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordB.accessToken,
        body: { amount: 1000 },
      },
    );
    expect(foreignPayment.status).toBe(404);
    expect(foreignPayment.json?.error.code).toBe('INVOICE_NOT_FOUND');

    const endLease = await requestJson<any>(harness.baseUrl, `/api/v1/leases/${lease.id}/end`, {
      method: 'POST',
      token: landlordA.accessToken,
    });
    expect(endLease.status).toBe(201);
    expect(endLease.json?.data.status).toBe('ended');

    const roomAfterEnd = await requestJson<any>(harness.baseUrl, `/api/v1/rooms/${roomA.id}`, {
      token: landlordA.accessToken,
    });
    expect(roomAfterEnd.status).toBe(200);
    expect(roomAfterEnd.json?.data.status).toBe('maintenance');
    expect(roomAfterEnd.json?.data.tenantName).toBeNull();

    const foreignEnd = await requestJson(
      harness.baseUrl,
      `/api/v1/leases/${lease.id}/end`,
      {
        method: 'POST',
        token: landlordB.accessToken,
      },
    );
    expect(foreignEnd.status).toBe(404);
    expect(foreignEnd.json?.error.code).toBe('LEASE_NOT_FOUND');
  });

  it('guards payment overpayment, reversal and invoice cancellation flows', async () => {
    const landlordA = await registerLandlord(harness.baseUrl, 'billing-a');
    const landlordB = await registerLandlord(harness.baseUrl, 'billing-b');
    const admin = await createAdmin(harness.prisma, 'billing-admin');
    const adminSession = await login(harness.baseUrl, admin.email);

    const property = await createProperty(harness.baseUrl, landlordA.accessToken, 'Khu Billing A');
    const room = await createRoom(harness.baseUrl, landlordA.accessToken, property.id, 'P.301');
    const tenant = await createTenant(harness.baseUrl, landlordA.accessToken, 'Tenant Billing A');
    const lease = await createLease(
      harness.baseUrl,
      landlordA.accessToken,
      room.id,
      tenant.id,
      4_000_000,
    );

    const invoice = await requestJson<any>(harness.baseUrl, '/api/v1/billing/invoices', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        leaseId: lease.id,
        billingMonth: '2026-09-15T00:00:00.000Z',
        otherAmount: 100_000,
        meterReadings: [
          {
            utilityType: 'electricity',
            previousReading: 10,
            currentReading: 20,
            unitPrice: 3000,
          },
          {
            utilityType: 'water',
            previousReading: 5,
            currentReading: 10,
            unitPrice: 12000,
          },
        ],
      },
    });
    expect(invoice.status).toBe(201);
    expect(invoice.json?.data.billingMonth).toBe('2026-09-01T00:00:00.000Z');
    expect(invoice.json?.data.rentAmount).toBe(4_000_000);
    expect(invoice.json?.data.electricityAmount).toBe(30_000);
    expect(invoice.json?.data.waterAmount).toBe(60_000);
    expect(invoice.json?.data.otherAmount).toBe(100_000);
    expect(invoice.json?.data.totalAmount).toBe(4_190_000);
    expect(invoice.json?.data.paidAmount).toBe(0);
    expect(invoice.json?.data.remainingAmount).toBe(4_190_000);

    const overpayment = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { amount: 4_190_001 },
      },
    );
    expect(overpayment.status).toBe(409);
    expect(overpayment.json?.error.code).toBe('PAYMENT_EXCEEDS_REMAINING');
    await expect(
      harness.prisma.payment.count({ where: { invoiceId: invoice.json!.data.id } }),
    ).resolves.toBe(0);

    const partial = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { amount: 1_000_000, method: 'bank_transfer' },
      },
    );
    expect(partial.status).toBe(201);
    expect(partial.json?.data.status).toBe('partial');
    expect(partial.json?.data.paidAmount).toBe(1_000_000);
    expect(partial.json?.data.remainingAmount).toBe(3_190_000);
    const originalPayment = partial.json!.data.payments[0];
    expect(originalPayment.type).toBe('payment');
    expect(originalPayment.reversalOfPaymentId).toBeNull();

    const reversed = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments/${originalPayment.id}/reverse`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { note: 'Nhập sai giao dịch' },
      },
    );
    expect(reversed.status).toBe(201);
    expect(reversed.json?.data.status).toBe('unpaid');
    expect(reversed.json?.data.paidAmount).toBe(0);
    const reversal = reversed.json!.data.payments.find((item: any) => item.type === 'reversal');
    expect(reversal.amount).toBe(-1_000_000);
    expect(reversal.reversalOfPaymentId).toBe(originalPayment.id);

    const reverseAgain = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments/${originalPayment.id}/reverse`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { note: 'Reverse lại' },
      },
    );
    expect(reverseAgain.status).toBe(409);
    expect(reverseAgain.json?.error.code).toBe('PAYMENT_ALREADY_REVERSED');

    const reverseReversal = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/payments/${reversal.id}/reverse`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { note: 'Không hợp lệ' },
      },
    );
    expect(reverseReversal.status).toBe(409);
    expect(reverseReversal.json?.error.code).toBe('PAYMENT_REVERSAL_NOT_ALLOWED');

    const cancelWithHistory = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${invoice.json!.data.id}/cancel`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { note: 'Đã reverse nhưng vẫn có lịch sử thanh toán' },
      },
    );
    expect(cancelWithHistory.status).toBe(409);
    expect(cancelWithHistory.json?.error.code).toBe('INVOICE_HAS_PAYMENTS');

    const cancellableInvoice = await requestJson<any>(harness.baseUrl, '/api/v1/billing/invoices', {
      method: 'POST',
      token: landlordA.accessToken,
      body: {
        leaseId: lease.id,
        billingMonth: '2026-10-01T00:00:00.000Z',
      },
    });
    expect(cancellableInvoice.status).toBe(201);

    const foreignCancel = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${cancellableInvoice.json!.data.id}/cancel`,
      {
        method: 'POST',
        token: landlordB.accessToken,
        body: { note: 'Không thuộc chủ nhà này' },
      },
    );
    expect(foreignCancel.status).toBe(404);
    expect(foreignCancel.json?.error.code).toBe('INVOICE_NOT_FOUND');

    const adminCancel = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${cancellableInvoice.json!.data.id}/cancel`,
      {
        method: 'POST',
        token: adminSession.accessToken,
        body: { note: 'Admin không dùng landlord API' },
      },
    );
    expect(adminCancel.status).toBe(403);

    const cancelled = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/billing/invoices/${cancellableInvoice.json!.data.id}/cancel`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { note: 'Lập nhầm hóa đơn' },
      },
    );
    expect(cancelled.status).toBe(201);
    expect(cancelled.json?.data.status).toBe('cancelled');
    expect(cancelled.json?.data.cancelledNote).toBe('Lập nhầm hóa đơn');
    expect(cancelled.json?.data.cancelledAt).toEqual(expect.any(String));

    const payCancelled = await requestJson(
      harness.baseUrl,
      `/api/v1/billing/invoices/${cancellableInvoice.json!.data.id}/payments`,
      {
        method: 'POST',
        token: landlordA.accessToken,
        body: { amount: 1_000 },
      },
    );
    expect(payCancelled.status).toBe(400);
    expect(payCancelled.json?.error.code).toBe('INVOICE_CANCELLED');

    const dashboard = await requestJson<any>(harness.baseUrl, '/api/v1/dashboard/metrics?months=2', {
      token: landlordA.accessToken,
    });
    expect(dashboard.status).toBe(200);
    expect(dashboard.json?.data.currentMonth.receivedAmount).toBe(0);
  });
});
