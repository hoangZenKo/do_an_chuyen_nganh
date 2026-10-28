# Update Log

File này ghi lịch sử thay đổi theo thời gian. Trạng thái hiện tại nằm trong [`PROJECT_STATUS.md`](PROJECT_STATUS.md); hướng dẫn chạy nằm trong [`README.md`](README.md).

## 2026-10-26 — Invoice line items and versioned service tariffs

- Thêm migration `20261026150000_invoice_line_items_service_tariffs`, `InvoiceLineItem` và `ServiceTariffVersion`; backfill invoice cũ thành dòng tương thích và baseline tariff legacy.
- Refactor single/bulk/preflight/automation billing để dùng cùng effective tariff calculator; snapshot `source`, `tariffVersion`, quantity, unit price và amount vào lúc phát hành.
- Thêm API tạo phiên bản, xem lịch sử, optimistic concurrency, chống backdate, chống thay đổi kỳ đã có hóa đơn và trigger DB bảo vệ snapshot bất biến.
- Cập nhật Flutter model/API/UI: invoice detail, tenant portal, room service fee history và form tạo phiên bản; giữ aggregate columns để tương thích client cũ.
- Verification: TypeScript/Nest build, backend Jest `395 passed / 7 skipped`, isolated invoice/tariff E2E `7 passed` kèm legacy backfill rehearsal; Flutter analyzer mục tiêu sạch và billing/room/tenant tests `44 passed`.
- Không migrate/reset/seed database đang dùng; readiness đọc-only còn thiếu migration settlement và invoice/tariff. Chưa nghiệm thu trên thiết bị/staging.

## 2026-10-26 — Landlord move-out settlement vertical slice

- Thêm migration `20261026133000_lease_settlement`, model `LeaseSettlement`/`LeaseSettlementLine` và API preview/confirm/refund cho landlord.
- Bảo vệ quyết toán bằng Serializable transaction, row lock, preview fingerprint, request hash, idempotency UUID, versioned refund, deposit ledger và audit log.
- Bổ sung Flutter screen/API, bỏ nút kết thúc hợp đồng cũ khỏi landlord flow, thêm validation response và giữ nguyên confirmation key khi retry network.
- Chặn race lập hóa đơn đơn lẻ/hàng loạt với settlement bằng room/lease lock, revalidation và cập nhật `updatedAt`; bổ sung 2 billing regression tests.
- Verification: backend build và 381 unit tests pass (7 skipped), 8 isolated settlement E2E tests pass, Flutter settlement API/widget 16 tests pass; disposable E2E tự tạo rồi xóa database tạm.
- Read-only readiness check xác nhận local còn thiếu migration settlement; không migrate/reset/seed database đang dùng. Runbook: `docs/landlord-settlement.md`; disposable E2E dùng `backend/scripts/run-settlement-e2e.mjs`.

## 2026-10-26 — Roadmap P0/P1 safety and admin inbox completion

- Thêm schema readiness strict theo toàn bộ migration/checksum/auth columns; `prestart:prod` chạy bản compiled, không dùng `tsx` devDependency.
- Thêm migration rehearsal/restore safety CLI và provider smoke connectivity probe với staging-only, timeout, redirect rejection và redaction.
- Hoàn thiện incident filter/pagination/deep-link, support SLA helper dùng chung, merged-ticket exclusion và moderation bulk preview trước mutation.
- Thêm regression coverage cho moderation preview, SLA filter, deep-link allowlist/session-permission guard; backend 359 tests, safety 10 tests và admin Flutter 52 tests pass.
- Full Flutter suite vẫn còn 11 lỗi dashboard floating navigation ngoài phạm vi admin; staging/provider/device verification chưa được thực hiện.

## 2026-10-26 — Admin operations release hardening

- Thêm step-up MFA one-time có ràng buộc session, action, payload fingerprint và expiry; bao phủ cả legacy landlord status route để không còn đường khóa tài khoản bỏ qua step-up.
- Hoàn thiện access review masking/version, incident assign/snooze/resolve/reopen, runbook/history và migration mở rộng constraint trạng thái `SNOOZED`.
- Hoàn thiện business-hours support SLA, escalation deduplication, support case links/timeline lọc theo permission và Flutter retry/permission/session states.
- Bổ sung API/widget/E2E regression: backend unit `328 passed`, admin release E2E `29 passed`, Flutter admin API/widget tests `50 passed`; `flutter analyze` còn 4 cảnh báo cũ ở dashboard.

