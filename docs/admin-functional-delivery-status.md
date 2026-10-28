# Admin Functional Delivery Status

Cập nhật: 28/10/2026 (Asia/Ho_Chi_Minh). Mục mới nhất là checkpoint follow-up bên dưới; Phase 0–5 Admin và các milestone trước được giữ làm lịch sử.
Phạm vi lượt này: milestone 1–3 của Admin Console và ba điểm hardening bổ sung (release preflight, platform search, moderation QA). Không chạy migration, không deploy production và không thay đổi nghiệp vụ lease, settlement, invoice pricing, receipt allocation hoặc tenant lifecycle.

Phê duyệt ban đầu chỉ cho DB test cô lập. Follow-up user request ngày 28/10/2026 đã cho phép backup, rehearsal và guarded migration trên local `rental_management`; đã hoàn tất. Staging/production không thuộc phạm vi.

## Project follow-up Phases 1–5 — Checkpoint 28/10/2026

- Added a shared-theme Admin permission editor and read-only `GET /admin/admins/:id/access` with `private, no-store`. Only a live active super-admin may customize individual capabilities; ordinary preset callers retain their workflow subject to the delegation ceiling.
- Existing MFA/version/self-change/last-super-admin checks remain. Capability changes revoke sessions and review evidence and persist an audit snapshot atomically; explicit, preset-only and invitation flows cannot grant capabilities missing from the operator.
- The editor shows assigned capabilities and differences from its preset; session/permission loss invalidates the draft, and changed versions or delegation authority require a fresh read. No automatic permission elevation or data migration.
- Full current Flutter suite: **637 pass**. Backend: **716 pass, 7 skipped**; build pass. Admin disposable-DB E2E: **42 pass / 6 suites**, test database dropped. New editor/provider/focused-test analysis: no issues; broader dashboard analysis retains two old unused-section warnings and two const hints.
- iPhone 16/iOS 18.4 fixture-only visual spot check and simulator build passed; the separate preview app was uninstalled. No live Admin/MFA/provider/staging acceptance claim.
- Follow-up Phase 3 adds overdue-invoice navigation; Phase 4 resolves the prior dashboard/chatbot regressions. Phase 2 real subscription checkout/settlement is not implemented without a provider contract. Phase 5 inventory is complete, but new product expansion remains open. These follow-up phase numbers are not the original Admin Phase 0–5 milestones.
- Evidence and outstanding scope: `docs/superpowers/plans/2026-10-28-project-follow-up-phases.md`. No working DB writes or deployment in this pass; earlier failure counts below are historical.

## Phase 0–5 — Implementation ngày 28/10/2026

### Đồng bộ UI và loại bỏ legacy — 28/10/2026

- Đã xóa Dashboard Admin cũ không còn caller, renderer Dashboard dự phòng và barrel `admin_sprints_screen.dart`; các trang còn hoạt động giữ nguyên route/workflow.
- Nhóm route Admin có một boundary theme sáng chung, gồm loading/error/phiên thay đổi và dialog; không đổi theme các phân hệ ngoài Admin. SLA dùng shell chung, danh mục chủ trọ dùng section/empty/error pattern mới.
- Thay palette cyan/teal cũ bằng token overview; form chủ trọ/khu trọ không dùng widget Tenant có nhãn trắng nữa. Chuẩn hóa input, dialog, card và nhãn tiếng Việt tại các màn này.
- `flutter test test/features/admin test/features/auth test/data/admin --reporter expanded`: **212 pass**. Analyzer không có error/warning, còn 7 style info cũ. Kiểm tra trực quan iPhone 16/iOS 18.4 bằng fixture cô lập cho form khu trọ và Support Center; chưa phải full manual acceptance trên dữ liệu thật.

### Trạng thái bàn giao

Code đã triển khai theo từng phân hệ; **chưa phải production acceptance**. Local working DB đã guarded migrate theo phê duyệt sau đó; chưa deploy production. Ledger: `tasks/admin-completion-progress.md`; plan: `docs/superpowers/plans/2026-10-28-admin-console-completion.md`.

