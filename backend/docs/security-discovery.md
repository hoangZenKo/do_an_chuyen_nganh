# Security and discovery additions (2026-10-23)

Implementation and rollout notes are maintained in the repository documentation:
`../../docs/security-discovery-2026-10-23.md` (relative to this document).

## API contracts

All API paths below are under `/api/v1`.

- `GET /public/listings`: adds optional `maxBudget` (integer VND),
  `electricityKwh` (default 50), `waterM3` (default 3), `freshOnly` (boolean).
  Public results include `estimatedMonthlyCost` and `availabilityFresh`.
- `GET /public/campuses`: active campuses only; demo entries remain labeled.
- Admin `GET/POST /admin/campuses`, `PATCH /admin/campuses/:id`:
  name, campus, city, address, latitude, longitude, optional HTTPS sourceUrl.
  Update also requires isActive; null sourceUrl clears the source.
- Tenant `GET/POST /student/searches`: create with `{name, filters}`. Filters
  use the public-listing query contract; page/limit are not persisted.
- Tenant `PATCH /student/searches/:id`: `{enabled}`; `DELETE` removes a filter
  and its alerts. Ownership is checked even when the identifier is known.
- Tenant `GET /student/searches/alerts?page=1`: 20 items with total/unread metadata;
  checks that account's filters before returning. Published/public fields only.
- Tenant `POST /student/searches/alerts/:id/read`: marks one owned alert read.
- Authenticated `POST /uploads`: multipart `file`, optional `purpose`
  (`PRIVATE`, default; `PUBLIC_LISTING`, landlord images only), max 8 MiB.
- Authenticated `GET /uploads/:filename/access`: `{data:{url,expiresInSeconds}}`.
  Private file URLs expire after 300 seconds and are session-bound.
- `GET /uploads/:filename?access=...` is outside the API prefix. Do not mount a
  public static server on that path or bypass the application through Nginx.

`20261023120000_security_discovery` is an additive migration. Apply it and run
`npm run prisma:generate` before starting the updated server. Existing referenced
files are classified; unknown files fail closed. Private metadata takes priority
over legacy public listing references. JWTs without a session version remain valid
only while the account version is zero; a password change revokes them too.

Uploads use `UPLOADS_DIR` when configured, otherwise `./uploads` relative to the
backend working directory. Keep this persistent across server restarts. The
existing-file backfill does not copy files to a different directory.

Saved-search scanning runs in-process every 15 minutes, at most 100 searches per
background batch; on-demand refresh scans up to ten owned filters. Alert insertion
and cursor advancement are atomic; a row lock/CAS and a unique search/listing key
avoid duplicate delivery during concurrent scans. This is in-app delivery only.

Tests: `npm run build`, `npm test -- --runInBand`, and `npm run test:e2e` with an
isolated local test database. Chatbot E2E additionally requires the database name
to start with `rental_chatbot_test_`. The shared harness isolates uploaded files in
temporary directories. Never point E2E fixtures at the working database.
