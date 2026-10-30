# Admin Moderation Search Implementation Plan

> **For agentic workers:** Use executing-plans to implement the tasks in order.

**Goal:** Upgrade the existing admin moderation search to find pending items by
room name/ID, listing title/ID, property name, and landlord name.

**Approved design:** The user approved upgrading the existing search in chat.
Keep the moderation toolbar and its filters; search the full server-side queue
before counting and pagination. Keep exact UUID targeting for moderation links,
debounced input, and the existing permission checks. Add an immediate clear
action and useful Vietnamese search/empty-state copy. Reviewed listings remain
outside the pending queue. No new dependency, migration, or contact-data search.

**Architecture:** Extend only the console queue search with correlated relational
predicates; leave the shared pending-queue SQL used by health/reports unchanged.
Use parameterized SQL and literal matching for wildcard characters. Reuse the
workspace search control without changing unrelated screens' search behavior.

**Tech Stack:** Flutter/Riverpod, NestJS, Prisma/PostgreSQL, Flutter Test, Jest.

## Global Constraints

- Preserve unrelated dirty files, authorization, filters, and stable pagination.
- Match case-insensitively; do not promise accent-insensitive Vietnamese search.
- Never return landlord contact details as a side effect of searching names.
- A complete listing UUID must not match a decoy title containing that UUID.

## Review Focus

- Searches must match rooms beyond the first page and return correct totals.
- Room UUID searches must coexist with exact moderation-item UUID deep links.
- Quotes, percent, underscore, and backslash must remain literal search input.
- Clear must cancel pending debounce, retain filters, and reset page to one.
- Narrow layouts, large text, stale responses, and session changes stay safe.

## Task 1: Backend Search

**Files:** `backend/src/admin/admin-console.service.ts`,
`backend/src/admin/admin-moderation-search.spec.ts`,
`backend/test/e2e/admin-inventory.e2e-spec.ts`.

- [x] Write and run failing queue-search tests for related names/IDs, filters,
  SQL parameters, UUID exactness, and pagination.
- [x] Add relational search predicates for listings, reports, reviews, replies.
- [x] Run focused Jest tests and disposable-database acceptance tests.

## Task 2: Toolbar And Regression Checks

**Files:** `lib/features/admin/admin_workspace_screen.dart`,
`test/features/admin/admin_moderation_search_test.dart`.

- [x] Write and run failing widget tests for debounce, filters, clear, empty
  results, exact initial filters, and narrow layouts.
- [x] Add moderation-specific hints, clear action, and empty-state copy.
- [x] Run targeted and adjacent Flutter tests, analyzer, backend build, and
  visually inspect rendered toolbar captures.

## Verification And Decisions

- Backend regression: 24 Jest suites / 400 tests pass; Nest build passes.
- Database acceptance: 6 suites / 45 tests pass using the repository's runner;
  migrations apply only to its disposable database, which is dropped afterward.
- Flutter regression: 5 files / 51 tests, including 9 search-specific tests.
- Analyzer and formatting checks target the changed Dart files only.
- Rendered widget captures inspected at desktop and 320/390px with text scales
  1.0 and 1.5. This is widget-render evidence, not a physical-device test.
- Ruling: keep the shared pending SQL unchanged; correlated predicates extend
  console searches without affecting health checks and moderation reports.
- Ruling: retain exact UUID item matching and add room UUID matching; partial
  room IDs use literal substring matching. Existing UUID deep-link E2E passes.
- No new dependencies or migrations; no commit, deployment, or production writes.
- Residual limits: no accent folding or production-scale performance benchmark.
