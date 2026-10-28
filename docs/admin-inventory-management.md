# Admin property and room inventory

Implemented 2026-10-27. Plan: `tasks/admin-inventory-plan.md`.

## Scope

- Property list/detail and read-only room inventory use real backend data.
- No new property approval state, publishing gate or database schema is added.
- Existing property creation/update and listing moderation remain the write paths.
- Room occupancy, internal rent, leases and billing are not mutated by this UI.

## Permissions and privacy

| Operation | Capability |
| --- | --- |
| List/detail properties, list rooms | `admin.properties.view` |
| Create/update a property | `admin.properties.manage` |
| Claim/review a pending listing | `admin.listings.moderate` |

The existing support preset can inspect inventory without editing. The moderator
preset is not silently granted inventory access. An operator needs both inventory
view and listing moderation rights to use the review shortcut from a room card.
Capability checks exist in the route guard, UI/provider and backend. Writes bind
the request to its original account identity. Search/filter state resets when
the account changes, old responses are hidden, and a read-only account cannot
use a direct property form URL or controller call to write.

Inventory uses explicit database field projections. Landlord email/phone are
masked; tenant names, room notes, leases, invoices, financial records and private
landlord documents are not included. All inventory GET responses have
`Cache-Control: private, no-store`.

## API contracts

- `GET /api/v1/admin/properties`: `page`, `limit`, `search`, `landlordId`,
  `archived=all|active|archived`, `ownerStatus=all|active|inactive`.
- `GET /api/v1/admin/properties/:id`: lifecycle, masked owner, full occupancy
  counts and at most 20 rooms, ordered by name then ID. Room status remains
  lowercase here for compatibility with the existing detail contract.
- `GET /api/v1/admin/rooms`: `page`, `limit`, `search`, `propertyId`, `landlordId`,
  `status=VACANT|OCCUPIED|MAINTENANCE`, `activity=all|active|inactive`,
  `listingStatus=NONE|DRAFT|PENDING|PUBLISHED|REJECTED|HIDDEN`, `minPrice`,
  `maxPrice`. `NONE` means no related listing, not a draft listing.
- Lists retain `{data, meta: {page, limit, total, pages}}`. Room defaults are
  page 1/limit 20; limit is at most 100. Results are stable by createdAt DESC/ID
  ASC. Count and page/preview reads use repeatable-read transactions.
- Price bounds apply to **Room.basePrice**, not advertised listing rent. Values
  must be whole numbers from 0 through 2147483647; reversed bounds are rejected.
- Room/listing fields expose separate `basePrice` and `listing.monthlyRent`;
  listing includes ID, title, status and version, or null when absent.

## Screens and moderation handoff

- `/admin/properties`: debounced search, archived/owner-status filters, server
  pagination and conditional create/edit actions. Detail/back preserves query.
- `/admin/properties/:id`: complete counts, masked owner, bounded room preview
  and a shortcut to `/admin/rooms?propertyId=...` for full pagination.
- `/admin/rooms`: search, occupancy/activity/listing filters and validated price
  bounds. Filter/search changes reset page 1; scope and price filters can be
  cleared explicitly. Empty/loading/retry/404 states do not expose raw errors.
- Only a pending listing with moderation permission offers the review shortcut.
  It pushes `/admin/moderation?kind=LISTING&search=<listing UUID>` into the
  existing workspace; claim, reason, version conflicts and audit are unchanged.
- A UUID queue search now means exact ID, including uppercase UUID input. It
  does not also match another listing's title containing that UUID. Ordinary
  non-UUID search still filters titles. No second moderation workflow is added.
- Listing review invalidates typed inventory; returning from the shortcut also
  refreshes it. Published/rejected/hidden/draft listings are not presented as
  items waiting in the pending queue.

## Verification and safe database testing

```sh
flutter test test/features/admin test/data/admin test/features/auth test/data/auth
cd backend
npm test -- --runInBand
npm run build
npm run test:admin-accounts:safety
npm run test:admin-inventory:e2e
```

The inventory command reuses the account runner, including the existing account,
console, next-sprint and operations-release acceptance suites. It creates a fresh
local `rental_admin_accounts_test_<timestamp>_<random>` database, applies existing
migrations only there, disables delivery/workers and drops only that generated
database in `finally`. Inventory tests check the target name and actual connected
database before resetting fixtures. Never run these reset-based suites directly
against `rental_management` or a shared database.

Acceptance includes view/write separation, query validation, a 25-room property
with a 20-room preview, all-room pagination, masked fields, filters using internal
rent, exact queue targeting despite a decoy title, claim/review/version conflicts,
unchanged room accounting and preserved property CRUD/audits.

Widget checks cover desktop and 320px/200% text, query/back navigation, session
and permission loss, form access and the actual moderation route. Optional
captures use `ADMIN_QA_OUTPUT=/tmp/admin-inventory-captures` with
`test/features/admin/admin_inventory_panel_test.dart`. These are widget renders,
not proof of a live-browser/device pass or an independent review. No deployment,
working-database migration, real email, commit or new branch is performed.

### Current evidence

- Inventory-focused backend/PII tests: 8 passed. Full backend unit run: 651
  passed, 7 skipped. Nest build passed.
- Disposable-database acceptance: 35 passed across 5 suites; runner safety:
  8 passed. No generated admin-test databases remain after the run.
- Inventory widgets: 13 passed; API contract regression: 12 passed; combined
  Admin/Auth/API regression: 168 passed. Targeted analyzer found no issues.
- Full Flutter run: 552 passed, 11 existing failures, all in
  `test/features/dashboard/dashboard_chatbot_entry_test.dart`, concerning the
  landlord floating navigation. They are outside this inventory change.
- `flutter build web --no-tree-shake-icons` was attempted and blocked by the
  existing missing `web/index.html`. No platform scaffold was generated to hide
  that gap. Live browser/device verification remains unperformed.
