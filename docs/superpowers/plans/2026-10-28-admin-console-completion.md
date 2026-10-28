# Admin Console Completion Implementation Plan

> For agentic workers: use an implementation workflow task-by-task. Do not overwrite the existing `tasks/plan.md` or `tasks/todo.md`; those files track work already in progress.

**Goal:** Hoàn thiện Admin Console từ trạng thái hiện tại thành một hệ thống quản trị có giao diện thống nhất, dữ liệu thật qua API, phân quyền/audit đầy đủ và đủ các phân hệ ưu tiên trong yêu cầu sản phẩm.

**Architecture:** Giữ NestJS + Prisma làm backend source of truth, Flutter làm admin client. Mỗi phân hệ triển khai theo vertical slice: contract/schema (nếu cần) -> API + authorization -> Flutter repository/provider -> màn hình -> focused tests -> acceptance check. Dùng `AdminOverviewShell` làm shell chuẩn; không tạo thêm một layout admin song song.

**Tech Stack:** NestJS, Prisma/PostgreSQL, Flutter, Riverpod, GoRouter, Jest, Flutter test/analyzer.

**Spec:** Yêu cầu chức năng Admin trong hội thoại; hiện trạng đối chiếu tại `docs/admin-functional-delivery-status.md`, `docs/admin-inventory-management.md`, `docs/admin-phase1-dashboard.md`.

## Execution Status — 28/10/2026

Implementation ledger: `tasks/admin-completion-progress.md`. Delivery matrix, exact verification and deviations: `docs/admin-functional-delivery-status.md` (section Phase 0–5). Baseline/gap sections below describe the starting point, not a claim that the new registry work is missing.

- Phases 0–4: implementation slices delivered; external paid settlement and legal verification policy remain explicitly partial, not invented from a UI/catalog.
- Phase 5: audit/security/operations code and local test gates delivered. Full runtime/staging/provider/restore/rollout acceptance is still open; Checkpoint F is not reached.
- Runtime evidence covers iPhone dashboard/accounts/properties/rooms/verification/review queue/plans against a real isolated API. A later explicit user request authorized the guarded migration on local `rental_management`; it passed backup/restore/rehearsal, readiness and startup. No staging/production deployment or migration was performed.
- Rulings: quotas are per landlord, legacy unassigned landlords are preserved, approval is independent of listing moderation, verification uses scanned Support evidence, and audit export keeps authenticated bounded CSV rather than adding a public signed link.
- Checklist items below remain acceptance gates: a test pass or implementation checkbox in the ledger does not automatically sign off all criteria.

## Global Constraints

- Không reset/drop/migrate database làm việc nếu chưa có backup, isolated rehearsal và approval rõ ràng.
- Backend luôn enforce role/capability; Flutter permission check chỉ là UX.
- PII mặc định masked; reveal cần capability riêng, reason, step-up và audit.
- Admin không sửa trực tiếp lease/invoice/payment ledger/tenant history nếu nghiệp vụ chưa định nghĩa rõ.
- Mọi mutation quan trọng phải có version check, transaction, audit before/after và idempotency khi có thể retry.
- Mỗi slice phải có loading, empty, error, retry, permission-loss và session-change behavior.
- Không coi unit/widget test là production acceptance; phải ghi rõ phần chưa verify device/staging/provider.

## Current Baseline

### Đã có chức năng nền

- Admin auth, capability matrix, MFA/step-up, session revocation, access review và audit log.
- Dashboard/overview analytics API và Flutter dashboard; báo cáo tổng quan có period selector, growth, occupancy và finance snapshot.
- Account list/detail, suspend/restore, revoke sessions, reset/reveal có guard và audit.
- Property/room inventory API, pagination/filter, detail, masked landlord contact và moderation deep link.
- Support Center, notifications queue, moderation v2/appeal/quality, governance, feature flags, report schedules, finance reconciliation, operations/incident center và global search.

