# Manual Bank Transfer Payments Implementation Plan

**Goal:** Reuse invoice and payment-proof workflows for real bank transfers confirmed manually by the landlord, without payOS or simulated confirmation of real invoices.

**Architecture:** Add versioned recipient configuration per property, editable only by its landlord. A tenant-owned invoice exposes private transfer instructions and an optional owner-uploaded bank QR image. Existing proof submission reserves pending balances; existing landlord approval writes the receipt, allocation and payment atomically. Demo card checkout remains restricted to separate test invoices.

**Tech Stack:** NestJS, Prisma/PostgreSQL, Flutter/Riverpod, existing private uploads.

**Scope:** The user accepted transfer plus manual confirmation after comparing it with payOS. The app never debits a bank account, verifies a bank balance or treats tenant confirmation as proof of receipt. No provider account is required by this implementation; no live bank transaction or working-database migration is performed here.

## Tasks

- [x] Add account DTO/service/controller tests, then implement private/versioned owner-only account configuration and tenant-owned instructions.
- [x] Add an additive migration; validate it only on disposable databases. No working DB changes.
- [x] Add landlord account configuration and tenant transfer UI using existing styles; keep demo card checkout explicitly isolated.
- [x] Reuse proof submission with pending/rejected/approved states; require the reviewer to acknowledge checking actual funds.
- [x] Verify authorization, stale updates, upload access, pending balances, duplicate approval and demo isolation with focused and full regression tests.
- [x] Document setup, migrations and manual-confirmation limitations with current verification evidence.

## Review Focus

- Other landlords/tenants and staff must not change the recipient account or read unrelated private QR images.
- Stale configuration changes must conflict; account changes must be audited without exposing full account details in logs.
- Uploads must be owner-owned image files, not arbitrary URLs, public listing files or another user's evidence.
- Pending proof submission never changes paidAmount; approve/reject use existing transactional ledger guards.
- Paid/cancelled/demo invoices and disabled/absent account settings must not offer payable transfer instructions.
- Old-session screens must not submit writes after an account switch.

## Execution Evidence — 2026-10-29

- Backend: `npm test -- --runInBand` — 736 passed, 7 skipped; `npm run build` passed. Evidence: `/tmp/rental-manual-backend-verified.log`, `/tmp/rental-manual-build-verified.log`.
- Disposable-database migration + E2E: `npm run test:manual-transfers:e2e` — 18 passed across manual-transfer and original demo-card suites; the runner dropped its temporary database. Authorization, stale versions, pending/partial balances, real uploaded evidence, concurrent approval, QR access and demo isolation exercised. The two expected 503 logs belong to disabled/production demo-gateway tests. Evidence: `/tmp/rental-manual-e2e-verified.log`.
- Flutter full suite — 678 passed. New focused coverage includes recipient settings, tenant instructions/proof UI, malformed API response handling, account-switch invalidation and the same receipt acknowledgement on both billing-list and invoice-detail review entry points. Evidence: `/tmp/rental-manual-flutter-complete.log`.
- Red/green regression: malformed instructions previously leaked TypeError; a focused proof form and review form disposed their controllers before reverse route animation finished. Typed decoding and widget-owned controller lifetimes now pass the reproductions. Shared review dialog removes the invoice-detail bypass. Evidence: `/tmp/rental-manual-parser-red.log`, `/tmp/rental-review-repro.log`, `/tmp/rental-proof-close-red.log`, `/tmp/rental-review-all-entry-green.log`.
- Targeted analysis: 12 edited/new Dart files, no issues. `git diff --check` passed. Evidence: `/tmp/rental-manual-analyze-verified.log`.
- Native verification: isolated provider-fixture iPhone 16 preview visually inspected; no live API writes. Preview app was installed under a separate identifier, then uninstalled; temporary preview source removed. Final standard app `flutter build ios --simulator --debug --no-codesign` passed. Evidence: `/tmp/rental-manual-ios-verified.log`; visual fixture screenshot: `/tmp/rental-manual-payment-ios.png`.
- Local self-review checked account scope, signed-upload boundaries, pending-versus-paid accounting and both review call sites. No independent review or real-bank verification is claimed.

## Operational Work Still Pending

- Read-only `npm run ops:readiness`: missing only `20261028140000_manual_transfer_account`; no checksum drift, failed or unexpected migrations. Overall readiness remains false. Evidence: `/tmp/rental-manual-readiness-verified.log`.
- Do not start the new API against the working database until backup, isolated restore/migration rehearsal and guarded migration pass. No working-database migration/reset/seed was performed in this implementation.
- Real landlord/tenant device acceptance, actual bank receipt checking and staging rollout are not covered by automated tests. Seven pre-existing backend tests remain skipped.
- Setup, API contract, migration gates and manual-confirmation limitations: `docs/manual-transfer-payments.md`.
- This slice covers landlord rental-invoice collection only, not paid platform subscription activation or platform revenue.