| Phân hệ yêu cầu ban đầu | Route chuẩn | Trạng thái và giới hạn |
| --- | --- | --- |
| Dashboard | `/admin`, `/admin/overview` | Implemented: dữ liệu API, growth, occupancy; partial: doanh thu subscription settled chưa có nguồn |
| Tài khoản | `/admin/accounts`, `/admin/landlords` | Implemented: danh sách, lifecycle, session, quyền/reveal/audit theo capability |
| Khu trọ | `/admin/properties`, `/admin/property-reviews` | Implemented: light shell thống nhất, inventory, quyết định versioned, phát hiện snapshot thay đổi |
| Phòng | `/admin/rooms` | Implemented: tìm kiếm, trạng thái, giá, occupancy/listing context; không sửa lease/payment từ Admin |
| Xác minh chủ trọ | `/admin/landlord-verifications`; self API `/landlord-verification` | Implemented: hồ sơ có scan evidence, approve/reject/needs-info; partial: không phải tích hợp pháp lý/KYC bên ngoài |
| Giao dịch | `/admin/finance-reconciliation` | Implemented: reconciliation và panel LINK/PAYMENT/EVENT có filter/phân trang; partial: không retry provider hay tự sửa ledger |
| Gói dịch vụ | `/admin/service-plans`, `/admin/subscriptions` | Implemented: Free/Pro/Premium, snapshot, quota, expiry, đổi/hủy, history; partial: chưa có thu tiền subscription |
| Khiếu nại/hỗ trợ | `/admin/support-center` | Implemented: ticket, evidence, assignment/SLA, case context; giữ workflow hiện có |
| Thông báo | `/admin/notifications` | Implemented: compose/preview và delivery queue hiện có; provider delivery thật vẫn cần staging evidence |
| Báo cáo | `/admin/reports/overview`, `/admin/reports` | Implemented: tổng quan và scheduled reports; doanh thu nền tảng tiếp tục unavailable |
| Cấu hình | `/admin/governance`, `/admin/policies`, `/admin/service-plans` | Implemented: policy/flags/quota có guard và audit; không expose secret |
| Nhật ký/bảo mật | `/admin/audit-logs`, `/admin/security`, `/admin/operations` | Implemented: filter/detail/CSV, session/MFA/incident/readiness; partial: recovery/release evidence chưa nghiệm thu |

### Điểm tích hợp mới

- `AdminWorkspaceScaffold` trở thành access/session adapter của `AdminOverviewShell`, không còn shell tối riêng ở Khu trọ và các form/chủ trọ liên quan. Root `/admin` dùng overview chuẩn.
- Registry APIs/UI dùng capability riêng, optimistic version, reason, transaction, audit và step-up theo policy. Xác minh Admin cần cả `admin.verifications.view` và `admin.support.read`; tài liệu đi qua Support scanner/access hiện có.
- Duyệt khu trọ độc lập với archival/listing moderation. Sửa thông tin sau duyệt trả trạng thái effective `NEEDS_INFO`; xóa khu trọ đã có review trả 409, hướng dẫn archive để giữ lịch sử.
- Gói tính trên chủ trọ, giới hạn khu trọ/phòng đang hoạt động. Assignment khóa owner để serialize tăng inventory, chặn downgrade vượt quota. Expiry/cancel chặn tăng trưởng; không xóa inventory, không tạo payment/refund. Chủ trọ chưa có subscription giữ hành vi legacy, không tự backfill Free.
- Catalog sửa version không thay snapshot đã cấp. History append theo assignment/change/cancel; không có API update/delete event, nhưng không tuyên bố có DB immutability trigger.
- Transaction investigation chỉ đọc projection an toàn, tối đa 50 dòng/trang và khoảng 93 ngày; không expose checkout URL/QR/bank account/provider raw reason/reference. Tiền thuê và entitlement hành chính không được cộng vào doanh thu nền tảng.
- Audit deep link áp dụng filter `resourceId`; các query không hỗ trợ bị bỏ. Export giữ authenticated bounded CSV/clipboard hiện có, không tạo signed public export link mới.
- Không tự nâng quyền profile Admin đã lưu. Operator cần rà soát/cấp rõ các capability mới `admin.verifications.view/manage`, `admin.plans.view/manage` trước khi thấy và thao tác các mục tương ứng.

