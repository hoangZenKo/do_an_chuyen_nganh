# Admin accounts implementation - 2026-10-27

## Approved scope

Execute the account-management plan agreed in chat, in vertical slices. Reuse the
existing NestJS endpoints, capabilities, MFA/step-up, admin lifecycle and Flutter
workspace. Do not implement billing, change customer roles, run migrations, send
real reset/invitation messages, deploy, create branches or commit.

## Sequence

1. Account list: query contract, typed client, filters, pagination, session isolation.
2. Account detail: typed counts/history, loading, missing/forbidden states.
3. Suspend/restore: reason/version, transactional session revocation and audit.
4. Session revoke/reset and PII reveal: typed actions, guarded dialogs, no PII cache.
5. Preserve and verify existing administrator lifecycle and role-management flows.
6. Focused backend/Flutter tests, build/analyze and regression verification.

## Decisions

- Work in the current dirty checkout: existing changes include the implementation
  being continued and must not be lost in a fresh checkout.
- No new schema/index without measured evidence. Existing role/preset boundaries
  stay intact; customer role conversion is not an account-management shortcut.
- Existing functionality counts only when verified; do not rebuild admin MFA,
  invites, access review or lifecycle simply because the roadmap mentions them.
- Initial assumption: keep the established account workspace visual language;
  the completed overview Dashboard keeps its scoped theme.

## Verification

Use isolated service/HTTP tests with mock persistence for backend changes. Run
Flutter API, provider and widget tests per slice, then the Admin/Auth regression
suite. Never apply migrations or mutate the working database for these tests.
Record results and any unverified live end-to-end steps in tasks/todo.md.
