CREATE TYPE "ListingStatus" AS ENUM ('DRAFT', 'PENDING', 'PUBLISHED', 'REJECTED', 'HIDDEN');

CREATE TABLE "RoomListing" (
  "id" TEXT NOT NULL,
  "roomId" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "imageUrls" TEXT[] NOT NULL,
  "city" TEXT NOT NULL,
  "district" TEXT NOT NULL,
  "publicAddress" TEXT NOT NULL,
  "monthlyRent" INTEGER NOT NULL,
  "deposit" INTEGER NOT NULL DEFAULT 0,
  "electricityPrice" INTEGER NOT NULL DEFAULT 0,
  "waterPrice" INTEGER NOT NULL DEFAULT 0,
  "serviceFee" INTEGER NOT NULL DEFAULT 0,
  "areaSqm" DOUBLE PRECISION NOT NULL,
  "amenities" TEXT[] NOT NULL,
  "status" "ListingStatus" NOT NULL DEFAULT 'DRAFT',
  "version" INTEGER NOT NULL DEFAULT 1,
  "reviewNote" TEXT,
  "publishedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RoomListing_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "RoomListing_amounts_check" CHECK (
    "monthlyRent" > 0 AND "deposit" >= 0 AND "electricityPrice" >= 0
    AND "waterPrice" >= 0 AND "serviceFee" >= 0 AND "areaSqm" > 0
  )
);
CREATE UNIQUE INDEX "RoomListing_roomId_key" ON "RoomListing"("roomId");
CREATE INDEX "RoomListing_status_publishedAt_id_idx" ON "RoomListing"("status", "publishedAt", "id");
CREATE INDEX "RoomListing_city_district_monthlyRent_idx" ON "RoomListing"("city", "district", "monthlyRent");
ALTER TABLE "RoomListing" ADD CONSTRAINT "RoomListing_roomId_fkey"
  FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
