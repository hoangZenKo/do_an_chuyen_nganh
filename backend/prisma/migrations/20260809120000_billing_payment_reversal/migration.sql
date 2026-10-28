-- CreateEnum
CREATE TYPE "PaymentType" AS ENUM ('PAYMENT', 'REVERSAL');

-- AlterTable
ALTER TABLE "Invoice"
ADD COLUMN "cancelledAt" TIMESTAMP(3),
ADD COLUMN "cancelledNote" TEXT;

-- AlterTable
ALTER TABLE "Payment"
ADD COLUMN "type" "PaymentType" NOT NULL DEFAULT 'PAYMENT',
ADD COLUMN "reversalOfPaymentId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "Payment_reversalOfPaymentId_key" ON "Payment"("reversalOfPaymentId");

-- CreateIndex
CREATE INDEX "Payment_type_idx" ON "Payment"("type");

-- AddForeignKey
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_reversalOfPaymentId_fkey" FOREIGN KEY ("reversalOfPaymentId") REFERENCES "Payment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Add guardrails for invoice balances and signed payment ledger entries.
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_totalAmount_nonnegative_check" CHECK ("totalAmount" >= 0);
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_paidAmount_nonnegative_check" CHECK ("paidAmount" >= 0);
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_paidAmount_not_over_total_check" CHECK ("paidAmount" <= "totalAmount");
ALTER TABLE "Payment" ADD CONSTRAINT "Payment_type_amount_reversal_check" CHECK (
  (
    "type" = 'PAYMENT'
    AND "amount" > 0
    AND "reversalOfPaymentId" IS NULL
  )
  OR
  (
    "type" = 'REVERSAL'
    AND "amount" < 0
    AND "reversalOfPaymentId" IS NOT NULL
  )
);
