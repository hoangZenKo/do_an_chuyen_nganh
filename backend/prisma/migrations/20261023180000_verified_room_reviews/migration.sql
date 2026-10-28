CREATE TYPE "RoomReviewStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'HIDDEN');
CREATE TABLE "RoomReview" (
  "id" TEXT NOT NULL PRIMARY KEY,
  "leaseId" TEXT NOT NULL, "roomId" TEXT NOT NULL, "authorId" TEXT NOT NULL, "landlordId" TEXT NOT NULL,
  "roomRating" INTEGER NOT NULL, "costRating" INTEGER NOT NULL, "landlordRating" INTEGER NOT NULL, "areaRating" INTEGER NOT NULL,
  "body" TEXT NOT NULL, "status" "RoomReviewStatus" NOT NULL DEFAULT 'PENDING', "version" INTEGER NOT NULL DEFAULT 1,
  "verificationSource" TEXT NOT NULL, "tenancyVerifiedAt" TIMESTAMP(3) NOT NULL,
  "moderationNote" TEXT, "reviewedById" TEXT, "reviewedAt" TIMESTAMP(3), "withdrawnAt" TIMESTAMP(3),
  "replyBody" TEXT, "replyStatus" "RoomReviewStatus", "replyModerationNote" TEXT, "replyReviewedById" TEXT, "replyReviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "RoomReview_scores_check" CHECK ("roomRating" BETWEEN 1 AND 5 AND "costRating" BETWEEN 1 AND 5 AND "landlordRating" BETWEEN 1 AND 5 AND "areaRating" BETWEEN 1 AND 5),
  CONSTRAINT "RoomReview_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "RoomReview_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "RoomReview_authorId_fkey" FOREIGN KEY ("authorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "RoomReview_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "RoomReview_leaseId_key" ON "RoomReview"("leaseId");
CREATE UNIQUE INDEX "RoomReview_authorId_roomId_landlordId_key" ON "RoomReview"("authorId", "roomId", "landlordId");
CREATE INDEX "RoomReview_roomId_landlordId_status_idx" ON "RoomReview"("roomId", "landlordId", "status");
CREATE INDEX "RoomReview_status_createdAt_idx" ON "RoomReview"("status", "createdAt");
CREATE INDEX "RoomReview_replyStatus_updatedAt_idx" ON "RoomReview"("replyStatus", "updatedAt");
CREATE INDEX "RoomReview_landlordId_createdAt_idx" ON "RoomReview"("landlordId", "createdAt");
