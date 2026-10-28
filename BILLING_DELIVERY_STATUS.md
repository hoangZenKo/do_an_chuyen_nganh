# Billing and operations delivery status

Verified locally on 2026-10-26. This is an implementation inventory, not production deployment approval. The existing application database has not been migrated by this work.

Tariff UI follow-up verified locally on 2026-10-27; exact new-change evidence and remaining acceptance are in `docs/app-functional-delivery-status.md`.

## Coverage against the requested backlog

| # | Capability | Implemented | Remaining before full acceptance |
| --- | --- | --- | --- |
| 1 | Invoice correction / credit and debit notes | Required cancellation reason; immutable original lines; replacement revisions and links; adjustment lines; transactional audit; Flutter cancellation, replacement editor and adjustment actions | Production user acceptance |
| 2 | Payment allocation and receivables | Receipt ledger, multi-invoice allocation, partial/overpayment, release/reversal, unallocated-credit refunds, idempotency; Flutter receipt workbench from invoice detail | Paginated receipt browsing beyond the latest 200; complete migration strategy for legacy payments |
| 3 | Aging | Business-day buckets, tenant/property/room grouping, outstanding totals, Flutter aging view | Historical as-of reporting and export beyond current balances |
| 4 | Reminder policy | Landlord/property policy, before/on/after due date, event-key deduplication, app notifications, EMAIL/ZALO webhook adapters, retries, tenant channel preferences, Flutter settings UI with inherited property scope | Real provider configuration and staging delivery tests |
| 5 | Production billing migration | Backup/restore tooling, disposable billing rehearsal, legacy snapshot preservation check, schema diff command, migration checksum/readiness gates, rollback runbook | Rehearsal from a real production backup on staging, operational signoff and actual deployment |
| 6 | Property service tariffs | Property defaults, room overrides and legacy fallback in invoice pricing; landlord/staff workbench with proposal history/search/filter | Production/device user acceptance |
| 7 | Utility tariff versions | Effective-month versions, electricity/water, progressive tiers, shared preview/issue pricing; property/room utility editor with tier comparison | Production/device user acceptance |
| 8 | Discounts / surcharges | Fixed or basis-point adjustment notes, discount/surcharge invoice lines, permission checks and audit, Flutter category and percentage controls | Automated scheduled late-fee assessment and dedicated waiver settings |
| 9 | Tariff approval | Proposal/review API, impacted rooms, immutable approved versions, locked/issued-period safeguards; staff cannot bypass approval via legacy room fee writes; legacy versions share the property lock with issuance/period closing; landlord-only old/new comparison and approve/reject UI with reasons | Production/device user acceptance |
| 10 | Maintenance assignment / SLA | Property-scoped active staff assignment, default SLA (4h/48h/168h), custom deadline, once-per-deadline escalation worker/audit, landlord overdue notifications, costs and linked repair expense; concurrent completion creates one expense; Flutter assignment/deadline controls | Live notification acceptance and configurable SLA policies |
| 11 | Staff property scope | Prisma scope storage, staff invite/update assignment, JWT scope claims, request interceptor enforcement, scoped module queries/actions, scope-change audit and permission simulator; Flutter scope/simulator screen | Review any newly added endpoint when expanding the API; production acceptance |
| 12 | Tenant lifecycle | Renewal/transfer/checkout request workflow, tenant cancel flow, landlord/staff review, co-occupants with room-capacity locking, tenant notification preferences, reminder preference enforcement | Dedicated tenant lifecycle UI/screens; production acceptance |
| 13 | Finance reconciliation | Existing bank CSV import, duplicate detection, manual maker/checker review and audit; now matches whole billing receipts instead of their allocation payment rows; candidate API and Flutter candidate/receipt proposal selection | Outgoing refund statement lines, landlord-facing workbench if required |
| 14 | Scheduled report/export | Existing manual monthly CSV and admin scheduled-report infrastructure remain | Landlord revenue/debt/occupancy/maintenance schedules and XLSX/PDF generation/delivery |
| 15 | Outbox | Billing invoice/payment/refund/tariff events, retry/backoff, dead-letter management, webhook/notification idempotency | Generalized event consumers for non-billing modules; production webhook acceptance |
| 16 | Analytics read model | `GET /reports/analytics` returns definitions plus MRR, collection rate, occupancy rate and average overdue days with property scope enforcement | Persisted/materialized analytics read model and tariff-change revenue-impact comparison model |

## Main entry points

- In Flutter, open a real invoice and use **Khoản thu, phân bổ và hoàn tiền** (payments icon). Receipts can allocate across that tenant's invoices, including invoices from different months. Refunds only use unallocated credit; release an allocation first when necessary. Recording a refund does not execute a bank transfer.
- Billing list includes **Xem tuổi nợ theo người thuê / phòng / khu trọ**.
- Billing list includes **Biểu phí khu trọ, phòng & điện nước**. Staff with `billing.view` can inspect scoped tariffs and `billing.create` can propose; only landlord can approve/reject. Room selection additionally requires `room.view`. Unknown command outcomes require explicit read reconciliation before another write.
- Invoice detail includes **Tạo hóa đơn thay thế** for real, non-cancelled invoices without any payment history. The editor creates a new revision and never edits the original invoice lines.
- Invoice detail **Phát hành credit / debit note** includes fixed/percentage mode and adjustment/discount/tenant waiver/surcharge/late-fee categories. Percentage adjustments use the current invoice total, not the remaining balance; credits cannot exceed that balance.
- **Báo cáo > Chính sách nhắc nợ > Cấu hình** edits the landlord default or selected property's override. Inherited values are displayed and used when creating an override. The form uses optimistic versions and a stable retry key. Saving does not send immediately or enable background workers.
- Maintenance ticket menu includes **Giao việc / SLA**. Assignees need an active account, maintenance permission, the same landlord, and a scope covering the ticket's property.
- Staff management includes **Phạm vi khu trọ** and a server-side permission simulator. Unconverted staff modules are denied rather than returning unscoped landlord data.
- Admin finance proposals accept `MATCH_RECEIPT` with `receiptId`; a second admin must approve. Allocated `Payment` rows cannot be independently bank-matched.

## Evidence

- Backend build and Prisma schema validation pass.
- Backend unit suite: 418 passed, 7 skipped.
- Database safety scripts: 10 passed. Targeted Flutter billing/API suite: 48 passed; targeted analysis of billing/reports/staff/maintenance and touched room screens passes. This is not a full Flutter-suite or native-device acceptance result.
- `npm run ops:billing-rehearse`: 40 E2E tests pass in the 2026-10-27 follow-up run; migrations apply to a disposable local database, legacy invoice/payment history survives, staff scope and tenant lifecycle checks pass, legacy tariff writes respect locked periods, and Prisma reports `No difference detected`. The disposable database is removed afterward.
- Flutter billing tests cover replacement immutability/validation, credit/debit percentage controls, reminder policy inheritance/retry, receipt allocation/refund behavior and narrow mobile viewports.
- See `backend/docs/billing-production-runbook.md` for backup, staging rehearsal, guarded migration, schema drift and rollback steps.

## Release restrictions

Do not treat all 16 backlog items as production-approved. Scheduled landlord reports/exports, device/staging acceptance for tariff/lifecycle screens, persisted analytics read models, and real EMAIL/ZALO provider acceptance remain follow-up work. Do not enable `MAINTENANCE_SLA_WORKER_ENABLED` or billing workers against an unmigrated database. Do not run migrations directly against production without the backup/rehearsal gates.
