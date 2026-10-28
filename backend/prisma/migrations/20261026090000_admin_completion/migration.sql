-- Admin completion: support attachments/views/skills, notification delivery state, finance statement workflow.
ALTER TABLE "AdminReportSchedule" ADD COLUMN "timezone" TEXT NOT NULL DEFAULT 'UTC';
ALTER TABLE "AdminReportRun" ADD COLUMN "objectKey" TEXT;

CREATE TABLE "SupportAttachment" (
    "id" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "filename" TEXT NOT NULL,
    "internal" BOOLEAN NOT NULL DEFAULT false,
    "sha256" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "SupportAttachment_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "SupportAttachment_filename_key" ON "SupportAttachment"("filename");
CREATE INDEX "SupportAttachment_ticketId_createdAt_idx" ON "SupportAttachment"("ticketId", "createdAt");
ALTER TABLE "SupportAttachment" ADD CONSTRAINT "SupportAttachment_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SupportAttachment" ADD CONSTRAINT "SupportAttachment_filename_fkey" FOREIGN KEY ("filename") REFERENCES "UploadedFile"("filename") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "SupportSavedView" (
    "id" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "filters" JSONB NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "SupportSavedView_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "SupportSavedView_ownerId_name_key" ON "SupportSavedView"("ownerId", "name");
ALTER TABLE "SupportSavedView" ADD CONSTRAINT "SupportSavedView_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "SupportAgentSkill" (
    "userId" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "maxOpen" INTEGER NOT NULL DEFAULT 20,
    CONSTRAINT "SupportAgentSkill_pkey" PRIMARY KEY ("userId", "category")
);
ALTER TABLE "SupportAgentSkill" ADD CONSTRAINT "SupportAgentSkill_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "PlatformNotificationPreference" (
    "userId" TEXT NOT NULL,
    "email" BOOLEAN NOT NULL DEFAULT false,
    "push" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "PlatformNotificationPreference_pkey" PRIMARY KEY ("userId")
);
ALTER TABLE "PlatformNotificationPreference" ADD CONSTRAINT "PlatformNotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "PlatformNotificationDelivery" (
    "id" TEXT NOT NULL,
    "notificationId" TEXT NOT NULL,
    "channel" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "availableAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leaseOwner" TEXT,
    "leaseUntil" TIMESTAMP(3),
    "lastError" TEXT,
    "deliveredAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "PlatformNotificationDelivery_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "PlatformNotificationDelivery_notificationId_channel_key" ON "PlatformNotificationDelivery"("notificationId", "channel");
CREATE INDEX "PlatformNotificationDelivery_status_availableAt_idx" ON "PlatformNotificationDelivery"("status", "availableAt");
ALTER TABLE "PlatformNotificationDelivery" ADD CONSTRAINT "PlatformNotificationDelivery_notificationId_fkey" FOREIGN KEY ("notificationId") REFERENCES "PlatformNotification"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "FinanceStatement" (
    "id" TEXT NOT NULL,
    "propertyId" TEXT NOT NULL,
    "accountKey" TEXT NOT NULL,
    "importKey" TEXT NOT NULL,
    "contentHash" TEXT NOT NULL,
    "importedBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "FinanceStatement_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "FinanceStatement_importKey_key" ON "FinanceStatement"("importKey");
CREATE INDEX "FinanceStatement_propertyId_createdAt_idx" ON "FinanceStatement"("propertyId", "createdAt");

CREATE TABLE "FinanceStatementLine" (
    "id" TEXT NOT NULL,
    "statementId" TEXT NOT NULL,
    "accountKey" TEXT NOT NULL,
    "propertyId" TEXT NOT NULL,
    "externalId" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL,
    "reference" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'UNMATCHED',
    "paymentId" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT "FinanceStatementLine_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "FinanceStatementLine_paymentId_key" ON "FinanceStatementLine"("paymentId");
CREATE UNIQUE INDEX "FinanceStatementLine_accountKey_externalId_key" ON "FinanceStatementLine"("accountKey", "externalId");
CREATE INDEX "FinanceStatementLine_propertyId_status_occurredAt_idx" ON "FinanceStatementLine"("propertyId", "status", "occurredAt");
ALTER TABLE "FinanceStatementLine" ADD CONSTRAINT "FinanceStatementLine_statementId_fkey" FOREIGN KEY ("statementId") REFERENCES "FinanceStatement"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "FinanceStatementLine" ADD CONSTRAINT "FinanceStatementLine_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "FinanceReconciliationProposal" (
    "id" TEXT NOT NULL,
    "lineId" TEXT NOT NULL,
    "paymentId" TEXT,
    "action" TEXT NOT NULL,
    "lineVersion" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "makerId" TEXT NOT NULL,
    "checkerId" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "reviewReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewedAt" TIMESTAMP(3),
    CONSTRAINT "FinanceReconciliationProposal_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "FinanceReconciliationProposal_status_createdAt_idx" ON "FinanceReconciliationProposal"("status", "createdAt");
CREATE UNIQUE INDEX "FinanceReconciliationProposal_pending_line_key" ON "FinanceReconciliationProposal"("lineId") WHERE "status" = 'PENDING';
ALTER TABLE "FinanceReconciliationProposal" ADD CONSTRAINT "FinanceReconciliationProposal_lineId_fkey" FOREIGN KEY ("lineId") REFERENCES "FinanceStatementLine"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