### Chưa hoàn thiện hoặc còn thiếu

- UI `Khu trọ` và một số admin route vẫn dùng `AdminWorkspaceScaffold` cũ, không đồng bộ Dashboard mới.
- Dashboard còn hiển thị `SUBSCRIPTION_BILLING_NOT_IMPLEMENTED` cho doanh thu nền tảng; chưa có domain gói dịch vụ/subscription.
- Chưa có luồng xác minh chủ trọ độc lập: hồ sơ, tài liệu, hàng đợi duyệt, từ chối/yêu cầu bổ sung, lịch sử quyết định.
- Property hiện có archive nhưng chưa có workflow duyệt khu trọ/publish status cấp platform.
- Quản lý giao dịch hiện thiên về read-only reconciliation; chưa có màn hình transaction investigation và payment-error workflow hoàn chỉnh.
- Cấu hình đã có governance/feature flags/policy nhưng chưa có màn hình thống nhất cho service package, limits và system settings.
- Live browser/device, staging, provider delivery, restore/rollback và production release acceptance chưa hoàn tất.

## Dependency Graph

```text
Admin shell/design tokens
        |
        +--> dashboard/report contract
        +--> properties/rooms UI
        +--> account/landlord verification UI
        +--> support/moderation/notification UI consolidation

Prisma domain models + migrations
        |
        +--> API DTO/service/authorization
        +--> Flutter API models/providers
        +--> screens and workflows
        +--> E2E + release evidence
```

## Phase 0: Baseline, Contracts and Shell

### Task 0.1: Freeze current admin route inventory

**Files:**
- Read/verify: `lib/app/app.dart`, `lib/features/admin/admin_workspace_navigation.dart`
- Read/verify: `backend/src/admin/admin-route-inventory.ts`, `docs/admin-permission-matrix.md`
- Update: `docs/admin-functional-delivery-status.md`

**Acceptance criteria:**
- [x] Mỗi chức năng trong yêu cầu có một canonical route, capability và backend endpoint hoặc được đánh dấu `missing`.
- [ ] Không còn route trùng nghĩa giữa legacy workspace và new overview shell mà không có lý do.
- [x] Bảng gap được cập nhật với trạng thái `done`, `partial`, `missing`.

**Verification:** route catalog test, `flutter analyze` focused admin, backend route inventory test.

### Task 0.2: Chuẩn hóa Admin shell và design tokens

**Files:**
- Modify: `lib/features/admin/admin_workspace_scaffold.dart`
- Modify: `lib/features/admin/admin_overview_shell.dart`
- Modify: `lib/features/admin/admin_overview_theme.dart`
- Modify: `lib/features/admin/admin_workspace_navigation.dart`
- Modify: `lib/features/admin/admin_properties_screen.dart`, `admin_rooms_screen.dart`, `admin_landlords_screen.dart`, `admin_accounts_screen.dart`
- Test: `test/features/admin/admin_shell_navigation_test.dart` hoặc test tương đương hiện có

**Acceptance criteria:**
- [x] `/admin`, `/admin/accounts`, `/admin/landlords`, `/admin/properties`, `/admin/rooms`, reports và governance dùng cùng header/sidebar/breadcrumb/spacing/color tokens.
- [x] Click `Khu trọ` không còn mở giao diện cũ; title, active navigation, refresh và back behavior nhất quán.
- [ ] Desktop, tablet, mobile/320px và text scale 200% không overflow.
- [ ] Không đổi API contract trong slice này.

**Verification:** focused widget tests, analyzer, screenshot capture ở ít nhất desktop + 320px/200%, kiểm tra route runtime.

### Checkpoint A: Shell complete

- [ ] Không còn admin route ưu tiên nào dùng legacy scaffold ngoài danh sách được chấp thuận.
- [ ] API readiness `ready=true`.
- [x] Admin/Auth/API focused regression pass.

## Phase 1: Dashboard and Reports

