# App functional delivery status

Updated: 2026-10-27 (Asia/Ho_Chi_Minh). Scope: landlord, property-scoped staff and tenant only. This is not production acceptance.

## Inventory before these changes

| Stage | API already present | UI already present | Existing test evidence | Actual acceptance |
| --- | --- | --- | --- | --- |
| 1 Lifecycle / settlement | Renewal/transfer/checkout requests, cancellation/review, occupants; canonical settlement/deposit/refund ledger | Landlord renewal/settlement; tenant lease/deposit history; no dedicated request/occupant screens | Staff lifecycle E2E, settlement E2E, settlement Flutter API/widget tests | No device/staging evidence found |
| 2 Account / sessions | Account-access one-time tokens and encrypted delivery jobs; tenant/staff invites; refresh/revocation | Login/forgot, activation/invite screens; secure session storage | Auth API/repository/refresh/cache isolation tests | Provider delivery, installed-app links/restart not accepted |
| 3 Payments | Tenant proof submission and review; separate receipt/allocation/refund ledger; demo gateway | Proof upload/review and invoice timelines; demo checkout visibly separate | Billing/tenant portal tests and demo-payment E2E | Bank/provider/device acceptance not demonstrated |
| 4 Push | In-app notifications, delivery jobs, billing outbox | In-app notification lists | Existing notification API tests, not native push acceptance | Device registration/provider credentials missing |
| 5 Import | No audited business import/opening-balance workflow identified | None identified | None identified | Not accepted |
| 6 Tariffs | Property/room/legacy precedence; effective versions, progressive utilities, proposals/review and period safeguards | Legacy room fee versions and invoice preview | Tariff unit/E2E/Flutter tests reported in BILLING_DELIVERY_STATUS.md | Complete property/utility approval UI not accepted |
| 7 Data experience | Filters vary by endpoint; lifecycle already has cursor pagination | Existing lists have mixed error/empty/refresh patterns | Feature-specific tests, not comprehensive acceptance | Not accepted across all lists |
| 8 Contracts | Handover/acknowledgement and lease/deposit history | PDF export, handover screen | Housing/handover tests exist | No legal e-signature provider or acceptance |
| 9 Landlord reports | Manual monthly CSV, scoped analytics definitions | Monthly reporting screen | Existing report/billing E2E evidence | No landlord scheduled report artifact/retention acceptance |

Counts in PRODUCT.md, PROJECT_STATUS.md and BILLING_DELIVERY_STATUS.md describe earlier work; they are not tests run by this change. Admin modules and their moderation/support/governance/access-review workflows are excluded.

## Follow-up vertical slice: tariff management UI

### Already present before this change

- `GET /billing/tariffs`, proposal/review commands, impacted-room lookup, effective-month guards, progressive utility tiers and invoice preview already existed in the landlord/staff billing API.
- The app had legacy room service-fee editing and invoice line provenance, but no property-level utility tariff workbench or proposal/review screen.

### New in this change

- Added `lib/features/billing/billing_tariffs_screen.dart` and a link from billing. Landlord/staff can select a property, choose property default or room override, propose service/electricity/water prices, set an effective month, enter progressive tiers and submit an audited proposal.
- Added proposal history search/filter/client-side pagination (12 versions per page), proposed/approved/rejected state chips, old/new comparison, tier detail, impacted-room disclosure and issued/locked-period blockers. Server-side tariff-history pagination remains a follow-up for large portfolios.
- Added landlord-only approve/reject UI with mandatory reason. Staff can propose but cannot approve because the screen and backend role/permission rules remain separate. Property selection reuses `property.view`; room selection requires `room.view`; neither permission is silently broadened.
- Preserved loaded tariff rows on read refresh failures; blocked approval/resubmission after an unknown/conflicting mutation result until an explicit fresh read. An explicit retry of the same proposal payload retains its command key after that read; refreshing never sends a mutation. Draft/mutation responses are ignored after an account identity change.
- Added `BillingTariffVersion`, `BillingTariffImpact`, API/repository methods and scoped Riverpod providers. No second pricing or ledger path was introduced.
- Fixed the backend impact comparison so a viewed proposal is not compared to itself, room overrides are disclosed separately, and approval blockers include issued invoices, locked periods, backdating, effective-order and already-reviewed states. Missing property filters now fail before a tariff history read, preventing staff from accidentally querying across unassigned properties.

### Tests actually run for this slice

