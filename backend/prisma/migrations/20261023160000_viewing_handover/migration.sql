ALTER TABLE "RoomListing" ADD COLUMN "viewingSlotsRequired" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "RoomViewing" ADD COLUMN "endsAt" TIMESTAMP(3),
  ADD COLUMN "slotId" TEXT, ADD COLUMN "cancellationReason" TEXT NOT NULL DEFAULT '',
  ADD COLUMN "reminderSentAt" TIMESTAMP(3);
UPDATE "RoomViewing" SET "endsAt" = "scheduledAt" + INTERVAL '30 minutes';
UPDATE "RoomViewing" SET "cancellationReason" = "responseNote" WHERE status = 'CANCELLED';
ALTER TABLE "RoomViewing" ALTER COLUMN "endsAt" SET NOT NULL;
CREATE TABLE "ViewingSlot" (
  "id" TEXT NOT NULL PRIMARY KEY, "listingId" TEXT NOT NULL,
  "startsAt" TIMESTAMP(3) NOT NULL, "endsAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ViewingSlot_period_check" CHECK ("endsAt" > "startsAt"),
  CONSTRAINT "ViewingSlot_listingId_fkey" FOREIGN KEY ("listingId") REFERENCES "RoomListing"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "ViewingSlot_listingId_startsAt_idx" ON "ViewingSlot"("listingId", "startsAt");
ALTER TABLE "RoomViewing" ADD CONSTRAINT "RoomViewing_slotId_fkey" FOREIGN KEY ("slotId") REFERENCES "ViewingSlot"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "RoomViewing_status_scheduledAt_reminderSentAt_idx" ON "RoomViewing"("status", "scheduledAt", "reminderSentAt");
CREATE TABLE "LeaseHandover" (
  "id" TEXT NOT NULL PRIMARY KEY, "leaseId" TEXT NOT NULL UNIQUE, "version" INTEGER NOT NULL DEFAULT 1,
  "electricity" INTEGER NOT NULL, "water" INTEGER NOT NULL, "condition" TEXT NOT NULL,
  "imageUrls" TEXT[] NOT NULL, "acceptedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "LeaseHandover_readings_check" CHECK ("electricity" >= 0 AND "water" >= 0),
  CONSTRAINT "LeaseHandover_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
