# Cơ chế hỗ trợ, giới hạn và ứng viên chưa đủ bằng chứng

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Không phải Use Case độc lập

Không loại các chức năng này khỏi inventory. Chỉ phân loại lại vì là cơ chế thực thi, công cụ vận hành hoặc chưa có Actor/quyền ứng dụng đủ bằng chứng; không bịa một Actor Hệ thống để tạo UC. Mã TECH không nằm trong tổng 162 UC.

### TECH-01 — Khôi phục/làm mới phiên và nạp danh tính

Cơ chế duy trì đăng nhập, không phải mục tiêu người dùng mới.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:38` (AuthController.refresh); `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:51` (AuthController.me); `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:91` (AuthService.refresh); `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:153` (AuthService.me); `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:316` (AuthService.serializeUser).

Mục khảo sát: F-004.

### TECH-02 — Tính capability, guard và phạm vi dữ liệu

Quy tắc xuyên suốt; các đường STAFF bị chặn ghi thành gap, không thành UC thực thi được.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:17` (AdminConsoleController.capabilities); `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:1`.

Mục khảo sát: F-079, F-115.

### TECH-03 — Cấp token xác minh tăng cường

Tiến trình bảo vệ thao tác quản trị nhạy cảm, không là mục tiêu độc lập.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.controller.ts:23` (AdminStepUpController.issue); `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.service.ts:19` (AdminStepUpService.issue).

Mục khảo sát: F-143.

### TECH-04 — Kiểm tra sức khỏe và schema

Probe triển khai cho hạ tầng; không có Actor nghiệp vụ khởi tạo mục tiêu riêng.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:9` (HealthController.check); `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:22` (HealthController.live); `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:24` (HealthController.ready); `/Users/hoang/Rental_room_management/backend/src/health/schema-readiness.service.ts:38` (SchemaReadinessService.inspect).

Mục khảo sát: F-170.

### TECH-05 — Tải tệp và cấp URL truy cập

Bước chứng cứ/ảnh dùng lại trong các UC; quyền tệp kiểm độc lập; STAFF vẫn bị interceptor chặn.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.controller.ts:13` (UploadsController.upload); `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.controller.ts:20` (UploadsController.access); `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.service.ts:23` (UploadsService.save); `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.service.ts:95` (UploadsService.access).

Mục khảo sát: F-123.

### TECH-06 — Nhập/thu hồi nguồn tri thức bằng CLI

Công cụ bảo trì dữ liệu tri thức, chưa thấy Actor/quyền UI/API; giữ trong phạm vi kỹ thuật để không mất chức năng đã xác minh.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/chatbot/knowledge-import.cli.ts:1`; `/Users/hoang/Rental_room_management/backend/src/chatbot/knowledge.repository.ts:1`; `/Users/hoang/Rental_room_management/backend/scripts/import-knowledge.ts:1`.

Mục khảo sát: F-122.

### TECH-07 — Hướng dẫn lần đầu và thông tin phiên

Trợ giúp/đọc metadata người dùng; hồ sơ thuê đã ở UC-TEN-01, không suy thành UC tự sửa hồ sơ.

Bằng chứng: `/Users/hoang/Rental_room_management/lib/features/onboarding/onboarding_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/data/onboarding/onboarding_preferences.dart:1`; `/Users/hoang/Rental_room_management/lib/features/settings/settings_screen.dart:1`.

Mục khảo sát: F-175.

### TECH-08 — Sao lưu, phục hồi thử và bản sao ngoài hệ thống

Script vận hành có thật, không có phân quyền Actor ứng dụng; chưa chạy backup/restore thật trong đợt này.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/scripts/database-safety.mjs:1`; `/Users/hoang/Rental_room_management/backend/scripts/offsite-backup.mjs:1`; `/Users/hoang/Rental_room_management/backend/scripts/backup-worker.mjs:1`.

Mục khảo sát: F-177.

### TECH-09 — Điểm tương thích đối soát thanh toán demo

Service chỉ trả lại sự kiện đã đối soát; trường hợp mới bị từ chối, không có UC đối soát ngân hàng thật.

Bằng chứng: `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:26` (LandlordOnlinePaymentsController.reconcile); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:139` (OnlinePaymentsService.reconcile).

Mục khảo sát: F-068.

## 2. Chưa đủ bằng chứng — ngoài catalog chính

