# Phase 3: Admin property/room inventory

Approved: 2026-10-27, Asia/Ho_Chi_Minh.

## Scope and decisions

- No separate property approval state or publishing gate. Internal property/room,
  leases and billing behavior stays unchanged. No migration or production rollout.
- Preserve property CRUD. Read routes use the existing `admin.properties.view`
  capability; writes retain `admin.properties.manage`. Mask owner contacts.
- Property list: server pagination, debounced search, archived/owner-status filters.
- Property detail: real lifecycle/counts, bounded room preview with prices and
  listing state, navigation to the full property-filtered room list.
- Room list: read-only inventory, pagination, search, occupancy/active/listing-state
  and price filters. No admin rewrite of room occupancy or accounting data.
- Pending listing actions open the existing moderation workspace for the exact
  target; preserve claim, version, reason, audit and conflict handling.
- Reuse the established Admin visual language; support 320px and large text.
- Work in the dirty checkout; preserve unrelated changes and prior task evidence.

## Implementation slices

1. Backend contracts/tests: property read capability/no-store, bounded detail,
   paginated rooms and strict query validation. No tenant/financial/PII leakage.
2. Typed Flutter contracts/providers: retain metadata and filters; session-scoped
   queries, fail-closed permissions and cancellation/identity checks.
3. Property/room UI: filters, pagination, detail/navigation, correct read-only vs
   management actions, loading/error/empty states; reuse moderation workflow.
4. Verification: focused red/green tests, backend build/unit suite, Flutter
   Admin/Auth/API tests/analyzer, widget captures at desktop/mobile. Database E2E
   only through the disposable local runner, never the working database.

## Acceptance

- An authorized viewer can inspect any property/room without management rights.
- Search/filter resets the page; detail/back preserves the selected list query.
- Every room shows internal rent separately from advertised listing rent/status.
- A pending listing opens its exact queue item; other states are not mislabeled
  as pending. There is no duplicate property approval mechanism.
- Permission/session loss cannot render an old inventory response or send writes.
- Existing account, moderation, landlord, lease and billing tests stay intact.
