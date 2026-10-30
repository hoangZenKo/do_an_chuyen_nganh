# Rental Room Management — Project Status

> **Last updated:** 2026-10-29
> **Scope:** Flutter client và NestJS backend `backend/` trong cùng repository `/Users/hoang/Rental_room_management`.

Tài liệu này là snapshot hiện tại, không phải changelog. Lịch sử thay đổi nằm trong [`UPDATE_LOG.md`](UPDATE_LOG.md), quick start nằm trong [`README.md`](../README.md), còn bản đồ file/flow của từng feature nằm trong [`IMPLEMENTATION_MAP.md`](IMPLEMENTATION_MAP.md).

## 2026-10-29 — Chuyển khoản thật, xác nhận thủ công

- Chủ trọ cấu hình tài khoản nhận tiền theo khu trọ và ảnh QR private tùy chọn; API kiểm tra quyền sở hữu, version, audit và giới hạn truy cập upload. Người thuê xem hướng dẫn của hóa đơn thật, chuyển ngoài app và gửi chứng từ chờ duyệt.
- Chứng từ chờ duyệt không giảm dư nợ. Dùng chung hộp duyệt trên danh sách thu tiền và chi tiết hóa đơn, yêu cầu xác nhận đã kiểm tra thực nhận; backend hiện có ghi khoản thu/phân bổ/thanh toán trong transaction và chống duyệt trùng. Thẻ giả lập chỉ dành cho hóa đơn demo riêng.
- Xác minh hiện tại: Flutter 678 pass; backend 736 pass, 7 skip; E2E chuyển khoản + thẻ demo 18 pass trên DB tạm; backend build và iOS simulator build pass; analyzer mục tiêu 12 file sạch; `git diff --check` pass. Đây không phải nghiệm thu giao dịch ngân hàng thật hoặc staging.
- Readiness DB đang dùng còn thiếu `20261028140000_manual_transfer_account`, không có drift/failed/unexpected migration. Chưa migrate/reset/seed DB này; cần backup → rehearsal → guarded migration trước khi khởi động API mới.
- Phạm vi là tiền thuê phòng của chủ trọ, không phải thanh toán gói dịch vụ hay doanh thu nền tảng; không tích hợp payOS, tự trừ tiền hoặc webhook ngân hàng. Runbook: `docs/manual-transfer-payments.md`; execution ledger: `docs/superpowers/plans/2026-10-28-manual-transfer-payments.md`.

## 2026-10-28 — Project follow-up implementation checkpoint

- Added explicit Admin capability editing using the existing shared light shell and versioned/MFA-protected profile command. Live super-admin authority, delegation limits, last-super-admin protection, session revocation and before/after audit remain enforced. Preset updates and invitations cannot grant permissions the operator does not hold.
- Connected the landlord attention card to overdue invoices; whitelisted initial filters, standalone billing Material scaffolding, permission checks and property scoping remain intact. Fixed room-filter overflow and dashboard tab/scroll regressions without eagerly mounting hidden tabs.
- Current verification: full Flutter suite 637 passed; backend 716 passed, 7 skipped; six Admin disposable-DB E2E suites 42 passed; backend and iOS simulator builds passed. Targeted new-file analysis is clean; broader dashboard analysis retains two unused-section warnings and two const hints.
- This is a delivered slice across follow-up Phases 1, 3 and 4, not completion of all five phases. Phase 2 requires provider/merchant/pricing/settlement decisions; Phase 5 existing discovery/viewing/chatbot inventory is recorded, but no new chat/push integration shipped. Landlord/tenant live-device acceptance remains open.
- No working-database mutation or deployment in this pass. Execution ledger and evidence: `docs/superpowers/plans/2026-10-28-project-follow-up-phases.md`. Older counts and failures below are historical checkpoints, superseded by this entry.

## 2026-10-28 — Admin UI consolidation

- All Admin routes now use the shared light theme boundary; removed the unused legacy dashboard, duplicate dashboard renderer and old sprint export barrel without removing live workflows.
- SLA, landlord inventory, forms, dialogs, status accents and error/loading states use the overview design tokens; non-Admin themes and existing capability/session guards remain intact.
- Admin/Auth/Admin API Flutter suite: 212 pass; analyzer has no errors/warnings and retains seven previously recorded style infos. Native iPhone 16 spot checks used isolated provider fixtures, not working-DB mutations or full production acceptance.
- This cleanup does not change the database. The separately approved local guarded migration is complete; staging/provider/off-site restore/rollout acceptance remains open as documented in `docs/admin-functional-delivery-status.md`.

