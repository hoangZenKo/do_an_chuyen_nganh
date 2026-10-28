# Invoice line items and versioned service tariffs

## What changed

- Every newly created invoice stores immutable `InvoiceLineItem` snapshots.
- Service fees use `ServiceTariffVersion` records with an effective billing month and version number.
- Single billing, bulk billing, preflight, scheduled billing, landlord invoice APIs, and tenant invoice APIs use the same effective tariff calculation.
- Existing invoices remain readable. If an old invoice has no line rows, the API exposes a compatibility breakdown from the legacy aggregate columns.

## Operational rules

1. Do not update or delete a tariff version. Create a new version with a later `effectiveFrom` month.
2. A tariff cannot be backdated or scheduled for a billing period that already has an invoice.
3. A billing line is copied into the invoice at creation time; changing a tariff never reprices that invoice.
4. Deleting a room service fee schedules a non-active version, defaulting to the next billing month or the month after its latest scheduled version. It preserves prior charges. The Flutter editor exposes the effective month explicitly.
5. The migration also installs database triggers that reject updates to tariff versions and invoice line snapshots.

## Deploy safely

The working database has not been migrated. Before deploying, follow the repository's backup and restore-rehearsal procedure (`backend/scripts/database-safety.mjs` / `npm run ops:migrate`). Do not use an unreviewed migration command against the working database.

Source validation without changing the working database:

```sh
cd backend
npx prisma generate
npm run build
npm test -- --runInBand
node --env-file=.env scripts/run-invoice-tariffs-e2e.mjs
```

Run the disposable E2E command only against a local PostgreSQL server. It creates a database named `rental_invoice_test_*`, rehearses the upgrade with legacy fee/invoice fixtures, verifies the backfill, runs seven invoice/tariff scenarios, and drops the database afterward. It never migrates, seeds, or resets the database named by the original URL.

The migration converts old invoice aggregates into `LEGACY` lines, without inventing original quantities or tariff provenance. Existing service fees receive a baseline version effective on 1970-01-01 using their last known values; this is a compatibility baseline, not reconstructed historical price evidence.

## API examples

- `POST /rooms/:roomId/service-fees` creates a fee and version 1.
- `PATCH /rooms/:roomId/service-fees/:feeId` appends the next tariff version, including activation/retirement changes; pass `expectedVersion` for optimistic concurrency. An unchanged activity-only request is a no-op.
- `GET /rooms/:roomId/service-fees/:feeId/versions` lists tariff history.
- `POST /billing/invoices` and `POST /billing/invoices/bulk` return `lineItems` in the invoice payload.
- `GET /billing/active-leases?month=2026-11-01` previews fixed fees for a selected billing month.

Dates use first-of-month UTC markers (`YYYY-MM-01`); default months follow Vietnam time. Each version applies from its effective month, inclusive, until the next version, exclusive. Versions are append-only and cannot reuse a date or precede the latest scheduled version. A future version cannot currently be replaced/cancelled; append a later correction.

These tariffs cover fixed room services (one unit per invoice). Electricity/water remain quantity-based meter-reading snapshots; this slice does not add progressive utility tariffs or property-wide tariff inheritance.
