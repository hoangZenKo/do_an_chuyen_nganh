ALTER TABLE "PaymentProof" ADD COLUMN "requestKey" TEXT, ADD COLUMN "requestHash" TEXT;
CREATE UNIQUE INDEX "PaymentProof_requestKey_key" ON "PaymentProof"("requestKey");
