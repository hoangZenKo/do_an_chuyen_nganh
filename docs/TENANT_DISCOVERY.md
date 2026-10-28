# Tenant discovery: first release

This release implements steps 0-4 of the agreed tenant plan. It adds public
room discovery alongside the existing landlord management and tenant portal.
It does not implement favorites, viewing requests, reservations, payments
between parties, or linking an existing seeker account to a rental contract.

## Local startup

Backend source: `backend`.

```sh
cd /Users/hoang/Rental_room_management/backend
npm run prisma:generate
npm run prisma:deploy
npm run start:dev
```

Use the existing local database configuration. The new migration adds
`ListingStatus` and `RoomListing`; it does not publish or delete existing rooms.
Never run database reset commands against the local working database.

```sh
cd /Users/hoang/Rental_room_management
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## Manual walkthrough

1. Landlord: Dashboard > Menu > Tin dang (Vietnamese label: Tin đăng).
2. Create a listing for an owned vacant room. Enter public description, location,
   monthly rent, deposit, electricity price per kWh, water price per cubic meter,
   monthly service fee, area, amenities, and up to 12 actual room photos.
3. Save the draft, then submit it for review.
4. Admin: Admin Console > Kiem duyet tin dang (Kiểm duyệt tin đăng).
   Open the card to review every photo and charge. Approve or reject with a reason.
5. Use the discovery icon in listing management to open the public catalog.
6. Guest: Login > Kham pha phong khong can dang nhap
   (Khám phá phòng không cần đăng nhập), or complete onboarding and reopen the app.
7. New user: Register > Tim thue phong (Tìm thuê phòng). Login opens discovery.
   The My Room tab explains that no rental profile has been linked yet.
8. Existing tenant: My Room retains the original portal, contracts, invoices,
   notifications, payment proofs, and maintenance functionality.

An empty public catalog is expected until an admin approves a listing. Do not
invent listings, reuse payment-proof photos, or publish private room records to
make this screen look populated. Failed image requests show a neutral placeholder,
not unrelated stock photos.

## Account and access contract

- `POST /auth/register` still creates landlords, preserving old clients.
- `POST /auth/register-seeker` creates a `TENANT` user without a `Tenant` record.
- Both endpoints accept the existing registration fields, not an arbitrary role.
- Discovery routes `/explore`, `/explore/account`, `/explore/listings/:id` are public.
- Initial public deep links survive session restoration through a validated splash
  destination. Management and private tenant routes remain protected.
- Opening discovery or registering does not grant access to a contract or invoice.
- A missing rental profile is an onboarding state; a server failure is shown as
  an error with retry, not interpreted as an absent room.

## Listing APIs

All paths below are relative to `/api/v1`.

| Method | Path | Access |
| --- | --- | --- |
| GET | `/public/listings` | Public |
| GET | `/public/listings/:id` | Public, visible listings only |
| GET / POST | `/listings` | Landlord, owned rooms only |
| PATCH | `/listings/:id` | Owning landlord |
| POST | `/listings/:id/submit` | Owning landlord |
| POST | `/listings/:id/hide` | Owning landlord |
| GET | `/admin/listings` | Admin |
| POST | `/admin/listings/:id/review` | Admin |

Public filters: `search`, `city`, `district`, `minPrice`, `maxPrice`, `minArea`,
`amenity`, `sort=newest|price_asc|price_desc`, `page`, and `limit` (maximum 50).
Management adds `status=DRAFT|PENDING|PUBLISHED|REJECTED|HIDDEN`.
The list envelope is `{data: [...], meta: {total, page, limit}}`.

Creation accepts the public content plus `roomId`. Updates accept the full public
content plus `version`; moving a listing to a different room is not supported.
Submission and hiding accept `{version}`. Review accepts
`{version, decision: "PUBLISH" | "REJECT" | "HIDE", note?}`.
Rejection and admin hiding require a nonempty reason.

## Publication rules

- One listing per room. Existing rooms do not become listings automatically.
- Draft/rejected/hidden -> pending -> published or rejected.
- Editing immediately withdraws the old publication and resets the listing to
  draft. The changed content needs fresh review.
- Landlords can withdraw their own listings. Admins can hide published listings.
- Every mutation increments `version`; stale updates/reviews fail with 409.
- Mutation and audit record are committed in the same transaction.
- Public queries require a published listing, vacant active room, non-archived
  property, and active landlord. Details use the same rule as search.
- No private room notes, tenant names, user contact fields, landlord IDs,
  contracts, invoices, or review notes are serialized by the public API.
- Fees and description are explicit listing content, independent from operational
  room records. A future contract must confirm actual rental terms.
- Existing upload paths and HTTP(S) photo URLs are supported. Only upload images
  intended to be public. Private-document storage hardening is not part of this
  release.

## Verification

Flutter:

```sh
flutter analyze
flutter test --reporter expanded
```

Backend:

```sh
npm run build
npm test -- --runInBand
```

Run E2E tests only against a dedicated disposable test database, after deploying
all migrations there. `test/e2e/e2e-fixtures.ts` deletes test data between cases.
Never point it at `rental_management`. The chatbot suite additionally requires
a local database named `rental_chatbot_test_*`.

```sh
NODE_ENV=test DATABASE_URL="$TEST_DATABASE_URL" CHATBOT_ENABLED=false \
  npm run test:e2e -- --testPathPattern=listings.e2e-spec
