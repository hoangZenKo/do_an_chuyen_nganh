-- CreateTable
CREATE TYPE "LeaseSettlementStatus" AS ENUM ('CONFIRMED');

CREATE TABLE "LeaseSettlement" (
    "id" TEXT NOT NULL,
    "leaseId" TEXT NOT NULL,
    "landlordId" TEXT NOT NULL,
    "status" "LeaseSettlementStatus" NOT NULL DEFAULT 'CONFIRMED',
    "version" INTEGER NOT NULL DEFAULT 1,
    "moveOutDate" TIMESTAMP(3) NOT NULL,
    "rentAmount" INTEGER NOT NULL,
    "electricityAmount" INTEGER NOT NULL DEFAULT 0,
    "waterAmount" INTEGER NOT NULL DEFAULT 0,
    "otherCharges" INTEGER NOT NULL DEFAULT 0,
    "totalCharges" INTEGER NOT NULL,
    "depositBalance" INTEGER NOT NULL,
    "depositApplied" INTEGER NOT NULL DEFAULT 0,
    "refundAmount" INTEGER NOT NULL DEFAULT 0,
    "refundStatus" TEXT NOT NULL DEFAULT 'NOT_DUE',
    "refundReference" TEXT,
    "refundPaidAt" TIMESTAMP(3),
    "refundRequestKey" TEXT,
    "balanceDue" INTEGER NOT NULL DEFAULT 0,
    "outstandingInvoiceAmount" INTEGER NOT NULL DEFAULT 0,
    "requestKey" TEXT NOT NULL,
    "requestHash" TEXT NOT NULL,
    "previewFingerprint" TEXT NOT NULL,
    "snapshot" JSONB NOT NULL,
    "note" TEXT,
    "confirmedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LeaseSettlement_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "LeaseSettlement_amounts_check" CHECK (
      "rentAmount" >= 0 AND "electricityAmount" >= 0 AND "waterAmount" >= 0 AND "otherCharges" >= 0
      AND "totalCharges"::bigint = "rentAmount"::bigint + "electricityAmount" + "waterAmount" + "otherCharges"
      AND "depositBalance" >= 0 AND "depositApplied" >= 0 AND "refundAmount" >= 0 AND "balanceDue" >= 0
      AND "depositApplied" <= "totalCharges" AND "depositApplied" <= "depositBalance"
      AND "refundAmount"::bigint + "depositApplied" = "depositBalance"
      AND "balanceDue"::bigint + "depositApplied" = "totalCharges" AND "outstandingInvoiceAmount" >= 0
    ),
    CONSTRAINT "LeaseSettlement_refund_check" CHECK (
      ("refundAmount" = 0 AND "refundStatus" = 'NOT_DUE' AND "refundPaidAt" IS NULL)
      OR ("refundAmount" > 0 AND "refundStatus" = 'PENDING' AND "refundPaidAt" IS NULL)
      OR ("refundAmount" > 0 AND "refundStatus" = 'PAID' AND "refundPaidAt" IS NOT NULL AND "refundReference" IS NOT NULL)
    )
);

CREATE TABLE "LeaseSettlementLine" (
    "id" TEXT NOT NULL,
    "settlementId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "LeaseSettlementLine_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "LeaseSettlementLine_amount_check" CHECK ("amount" >= 0)
);

CREATE UNIQUE INDEX "LeaseSettlement_leaseId_key" ON "LeaseSettlement"("leaseId");
CREATE UNIQUE INDEX "LeaseSettlement_landlordId_requestKey_key" ON "LeaseSettlement"("landlordId", "requestKey");
CREATE UNIQUE INDEX "LeaseSettlement_refundRequestKey_key" ON "LeaseSettlement"("refundRequestKey");
CREATE INDEX "LeaseSettlement_landlordId_confirmedAt_idx" ON "LeaseSettlement"("landlordId", "confirmedAt");
CREATE INDEX "LeaseSettlement_status_confirmedAt_idx" ON "LeaseSettlement"("status", "confirmedAt");
CREATE INDEX "LeaseSettlementLine_settlementId_idx" ON "LeaseSettlementLine"("settlementId");

ALTER TABLE "LeaseSettlement" ADD CONSTRAINT "LeaseSettlement_leaseId_fkey"
  FOREIGN KEY ("leaseId") REFERENCES "Lease"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "LeaseSettlement" ADD CONSTRAINT "LeaseSettlement_landlordId_fkey"
  FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "LeaseSettlementLine" ADD CONSTRAINT "LeaseSettlementLine_settlementId_fkey"
  FOREIGN KEY ("settlementId") REFERENCES "LeaseSettlement"("id") ON DELETE CASCADE ON UPDATE CASCADE;
