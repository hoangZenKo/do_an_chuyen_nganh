# Rental Room Management

Admin MVP (24/10/2026): đã triển khai đủ 3 giai đoạn gồm phân quyền/MFA/audit,
quản lý tài khoản và hỗ trợ read-only, cùng moderation queue/dashboard.
Chi tiết endpoint, env và flow vận hành nằm trong `ADMIN_SETUP.md`.

P1 vận hành (25/10/2026): đã bổ sung quy trình trả phòng, checklist định kỳ,
thanh toán QR mở checkout thẻ demo nội bộ và trung tâm thông báo có lịch gửi/xác
nhận đã đọc. Không dùng payOS, API key thanh toán, ngân hàng thật hoặc tiền thật.
Xem `docs/p1-operations-2026-10-24.md` để chạy demo an toàn.

Luồng tìm phòng → xem phòng → tạo hợp đồng (23/10/2026): thêm yêu thích theo tài khoản, lịch xem và thông báo trong app, chuyển lịch đã xem thành hợp đồng, ledger tiền cọc cho người thuê và phản hồi pilot theo khu vực. Hướng dẫn migration, phạm vi và thử nghiệm: `docs/housing-journey-2026-10-23.md`. Chưa mở pilot hoặc mời người thật.

Chatbot tài liệu (22/10/2026): đã thêm API/RAG và Flutter chat dành cho chủ trọ. Xem docs/chatbot-implementation-2026-10-22.md; mặc định chưa bật pilot vì còn chờ duyệt tài liệu và đánh giá model thật.

Ứng dụng Flutter quản lý khu trọ, phòng, người thuê và hợp đồng. Backend NestJS nằm trong thư mục `backend/` của cùng repository.

> **Documentation status:** cập nhật ngày 2026-10-24. Nội dung dưới đây phản ánh source hiện tại; runtime/database verification vẫn phải chạy theo phần Verification.

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
- Billing với meter readings, invoices, payments, tạo hóa đơn hàng loạt, prefill chỉ số kỳ trước, PDF/share, reminders và worker tự động lập hóa đơn hằng tháng theo từng khu trọ.
- Tenant Portal invoice flow: khách thuê xem dashboard/list/detail hóa đơn, tải/chia sẻ PDF, upload chứng từ thanh toán và chủ trọ duyệt/từ chối chứng từ.
- Tenant Portal maintenance flow: khách thuê xem danh sách/filter yêu cầu bảo trì, tạo yêu cầu, upload ảnh/PDF và phản hồi trong ticket.
- Backend Prisma models và REST modules cho Property, Room, Tenant, Lease và Billing.
- Admin workspace 3 giai đoạn: capability-based permissions, MFA/TOTP và recovery codes, audit log, account suspend/restore/session revoke/PII reveal, support context read-only, moderation queue/assignment/decision và analytics.
- Admin overview và admin management cho landlords/properties qua `/api/v1/admin/...`, có backend role guard `ADMIN` và Flutter admin screens tương ứng.
- Flutter stability tests cho admin API contract, billing API contract, auth refresh/retry và onboarding persistence.

Chưa hoàn tất hoặc chưa được xác minh đầy đủ:

- Lifecycle archive/deactivate/delete cho property/room/tenant đã có trong source nhưng cần chạy lại formatter/analyzer/build/test và backend E2E với database test.
- Billing report nâng cao và full production verification cho worker tự động/reminders.
- Runtime verification cho tenant payment proof với upload file thật trên thiết bị/simulator.
- Runtime verification cho tenant maintenance với tạo ticket/comment và upload file thật trên thiết bị/simulator.
- Admin chưa có platform-wide CRUD cho rooms, tenants, leases, invoices, payments hoặc admin accounts; đây là giới hạn có chủ đích để bảo vệ dữ liệu tài chính và vận hành theo ownership.
- Admin account invite/reset delivery, MFA encryption key và external notification delivery vẫn cần cấu hình secret/webhook theo `ADMIN_SETUP.md` trước production.
- Flutter/backend integration tests và physical-device verification.
- Production runtime verification trên thiết bị thật/môi trường release.

