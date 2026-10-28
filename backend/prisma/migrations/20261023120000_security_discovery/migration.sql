ALTER TABLE "User" ADD COLUMN "sessionVersion" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "SchoolCampus" ADD COLUMN "isActive" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "sourceUrl" TEXT, ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
CREATE TABLE "UploadedFile" (
 "filename" TEXT PRIMARY KEY, "ownerId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
 "mimeType" TEXT NOT NULL, "purpose" TEXT NOT NULL DEFAULT 'PRIVATE', "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "UploadedFile_ownerId_idx" ON "UploadedFile"("ownerId");
CREATE TABLE "SavedSearch" (
 "id" TEXT PRIMARY KEY, "userId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
 "name" TEXT NOT NULL, "filters" JSONB NOT NULL, "enabled" BOOLEAN NOT NULL DEFAULT true,
 "checkedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "SavedSearch_userId_createdAt_idx" ON "SavedSearch"("userId", "createdAt");
CREATE TABLE "SavedSearchMatch" (
 "id" TEXT PRIMARY KEY,
 "savedSearchId" TEXT NOT NULL REFERENCES "SavedSearch"("id") ON DELETE CASCADE ON UPDATE CASCADE,
 "listingId" TEXT NOT NULL REFERENCES "RoomListing"("id") ON DELETE CASCADE ON UPDATE CASCADE,
 "readAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "SavedSearchMatch_savedSearchId_listingId_key" ON "SavedSearchMatch"("savedSearchId", "listingId");
WITH references_to_files AS (
 SELECT url, COALESCE(t."userId", t."landlordId") AS owner, 'PRIVATE' AS purpose
 FROM "PaymentProof" p JOIN "Tenant" t ON t.id = p."tenantId", unnest(p."proofImageUrls") url
 UNION ALL SELECT url, "authorId", 'PRIVATE' FROM "MaintenanceComment", unnest("imageUrls") url
 UNION ALL SELECT url, "landlordId", 'PRIVATE' FROM "MaintenanceTicket", unnest("imageUrls") url
 UNION ALL SELECT "receiptUrl", "landlordId", 'PRIVATE' FROM "Expense" WHERE "receiptUrl" IS NOT NULL
 UNION ALL SELECT r."imageUrl", p."landlordId", 'PRIVATE' FROM "Room" r JOIN "Property" p ON p.id = r."propertyId" WHERE r."imageUrl" IS NOT NULL
 UNION ALL SELECT a."imageUrl", p."landlordId", 'PRIVATE' FROM "RoomAsset" a JOIN "Room" r ON r.id = a."roomId" JOIN "Property" p ON p.id = r."propertyId" WHERE a."imageUrl" IS NOT NULL
 UNION ALL SELECT url, p."landlordId", 'PUBLIC_LISTING' FROM "RoomListing" l JOIN "Room" r ON r.id = l."roomId" JOIN "Property" p ON p.id = r."propertyId", unnest(l."imageUrls") url
), named AS (
 SELECT substring(url from '/uploads/([a-zA-Z0-9_-]+\.(?:jpg|jpeg|png|webp|heic|heif|pdf))$') AS filename, owner, purpose FROM references_to_files
)
INSERT INTO "UploadedFile" (filename, "ownerId", "mimeType", purpose)
SELECT DISTINCT ON (filename) filename, owner,
 CASE lower(split_part(filename, '.', 2)) WHEN 'pdf' THEN 'application/pdf' WHEN 'jpg' THEN 'image/jpeg' WHEN 'jpeg' THEN 'image/jpeg' ELSE 'image/' || lower(split_part(filename, '.', 2)) END,
 purpose FROM named WHERE filename IS NOT NULL AND owner IS NOT NULL ORDER BY filename, purpose, owner;