### Bằng chứng kiểm thử

- Backend `npm run build`: pass. `npm test -- --runInBand`: 696 pass, 7 skip, 68 suites pass.
- Disposable PostgreSQL migration + Admin E2E: 41 pass / 6 suites. Có test owner isolation, scan evidence, stale decision, changed snapshot, concurrent quota, cancellation giữ inventory/không tạo payment, transaction permission/redaction.
- Safety scripts: 11 pass; disposable-runner safety: 8 pass. Những log 500/503 trong account E2E là fault-injection scenarios có assertion, không phải failure của bộ test.
- Flutter Admin/Auth/API rerun cuối: 173 pass, gồm registry/transaction mobile 320px/200% text và end-of-day date filter.
- Chạy thêm toàn bộ `flutter test`: 567 pass, 11 fail đều thuộc `test/features/dashboard/dashboard_chatbot_entry_test.dart` (floating navigation ngoài Admin: overflow và finder không còn khớp). Không sửa phần ngoài phạm vi này; không tuyên bố toàn dự án đã xanh.
- Analyzer không có error; còn 7 style infos (`curly_braces_in_flow_control_structures`) trong moderation quality panel và search quality tests hiện có, không bị che bằng suppressions.
- Xcode build và runtime iPhone 16/iOS 18.4 dùng Nest API thật trên DB mới cô lập: dashboard 2 users/1 property/2 rooms, masked accounts, Khu trọ light UI, room prices/status, verification pending queue, property-review empty state, Free/Pro/Premium catalog. Dữ liệu synthetic; không sửa dữ liệu làm việc.
- Chưa nghiệm thu bằng manual device flow toàn bộ finance/support/notifications/audit. Không suy ra full runtime acceptance từ widget/E2E. Repo hiện cấu hình iOS; web bootstrap thiếu platform shell không được dùng làm bằng chứng đạt.
- Đã dừng API/web-server tạm, harness xác nhận cleanup DB runtime cô lập và đã xóa entry Flutter thử nghiệm; không để test credential/session vào storage thật hay thay backend config người dùng.

### Local migration completed / release gates còn mở

1. Local `rental_management` đã apply `20261028090000_admin_registries` qua guard sau encrypted backup, restore-check và rehearsal trên DB cô lập. Readiness hiện `ready=true`, auth/billing schema ready, không missing/drifted/failed/unexpected; có 53 migration đã apply.
2. Prisma generate/build/start:dev đạt, health live/ready HTTP 200. So sánh backup giữ nguyên 103 bảng cũ; chỉ timestamp `WorkerHeartbeat` cập nhật trước migration khi worker còn chạy. Các route mới HTTP 401 khi chưa auth; chưa làm authenticated smoke trên DB làm việc. Gói/verification/subscription tables mới rỗng và không tự nâng quyền Admin. Chi tiết manifest và restore evidence trong ledger/runbook; backup local chưa có off-site durability.
3. Product chốt bằng chứng cá nhân/doanh nghiệp cho verification và hợp đồng thu phí subscription/settlement/refund/tax. Chưa có settled provider evidence thì doanh thu nền tảng vẫn unavailable.
4. Staging provider smoke, off-site restore drill, full desktop/mobile runtime acceptance, người chịu trách nhiệm rollout/rollback và deployment approval vẫn bắt buộc. Phase 5 release gate giữ mở.

## Đã có trước

- Backend đã có capability-based admin authorization, MFA/TOTP/recovery, JWT session-version check, access review, step-up, audit và incident workflow.
- Support, moderation, finance reconciliation read-only, report delivery, notification delivery, attachment scanner/signed URL và workspace action items đã có source/test riêng.
- Flutter đã có design system/workflow widgets, session-change invalidation, permission-gated admin surfaces và operations incident UI.

## Thay đổi mới

### Milestone 1 — Release gate và permission matrix

