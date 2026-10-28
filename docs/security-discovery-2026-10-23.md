# Stability and student discovery

Implemented on 2026-10-23 in this repository; the backend is located at
`backend`. This extends the first discovery release and
the housing journey; it does not replace favorites, viewing requests or leases.

## Where to use it

- Student: Explore -> Filters -> maximum total monthly budget, electricity
  usage, water usage, and availability confirmed within 14 days.
- Student: Explore -> Save search -> name the current filters. Open Saved
  searches to apply a filter, pause/resume it, delete it, or read matching
  listing alerts. An unread count appears on Explore when available.
- Admin: Listing moderation -> school icon -> create/edit campus names,
  addresses, coordinates, an optional HTTPS source, and active state.
- Landlord: My listings -> stale published listings display a reminder to
  confirm availability. Confirmation uses the existing version-checked action.
- Billing: payment-proof attachments now open through authorized temporary
  links instead of copying permanently public file URLs.

The existing two-column Explore layout is preserved. Large accessibility text
and very narrow windows retain their existing single-column fallback.

## Estimate and freshness semantics

Monthly estimate = rent + electricity rate * kWh + water rate * cubic meters
+ service fee + parking. Defaults are 50 kWh and 3 cubic meters for the whole
room. These are adjustable assumptions, not metered consumption or a price
guarantee. Deposits and undeclared extra charges are not included. Server-side
filtering, saved searches and listing-card estimates use the same assumptions.

Freshness means the landlord last confirmed availability within 14 days. It
does not independently verify that a room is vacant or that a transaction is
safe. Campus distances remain straight-line estimates, not travel times.

The existing six campuses are explicitly fictional demo data. This change
adds an admin editor, not a fabricated catalog of real university locations.
Admins must obtain and check real addresses and coordinates before publishing
them. Editing a demo campus does not remove its demo label.

## Saved searches and notifications

- Up to 10 saved filters per student, persisted in PostgreSQL by account.
- Newly published matching listings create deduplicated in-app alerts. Existing
  listings are not replayed when a filter is first saved. Re-enabling a paused
  filter starts from the resume time rather than backfilling the paused period.
- All matching pages are scanned, not just the first 50 results. Alert history
  is paginated at 20 records. Withdrawn/unavailable listings are hidden.
- Refreshing Explore or the alert list checks that student's filters. A backend
  worker also runs every 15 minutes, processing up to 100 searches per batch in
  round-robin order. Larger installations therefore require multiple intervals.
- This is not push, email, SMS, or an always-running mobile background task.
  The backend must be running. The worker is disabled under `NODE_ENV=test`.
- Inactive campuses pause matching until they become active again. Inactive
  accounts are not scanned. Account ownership is checked for every operation.

## Stability and private files

- Payment-proof review locks the proof before checking its pending status and
  crediting the invoice. Concurrent duplicate reviews yield one success and
  one conflict, not two credits.
- Deposit refunds/deductions lock the lease and check the recorded ledger
  balance inside the same transaction. Over-refunds return HTTP 409. Monetary
  and date validation rejects relevant invalid input before database writes.
- Password changes increment the account session version and revoke all
  refresh tokens. Existing access tokens and private file links stop working.
  Flutter clears its local session and returns to sign-in.
- Uploads default to private. The backend checks supported file signatures and
  an 8 MiB limit rather than trusting an extension/MIME claim. This is not an
  antivirus or full document/image decoder.
- Only a landlord can explicitly upload a `PUBLIC_LISTING` image. Private files
  require an authenticated access-link request; links expire after 300 seconds,
  bind to the account session version, and recheck authorization when opened.
  Treat these temporary links as bearer secrets while valid.
- Proof, maintenance, room/asset and expense access follows ownership and module
  permissions. New requests cannot attach another account's inaccessible local
  upload to gain access through their own resource. Staff permissions are checked.
- Local file responses use `nosniff`, private/no-store caching, and a sandbox
  policy. PDFs are served as attachments. External file/image URLs are outside
  this server's access-control boundary.

## Migration and rollout

The additive backend migration is
`prisma/migrations/20261023120000_security_discovery/migration.sql`.
Generate the Prisma client, deploy migrations, build/restart the API and rebuild
or hot-restart Flutter when rolling out elsewhere. Do not reset or run test
fixtures against the working database.

The migration classifies existing local uploads using their stored references.
Private references take precedence if a file was also used on a listing. Files
without a recognized owner/reference stay inaccessible; re-upload them from the
correct account. If a legacy listing shared a private attachment, upload a
separate public listing image rather than making the private file public.
`UPLOADS_DIR` can select a dedicated upload directory; without it the backend
uses its existing `uploads/` folder.

Local rollout preserved all 600 listings, six demo campuses and four accounts.
It also applied the already-pending housing-journey migration. No search alerts
or synthetic accounts were inserted into the working database.

## Validation

- Flutter: analyzer clean; 206 automated tests pass.
- Backend: build succeeds; 164 unit tests pass, seven existing tests skipped;
  all 63 E2E tests pass, including nine new security/discovery regressions.
- E2E uses only `rental_chatbot_test_audit_20261023`, with temporary upload
  directories removed after the tests. No interactive testing on the user's
  running app was used.
- Regression coverage includes concurrent approvals/refunds, private-file
  denial, forged attachment references, expired/tampered links, staff permissions,
  password revocation, budget/freshness, admin campuses, account isolation,
  paused/limited searches, and scanning more than 50 matching listings.
- Previously stale E2E assertions now use the actual invoice arithmetic,
  current-month semantics, no reminder after full payment, and the existing
  Zalo `purpose` response contract. The underlying billing amounts were not
  changed to satisfy the tests.

This is targeted hardening, not a guarantee that every project defect is gone.
Password recovery delivery, Remember Me, device push and external file storage
are not implemented by this change.
