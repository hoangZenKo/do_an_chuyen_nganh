# Rental Room Management

Ứng dụng Flutter quản lý khu trọ, phòng, người thuê và hợp đồng. Backend NestJS nằm ở project sibling `/Users/hoang/rental-room-api`.

> **Documentation status:** cập nhật ngày 2026-08-08. Nội dung dưới đây phản ánh source hiện tại; runtime/database verification vẫn phải chạy theo phần Verification.

## Current scope

Đã có trong source:

- Splash, onboarding và session-aware startup routing.
- Đăng ký landlord, đăng nhập, đăng xuất và khôi phục session.
- JWT access token, rotating refresh token và tự refresh/retry một lần trong Flutter.
- Role routing: `admin` → `/admin`, `landlord` → `/dashboard`.
- Dashboard landlord với metrics tổng quan từ API thật và filter theo property đang chọn.
- Property management UI: danh sách/chọn/tạo/sửa/archive/restore/xóa khu trọ chưa có phòng, occupancy summary, archived filter, loading/error/retry/refresh/empty states.
- Room models, API, repository, providers và UI list/detail/form/deactivate/reactivate/delete unused room.
- Tenant/lease models, API, repository, providers và UI list/detail/form/history/deactivate/reactivate/delete unused tenant.
- Billing MVP với meter readings, invoices, payments, API/backend schema và tab hóa đơn Flutter.
- Backend Prisma models và REST modules cho Property, Room, Tenant, Lease và Billing.
- Admin overview và admin management cho landlords/properties qua `/api/v1/admin/...`, có backend role guard `ADMIN` và Flutter admin screens tương ứng.
- Flutter stability tests cho admin API contract, billing API contract, auth refresh/retry và onboarding persistence.

Chưa hoàn tất hoặc chưa được xác minh đầy đủ:

- Lifecycle archive/deactivate/delete cho property/room/tenant đã có trong source nhưng cần chạy lại formatter/analyzer/build/test và backend E2E với database test.
- Billing report nâng cao, recurring invoice automation và audit log.
- Admin chưa có platform-wide CRUD cho rooms, tenants, leases, invoices, payments, audit records hoặc admin accounts.
- Flutter/backend integration tests và physical-device verification.
- Production runtime verification trên thiết bị thật/môi trường release.

## Architecture

```text
/Users/hoang/Rental_room_management   # Flutter client
/Users/hoang/rental-room-api           # NestJS REST API
```

Backend stack:

```text
NestJS + TypeScript
Prisma ORM
PostgreSQL 16 native qua Homebrew (Docker Compose là fallback)
JWT access token
Rotating opaque refresh token
Argon2id password hashing
```

Flutter gọi API dưới prefix:

```text
/api/v1
```

## Prerequisites

- Flutter SDK và Dart SDK
- Node.js 20+ và npm
- Homebrew
- PostgreSQL 16 native local service
- Docker Desktop (tùy chọn, chỉ dùng fallback)

Kiểm tra toolchain:

```sh
flutter --version
node --version
npm --version
brew --version
```

## Local setup

### 1. Start native PostgreSQL và backend

Native PostgreSQL là quy trình mặc định:

```sh
cd /Users/hoang/rental-room-api
cp .env.example .env
npm install
brew services start postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
pg_isready -h 127.0.0.1 -p 5432
```

Đặt `DATABASE_URL` trong file `.env` theo database local của bạn, ví dụ:

```env
DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management?schema=public"
```

Generate Prisma Client và áp dụng các migration đã commit:

```sh
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
```

> Chỉ dùng `npx prisma migrate dev --name <descriptive-change>` sau khi chủ động thay đổi `prisma/schema.prisma`. Không dùng lệnh đó để thay thế việc deploy migration history đã commit.

Start API:

```sh
npm run start:dev
```

API mặc định chạy tại `http://localhost:3000`. Kiểm tra health:

```sh
curl http://localhost:3000/api/v1/health
```

Expected response khi database sẵn sàng:

```json
{
  "status": "ok",
  "database": "ok"
}
```

### Docker fallback

Chỉ dùng Docker nếu không dùng native PostgreSQL:

```sh
docker compose up -d postgres
```

Không chạy native và Docker PostgreSQL đồng thời trên port `5432`. Không chạy `docker compose down -v` nếu cần giữ Docker volume cũ.

### 2. Bootstrap admin

Không tạo admin qua public registration. Xem hướng dẫn đầy đủ tại [`ADMIN_SETUP.md`](ADMIN_SETUP.md), hoặc chạy:

