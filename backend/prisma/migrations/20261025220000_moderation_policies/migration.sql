-- AlterTable
ALTER TABLE "ModerationDecision" ADD COLUMN     "evidence" JSONB,
ADD COLUMN     "policyId" TEXT;

-- CreateTable
CREATE TABLE "ModerationPolicy" (
    "id" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'DRAFT',
    "createdById" TEXT NOT NULL,
    "activatedById" TEXT,
    "activatedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ModerationPolicy_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ModerationPolicy_kind_status_idx" ON "ModerationPolicy"("kind", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ModerationPolicy_kind_version_key" ON "ModerationPolicy"("kind", "version");

-- AddForeignKey
ALTER TABLE "ModerationDecision" ADD CONSTRAINT "ModerationDecision_policyId_fkey" FOREIGN KEY ("policyId") REFERENCES "ModerationPolicy"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

