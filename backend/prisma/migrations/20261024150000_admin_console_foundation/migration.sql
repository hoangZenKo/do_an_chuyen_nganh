CREATE TABLE "AdminProfile" (
  "userId" TEXT NOT NULL,
  "preset" TEXT NOT NULL,
  "permissions" TEXT[] NOT NULL,
  "mfaSecret" TEXT,
  "mfaEnabled" BOOLEAN NOT NULL DEFAULT false,
  "mfaLastCounter" BIGINT NOT NULL DEFAULT -1,
  "recoveryHashes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "AdminProfile_pkey" PRIMARY KEY ("userId")
);
CREATE TABLE "AccountAccessToken" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "tokenHash" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "consumedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AccountAccessToken_pkey" PRIMARY KEY ("id")
);
CREATE TABLE "ModerationWorkItem" (
  "id" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "targetId" TEXT NOT NULL,
  "assigneeId" TEXT,
  "priority" TEXT NOT NULL DEFAULT 'NORMAL',
  "dueAt" TIMESTAMP(3) NOT NULL,
  "note" TEXT NOT NULL DEFAULT '',
  "version" INTEGER NOT NULL DEFAULT 1,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ModerationWorkItem_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "RefreshToken" ADD COLUMN "mfaVerified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "AdminProfile" ADD CONSTRAINT "AdminProfile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "AccountAccessToken" ADD CONSTRAINT "AccountAccessToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE UNIQUE INDEX "AccountAccessToken_tokenHash_key" ON "AccountAccessToken"("tokenHash");
CREATE INDEX "AccountAccessToken_userId_purpose_idx" ON "AccountAccessToken"("userId", "purpose");
CREATE INDEX "AccountAccessToken_expiresAt_idx" ON "AccountAccessToken"("expiresAt");
CREATE UNIQUE INDEX "ModerationWorkItem_kind_targetId_key" ON "ModerationWorkItem"("kind", "targetId");
CREATE INDEX "ModerationWorkItem_assigneeId_dueAt_idx" ON "ModerationWorkItem"("assigneeId", "dueAt");
