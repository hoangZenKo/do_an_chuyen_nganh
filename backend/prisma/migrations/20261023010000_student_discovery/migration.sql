ALTER TABLE "RoomListing"
ADD COLUMN "latitude" DOUBLE PRECISION,
ADD COLUMN "longitude" DOUBLE PRECISION,
ADD COLUMN "parkingFee" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "availabilityConfirmedAt" TIMESTAMP(3),
ADD COLUMN "landlordVerifiedAt" TIMESTAMP(3),
ADD COLUMN "inspectedAt" TIMESTAMP(3);
ALTER TABLE "RoomListing" ADD CONSTRAINT "listing_coordinate_pair" CHECK (
  ("latitude" IS NULL AND "longitude" IS NULL) OR
  ("latitude" IS NOT NULL AND "longitude" IS NOT NULL AND "latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180)
);
ALTER TABLE "RoomListing" ADD CONSTRAINT "listing_parking_nonnegative" CHECK ("parkingFee" >= 0);
CREATE INDEX "RoomListing_latitude_longitude_idx" ON "RoomListing"("latitude", "longitude");
CREATE TABLE "SchoolCampus" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "name" TEXT NOT NULL,
  "campus" TEXT NOT NULL,
  "city" TEXT NOT NULL,
  "address" TEXT NOT NULL,
  "latitude" DOUBLE PRECISION NOT NULL CHECK ("latitude" BETWEEN -90 AND 90),
  "longitude" DOUBLE PRECISION NOT NULL CHECK ("longitude" BETWEEN -180 AND 180),
  "isDemo" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE "ListingReport" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "listingId" TEXT NOT NULL REFERENCES "RoomListing"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "reporterId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "reason" TEXT NOT NULL,
  "detail" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'OPEN',
  "reviewNote" TEXT,
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "ListingReport_listingId_reporterId_key" ON "ListingReport"("listingId", "reporterId");
CREATE INDEX "ListingReport_status_createdAt_idx" ON "ListingReport"("status", "createdAt");
