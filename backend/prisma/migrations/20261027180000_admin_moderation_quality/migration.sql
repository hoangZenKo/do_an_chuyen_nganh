CREATE TABLE "ModerationQualityReview" (
  "id" TEXT NOT NULL,
  "decisionId" TEXT NOT NULL,
  "reviewerId" TEXT NOT NULL,
  "outcome" TEXT NOT NULL,
  "reason" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ModerationQualityReview_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ModerationQualityReview_outcome_check" CHECK ("outcome" IN ('AGREE', 'DISAGREE', 'NEEDS_DISCUSSION')),
  CONSTRAINT "ModerationQualityReview_reason_check" CHECK (length(trim("reason")) >= 5),
  CONSTRAINT "ModerationQualityReview_decisionId_fkey" FOREIGN KEY ("decisionId") REFERENCES "ModerationDecision"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "ModerationQualityReview_decisionId_key" ON "ModerationQualityReview"("decisionId");
CREATE INDEX "ModerationQualityReview_createdAt_outcome_idx" ON "ModerationQualityReview"("createdAt", "outcome");
