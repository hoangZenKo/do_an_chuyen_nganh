CREATE UNIQUE INDEX "Invoice_leaseId_billingMonth_isDemo_key" ON "Invoice"("leaseId", "billingMonth", "isDemo");
DROP INDEX "Invoice_leaseId_billingMonth_key";
