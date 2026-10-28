-- Versioned tariff history is attached to the existing room service fee.
CREATE TABLE "ServiceTariffVersion" (
    "id" TEXT NOT NULL,
    "serviceFeeId" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL DEFAULT 'thang',
    "amount" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "effectiveFrom" TIMESTAMP(3) NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ServiceTariffVersion_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ServiceTariffVersion_amount_check" CHECK ("amount" >= 0)
);
CREATE TABLE "InvoiceLineItem" (
    "id" TEXT NOT NULL,
    "invoiceId" TEXT NOT NULL,
    "position" INTEGER NOT NULL,
    "kind" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit" TEXT NOT NULL,
    "unitPrice" INTEGER NOT NULL,
    "amount" INTEGER NOT NULL,
    "source" TEXT NOT NULL,
    "sourceId" TEXT,
    "tariffVersionId" TEXT,
    "tariffVersion" INTEGER,
    CONSTRAINT "InvoiceLineItem_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "InvoiceLineItem_amounts_check" CHECK ("quantity" >= 0 AND "unitPrice" >= 0 AND "amount" >= 0 AND "amount"::bigint = "quantity"::bigint * "unitPrice")
);
CREATE UNIQUE INDEX "ServiceTariffVersion_serviceFeeId_version_key" ON "ServiceTariffVersion"("serviceFeeId", "version");
CREATE UNIQUE INDEX "ServiceTariffVersion_serviceFeeId_effectiveFrom_key" ON "ServiceTariffVersion"("serviceFeeId", "effectiveFrom");
CREATE INDEX "InvoiceLineItem_tariffVersionId_idx" ON "InvoiceLineItem"("tariffVersionId");
CREATE UNIQUE INDEX "InvoiceLineItem_invoiceId_position_key" ON "InvoiceLineItem"("invoiceId", "position");
ALTER TABLE "ServiceTariffVersion" ADD CONSTRAINT "ServiceTariffVersion_serviceFeeId_fkey" FOREIGN KEY ("serviceFeeId") REFERENCES "RoomServiceFee"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "InvoiceLineItem" ADD CONSTRAINT "InvoiceLineItem_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "Invoice"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "InvoiceLineItem" ADD CONSTRAINT "InvoiceLineItem_tariffVersionId_fkey" FOREIGN KEY ("tariffVersionId") REFERENCES "ServiceTariffVersion"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Historical tariff prices cannot be reconstructed. Preserve the last known state as a baseline.
INSERT INTO "ServiceTariffVersion" ("id", "serviceFeeId", "version", "name", "amount", "isActive", "effectiveFrom", "note")
SELECT 'baseline:' || "id", "id", 1, "name", "amount", "isActive", TIMESTAMP '1970-01-01', "note"
FROM "RoomServiceFee";

-- Do not infer tariff provenance or utility quantities from mutable current data.
INSERT INTO "InvoiceLineItem" ("id", "invoiceId", "position", "kind", "description", "quantity", "unit", "unitPrice", "amount", "source")
SELECT 'legacy:' || invoice."id" || ':' || lines.position, invoice."id", lines.position, lines.kind, lines.description, 1, 'lan', lines.amount, lines.amount, 'LEGACY'
FROM "Invoice" invoice
CROSS JOIN LATERAL (VALUES
  (0, 'RENT', 'Tiền phòng', invoice."rentAmount"),
  (1, 'ELECTRICITY', 'Tiền điện', invoice."electricityAmount"),
  (2, 'WATER', 'Tiền nước', invoice."waterAmount"),
  (3, 'OTHER', 'Phí khác (dữ liệu cũ)', invoice."otherAmount")
) AS lines(position, kind, description, amount)
WHERE lines.amount <> 0;

CREATE FUNCTION reject_billing_snapshot_update() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Billing snapshots are immutable; create a new tariff version or cancel/reissue the invoice.';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER "ServiceTariffVersion_immutable" BEFORE UPDATE ON "ServiceTariffVersion"
FOR EACH ROW EXECUTE FUNCTION reject_billing_snapshot_update();
CREATE TRIGGER "InvoiceLineItem_immutable" BEFORE UPDATE ON "InvoiceLineItem"
FOR EACH ROW EXECUTE FUNCTION reject_billing_snapshot_update();