## 2026-10-26 — Invoice line items và biểu phí phiên bản

- Hóa đơn mới lưu từng khoản thu bất biến với số lượng, đơn vị, đơn giá, thành tiền và nguồn/phiên bản biểu phí; giữ aggregate fields để tương thích client cũ.
- Phí dịch vụ cố định theo phòng có lịch hiệu lực, lịch sử, optimistic concurrency và lịch ngừng thu; không áp dụng ngược cho kỳ đã có hóa đơn. Single/bulk/preflight/automation dùng chung calculator.
- Flutter bổ sung form tạo phiên bản, lịch sử, trạng thái hiệu lực và chi tiết khoản thu cho chủ trọ/người thuê; preview phí theo tháng được chọn.
- Đã xác minh: backend build, 395 unit tests pass (7 skipped), 7 E2E pass và legacy backfill rehearsal trên database tạm; 44 Flutter tests liên quan pass; analyzer mục tiêu sạch.
- Readiness đọc-only ngày 2026-10-26: `ready: false`, thiếu `20261026133000_lease_settlement` và `20261026150000_invoice_line_items_service_tariffs`, không có checksum drift/failed/unexpected migration. Chưa migrate/reset/seed database đang dùng; chưa nghiệm thu trên thiết bị hoặc staging.
- Runbook: `docs/billing-line-items-tariffs.md`. Phạm vi hiện tại là phí dịch vụ cố định theo phòng, chưa gồm biểu phí điện/nước bậc thang hay kế thừa biểu phí cấp tòa nhà.

## 2026-10-26 — Roadmap P0/P1 implementation checkpoint

- P0 release safety đã có schema readiness gate đọc-only, migration restore/rehearsal CLI, provider connectivity smoke test và guard không log credential/URL/body nhạy cảm.
- Admin Workspace đã có incident server-side filter/pagination, assignment/time-window/search, action queue deep-link allowlist và responsive filter controls.
- Support Center đã có SLA filter intersection (`overdue`, `due_soon`, `paused`), category/sort, merged-ticket exclusion và saved-view/deep-link compatibility.
- Moderation v2 đã có bulk preview read-only với permission/assignment/version/status/room availability revalidation trước khi mutation.
- Verification tại checkpoint admin (trước settlement): backend build; 35 Jest suites / 359 tests pass; safety scripts 10/10; Flutter admin analyzer sạch và 52 admin tests pass. Readiness hiện tại xem checkpoint settlement bên dưới.
- Chưa đánh dấu production: restore rehearsal thực tế cần backup manifest/key, provider smoke cần staging env, và device/manual QA vẫn chưa chạy. Full Flutter suite còn 11 lỗi cũ tại dashboard floating navigation.

## 2026-10-26 — Landlord move-out settlement vertical slice

- Hoàn thiện quyết toán trả phòng theo transaction Serializable: tiền thuê prorated gồm ngày trả, điện/nước chốt cuối kỳ, khoản phí chi tiết, số dư cọc, cấn trừ, phải thu và công nợ hóa đơn cũ tách riêng.
- Thêm ledger `DEDUCTED` khi xác nhận quyết toán và `REFUNDED` chỉ khi landlord ghi nhận đã chuyển/trao tiền; cả hai bước có idempotency, version/fingerprint, row lock và audit log.
- Quyết toán xác nhận tự kết thúc lease và mở turnover `MAINTENANCE`; UI landlord không còn nút kết thúc hợp đồng cũ để bypass settlement.
- Chặn race lập hóa đơn đơn lẻ/hàng loạt khi lease đổi hoặc kết thúc: kiểm tra lại lease dưới room/lease lock và cập nhật `updatedAt` để settlement Serializable nhận ra ghi đồng thời.
- Verification tại checkpoint settlement: Prisma generate/build pass; backend 36 Jest suites / 381 tests pass, 7 tests skipped; isolated settlement E2E 8/8 pass; Flutter settlement API/widget 16/16 pass. Kết quả mới nhất nằm ở checkpoint invoice/tariff đầu tài liệu.
- Tại checkpoint settlement, readiness local `ready: false`, thiếu migration `20261026133000_lease_settlement`, không có drift/failed migration. Kết quả hiện tại nằm ở checkpoint invoice/tariff; phải backup/rehearsal và deploy migration trước khi khởi động API mới.
- E2E chỉ chạy trên database tạm có tên được guard và tự xóa sau kiểm thử. Chưa chạy nghiệm thu trên thiết bị hoặc staging; hợp đồng đã kết thúc bằng luồng cũ chỉ hiện thông báo, chưa có backfill settlement tự động. Endpoint legacy `/leases/:id/end` còn giữ để tương thích client cũ.
- Đã triển khai invoice line items và versioned service tariffs: snapshot bất biến, effective-month selection, parity single/bulk/preflight/automation và tenant serialization. Runbook: `docs/billing-line-items-tariffs.md`. Các mục còn lại như aging/reminder, tenant lifecycle mới, marketplace và integration/intelligence vẫn là backlog kế tiếp.