## 2026-10-25 - Backend trong cung repository

- Di chuyen backend NestJS vao `backend/`; giu nguyen source, migrations, cau hinh local va uploads.
- Cap nhat tai lieu, duong dan seed anh va script doi chieu so do theo vi tri moi.
- Ignore `.env`, cac ban sao `.env.*`, `node_modules/`, `dist/` va `uploads/`; van quan ly version `.env.example`.
- Giu Docker Compose project name `rental-room-api` de khong doi ten volume mac dinh; khong chay migration, seed hoac reset database.
- Verification: Prisma generate va backend build thanh cong; Jest 21 suites / 196 tests pass, 1 suite / 7 tests skipped. Git ignore checks pass.

## 2026-09-08 — Tenant Portal maintenance flow

- Thêm màn `/tenant/maintenance` để khách thuê xem toàn bộ yêu cầu bảo trì với filter tất cả, đang mở, đang xử lý, đã xong và đã hủy.
- Nối shortcut “Sửa chữa” và section sửa chữa trong tenant portal sang danh sách đầy đủ, đồng thời giữ nút báo nhanh trên dashboard.
- Bổ sung form báo sự cố trong màn riêng với tiêu đề, mức độ, mô tả, link file và upload ảnh/PDF qua upload API hiện có.
- Bổ sung chi tiết ticket dạng bottom sheet: trạng thái, phòng, ngày báo, mô tả, file đính kèm, lịch sử trao đổi và gửi phản hồi kèm file.
- Verification đã chạy: `flutter analyze` và `flutter test test/data/tenant_portal/tenant_portal_api_test.dart test/features/auth/auth_navigation_test.dart`.

## 2026-09-08 — Tenant Portal invoice flow

- Thêm màn `/tenant/invoices` để khách thuê xem toàn bộ hóa đơn với filter tất cả, chưa trả, trễ hạn, chờ duyệt chứng từ và đã trả.
- Nối shortcut và section hóa đơn trong tenant portal sang danh sách đầy đủ, giữ dashboard là preview nhanh.
- Xác nhận luồng chi tiết hóa đơn tenant đã có PDF/share, upload ảnh/PDF chứng từ, submit payment proof và refresh dashboard/list/detail sau khi gửi.
- Xác nhận phía landlord/staff đã có pending payment proofs và review approve/reject; approve tự ghi payment và cập nhật trạng thái hóa đơn.
- Verification đã chạy: targeted `flutter analyze`, `flutter test test/data/tenant_portal/tenant_portal_api_test.dart test/features/auth/auth_navigation_test.dart`, và backend billing service test.

## 2026-09-08 — Billing automation hoàn chỉnh hơn

- Thêm backend worker tự động lập hóa đơn hằng tháng theo `BillingAutomation.isEnabled`, `invoiceDay` và `lastRunMonth`; worker mặc định tắt trong `NODE_ENV=test`.
- Scheduler dùng ngày nghiệp vụ Việt Nam, bỏ qua kỳ còn thiếu chỉ số điện/nước hiện tại để tránh tạo hóa đơn điện/nước bằng 0 ngoài ý muốn, và sẽ thử lại ở vòng sau.
- Bulk invoice preflight trả thêm `suggestedMeterReadings` từ kỳ trước để Flutter prefill chỉ số cũ ngay trong response chính.
- Thêm env điều khiển worker và reminder opt-in: `BILLING_AUTOMATION_WORKER_ENABLED`, interval/delay, `BILLING_AUTOMATION_SEND_REMINDERS` và reminder window.
- Verification đã chạy: backend `npm run build`, backend `npm test -- src/billing/billing.service.spec.ts --runInBand`, Flutter `flutter test test/data/billing/billing_api_test.dart` và targeted `flutter analyze` cho các file billing vừa sửa.

## 2026-08-08 — Giai đoạn 2 lifecycle quản lý phòng trọ

