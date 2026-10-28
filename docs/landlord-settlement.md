# Landlord move-out settlement

## Scope

This is the first Landlord/Billing slice, not completion of the full roadmap.
The landlord opens **Tra phong & quyet toan** from the tenant's lease card.
Staff, tenants and platform admins cannot call settlement endpoints.

API prefix: `/api/v1/leases/:id/settlement`.

| Method | Suffix | Behavior |
| --- | --- | --- |
| GET | (none) | Read the persisted settlement, or `data: null`. |
| POST | `/preview` | Calculate charges and return `previewFingerprint`; no writes. |
| POST | `/confirm` | Recalculate under locks, compare fingerprint, settle and begin turnover. |
| POST | `/refund` | Record a completed external refund; does not transfer money. |

## Accounting rules

- Rent is prorated by actual calendar days in the move-out month, inclusive of the move-out date, rounded to integer VND.
- An existing non-cancelled, non-demo invoice for that month suppresses new rent charges. There is no automatic credit for prepaid rent.
- Utility readings are optional. When provided, the baseline is the latest room reading, falling back to the lease handover. Usage must not be negative and positive usage requires a price.
- Damage, cleaning and other charges are explicit settlement lines. Deposit available is collected plus adjustments minus prior deductions and refunds.
- `depositApplied = min(depositBalance, totalCharges)`. Any remaining charges become `balanceDue`; remaining deposit becomes `refundAmount`.
- Outstanding invoice debt is shown separately and is not silently paid, deducted or cancelled. Settlement balance due is stored separately; this slice does not create a receivable invoice or a settlement-payment workflow.
- Confirmation creates one `DEDUCTED` ledger entry when applicable, ends the lease, sets the room to `MAINTENANCE`, creates turnover steps and hides published listings for the room.
- Refund requires version, UUID idempotency key, receipt/reference and a reason. Only a recorded refund writes `REFUNDED` and changes status from `PENDING` to `PAID`.

## Concurrency and retries

Confirmation requires the exact preview fingerprint plus a stable UUID idempotency key.
Retry an uncertain network outcome with the same payload and key; do not create a new intent.
A 409 requires reloading/reviewing state. Both mutations run in Serializable transactions,
with ownership checks, room/lease locks, database constraints and transaction-local audit logs.

Invoice creation, including bulk billing, revalidates the lease under the same locks
and updates its revision before writing charges. This prevents a request based on an
active lease from issuing an invoice after a concurrent settlement has ended it.
Concurrent confirmation/refund retries cannot duplicate ledger entries.

## Verification

From `backend/`:

```sh
npx prisma generate
npm run build
npm test -- --runInBand
node --env-file=.env scripts/run-settlement-e2e.mjs
npm run ops:readiness
```

The E2E runner requires local PostgreSQL, `psql` on PATH and permission to create a
temporary database. It replaces the database name with a generated
`rental_settlement_test_<timestamp>_<random>` name, deploys migrations only there,
disables delivery/automation workers, runs the settlement suite and drops the temporary
database on normal success/failure. An abrupt process termination may require removing
the leftover test database manually. Never point destructive E2E fixtures at a working database.

From the repository root:

```sh
flutter analyze lib/features/tenants lib/data/tenants
flutter test test/data/lease_settlement_api_test.dart test/features/tenants/lease_settlement_screen_test.dart
```

## Rollout requirements and limits

Migration `20261026133000_lease_settlement` has only been exercised on disposable databases.
The working database has not been migrated, seeded or reset. Its readiness check intentionally
fails until this migration is deployed; the API prestart gate will refuse startup.
Use the existing verified-backup, restore/rehearsal and guarded `ops:migrate` workflow
before deploying, then rerun readiness and stage a real landlord move-out/refund scenario.

The old UI end-lease action is removed. The legacy `/leases/:id/end` endpoint remains
for compatibility; leases previously ended that way do not acquire a settlement automatically.
No automatic backfill, settlement reversal, real bank refund, explicit contractual forfeiture
approval, receivable collection, device acceptance test or production rollout is included.

Next slices: invoice line-item snapshots and versioned tariffs; aging/reminder policy;
maintenance assignment/SLA and staff property scope; tenant lifecycle requests; marketplace;
then integrations and permission-scoped intelligence.