## 1. Status summary

### Implemented in source

- Flutter onboarding, auth UI, Riverpod session state và secure token storage.
- Splash session restore, role-based routing, client route guards và onboarding completion persistence bằng `shared_preferences`.
- Automatic access-token refresh/retry với single-flight coordinator và Flutter regression tests.
- Landlord dashboard overview dùng API tổng hợp thật cho room stats, finance, revenue trend, attention và recent invoices.
- Property management UI: danh sách/chọn/tạo/sửa/archive/restore/xóa khu trọ chưa có phòng, occupancy summary, active/archived filters, retry/refresh/empty states và selected-property integration với Dashboard/Rooms.
- Room models, API, repository/providers và rooms list/detail/form/deactivate/reactivate/delete UI.
- Tenant/Lease models, API, repository/providers và tenant/lease lifecycle UI.
- Billing nâng cao: meter readings, invoices, payments, transaction tạo invoice kèm readings, duplicate preflight, tạo hàng loạt, prefill chỉ số kỳ trước, PDF/share, reminder list/run và worker tự động lập hóa đơn hằng tháng.
- NestJS auth, health, Prisma và admin bootstrap CLI.
- Backend Property, Room, Tenant, Lease, Billing và Admin modules/controllers/services.
- Prisma models/migrations cho `User`, `RefreshToken`, `Property`, `Room`, `Tenant`, `Lease`, `MeterReading`, `Invoice` và `Payment`.
- Admin MVP 3 giai đoạn dưới `/api/v1/admin/...`: capability-based permissions, MFA/TOTP + recovery codes, audit log, account management/support read-only, moderation queue/assignment/decision và analytics.
- Admin overview, landlord management và property management dưới `/api/v1/admin/...`, có backend E2E coverage.
- Argon2id password hashing, SHA-256 refresh-token digest lookup, transactional rotation và auth throttling.
- Tenant Portal invoice flow: dashboard preview, full invoice list/filter, invoice detail/PDF/share, payment proof upload/submit và landlord proof review.
- Tenant Portal maintenance flow: dashboard preview, full ticket list/filter, create request, upload attachment, detail view và tenant comment.
- Admin release hardening: scoped single-use step-up cho PII, suspend, export, bulk moderation, access review và legacy landlord status; access review masking/version; incident lifecycle; business-hours SLA, escalation worker và support case timeline.
- Admin Flutter workflows: step-up retry, incident runbook/actions, access review, SLA policy, case timeline và landlord status reason/version flow.

Runbook và phạm vi nghiệm thu release admin đầu tiên: `docs/admin-operations-release-2026-10-26.md`. ADM-07 vẫn còn staging/device/provider verification, không phải đã được phê duyệt production.

### Chưa hoàn tất hoặc chưa được runtime verify

