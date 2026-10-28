-- CreateEnum
CREATE TYPE "DepositTransactionType" AS ENUM ('COLLECTED', 'REFUNDED', 'DEDUCTED', 'ADJUSTMENT');

-- CreateTable
CREATE TABLE "DepositTransaction" (
    "id" TEXT NOT NULL,
    "leaseId" TEXT NOT NULL,
    "landlordId" TEXT NOT NULL,
    "type" "DepositTransactionType" NOT NULL,
    "amount" INTEGER NOT NULL,
    "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DepositTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LeaseChange" (
    "id" TEXT NOT NULL,
    "leaseId" TEXT NOT NULL,
    "landlordId" TEXT NOT NULL,
    "changeType" TEXT NOT NULL,
    "previousValues" JSONB NOT NULL,
    "newValues" JSONB NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeaseChange_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DepositTransaction_leaseId_idx" ON "DepositTransaction"("leaseId");

-- CreateIndex
CREATE INDEX "DepositTransaction_landlordId_idx" ON "DepositTransaction"("landlordId");

-- CreateIndex
CREATE INDEX "DepositTransaction_type_idx" ON "DepositTransaction"("type");

-- CreateIndex
CREATE INDEX "DepositTransaction_occurredAt_idx" ON "DepositTransaction"("occurredAt");

-- CreateIndex
CREATE INDEX "LeaseChange_leaseId_idx" ON "LeaseChange"("leaseId");

-- CreateIndex
CREATE INDEX "LeaseChange_landlordId_idx" ON "LeaseChange"("landlordId");

-- CreateIndex
CREATE INDEX "LeaseChange_createdAt_idx" ON "LeaseChange"("createdAt");

-- AddForeignKey
ALTER TABLE "DepositTransaction" ADD CONSTRAINT "DepositTransaction_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DepositTransaction" ADD CONSTRAINT "DepositTransaction_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LeaseChange" ADD CONSTRAINT "LeaseChange_leaseId_fkey" FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE CASCADE ON UPDATE CASCADE;