### Task 1.1: Chốt contract và định nghĩa số liệu Dashboard

**Files:**
- Modify: `backend/src/admin/admin-overview-analytics.service.ts`
- Modify: `backend/src/admin/admin-overview-analytics.controller.ts`
- Modify: `backend/src/admin/admin-overview-analytics.http.spec.ts`
- Modify: `lib/features/admin/admin_overview_providers.dart` and typed admin overview models
- Update: `docs/admin-phase1-dashboard.md`

**Acceptance criteria:**
- [ ] KPI tổng tài khoản/khu trọ/phòng có source, period và timestamp rõ ràng.
- [ ] Growth dùng cùng timezone/date boundary; kỳ hiện tại và kỳ so sánh không mơ hồ.
- [x] Doanh thu nền tảng trả `null/UNKNOWN` có reason khi subscription billing chưa tồn tại, không hiển thị số giả.
- [x] API có permission riêng cho finance data và không leak finance khi thiếu quyền.

**Verification:** service/HTTP tests cho period, timezone, zero data, no-finance permission, DB unavailable.

### Task 1.2: Hoàn thiện Dashboard/report UI và trạng thái dữ liệu

**Files:**
- Modify: `lib/features/admin/admin_overview_page.dart`
- Modify: `lib/features/admin/admin_overview_chart.dart`
- Modify: `lib/features/admin/admin_workflow_widgets.dart`
- Test: `test/features/admin/admin_overview_page_test.dart`, API/provider tests

**Acceptance criteria:**
- [ ] KPI cards, trend chart, occupancy, account breakdown, action queue và finance card hiển thị dữ liệu API thật.
- [ ] Có skeleton/loading, empty state, error/retry và stale-data indication.
- [ ] Có export/report schedule entry point nhưng không giả vờ export thành công khi worker/storage chưa sẵn sàng.
- [ ] Mobile và desktop giữ hierarchy theo giao diện tham khảo.

**Verification:** focused Flutter tests, analyzer, runtime API check, screenshot comparison.

### Task 1.3: Báo cáo định kỳ và export an toàn

**Files:**
- Modify: `backend/src/platform/governance.service.ts`, report schedule/run services
- Modify: `lib/features/admin/admin_governance.dart`
- Test: backend report schedule/export tests and Flutter report tests

**Acceptance criteria:**
- [ ] Tạo/sửa/chạy schedule có timezone, frequency, recipient scope và audit.
- [ ] Export bounded theo date range/limit, signed download link, expiry và audit download.
- [ ] Retry chỉ được phép với report run idempotent và có reason.

**Verification:** backend HTTP/E2E with disposable DB, Flutter workflow tests.

### Checkpoint B: Dashboard/report complete

- [x] Dashboard không còn hard-code mock KPI.
- [ ] All report claims have a documented source/definition.
- [x] Focused admin suite and backend build pass.

## Phase 2: Properties, Rooms and Landlord Verification

### Task 2.1: Đồng bộ danh sách/chi tiết Khu trọ theo shell mới

**Files:**
- Modify: `lib/features/admin/admin_properties_screen.dart`
- Modify: `lib/features/admin/admin_property_detail_screen.dart`
- Modify: `lib/features/admin/admin_property_form_screen.dart`
- Modify: `lib/features/admin/admin_inventory_widgets.dart`
- Test: `test/features/admin/admin_inventory_panel_test.dart` and route tests

**Acceptance criteria:**
- [x] List supports search, archived/owner filters, pagination, retry and empty state in new visual system.
- [ ] Detail shows owner, rooms, status, rent summary, listing/moderation state and exact deep links.
- [x] Write actions are hidden/blocked unless `admin.properties.manage`.
- [x] No private contact leaks in list/detail without explicit reveal flow.

**Verification:** focused widget/API tests, analyzer, runtime manual flow.

### Task 2.2: Hoàn thiện quản lý phòng toàn hệ thống