- Thêm lifecycle fields cho backend: `Property.isArchived`, `Room.isActive`, `Tenant.isActive`, kèm migration/index và partial unique index cho một active lease mỗi room.
- Bổ sung landlord endpoints cho property archive/restore/delete unused, room deactivate/reactivate/delete unused và tenant deactivate/reactivate/delete unused; backend chặn thao tác khi còn lease `ACTIVE` hoặc lịch sử cần giữ.
- Siết lease/dashboard/billing operational scope: không tạo lease với archived property/inactive room/inactive tenant; dashboard/billing active leases loại resource không còn vận hành.
- Cập nhật Flutter models/API/repositories/providers và UI để có active/archived/inactive filters, confirmation dialogs, restore actions và lifecycle error guidance.
- Cải thiện admin property form: tạo property bằng active landlord selector/search thay vì nhập raw Landlord ID; edit giữ landlord context read-only.
- Thêm Flutter lifecycle API tests và backend E2E source cho lifecycle constraints tại `test/e2e/resource-lifecycle.e2e-spec.ts`.
- Verification chưa hoàn tất vì Bash classifier đang lỗi khi chạy lệnh; cần chạy lại `dart format lib test`, `flutter analyze`, `flutter test`, `npm run prisma:generate`, `npm run build`, `npm test` và backend E2E với `NODE_ENV=test DATABASE_URL=...`.

## 2026-08-07 — Giai đoạn 1 ổn định app

- Xác nhận backend admin module hiện có overview, landlord management và property management dưới `/api/v1/admin/...`, được guard bằng `@Roles(AuthRole.ADMIN)` và có backend E2E coverage.
- Bổ sung Flutter tests cho admin API contract, billing API contract, Dio auth refresh/retry và `TokenRefreshCoordinator` single-flight behavior.
- Thêm onboarding persistence bằng `shared_preferences` qua abstraction/provider; splash route unauthenticated users tới onboarding hoặc login theo completion flag, và mọi action rời onboarding đều mark completed.
- Đồng bộ README, ADMIN_SETUP, PROJECT_STATUS, IMPLEMENTATION_CHECKLIST và IMPLEMENTATION_MAP để không còn mô tả admin landlords/properties CRUD hoặc role guard là missing; giữ rõ giới hạn admin chưa có CRUD cho rooms/tenants/leases/billing/audit/admin accounts.
- Verification cần chạy lại: `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`, và backend E2E với PostgreSQL test database.

## 2026-08-06 — Backend E2E / integration milestone

- Thêm shared Nest app bootstrap `src/app.bootstrap.ts` để E2E dùng cùng global prefix, Helmet, CORS và ValidationPipe như runtime.
- Thêm Jest E2E config riêng `test/jest-e2e.json`, cập nhật `npm run test:e2e` và bổ sung E2E harness/fixtures với PostgreSQL test database riêng.
- Thêm HTTP-level E2E suites cho auth lifecycle, `/auth/me`, refresh rotation/replay, logout invalidation, role guard admin `403`, cross-landlord `404`, property/room/tenant ownership, lease room-status transitions, billing invoice/payment transitions và dashboard scoping.
- Đồng bộ `README.md`, `PROJECT_STATUS.md`, `IMPLEMENTATION_CHECKLIST.md` và `IMPLEMENTATION_MAP.md` để ghi nhận E2E suite, test DB workflow và phạm vi đã covered. Flutter integration, physical-device verification, admin-wide CRUD và production readiness vẫn là milestone riêng.
- Verification: người dùng báo chạy không có lỗi sau khi thêm E2E suite.

## 2026-08-06 — Authorization hardening

- Thêm typed auth role mapping `landlord/admin` ở backend và reusable `Roles` decorator/guard dùng cho controller-level authorization.
- Áp dụng landlord-only policy cho dashboard, properties, rooms, tenants, leases và billing; `GET /auth/me` vẫn JWT-only nhưng role-neutral để cả landlord/admin đều restore session được.
- Cập nhật `AuthService`, `JwtStrategy` và `CurrentUser` để trả/nhận role typed thay vì string tự do.
- Bổ sung unit tests cho `AuthRole`, `RolesGuard`, `JwtStrategy` và metadata authorization của landlord-resource controllers.
- Đồng bộ Flutter route guard để admin deep link vào landlord workflows đều redirect về `/admin`.
- Cập nhật README, PROJECT_STATUS và IMPLEMENTATION_CHECKLIST để mô tả đúng policy authorization hiện tại; admin-wide CRUD vẫn để dành cho `/admin/...` APIs tương lai.

