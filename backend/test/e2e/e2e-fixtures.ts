import * as argon2 from 'argon2';
import { PrismaService } from '../../src/prisma/prisma.service';
import { requestJson } from './e2e-app';
import { UserRole } from '@prisma/client';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';

export const testPassword = 'StrongPassword!123';

export function assertE2eDatabase() {
  const url = process.env.DATABASE_URL ?? '';
  if (process.env.NODE_ENV !== 'test') {
    throw new Error('E2E tests require NODE_ENV=test.');
  }
  if (!/test/i.test(url)) {
    throw new Error('E2E tests require DATABASE_URL to point to a test database.');
  }
}

export async function resetDatabase(prisma: PrismaService) {
  assertE2eDatabase();
  await prisma.subscriptionEvent.deleteMany();
  await prisma.landlordSubscription.deleteMany();
  await prisma.landlordVerification.deleteMany();
  await prisma.propertyApprovalReview.deleteMany();
  await prisma.servicePlan.deleteMany();
  await prisma.billingNotification.deleteMany();
  await prisma.tenantNotificationPreference.deleteMany();
  await prisma.tenantLifecycleRequest.deleteMany();
  await prisma.tenantOccupant.deleteMany();
  await prisma.staffPropertyScope.deleteMany();
  await prisma.billingRefund.deleteMany();
  await prisma.paymentAllocation.deleteMany();
  await prisma.invoiceAdjustment.deleteMany();
  await prisma.billingCommand.deleteMany();
  await prisma.billingReminderPolicy.deleteMany();
  await prisma.billingOutboxEvent.deleteMany();
  await prisma.billingPeriodLock.deleteMany();
  await prisma.billingTariffVersion.deleteMany();
  await prisma.adminStepUpGrant.deleteMany();
  await prisma.supportSlaPolicy.deleteMany();
  await prisma.supportEscalation.deleteMany();
  await prisma.supportCaseLink.deleteMany();
  await prisma.financeReconciliationProposal.deleteMany();
  await prisma.financeStatementLine.deleteMany();
  await prisma.financeStatement.deleteMany();
  await prisma.billingReceipt.deleteMany();
  await prisma.platformNotificationDelivery.deleteMany();
  await prisma.deliveryJob.deleteMany();
  await prisma.operationsIncident.deleteMany();
  await prisma.operationsMetric.deleteMany();
  await prisma.workerHeartbeat.deleteMany();
  await prisma.auditLog.deleteMany();
  await prisma.adminReportRun.deleteMany();
  await prisma.adminReportSchedule.deleteMany();
  await prisma.adminTeamMember.deleteMany();
  await prisma.adminTeam.deleteMany();
  await prisma.slaEscalation.deleteMany();
  await prisma.moderationQualityReview.deleteMany();
  await prisma.moderationAppeal.deleteMany();
  await prisma.moderationDecision.deleteMany();
  await prisma.moderationPolicy.deleteMany();
  await prisma.platformNotification.deleteMany();
  await prisma.supportSavedView.deleteMany();
  await prisma.supportAgentSkill.deleteMany();
  await prisma.supportMessage.deleteMany();
  await prisma.supportTemplate.deleteMany();
  await prisma.supportTicket.deleteMany();
  await prisma.featureFlag.deleteMany();
  await prisma.moderationWorkItem.deleteMany();
  await prisma.paymentWebhookEvent.deleteMany();
  await prisma.paymentLink.deleteMany();
  await prisma.announcementRecipient.deleteMany();
  await prisma.announcement.deleteMany();
  await prisma.announcementTemplate.deleteMany();
  await prisma.tenantGroup.deleteMany();
  await prisma.operationTask.deleteMany();
  await prisma.recurringOperation.deleteMany();
  await prisma.turnoverStep.deleteMany();
  await prisma.roomTurnover.deleteMany();
  await prisma.housingNotification.deleteMany();
  await prisma.roomReview.deleteMany();
  await prisma.roomViewing.deleteMany();
  await prisma.savedListing.deleteMany();
  await prisma.pilotFeedback.deleteMany();
  await prisma.notificationRead.deleteMany();
  await prisma.notificationDelivery.deleteMany();
  await prisma.maintenanceComment.deleteMany();
  await prisma.maintenanceTicket.deleteMany();
  await prisma.paymentProof.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.invoice.deleteMany();
  await prisma.serviceTariffVersion.deleteMany();
  await prisma.roomServiceFee.deleteMany();
  await prisma.meterReading.deleteMany();
  await prisma.leaseSettlement.deleteMany();
  await prisma.lease.deleteMany();
  await prisma.room.deleteMany();
  await prisma.property.deleteMany();
  await prisma.tenantInvite.deleteMany();
  await prisma.staffInvite.deleteMany();
  await prisma.accountAccessToken.deleteMany();
  await prisma.authSession.deleteMany();
  await prisma.adminProfile.deleteMany();
  await prisma.tenant.deleteMany();
  await prisma.staffProfile.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
}

