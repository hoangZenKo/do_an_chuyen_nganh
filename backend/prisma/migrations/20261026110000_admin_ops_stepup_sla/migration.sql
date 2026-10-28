-- Admin operations: scoped step-up grants, incident ownership/lifecycle, support case links and SLA policy.
ALTER TABLE "AdminProfile"
  ADD COLUMN "accessReviewedAt" TIMESTAMP(3),
  ADD COLUMN "accessReviewedBy" TEXT,
  ADD COLUMN "nextAccessReviewAt" TIMESTAMP(3),
  ADD COLUMN "reviewVersion" INTEGER NOT NULL DEFAULT 1;

ALTER TABLE "OperationsIncident"
  ADD COLUMN "ownerId" TEXT,
  ADD COLUMN "conditionActive" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN "snoozedUntil" TIMESTAMP(3),
  ADD COLUMN "resolutionNote" TEXT,
  ADD COLUMN "resolvedBy" TEXT;
CREATE INDEX "OperationsIncident_status_snoozedUntil_idx" ON "OperationsIncident"("status", "snoozedUntil");
CREATE INDEX "OperationsIncident_ownerId_status_idx" ON "OperationsIncident"("ownerId", "status");

ALTER TABLE "SupportTicket"
  ADD COLUMN "slaSnapshot" JSONB,
  ADD COLUMN "slaPausedAt" TIMESTAMP(3),
  ADD COLUMN "slaCheckedAt" TIMESTAMP(3);
CREATE INDEX "SupportTicket_slaCheckedAt_idx" ON "SupportTicket"("slaCheckedAt");

CREATE TABLE "AdminStepUpGrant" (
  "id" TEXT NOT NULL,
  "tokenHash" TEXT NOT NULL,
  "sessionId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "action" TEXT NOT NULL,
  "fingerprint" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "consumedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AdminStepUpGrant_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "AdminStepUpGrant_tokenHash_key" ON "AdminStepUpGrant"("tokenHash");
CREATE INDEX "AdminStepUpGrant_expiresAt_idx" ON "AdminStepUpGrant"("expiresAt");
ALTER TABLE "AdminStepUpGrant" ADD CONSTRAINT "AdminStepUpGrant_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "AuthSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "SupportSlaPolicy" (
  "id" TEXT NOT NULL DEFAULT 'platform',
  "enabled" BOOLEAN NOT NULL DEFAULT false,
  "timezone" TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
  "weekdays" INTEGER[] NOT NULL DEFAULT ARRAY[1,2,3,4,5],
  "startMinute" INTEGER NOT NULL DEFAULT 540,
  "endMinute" INTEGER NOT NULL DEFAULT 1020,
  "holidays" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "pauseWaiting" BOOLEAN NOT NULL DEFAULT false,
  "responseMinutes" JSONB NOT NULL,
  "resolutionMinutes" JSONB NOT NULL,
  "escalationMinutes" INTEGER[] NOT NULL DEFAULT ARRAY[0,240,1440],
  "version" INTEGER NOT NULL DEFAULT 1,
  "updatedById" TEXT NOT NULL,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "SupportSlaPolicy_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SupportEscalation" (
  "id" TEXT NOT NULL,
  "ticketId" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "deadlineAt" TIMESTAMP(3) NOT NULL,
  "level" INTEGER NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SupportEscalation_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "SupportEscalation_ticketId_kind_deadlineAt_level_key" ON "SupportEscalation"("ticketId", "kind", "deadlineAt", "level");
ALTER TABLE "SupportEscalation" ADD CONSTRAINT "SupportEscalation_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "SupportCaseLink" (
  "id" TEXT NOT NULL,
  "ticketId" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "targetId" TEXT NOT NULL,
  "createdById" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "SupportCaseLink_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "SupportCaseLink_ticketId_kind_targetId_key" ON "SupportCaseLink"("ticketId", "kind", "targetId");
ALTER TABLE "SupportCaseLink" ADD CONSTRAINT "SupportCaseLink_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "SupportTicket"("id") ON DELETE CASCADE ON UPDATE CASCADE;
