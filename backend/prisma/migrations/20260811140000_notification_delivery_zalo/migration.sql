CREATE TYPE "NotificationDeliveryChannel" AS ENUM ('ZALO');
CREATE TYPE "NotificationDeliveryStatus" AS ENUM ('PENDING', 'SENT', 'FAILED', 'SKIPPED');

CREATE TABLE "NotificationDelivery" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "tenantId" TEXT,
  "invoiceId" TEXT,
  "channel" "NotificationDeliveryChannel" NOT NULL,
  "purpose" TEXT NOT NULL,
  "recipient" TEXT NOT NULL,
  "templateId" TEXT,
  "status" "NotificationDeliveryStatus" NOT NULL DEFAULT 'PENDING',
  "payload" JSONB,
  "providerMessageId" TEXT,
  "errorCode" TEXT,
  "errorMessage" TEXT,
  "sentAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "NotificationDelivery_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "NotificationDelivery_landlordId_idx" ON "NotificationDelivery"("landlordId");
CREATE INDEX "NotificationDelivery_tenantId_idx" ON "NotificationDelivery"("tenantId");
CREATE INDEX "NotificationDelivery_invoiceId_idx" ON "NotificationDelivery"("invoiceId");
CREATE INDEX "NotificationDelivery_channel_idx" ON "NotificationDelivery"("channel");
CREATE INDEX "NotificationDelivery_status_idx" ON "NotificationDelivery"("status");
CREATE INDEX "NotificationDelivery_purpose_idx" ON "NotificationDelivery"("purpose");
CREATE INDEX "NotificationDelivery_createdAt_idx" ON "NotificationDelivery"("createdAt");
