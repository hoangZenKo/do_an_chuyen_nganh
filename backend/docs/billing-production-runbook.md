# Billing production runbook

## Before migration

1. Freeze invoice issuance, payment recording, tariff activation and reminder jobs.
2. Run `npm run ops:backup` and retain the `backupManifest` path from its JSON output. Configure a 32-byte base64 `BACKUP_ENCRYPTION_KEY` outside the repository. Use `ALLOW_RESTORE_CHECK=true npm run ops:restore-check -- <manifest>` with `RESTORE_CHECK_DATABASE` pointing to a separate disposable restore-check database. This drill creates and drops its own target; do not point it at an existing application database.
3. Run `ALLOW_RESTORE_CHECK=true npm run ops:rehearse -- <manifest>` to rehearse the real backup on an isolated clone. Separately, `npm run ops:billing-rehearse` connects to a local PostgreSQL instance and creates its own disposable database for synthetic billing tests. Neither command migrates the source database.
4. Confirm the rehearsal output includes legacy invoice line backfill, `No difference detected`, and green billing E2E tests.
5. Run `npm run ops:preflight` against the target database. Missing release migrations are expected before deploy; checksum drift, failed migrations or unknown applied migrations must be investigated. `ops:readiness` will intentionally fail until all release migrations are applied.

## Deploy

1. Stop old API writers and workers. Stage the new API image; its startup readiness gate should not be bypassed.
2. Set `MIGRATION_CONFIRM_DATABASE` to the exact target database name and run `npm run ops:migrate -- <manifest>` once. The command requires the verified backup from step 2, taken within the last 24 hours; it does not create a backup for you.
3. Run `npm run ops:readiness` again, then start the new API and workers. Run `npm run ops:smoke` using the staging smoke configuration.
   Also run `npm run ops:schema-drift`: exit code 0 means no Prisma-visible drift, 2 means a schema difference. This is read-only and does not repair drift. It does not compare function bodies or all PostgreSQL check constraints, so keep the explicit trigger/readiness checks.
4. Verify one legacy invoice, one replacement invoice, one credit note, one multi-invoice receipt, one refund, one reminder event and one outbox retry in staging.

## Rollback

- Do not edit or delete applied migration rows and do not run `prisma migrate reset`.
- If the API is incompatible, stop writes, disable workers, restore the verified backup to a new database, point the previous API release at it, and run readiness before reopening traffic.
- If only the application release is faulty, roll back the API image first; keep the forward-compatible schema and do not reverse billing data migrations in place.

## Post-deploy checks

- `GET /api/v1/health/ready` returns `database: ok`.
- Invoice line item immutability triggers are present.
- Receipt allocations reconcile: `amount = availableAmount + refundedAmount + active allocations`.
- Every cancelled/replaced/adjusted invoice has an audit event and reason.
- Schema readiness reports no checksum drift and no database migrations newer than the API.

## Staff scope and tariff compatibility

- The staff scope/lifecycle migration backfills existing staff property scopes and pending invite property IDs. Verify the resulting allowlists against the landlord's actual assignments before opening staff access.
- Staff without property scopes see no property-scoped data. Unsupported unscoped modules fail closed. Test both an allowed and an unassigned property with a staff account; a landlord smoke test alone is insufficient.
- Legacy room service-fee creation, update and removal are landlord-only. Staff must use `POST /api/v1/billing/tariffs/proposals`; only the landlord can review/activate. Module permission alone must not bypass this restriction.
- Legacy service-fee versions also reject effective months that affect locked periods and serialize on the same property lock used by invoice issuance and tariff review. Verify this on staging, including a concurrent edit/issue attempt.
- In Flutter, invoice replacement is available only without payment history. Invoices with any payment history must use credit/debit notes; released allocations or reversals do not erase that history.
- Reminder settings are under Reports and follow the selected property. A property's first save creates an override of the landlord default. Saving a policy does not enable workers; configure and acceptance-test external delivery providers separately.

## Reconciliation and maintenance changes

- Statement lines link to exactly one legacy payment or receipt, never both. Allocated payment rows cannot be matched separately; reconcile the receipt instead.
- `MATCH_RECEIPT` proposals use the same maker/checker, optimistic version and audit protections as legacy payment matching. Unmatching never deletes a payment, receipt, refund or allocation.
- A receipt spanning several properties is deliberately excluded from a property statement match. Split/review the ownership of such incoming transfers before reconciling.
- The new proposal target check is added `NOT VALID` to avoid rejecting historical proposals that older code permitted. It is enforced on new writes. Inspect old proposals and validate it separately in staging before `ALTER TABLE "FinanceReconciliationProposal" VALIDATE CONSTRAINT "FinanceReconciliationProposal_target_check"` on production.
- SLA defaults: urgent 4 hours, medium 48 hours, low 168 hours from reported time. A database trigger covers both landlord-created and tenant-created tickets. Changing priority without an explicit deadline recalculates this deadline.
- Set `MAINTENANCE_SLA_WORKER_ENABLED=true` only after readiness passes. The worker marks at most 200 overdue tickets per minute and records each escalation once per deadline. The landlord notification feed also shows overdue tickets without waiting for the worker.
- Deadline extensions are operational changes and stay in the maintenance audit trail. They do not automatically send email or Zalo.