## Architecture

```text
lib/              # Flutter client source
backend/          # NestJS REST API
  src/            # API modules, controllers and services
  prisma/         # Database schema, migrations and seed scripts
  test/           # Backend E2E tests
test/             # Flutter tests
pubspec.yaml      # Flutter dependencies
```

Frontend và backend dùng chung một Git repository nhưng vẫn chạy thành hai tiến trình riêng.
Các lệnh backend bên dưới chạy trong `backend/`. Không commit `.env`, các bản sao
`.env.*`, `node_modules/`, `dist/` hoặc `uploads/`; `backend/.env.example` là file mẫu
được quản lý version. PostgreSQL vẫn là dịch vụ bên ngoài source tree; việc gộp
thư mục không di chuyển hay reset database.

Nếu dùng Docker Compose, chạy từ `backend/`. Compose project name được giữ là
`rental-room-api` để tiếp tục dùng tên volume mặc định trước khi di chuyển.

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
cd /Users/hoang/Rental_room_management/backend
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
cd /Users/hoang/Rental_room_management/backend
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
cd /Users/hoang/Rental_room_management/backend
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

#### Chạy đồng thời hai giả lập iOS: chủ trọ và tenant

Hai giả lập cài cùng app nhưng giữ phiên đăng nhập riêng. Chỉ chạy **một backend và một database** trên Mac; cả hai app dùng `http://localhost:3000/api/v1`.

**Chuẩn bị lần đầu:** kiểm tra thiết bị và runtime có sẵn:

```sh
xcrun simctl list devices available
xcrun simctl list devicetypes
xcrun simctl list runtimes
```

Máy phát triển hiện dùng `iPhone 16` và runtime iOS 18.4. Nếu chưa có giả lập tên `iPhone Tenant`, tạo **một lần**:

```sh
xcrun simctl create \
  "iPhone Tenant" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16 \
  com.apple.CoreSimulator.SimRuntime.iOS-18-4
```

Nếu máy khác không có iOS 18.4, thay device type/runtime bằng ID từ danh sách trên. Không chạy lại lệnh `create` mỗi lần vì sẽ tạo thêm thiết bị trùng tên.

**Mỗi lần chạy:** mở Simulator, giữ `iPhone 16` đang chạy và mở thêm máy tenant. Bỏ qua lệnh `boot` nếu máy tenant đã ở trạng thái `Booted`:

```sh
open -a Simulator
xcrun simctl boot "iPhone Tenant"
xcrun simctl bootstatus "iPhone Tenant" -b
```

Nếu chưa mở máy chủ trọ, chọn **Simulator → File → Open Simulator → iPhone 16**. Nếu cửa sổ tenant chưa hiện, chọn **Window → iPhone Tenant**.

**Tab Terminal chủ trọ:** nếu app đang chạy trên `iPhone 16` thì giữ nguyên, không chạy thêm phiên Flutter cho cùng máy. Nếu chưa chạy:

```sh
cd /Users/hoang/Rental_room_management
flutter pub get
flutter run -d "iPhone 16" \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Đợi app thứ nhất mở xong rồi mở **tab Terminal mới** (`Cmd + T`) để chạy tenant:

```sh
cd /Users/hoang/Rental_room_management
flutter run -d "iPhone Tenant" \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

- `iPhone 16`: đăng nhập tài khoản chủ trọ.
- `iPhone Tenant`: đăng nhập tài khoản tenant đã liên kết với người thuê/hợp đồng của chủ trọ đó.
- Giữ hai tab Flutter và backend chạy. `r` hot reload riêng app của tab hiện tại; `q` dừng phiên Flutter đó.
- Nếu Flutter báo nhiều thiết bị trùng tên, chạy `flutter devices` rồi thay tên sau `-d` bằng UUID của đúng giả lập.
- Có thể test chủ trọ tạo hóa đơn → tenant xem/gửi chứng từ → chủ trọ xác nhận. Tải lại màn hình nếu dữ liệu chưa tự cập nhật.
- Nếu dùng Zalo demo trên cả hai máy, cài app Zalo riêng lên từng giả lập theo bước 4, chỉ rõ `-d "iPhone 16"` hoặc `-d "iPhone Tenant"`.

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