```sh
cd /Users/hoang/rental-room-api
export ADMIN_BOOTSTRAP_EMAIL="<unique-admin-email>"
export ADMIN_BOOTSTRAP_NAME="<admin-full-name>"
read -s ADMIN_BOOTSTRAP_PASSWORD
export ADMIN_BOOTSTRAP_PASSWORD
npm run admin:bootstrap
```

Không commit password, biến môi trường thật hoặc `.env`.

### 3. Run Flutter

Mở terminal thứ hai:

```sh
cd /Users/hoang/Rental_room_management
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Trên thiết bị thật, `localhost` trỏ tới chính thiết bị; dùng IP LAN hoặc HTTPS host của máy chạy API.

### 4. Nếu dùng app Zalo riêng

Luồng hiện tại tách làm 2 Flutter app:

- `/Users/hoang/Rental_room_management` là app quản lý trọ
- `/Users/hoang/zalo_demo_app` là app nhắn tin riêng

Cách chạy đúng:

1. Chạy backend.
2. Chạy `zalo_demo_app` một lần để cài app Zalo lên simulator.
3. Dừng terminal đó nếu muốn.
4. Chạy lại `Rental_room_management` để thao tác chính.

```sh
cd /Users/hoang/zalo_demo_app
/Users/hoang/development/flutter/bin/flutter pub get
/Users/hoang/development/flutter/bin/flutter run -d "iPhone 16"

cd /Users/hoang/Rental_room_management
/Users/hoang/development/flutter/bin/flutter pub get
/Users/hoang/development/flutter/bin/flutter run -d "iPhone 16" --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Nếu simulator đã có app cũ, gỡ rồi cài lại:

```sh
xcrun simctl uninstall booted com.example.zaloDemoApp
xcrun simctl uninstall booted com.example.rental_room_management
```

Nếu platform folders thực sự bị thiếu, mới chạy `flutter create .`. Không chạy lệnh này theo quick start khi project đã có `ios/`, `android/` hoặc platform configuration cần giữ.

## Authentication endpoints

Public registration luôn tạo role `landlord`:

```http
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

Flutter tự refresh access token khi protected request nhận `401`; các request đồng thời dùng chung một refresh request. Backend lookup refresh token bằng SHA-256 digest và rotate token trong transaction. Password được hash bằng Argon2id. Auth endpoints có throttling.

## Property, room, tenant, lease và billing endpoints

Các endpoint dưới đây yêu cầu Bearer JWT và backend role guard hiện giới hạn cho role `landlord`. Service tiếp tục scope resource theo authenticated landlord identity; admin gọi các landlord resource endpoints sẽ nhận `403`; admin dùng nhóm `/api/v1/admin/...` riêng cho landlords/properties.

```http
GET    /api/v1/properties?lifecycle=active|archived|all
POST   /api/v1/properties
GET    /api/v1/properties/:id
PATCH  /api/v1/properties/:id
PATCH  /api/v1/properties/:id/status   # { "isArchived": true|false }
DELETE /api/v1/properties/:id           # chỉ property chưa có phòng

GET    /api/v1/properties/:propertyId/rooms?lifecycle=active|inactive|all
POST   /api/v1/properties/:propertyId/rooms
GET    /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id
PATCH  /api/v1/rooms/:id/status         # { "isActive": true|false }
DELETE /api/v1/rooms/:id                # chỉ room chưa có lịch sử

GET    /api/v1/tenants?lifecycle=active|inactive|all
POST   /api/v1/tenants
GET    /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id
PATCH  /api/v1/tenants/:id/status       # { "isActive": true|false }
DELETE /api/v1/tenants/:id              # chỉ tenant chưa có lịch sử

POST   /api/v1/leases
POST   /api/v1/leases/:id/end
GET    /api/v1/rooms/:roomId/leases
GET    /api/v1/tenants/:tenantId/leases
```

Billing endpoints:

```http
GET    /api/v1/billing/active-leases
GET    /api/v1/billing/meter-readings
POST   /api/v1/billing/meter-readings
GET    /api/v1/billing/invoices
POST   /api/v1/billing/invoices
GET    /api/v1/billing/invoices/:id
POST   /api/v1/billing/invoices/:id/payments
```

Admin endpoints hiện có, yêu cầu role `admin`:

```http
GET    /api/v1/admin/overview
GET    /api/v1/admin/landlords
POST   /api/v1/admin/landlords
GET    /api/v1/admin/landlords/:id
PATCH  /api/v1/admin/landlords/:id
PATCH  /api/v1/admin/landlords/:id/status
GET    /api/v1/admin/properties
POST   /api/v1/admin/properties
GET    /api/v1/admin/properties/:id
PATCH  /api/v1/admin/properties/:id
```

Tạo/kết thúc lease cập nhật trạng thái phòng trong backend transaction. Backend chặn tạo lease nếu property đã archive, room inactive hoặc tenant inactive. Archive/deactivate/delete lifecycle cũng bị chặn khi resource còn lease `ACTIVE`; hard delete chỉ dành cho property chưa có phòng, room chưa có lease/meter/invoice history và tenant chưa có lease/invoice history. Các trường room hiện có gồm `capacity`, `amenities` và `imageUrl` ngoài tên, tầng, diện tích, giá, status, lifecycle và ghi chú.

## Verification

Flutter:

```sh
cd /Users/hoang/Rental_room_management
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Backend:

