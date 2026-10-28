ALTER TABLE "OperationsIncident"
  DROP CONSTRAINT "OperationsIncident_status_check",
  ADD CONSTRAINT "OperationsIncident_status_check"
    CHECK ("status" IN ('OPEN', 'ACKNOWLEDGED', 'SNOOZED', 'RESOLVED'));

UPDATE "OperationsIncident"
  SET "conditionActive" = false
  WHERE "status" = 'RESOLVED' AND "conditionActive" = true;