**Files:**
- Modify: `backend/src/admin/admin.controller.ts` and inventory service/DTOs as needed
- Modify: `lib/features/admin/admin_rooms_screen.dart`
- Test: `backend/src/admin/admin-inventory.http.spec.ts`, Flutter room inventory tests

**Acceptance criteria:**
- [ ] Admin lọc được property, room status, listing status, price range and occupancy.
- [ ] Detail shows room state and violation/moderation context without allowing unsafe direct lease/payment mutation.
- [ ] Pagination and counts remain consistent under filters.

**Verification:** isolated DB E2E, Flutter API/widget tests.

### Task 2.3: Xây landlord verification workflow

**Files:**
- Create/modify: Prisma migration and verification models under `backend/prisma/schema.prisma`
- Create/modify: `backend/src/admin` verification controller/service/DTO/tests
- Modify: `lib/data/admin`, `lib/features/admin/admin_landlords_screen.dart`, `admin_landlord_detail_screen.dart`
- Update: `docs/admin-permission-matrix.md`

**Acceptance criteria:**
- [x] Hồ sơ có trạng thái `PENDING`, `NEEDS_INFO`, `APPROVED`, `REJECTED`, version và reviewer/audit.
- [x] Tài liệu có metadata/scan status; không trả raw secret/file storage credential.
- [x] Approve/reject/request-info yêu cầu reason, version conflict protection và step-up nếu policy yêu cầu.
- [ ] Landlord chỉ được xem trạng thái của mình; admin có queue/filter/detail/history.

**Verification:** migration rehearsal trên DB cô lập, backend HTTP/E2E, Flutter workflow tests, PII/access review.

### Task 2.4: Property approval/status workflow

**Files:**
- Modify: Prisma `Property` status/audit model or reuse approved moderation model only if semantics fit
- Modify: admin property controller/service and Flutter property panels
- Test: status transitions, permission and concurrency tests

**Acceptance criteria:**
- [x] Có phân biệt archived với approval/publishing status.
- [x] Duyệt/từ chối/yêu cầu bổ sung có reason, actor, timestamp, version và audit.
- [ ] Property rejected không xuất hiện như active approved inventory.

**Verification:** isolated DB E2E and UI state tests.

### Checkpoint C: Inventory and verification complete

- [x] Khu trọ không còn giao diện legacy.
- [ ] Property/room/landlord flows pass at desktop/mobile.
- [x] No destructive mutation on existing lease/payment history.

## Phase 3: Accounts, Support, Complaints and Notifications

### Task 3.1: Hoàn thiện account lifecycle UI

**Files:**
- Modify: `lib/features/admin/admin_accounts_screen.dart`, `admin_account_detail_panel.dart`, `admin_lifecycle_panel.dart`
- Backend only where gaps remain: account DTO/service/controller
- Test: existing account HTTP/E2E and Flutter lifecycle tests

**Acceptance criteria:**
- [ ] Search/filter/date/status/role, detail, suspend/restore, revoke sessions, reset and reveal work against typed API.
- [ ] Lock/unlock reason, version conflict, session invalidation and audit visible.
- [ ] Admin cannot suspend last/same protected admin through customer account route.

### Task 3.2: Support Center and complaint/dispute workflow

**Files:**
- Modify: `backend/src/support` and `backend/src/admin` only for missing triage/complaint links
- Modify: `lib/features/admin/admin_support_center.dart`, `admin_case_timeline_dialog.dart`, `admin_workflow_widgets.dart`
- Test: support E2E, SLA/assignment/version/widget tests

**Acceptance criteria:**
- [ ] Khiếu nại có queue, category, priority, owner, SLA, evidence, internal note và audit timeline.
- [ ] Dispute links tới account/property/listing/payment context theo permission, không sao chép ownership.
- [ ] Escalate/reassign/close yêu cầu reason; SLA không bị reset sai khi đổi owner.

### Task 3.3: Notification center

