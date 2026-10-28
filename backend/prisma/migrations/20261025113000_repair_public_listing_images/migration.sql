WITH private_references AS (
  SELECT unnest("proofImageUrls") AS url FROM "PaymentProof"
  UNION ALL SELECT unnest("imageUrls") FROM "MaintenanceTicket"
  UNION ALL SELECT unnest("imageUrls") FROM "MaintenanceComment"
  UNION ALL SELECT "receiptUrl" FROM "Expense" WHERE "receiptUrl" IS NOT NULL
  UNION ALL SELECT unnest("imageUrls") FROM "LeaseHandover"
  UNION ALL SELECT "imageUrl" FROM "RoomAsset" WHERE "imageUrl" IS NOT NULL
), named_listing_files AS (
  SELECT substring(url from '/uploads/([a-zA-Z0-9_-]+\.(?:jpg|jpeg|png|webp|heic|heif))$') AS filename,
    p."landlordId" AS "ownerId"
  FROM "RoomListing" l
  JOIN "Room" r ON r.id = l."roomId"
  JOIN "Property" p ON p.id = r."propertyId"
  CROSS JOIN unnest(l."imageUrls") AS image(url)
  WHERE l.status = 'PUBLISHED'
), listing_files AS (
  SELECT DISTINCT ON (filename) filename, "ownerId"
  FROM named_listing_files
  WHERE filename IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM private_references
      WHERE right(url, length('/uploads/' || filename)) = '/uploads/' || filename
    )
  ORDER BY filename, "ownerId"
)
INSERT INTO "UploadedFile" (filename, "ownerId", "mimeType", purpose)
SELECT filename, "ownerId",
  CASE lower(split_part(filename, '.', 2))
    WHEN 'jpg' THEN 'image/jpeg'
    WHEN 'jpeg' THEN 'image/jpeg'
    ELSE 'image/' || lower(split_part(filename, '.', 2))
  END,
  'PUBLIC_LISTING'
FROM listing_files
ON CONFLICT (filename) DO UPDATE SET purpose = 'PUBLIC_LISTING'
WHERE "UploadedFile"."ownerId" = EXCLUDED."ownerId";