- Billing còn cần runtime/device verification cho worker tự động/reminders và báo cáo nâng cao hơn.
- Dashboard cần follow-up: deep link từ attention card sang danh sách hóa đơn trễ hạn và all-properties mode rõ ràng hơn.
- Lifecycle archive/deactivate/delete cho property/room/tenant đã có trong source nhưng cần chạy lại formatter/analyzer/build/test và E2E với test database.
- Admin chưa có platform-wide CRUD cho rooms, tenants, leases, invoices, payments hoặc admin accounts; các nhóm này giữ read-only/ownership boundary theo thiết kế.
- Account invite/reset delivery, MFA encryption key và external notification delivery cần cấu hình production secrets/webhook.
- Billing automation/reminder cần E2E production-like verification với database thật và cấu hình Zalo thật.
- Tenant Portal payment proof cần manual runtime verification với upload file thật trên thiết bị/simulator.
- Tenant Portal maintenance cần manual runtime verification cho tạo ticket/comment với upload file thật trên thiết bị/simulator.
- Flutter/backend integration và physical-device verification.
- Production/device runtime status của migration, analyzer, build và test trên môi trường release; isolated admin E2E đã pass với migration `20261026120000_incident_snooze_constraint`.
- Production secrets, HTTPS và rollout theo `docs/production-safety-2026-10-25.md`; code backup/restore, outbox, monitoring và guarded migration đã có nhưng chưa triển khai production.

### Admin Sprint 5 — Identity & API Safety

- `AuthSession` tách phiên đăng nhập khỏi refresh-token rotation; user có thể xem thiết bị/địa chỉ mạng đã che, thu hồi một phiên hoặc thu hồi các phiên khác.
- JWT kiểm tra session còn active; thu hồi phiên làm access token của phiên đó bị từ chối ngay ở request kế tiếp.
- API error filter chuẩn hóa lỗi thành `error.code`, `error.message`, `error.details` và `requestId`; lỗi 5xx không trả nội dung nội bộ.
- Swagger/OpenAPI được dựng tại `/docs` và `/docs-json` ngoài production; production cần bật rõ `SWAGGER_ENABLED=true`.
- Migration nguồn: `backend/prisma/migrations/20261025200000_auth_sessions`, `backend/prisma/migrations/20261025210000_support_tools` và `backend/prisma/migrations/20261025220000_moderation_policies`; đã apply trên DB test cô lập, chưa apply production.

## 2. Architecture

```text
Flutter client
  ├── onboarding/auth/session
  ├── dashboard
  ├── rooms/property
  └── tenants/leases
          │ REST /api/v1 + Bearer JWT
          ▼
NestJS API
  ├── auth + health
  ├── properties + rooms
  ├── tenants + leases
  ├── billing + admin workspace
  └── Prisma
          ▼
PostgreSQL 16
```

Local default là PostgreSQL native qua Homebrew. Docker Compose PostgreSQL chỉ là fallback; không chạy cả hai trên port `5432`.

### Admin MVP status

Ba giai đoạn đã có code và test:

1. `Security`: capability menu/route guard, admin profile, MFA/TOTP, recovery code, session invalidation và audit log.
2. `Accounts`: phân trang/tìm kiếm account, suspend/restore có reason + version, revoke sessions, password reset request và PII reveal có audit; support context chỉ đọc.
3. `Moderation`: queue cho listing/report/review/reply, filter, assignment có conflict lock, priority/due date/internal note, quyết định moderation và analytics summary.

Giới hạn an toàn: admin không sửa/xóa trực tiếp invoice, payment, payment proof, lease, deposit hoặc audit log.

## 3. Flutter status

### Startup và navigation

`lib/features/splash/splash_screen.dart` hiển thị minimum splash duration rồi gọi session restore và đọc onboarding completion flag. Session authenticated được route theo role; session chưa đăng nhập đi tới `/onboarding` nếu chưa hoàn tất onboarding, hoặc `/auth/login` nếu đã hoàn tất. Splash không còn cấp quyền bypass trực tiếp vào dashboard.

Routes hiện có gồm:

```text
/splash
/onboarding
/auth/login
/auth/register
/dashboard
/admin
/properties
/properties/form
/rooms/form
/rooms/:id
/tenants
/tenants/form
/tenants/:id
/leases/form
/billing/form
/tenant
/tenant/invoices
/tenant/invoices/:id
/tenant/maintenance
/tenant/password
/tenant/zalo
```

Client guard hiện yêu cầu authenticated session cho `/dashboard`, `/admin`, `/properties...`, `/rooms...`, `/tenants...`, `/leases...`, `/billing...` và `/tenant...`. Admin deep link vào landlord/tenant workflows được redirect về `/admin`; landlord vào `/admin` hoặc `/tenant...` được redirect về `/dashboard`; tenant vào landlord/admin routes được redirect về `/tenant`. Backend role guard enforce landlord-only cho landlord resource endpoints.

### Auth/session

