# Admin Next Sprints — Identity, Search, Support Tools, Moderation Policy

Ngày cập nhật: 25/10/2026

Roadmap phát triển admin sau completion nằm tại [`ADMIN_PRODUCT_ROADMAP_2026-10-26.md`](ADMIN_PRODUCT_ROADMAP_2026-10-26.md), gồm Sprint A–J, backlog P0/P1/P2 và permission catalog đề xuất.

## Identity & API Safety

- `GET /api/v1/auth/sessions`: liệt kê phiên active, che địa chỉ mạng và không trả refresh token.
- `POST /api/v1/auth/sessions/:id/revoke`: thu hồi một phiên của chính user.
- `POST /api/v1/auth/sessions/revoke-all`: thu hồi các phiên khác, giữ phiên hiện tại.
- JWT kiểm tra `AuthSession` ở mỗi request; refresh-token rotation dùng cùng session.
- `ApiErrorFilter` chuẩn hóa `{ error: { code, message, details }, requestId }`; nội dung 5xx được redacted.
- Swagger: `/docs` và `/docs-json` ở development/test; production chỉ bật khi `SWAGGER_ENABLED=true`.

## Admin Search

- `GET /api/v1/admin/search?search=...`: kết quả nhóm theo account, property, room, support ticket, tenant và invoice theo permission.
- Kết quả account che email/phone; finance resource không có mutation endpoint.
- Flutter route: `/admin/search`.

## Support Tools

- `GET/POST/PATCH /api/v1/support/templates`: canned response có optimistic version và audit.
- `PATCH /api/v1/support/tickets/:id/labels`: nhãn ticket có optimistic version.
- `POST /api/v1/support/tickets/:id/merge`: chỉ gộp ticket cùng requester; chuyển message sang ticket đích.
- `POST /api/v1/support/tickets/:id/feedback`: requester chấm CSAT một lần sau khi resolve/close.
- Ticket list hỗ trợ tìm nội dung, label, assignee, team và priority.

## Moderation Policy

- `GET/POST /api/v1/admin/moderation-policies`: đọc và tạo policy version.
- `POST /api/v1/admin/moderation-policies/:id/activate`: chỉ có một policy active cho mỗi kind.
- Mỗi decision lưu evidence snapshot và policy ID nếu có policy active.
- `GET /api/v1/admin/moderation-policies/quality`: báo cáo quyết định, appeal và CSAT trong 30 ngày; không tự động phạt moderator.
- Flutter route: `/admin/moderation-policies`.

## Migrations

- `20261025200000_auth_sessions`
- `20261025210000_support_tools`
- `20261025220000_moderation_policies`

Các migration đã apply trên DB test cô lập `rental_chatbot_test_safety_20261025`. Chưa apply database làm việc/production.

## Admin completion - 26/10/2026

- Support attachments: giới hạn 8 MB, magic-byte/MIME validation, malware scanner webhook bắt buộc và signed access URL; tối đa 20 file/ticket.
- Support saved views, skill/capacity profiles và auto-assignment theo skill + workload.
- Notification delivery preferences, retry/backoff, dead-letter queue và operations endpoint.
- Finance statement import idempotent, auto-match chuyển khoản duy nhất, maker-checker proposals và audit log.
- Scheduled report timezone IANA, retry failed run, signed download link; production có thể bắt buộc object storage qua `REPORT_STORAGE_URL`/`REPORT_STORAGE_SECRET`.
- Migration mới: `20261026090000_admin_completion` (đã deploy trên DB test cô lập `rental_chatbot_test_admin_completion_20261026`, chưa deploy working/production DB).

### Final verification - 26/10/2026

- Finance workflow và notification queue theo dõi session/capability changes; ẩn dữ liệu phiên cũ khi đổi tài khoản hoặc đăng xuất.
- Thêm 8 widget regression tests cho đổi phiên, đăng xuất, thay đổi quyền và không fetch khi chưa đăng nhập.
- Backend build, 223 unit tests và 6 safety-script tests đều pass (7 unit tests skipped).
- 25 targeted admin/API/CSV tests và 8 session regression tests pass.
- Flutter analyze còn 4 cảnh báo/info có sẵn trong dashboard; full Flutter suite ở lượt kiểm tra trước còn 11 lỗi dashboard/navigation ngoài phạm vi admin.
- Chưa migrate working/production DB hoặc xác minh delivery, scanner, report storage và off-site backup trên hạ tầng thật.
