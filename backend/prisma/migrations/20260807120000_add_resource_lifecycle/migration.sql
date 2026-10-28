-- Add soft lifecycle flags for operational resources.
ALTER TABLE "Property" ADD COLUMN "isArchived" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Room" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "Tenant" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX "Property_landlordId_isArchived_idx" ON "Property"("landlordId", "isArchived");
CREATE INDEX "Room_propertyId_isActive_idx" ON "Room"("propertyId", "isActive");
CREATE INDEX "Tenant_landlordId_isActive_idx" ON "Tenant"("landlordId", "isActive");

-- Close the race window around the application-level active lease check.
CREATE UNIQUE INDEX "Lease_one_active_per_room" ON "Lease"("roomId")
WHERE "status" = 'ACTIVE';
