# Admin Phase 1: Dashboard and Overview Reports

## Scope

Phase 1 adds the admin dashboard and the overview-report route:

- `/admin`: operational dashboard with KPI totals, growth, occupancy, queue, trend chart, and permission-scoped finance.
- `/admin/reports/overview`: reporting view with the same period selector, daily data table, CSV copy action, and finance summaries.
- `/admin/reports` remains the scheduled-report route for backwards compatibility.

## API

`GET /api/v1/admin/analytics/overview?days=7|30|90|180`

The endpoint requires `admin.dashboard.view`. It returns no-store/private cache headers and computes the current period through the captured request time in `Asia/Ho_Chi_Minh`. Growth compares new records with the preceding full period of the same length.

The response includes:

- account totals, active/inactive counts, and role breakdown;
- property totals, active and archived counts;
- all-room total plus active-room status/occupancy when `admin.properties.view` is granted;
- zero-filled daily account/property/room/listing trends;
- finance totals and daily rental fields only when `admin.finance.read` is granted.

All finance queries exclude demo invoices. Reversal amounts are represented as positive reversed value in summary data and subtracted from collected rent to produce rental net. No platform subscription revenue is fabricated: `platformRevenue.available` is `false`, `amount` is `null`, and the UI explains that service-package billing is not implemented yet.

## UI behavior

- Trend charts support account/property/room metrics and rental net when finance permission is available.
- Selecting or tapping a chart point exposes its date/value through visible detail text and accessibility semantics.
- Empty, zero-only, negative-net, loading, retry, permission-revoked, and session-change states do not show fabricated zeros or stale private data.
- The dashboard uses a scoped light theme and responsive shell: desktop sidebar, mobile bottom navigation, minimum 44pt controls, and a narrow/large-text layout path.

## Verification

- Backend admin tests cover service aggregation, permission projection, period validation, demo-payment exclusion, role/status totals, reversal signs, and HTTP authorization.
- Flutter tests cover dashboard/report rendering, period switching, chart semantics and negative values, permission revocation, session isolation, 320px/200% text, mobile, and desktop layouts.
- A read-only local PostgreSQL smoke check reconciles 7, 30, 90, and 180-day trend totals with the API summaries.