- Thêm inventory sinh từ metadata controller tại `docs/admin-permission-matrix.md`, bao gồm route, HTTP method, role, capability, preset giao nhau và step-up action.
- Thêm `backend/src/admin/admin-release-gate.spec.ts` để dò route động, kiểm thử fail-closed khi revoke từng capability, role boundary và ngoại lệ MFA self-enrollment.
- Thêm `backend/src/admin/admin-release-http.spec.ts` cho HTTP authorization thật với mock persistence: anonymous/non-admin 401/403, permission/session-version revocation, step-up single-use và exact payload.
- Attachment signed URL binding thêm `sessionId`; `backend/src/uploads/admin-attachment-authorization.spec.ts` kiểm thử requester ownership, PII/internal attachment boundary, permission revoke, session revoke, version conflict và tamper.

### Milestone 2 — Admin account lifecycle và access review

- Thêm `AdminLifecycleController/Service`: lifecycle detail, resend invite trước activation với cooldown 60 giây, revoke toàn bộ admin session/refresh token, version conflict và self-action guard.
- Resend dùng lại `AccountAccessService`/one-time token queue; không trả token, URL kích hoạt hoặc payload nhạy cảm. Audit before/after nằm trong cùng transaction.
- Deactivation/admin profile update thu hồi `AuthSession`, refresh token và lời mời pending; audit ghi preset, permission, trạng thái và session version trước/sau.
- Access review giữ team/preset/MFA, bổ sung cảnh báo overdue/unreviewed/inactive; team membership reset review state và ghi before/after.
- Flutter bổ sung lifecycle panel cho lời mời/session/history và cảnh báo review; self-approval vẫn bị ẩn/chặn.

### Hardening bổ sung — search, moderation quality và release preflight

- Global search hỗ trợ `kind`, `page`, `limit`, `total`, `hasMore`; bổ sung lease/payment vào kết quả tổng hợp và ghi audit cho đọc resource nhạy cảm. PII account/email/phone vẫn mask mặc định; lookup vẫn read-only.
- Moderation quality hỗ trợ khoảng thời gian explicit ISO8601, timezone IANA, appeal reopen rate có định nghĩa rõ và mẫu QA lấy deterministic theo hash. Reviewer phải có quyền theo loại nội dung và không được review quyết định của chính mình.
- Thêm `ModerationQualityReview` với version conflict, reason, audit before/after; QA không sửa quyết định, không tạo sanction và không thay đổi ledger/resource.
- Release preflight chỉ đọc cấu hình; operations summary trả blocker, manual evidence bắt buộc và không đổi `productionAccepted=true` từ unit test/configuration.
- Backup telemetry tùy chọn dùng envelope HMAC, database fingerprint, checksum/durable off-site receipt; API chỉ trả age khi chữ ký và binding hợp lệ. Restore rehearsal vẫn là bước nghiệm thu riêng.

### Milestone 3 — Operations command center

- Health summary trả readiness schema với trạng thái `READY`, `NOT_READY` hoặc `UNAVAILABLE`; không còn coi database query thành công là schema acceptance.
- Backup age chỉ hiển thị khi envelope HMAC được bind với database fingerprint, checksum archive và durable off-site receipt; nếu thiếu chứng cứ API vẫn trả `UNKNOWN`/`null`.
- Thêm delivery-job projection chỉ đọc, bounded pagination, không chọn payload/token, redaction lỗi và không có manual retry khi semantics chưa được chứng minh idempotent.
- Incident detail trả deep link runbook; Flutter hiển thị readiness, backup telemetry state, report queue và delivery investigation panel. Incident acknowledge/assign/snooze/resolve/reopen hiện có được tái sử dụng.

## Tests thực chạy

### Chạy lại theo yêu cầu người dùng — 27/10/2026 08:07 (Asia/Ho_Chi_Minh)

