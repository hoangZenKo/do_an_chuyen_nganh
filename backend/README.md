# Rental Room API

NestJS REST API for the Rental Room Management Flutter application. This directory
is part of the same repository as the Flutter client. Run backend commands from
`backend/` and Flutter commands from the repository root.

## Stack

- NestJS + TypeScript
- Prisma ORM
- PostgreSQL
- Argon2 password and refresh-token hashing
- JWT access tokens with rotating opaque refresh tokens

## Local setup (native PostgreSQL — recommended)

Install and start PostgreSQL 16 with Homebrew:

```bash
brew install postgresql@16
brew services start postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
pg_isready -h 127.0.0.1 -p 5432
```

Create the local role and database, then configure the ignored `.env` file with a local password:

```env
DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management?schema=public"
```

Install dependencies and apply the committed migrations:

```bash
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:deploy
npm run start:dev
```

The local database is a fresh native database. Docker data is not migrated automatically.

## Optional Docker PostgreSQL fallback

Docker remains available as a separate local database:

```bash
docker compose up -d postgres
```

Do not run native and Docker PostgreSQL simultaneously on port `5432`. Do not use `docker compose down -v` during this switch because it removes the Docker database volume.

For a fresh database with the existing migration history, use `npm run prisma:deploy`. Use `npx prisma migrate dev --name <descriptive-change>` only after deliberately changing the Prisma schema.

### Native PostgreSQL commands

```bash
brew services start postgresql@16
brew services stop postgresql@16
pg_isready -h 127.0.0.1 -p 5432
```

### Docker fallback commands

```bash
docker compose up -d postgres
docker compose stop postgres
```

## Start the API

```bash
npm run start:dev
```

Health check:

```bash
curl http://localhost:3000/api/v1/health
```

Expected response:

```json
{
  "status": "ok",
  "database": "ok"
}
```

## Useful scripts

```bash
npm run prisma:generate   # regenerate Prisma client after schema changes
npm run prisma:deploy     # apply committed migrations
npm run prisma:migrate    # create/apply a development migration
npm run build             # compile the NestJS app
npm test                  # run unit tests
npm run test:e2e          # run E2E tests against a test database
npm run admin:bootstrap   # create an admin from environment variables
```

E2E tests call `resetDatabase()`, so they intentionally refuse to run unless `NODE_ENV=test` and `DATABASE_URL` points to a database whose URL contains `test`.

Example:

```bash
DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management_test?schema=public" npm run prisma:deploy
DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management_test?schema=public" npm run test:e2e
```

## Response conventions

Successful API responses use a data envelope:

```json
{
  "data": {}
}
```

Business errors use an error envelope:

```json
{
  "error": {
    "code": "INVOICE_NOT_FOUND",
    "message": "Invoice not found."
  }
}
```

Cross-landlord resource lookups return `404` to avoid exposing whether another landlord's resource exists. Admin accounts receive `403 Forbidden` from landlord-only endpoints.

## Auth endpoints

```text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

Public registration always creates a `landlord`. It never accepts a role from the client.

## Authorization policy

Wire/API roles are lowercase: `landlord` and `admin`.

- `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, and `GET /health` are public endpoints.
- `GET /auth/me` requires a valid access token and is available to both `landlord` and `admin` accounts.
- Landlord resource endpoints are protected by the backend role guard and require `landlord`:
  - `/dashboard/...`
  - `/properties...`
  - `/rooms...`
  - `/tenants...`
  - `/leases...`
  - `/billing...`
- Admin endpoints require `admin` and are available under `/admin/...`.
- Landlord ownership checks remain in services. Cross-landlord resource lookups continue to return `404` so another landlord's resource existence is not exposed.

## Landlord API overview

### Properties

```text
GET    /api/v1/properties
POST   /api/v1/properties
GET    /api/v1/properties/:id
PATCH  /api/v1/properties/:id
PATCH  /api/v1/properties/:id/status
DELETE /api/v1/properties/:id
```

### Rooms

```text
GET    /api/v1/properties/:propertyId/rooms
POST   /api/v1/properties/:propertyId/rooms
GET    /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id/status
DELETE /api/v1/rooms/:id
```

### Tenants

```text
GET    /api/v1/tenants
POST   /api/v1/tenants
GET    /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id/status
DELETE /api/v1/tenants/:id
```

### Leases

```text
POST /api/v1/leases
POST /api/v1/leases/:id/end
GET  /api/v1/rooms/:roomId/leases
GET  /api/v1/tenants/:tenantId/leases
```

Creating a lease marks the room as occupied. Ending a lease marks the room as vacant again.

### Billing

