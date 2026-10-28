# Implementation Checklist

Theo dõi trạng thái code, test source và runtime verification của Flutter client và NestJS backend. Bản đồ file và flow chi tiết của từng feature nằm trong [`IMPLEMENTATION_MAP.md`](IMPLEMENTATION_MAP.md); file này chỉ là checklist trạng thái.

## Quy ước

- ✅ Code/cấu trúc đã có
- 🟡 Code đã có nhưng runtime/E2E hoặc test chưa verify đầy đủ
- ⬜ Chưa triển khai
- ❌ Có lỗi cần xử lý

> ✅ chỉ nói về source. Không đánh dấu runtime đã pass nếu chưa có kết quả lệnh hoặc manual flow tương ứng.

## Flutter UI và auth

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| Splash, onboarding, responsive layouts | ✅ | Có trong `features/splash` và `features/onboarding`; onboarding completion persistence đã có |
| Login/register UI | ✅ | Public registration tạo landlord |
| Password visibility/loading/error states | ✅ | Dùng shared auth form |
| Forgot password/remember-me | ⬜ | Chưa có backend policy/API |
| Dashboard landlord shell | ✅ | Stats, chart, rooms/invoices sections |
| Dashboard data thật | 🟡 | Overview stats/revenue, attention và invoices đã nối API metrics; cần runtime verify với dữ liệu thật |
| Invoice/billing UI | ✅ | Có danh sách hóa đơn, tạo hóa đơn, ghi nhận thanh toán |
| Session restore | 🟡 | Code đã nối vào splash; backend `/auth/me` covered bởi E2E, cần app restart/device verify |
| Automatic refresh/retry | ✅ | Single-flight interceptor và retry một lần đã có Flutter regression tests; backend refresh replay/logout covered bởi E2E |
| Role route policy | 🟡 | `/dashboard` landlord, `/admin` admin; client route tests có, cần runtime verify |
| Onboarding persistence | ✅ | `shared_preferences` device-global flag, splash decision và onboarding actions có tests |

## Property và Room

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| Property/Room models | ✅ | `lib/models/property.dart`, `room.dart` |
| Property/Room API clients | ✅ | `lib/data/rooms/` |
| Repository/providers | ✅ | Có loading/error/refresh flow |
| Rooms list/filter/empty state | ✅ | `lib/features/rooms/rooms_list_screen.dart` |
| Room detail | ✅ | Có hiển thị thông tin room và lease liên quan |
| Room create/update UI | ✅ | Form và actions create/update đã có |
| Room lifecycle/delete UI | 🟡 | Deactivate/reactivate/delete action đã có trong room detail; cần chạy lại widget/analyzer/test |
| Property create/update UI | ✅ | Có `features/properties` list/form và `PropertyFormController` |
| Property archive/delete UI/API | 🟡 | Archive/restore/delete unused property đã có trong source; cần chạy lại backend E2E và Flutter verification |
| Backend Property/Room modules | ✅ | Controller/service/module đã có |
| Ownership scoping | ✅ | Service scope theo authenticated landlord ID |
| Landlord role guard | ✅ | Backend `RolesGuard`/`@Roles(AuthRole.LANDLORD)` đã áp dụng cho landlord resource endpoints; admin token nhận `403` trong E2E |
| Runtime CRUD verification | 🟡 | Backend E2E cover property/room/tenant ownership và representative create/read/lease flows; app/manual CRUD đầy đủ còn cần chạy |

## Tenant và Lease

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| Tenant/Lease models | ✅ | `lib/models/tenant.dart`, `lease.dart` |
| Tenant/Lease API clients | ✅ | `lib/data/tenants/` |
| Repository/providers | ✅ | Có state và API failure mapping |
| Tenant list/detail/form | ✅ | CRUD flow đã có trong `features/tenants` |
| Lease create/end/history UI | ✅ | Có form và lịch sử theo room/tenant |
| Backend Tenant/Lease modules | ✅ | Controller/service/module đã có |
| Lease room-status transaction | ✅ | Create/end lease cập nhật room status |
| Runtime tenant/lease verification | 🟡 | Backend E2E cover tenant ownership và lease create/end room-status transitions; Flutter manual flow còn cần chạy |