Đã có:

- Login/register/logout và `/auth/me`.
- `flutter_secure_storage` cho access/refresh token, expiry, user và role.
- Restore session qua Riverpod.
- Dio Bearer header cho protected requests.
- Single-flight refresh khi protected request nhận `401`, retry request gốc một lần.

Chưa runtime verify đầy đủ:

- App restart và session restore trên device thật.
- Expired access token và concurrent refresh trên backend/device thật; Flutter unit tests đã cover retry/single-flight behavior.
- Logout/replay behavior trên device thật.
- Role redirect trên device thật.

### Dashboard

`lib/features/dashboard/dashboard_screen.dart` hiện có header, stats, finance summary, revenue chart, rooms needing attention, recent invoices và bottom navigation. Overview đã nối `dashboardMetricsProvider` tới backend `/dashboard/metrics`; số phòng, doanh thu, chart, attention và recent invoices lấy từ API thật. Tab Rooms đã nối tới rooms flow; tab Hóa đơn đã nối billing với dữ liệu API thật. Revenue chart dùng cubic Bézier smoothing trong `CustomPainter`.

### Property/Room

Các file chính:

```text
lib/models/property.dart
lib/models/room.dart
lib/data/rooms/
lib/features/properties/
lib/features/rooms/
```

Đã có property management flow gồm danh sách/chọn/tạo/sửa khu trọ, room/occupied/vacant summary, retry/refresh/empty states và kết nối selected property sang Dashboard/Rooms. Backend property contract hiện hỗ trợ list/get/create/update, chưa có delete.

Đã có list/filter/detail/create/update/delete room flow, property selection và loading/error/empty states. Room model/backend hỗ trợ `capacity`, `amenities` và `imageUrl` ngoài floor, area, base price, status, tenant name và note.

### Tenant/Lease

Các file chính:

```text
lib/models/tenant.dart
lib/models/lease.dart
lib/data/tenants/
lib/features/tenants/
```

Đã có tenant list/detail/form và lease create/end/history flow. Cần runtime verify API integration, ownership isolation và room status transitions.

## 4. Backend status

### Modules và endpoints

