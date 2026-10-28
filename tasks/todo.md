# Admin accounts progress

## Database-backed acceptance - 2026-10-27

- [x] Inspect harness and confirm local PostgreSQL; initial console E2E 10/10.
- [x] Add a reusable disposable-DB runner with safety tests.
- [x] Verify account filtering/detail, dependent sessions, audit rollback and recovery.
- [x] Run focused E2E/regressions; record evidence and remaining operational limits.

Ruling: the latest approval covers database-backed account acceptance before
property/room moderation. Only a newly created disposable database may receive
migrations or cleanup. Never migrate/reset the working database. Keep delivery
workers off and real provider configuration disabled. No deploy/commit/branch.

Evidence: `npm run test:admin-accounts:safety` passed 8/8. The disposable runner
created a fresh PostgreSQL database, applied all 52 existing migrations, ran the
account/admin E2E set with 30/30 tests passing, and dropped only its generated
database. Account-recovery delivery endpoint/secret/key configuration was cleared
for the run; the queue-only test used synthetic encryption and .invalid URLs.
The working `rental_management` database was not migrated, reset or dropped.

Current regression evidence: `npm run build` passed; full backend unit suite
passed 643 tests with 7 skipped (62 passing suites, 1 skipped).
Existing operational safety scripts passed 11/11. A read-only pg_database check
confirmed zero `rental_admin_accounts_test_*` databases remained after the runs.
Logs: `/tmp/admin-accounts-db-third.log`, `/tmp/admin-accounts-unit-current.log`.
The 500/503 log entries in account acceptance are deliberate audit-failure and
missing-provider scenarios, not unexpected E2E failures.
Final review: self-review. Fresh-context review dispatch was attempted but failed
because inherited model `gpt` was unavailable; no independent-review claim.
No UI/runtime service changes or new migrations were needed after acceptance.
Actual email delivery, staging rollout and live-device UI/backend testing remain
outside this verification. Flutter was not rerun in this backend-only follow-up.

- [x] 1. Typed list contract and connected list UI; verify search/filter/pagination.
- [x] 2. Typed detail and history; verify 404, permission and identity changes.
- [x] 3. Suspend/restore; verify version conflict, dependent sessions and audit.
- [x] 4. Revoke/reset/reveal; verify step-up, dialog isolation and no PII caching.
- [x] 5. Verify existing admin lifecycle/permissions and preserve routes.
- [x] 6. Analyze, build, regression tests and final review.

## Evidence / rulings

- Initial review: customer list/detail/status/revoke/reveal/reset and administrator
  lifecycle already exist. The current customer UI reads untyped maps; typed list
  models omit version and the date filters are not passed through the client.
- Ruling: no new worktree/branch/commit; preserve the user's uncommitted baseline.
- Ruling: no new role-conversion endpoint; use existing protected admin presets.
- Ruling: preserve the original session-scoped list-provider lifetime to avoid
  duplicate fetches during capability/toolbar refresh; detail stays autoDispose,
  reveal data never enters a provider. Rights/session changes invalidate both reads.
- Slice 1 RED/GREEN: API tests initially failed for missing date/version contract;
  list UI tests initially failed for the missing typed panel. Now search debounce,
  pagination, status/role/date filters, retry, permission/session gating and navigation
  restoration are exercised.
- Slice 2-4 RED/GREEN: detail API/panel tests initially failed for missing typed
  methods/panel. Backend service tests exposed missing AuthSession invalidation,
  missing audit versions/revoke counts and missing reversed-range rejection.
- Final review fix RED/GREEN: restoring a revoked PII capability could resurrect
  an old reveal dialog. Both confirmation and reveal dialogs now latch invalidation;
  `restored permission cannot resurrect an old PII reveal` proves the fix.
- Final review fix RED/GREEN: PII completing after backgrounding could initialize
  visibly without receiving the earlier lifecycle event. Private-contact content
  now initializes hidden when the app is already inactive; the delayed-response
  regression test proves the fix.
- Route integration: existing workspace list/detail routes use the typed repository
  at widths 1440 and 320; toolbar refresh fetches the list once, not twice.
- Existing admin governance: five focused tests preserve MFA, self-action/stale
  version/last-super-admin guards, session invalidation, before/after audit and
  truthful reset/invite delivery failure behavior.
- Visual verification: widget captures at /tmp/admin-accounts-qa, including 320px
  with 200% text; list/detail desktop/mobile tests report no layout exception.
- Final review: self-review. Fresh-reviewer dispatch failed because the configured
  inherited model was unavailable; no unrequested model override was made.
- At initial UI/API delivery, live database E2E had not run; see the new
  database-backed acceptance section for current results. Actual reset/invite
  delivery and production rollout remain unverified.

## Final verification results

- Backend `npm run build`: PASS.
- Backend `npm test -- --runInBand`: 643 passed, 7 skipped, no failures (62 passing
  suites, 1 skipped); /tmp/admin-accounts-backend-final.log.
- Flutter Admin/Auth/API targeted: 141 passed, no failures;
  /tmp/admin-accounts-focused-last.log.
- Full Flutter suite: 535 passed, 11 failed. All 11 failures are existing landlord
  floating-navigation tests in test/features/dashboard/dashboard_chatbot_entry_test.dart;
  no Admin/account failures remain. /tmp/admin-accounts-flutter-last.log.
- Analyzer for all 13 changed source/test targets: no issues;
  /tmp/admin-accounts-analyze-last.log. Broader Admin-folder analysis also reports
  existing style infos in unrelated moderation/search-quality files; left intact.
- `git diff --check` on tracked changed account files: PASS.
- No new dependencies, migrations, real-message sends, commits or deployments.
