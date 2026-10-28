ALTER TABLE "AuditLog" ADD COLUMN "requestId" TEXT;
CREATE INDEX "AuditLog_requestId_idx" ON "AuditLog"("requestId");

CREATE TABLE "DeliveryJob" (
  "id" TEXT NOT NULL, "kind" TEXT NOT NULL, "tokenId" TEXT, "payload" TEXT,
  "status" TEXT NOT NULL DEFAULT 'PENDING', "attempts" INTEGER NOT NULL DEFAULT 0,
  "availableAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "expiresAt" TIMESTAMP(3) NOT NULL,
  "leaseUntil" TIMESTAMP(3), "leaseOwner" TEXT, "lastError" TEXT, "deliveredAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "DeliveryJob_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "DeliveryJob_tokenId_fkey" FOREIGN KEY ("tokenId") REFERENCES "AccountAccessToken"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "DeliveryJob_status_check" CHECK ("status" IN ('PENDING','PROCESSING','SENT','DEAD','CANCELLED')),
  CONSTRAINT "DeliveryJob_kind_check" CHECK ("kind" IN ('ACCOUNT_ACCESS','INCIDENT_ALERT'))
);
CREATE UNIQUE INDEX "DeliveryJob_tokenId_key" ON "DeliveryJob"("tokenId");
CREATE INDEX "DeliveryJob_status_availableAt_idx" ON "DeliveryJob"("status", "availableAt");
CREATE INDEX "DeliveryJob_leaseUntil_idx" ON "DeliveryJob"("leaseUntil");

CREATE TABLE "OperationsMetric" (
  "minute" TIMESTAMP(3) NOT NULL, "requests" INTEGER NOT NULL DEFAULT 0,
  "errors" INTEGER NOT NULL DEFAULT 0, "loginFailures" INTEGER NOT NULL DEFAULT 0,
  "mfaFailures" INTEGER NOT NULL DEFAULT 0, "durationMs" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "OperationsMetric_pkey" PRIMARY KEY ("minute")
);
CREATE TABLE "WorkerHeartbeat" (
  "name" TEXT NOT NULL, "status" TEXT NOT NULL, "lastRunAt" TIMESTAMP(3) NOT NULL,
  "lastSuccessAt" TIMESTAMP(3), CONSTRAINT "WorkerHeartbeat_pkey" PRIMARY KEY ("name")
);
CREATE TABLE "OperationsIncident" (
  "id" TEXT NOT NULL, "key" TEXT NOT NULL, "severity" TEXT NOT NULL, "title" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'OPEN', "occurrences" INTEGER NOT NULL DEFAULT 1,
  "firstSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolvedAt" TIMESTAMP(3), "acknowledgedBy" TEXT, "version" INTEGER NOT NULL DEFAULT 1,
  CONSTRAINT "OperationsIncident_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "OperationsIncident_status_check" CHECK ("status" IN ('OPEN','ACKNOWLEDGED','RESOLVED'))
);
CREATE UNIQUE INDEX "OperationsIncident_key_key" ON "OperationsIncident"("key");

UPDATE "AdminProfile" SET permissions = array_append(permissions, 'admin.operations.view')
  WHERE preset = 'super_admin' AND NOT ('admin.operations.view' = ANY(permissions));
UPDATE "AdminProfile" SET permissions = array_append(permissions, 'admin.operations.manage')
  WHERE preset = 'super_admin' AND NOT ('admin.operations.manage' = ANY(permissions));
UPDATE "AdminProfile" SET permissions = array_append(permissions, 'admin.audit.export')
  WHERE preset = 'super_admin' AND NOT ('admin.audit.export' = ANY(permissions));