```

The new tests cover anonymous visibility, owner/role isolation, duplicate rooms,
approval transitions, concurrent/stale reviews, edited-content withdrawal,
inactive/occupied/archived records, filters, parsing, timeouts, small screens,
new-user empty states, draft validation and management account switching.

## Local verification (2026-10-23)

- Flutter analyzer: no issues. Full Flutter suite: 170 passed.
- Backend build: passed. Unit suite: 146 passed, 7 existing skipped tests.
- Listing E2E suite: 7 passed against a separate test database.
- Full backend E2E suite: 37 passed, 2 failed in unchanged billing/dashboard tests.
  `lease-billing-dashboard.e2e-spec.ts` creates an August invoice but expects it in
  the current month's dashboard. `tenant-portal-priority.e2e-spec.ts` expects
  3,650,000 while the response is 3,670,000 for its fixture. These tests were not
  changed as part of the discovery slice.
- iPhone 16 simulator: built and launched the discovery route against the local
  API. The working database has no published listings, so the real empty state
  is shown. No existing room was published automatically.

## Student discovery A-B-C (2026-10-23)

The student-facing slice extends the public catalog while keeping the existing
two-column mobile layout and the private rental portal separate.

### A. Campus and radius

- Explore > Bo loc (Bộ lọc): select a campus and a 1, 3, 5 or 10 km radius.
- The API supports `campusId` and `radiusKm` (0.1-50, default 5). Filtering
  happens before pagination; the result includes `distanceKm`.
- Distances use coordinates and the Haversine formula, not road directions,
  walking time or a map provider. Listings without coordinates are excluded
  when a campus is selected.
- Landlords can enter or clear a latitude/longitude pair in the listing form.
  Changing listing content withdraws the publication until it is reviewed.
- `GET /public/campuses` is public. `POST /admin/campuses` is admin-only and
  accepts `name`, `campus`, `city`, `address`, `latitude`, and `longitude`.
  Real campus creation is currently API-only; verify coordinates before import.

### B. Budget and comparison

- Select 2-3 cards using their comparison icon, then tap So sanh (So sánh).
- The detail and comparison screens estimate rent + electricity + water +
  service + parking per month, per-person sharing, and deposit + first-month
  budget. Default usage is 50 kWh, 3 cubic meters and one person; all usage
  inputs are editable and validated.
- These are estimates, not invoices or a demand to pay in advance. Undeclared
  charges, purchases and Internet outside the service fee are not included.
- Comparison reloads details on entry and provides a refresh action. Failed
  or withdrawn listings do not reuse stale prices. Campus distance is labeled
  as the straight-line estimate at selection time.
- Selection is in-memory, limited to three, and cleared on account or campus
  changes. It is not a persistent favorites feature.

### C. Trust and reports

- Details distinguish content approval, landlord identity verification,
  physical inspection and the landlord's last availability confirmation.
  Missing verification is shown explicitly, never inferred from approval.
- An owning landlord can call `POST /listings/:id/confirm-availability` with
  `{version}`. The management UI exposes this for published listings.
- Admins can record or revoke verification through the published listing's
  Xac minh (Xác minh) action or `POST /admin/listings/:id/verification` with
  `{version, landlordVerified, roomInspected, note}`. Evidence notes are
  mandatory (at least 10 characters) and are not returned publicly.
- Editing content clears verification and availability confirmation. Review
  and verification use optimistic versions and transactional audit records.
- Signed-in tenant/seeker accounts can submit one report per listing through
  `POST /student/listings/:id/reports` with `{reason, detail}`. Supported reasons
  are `wrong_price`, `wrong_photos`, `unavailable`, `suspected_scam`, and `other`;
  detail must contain 10-2000 characters. Duplicate reports return 409.
- Admin management > report icon opens the paginated report queue.
  `GET /admin/listings/reports` and
  `POST /admin/listings/reports/:id/review` are admin-only. Review accepts
  `{status: "RESOLVED" | "DISMISSED", note}`. Closing a report does not hide
  the listing automatically; use the existing moderation action when needed.
- Verification is not a guarantee of transaction safety. Do not place identity
  documents, bank account details or other sensitive data in reports/notes.

### Local migration and demo data

The additive migration is `20261023010000_student_discovery`. It adds campus
and report tables plus listing coordinates, parking and verification dates.
It does not reset existing operational data.

```sh
cd /Users/hoang/Rental_room_management/backend
npm run prisma:generate
npm run prisma:deploy
# Optional, local development only, after the existing Explore fixtures:
npx tsx prisma/seed-student-discovery.ts
```

The local preview currently has 600 demo listings and six explicitly fictional
campuses. This seed adds simulated coordinates only to the dedicated demo
landlord's marked listings that lack coordinates. Re-running does not overwrite
coordinates or create verification claims. Campus names, coordinates, listings
and photos in these fixtures must not be presented as real rental offers or
real university locations. Never run preview seeds in production.

Validation for this slice: all 182 Flutter tests pass, the targeted Flutter
analyzer reports no issues, the API builds, and all 11 listing E2E tests pass
against the separate `rental_student_discovery_test` database. E2E fixtures
must never target the working preview database.

## Next release scope

Add favorites and viewing requests after this slice is accepted. Linking a seeker
to existing landlord-scoped tenant records needs its own verified identity flow
and migration of the current unique `Tenant.userId` relationship. Do not auto-link
using a matching name, email supplied by a third party, or phone number alone.