## 2026-08-06 — Property management hardening

- Xác nhận property management UI đã tồn tại trong source: list/select/create/edit, occupancy summary, empty/loading/error/retry states và liên kết selected-property sang Dashboard/Rooms.
- Sửa `PropertyFormScreen` để màn edit có error state kèm nút `Thử lại` khi không load được property list.
- Thêm `test/properties_test.dart` cho Property model, Property API, property list screen và property form screen.
- Đồng bộ `README.md`, `PROJECT_STATUS.md`, `IMPLEMENTATION_CHECKLIST.md` và `IMPLEMENTATION_MAP.md` để phản ánh đúng khả năng hiện tại và việc backend chưa có `DELETE /properties/:id`.

## 2026-08-06 — API-backed dashboard và billing nâng cao

- Thay dashboard overview mock bằng endpoint tổng hợp `/api/v1/dashboard/metrics`, Flutter data layer `lib/data/dashboard/`, model `lib/models/dashboard.dart` và providers `lib/features/dashboard/dashboard_providers.dart`.
- Dashboard hiển thị room stats, doanh thu thực thu, revenue trend, overdue/maintenance attention và recent invoices từ dữ liệu API thật; header dùng property đang chọn.
- Sửa dashboard notification/logout affordance và overflow trong attention cards.
- Nâng cấp billing flow: tạo invoice kèm meter readings trong một backend transaction, tránh ghi dở khi invoice hoặc meter reading bị trùng.
- Thêm validation điện/nước dạng optional group, duplicate invoice preflight, friendly billing error messages và filter hóa đơn `Trễ hạn`/status trong Flutter.
- Thêm local demo landlord credential vào `ADMIN_SETUP.md`; admin password thật vẫn không được ghi vào tài liệu.
- Flutter format/analyze/test đã được chạy sau thay đổi billing và phát hiện một số lỗi UI/analyze; source đã được sửa nhưng cần chạy lại để xác nhận pass cuối cùng. Backend billing test/build cũng cần chạy lại.

## 2026-08-04 — Documentation synchronization

- Đồng bộ tài liệu với source hiện tại của Flutter và `backend`.
- Ghi nhận Property, Room, Tenant và Lease đã có models, REST clients/modules, migrations và UI tương ứng.
- Thống nhất PostgreSQL 16 native qua Homebrew là local default; Docker Compose là fallback.
- Sửa mô tả automatic token refresh, throttling, Argon2id password hashing và SHA-256 refresh-token digest rotation.
- Cập nhật routes, endpoint contracts, schema fields và giới hạn authorization hiện tại.
- Làm sạch hướng dẫn admin để không dùng demo landlord credential làm ví dụ.
- Phân biệt source implementation với runtime/E2E verification chưa được xác nhận.

## 2026-07-26 — Property, room, tenant và lease features

- Thêm Prisma schema/migrations cho Property và Room, sau đó bổ sung Tenant và Lease cùng room detail fields.
- Thêm backend modules/controllers/services cho Property, Room, Tenant và Lease.
- Thêm Flutter models, API clients, repositories/providers và UI list/detail/form cho rooms và tenants.
- Thêm lease create/end/history flow; backend transaction cập nhật room status khi lease bắt đầu/kết thúc.
- Thêm demo seed cho dữ liệu property/room/tenant/lease.
- Thêm room model/widget tests trong `test/rooms_test.dart`.
- Trạng thái “Rooms placeholder” và “backend chưa implement Property/Room” trong các entry cũ đã được thay thế bởi feature rollout này; các entry cũ được giữ lại như lịch sử.

## 2026-07-24 — Authentication core update