- `npm run build` — pass; `npm test -- --runInBand` — 56 suites pass, 1 skipped; 605 tests pass, 7 skipped.
- `npm run test:safety-scripts` — 11 tests pass; `flutter test test/features/admin` — 67 tests pass.
- `npm run ops:preflight` — pass kiểm tra migration history, read-only; còn pending `20261027090000_tenant_lifecycle_execution`, `20261027100000_payment_proof_idempotency`, `20261027180000_admin_moderation_quality`.
- `npm run ops:readiness` — exit 1, `ready=false`; thiếu ba migration trên, `authSchemaReady=false`, `billingSchemaReady=false`; không phát hiện migration drift/failed/unexpected.
- `npm run ops:admin-preflight` — exit 1, `BLOCKED`, `productionAccepted=false`, `databaseAccessed=false`; thiếu MFA, step-up, account delivery, scanner, report storage, alert receiver và backup/restore configuration; backup `UNKNOWN`.
- Database cấu hình trỏ host local. Health probe `localhost:3000/api/v1/health/live` không kết nối được; chưa khởi động API/Flutter app vì readiness chưa đạt. Widget tests không phải device acceptance.
- Lượt chạy này không sửa source/configuration, không apply migration, reset DB, chạy DB E2E, backup/restore, gọi provider, commit hoặc deploy. Không tự apply migration tenant/payment của phiên nghiệp vụ; cần xác nhận môi trường cô lập và phạm vi migration trước bước có ghi DB.

### Xác minh trên DB test cô lập — 27/10/2026 08:15–08:25 (Asia/Ho_Chi_Minh)

- Đã tạo DB riêng `rental_admin_test_20261027081353`; không chạm DB local hiện tại, staging hoặc production.
- Đã apply đủ 52 migration vào DB test; `npm run ops:readiness` với DB này trả `ready=true`, không có `missing`, `drifted`, `failed` hoặc `unexpected` migration.
- Full E2E trên DB test này: `22` suite pass, `9` suite fail (`152` tests pass, `75` fail). Trong đó settlement, billing-production, app-functional, invoice-tariffs, staff-lifecycle và chatbot bị chặn do yêu cầu disposable runner/DB name chuyên biệt. Có failure authorization ở operations/security-discovery (403 khác kỳ vọng 200/404) cần điều tra riêng; không kết luận full E2E đạt, không sửa nghiệp vụ ngoài phạm vi Admin.
- Admin E2E chuyên biệt: `11` suite pass, `57/57` tests pass, gồm lifecycle, authorization, revocation, audit, operations, search và moderation policy.
- Smoke staging-style chạy trên API local test: `16/16` checks pass (health/readiness, anonymous/non-admin denial, admin access, audit validation, finance boundary, notification preferences).
- Gọi API thực tế xác nhận search trả pagination `page/limit/total/hasMore`, PII account được mask; quality metrics, QA samples và lease/payment read-only lookup trả 200 theo quyền.
- Đã khởi động API test tại `http://localhost:3101` và Flutter web preview tạm tại `http://127.0.0.1:3100`; đã đăng nhập bằng tài khoản synthetic và xem được Dashboard, Operations Console, Platform Search và Moderation Policy/QA.
- Operations UI vẫn hiển thị `Release gate: BLOCKED`, backup `UNKNOWN` và các blocker provider/MFA/alert đúng thiết kế; DB migration/readiness đạt không đồng nghĩa production acceptance.

- Backend build: `npm run build` — pass.
- Preflight thực chạy lúc 27/10/2026 07:39 (Asia/Ho_Chi_Minh): `npm run ops:admin-preflight` — `BLOCKED`, `databaseAccessed=false`; local chưa cấu hình MFA/step-up, account delivery, scanner, report storage, alert receiver và backup toolchain/telemetry. Không gửi provider request hoặc chạy restore/migration.
- Backend full unit suite: `npm test -- --runInBand` — 56 suites pass, 1 suite skipped; 605 tests pass, 7 skipped. Bao gồm release gate, release HTTP, lifecycle, access review, PII projection, queue, readiness, search, moderation QA, backup telemetry và attachment authorization.
- Backend new hardening tests: search, moderation QA/quality metrics, backup telemetry, operations release blockers và release preflight — 11 new tests pass; backup/provider/safety scripts — 11 tests pass.
- Flutter analyze 7 file của lượt hardening (search screen/results, moderation quality panel, policy screen, production panels, console providers và app router) — không phát hiện issue. Analyze targeted milestone lifecycle/access review trước đó cũng pass.
- `npx prisma validate` — pass; `prisma generate` chỉ sinh client local, không apply migration.
- Flutter targeted: existing admin workflow/session suites plus `admin_search_quality_test.dart` — 52 tests pass, gồm pagination search, QA sample, independent review, revocation và large-text mobile/desktop.
- Đã xem ảnh widget-render QA/search ở 390 px chữ lớn và 1200 px; đây là ảnh test harness, không phải nghiệm thu Simulator/device thật.
- Chưa coi test pass là production acceptance; chưa thực provider/device/staging/backup-restore verification.

