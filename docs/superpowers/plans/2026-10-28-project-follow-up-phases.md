# Project Follow-up Phases Implementation Plan

**Goal:** Execute the five follow-up phases requested after Admin UI consolidation without replacing existing workflows or claiming external acceptance from local tests.

**Architecture:** Reuse NestJS/Prisma services and the Flutter Admin shell. Implement thin API-to-UI slices with regression tests. No working-database mutation, automatic capability elevation, new dependencies, branches or commits.

**Spec:** The latest roadmap in this conversation: (1) Admin operational gaps, (2) real payment/revenue integration, (3) landlord/tenant workflows, (4) quality, (5) product expansion. These are NOT the phase numbers in `2026-10-28-admin-console-completion.md`.

## Scope Corrections

- Admin invitation, password recovery, role presets, lifecycle, global read-only investigation, audit export and teams already exist. Extend gaps rather than duplicate them.
- Marketplace, viewing slots, saved searches and chatbot source already exist. Their existence does not establish provider/device acceptance.
- Subscription assignments are administrative entitlements, not paid checkout or settlement. Rent is not platform revenue.

## Execution Ledger

### Phase 1: Explicit Administrator Capabilities

- [x] Add validated optional explicit permissions to the existing versioned Admin profile command.
- [x] Reject unknown/duplicate grants, self-change, grants outside the actor's permissions, partial super-admin profiles and last-super-admin removal.
- [x] Preserve default preset behavior for existing clients, session revocation, review invalidation and before/after audit.
- [x] Add a shared-theme editor showing effective permissions and preset differences; prevent submission after session/permission loss.
- [x] Verify unit, HTTP, widget and isolated database regressions where available.

Files: `backend/src/admin/admin-console.dto.ts`, `admin-console.service.ts`, `lib/features/admin/admin_workspace_screen.dart`, a focused permissions editor and tests.

### Phase 2: Real Subscription Payments

- [ ] Confirm payment provider, merchant account, subscription pricing/currency/term and settlement/refund contract.
- [ ] Implement provider checkout, verified idempotent webhook and settlement-backed revenue only after that contract is available.
- [ ] Verify signed provider fixtures and staging credentials; never use demo payments to claim settlement.

External dependency: no provider/merchant contract selected in this conversation. Keep revenue explicitly unavailable; do not fabricate paid events or change the working DB.

### Phase 3: Core Workflow Follow-through

- [x] Verify existing lifecycle/tariff/payment-proof entry points before extending them.
- [x] Close an identified landlord dashboard-to-overdue-invoice navigation gap using existing filters and ownership checks.
- [x] Run focused tests; retain device/provider acceptance as separate open gates.

Delivered slice only: overdue navigation and filter initialization. This does not mark every landlord/tenant workflow complete. Existing lifecycle, tariffs and payment-proof APIs remain unchanged.

### Phase 4: Quality Gates

- [x] Reproduce the dashboard/chatbot navigation failures before fixes.
- [x] Correct actual layout/accessibility issues and update obsolete interaction assumptions only when demonstrated.
- [x] Run Flutter tests, targeted analysis, backend tests/build and record current evidence.

### Phase 5: Product Expansion

- [x] Inventory existing discovery/viewing/chatbot capabilities before choosing a missing vertical slice.
- [x] Do not add native push, chat transports or paid AI providers without confirmed delivery/identity contracts.
- [x] Record incomplete scope explicitly instead of calling all five phases complete.
- [ ] Select and implement a new product-expansion vertical slice with acceptance criteria.

Inventory: `lib/features/listings/saved_searches_screen.dart`, `viewing_slots_screen.dart`, `discovery_tools.dart`, `lib/features/chatbot/`, `backend/src/listings/saved-searches.service.ts`, `backend/src/housing/viewing-reminder.worker.ts` and `backend/src/chatbot/`. Presence in source is not end-to-end/provider acceptance. No new chat/push transport shipped in this pass.

## Verification Checkpoint: 2026-10-28

- `flutter test`: 637 passed, no failures. The previous 11 dashboard/chatbot failures are resolved. Log: `/tmp/rental-followup-flutter-final.log`.
- `npm test -- --runInBand`: 716 passed, 7 skipped; 69 passing suites, 1 skipped. Log: `/tmp/rental-followup-backend-final.log`.
- `npm run build`: passed. Log: `/tmp/rental-followup-build-final.log`.
- `npm run test:admin-accounts:e2e`: 42 passed across six suites against a generated disposable PostgreSQL database; runner dropped it afterward. Expected injected 500/503 cases are not test failures. Log: `/tmp/rental-followup-admin-e2e-final.log`.
- `flutter analyze` on the new permissions editor, resource provider and three focused test files: no issues. Broader touched-file analysis still reports two existing unused dashboard sections and two const hints; no whole-project clean-analyzer claim.
- iOS simulator debug build passed. Inspected the permissions dialog on iPhone 16/iOS 18.4 using isolated fixtures under a separate preview bundle ID; uninstalled that preview and removed its temporary entrypoint afterward. Screenshot: `/tmp/rental-followup-admin-permissions-ios.png`. This is a visual spot check, not a real login/API acceptance run.
- `git diff --check`: passed. Local self-review checked delegation ceilings on explicit grants, preset changes and invitations, stale drafts, session revocation and audit boundaries; no independent-review claim.
- No new dependency, migration, working-database mutation, real payment/email, branch, commit or deployment.

## Review Focus

- Current-account switches and capability loss must disable old mutation forms.
- Failed/ambiguous writes must require a fresh read, not automatic replay.
- Existing preset clients must retain their command semantics.
- Any permission changes invalidate sessions and access-review evidence atomically.
- Financial and provider claims must be supported by real sources, not inferred from UI/tests.
