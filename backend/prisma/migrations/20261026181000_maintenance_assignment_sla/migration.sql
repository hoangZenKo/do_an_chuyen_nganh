ALTER TABLE "MaintenanceTicket" ADD COLUMN "assigneeStaffProfileId" TEXT;
ALTER TABLE "MaintenanceTicket" ADD COLUMN "dueAt" TIMESTAMP(3);
ALTER TABLE "MaintenanceTicket" ADD COLUMN "escalatedAt" TIMESTAMP(3);
ALTER TABLE "MaintenanceTicket" ADD CONSTRAINT "MaintenanceTicket_assigneeStaffProfileId_fkey"
  FOREIGN KEY ("assigneeStaffProfileId") REFERENCES "StaffProfile"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "MaintenanceTicket_assigneeStaffProfileId_status_dueAt_idx"
  ON "MaintenanceTicket"("assigneeStaffProfileId", "status", "dueAt");

UPDATE "MaintenanceTicket" SET "dueAt" = "reportedAt" +
  CASE "priority" WHEN 'URGENT' THEN INTERVAL '4 hours' WHEN 'LOW' THEN INTERVAL '168 hours' ELSE INTERVAL '48 hours' END;

CREATE FUNCTION maintenance_sla_deadline() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW."dueAt" IS NULL THEN
    NEW."dueAt" := NEW."reportedAt" + CASE NEW."priority"
      WHEN 'URGENT' THEN INTERVAL '4 hours' WHEN 'LOW' THEN INTERVAL '168 hours' ELSE INTERVAL '48 hours' END;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW."dueAt" IS DISTINCT FROM OLD."dueAt" THEN
    NEW."escalatedAt" := NULL;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER maintenance_sla_deadline_trigger BEFORE INSERT OR UPDATE ON "MaintenanceTicket"
  FOR EACH ROW EXECUTE FUNCTION maintenance_sla_deadline();
