-- Billing production controls: immutable corrections, allocation ledger, reminders and outbox.
ALTER TABLE "Invoice" ADD COLUMN "revision" INTEGER NOT NULL DEFAULT 1;
ALTER TABLE "Invoice" ADD COLUMN "replacesInvoiceId" TEXT;
DROP INDEX IF EXISTS "Invoice_leaseId_billingMonth_isDemo_key";
CREATE UNIQUE INDEX "Invoice_leaseId_billingMonth_isDemo_revision_key" ON "Invoice"("leaseId", "billingMonth", "isDemo", "revision");
CREATE UNIQUE INDEX "Invoice_replacesInvoiceId_key" ON "Invoice"("replacesInvoiceId");
ALTER TABLE "Invoice" ADD CONSTRAINT "Invoice_replacesInvoiceId_fkey" FOREIGN KEY ("replacesInvoiceId") REFERENCES "Invoice"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "BillingCommand" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "requestKey" TEXT NOT NULL,
  "requestHash" TEXT NOT NULL,
  "response" JSONB NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingCommand_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingCommand_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "BillingCommand_landlordId_requestKey_key" ON "BillingCommand"("landlordId", "requestKey");

CREATE TABLE "InvoiceAdjustment" (
  "id" TEXT NOT NULL,
  "invoiceId" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "category" TEXT NOT NULL,
  "amount" INTEGER NOT NULL,
  "reason" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "lineId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "InvoiceAdjustment_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "InvoiceAdjustment_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "InvoiceAdjustment_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "InvoiceAdjustment_lineId_key" ON "InvoiceAdjustment"("lineId");
CREATE INDEX "InvoiceAdjustment_invoiceId_createdAt_idx" ON "InvoiceAdjustment"("invoiceId", "createdAt");

CREATE TABLE "BillingReceipt" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "amount" INTEGER NOT NULL,
  "availableAmount" INTEGER NOT NULL,
  "refundedAmount" INTEGER NOT NULL DEFAULT 0,
  "method" "PaymentMethod" NOT NULL,
  "reference" TEXT NOT NULL,
  "paidAt" TIMESTAMP(3) NOT NULL,
  "actorId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingReceipt_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingReceipt_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "BillingReceipt_availableAmount_check" CHECK ("availableAmount" >= 0),
  CONSTRAINT "BillingReceipt_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "BillingReceipt_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "BillingReceipt_landlordId_tenantId_paidAt_idx" ON "BillingReceipt"("landlordId", "tenantId", "paidAt");

CREATE TABLE "PaymentAllocation" (
  "id" TEXT NOT NULL,
  "receiptId" TEXT NOT NULL,
  "paymentId" TEXT NOT NULL,
  "amount" INTEGER NOT NULL,
  "releasedAt" TIMESTAMP(3),
  "releaseReason" TEXT,
  "releasedBy" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PaymentAllocation_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "PaymentAllocation_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "PaymentAllocation_receiptId_fkey" FOREIGN KEY ("receiptId") REFERENCES "BillingReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "PaymentAllocation_paymentId_fkey" FOREIGN KEY ("paymentId") REFERENCES "Payment"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "PaymentAllocation_paymentId_key" ON "PaymentAllocation"("paymentId");
CREATE INDEX "PaymentAllocation_receiptId_releasedAt_idx" ON "PaymentAllocation"("receiptId", "releasedAt");

CREATE TABLE "BillingRefund" (
  "id" TEXT NOT NULL,
  "receiptId" TEXT NOT NULL,
  "amount" INTEGER NOT NULL,
  "reason" TEXT NOT NULL,
  "reference" TEXT NOT NULL,
  "actorId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingRefund_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingRefund_amount_check" CHECK ("amount" > 0),
  CONSTRAINT "BillingRefund_receiptId_fkey" FOREIGN KEY ("receiptId") REFERENCES "BillingReceipt"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "BillingRefund_receiptId_createdAt_idx" ON "BillingRefund"("receiptId", "createdAt");

CREATE TABLE "BillingReminderPolicy" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "scopeKey" TEXT NOT NULL,
  "propertyId" TEXT,
  "enabled" BOOLEAN NOT NULL DEFAULT false,
  "beforeDays" INTEGER[] NOT NULL DEFAULT ARRAY[3, 1]::INTEGER[],
  "onDueDate" BOOLEAN NOT NULL DEFAULT true,
  "overdueDays" INTEGER[] NOT NULL DEFAULT ARRAY[1, 7, 30]::INTEGER[],
  "channels" TEXT[] NOT NULL DEFAULT ARRAY['APP']::TEXT[],
  "version" INTEGER NOT NULL DEFAULT 1,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "BillingReminderPolicy_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingReminderPolicy_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "BillingReminderPolicy_propertyId_fkey" FOREIGN KEY ("propertyId") REFERENCES "Property"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "BillingReminderPolicy_scopeKey_key" ON "BillingReminderPolicy"("scopeKey");
CREATE INDEX "BillingReminderPolicy_landlordId_idx" ON "BillingReminderPolicy"("landlordId");

CREATE TABLE "BillingOutboxEvent" (
  "id" TEXT NOT NULL,
  "landlordId" TEXT NOT NULL,
  "eventKey" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "resourceId" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "availableAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "leaseOwner" TEXT,
  "leaseUntil" TIMESTAMP(3),
  "lastError" TEXT,
  "completedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingOutboxEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingOutboxEvent_landlordId_fkey" FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "BillingOutboxEvent_eventKey_key" ON "BillingOutboxEvent"("eventKey");
CREATE INDEX "BillingOutboxEvent_status_availableAt_idx" ON "BillingOutboxEvent"("status", "availableAt");
CREATE INDEX "BillingOutboxEvent_landlordId_createdAt_idx" ON "BillingOutboxEvent"("landlordId", "createdAt");

CREATE TABLE "BillingNotification" (
  "id" TEXT NOT NULL,
  "tenantId" TEXT NOT NULL,
  "invoiceId" TEXT NOT NULL,
  "eventKey" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "readAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingNotification_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingNotification_eventKey_key" UNIQUE ("eventKey"),
  CONSTRAINT "BillingNotification_tenantId_fkey" FOREIGN KEY ("tenantId") REFERENCES "Tenant"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "BillingNotification_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "BillingNotification_tenantId_createdAt_idx" ON "BillingNotification"("tenantId", "createdAt");

ALTER TABLE "InvoiceLineItem" DROP CONSTRAINT "InvoiceLineItem_amounts_check";
ALTER TABLE "InvoiceLineItem" ADD CONSTRAINT "InvoiceLineItem_amounts_check" CHECK (
  "quantity" >= 0 AND "amount"::bigint = "quantity"::bigint * "unitPrice" AND
  (("amount" >= 0 AND "unitPrice" >= 0) OR ("kind" IN ('CREDIT_NOTE', 'DISCOUNT') AND "amount" <= 0 AND "unitPrice" <= 0))
);
ALTER TABLE "BillingReceipt" ADD CONSTRAINT "BillingReceipt_conservation_check" CHECK (
  "refundedAmount" >= 0 AND "availableAmount"::bigint + "refundedAmount" <= "amount"
);

CREATE TABLE "BillingTariffVersion" (
  "id" TEXT NOT NULL, "landlordId" TEXT NOT NULL, "propertyId" TEXT NOT NULL, "roomId" TEXT,
  "scopeKey" TEXT NOT NULL, "serviceKey" TEXT NOT NULL, "name" TEXT NOT NULL, "kind" TEXT NOT NULL,
  "unit" TEXT NOT NULL, "amount" INTEGER NOT NULL, "tiers" JSONB NOT NULL, "effectiveFrom" TIMESTAMP(3) NOT NULL,
  "version" INTEGER NOT NULL, "state" TEXT NOT NULL DEFAULT 'PROPOSED', "isActive" BOOLEAN NOT NULL DEFAULT true,
  "makerId" TEXT NOT NULL, "checkerId" TEXT, "reason" TEXT NOT NULL, "reviewReason" TEXT,
  "reviewedAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingTariffVersion_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "BillingTariffVersion_amount_check" CHECK ("amount" >= 0 AND "version" > 0),
  CONSTRAINT "BillingTariffVersion_state_check" CHECK ("state" IN ('PROPOSED', 'APPROVED', 'REJECTED'))
);
CREATE UNIQUE INDEX "BillingTariffVersion_scopeKey_serviceKey_version_key" ON "BillingTariffVersion"("scopeKey", "serviceKey", "version");
CREATE INDEX "BillingTariffVersion_propertyId_state_effectiveFrom_idx" ON "BillingTariffVersion"("propertyId", "state", "effectiveFrom");
CREATE INDEX "BillingTariffVersion_roomId_state_effectiveFrom_idx" ON "BillingTariffVersion"("roomId", "state", "effectiveFrom");
CREATE UNIQUE INDEX "BillingTariffVersion_approved_period_key" ON "BillingTariffVersion"("scopeKey", "serviceKey", "effectiveFrom") WHERE "state" = 'APPROVED';
CREATE TABLE "BillingPeriodLock" (
  "id" TEXT NOT NULL, "propertyId" TEXT NOT NULL, "month" TIMESTAMP(3) NOT NULL, "reason" TEXT NOT NULL,
  "actorId" TEXT NOT NULL, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "BillingPeriodLock_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "BillingPeriodLock_propertyId_month_key" ON "BillingPeriodLock"("propertyId", "month");

CREATE FUNCTION protect_billing_tariff_snapshot() RETURNS trigger AS $$
BEGIN
  IF OLD."state" <> 'PROPOSED' OR NEW."state" NOT IN ('APPROVED', 'REJECTED') OR
    (to_jsonb(NEW) - ARRAY['state','checkerId','reviewReason','reviewedAt']) IS DISTINCT FROM
    (to_jsonb(OLD) - ARRAY['state','checkerId','reviewReason','reviewedAt']) THEN
    RAISE EXCEPTION 'Tariff versions are immutable; only a pending proposal may be reviewed.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "BillingTariffVersion_immutable" BEFORE UPDATE ON "BillingTariffVersion"
FOR EACH ROW EXECUTE FUNCTION protect_billing_tariff_snapshot();
CREATE TRIGGER "InvoiceAdjustment_immutable" BEFORE UPDATE ON "InvoiceAdjustment"
FOR EACH ROW EXECUTE FUNCTION reject_billing_snapshot_update();
CREATE TRIGGER "BillingRefund_immutable" BEFORE UPDATE ON "BillingRefund"
FOR EACH ROW EXECUTE FUNCTION reject_billing_snapshot_update();

CREATE FUNCTION emit_billing_outbox() RETURNS trigger AS $$
DECLARE owner_id TEXT;
DECLARE event_type TEXT;
BEGIN
  IF TG_TABLE_NAME = 'Invoice' THEN
    IF NEW."isDemo" THEN RETURN NEW; END IF;
    SELECT p."landlordId" INTO owner_id FROM "Room" r JOIN "Property" p ON p.id = r."propertyId" WHERE r.id = NEW."roomId";
    event_type := 'invoice.created';
  ELSIF TG_TABLE_NAME = 'Payment' THEN
    SELECT p."landlordId" INTO owner_id FROM "Invoice" i JOIN "Room" r ON r.id = i."roomId" JOIN "Property" p ON p.id = r."propertyId" WHERE i.id = NEW."invoiceId" AND NOT i."isDemo";
    event_type := 'payment.created';
  ELSE
    SELECT p."landlordId" INTO owner_id FROM "RoomServiceFee" f JOIN "Room" r ON r.id = f."roomId" JOIN "Property" p ON p.id = r."propertyId" WHERE f.id = NEW."serviceFeeId";
    event_type := 'tariff.created';
  END IF;
  IF owner_id IS NOT NULL THEN
    INSERT INTO "BillingOutboxEvent" (id, "landlordId", "eventKey", type, "resourceId", payload)
    VALUES ('event:' || event_type || ':' || NEW.id, owner_id, event_type || ':' || NEW.id, event_type, NEW.id, jsonb_build_object('id', NEW.id));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "Invoice_outbox" AFTER INSERT ON "Invoice" FOR EACH ROW EXECUTE FUNCTION emit_billing_outbox();
CREATE TRIGGER "Payment_outbox" AFTER INSERT ON "Payment" FOR EACH ROW EXECUTE FUNCTION emit_billing_outbox();
CREATE TRIGGER "ServiceTariffVersion_outbox" AFTER INSERT ON "ServiceTariffVersion" FOR EACH ROW EXECUTE FUNCTION emit_billing_outbox();