Auth/health:

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
GET  /api/v1/health
```

Property/room:

```http
GET    /api/v1/properties?lifecycle=active|archived|all
POST   /api/v1/properties
GET    /api/v1/properties/:id
PATCH  /api/v1/properties/:id
PATCH  /api/v1/properties/:id/status
DELETE /api/v1/properties/:id
GET    /api/v1/properties/:propertyId/rooms?lifecycle=active|inactive|all
POST   /api/v1/properties/:propertyId/rooms
GET    /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id/status
DELETE /api/v1/rooms/:id
```

Tenant/lease:

```http
GET    /api/v1/tenants?lifecycle=active|inactive|all
POST   /api/v1/tenants
GET    /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id/status
DELETE /api/v1/tenants/:id
POST   /api/v1/leases
POST   /api/v1/leases/:id/end
GET    /api/v1/rooms/:roomId/leases
GET    /api/v1/tenants/:tenantId/leases
```

Resource services scope query theo authenticated user/landlord ID thay vì tin `landlordId` từ client. Backend role guard hiện giới hạn dashboard/properties/rooms/tenants/leases/billing cho `landlord`; admin gọi các landlord resource endpoints sẽ nhận `403` và dùng `/admin/...` API riêng cho overview, landlords và properties. Property archive/delete, room deactivate/delete và tenant deactivate/delete được guard bởi active lease và history checks. Tạo lease kiểm tra room/tenant ownership, reject archived property/inactive room/inactive tenant và cập nhật room thành occupied trong transaction; end lease cập nhật room thành vacant.

### Auth security

- Password: Argon2id.
- Refresh token: raw token không lưu; backend lookup SHA-256 digest, unique index và rotate trong transaction.
- JWT strategy kiểm tra current user và `isActive`.
- Auth endpoints có global throttler và limit riêng.
- Helmet, CORS config và global ValidationPipe đã có.

## 5. Prisma/database status

Schema hiện có:

```text
User
RefreshToken
Property
Room
Tenant
Lease
MeterReading
Invoice
Payment
PaymentProof
MaintenanceTicket
MaintenanceComment
```

Enums:

```text
UserRole: LANDLORD, ADMIN
RoomStatus: OCCUPIED, VACANT, MAINTENANCE
LeaseStatus: ACTIVE, ENDED
UtilityType: ELECTRICITY, WATER
InvoiceStatus: UNPAID, PARTIAL, PAID, CANCELLED
PaymentMethod: CASH, BANK_TRANSFER, E_WALLET, OTHER
MaintenanceStatus: OPEN, IN_PROGRESS, DONE, CANCELLED
MaintenancePriority: LOW, MEDIUM, URGENT
```

Migration history trong source bao gồm auth, refresh-token hash/index, property/room, tenant/lease, room detail fields và lifecycle flags cho property/room/tenant. Lifecycle migration cũng thêm partial unique index PostgreSQL cho invariant một room chỉ có một active lease. Migration files tồn tại không chứng minh database local đã migrate; xác minh bằng:

```bash
cd /Users/hoang/Rental_room_management/backend
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
```

Chưa có model/table cho `AuditLog`.

## 6. Admin status

Đã có:

- `ADMIN` role trong Prisma.
- Admin bootstrap CLI `npm run admin:bootstrap`.
- Client admin workspace responsive với routes `/admin`, `/admin/accounts`, `/admin/audit-logs`, `/admin/moderation`, `/admin/support`, `/admin/admins` và `/admin/security`.
- Backend admin module với capability presets, MFA/TOTP, audit log, account/support read-only, moderation queue và analytics dưới `/api/v1/admin/...`.
- Backend `@Roles(AuthRole.ADMIN)` + capability guard cho admin controller; backend E2E cover `401/403`, MFA replay/recovery, account lifecycle, PII audit và moderation concurrency.
- Public registration bị giới hạn ở landlord.

Giới hạn có chủ đích:

- Admin không sửa/xóa trực tiếp rooms, tenants, leases, invoices, payments, payment proofs, deposits hoặc audit records; các thao tác tài chính tiếp tục thuộc domain owner/operator và support chỉ đọc.
- Invite/reset delivery cần `AUTH_PUBLIC_APP_URL` + `AUTH_DELIVERY_WEBHOOK_URL`; MFA production cần `ADMIN_MFA_ENCRYPTION_KEY`.

Admin setup chi tiết nằm trong [`ADMIN_SETUP.md`](../ADMIN_SETUP.md). Bootstrap chạy lại với email admin hiện hữu có thể cập nhật password và activate lại tài khoản; email landlord không được tự nâng thành admin.

## 7. Tests và verification

Test source hiện có gồm onboarding/responsive/persistence tests, auth API/navigation/refresh tests, admin API tests, billing API tests, `test/rooms_test.dart`, `test/properties_test.dart`, backend unit/authz tests và backend E2E specs. Backend E2E chạy HTTP-level Nest app thật với PostgreSQL test database riêng cho auth lifecycle, admin CRUD/authorization boundaries, role guard, ownership isolation, lease transitions, billing payment transitions và dashboard scoping.

Commands khuyến nghị:

```bash
# Flutter
cd /Users/hoang/Rental_room_management
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

# Backend
cd /Users/hoang/Rental_room_management/backend
npm install
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
npm test
npm run build