## Flutter authentication integration

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| Dio/API config | ✅ | Hỗ trợ `API_BASE_URL` qua `dart-define` |
| Secure token storage | ✅ | `flutter_secure_storage` |
| Login/register repository flow | ✅ | Riverpod session controller |
| `/auth/me` restore | 🟡 | Backend `/auth/me` covered bởi E2E cho landlord/admin; app restore trên device còn cần chạy |
| Logout cleanup | 🟡 | Backend logout/refresh invalidation covered bởi E2E; local storage cleanup còn cần app verify |
| Route guard `/dashboard` | 🟡 | Client auth redirect |
| Role guard `/admin` | 🟡 | Client admin/landlord redirect tests có; backend landlord-resource guard covered bởi E2E, không thay thế device verify |
| Token refresh concurrency | 🟡 | Single-flight code và Flutter tests có; chưa có device/backend concurrency verification |

## Backend và database

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| NestJS/Prisma structure | ✅ | Backend sibling `/Users/hoang/rental-room-api` |
| Native PostgreSQL local setup | ✅ | Native PostgreSQL 16 mặc định; Docker fallback |
| `User`/`RefreshToken` schema | ✅ | Auth và rotating refresh token |
| `Property`/`Room` schema | ✅ | Có migration và relation |
| `Tenant`/`Lease` schema | ✅ | Có migration và relation |
| Password hashing | ✅ | Argon2id |
| Refresh token storage | ✅ | SHA-256 digest lookup, unique index, transactional rotation |
| Auth endpoints | ✅ | register/login/refresh/logout/me |
| Health endpoint | ✅ | Database `SELECT 1` check |
| Global throttler | ✅ | Auth endpoint limits đã wiring |
| Helmet/CORS/ValidationPipe | ✅ | CORS production config cần kiểm tra runtime |
| Admin bootstrap CLI | ✅ | Không dùng public registration |
| Swagger/OpenAPI wiring | ⬜ | Dependency có, wiring chưa hoàn thiện |
| Global error envelope | ⬜ | Chưa nhất quán cho mọi lỗi |
| Role guard/decorator | ✅ | Landlord resource endpoints và admin controller có backend role guard; admin/landlord boundary covered bởi E2E |
| Admin landlords/properties CRUD | ✅ | Backend `/api/v1/admin/...` có overview, landlord management và property management; Flutter AdminApi tests cover client contract |
| Invoice/payment/meter reading | ✅ | Có Prisma schema/migration và REST API MVP |
| Audit log | ⬜ | Chưa có schema/API |
| Production backups/secret management | ⬜ | Chưa cấu hình |

## Database migrations

Các model hiện có trong Prisma schema:

- `User`, `RefreshToken`
- `Property`, `Room` (`isArchived`/`isActive` lifecycle fields in source)
- `Tenant`, `Lease` (`isActive` lifecycle field in source)
- `MeterReading`, `Invoice`, `Payment`
- `RoomStatus`, `LeaseStatus`, `UtilityType`, `InvoiceStatus`, `PaymentMethod`

Migration history hiện có các thay đổi auth, property/room, tenant/lease và room detail fields. Việc migration tồn tại trong source không có nghĩa database local hiện tại đã được migrate; chạy `npm run prisma:deploy` và `npx prisma migrate status` để xác minh từng môi trường.

## Tests có trong source

