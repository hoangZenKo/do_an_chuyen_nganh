import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import {
  createLease,
  createProperty,
  createRoom,
  createTenant,
  registerLandlord,
  resetDatabase,
  testPassword,
} from './e2e-fixtures';

async function uploadFile(
  baseUrl: string,
  token: string,
  fileName: string,
  content: string,
  mimeType = 'image/png',
) {
  const form = new FormData();
  form.append(
    'file',
    new Blob([Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==', 'base64'), content], { type: mimeType }),
    fileName,
  );

  const response = await fetch(new URL('/api/v1/uploads', baseUrl), {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
    },
    body: form,
  });

  const text = await response.text();
  const json = text ? (JSON.parse(text) as any) : null;
  return {
    status: response.status,
    json,
  };
}

async function createTenantInvite(
  baseUrl: string,
  token: string,
  tenantId: string,
  email: string,
) {
  return requestJson<any>(baseUrl, `/api/v1/tenants/${tenantId}/invite`, {
    method: 'POST',
    token,
    body: { email },
  });
}

async function acceptTenantInvite(baseUrl: string, inviteCode: string) {
  return requestJson<any>(baseUrl, '/api/v1/tenant-invites/accept', {
    method: 'POST',
    body: {
      inviteCode,
      password: testPassword,
    },
  });
}

describe('Tenant portal priority flows E2E', () => {
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

  it('covers tenant invite, portal, upload, payment proof, maintenance, notifications and Zalo flows', async () => {
    const landlord = await registerLandlord(harness.baseUrl, 'tenant-flow');
    const property = await createProperty(harness.baseUrl, landlord.accessToken, 'Khu Tenant Flow');
    const room = await createRoom(harness.baseUrl, landlord.accessToken, property.id, 'P.401');
    const tenant = await createTenant(harness.baseUrl, landlord.accessToken, 'Tenant Portal Flow');
    const tenantEmail = `tenant-flow-${Date.now()}@example.com`;

    const invite = await createTenantInvite(
      harness.baseUrl,
      landlord.accessToken,
      tenant.id,
      tenantEmail,
    );
    expect(invite.status).toBe(201);
    expect(invite.json?.data.email).toBe(tenantEmail);

    const tenantSession = await acceptTenantInvite(
      harness.baseUrl,
      invite.json!.data.inviteCode,
    );
    expect(tenantSession.status).toBe(201);
    expect(tenantSession.json?.data.user.role).toBe('tenant');
    expect(tenantSession.json?.data.user.email).toBe(tenantEmail);

    const tenantToken = tenantSession.json!.data.accessToken as string;

    const landlordForbidden = await requestJson(
      harness.baseUrl,
      '/api/v1/tenant/me',
      { token: landlord.accessToken },
    );
    expect(landlordForbidden.status).toBe(403);

    const me = await requestJson<any>(harness.baseUrl, '/api/v1/tenant/me', {
      token: tenantToken,
    });
    expect(me.status).toBe(200);
    expect(me.json?.data.id).toBe(tenant.id);
    expect(me.json?.data.landlordName).toBe(landlord.user.fullName);

    const lease = await createLease(
      harness.baseUrl,
      landlord.accessToken,
      room.id,
      tenant.id,
      3_500_000,
    );

    const invoice = await requestJson<any>(harness.baseUrl, '/api/v1/billing/invoices', {
      method: 'POST',
      token: landlord.accessToken,
      body: {
        leaseId: lease.id,
        billingMonth: '2026-08-01T00:00:00.000Z',
        dueDate: '2026-08-20T00:00:00.000Z',
        otherAmount: 50_000,
        meterReadings: [
          {
            utilityType: 'electricity',
            previousReading: 100,
            currentReading: 120,
            unitPrice: 3000,
          },
          {
            utilityType: 'water',
            previousReading: 40,
            currentReading: 45,
            unitPrice: 12000,
          },
        ],
      },
    });
    expect(invoice.status).toBe(201);
    expect(invoice.json?.data.totalAmount).toBe(3_670_000);

    const proofUpload = await uploadFile(
      harness.baseUrl,
      tenantToken,
      'proof.png',
      'payment-proof-file',
    );
    expect(proofUpload.status).toBe(201);
    const proofUrl = proofUpload.json?.data.url as string;
    expect(proofUrl).toMatch(/^\/uploads\//);

    const paymentProof = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenant/invoices/${invoice.json!.data.id}/payment-proofs`,
      {
        method: 'POST',
        token: tenantToken,
        body: {
          amount: 3_650_000,
          method: 'bank_transfer',
          note: 'Đã chuyển khoản',
          proofImageUrls: [proofUrl],
        },
      },
    );
    expect(paymentProof.status).toBe(201);
    expect(paymentProof.json?.data.proofImageUrls).toEqual([proofUrl]);
    expect(paymentProof.json?.data.status).toBe('pending');

    const invoiceDetail = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenant/invoices/${invoice.json!.data.id}`,
      { token: tenantToken },
    );
    expect(invoiceDetail.status).toBe(200);
    expect(invoiceDetail.json?.data.paymentProofs).toHaveLength(1);
    expect(invoiceDetail.json?.data.paymentProofs[0].proofImageUrls).toEqual([
      proofUrl,
    ]);

    const maintenanceImage = await uploadFile(
      harness.baseUrl,
      tenantToken,
      'maintenance.png',
      'maintenance-image-file',
    );
    expect(maintenanceImage.status).toBe(201);
    const maintenanceUrl = maintenanceImage.json?.data.url as string;

    const maintenance = await requestJson<any>(harness.baseUrl, '/api/v1/tenant/maintenance', {
      method: 'POST',
      token: tenantToken,
      body: {
        title: 'Máy lạnh không mát',
        description: 'Quạt vẫn quay nhưng không lạnh',
        priority: 'urgent',
        imageUrls: [maintenanceUrl],
      },
    });
    expect(maintenance.status).toBe(201);
    expect(maintenance.json?.data.priority).toBe('urgent');
    expect(maintenance.json?.data.imageUrls).toEqual([maintenanceUrl]);

    const commentImage = await uploadFile(
      harness.baseUrl,
      tenantToken,
      'comment.png',
      'maintenance-comment-file',
    );
    expect(commentImage.status).toBe(201);
    const commentUrl = commentImage.json?.data.url as string;

    const comment = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenant/maintenance/${maintenance.json!.data.id}/comments`,
      {
        method: 'POST',
        token: tenantToken,
        body: {
          body: 'Mình chụp thêm ảnh ở đây.',
          imageUrls: [commentUrl],
        },
      },
    );
    expect(comment.status).toBe(201);
    expect(comment.json?.data.imageUrls).toEqual([commentUrl]);

    const landlordMessage = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/notifications/zalo/manual-message',
      {
        method: 'POST',
        token: landlord.accessToken,
        body: {
          tenantId: tenant.id,
          invoiceId: invoice.json!.data.id,
          message: 'Anh/chị nhớ thanh toán hóa đơn tháng 08 nhé.',
        },
      },
    );
    expect(landlordMessage.status).toBe(201);
    expect(landlordMessage.json?.data.purpose).toBe('zalo_manual_message');

    const tenantMessage = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/zalo-messages',
      {
        method: 'POST',
        token: tenantToken,
        body: {
          message: 'Em đã xem tin nhắn, em sẽ thanh toán sớm.',
        },
      },
    );
    expect(tenantMessage.status).toBe(201);
    expect(tenantMessage.json?.data.purpose).toBe('tenant_manual_message');

    const dashboard = await requestJson<any>(harness.baseUrl, '/api/v1/tenant/dashboard', {
      token: tenantToken,
    });
    expect(dashboard.status).toBe(200);
    expect(dashboard.json?.data.profile.id).toBe(tenant.id);
    expect(dashboard.json?.data.outstandingAmount).toBe(3_670_000);
    expect(dashboard.json?.data.openInvoiceCount).toBe(1);
    expect(dashboard.json?.data.overdueInvoiceCount).toBe(1);
    expect(dashboard.json?.data.openMaintenanceCount).toBe(1);
    expect(dashboard.json?.data.unreadNotificationCount).toBeGreaterThanOrEqual(2);

    const invoices = await requestJson<any>(harness.baseUrl, '/api/v1/tenant/invoices', {
      token: tenantToken,
    });
    expect(invoices.status).toBe(200);
    expect(invoices.json?.data).toHaveLength(1);
    expect(invoices.json?.data[0].paymentProofs).toHaveLength(1);

    const maintenanceList = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/maintenance',
      { token: tenantToken },
    );
    expect(maintenanceList.status).toBe(200);
    expect(maintenanceList.json?.data).toHaveLength(1);
    expect(maintenanceList.json?.data[0].comments).toHaveLength(1);
    expect(maintenanceList.json?.data[0].comments[0].imageUrls).toEqual([commentUrl]);

    const notificationsBefore = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/notifications',
      { token: tenantToken },
    );
    expect(notificationsBefore.status).toBe(200);
    expect(notificationsBefore.json?.data.length).toBeGreaterThanOrEqual(2);
    const invoiceNotification = notificationsBefore.json!.data.find(
      (item: any) => item.kind === 'invoice_overdue',
    );
    expect(invoiceNotification).toBeTruthy();

    const markNotification = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenant/notifications/${invoiceNotification.id}/read`,
      {
        method: 'POST',
        token: tenantToken,
      },
    );
    expect(markNotification.status).toBe(201);
    expect(markNotification.json?.data.read).toBe(true);

    const notificationsAfter = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/notifications',
      { token: tenantToken },
    );
    expect(notificationsAfter.status).toBe(200);
    expect(notificationsAfter.json?.summary.unreadCount).toBe(
      notificationsBefore.json!.summary.unreadCount - 1,
    );

    const zaloMessagesBefore = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/zalo-messages',
      { token: tenantToken },
    );
    expect(zaloMessagesBefore.status).toBe(200);
    expect(zaloMessagesBefore.json?.data.length).toBeGreaterThanOrEqual(2);
    const landlordZalo = zaloMessagesBefore.json!.data.find(
      (item: any) => item.purpose === 'zalo_manual_message',
    );
    expect(landlordZalo).toBeTruthy();
    expect(landlordZalo.read).toBe(false);

    const readZalo = await requestJson<any>(
      harness.baseUrl,
      `/api/v1/tenant/zalo-messages/${landlordZalo.id}/read`,
      {
        method: 'POST',
        token: tenantToken,
      },
    );
    expect(readZalo.status).toBe(201);
    expect(readZalo.json?.data.read).toBe(true);

    const zaloMessagesAfter = await requestJson<any>(
      harness.baseUrl,
      '/api/v1/tenant/zalo-messages',
      { token: tenantToken },
    );
    expect(zaloMessagesAfter.status).toBe(200);
    const readBack = zaloMessagesAfter.json!.data.find(
      (item: any) => item.id === landlordZalo.id,
    );
    expect(readBack.read).toBe(true);

    const tenantInvoiceOnLandlordScope = await requestJson(
      harness.baseUrl,
      `/api/v1/tenant/invoices/${invoice.json!.data.id}`,
      { token: landlord.accessToken },
    );
    expect(tenantInvoiceOnLandlordScope.status).toBe(403);
  });
});