```text
GET  /api/v1/billing/active-leases
GET  /api/v1/billing/meter-readings
POST /api/v1/billing/meter-readings
GET  /api/v1/billing/invoices
POST /api/v1/billing/invoices
GET  /api/v1/billing/invoices/:id
POST /api/v1/billing/invoices/:id/payments
POST /api/v1/billing/invoices/:id/cancel
POST /api/v1/billing/invoices/:invoiceId/payments/:paymentId/reverse
```

Billing rules:

- Invoice months are normalized to the first day of the UTC month.
- An invoice can only be created for an active lease and for a billing month inside the lease period.
- One invoice is allowed per `(leaseId, billingMonth)`.
- One meter reading is allowed per `(roomId, utilityType, billingMonth)`.
- Payment amounts must be positive and cannot exceed the invoice remaining balance.
- Fully paid invoices reject additional payments.
- Cancelled invoices reject new payments.
- Payment corrections are handled through reversal payments instead of editing or deleting the original payment.
- A reversal payment is a signed ledger entry with a negative amount and a `reversalOfPaymentId` pointing to the original payment.
- A payment can be reversed only once, and reversal payments cannot be reversed.
- An invoice can be cancelled only if it has no payment history. An invoice that had a payment and later had that payment reversed still cannot be cancelled.

Common billing error codes:

```text
INVOICE_NOT_FOUND
LEASE_NOT_FOUND
LEASE_NOT_ACTIVE
BILLING_MONTH_OUTSIDE_LEASE
INVOICE_EXISTS
METER_READING_EXISTS
INVALID_METER_READING
INVALID_UNIT_PRICE
INVALID_BILLING_MONTH
INVALID_DUE_DATE
INVALID_PAID_AT
INVALID_INVOICE_STATUS
INVOICE_CANCELLED
INVOICE_ALREADY_PAID
PAYMENT_EXCEEDS_REMAINING
PAYMENT_NOT_FOUND
PAYMENT_ALREADY_REVERSED
PAYMENT_REVERSAL_NOT_ALLOWED
INVOICE_HAS_PAYMENTS
INVOICE_ALREADY_CANCELLED
```

### Dashboard

```text
GET /api/v1/dashboard/metrics
```

Dashboard revenue is calculated from signed payment ledger entries. Normal payments increase received revenue; reversal payments are negative entries and reduce revenue in the month of the reversal `paidAt` date. Cancelled invoices are excluded from billing totals.

## Admin API overview

```text
GET   /api/v1/admin/overview
GET   /api/v1/admin/landlords
POST  /api/v1/admin/landlords
GET   /api/v1/admin/landlords/:id
PATCH /api/v1/admin/landlords/:id
PATCH /api/v1/admin/landlords/:id/status
GET   /api/v1/admin/properties
POST  /api/v1/admin/properties
GET   /api/v1/admin/properties/:id
PATCH /api/v1/admin/properties/:id
```

Admin APIs are role-protected and are separate from landlord-scoped resource APIs.

## Bootstrap an admin

Set the values only in a local environment or secret manager:

```bash
export ADMIN_BOOTSTRAP_EMAIL=admin@atrium.com
export ADMIN_BOOTSTRAP_NAME='Project Admin'
export ADMIN_BOOTSTRAP_PASSWORD='use-a-unique-password-with-12-chars'
npm run admin:bootstrap
```

The command refuses weak/default passwords and refuses to convert an existing landlord into an admin. It stores only an Argon2id hash.

## P1 operations and online payments

P1 adds room-turnover workflows, recurring operation checklists, scheduled
in-app announcements with read receipts, and an internal demo-card checkout.
Apply Prisma migrations before starting the API. The worker runs every minute
outside test mode; `OPERATIONS_SCHEDULER_ENABLED=false` disables it.

The payment demo has no payOS, bank, Stripe, Visa or external webhook dependency.
Enable it only locally with `DEMO_PAYMENTS_ENABLED=true` and a random
`DEMO_CHECKOUT_SECRET` of at least 32 characters. `DEMO_PAYMENT_BASE_URL` must
match the API origin, for example `http://localhost:3000`. Only a separate
`isDemo=true` invoice can be settled; the test card is `4242 4242 4242 4242`
with a future `MM/YY` expiry and CVC `123`. Production always rejects this flow.

To prepare the sample account, run `npm run demo:prepare`. The app can also
create a separate 10,000 VND demo invoice from an existing tenant invoice; the
original invoice remains unchanged. Demo invoices are excluded from reports,
financial summaries and real payment reminders.

Full setup, UI entry points, local verification and production limitations:
`../docs/p1-operations-2026-10-24.md`.

## Flutter connection

The Flutter app defaults to `http://localhost:3000/api/v1` for local development. For a different environment:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Use an HTTPS endpoint for physical devices and production.