| Hạng mục | Trạng thái | Ghi chú |
|---|---:|---|
| Onboarding widget/responsive/persistence tests | 🟡 | Có test source cho responsive flow, persistence storage và splash decisions; cần chạy lại |
| Auth API/navigation/refresh tests | 🟡 | Có test source cho `/auth/me`, route policy, refresh/retry và coordinator single-flight; cần chạy lại |
| Room model/widget tests | 🟡 | `test/rooms_test.dart` |
| Property model/API/widget tests | 🟡 | `test/properties_test.dart`; cần chạy lại sau thay đổi mới nhất |
| Backend AuthService/unit authz tests | ✅ | AuthService, JwtStrategy, AuthRole, RolesGuard và controller metadata tests |
| Admin API tests | 🟡 | Flutter `AdminApi` contract tests có; backend admin E2E có, cần chạy lại |
| Billing API tests | 🟡 | Flutter `BillingApi` contract tests có; backend billing E2E có, cần chạy lại |
| Token refresh coordinator tests | 🟡 | Flutter single-flight coordinator và Dio retry tests có; cần chạy lại |
| Backend E2E suite | 🟡 | `test/e2e/*.e2e-spec.ts` với PostgreSQL test DB cover auth, admin CRUD, role/ownership, lease, billing, dashboard và resource lifecycle; cần chạy lại sau thay đổi mới nhất |
| Flutter/backend integration | ⬜ | Chưa có |
| Physical device test | ⬜ | Chưa có |

## Verification commands

Flutter:

```bash
cd /Users/hoang/Rental_room_management
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Backend:

```bash
cd /Users/hoang/rental-room-api
npm install
brew services start postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
pg_isready -h 127.0.0.1 -p 5432
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
npm test
npm run build
curl http://localhost:3000/api/v1/health

# Backend E2E với database test riêng
createdb rental_management_test # nếu chưa có
export DATABASE_URL="postgresql://rental_user:<your-password>@127.0.0.1:5432/rental_management_test?schema=public"
npm run prisma:generate
npm run prisma:deploy
NODE_ENV=test DATABASE_URL="$DATABASE_URL" npm run test:e2e
```

> `npm run lint` hiện dùng ESLint `--fix`, nên có thể thay đổi source. Backend E2E helper reset dữ liệu và chỉ chạy khi `NODE_ENV=test` và `DATABASE_URL` có marker `test`.

## Manual flow cần verify

1. Health endpoint và kết nối PostgreSQL.
2. Landlord register/login → `/dashboard`.
3. Bootstrap admin/login → `/admin`.
4. `/auth/me`, refresh và logout.
5. Admin deep link vào landlord routes redirect về `/admin`; admin token gọi landlord resource endpoints nhận `403`.
6. Property list/create/edit/select/archive/restore/delete unused, selected property ảnh hưởng Dashboard/Rooms và ownership isolation.
7. Room list/create/update/deactivate/reactivate/delete unused và ownership isolation.
8. Tenant create/update/deactivate/reactivate/delete unused.
9. Lease create/end, room status transitions và active-lease lifecycle guards.
10. Onboarding không lặp lại sau Skip/Close/Login/Register/Finish.
11. App restart, token expiry và session restore.

## Production checklist

- ⬜ HTTPS và reverse proxy.
- ⬜ Secret manager cho `DATABASE_URL`, JWT secrets và admin bootstrap.
- ⬜ Không expose PostgreSQL public.
- ⬜ `prisma migrate deploy` trong release pipeline.
- ⬜ Backup/restore PostgreSQL.
- ⬜ Tune và runtime verify throttling.
- 🟡 Backend enforce role và ownership policy cho landlord resources; admin-wide APIs còn chờ milestone riêng.
- ✅ Verify refresh-token rotation/replay defense bằng backend E2E.
- ⬜ Global error envelope và log redaction.
- ⬜ Backend E2E, Flutter integration và physical-device tests.

## Tài liệu liên quan

- `README.md`: quick start và API overview.
- `IMPLEMENTATION_MAP.md`: file nào thuộc feature nào, flow và trách nhiệm từng layer.
- `PROJECT_STATUS.md`: snapshot kiến trúc, giới hạn và milestones.
- `ADMIN_SETUP.md`: bootstrap admin và vận hành an toàn.
- `UPDATE_LOG.md`: lịch sử thay đổi theo thời gian.