**Files:**
- Modify: `lib/features/admin/admin_notification_queue.dart`, support center tabs
- Backend notification/delivery projection where needed
- Test: notification queue filters, redaction, retry semantics

**Acceptance criteria:**
- [ ] Gửi broadcast/targeted group preview trước khi gửi.
- [ ] Hiển thị queued/sent/failed/dead-letter đúng semantics; không gọi queued là delivered.
- [ ] Không cho retry job nếu chưa chứng minh idempotency.

### Checkpoint D: User operations complete

- [ ] Account, complaint, notification flows có API + UI + audit.
- [ ] PII and capability tests pass.
- [ ] No raw delivery payload/token in admin responses.

## Phase 4: Transactions, Service Packages and System Configuration

### Task 4.1: Transaction and payment exception center

**Files:**
- Extend: `backend/src/platform/finance-reconciliation*`, billing projections and DTOs
- Modify: `lib/features/admin/admin_finance_workflow.dart`, `admin_governance.dart`
- Test: finance HTTP/E2E and Flutter reconciliation tests

**Acceptance criteria:**
- [ ] Search/filter transaction by reference, status, time, type and error category.
- [ ] Reconciliation shows source event, current state, candidate/proposal, reviewer and audit.
- [ ] Payment failure workflow supports investigation/resolution without direct ledger mutation.
- [ ] Platform revenue remains explicitly unavailable until subscription billing is implemented.

### Task 4.2: Service package/subscription domain

**Files:**
- Create: Prisma models/migration for `ServicePlan`, `PlanLimit`, `Subscription`, `SubscriptionEvent` (names may follow existing conventions)
- Create/modify: backend admin package controller/service/DTO/tests
- Create/modify: Flutter package management screen/provider/models/tests
- Update: `docs/admin-permission-matrix.md`, dashboard finance definitions

**Acceptance criteria:**
- [ ] Admin can create/update/activate/deactivate Free/Pro/Premium with versioned limits.
- [ ] Existing subscriptions keep historical plan/price/limit snapshot.
- [ ] Plan changes are audited and do not silently alter active billing.
- [ ] Dashboard can calculate platform revenue from settled subscription events, not rent collection.

**Verification:** isolated migration rehearsal, billing E2E, concurrency/idempotency tests, Flutter workflow tests.

### Task 4.3: Unified system configuration

**Files:**
- Modify: `backend/src/platform/governance*`, feature flags/policies DTOs
- Modify: `lib/features/admin/admin_governance.dart`, `admin_policies_screen.dart`, `admin_security_screen.dart`
- Test: authorization, version conflict, secret redaction, audit

**Acceptance criteria:**
- [ ] Configuration is grouped by platform, plan limits, moderation, notifications and operations.
- [ ] Secrets are never editable/readable as plaintext in this UI.
- [ ] Changes show impact, require reason where sensitive and are auditable.

### Checkpoint E: Finance/config complete

- [ ] Transaction and reconciliation screens are usable with real API data.
- [x] Plan model exists before claiming platform revenue.
- [ ] Configuration changes are guarded and audited.

## Phase 5: Audit, Security, Operations and Release

### Task 5.1: Activity log and security hardening

**Files:**
- Modify: `lib/features/admin/admin_audit_screen.dart`, `admin_sessions_screen.dart`, `admin_security_screen.dart`
- Backend audit query/export and security endpoints only where gaps remain
- Test: audit filter/detail/export, PII redaction, session revoke, retention boundaries

**Acceptance criteria:**
- [ ] Login, admin actions and data changes searchable by actor/action/resource/time/request ID.
- [ ] Export requires reason, bounded date range/limit and signed link.
- [x] Audit records are immutable from admin UI.

### Task 5.2: Operations command center and recovery evidence

**Files:**
- Modify: `lib/features/admin/admin_production_panels.dart`, `admin_workspace_action_queue.dart`
- Backend health/operations telemetry only where gaps remain
- Update: `docs/admin-release-gate-runbook.md`, `docs/production-safety-2026-10-25.md`