# Backend E2E với database test riêng
createdb rental_management_test # nếu chưa có
export DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management_test?schema=public"
npm run prisma:generate
npm run prisma:deploy
NODE_ENV=test DATABASE_URL="$DATABASE_URL" npm run test:e2e
```

`npm run lint` hiện dùng ESLint `--fix`, có thể sửa source. Backend E2E reset dữ liệu nên chỉ chạy với database test có marker `test` trong `DATABASE_URL`.

Manual flow cần chạy trên thiết bị/app thật: health, register/login landlord, bootstrap/login admin, `/auth/me`, refresh, logout, onboarding không lặp lại sau skip/login/register, room/tenant CRUD, lease create/end, app restart và token expiry. Backend E2E đã cover các flow API chính nhưng chưa thay thế physical-device verification.

## 8. Known limitations và next milestones

### Ưu tiên cao

1. Chạy lại và ghi kết quả Flutter/backend analyzer, build, tests và migrations sau các thay đổi dashboard/billing mới nhất.
2. Chạy backend lifecycle E2E mới và xử lý lỗi compile/runtime nếu có.
3. Làm sạch cascade relation policy trước production nếu muốn enforce restrict ở database layer thay vì chỉ service guards.
4. Mở rộng `/admin/...` API nếu cần quản lý rooms, tenants, leases, billing, audit records hoặc admin accounts.
5. Hoàn thiện global error envelope và Swagger/OpenAPI.

### Production readiness

- HTTPS/reverse proxy và CORS allowlist.
- Secret manager, password/token log redaction.
- PostgreSQL backup/restore và migration release step.
- Rate-limit tuning và monitoring.
- Physical-device testing bằng HTTPS host/tunnel.

## 9. Important files

Flutter:

```text
lib/app/app.dart
lib/core/network/api_client.dart
lib/data/auth/
lib/data/admin/
lib/data/billing/
lib/data/onboarding/
lib/data/rooms/
lib/data/tenants/
lib/models/
lib/features/auth/
lib/features/admin/
lib/features/billing/
lib/features/dashboard/
lib/features/onboarding/
lib/features/rooms/
lib/features/tenants/
test/core/network/api_client_test.dart
test/data/auth/token_refresh_coordinator_test.dart
test/data/admin/admin_api_test.dart
test/data/billing/billing_api_test.dart
test/data/onboarding/onboarding_preferences_test.dart
test/data/rooms_lifecycle_api_test.dart
test/data/tenants_lifecycle_api_test.dart
test/features/onboarding/onboarding_persistence_test.dart
test/rooms_test.dart
```

Backend:

```text
src/app.module.ts
src/auth/
src/properties/
src/rooms/
src/tenants/
src/leases/
src/prisma/
src/health/
prisma/schema.prisma
prisma/migrations/
test/e2e/resource-lifecycle.e2e-spec.ts
prisma/seed.ts
prisma/bootstrap-admin.ts
```

## Security boundary

Ownership scoping, JWT authentication và backend role guard đã có cho landlord resource endpoints và admin overview/landlord/property endpoints. Flutter role checks chỉ là client UX; backend vẫn phải tiếp tục enforce role/permission cho mọi admin và landlord operation, đặc biệt khi mở rộng `/admin/...` APIs trước production.

## Admin Sprints 2–7 — 2026-10-25

Support Center, Moderation v2, Governance, Identity/API Safety, Admin Search, Support Tools và Moderation Policy đã được triển khai ở backend và Flutter. Runbook Sprint 2–4 nằm tại `docs/admin-sprints-234.md`; phần bổ sung nằm tại `docs/admin-next-sprints.md`. Backend đã verify trên database test riêng; chưa có staging/production deployment verification.

## Admin completion update — 26/10/2026
- Added support attachment scanning/access, saved support views, support skills/capacity auto-assignment.
- Added notification delivery preferences, retry/backoff/dead-letter queue and operations monitoring.
- Added finance statement import, deterministic matching and maker-checker reconciliation proposals.
- Added IANA timezone-aware scheduled reports, retry and signed download links with production object-storage guard.
- Migration `20261026090000_admin_completion` is verified only on isolated test DB `rental_chatbot_test_admin_completion_20261026`.

## Admin Phase 0–5 implementation — 28/10/2026
- Unified the light Admin shell, including property/room/landlord forms, route matching and permission-aware navigation.
- Added scanned-evidence landlord verification (with self-only submission), property approval snapshots, Free/Pro/Premium administrative entitlements, quota enforcement, cancellation/history and read-only transaction investigation.
- Closed audit deep-link filtering, typed property-cache refresh and reviewed-property deletion conflict handling; retained existing account/support/notification/report/security/operations workflows.
- Verified backend build, 696 unit tests (7 skipped), 41 Admin E2E on disposable databases, 11 safety-script tests and 8 runner-safety tests. Flutter and runtime details: `docs/admin-functional-delivery-status.md`.
- Admin/Auth/API Flutter suite: 173 pass. Broader Flutter suite: 567 pass / 11 failures in non-Admin dashboard floating-navigation tests; seven existing analyzer style infos remain. This is not a whole-project green claim.
- Local working DB `rental_management` now has additive migration `20261028090000_admin_registries` after encrypted backup, isolated restore/rehearsal and guarded confirmation. Readiness/build/start:dev/health pass; 103 old tables retain identical content, with only pre-migration worker heartbeat timestamps changing. No subscription settlement/revenue or production acceptance claim. Staging off-site backup/restore/provider/rollout evidence remains open.