### 5. Chạy Ollama cho trợ lý tài liệu

Ollama chạy **một lần trên Mac**, không chạy trong từng giả lập. Luồng gọi là Flutter → backend NestJS → Ollama. Chatbot hiện chỉ dành cho **chủ trọ**, không phải tenant; chỉ trả lời từ tài liệu đã duyệt, không đọc công nợ trực tiếp hoặc thực hiện thao tác nghiệp vụ.

**Chạy lại hằng ngày khi model và chatbot đã được thiết lập:**

1. Kiểm tra Ollama bằng `curl http://127.0.0.1:11434/api/tags`.
2. Nếu không kết nối được, mở một tab Terminal riêng và giữ tiến trình này chạy:

```sh
OLLAMA_HOST=127.0.0.1:11434 ollama serve
```

3. Giữ backend chạy theo bước 1 và Flutter theo bước 3. Nếu vừa sửa `backend/.env`, dừng backend bằng `Ctrl + C` rồi chạy lại `npm run start:dev` trong `backend/`.
4. Trên app chủ trọ, mở biểu tượng quyển sách ở Dashboard hoặc **More / Management Menu → Trợ lý tài liệu**, rồi gửi câu hỏi mới.

Nếu `ollama serve` báo `address already in use`, kiểm tra lại `/api/tags`: có thể Ollama app hoặc một tiến trình Ollama khác đã phục vụ cổng 11434; không cần chạy thêm server.

**Thiết lập lần đầu trên máy mới:** nếu chưa có lệnh `ollama`, cài bằng Homebrew:

```sh
brew install ollama
```

Khởi động `ollama serve` như trên, rồi mở tab Terminal khác để tải các model còn thiếu:

```sh
ollama pull qwen2.5:7b
ollama pull embeddinggemma:latest
ollama list
curl http://127.0.0.1:11434/api/tags
```

Không cần `pull` mỗi lần chạy. Không tự cập nhật model embedding cho database đã có chỉ mục: tag `latest` có thể đổi digest và khiến chỉ mục không tương thích.

Chỉ sửa các biến chatbot trong `backend/.env`, giữ nguyên database/JWT/cấu hình khác; **không chép đè `.env` đang dùng bằng `.env.example`**:

```env
CHATBOT_ENABLED=false
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_CHAT_MODEL=qwen2.5:7b
OLLAMA_EMBED_MODEL=embeddinggemma:latest
OLLAMA_EMBED_DIGEST=<digest 64 ky tu hex cua embeddinggemma:latest tu /api/tags>
OLLAMA_EMBED_DIMENSIONS=768
CHATBOT_TIMEOUT_MS=60000
KNOWLEDGE_ROOT=knowledge
```

Thay placeholder digest trước khi khởi động backend; dùng digest **model embedding**, không phải model chat. Giữ Ollama ở loopback, không mở cổng 11434 ra internet và không đổi URL Flutter sang cổng này.

Với database mới, cần migration chatbot, tài liệu được duyệt, import chỉ mục và hiệu chỉnh `RAG_MIN_SCORE` trước khi đổi `CHATBOT_ENABLED=true`. Thiếu digest hoặc score khi bật chatbot sẽ gây `CHATBOT_INVALID_CONFIG`. Chỉ import sau khi xác nhận `DATABASE_URL` đúng đích và manifest đã được duyệt; dừng backend trong lúc bảo trì chỉ mục:

```sh
cd /Users/hoang/Rental_room_management/backend
npm run knowledge:import -- --manifest knowledge/manifest.json
```

Không cần import lại mỗi lần bật máy. Nếu đổi model embedding/digest hoặc tài liệu, thực hiện lại quy trình import/đánh giá theo runbook, không chỉ thay digest để bỏ qua lỗi tương thích.

