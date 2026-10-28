# Rental Room Management — Project Status

> **Last updated:** 2026-08-08  
> **Scope:** Flutter client `/Users/hoang/Rental_room_management` và NestJS backend `/Users/hoang/rental-room-api`.

Tài liệu này là snapshot hiện tại, không phải changelog. Lịch sử thay đổi nằm trong [`UPDATE_LOG.md`](UPDATE_LOG.md), quick start nằm trong [`README.md`](README.md), còn bản đồ file/flow của từng feature nằm trong [`IMPLEMENTATION_MAP.md`](IMPLEMENTATION_MAP.md).

## 1. Status summary

### Implemented in source

- Flutter onboarding, auth UI, Riverpod session state và secure token storage.
- Splash session restore, role-based routing, client route guards và onboarding completion persistence bằng `shared_preferences`.
- Automatic access-token refresh/retry với single-flight coordinator và Flutter regression tests.
- Landlord dashboard overview dùng API tổng hợp thật cho room stats, finance, revenue trend, attention và recent invoices.
- Property management UI: danh sách/chọn/tạo/sửa/archive/restore/xóa khu trọ chưa có phòng, occupancy summary, active/archived filters, retry/refresh/empty states và selected-property integration với Dashboard/Rooms.
- Room models, API, repository/providers và rooms list/detail/form/deactivate/reactivate/delete UI.
- Tenant/Lease models, API, repository/providers và tenant/lease lifecycle UI.
- Billing nâng cao: meter readings, invoices, payments, transaction tạo invoice kèm readings, duplicate preflight, validation chỉ số và filter quá hạn trong Flutter.
- NestJS auth, health, Prisma và admin bootstrap CLI.
- Backend Property, Room, Tenant, Lease, Billing và Admin modules/controllers/services.
- Prisma models/migrations cho `User`, `RefreshToken`, `Property`, `Room`, `Tenant`, `Lease`, `MeterReading`, `Invoice` và `Payment`.
- Admin overview, landlord management và property management dưới `/api/v1/admin/...`, có backend E2E coverage.
- Argon2id password hashing, SHA-256 refresh-token digest lookup, transactional rotation và auth throttling.

### Chưa hoàn tất hoặc chưa được runtime verify

- Billing nâng cao còn thiếu: tự điền chỉ số kỳ trước, recurring invoice automation, invoice PDF/share, reporting và audit log.
- Dashboard cần follow-up: deep link từ attention card sang danh sách hóa đơn trễ hạn và all-properties mode rõ ràng hơn.
- Lifecycle archive/deactivate/delete cho property/room/tenant đã có trong source nhưng cần chạy lại formatter/analyzer/build/test và E2E với test database.
- Admin chưa có platform-wide CRUD cho rooms, tenants, leases, invoices, payments, audit records hoặc admin accounts.
- Billing nâng cao chưa có invoice cancellation/update/export/share và recurring automation.
- Global error envelope nhất quán và Swagger wiring.
- Flutter/backend integration và physical-device verification.
- Production/device runtime status của migration, analyzer, build và test trên môi trường release.
- Production secrets, HTTPS, backup/restore, monitoring và release migration pipeline.

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
  ├── billing + admin
  └── Prisma
          ▼
PostgreSQL 16
```

Local default là PostgreSQL native qua Homebrew. Docker Compose PostgreSQL chỉ là fallback; không chạy cả hai trên port `5432`.

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
```

Client guard hiện yêu cầu authenticated session cho `/dashboard`, `/admin`, `/properties...`, `/rooms...`, `/tenants...`, `/leases...` và `/billing...`. Admin deep link vào landlord workflows được redirect về `/admin`; landlord vào `/admin` được redirect về `/dashboard`. Backend role guard enforce landlord-only cho landlord resource endpoints.

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
```

Enums:

```text
UserRole: LANDLORD, ADMIN
RoomStatus: OCCUPIED, VACANT, MAINTENANCE
LeaseStatus: ACTIVE, ENDED
UtilityType: ELECTRICITY, WATER
InvoiceStatus: UNPAID, PARTIAL, PAID, CANCELLED
PaymentMethod: CASH, BANK_TRANSFER, E_WALLET, OTHER
```

Migration history trong source bao gồm auth, refresh-token hash/index, property/room, tenant/lease, room detail fields và lifecycle flags cho property/room/tenant. Lifecycle migration cũng thêm partial unique index PostgreSQL cho invariant một room chỉ có một active lease. Migration files tồn tại không chứng minh database local đã migrate; xác minh bằng:

```bash
cd /Users/hoang/rental-room-api
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
```

Chưa có model/table cho `AuditLog`.

## 6. Admin status

Đã có:

- `ADMIN` role trong Prisma.
- Admin bootstrap CLI `npm run admin:bootstrap`.
- Client routes/screens cho `/admin`, landlords và properties.
- Backend admin module với overview, landlord management và property management dưới `/api/v1/admin/...`.
- Backend `@Roles(AuthRole.ADMIN)` guard cho admin controller; backend E2E cover `401/403`, landlord CRUD và platform property CRUD.
- Public registration bị giới hạn ở landlord.

Chưa có:

- Admin-wide CRUD cho rooms, tenants, leases, invoices, payments, audit records hoặc admin accounts.
- Password reset, audit log hoặc admin role/account management.

Admin setup chi tiết nằm trong [`ADMIN_SETUP.md`](ADMIN_SETUP.md). Bootstrap chạy lại với email admin hiện hữu có thể cập nhật password và activate lại tài khoản; email landlord không được tự nâng thành admin.

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
cd /Users/hoang/rental-room-api
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
