import { Prisma } from '@prisma/client';

export const pendingModerationSql = Prisma.sql`
  SELECT 'LISTING'::text AS kind, id, title, version, "updatedAt" AS "createdAt" FROM "RoomListing" WHERE status = 'PENDING'
  UNION ALL SELECT 'REPORT', id, reason AS title, version, "createdAt" FROM "ListingReport" WHERE status = 'OPEN'
  UNION ALL SELECT 'REVIEW', id, left(body, 160) AS title, version, "updatedAt" AS "createdAt" FROM "RoomReview" WHERE status = 'PENDING' AND "withdrawnAt" IS NULL
  UNION ALL SELECT 'REPLY', id, left("replyBody", 160) AS title, version, "updatedAt" AS "createdAt" FROM "RoomReview" WHERE "replyStatus" = 'PENDING' AND "withdrawnAt" IS NULL`;