Cấu hình local được ghi nhận ngày **22/10/2026** đã có 6 tài liệu được duyệt, 19 chunks và score thử nghiệm `RAG_MIN_SCORE=0.4423`. Đây là dữ liệu lịch sử cho corpus/model tương ứng, **không phải ngưỡng mặc định cho mọi máy hoặc xác nhận đạt pilot/production**. Xem [local setup](backend/docs/chatbot-local-setup-2026-10-22.md), [runbook](backend/docs/chatbot-mvp-runbook.md) và [API/pilot gates](backend/docs/chatbot-api-and-pilot.md) trước khi bật trên môi trường mới.

Kiểm tra model đang nạp bằng `ollama ps`; giải phóng RAM khi không dùng bằng `ollama stop qwen2.5:7b` và `ollama stop embeddinggemma:latest`. Hai giả lập cùng model 7B có thể gây áp lực RAM; nếu máy chậm, đóng app không cần thiết. Các lệnh CLI Ollama tham khảo từ [tài liệu chính thức](https://docs.ollama.com/cli).

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
PATCH  /api/v1/billing/invoices/:id
POST   /api/v1/billing/invoices/:id/cancel
GET    /api/v1/billing/invoices/:id
POST   /api/v1/billing/invoices/:id/payments
POST   /api/v1/billing/invoices/:invoiceId/payments/:paymentId/reverse
POST   /api/v1/billing/invoices/bulk/preflight
POST   /api/v1/billing/invoices/bulk
GET    /api/v1/billing/reminders
POST   /api/v1/billing/reminders/run
GET    /api/v1/billing/automation
PUT    /api/v1/billing/automation
POST   /api/v1/billing/automation/preview
POST   /api/v1/billing/automation/run
```

Tenant portal endpoints:

```http
GET    /api/v1/tenant/me
GET    /api/v1/tenant/dashboard
GET    /api/v1/tenant/invoices
GET    /api/v1/tenant/invoices/:id
POST   /api/v1/tenant/invoices/:id/payment-proofs
GET    /api/v1/tenant/maintenance
POST   /api/v1/tenant/maintenance
POST   /api/v1/tenant/maintenance/:id/comments
```

Billing automation worker env:

```env
BILLING_AUTOMATION_WORKER_ENABLED=true
BILLING_AUTOMATION_INTERVAL_MS=3600000
BILLING_AUTOMATION_INITIAL_DELAY_MS=10000
BILLING_AUTOMATION_SEND_REMINDERS=false
BILLING_AUTOMATION_REMINDER_DUE_SOON_DAYS=60
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
cd /Users/hoang/Rental_room_management/backend
npm install
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
npm test
npm run build
```

Backend E2E dùng PostgreSQL test database riêng. Không chạy suite này với database dev/production vì helper sẽ reset dữ liệu:

```sh
cd /Users/hoang/Rental_room_management/backend
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

Tài liệu dự án được tập trung trong `docs/`; thư mục gốc chỉ giữ `README.md` và `ADMIN_SETUP.md`.

Xem [`IMPLEMENTATION_MAP.md`](docs/IMPLEMENTATION_MAP.md) để biết mỗi feature cần những file nào và flow code end-to-end. Xem [`IMPLEMENTATION_CHECKLIST.md`](docs/IMPLEMENTATION_CHECKLIST.md) để biết trạng thái code/test/verification, [`PROJECT_STATUS.md`](docs/PROJECT_STATUS.md) để xem snapshot và giới hạn hiện tại, và [`UPDATE_LOG.md`](docs/UPDATE_LOG.md) để xem lịch sử thay đổi.

## Security notes

- Không tạo admin qua public registration.
- Không commit password, `.env` thật, JWT secret hoặc refresh token.
- Không tin role hoặc resource ID do client gửi để quyết định quyền truy cập.
- Ownership scoping phải được enforce ở backend; Flutter route guard chỉ là UX guard.
- Không expose PostgreSQL ra public internet.
- Dùng HTTPS, secret manager, backup và CORS allowlist trong production.
- Không ghi password, token hoặc `Authorization` header vào log.
