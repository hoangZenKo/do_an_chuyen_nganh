ALTER TABLE "StaffInvite" ADD COLUMN "propertyIds" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE TABLE "StaffPropertyScope" (
  "id" TEXT NOT NULL,
  "staffProfileId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "StaffPropertyScope_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "StaffPropertyScope_staffProfileId_propertyId_key" ON "StaffPropertyScope"("staffProfileId", "propertyId");
CREATE INDEX "StaffPropertyScope_landlordId_propertyId_idx" ON "StaffPropertyScope"("landlordId", "propertyId");
CREATE INDEX "StaffPropertyScope_staffProfileId_idx" ON "StaffPropertyScope"("staffProfileId");
ALTER TABLE "StaffPropertyScope" ADD CONSTRAINT "StaffPropertyScope_staffProfileId_fkey" FOREIGN KEY ("staffProfileId") REFERENCES "StaffProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StaffPropertyScope" ADD CONSTRAINT "StaffPropertyScope_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StaffPropertyScope" ADD CONSTRAINT "StaffPropertyScope_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "StaffPropertyScope" ("id", "staffProfileId", "propertyId", "landlordId")
SELECT md5(sp."id" || ':' || p."id"), sp."id", p."id", sp."landlordId"
FROM "StaffProfile" sp JOIN "Property" p ON p."landlordId" = sp."landlordId"
ON CONFLICT ("staffProfileId", "propertyId") DO NOTHING;
UPDATE "StaffInvite" i SET "propertyIds" = COALESCE((SELECT array_agg(p."id") FROM "Property" p WHERE p."landlordId" = i."landlordId" AND NOT p."isArchived"), ARRAY[]::TEXT[])
WHERE i."propertyIds" = ARRAY[]::TEXT[];

CREATE TYPE "TenantLifecycleRequestType" AS ENUM ('RENEWAL', 'TRANSFER_ROOM', 'CHECKOUT');
CREATE TYPE "TenantLifecycleRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED');

CREATE TABLE "TenantOccupant" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "leaseId" TEXT NOT NULL,
  "fullName" TEXT NOT NULL,
  "phone" TEXT,
  "idNumber" TEXT,
  "relationship" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TenantOccupant_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "TenantOccupant_tenantId_idx" ON "TenantOccupant"("tenantId");
CREATE INDEX "TenantOccupant_leaseId_idx" ON "TenantOccupant"("leaseId");
ALTER TABLE "TenantOccupant" ADD CONSTRAINT "TenantOccupant_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TenantOccupant" ADD CONSTRAINT "TenantOccupant_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "TenantLifecycleRequest" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "leaseId" TEXT,
  "requestedRoomId" TEXT,
  "type" "TenantLifecycleRequestType" NOT NULL,
  "status" "TenantLifecycleRequestStatus" NOT NULL DEFAULT 'PENDING',
  "requestedStart" TIMESTAMP(3),
  "requestedEnd" TIMESTAMP(3),
  "note" TEXT,
  "decisionNote" TEXT,
  "reviewedById" TEXT,
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TenantLifecycleRequest_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "TenantLifecycleRequest_landlordId_status_createdAt_idx" ON "TenantLifecycleRequest"("landlordId", "status", "createdAt");
CREATE INDEX "TenantLifecycleRequest_tenantId_createdAt_idx" ON "TenantLifecycleRequest"("tenantId", "createdAt");
ALTER TABLE "TenantLifecycleRequest" ADD CONSTRAINT "TenantLifecycleRequest_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TenantLifecycleRequest" ADD CONSTRAINT "TenantLifecycleRequest_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "TenantLifecycleRequest" ADD CONSTRAINT "TenantLifecycleRequest_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "TenantLifecycleRequest" ADD CONSTRAINT "TenantLifecycleRequest_requestedRoomId_fkey" FOREIGN KEY ("requestedRoomId") REFERENCES "Room"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "TenantNotificationPreference" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "channels" TEXT[] NOT NULL DEFAULT ARRAY['APP']::TEXT[],
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "TenantNotificationPreference_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "TenantNotificationPreference_tenantId_key" ON "TenantNotificationPreference"("tenantId");
ALTER TABLE "TenantNotificationPreference" ADD CONSTRAINT "TenantNotificationPreference_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE;
