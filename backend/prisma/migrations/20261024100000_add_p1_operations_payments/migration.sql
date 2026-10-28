-- P1 operations, announcements and provider-backed payment links.
CREATE TYPE "TurnoverStage" AS ENUM ('RETURNED', 'INSPECTION', 'REPAIR', 'CLEANING', 'READY');
CREATE TYPE "TurnoverStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'CANCELLED');
CREATE TYPE "OperationFrequency" AS ENUM ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY');
CREATE TYPE "OperationTaskStatus" AS ENUM ('PENDING', 'COMPLETED', 'SKIPPED');
CREATE TYPE "AnnouncementAudience" AS ENUM ('ALL_TENANTS', 'PROPERTY', 'ROOM', 'GROUP', 'TENANTS');
CREATE TYPE "AnnouncementStatus" AS ENUM ('SCHEDULED', 'SENT', 'CANCELLED');
CREATE TYPE "PaymentLinkStatus" AS ENUM ('PENDING', 'PAID', 'EXPIRED', 'CANCELLED', 'FAILED');

CREATE TABLE "RoomTurnover" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "roomId" TEXT NOT NULL,
  "leaseId" TEXT,
  "stage" "TurnoverStage" NOT NULL DEFAULT 'RETURNED',
  "status" "TurnoverStatus" NOT NULL DEFAULT 'ACTIVE',
  "version" INTEGER NOT NULL DEFAULT 1,
  "note" TEXT,
  "completedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RoomTurnover_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "TurnoverStep" (
  "id" TEXT NOT NULL,
  "turnoverId" TEXT NOT NULL,
  "stage" "TurnoverStage" NOT NULL,
  "title" TEXT NOT NULL,
  "completedAt" TIMESTAMP(3),
  "completedBy" TEXT,
  "note" TEXT,
  CONSTRAINT "TurnoverStep_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "RecurringOperation" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "roomId" TEXT,
  "title" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "frequency" "OperationFrequency" NOT NULL,
  "interval" INTEGER NOT NULL DEFAULT 1,
  "anchorDay" INTEGER NOT NULL,
  "nextRunAt" TIMESTAMP(3) NOT NULL,
  "checklist" TEXT[] NOT NULL,
  "isEnabled" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RecurringOperation_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "OperationTask" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "roomId" TEXT,
  "recurringId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "dueAt" TIMESTAMP(3) NOT NULL,
  "checklist" JSONB NOT NULL,
  "version" INTEGER NOT NULL DEFAULT 1,
  "status" "OperationTaskStatus" NOT NULL DEFAULT 'PENDING',
  "completedAt" TIMESTAMP(3),
  "completedBy" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "OperationTask_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "TenantGroup" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "tenantIds" TEXT[] NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "TenantGroup_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "AnnouncementTemplate" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AnnouncementTemplate_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "Announcement" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT,
  "roomId" TEXT,
  "groupId" TEXT,
  "tenantIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "audience" "AnnouncementAudience" NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "status" "AnnouncementStatus" NOT NULL DEFAULT 'SCHEDULED',
  "sendAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sentAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Announcement_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "AnnouncementRecipient" (
  "announcementId" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "readAt" TIMESTAMP(3),
  CONSTRAINT "AnnouncementRecipient_pkey" PRIMARY KEY ("announcementId", "tenantId")
);
CREATE TABLE "PaymentLink" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "invoiceId" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "orderCode" SERIAL NOT NULL,
  "amount" INTEGER NOT NULL,
  "status" "PaymentLinkStatus" NOT NULL DEFAULT 'PENDING',
  "providerId" TEXT,
  "checkoutUrl" TEXT,
  "qrCode" TEXT,
  "accountNumber" TEXT,
  "accountName" TEXT,
  "description" TEXT,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "paidAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "PaymentLink_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "PaymentWebhookEvent" (
  "landlordId" TEXT NOT NULL,
  "id" TEXT NOT NULL,
  "paymentLinkId" TEXT NOT NULL,
  "reference" TEXT NOT NULL,
  "amount" INTEGER NOT NULL,
  "status" TEXT NOT NULL,
  "reason" TEXT,
  "paymentId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PaymentWebhookEvent_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "RoomTurnover_leaseId_key" ON "RoomTurnover"("leaseId");
CREATE UNIQUE INDEX "TurnoverStep_turnoverId_stage_key" ON "TurnoverStep"("turnoverId", "stage");
CREATE UNIQUE INDEX "OperationTask_recurringId_dueAt_key" ON "OperationTask"("recurringId", "dueAt");
CREATE UNIQUE INDEX "PaymentLink_orderCode_key" ON "PaymentLink"("orderCode");
CREATE UNIQUE INDEX "PaymentLink_providerId_key" ON "PaymentLink"("providerId");
CREATE UNIQUE INDEX "PaymentWebhookEvent_paymentLinkId_reference_key" ON "PaymentWebhookEvent"("paymentLinkId", "reference");
CREATE INDEX "RoomTurnover_landlordId_status_createdAt_idx" ON "RoomTurnover"("landlordId", "status", "createdAt");
CREATE INDEX "RoomTurnover_roomId_status_idx" ON "RoomTurnover"("roomId", "status");
CREATE INDEX "RecurringOperation_isEnabled_nextRunAt_idx" ON "RecurringOperation"("isEnabled", "nextRunAt");
CREATE INDEX "RecurringOperation_landlordId_propertyId_idx" ON "RecurringOperation"("landlordId", "propertyId");
CREATE INDEX "OperationTask_landlordId_status_dueAt_idx" ON "OperationTask"("landlordId", "status", "dueAt");
CREATE INDEX "TenantGroup_landlordId_idx" ON "TenantGroup"("landlordId");
CREATE INDEX "AnnouncementTemplate_landlordId_idx" ON "AnnouncementTemplate"("landlordId");
CREATE INDEX "Announcement_status_sendAt_idx" ON "Announcement"("status", "sendAt");
CREATE INDEX "Announcement_landlordId_createdAt_idx" ON "Announcement"("landlordId", "createdAt");
CREATE INDEX "AnnouncementRecipient_tenantId_readAt_idx" ON "AnnouncementRecipient"("tenantId", "readAt");
CREATE INDEX "PaymentLink_invoiceId_status_idx" ON "PaymentLink"("invoiceId", "status");
CREATE INDEX "PaymentLink_landlordId_createdAt_idx" ON "PaymentLink"("landlordId", "createdAt");

ALTER TABLE "RoomTurnover" ADD CONSTRAINT "RoomTurnover_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoomTurnover" ADD CONSTRAINT "RoomTurnover_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoomTurnover" ADD CONSTRAINT "RoomTurnover_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoomTurnover" ADD CONSTRAINT "RoomTurnover_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TurnoverStep" ADD CONSTRAINT "TurnoverStep_turnoverId_fkey" FOREIGN KEY ("turnoverId") REFERENCES "RoomTurnover"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RecurringOperation" ADD CONSTRAINT "RecurringOperation_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RecurringOperation" ADD CONSTRAINT "RecurringOperation_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RecurringOperation" ADD CONSTRAINT "RecurringOperation_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OperationTask" ADD CONSTRAINT "OperationTask_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OperationTask" ADD CONSTRAINT "OperationTask_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OperationTask" ADD CONSTRAINT "OperationTask_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "OperationTask" ADD CONSTRAINT "OperationTask_recurringId_fkey" FOREIGN KEY ("recurringId") REFERENCES "RecurringOperation"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AnnouncementRecipient" ADD CONSTRAINT "AnnouncementRecipient_announcementId_fkey" FOREIGN KEY ("announcementId") REFERENCES "Announcement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AnnouncementRecipient" ADD CONSTRAINT "AnnouncementRecipient_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentLink" ADD CONSTRAINT "PaymentLink_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentLink" ADD CONSTRAINT "PaymentLink_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentLink" ADD CONSTRAINT "PaymentLink_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentLink" ADD CONSTRAINT "PaymentLink_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PaymentWebhookEvent" ADD CONSTRAINT "PaymentWebhookEvent_paymentLinkId_fkey" FOREIGN KEY ("paymentLinkId") REFERENCES "PaymentLink"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "PaymentWebhookEvent_landlordId_reference_key" ON "PaymentWebhookEvent"("landlordId", "reference");
CREATE UNIQUE INDEX "RoomTurnover_one_active_room" ON "RoomTurnover"("roomId") WHERE status = 'ACTIVE';
CREATE UNIQUE INDEX "PaymentLink_one_pending_invoice" ON "PaymentLink"("invoiceId") WHERE status = 'PENDING';

CREATE FUNCTION enforce_turnover_room_status() RETURNS trigger AS $$
BEGIN
  IF NEW.status <> 'MAINTENANCE' AND EXISTS (SELECT 1 FROM "RoomTurnover" WHERE "roomId" = NEW.id AND status = 'ACTIVE') THEN
    RAISE EXCEPTION 'Room has an active turnover';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "Room_turnover_status_guard" BEFORE UPDATE OF status ON "Room" FOR EACH ROW EXECUTE FUNCTION enforce_turnover_room_status();