```sh
cd /Users/hoang/rental-room-api
npm install
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
npm test
npm run build
```

Backend E2E dùng PostgreSQL test database riêng. Không chạy suite này với database dev/production vì helper sẽ reset dữ liệu:

```sh
cd /Users/hoang/rental-room-api
createdb rental_management_test # nếu database test chưa tồn tại
export DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management_test?schema=public"
npm run prisma:generate
npm run prisma:deploy
NODE_ENV=test DATABASE_URL="$DATABASE_URL" npm run test:e2e
```

E2E suite hiện chạy HTTP-level Nest app thật và cover auth lifecycle, refresh replay/logout, admin CRUD/authorization boundaries, cross-landlord `404`, lease room-status transitions, billing payment transitions, dashboard scoping và resource lifecycle archive/deactivate/delete constraints. Flutter test suite bổ sung API-client regression cho admin/billing, auth refresh/retry, onboarding persistence và lifecycle API contract cho property/room/tenant.

`npm run lint` hiện gọi ESLint với `--fix`, có thể sửa file; chỉ chạy khi chấp nhận hành vi đó.

Runtime manual flow nên kiểm tra health, register/login landlord, bootstrap/login admin, `/auth/me`, refresh, logout, property list/create/edit/select/archive/restore/delete unused, tác động của selected property tới Dashboard/Rooms, room/tenant create/edit/deactivate/reactivate/delete unused và create/end lease. Admin deep link vào landlord workflows phải redirect về `/admin`, và admin token gọi landlord resource endpoints phải nhận `403`. Với resource có lease active hoặc lịch sử billing/lease, UI phải hiển thị lỗi backend thay vì xóa dữ liệu.

## Important files

Flutter:

```text
lib/app/app.dart
lib/core/config/api_config.dart
lib/core/network/api_client.dart
lib/data/auth/
lib/data/admin/
lib/data/billing/
lib/data/onboarding/
lib/data/rooms/
lib/data/tenants/
lib/models/auth_models.dart
lib/models/admin_models.dart
lib/models/billing.dart
lib/models/property.dart
lib/models/room.dart
lib/models/tenant.dart
lib/models/lease.dart
lib/features/auth/
lib/features/admin/
lib/features/billing/
lib/features/dashboard/
lib/features/onboarding/
lib/features/rooms/
lib/features/tenants/
test/core/network/api_client_test.dart
test/data/admin/admin_api_test.dart
test/data/billing/billing_api_test.dart
test/features/onboarding/onboarding_persistence_test.dart
test/rooms_test.dart
```

Backend:

```text
src/main.ts
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
prisma/seed.ts
prisma/bootstrap-admin.ts
```

Xem [`IMPLEMENTATION_MAP.md`](IMPLEMENTATION_MAP.md) để biết mỗi feature cần những file nào và flow code end-to-end. Xem [`IMPLEMENTATION_CHECKLIST.md`](IMPLEMENTATION_CHECKLIST.md) để biết trạng thái code/test/verification, [`PROJECT_STATUS.md`](PROJECT_STATUS.md) để xem snapshot và giới hạn hiện tại, và [`UPDATE_LOG.md`](UPDATE_LOG.md) để xem lịch sử thay đổi.

## Security notes

- Không tạo admin qua public registration.
- Không commit password, `.env` thật, JWT secret hoặc refresh token.
- Không tin role hoặc resource ID do client gửi để quyết định quyền truy cập.
- Ownership scoping phải được enforce ở backend; Flutter route guard chỉ là UX guard.
- Không expose PostgreSQL ra public internet.
- Dùng HTTPS, secret manager, backup và CORS allowlist trong production.
- Không ghi password, token hoặc `Authorization` header vào log.