| Mã | Ứng viên | Lý do không xác nhận | Nguồn đã kiểm |
| --- | --- | --- | --- |
| GAP-01 | Thanh toán thẻ/ngân hàng tiền thật | Chỉ tìm thấy DEMO_CARD/isDemo và enum legacy; không có bằng chứng luồng cổng thật. Không đưa vào catalog chính. | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:1`<br>`/Users/hoang/Rental_room_management/backend/src/billing/demo-card.gateway.ts:1` |
| GAP-02 | Ký số hợp đồng có giá trị pháp lý | PDF và chấp nhận biên bản không chứng minh chữ ký số/nhà cung cấp ký số. Không đưa vào catalog chính. | `/Users/hoang/Rental_room_management/lib/features/tenants/lease_pdf.dart:1`<br>`/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:1` |
| GAP-03 | Người dùng tự cập nhật hồ sơ cá nhân | Chỉ thấy xem thông tin phiên/hồ sơ và quản lý hồ sơ Tenant bởi chủ trọ; không thấy bằng chứng đủ cho tự cập nhật. Không đưa vào catalog chính. | `/Users/hoang/Rental_room_management/lib/features/settings/settings_screen.dart:1`<br>`/Users/hoang/Rental_room_management/lib/data/auth/auth_api.dart:1`<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:1` |

## 3. Giới hạn đã xác nhận — không sửa ứng dụng

| Mã | Phạm vi | Kết luận AS-IS | Bằng chứng |
| --- | --- | --- | --- |
| LIM-01 | STAFF ngoài whitelist | Operations/P1Operations, announcements, notifications, audit, tenant invite, online demo, support, uploads, my moderation… bị chặn. Không cấp từ enum/menu. | `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| LIM-02 | STAFF ngoại lệ whitelist | Không tạo khu, escalate bảo trì, billing outbox/retry; reminder policy/run/enqueue bắt buộc propertyId được giao. | `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| LIM-03 | Phí/biểu phí | STAFF đọc; ghi phí, review tariff và lock kỳ chỉ LANDLORD. | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:1` |
| LIM-04 | TENANT/ngữ cảnh | TENANT chưa tự có Tenant/Lease; occupant không tự có User; không tự sửa hồ sơ/occupant. ADMIN không thừa hưởng nghiệp vụ chủ trọ. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:1` |
| LIM-05 | Hoàn tiền/quyết toán | Ghi nhận hoàn không chuyển tiền. Quyết toán không tự tất toán hóa đơn cũ hoặc sinh hóa đơn mới. | `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1` |
| LIM-06 | Zalo thật/mock | Tin test/thủ công/portal lưu nội bộ; ZNS adapter/config riêng, không dùng mock làm bằng chứng OA thật. | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/notifications/zalo-zns.service.ts:1` |
| LIM-07 | Scanner/model/giao nhận | Adapter/fail-closed/fallback có code, chưa xác nhận runtime ngoài; UC giữ Một phần. | `/Users/hoang/Rental_room_management/backend/src/uploads/malware-scanner.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/chatbot/ollama.client.ts:1`; `/Users/hoang/Rental_room_management/backend/src/delivery/delivery.service.ts:1` |
| LIM-08 | Migration/test/production | Source/test không chứng minh DB áp migration hay nghiệm thu production; release summary có productionAccepted:false. | `/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.ts:1` |

## 4. Endpoint kỹ thuật

| Handler | Route | Phân loại | Bằng chứng |
| --- | --- | --- | --- |
| LandlordOnlinePaymentsController.reconcile | POST /api/v1/billing/invoices/:id/payment-events/:eventId/reconcile | TECH-09 | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:26` |
| AdminConsoleController.capabilities | GET /api/v1/admin/me/capabilities | TECH-02 | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:17` |
| AdminStepUpController.issue | POST /api/v1/admin/me/security/step-up | TECH-03 | `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.controller.ts:23` |
| AuthController.refresh | POST /api/v1/auth/refresh | TECH-01 | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:38` |
| AuthController.me | GET /api/v1/auth/me | TECH-01 | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:51` |
| HealthController.check | GET /api/v1/health | TECH-04 | `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:9` |
| HealthController.live | GET /api/v1/health/live | TECH-04 | `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:22` |
| HealthController.ready | GET /api/v1/health/ready | TECH-04 | `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:24` |
| UploadsController.upload | POST /api/v1/uploads | TECH-05 | `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.controller.ts:13` |
| UploadsController.access | GET /api/v1/uploads/:filename/access | TECH-05 | `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.controller.ts:20` |

10 endpoint kỹ thuật được bảo toàn truy vết. TECH khác là CLI/lớp bảo vệ/helper không HTTP riêng. Không xóa/vô hiệu hóa endpoint nào.
