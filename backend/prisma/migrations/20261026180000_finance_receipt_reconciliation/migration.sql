ALTER TABLE "FinanceStatementLine" ADD COLUMN "receiptId" TEXT;
ALTER TABLE "FinanceReconciliationProposal" ADD COLUMN "receiptId" TEXT;
CREATE UNIQUE INDEX "FinanceStatementLine_receiptId_key" ON "FinanceStatementLine"("receiptId");
ALTER TABLE "FinanceStatementLine" ADD CONSTRAINT "FinanceStatementLine_receiptId_fkey"
  FOREIGN KEY ("receiptId") REFERENCES "BillingReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "FinanceStatementLine" ADD CONSTRAINT "FinanceStatementLine_single_target_check"
  CHECK (NOT ("paymentId" IS NOT NULL AND "receiptId" IS NOT NULL));
ALTER TABLE "FinanceReconciliationProposal" ADD CONSTRAINT "FinanceReconciliationProposal_target_check"
  CHECK (
    ("action" = 'MATCH_PAYMENT' AND "paymentId" IS NOT NULL AND "receiptId" IS NULL) OR
    ("action" = 'MATCH_RECEIPT' AND "receiptId" IS NOT NULL AND "paymentId" IS NULL) OR
    ("action" IN ('MARK_REVIEWED', 'UNMATCH') AND "paymentId" IS NULL AND "receiptId" IS NULL)
  ) NOT VALID;