- Khôi phục role routing: admin → `/admin`, landlord → `/dashboard`; xóa dev bypass trong `auth_navigation.dart`.
- Thêm Confirm Password và validation mật khẩu trùng nhau trong register.
- Đổi nút login thành copy trung lập `Log In`; bỏ Keep me signed in và Forgot Password khi chưa có backend policy.
- Sửa secure storage chỉ xóa auth keys, không dùng `deleteAll()`.
- Restore session không xóa credential khi timeout/mất mạng; chỉ clear khi refresh token bị backend từ chối.
- Thêm automatic `401` refresh/retry với single-flight coordinator trong Dio client.
- Backend dùng refresh-token SHA-256 lookup, unique index, transaction rotation, inactive-user checks và TTL từ environment.
- Bổ sung JWT current-user check, throttling auth endpoints, CORS production fail-closed và AuthService unit test cơ bản.
- Full formatter/analyzer/build/test chưa được xác nhận trong entry này; xem verification snapshot hiện tại trong `PROJECT_STATUS.md`.

## 2026-07-24 — Dashboard UI

- Triển khai dashboard landlord theo design mockup trong `lib/features/dashboard/dashboard_screen.dart`.
- Thêm header, stats, finance summary, revenue chart, rooms needing attention, recent invoices và bottom navigation.
- Dashboard vẫn dùng mock data; tab Invoice/billing chưa có data flow thật.
- Revenue chart hiện dùng cubic Bézier smoothing trong `CustomPainter`; không xem đây là Catmull-Rom implementation.

## 2026-07-24 — Auth routing and API contract

- Sửa Flutter authenticated user lookup từ `/me` thành `/auth/me`.
- Cập nhật Dio auth policy để protected `/auth/me` nhận Bearer token.
- Nối splash startup với session restore và role-based navigation.
- Thêm auth/role redirect policy và landlord dashboard logout.
- Thêm focused navigation và AuthApi tests; full Flutter verification vẫn cần chạy lại.

## 2026-07-23 — Onboarding and branding

- Rebuilt onboarding UI với layout constrained để tránh overflow.
- Thêm widget tests cho viewport 375x812, 390x844 và 430x932.
- Thêm 4-page Atrium Living onboarding flow với Skip/Close/Next/Previous.
- Thêm logo asset và cập nhật theme màu teal.
- Các verification cũ chỉ phản ánh thời điểm entry; không thay thế việc chạy lại test trên source hiện tại.

## 2026-10-25 — Admin Sprints 2–4

- Hoàn tất Support Center: ticket scoping, SLA/assignment, internal notes, user replies, notification center và optimistic locking.
- Hoàn tất Moderation v2: appeal độc lập, decision history, bulk theo từng item, moderation reports và SLA escalation.
- Hoàn tất Governance: feature flags, admin teams, permission simulator, read-only finance reconciliation và encrypted scheduled report exports.
- Thêm Flutter routes/UI cho `/support-center`, `/admin/support-center`, `/admin/moderation-v2`, `/admin/governance`, `/admin/finance-reconciliation`, `/admin/report-schedules`.
- Verification: backend build pass; full E2E 18 suites/144 tests pass; isolated migration up-to-date; Flutter targeted tests pass. Chưa claim production deployment.
## 2026-10-25 — Admin Sprint 5

- Added active auth-session/device management with per-session revoke and revoke-other-sessions flow.
- Added request-bound session validation, audit records, and access-token invalidation after session revocation.
- Added global redacted API error envelope with stable error codes and request IDs.
- Added environment-gated Swagger/OpenAPI documentation and regression coverage.
- Added permission-scoped admin search, support labels/templates/merge/CSAT, and versioned moderation policy/evidence snapshots.

## 2026-10-26 - Admin completion

- Added Support attachments with scanner gate, signed access, saved views, skills/capacity and workload auto-assignment.
- Added notification preferences, delivery retries/dead letters and operations queue monitoring.
- Added finance statement import/matching and maker-checker reconciliation proposals.
- Added timezone-aware reports, encrypted object-storage handoff, signed download links and retry actions.
- Added moderation evidence/history UI, business metrics and off-site backup gateway/CI safety checks.
- Verified migration `20261026090000_admin_completion` only on isolated DB `rental_chatbot_test_admin_completion_20261026`; production/working DB remains untouched.
- Completed finance/notification panel session and capability reactivity with 8 regression tests; verified 25 existing admin/API/CSV tests, 223 backend unit tests, backend build and 6 safety-script tests.