## Phần còn thiếu

- Đã chạy full backend unit suite, Admin E2E với DB test cô lập và Flutter Admin tests; full Flutter suite và các E2E nghiệp vụ có disposable runner riêng chưa chạy trong lượt này.
- DB test preview đang chạy để kiểm tra thủ công; không phải staging acceptance. Cần dừng API/web preview và xóa DB test sau khi hoàn tất review nếu không cần giữ lại.
- Backup age đã có đường truyền telemetry ký/bound với database và durable receipt; vẫn thiếu chứng cứ restore thành công nên operator phải chạy runbook backup/restore.
- Chưa verify staging migration rehearsal, real MFA, provider delivery/scanner, worker recovery, external readiness monitor, alert receiver, mobile/desktop chữ lớn và rollback owner.
- `ops:admin-preflight` chỉ phân loại `CONFIGURED_NOT_VERIFIED`; không thay thế staging/provider/device acceptance.
- Chưa mở custom permission, break-glass, retention deletion, production migration hoặc deployment.
- Support SLA, finance maker-checker/reconciliation, policy activation/appeal và tenant-facing auth/notification được giữ nguyên/tái sử dụng, không viết lại. Quality/report được mở rộng riêng bằng QA workflow.

## Đánh giá mức độ đầy đủ chức năng

- Admin cơ bản đã có dashboard/workspace, quản lý tài khoản và property, permission/preset, MFA/session, audit, support, moderation/appeal, finance reconciliation, search, team/flag và scheduled reports. Có source/test không đồng nghĩa đã nghiệm thu toàn bộ workflow trên hạ tầng thật.
- Milestone 1–3 đã bổ sung hardening và UI; vẫn còn release gates về staging, provider, restore, recovery và kiểm thử thủ công nêu trên.
- Platform search: global search đã có pagination theo nhóm, `total/hasMore`, LEASE/PAYMENT, deep link read-only và audit sensitive access; PII vẫn mask mặc định.
- Moderation quality: đã có date range/timezone, appeal reopen rate có định nghĩa, deterministic QA sampling và review độc lập có version/reason/audit. Enforcement expiry vẫn chưa tự thêm vì domain chưa xác nhận hỗ trợ.
- Governance: flag hiện có role/percentage, optimistic version và audit; chưa có expiry/scope mở rộng trong DTO hiện tại. Policy đã có DRAFT/ACTIVE/RETIRED; chưa thấy hai người duyệt/rollback trong activation service. Cần đối chiếu tiếp ownership transfer và retention dry-run trước khi triển khai, không tự xóa audit/evidence.
- Finance exception workbench và analytics tổng hợp vẫn cần kiểm tra theo từng acceptance criterion của chặng 5 và 9; không đánh dấu hoàn tất chỉ từ việc reconciliation/report cơ bản đã tồn tại. Không mở quyền sửa ledger/invoice/refund/deposit cho admin.

## Files dùng chung đã sửa

