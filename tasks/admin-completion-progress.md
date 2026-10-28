# Admin completion execution

Plan: `docs/superpowers/plans/2026-10-28-admin-console-completion.md`.

## Rules and decisions

- Work in the current checkout; preserve the existing uncommitted work. No new branch, commit or production deployment is authorized. A later explicit user request authorized the guarded migration on local `rental_management` only.
- Ruling: retain `AdminWorkspaceScaffold` as the compatibility/access-control adapter and render the shared `AdminOverviewShell` from it. Existing screens keep their callbacks, permission checks and session invalidation without a second visual layout.
- Ruling: a catalog/administrative subscription assignment is not payment settlement. Platform revenue must stay unavailable until authenticated subscription payment/settlement evidence exists; never count rent or manually assigned plans as revenue.
- Ruling: preserve existing approved workflows rather than replacing account, support, reports, reconciliation, audit or delivery services.
- Ruling: verification is an administrative review of scanned Support evidence, not external legal KYC. Individual/business document policy still needs product approval.
- Ruling: plan limits are per landlord over active properties/rooms. No subscription preserves existing legacy behavior; explicit expiry/cancellation blocks inventory growth but never deletes history. Catalog edits do not rewrite assigned snapshots.
- Ruling: property approval is independent of archival and listing moderation; this change does not silently redefine public listing eligibility.
- Ruling: audit export keeps the existing authenticated, bounded CSV response and clipboard flow, not a newly invented signed public link.

## Progress

### Admin UI cleanup - 2026-10-28

- Removed unused `admin_dashboard_screen.dart`, the duplicate dashboard renderer in `AdminWorkspaceScreen`, and the obsolete `admin_sprints_screen.dart` export barrel. The default workspace entry still delegates to `AdminOverviewPage`; live moderation/support/account workflows remain intact.
- All Admin routes now sit under one light-themed `ShellRoute`. Loading, denied/changed-session states, pushed pages and root-navigator dialogs inherit Admin styling without changing the non-Admin app theme or route guards. Existing route paths, parameters and aliases remain available.
- SLA configuration now uses `AdminWorkspaceScaffold` / `AdminOverviewShell`. The scaffold adapter remains intentional: it contains capability, session, refresh and navigation behavior, not a second legacy visual layout.
- Shared panels, records, status badges, queues, forms and audit/support accents use the overview tokens instead of the old bright cyan/teal palette. Admin forms no longer import Tenant form widgets; they use accessible labeled fields and the shared input/dialog theme.
- Landlord inventory now uses the shared section/empty/error patterns; landlord forms/details use Vietnamese labels. No backend, database, grants or revenue rules changed in this cleanup.
- Verification: Admin/Auth/Admin API Flutter suite passed 212 tests. Analyzer reports only the seven previously recorded style infos; no errors or warnings. `git diff --check` passed.
- iPhone 16 / iOS 18.4 visual spot checks used an isolated in-memory provider fixture: property form labels, shared navigation and Support Center rendered in the light theme. This is not authenticated working-DB or full on-device acceptance. SLA shell/versioned-save behavior is covered by widget tests.

- [x] Phase 0: shared light shell, canonical navigation, route/capability matrix and regression tests.
- [x] Phase 1: verify and close dashboard/report gaps with truthful finance availability.
- [x] Phase 2: unified inventory UI, property review and landlord verification workflow.
- [x] Phase 3: verify account/support/notification workflows and close integration gaps.
- [x] Phase 4: transaction investigation, plan/limit/subscription administration, safe configuration.
- [ ] Phase 5: security/audit/operations verification, release checklist and evidence.

These checks track implementation slices, not production acceptance. Phase 5 code/security checks are implemented; staging/provider/restore and full runtime acceptance remain open.

## Verification ledger

Phase 0 implementation evidence:

- `test/features/admin/admin_unified_shell_test.dart` passed at 1440px, 320px and 320px/200% text scale.
- Inventory, account workspace, shell foundation and workspace-flow regressions passed.
- Admin/Auth/API focused Flutter suite passed 170 tests.
- Root `/admin` now resolves to `AdminOverviewPage`; inventory routes use the shared shell adapter.
- iPhone 16 / iOS 18.4 runtime used an actual Nest API and fresh disposable PostgreSQL DB. Dashboard, masked accounts, light property inventory, rooms, verification queue, property-review empty state and Free/Pro/Premium catalog loaded successfully. No working-user credentials or persistent session storage were used.
- Route/capability matrix was regenerated after adding transaction investigation and subscription cancellation.

Phase 2/4 implementation evidence:

- Registry migration `20261028090000_admin_registries` is additive; after isolated restore/rehearsal and explicit follow-up user approval, it was also deployed to local `rental_management` using the guarded migration flow. Staging/production were not touched.
- Admin verification queue supports `PENDING`, `NEEDS_INFO`, `APPROVED`, `REJECTED`, ticket evidence gating, row locks, version conflicts, self-review prevention and transactional audit.
- Property review is distinct from archival/listing moderation, exposes `approval` state, detects changed snapshots and requires resubmission before a new decision.
- Free/Pro/Premium administrative entitlements support versioned limits, snapshots, history, cancellation and explicit `platformRevenueAvailable: false`; no rent or manual assignment is counted as platform revenue.
- Subscription limits are enforced on property/room growth and reactivation without deleting existing inventory; operations remain auditable and read-only from the transaction investigation panel.
- Landlords can view only their own verification state and submit a ticket reference; Admin queues are capability-gated and evidence links return to Support Center.
- Final backend build passed; unit suite passed 696 tests (7 skipped), Admin E2E passed 41 tests across six suites, safety scripts passed 11 tests and isolated-runner safety passed 8 tests.
- Final Flutter `test/features/admin test/features/auth test/data/admin` passed 173 tests, including registry and transaction panels at 320px/200% text and date-boundary filtering.
- Reproduced audit deep-link failure and reviewed-property deletion HTTP 500 before fixes; both now have passing regressions. Audit links preserve the supported `resourceId` filter, and reviewed-property deletion returns 409 while keeping history.
- Property review commands invalidate typed inventory caches; subscription history has bounded UI pagination.
- Static analyzer has no errors; it reports 7 pre-existing style infos in moderation/search QA code, explicitly recorded in the delivery status.
- Broader `flutter test --reporter expanded` ran 578 tests: 567 passed, 11 failed, all in `test/features/dashboard/dashboard_chatbot_entry_test.dart` outside Admin (floating navigation overflow and stale finder assumptions). These unrelated failures were not modified; do not claim the whole project is green.
- Final independent reviewer dispatch was unavailable (tool returned `Unknown model gpt`); performed local source/contract/security review instead, without claiming a second independent review.
- Temporary API/web-server processes were stopped; disposable runtime harness confirmed `ISOLATED_ADMIN_QA_CLEANED`, and its temporary Flutter entry was removed. Working DB remains unchanged.

Known release blockers:

- Local `rental_management` now passes readiness with the new migration; staging/production still require their own backup/rehearsal/approval and acceptance evidence.
- No production provider settlement or refund/chargeback integration exists, so platform revenue remains unavailable.
- Full runtime acceptance remains partial: finance/support/notifications/audit flows were tested at API/widget/E2E level, not all manually completed on-device in this run. The repo configures iOS, not web; the unsuccessful web bootstrap was not used as acceptance evidence.
- Phase 5 still requires staging migration evidence, backup/restore drill, provider smoke, rollout owner and rollback approval.

## Reproduction commands

From the project root:

```sh
flutter test test/features/admin test/features/auth test/data/admin --reporter expanded
flutter analyze lib/features/admin lib/features/auth lib/data/admin lib/app/app.dart test/features/admin test/features/auth test/data/admin
```

From `backend`:

```sh
npm run build
npm test -- --runInBand
PATH=/opt/homebrew/opt/postgresql@16/bin:$PATH npm run test:admin-inventory:e2e
npm run test:safety-scripts
npm run test:admin-accounts:safety
npm run ops:readiness
```

The last command is read-only and now exits 0: `ready=true`, no missing/drifted/failed/unexpected migrations. `npm run start:dev` starts after the guarded migration. Never disable this check to make the server start.

## Local migration evidence — 28/10/2026

- Target verified as `localhost:5432/rental_management`, local development only. Existing local encryption key was validated without printing it or modifying `.env`.
- Encrypted backup manifest: `backend/.backups/rental_management-2026-10-27T23-03-42-312Z-dd092a5f.dump.enc.json`. AES-GCM authentication and checksum verified; local off-site durability is false.
- `ops:restore-check` and `ops:rehearse` passed on separate restore-check DBs, with migration `20261028090000_admin_registries` and preserved user count. Disposable restore DBs were removed.
- API was stopped, active DB sessions were zero, and `ops:migrate` passed with exact `MIGRATION_CONFIRM_DATABASE=rental_management`.
- Readiness is true, auth/billing schema ready, 53 migrations applied. Prisma generate, build and `start:dev` passed. Health/live and ready return 200; new registry routes return 401 without auth. Authenticated registry smoke was not performed on the working DB.
- Backup comparison: 103 existing tables have identical content; only `WorkerHeartbeat` timestamps advanced while workers were running before migration. User/property/room/tenant/lease/invoice/payment/admin/session data were preserved.
- New registry tables are empty. Existing Admin permissions were not auto-escalated; the current profile lacks verification/plans view grants. No production/off-site recovery claim is made.