- Flutter analyzer: clean for the changed tariff/API/route files.
- Flutter tariff API tests: 6/6 passed (`test/data/billing/billing_tariff_api_test.dart`).
- Flutter tariff UI tests: 12/12 passed (`test/features/billing/billing_tariffs_screen_test.dart`), including staff-vs-landlord authorization, duplicate-click protection, stale/unknown result handling, refresh error retention, account switching, 360px layout and 1.4 text scale.
- Broader Flutter billing/API/auth-navigation regression: 78/78 passed with `flutter test test/data/billing test/features/billing test/features/auth/auth_navigation_test.dart`.
- Widget render captures inspected locally at 360x800 (1.4 text scale) and 1024x768: `.impeccable/review/tariffs-phone.png`, `.impeccable/review/tariffs-phone-form.png`, `.impeccable/review/tariffs-tablet.png`. Capture uses optional test-only `--dart-define=TARIFF_CAPTURE=true`; this is not installed-device acceptance.
- Backend tariff impact unit tests: 7/7 passed (`backend/src/billing/billing-tariffs.service.spec.ts`).
- Backend build: passed (`npm run build`).
- Disposable billing rehearsal: 4 suites / 40 tests passed; all 52 migrations applied to an isolated database, Prisma schema diff clean, and the database was dropped afterward. New E2E covers concurrent identical proposals, competing decisions, stale effective order, predecessor comparison and preserved room-over-property pricing. The existing runner also covers staff scope and admin completion; no Admin Console workflow was changed.

### Still missing / not accepted

- No production migration, deploy, provider credential, bank reconciliation, native push or device/staging acceptance was performed.
- Tariff approval remains subject to live backend permissions and locked/issued-period rules; production UAT should verify landlord/staff property scopes with real accounts.
- Invoice preview remains the existing lease-based preview API; the tariff screen does not claim money collection or rewrite historical invoices.

## Files shared with the Admin Console branch

- `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart`: only the non-admin billing tariff route and billing capability guard were added; no admin route/workflow was modified.
- `lib/data/billing/billing_api.dart`, `lib/data/billing/billing_repository.dart`, `lib/features/billing/billing_providers.dart`, `lib/models/billing_tariff.dart`: shared billing data layer additions.
- `backend/src/billing/billing-tariffs.service.ts`: shared tariff impact metadata and guard clarification; no moderation/support/governance/access-review code changed.
- `lib/features/billing/billing_screen.dart`: new entry point only; existing invoice/payment UI remains.
- `BILLING_DELIVERY_STATUS.md` and this document: follow-up inventory/evidence only; earlier test totals remain dated snapshots rather than current rerun claims.

## Migration / environment / dependency changes

- No new migration, environment variable or runtime dependency.
- Test files added: `test/data/billing/billing_tariff_api_test.dart`, `test/features/billing/billing_tariffs_screen_test.dart`, `backend/src/billing/billing-tariffs.service.spec.ts`. Existing `backend/test/e2e/billing-production.e2e-spec.ts` and `backend/test/e2e/staff-lifecycle.e2e-spec.ts` gained tariff-specific cases only.
- Integration check: regenerate Prisma client if the Admin Console branch changes `schema.prisma`; rehearse the full migration chain on an isolated PostgreSQL database before any production operation. Preserve admin routes, MFA/step-up, notification consumers and platform report semantics.

## Milestone 1 (stages 1-3): verified locally, not production-accepted

### New lifecycle slice

- Tenant request form for renewal/transfer/checkout; cancellable pending requests; filter/cursor history, reason/date/decision display.
- Property-scoped landlord/staff review with optional backward-compatible request/lease `updatedAt` preconditions. Duplicate submission and concurrent decisions remain conflict-safe.
- Explicit execution separate from approval. Renewal reuses the existing lease/history implementation under fresh locks. Checkout/transfer require the canonical confirmed settlement. Transfer reuses lease creation and copies co-occupants, preserving the old occupant history.
- Transfer creates no new deposit collection, allocation or refund. Old-deposit settlement/refund stays on the original lease; actual new-deposit collection must use the existing deposit ledger. Future transfer execution waits for the requested business date.
- Tenant settlement view reuses the canonical serializer and checks lease ownership. Charges, deposit offset, balance due, old-invoice debt, refund due and recorded-refund status remain separate.
- Existing lease details link to the new screen. Landlord settlement/refund UI remains the source of financial mutation; staff review permission does not imply settlement/refund permission.
- New screen retains loaded rows after read failures, blocks mutations with unknown/conflicting outcomes until explicit refresh and binds requests to the opening account identity.

