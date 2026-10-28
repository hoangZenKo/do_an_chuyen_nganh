CREATE TABLE "BillingAutomation" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "propertyId" TEXT NOT NULL,
  "isEnabled" BOOLEAN NOT NULL DEFAULT false,
  "invoiceDay" INTEGER NOT NULL DEFAULT 1,
  "dueDay" INTEGER NOT NULL DEFAULT 10,
  "lastRunMonth" TIMESTAMP(3),
  "lastRunAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "BillingAutomation_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "BillingAutomation_propertyId_key" ON "BillingAutomation"("propertyId");
CREATE INDEX "BillingAutomation_landlordId_idx" ON "BillingAutomation"("landlordId");
CREATE INDEX "BillingAutomation_isEnabled_idx" ON "BillingAutomation"("isEnabled");
CREATE INDEX "BillingAutomation_lastRunMonth_idx" ON "BillingAutomation"("lastRunMonth");

ALTER TABLE "BillingAutomation" ADD CONSTRAINT "BillingAutomation_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "BillingAutomation" ADD CONSTRAINT "BillingAutomation_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE;