export function uniqueEmail(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}@example.com`;
}

export async function registerLandlord(baseUrl: string, prefix = 'landlord') {
  const email = uniqueEmail(prefix);
  const response = await requestJson<any>(baseUrl, '/api/v1/auth/register', {
    method: 'POST',
    body: {
      fullName: `Test ${prefix}`,
      email,
      phone: '+84901234567',
      password: testPassword,
    },
  });
  expect(response.status).toBe(201);
  return {
    email,
    user: response.json!.data.user,
    accessToken: response.json!.data.accessToken as string,
    refreshToken: response.json!.data.refreshToken as string,
  };
}

export async function createAdmin(prisma: PrismaService, prefix = 'admin') {
  const email = uniqueEmail(prefix);
  await prisma.user.create({
    data: {
      fullName: `Test ${prefix}`,
      email,
      phone: '+84909876543',
      passwordHash: await argon2.hash(testPassword),
      role: UserRole.ADMIN,
      adminProfile: {
        create: {
          preset: 'super_admin',
          permissions: [...ADMIN_PRESETS.super_admin],
        },
      },
    },
  });
  return { email };
}

export async function login(baseUrl: string, email: string) {
  const response = await requestJson<any>(baseUrl, '/api/v1/auth/login', {
    method: 'POST',
    body: { email, password: testPassword },
  });
  expect(response.status).toBe(201);
  return {
    user: response.json!.data.user,
    accessToken: response.json!.data.accessToken as string,
    refreshToken: response.json!.data.refreshToken as string,
  };
}

export async function createProperty(
  baseUrl: string,
  token: string,
  name = 'Khu trọ E2E',
) {
  const response = await requestJson<any>(baseUrl, '/api/v1/properties', {
    method: 'POST',
    token,
    body: { name, address: '123 Test Street' },
  });
  expect(response.status).toBe(201);
  return response.json!.data;
}

export async function createRoom(
  baseUrl: string,
  token: string,
  propertyId: string,
  name = 'P.101',
) {
  const response = await requestJson<any>(
    baseUrl,
    `/api/v1/properties/${propertyId}/rooms`,
    {
      method: 'POST',
      token,
      body: {
        name,
        status: 'vacant',
        basePrice: 3500000,
        floor: 1,
        areaSqm: 25,
      },
    },
  );
  expect(response.status).toBe(201);
  return response.json!.data;
}

export async function createTenant(
  baseUrl: string,
  token: string,
  fullName = 'Nguyễn Văn E2E',
) {
  const response = await requestJson<any>(baseUrl, '/api/v1/tenants', {
    method: 'POST',
    token,
    body: { fullName, phone: '+84901112222' },
  });
  expect(response.status).toBe(201);
  return response.json!.data;
}

export async function createLease(
  baseUrl: string,
  token: string,
  roomId: string,
  tenantId: string,
  monthlyRent = 3500000,
) {
  const response = await requestJson<any>(baseUrl, '/api/v1/leases', {
    method: 'POST',
    token,
    body: {
      roomId,
      tenantId,
      startDate: '2026-08-01T00:00:00.000Z',
      monthlyRent,
      deposit: 1000000,
    },
  });
  expect(response.status).toBe(201);
  return response.json!.data;
}