### Tests actually run

- Backend Prisma generate and `npm run build`: passed after the payment-proof idempotency patch.
- Targeted backend unit tests: 2 suites / 30 tests passed (`billing.service`, `account-access.service`; the requested tenant-invite/property-scope paths have no matching Jest suite in this checkout).
- Disposable migration rehearsal: all 51 migrations apply; Prisma schema diff reports `No difference detected`; only the generated disposable local database is modified and dropped.
- Lifecycle/auth/payment E2E: 10/10 pass on the disposable database, including duplicate requests, stale/concurrent handling, settlement ownership, recovery/invite activation, and payment-proof approval ledger creation.
- Targeted Flutter tests: 79 tests passed across lifecycle, auth/session, tenant portal payment, billing API, and invoice timeline coverage. Targeted Flutter analyzer reports no issues for the 10 edited lifecycle/auth/payment files.

### Still missing / not accepted

- Stages 2-3 now have local hardening: recovery resend cooldown, deep-link parsing, one-time activation race locks, tenant/staff invite invalidation and refresh-account isolation. Payment proof reuses the existing review/ledger flow and adds request idempotency without creating a second payment mechanism.
- Payment provider credentials, bank statement reconciliation and device/staging acceptance are still missing; upload/QR/demo checkout must not be reported as money received until landlord review or the existing ledger path records it.
- Approved bank-transfer proof now creates the existing `BillingReceipt` + `PaymentAllocation` pair in the same locked transaction; tenant upload and QR open remain non-payment states. Rejected proof keeps its reason visible in the tenant invoice timeline.
- Physical-device/staging UAT, real recovery/invite delivery, app/universal-link domain association and bank transfer reconciliation acceptance are not inferred from unit/E2E results.
- Stages 4-9 were follow-up vertical slices at this milestone; the subsequent tariff slice is documented above. Import/opening balance, native push, contract integrity and scheduled landlord reports remain incomplete. Existing functionality must not be replaced; no production push/provider/signature/report acceptance is claimed.

## Shared files edited by this work

- `backend/prisma/schema.prisma`: additive lifecycle execution model/relation only; preserve simultaneous admin schema additions.
- `backend/src/leases/leases.module.ts`: export the existing settlement service for the tenant read-only endpoint.
- `backend/src/leases/leases.service.ts`: reusable transactional renewal; fresh active/end-date checks under existing lock order.
- `backend/src/leases/settlements.service.ts`: authorized tenant read using the existing serializer; no second calculator.
- `lib/features/tenant_portal/tenant_leases_screen.dart`: link to request/occupant/settlement screen.
- `lib/features/tenants/tenant_detail_screen.dart`: link from lease history, including ended leases.

## Migration / environment / dependencies

- New additive migrations: `20261027090000_tenant_lifecycle_execution` (unique request/key, immutable execution result/actor/time) and `20261027100000_payment_proof_idempotency` (request key/hash for duplicate-safe proof submission). Tested on disposable PostgreSQL only.
- No new runtime dependency or production environment variable. Existing delivery configuration remains required for real account-access sending: `AUTH_PUBLIC_APP_URL`, encrypted delivery key, webhook URL and production webhook secret.
- Disposable test runner: `cd backend && node --env-file=.env scripts/run-app-functional-e2e.mjs`. It refuses remote database hosts, creates a unique `rental_functional_test_*` database, applies migrations, checks schema diff and drops that database. It supplies test-only delivery URLs/key; workers stay disabled and no real message is sent.
- No production migration, DB reset, commit, branch or deployment performed.

## Integration with the Admin Console branch

- Merge Prisma additions, regenerate the client and rehearse the complete migration chain on an isolated database before integration. Never reset an existing database.
- Preserve admin routes, MFA/step-up policies, notification consumers, platform report semantics and all existing uncommitted changes.
- Request `expectedUpdatedAt` / `expectedLeaseUpdatedAt` are optional for existing clients; the new client supplies them. Verify staff property scope and cross-role denial after merging auth/authorization infrastructure.
- Existing `APP`/EMAIL/ZALO outbox is not native push; demo card checkout is not production payment; handover acknowledgement is not a claim of legally qualified e-signature.