- Backend: `backend/src/admin/admin-console.controller.ts`, `backend/src/admin/admin-console.service.ts`, `backend/src/admin/admin.service.ts`, `backend/src/admin/admin-access-review.service.ts`, `backend/src/admin/admin.module.ts`, `backend/src/auth/admin-step-up.policy.ts`, `backend/src/health/operations-health.service.ts`, `backend/src/health/health.module.ts`, `backend/src/health/incident-workflow.service.ts`, `backend/src/platform/governance.service.ts`, `backend/src/uploads/uploads.service.ts`.
- Backend hardening: `backend/src/admin/admin-search.service.ts`, `backend/src/platform/moderation-quality.service.ts`, `backend/src/platform/moderation-quality.dto.ts`, `backend/src/platform/moderation-policy.service.ts`, `backend/src/health/backup-telemetry.service.ts`, `backend/scripts/admin-release-preflight.ts`, `backend/scripts/backup-telemetry.mjs`, `backend/scripts/database-safety.mjs`, `backend/prisma/schema.prisma`.
- Integration/config/test dùng chung: `backend/src/admin/admin-search.dto.ts`, `backend/src/platform/moderation-policy.controller.ts`, `backend/src/platform/platform.module.ts`, `backend/.env.example`, `backend/package.json`, `backend/test/e2e/e2e-fixtures.ts` (thêm thứ tự cleanup QA trước decision, đã thực chạy trong Admin E2E trên DB test cô lập), `test/features/admin/admin_workspace_flow_test.dart` (fixture search cấp đúng quyền account).
- Flutter: `lib/features/admin/admin_access_review_panel.dart`, `lib/features/admin/admin_production_panels.dart`, `lib/features/admin/admin_workflow_widgets.dart`, `lib/features/admin/admin_providers.dart`, `lib/features/admin/admin_landlord_form_screen.dart`.
- Flutter hardening: `lib/features/admin/admin_search_screen.dart`, `lib/features/admin/admin_search_results.dart`, `lib/features/admin/admin_moderation_quality_panel.dart`, `lib/features/admin/admin_policies_screen.dart`, `lib/features/admin/admin_console_providers.dart`, `lib/app/app.dart`.
- New shared surfaces: `backend/src/admin/admin-lifecycle.*`, `backend/src/admin/admin-route-inventory.ts`, `backend/src/health/operations-queue.*`, `lib/features/admin/admin_lifecycle_panel.dart`, `lib/features/admin/admin_delivery_jobs_panel.dart`.
- Documentation/runbook: `docs/admin-permission-matrix.md`, `docs/admin-release-gate-runbook.md`, this file.

## Migration, environment, dependency

- Migration mới: `backend/prisma/migrations/20261027180000_admin_moderation_quality/migration.sql`; đã apply trên DB test mới `rental_admin_test_20261027081353` cùng migration history. Chưa apply trên DB làm việc, staging hoặc production.
- Biến môi trường mới: `BACKUP_TELEMETRY_PATH`, `BACKUP_TELEMETRY_SECRET`, `BACKUP_MAX_AGE_HOURS`. Telemetry không hoạt động nếu thiếu durable off-site receipt.
- Dependency mới: không có.

## Khi tích hợp với nhánh nghiệp vụ

- Resolve các thay đổi cùng route/controller trước khi merge; đặc biệt `backend/src/admin/admin.module.ts`, `backend/src/auth/admin-step-up.policy.ts` và các admin Flutter panels.
- Chạy lại `npx tsx scripts/admin-route-inventory.ts` sau khi thêm/sửa controller admin, rồi cập nhật matrix nếu route/permission thay đổi.
- Chạy backend build + targeted release tests và Flutter admin tests trong cùng commit tích hợp; không dùng DB production.
- Xác nhận session version/current session behavior không bị thay đổi bởi auth/landlord/staff/tenant branch; signed attachment URL phải giữ session/ownership recheck.
- Kiểm tra permission catalog/preset bootstrap và migration state ở DB test cô lập trước staging rehearsal.
- Ghép model/relation `ModerationQualityReview` vào schema hiện có, giữ toàn bộ migration của nhánh nghiệp vụ; không đổi thứ tự/checksum migration đã apply. Chạy lại Prisma generate và rehearsal DB test mới trước khi bật quality endpoint mới.
- Khi ghép router dùng chung `lib/app/app.dart`, giữ các route landlord/staff/tenant có sẵn; search chỉ bổ sung đọc `kind/resourceId` query parameter. Không thêm mutation vào tenant/lease/invoice/payment lookup.
