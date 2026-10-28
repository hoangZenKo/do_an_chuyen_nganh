# Admin Sprints 2–4 Runbook

Ngày cập nhật: 25/10/2026

## Sprint 2 — Support Center

- `POST /api/v1/support/tickets`: người dùng tạo ticket; priority do user không-admin gửi lên luôn bị chuẩn hóa về `NORMAL`.
- `GET /api/v1/support/tickets`: requester chỉ thấy ticket của mình; admin có `admin.support.read` thấy toàn bộ.
- `GET /api/v1/support/tickets/:id`: internal note chỉ trả cho admin hỗ trợ.
- `POST /api/v1/support/tickets/:id/replies`: requester và admin xử lý có thể phản hồi; ticket `RESOLVED` chỉ reopen trong 7 ngày.
- `POST /api/v1/support/tickets/:id/notes`: admin hỗ trợ thêm ghi chú nội bộ.
- `PATCH /api/v1/support/tickets/:id/assignment`: yêu cầu `admin.support.manage`, kiểm tra assignee/team, priority và optimistic `version`.
- `PATCH /api/v1/support/tickets/:id/status`: chuyển trạng thái có lý do và optimistic `version`.
- `GET /api/v1/support/notifications` và `GET /api/v1/notification-center`: notification center theo user; đánh dấu từng mục hoặc tất cả đã đọc.

SLA được tính theo priority: `URGENT` 1h/12h, `HIGH` 4h/24h, `NORMAL` 24h/72h, `LOW` 48h/120h (first response/resolution). Các thao tác nhạy cảm ghi audit log.

## Sprint 3 — Moderation v2

- Appeal chỉ được tạo từ `ModerationDecision` bất lợi trong 14 ngày và chỉ owner của nội dung mới tạo được.
- Reviewer độc lập không được là người ra quyết định gốc; `REOPENED` kiểm tra version hiện tại trước khi đưa nội dung về `PENDING`/`OPEN`.
- `POST /api/v1/admin/moderation-v2/bulk` giới hạn 25 item, chống trùng item và trả kết quả thành công/thất bại riêng từng item.
- `GET /api/v1/admin/moderation-v2/decisions`, `/history/:kind/:id`, `/appeals`, `/reports` cung cấp decision history, appeal queue và báo cáo theo 30 ngày.
- Operations monitor đánh dấu work item quá hạn đúng một lần, tạo `SlaEscalation` và notification cho assignee.

## Sprint 4 — Governance

- Feature flags: `support.user_tickets`, `moderation.appeals`, `moderation.bulk`, `reports.scheduled`; cập nhật có optimistic `version`, rollout theo hash user và audit.
- Admin teams: tạo/sửa/activate, thêm/xóa thành viên; không xóa thành viên khi còn ticket đang xử lý của họ.
- Permission simulator chỉ mô phỏng preset/route/action, không cấp quyền thật; MFA và resource scope vẫn được enforce ở API.
- Finance reconciliation là read-only, giới hạn 366 ngày và 5.000 dòng mỗi nguồn; trả snapshot, giao dịch, mismatch và totals.
- Scheduled reports tạo queue run idempotent theo `scheduleId + scheduledFor`; worker tạo snapshot, mã hóa payload, chạy tối đa retry và artifact hết hạn sau 7 ngày.

## Capability matrix

| Capability | Preset mặc định |
|---|---|
| `admin.support.manage` | support, super_admin |
| `admin.notifications.view` | support, moderator, analyst, super_admin |
| `admin.moderation.appeals` / `bulk` / `reports` | moderator, analyst(reports), super_admin |
| `admin.flags.manage` / `teams.manage` / `permissions.simulate` | super_admin |
| `admin.finance.read` / `reports.manage` | analyst, super_admin |

## Kiểm thử đã chạy

- `npm run build`: pass.
- `npm test -- --runInBand`: 24 suites pass, 213 tests pass, 7 skipped.
- Isolated test DB `rental_chatbot_test_safety_20261025`: migration deploy và status up-to-date.
- Full backend E2E: 18 suites, 148 tests pass, gồm 14 tests Sprint 2–4.
- `npm run test:safety-scripts`: 4 tests pass.
- Flutter targeted admin/auth tests: 32 tests pass.
- `flutter analyze --no-pub`: không có error; còn 2 warning unused element và 2 info prefer const trong dashboard ngoài phạm vi Sprint 2–4.

## Vận hành an toàn

- Không migrate database làm việc/production bằng migration này nếu chưa backup và duyệt release.
- Bật worker bằng `ADMIN_REPORT_WORKER_ENABLED=true` sau khi cấu hình `DELIVERY_ENCRYPTION_KEY` 32-byte base64.
- Report worker không gửi email/webhook; người có quyền tải CSV từ admin UI.
- Trước production cần staging smoke: tạo ticket, appeal/reopen version conflict, bulk conflict, worker escalation, flag rollback và report download.
