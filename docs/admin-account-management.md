# Admin account management

Updated: 2026-10-27, Asia/Ho_Chi_Minh.

## Delivered scope

- `/admin/accounts` uses the typed `AdminRepository.accounts` contract rather than
  untyped workspace requests. Search is trimmed and debounced for 350 ms.
- Server pagination and role/status/creation-date filters are wired through the
  model, repository, API and UI. Date ranges represent inclusive Vietnam calendar
  days and are sent as UTC ISO timestamps. Reversed ranges return HTTP 400.
- The selected query and page survive opening a detail route and returning.
  Query state resets when the authenticated account identity changes.
- `/admin/accounts/:id` uses `AdminAccountDetail`, including the current version,
  related property/tenant counts, masked contacts and recent account history.
- Suspend/restore, revoke sessions, reset password and PII reveal use typed
  `AdminApi` methods and the existing authorized-command/step-up mechanism.
- Sensitive actions require a reason of 10-1000 trimmed characters. Status changes
  submit the version displayed in the detail response. A 409 blocks subsequent
  actions until the operator reloads; it never automatically retries a mutation.
- Successful mutations invalidate the account list/detail, overview, legacy
  landlord reads, audit and workspace projections.
- Permissions gate both reads and actions. Data and pending command results are
  hidden/discarded after an account identity change. Provider reads capture the
  session-bound repository before awaiting capabilities and check cancellation.
- Unmasked contacts live only in the reveal dialog, not a provider. The dialog
  permanently hides its contents after session/capability loss; restoring a
  capability does not resurrect the old reveal. App backgrounding also hides
  contacts until a fresh reveal is requested.

## Existing API contract

All paths below are relative to `/api/v1`. Customer-account APIs exclude ADMIN
targets. Administrator accounts retain their separate lifecycle/preset routes.

| Method | Path | Capability | Payload / result |
| --- | --- | --- | --- |
| GET | `/admin/accounts` | `admin.accounts.view` | `page`, `limit`, `search`, `role`, `status`, `from`, `to`; returns `data` and `meta` |
| GET | `/admin/accounts/:id` | `admin.accounts.view` | Masked detail, counts, history and version |
| POST | `/admin/accounts/:id/suspend` | `admin.accounts.suspend` | `reason`, `version`; existing step-up rule applies |
| POST | `/admin/accounts/:id/restore` | `admin.accounts.suspend` | `reason`, `version` |
| POST | `/admin/accounts/:id/revoke-sessions` | `admin.sessions.revoke` | `reason`; returns `revoked`, `revokedSessions` |
| POST | `/admin/accounts/:id/reset-password` | `admin.accounts.manage` | `reason`; returns `queued: true` only on queue acceptance |
| POST | `/admin/accounts/:id/reveal` | `admin.pii.reveal` | `reason`; existing step-up rule applies; returns unmasked contacts |

List/detail responses have `Cache-Control: private, no-store`. PII reveal retains
its existing `no-store` policy and throttling. Pagination remains capped at 100
items; UI uses 20. User-account role conversion is deliberately not introduced.

## Session and audit semantics

Status mutations lock the target User row, check `sessionVersion`, update status
and increment the version in one transaction with token/session invalidation and
the audit entry. Both suspend and restore revoke old `AuthSession` rows; restoring
an account does not reactivate old access/refresh tokens.

Suspending a landlord also increments dependent staff user versions and revokes
their refresh tokens and AuthSession rows. This does not delete properties,
contracts, tenant records or financial data. Standalone session revocation also
increments the account version and records before/after versions and the count of
newly revoked session rows. The count includes all previously unrevoked rows,
including expired ones; it is not a count of currently online devices.

Existing administrator protections are preserved and covered by regression tests:
MFA, no self role/status change, stale-version rejection, retaining at least one
active super admin, session revocation, cancelling pending invites on deactivation,
access review and auditable before/after presets.

## Verification

```sh
cd backend
npm run build
npm test -- --runInBand
cd ..
flutter test test/features/admin test/features/auth test/data/admin
flutter test test/features/admin/admin_accounts_workspace_test.dart
```

Dedicated tests cover API owner binding, pagination metadata, version/reason
payloads, UTC/Vietnam boundaries, search debounce, navigation restoration,
401/403/404/409 states, pending-result isolation, mobile 320px at 200% text,
PII invalidation and actual HTTP authorization/validation/one-time grants with
mock persistence. Tests do not change the working database or send real emails.

Optional reproducible widget-render captures:

```sh
ADMIN_QA_OUTPUT=/tmp/admin-accounts-qa flutter test \
  test/features/admin/admin_accounts_panel_test.dart \
  test/features/admin/admin_account_detail_panel_test.dart
```

Database-backed acceptance on a disposable local PostgreSQL database:

```sh
cd backend
npm run test:admin-accounts:safety
npm run test:admin-accounts:e2e
```

The runner rejects non-local or unnamed source databases, creates a random
`rental_admin_accounts_test_*` database, deploys the existing migrations there,
disables background workers and delivery configuration, runs the account/admin
regression E2E set, then drops only that generated database. The acceptance run
covered 30 tests: account filters/detail/permissions, concurrent status changes,
dependent staff session revocation, restore token invalidation, revoke counts,
audit rollback, recovery queue truthfulness, MFA and administrator safeguards.
The runner safety suite covered 8 tests.

Prerequisites: Node supporting `--env-file`, installed backend dependencies,
PostgreSQL `psql` on PATH, a local `DATABASE_URL` in `backend/.env`, and permission
to create/drop disposable databases via the `postgres` maintenance database.
No real email is sent. Expected 500/503 logs exercise deliberately failed audit
insertion and unavailable delivery; the test runner must still exit successfully.

## Operational limits

### 2026-10-28 follow-up

- The Admin workspace now uses a shared-theme permission editor backed by `GET /admin/admins/:id/access` (`admin.admins.manage`, `private, no-store`). The existing versioned profile PATCH accepts an optional, unique, nonempty `permissions` array containing `admin.dashboard.view`; null/unknown grants are rejected. Super-admin profiles must retain all capabilities.
- Only a live active super-admin may send explicit grants. All profile updates and Admin invitations enforce the operator's delegation ceiling. Self-change, MFA, stale-version and last-super-admin protections remain in place; sessions and access-review evidence are invalidated with before/after audit in the mutation transaction.
- Older clients may omit explicit grants and keep the preset workflow, subject to the delegation ceiling. No migration or automatic elevation is performed. Client drafts are invalidated on session/permission loss and must reload after version/authority changes.
- Current verification supersedes historical counts: 637 Flutter tests, 716 backend tests (7 skipped), 42 disposable-DB Admin E2E tests across six suites; backend build passed. The earlier dashboard floating-navigation failures are resolved. Full evidence and remaining provider/device gates: `superpowers/plans/2026-10-28-project-follow-up-phases.md`.

### Earlier checkpoint limits

- No schema migration, index addition, deployment, branch or commit is required by
  this change. Existing uncommitted work is preserved.
- Invitation/reset delivery still requires the existing configured delivery
  provider and public activation URL. Queue acceptance is not proof of email
  delivery. No real delivery or production login/revocation scenario was exercised.
- Database-backed concurrency/rollback tests now run through the disposable
  account E2E runner; the working database is not migrated, reset or dropped.
- Recovery/reset acceptance verifies queue persistence only. It does not send a
  real email or prove delivery-provider availability in staging/production.
- The full Flutter suite has pre-existing landlord floating-navigation failures;
  account/Admin/Auth focused suites must be evaluated separately. See tasks/todo.md
  for the current run's exact counts.
