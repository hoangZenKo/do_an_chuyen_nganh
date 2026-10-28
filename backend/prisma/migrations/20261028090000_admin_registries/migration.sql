-- CreateTable
CREATE TABLE "LandlordVerification" (
    "id" TEXT NOT NULL,
    "landlordId" TEXT NOT NULL,
    "ticketId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "version" INTEGER NOT NULL DEFAULT 1,
    "reviewNote" TEXT NOT NULL DEFAULT '',
    "reviewerId" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LandlordVerification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PropertyApprovalReview" (
    "id" TEXT NOT NULL,
    "propertyId" TEXT NOT NULL,
    "snapshotHash" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "version" INTEGER NOT NULL DEFAULT 1,
    "reviewNote" TEXT NOT NULL DEFAULT '',
    "reviewerId" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PropertyApprovalReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ServicePlan" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "price" INTEGER NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'VND',
    "interval" TEXT NOT NULL DEFAULT 'MONTHLY',
    "maxProperties" INTEGER NOT NULL,
    "maxRooms" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "version" INTEGER NOT NULL DEFAULT 1,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ServicePlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LandlordSubscription" (
    "id" TEXT NOT NULL,
    "landlordId" TEXT NOT NULL,
    "planId" TEXT NOT NULL,
    "planSnapshot" JSONB NOT NULL,
    "version" INTEGER NOT NULL DEFAULT 1,
    "startsAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endsAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LandlordSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SubscriptionEvent" (
    "id" TEXT NOT NULL,
    "subscriptionId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "snapshot" JSONB NOT NULL,
    "reason" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SubscriptionEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "LandlordVerification_landlordId_key" ON "LandlordVerification"("landlordId");

-- CreateIndex
CREATE INDEX "LandlordVerification_status_submittedAt_idx" ON "LandlordVerification"("status", "submittedAt");

-- CreateIndex
CREATE UNIQUE INDEX "PropertyApprovalReview_propertyId_key" ON "PropertyApprovalReview"("propertyId");

-- CreateIndex
CREATE INDEX "PropertyApprovalReview_status_submittedAt_idx" ON "PropertyApprovalReview"("status", "submittedAt");

-- CreateIndex
CREATE UNIQUE INDEX "ServicePlan_code_key" ON "ServicePlan"("code");

-- CreateIndex
CREATE UNIQUE INDEX "LandlordSubscription_landlordId_key" ON "LandlordSubscription"("landlordId");

-- CreateIndex
CREATE INDEX "SubscriptionEvent_subscriptionId_createdAt_idx" ON "SubscriptionEvent"("subscriptionId", "createdAt");

-- AddForeignKey
ALTER TABLE "LandlordVerification" ADD CONSTRAINT "LandlordVerification_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LandlordVerification" ADD CONSTRAINT "LandlordVerification_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PropertyApprovalReview" ADD CONSTRAINT "PropertyApprovalReview_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LandlordSubscription" ADD CONSTRAINT "LandlordSubscription_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LandlordSubscription" ADD CONSTRAINT "LandlordSubscription_planId_fkey" FOREIGN KEY ("planId") REFERENCES "ServicePlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SubscriptionEvent" ADD CONSTRAINT "SubscriptionEvent_subscriptionId_fkey" FOREIGN KEY ("subscriptionId") REFERENCES "LandlordSubscription"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


ALTER TABLE "LandlordVerification" ADD CONSTRAINT "LandlordVerification_state_check"
  CHECK ("status" IN ('PENDING','NEEDS_INFO','APPROVED','REJECTED') AND "version" > 0);
ALTER TABLE "PropertyApprovalReview" ADD CONSTRAINT "PropertyApprovalReview_state_check"
  CHECK ("status" IN ('PENDING','NEEDS_INFO','APPROVED','REJECTED') AND "version" > 0);
ALTER TABLE "ServicePlan" ADD CONSTRAINT "ServicePlan_terms_check"
  CHECK ("code" IN ('FREE','PRO','PREMIUM') AND "price" >= 0 AND ("code" <> 'FREE' OR "price" = 0)
    AND "currency" = 'VND' AND "interval" = 'MONTHLY' AND "maxProperties" > 0 AND "maxRooms" > 0 AND "version" > 0);
ALTER TABLE "LandlordSubscription" ADD CONSTRAINT "LandlordSubscription_terms_check"
  CHECK ("version" > 0 AND ("endsAt" IS NULL OR "endsAt" > "startsAt"));
ALTER TABLE "SubscriptionEvent" ADD CONSTRAINT "SubscriptionEvent_action_check"
  CHECK ("action" IN ('ASSIGNED','REASSIGNED','CANCELLED') AND length(trim("reason")) >= 10);
