CREATE TYPE "PaymentProvider" AS ENUM ('DEMO_CARD', 'LEGACY_BANK_TRANSFER');
CREATE TYPE "DemoCheckoutStatus" AS ENUM ('PENDING', 'PAID', 'EXPIRED', 'CANCELLED');
ALTER TABLE "Invoice" ADD COLUMN "isDemo" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "PaymentLink"
  ADD COLUMN "provider" "PaymentProvider" NOT NULL DEFAULT 'LEGACY_BANK_TRANSFER';
ALTER TABLE "PaymentLink" ALTER COLUMN "provider" SET DEFAULT 'DEMO_CARD';
UPDATE "PaymentLink" SET "status" = 'CANCELLED' WHERE "status" = 'PENDING';

CREATE TABLE "DemoCheckoutSession" (
  "id" TEXT NOT NULL,
  "paymentLinkId" TEXT NOT NULL,
  "tokenHash" TEXT NOT NULL,
  "status" "DemoCheckoutStatus" NOT NULL DEFAULT 'PENDING',
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "completedAt" TIMESTAMP(3),
  "cardBrand" TEXT,
  "cardLast4" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "DemoCheckoutSession_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DemoCheckoutSession_paymentLinkId_key" ON "DemoCheckoutSession"("paymentLinkId");
CREATE UNIQUE INDEX "DemoCheckoutSession_tokenHash_key" ON "DemoCheckoutSession"("tokenHash");
CREATE INDEX "DemoCheckoutSession_expiresAt_status_idx" ON "DemoCheckoutSession"("expiresAt", "status");

ALTER TABLE "DemoCheckoutSession"
  ADD CONSTRAINT "DemoCheckoutSession_paymentLinkId_fkey"
  FOREIGN KEY ("paymentLinkId") REFERENCES "PaymentLink"("id") ON DELETE CASCADE ON UPDATE CASCADE;