**Acceptance criteria:**
- [ ] Readiness, backup age/UNKNOWN, worker heartbeat, report/delivery queue and incident actions are visible.
- [x] Backup age is shown only with valid bound telemetry; otherwise `UNKNOWN`.
- [ ] Runbook deep links and evidence/reason fields are present for incident actions.

### Task 5.3: Full acceptance and release gate

**Files:**
- Update: `docs/admin-functional-delivery-status.md`, `PROJECT_STATUS.md`
- Add/update: focused release checks and QA checklist

**Acceptance criteria:**
- [x] Backend build/unit/admin E2E pass on disposable DB.
- [x] Flutter Admin/Auth/API tests pass; analyzer has no errors and 7 existing style infos are explicitly listed in delivery status.
- [ ] Real API + Flutter runtime check covers dashboard, accounts, properties, rooms, verification, finance, support, notifications, audit.
- [ ] Staging migration rehearsal, provider smoke, backup/restore drill, rollback owner and deployment approval are recorded.

### Checkpoint F: Admin ready for release

- [ ] All P0/P1 acceptance criteria complete.
- [ ] No `missing` item remains in the initial Admin requirement matrix unless explicitly accepted as out of scope.
- [ ] Production rollout has backup, migration, monitoring and rollback evidence.

## Recommended Execution Order

1. Phase 0.1 route/capability inventory.
2. Phase 0.2 shell consolidation, starting with `Khu trọ` because this is the visible defect now.
3. Phase 1 Dashboard/report.
4. Phase 2 inventory and landlord/property verification.
5. Phase 3 accounts/support/notifications.
6. Phase 4 transactions/packages/configuration.
7. Phase 5 audit/operations/release.

Do not start service packages before the shell and dashboard contracts are stable. Do not claim platform revenue before subscription events and settled-state semantics exist.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Legacy and new shells drift | High | One canonical `AdminOverviewShell`; migrate route-by-route with widget tests. |
| Platform revenue is confused with landlord rent | High | Separate subscription ledger/event model and explicit finance definitions. |
| Verification documents expose PII | High | Mask-by-default projections, signed URLs, scanner status, step-up and audit. |
| Admin mutations bypass domain invariants | High | Capability guard, version check, transaction, domain service; no direct ledger writes. |
| Migration breaks local data | High | Encrypted backup, isolated rehearsal, guarded migration and row/schema verification. |
| Scope expands indefinitely | Medium | Ship phases in order; mark P2 items after Phase 5 instead of mixing them into P0/P1. |
| UI passes widgets but fails runtime | Medium | Require live API/device/browser check at each checkpoint. |

## Open Decisions to Confirm Before Implementation

- [ ] Luồng xác minh chủ trọ sẽ xác minh cá nhân, giấy tờ kinh doanh, hay cả hai?
- [ ] Gói Free/Pro/Premium tính theo chủ trọ, khu trọ hay số phòng?
- [ ] Doanh thu nền tảng lấy từ subscription settled events nào và có hoàn tiền/thuế không?
- [ ] Admin có quyền duyệt khu trọ độc lập với duyệt listing không?
- [ ] Khiếu nại có cần người dùng gửi trực tiếp từ app trong Phase 3 hay chỉ cần admin queue trước?

## Definition of Done

- Giao diện Admin thống nhất, không còn legacy screen ở các route P0/P1.
- Mỗi mục trong yêu cầu Admin có route, capability, API, UI, audit và test hoặc có quyết định out-of-scope được ghi nhận.
- Dashboard/report dùng dữ liệu thật với định nghĩa KPI rõ ràng.
- Property/room/account/verification/support/notification/transaction/package/config/audit flows đã được nghiệm thu theo checklist.
- Database migration, backup/restore, staging/runtime smoke và rollback evidence hoàn tất trước khi gọi là release-ready.
