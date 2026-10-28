# Admin Release Gate Runbook

Ngày cập nhật: 28/10/2026 (Asia/Ho_Chi_Minh)

Runbook này dành cho staging/release review. Không dùng để tự động migrate hoặc deploy production.

## Registry migration / startup gate — 28/10

- Migration additive mới: `20261028090000_admin_registries` (verification, property approval, service plans, subscriptions/events). Đã backup, restore-check và rehearsal trên DB cô lập; đã guarded migrate vào local `rental_management` sau follow-up user approval. Staging/production chưa apply.
- `npm run start:dev` chạy `ops:readiness` trước khi start. Khi báo missing migration này, không tắt prestart/schema check, không dùng `db push`, `migrate reset` hoặc tự sửa `_prisma_migrations` để vượt gate.
- Sau khi operator phê duyệt đúng DB/environment: cấu hình encryption/off-site backup phù hợp, chạy `npm run ops:backup`, lấy manifest thực trả về; chạy `npm run ops:restore-check -- <manifest>` rồi `npm run ops:rehearse -- <manifest>`. Lưu output, xác minh restore và dữ liệu/row counts. Không dùng backup giả hoặc manifest của DB khác.
- Chỉ sau khi có backup dưới 24 giờ, rehearsal đạt và approval: đặt `MIGRATION_CONFIRM_DATABASE` chính xác tên DB đã duyệt rồi chạy `npm run ops:migrate -- <manifest>`. Không đưa encryption key/DB URL có mật khẩu vào log hoặc Git.
- Sau migrate: `npm run prisma:generate`, `npm run ops:readiness`, build và smoke Admin. Kiểm tra plan/version/quota/expiry, owner verification isolation, review snapshot conflict và audit. Không bật thu phí chỉ vì có catalog.
- Profile Admin đã lưu không được auto-escalate. Rà soát grants mới cho verification/plans bằng workflow quản trị quyền; verification còn cần `admin.support.read` để đọc evidence.
- Rollback app chỉ được dùng build tương thích additive schema; không drop registry tables hay xóa review/audit/event history. Dừng rollout khi readiness/permission/evidence fail và chuyển operator xử lý, không tự down-migrate dữ liệu.

## Preflight

Local execution evidence (28/10/2026): manifest `backend/.backups/rental_management-2026-10-27T23-03-42-312Z-dd092a5f.dump.enc.json`, owner-only và ignored trong Git. Readiness/auth/billing schema đều đạt, 53 migration đã apply; `start:dev` chạy và health live/ready trả 200. Backup comparison giữ nguyên dữ liệu nghiệp vụ; chỉ heartbeat timestamp trước migration thay đổi. Backup local chưa có off-site durability; không dùng bằng chứng này để nghiệm thu production.

1. Chọn DB test/staging cô lập; không đặt `DATABASE_URL` production trong shell kiểm thử.
2. Chạy `cd backend && npm run ops:preflight` để kiểm tra cấu hình backup/migration safety.
3. Chạy `cd backend && npm run ops:readiness`; `ready=true` phải bao gồm migration catalog, auth schema và billing schema.
4. Chạy `cd backend && npm run build`.
5. Sinh matrix bằng `cd backend && npx tsx scripts/admin-route-inventory.ts > ../docs/admin-permission-matrix.md`.
6. Chạy targeted release tests trước; chỉ sau đó chạy full suite phù hợp với DB test.
7. Chạy `cd backend && npm run ops:admin-preflight`; trạng thái `CONFIGURED_NOT_VERIFIED` chỉ xác nhận đã có cấu hình, không kiểm tra đầy đủ endpoint/key và không phải nghiệm thu provider. Exit code 1 = blocker, 2 = cấu hình đủ nhưng còn manual acceptance; script không truy cập DB hoặc provider.

## Authorization gate

- Anonymous: 401; staff/landlord/tenant: 403 trên admin lifecycle, operations, audit và search routes.
- Revoke capability khi đang mở màn hình: request kế tiếp phải 403; đổi session/user version phải 401.
- PII reveal/export/step-up: reason, permission, MFA/step-up, exact payload fingerprint và audit trong cùng transaction.
- Account, ticket, support attachment, lease/invoice/payment search: ownership/scope ở backend; UI ẩn menu không phải security control.
- Signed attachment URL: kiểm tra filename, expiry, user active, user version, session chưa revoke, role/capability và requester/resource ownership.
- Version conflict/duplicate submit: lần thứ hai phải 409 hoặc step-up single-use 403; không tạo audit giả thành công.

## Account lifecycle gate

- Invite admin: MFA fresh, `admin.admins.manage`, expiry one-time token, no secret in logs/response.
- Resend: chỉ trước activation, cooldown 60 giây, token cũ bị thay thế, không trả token/payload.
- Deactivate/profile change: giữ super admin recovery cuối cùng; chặn self-change; thu hồi auth session, refresh token và invite pending.
- Access review: reviewer khác target, preset/team/MFA/session status, overdue/unreviewed/inactive warning, review version conflict.
- Kiểm tra audit có actor, reason, request id và before/after cho role/team/status/session/review changes.

## Incident and job recovery

- Health: phân biệt database reachable với schema `READY`; `UNAVAILABLE` là gate fail, không phải pass.
- Worker: kiểm tra heartbeat, last success, stale/failed state và request/job identifier; không ghi token, secret hoặc raw payload vào incident.
- Incident: acknowledge/assign/snooze/resolve/reopen dùng version; resolve chỉ sau khi condition phục hồi và có reason/evidence.
- Dead letter: chỉ retry khi semantics idempotent đã được chứng minh bởi provider/job contract. Account-access dead letter đã bỏ payload: resend qua lifecycle workflow, không replay trực tiếp.
- Backup: chỉ công nhận age/durability từ telemetry được vận hành xác minh; API `UNKNOWN` phải được xử lý như thiếu bằng chứng.
- Backup telemetry: cấu hình `BACKUP_TELEMETRY_PATH`, `BACKUP_TELEMETRY_SECRET` và `BACKUP_MAX_AGE_HOURS`; file phải là envelope HMAC gắn với fingerprint database, checksum archive và durable off-site receipt. Không tự tạo envelope thủ công để vượt gate.
- Alert: xác nhận receiver, deduplication, escalation, worker recovery và external readiness monitor trong staging; không suy ra từ unit test.

## Manual acceptance

- Thực hiện trên desktop và mobile/chữ lớn: permission denied, stale session, conflict, empty/error/loading, incident filters, access review và lifecycle panel.
- Đổi tài khoản/logout trong lúc mở form; không để response cũ cập nhật UI mới.
- Verify provider delivery/scanner/report storage, off-site backup restore rehearsal và rollback owner bằng operator thật.
- Ghi lại timestamp, environment, commit SHA, DB migration state, test command/output và người chịu trách nhiệm.

## Signed backup telemetry

- Cấp secret HMAC riêng tối thiểu 32 byte cho backup worker và API; không tái sử dụng JWT/scanner/provider credential. `BACKUP_TELEMETRY_PATH` là đường dẫn tuyệt đối tới file JSON được chia sẻ qua mount tin cậy; API nên chỉ có quyền đọc, worker có quyền ghi nguyên tử. Parent directory phải tồn tại.
- Khi bật telemetry, `database-safety.mjs backup` chỉ publish sau khi kiểm tra checksum/authenticated encryption archive và nhận receipt durable có checksum/retention khớp từ off-site gateway. Flow cũ khi không cấu hình telemetry không bị thay đổi.
- `DATABASE_URL` ở worker/API phải chỉ cùng hostname/port/database; fingerprint không chứa username/password. Nếu hai bên dùng DNS alias khác nhau, giữ trạng thái UNKNOWN và thống nhất cấu hình thay vì bỏ binding.
- `BACKUP_MAX_AGE_HOURS` mặc định 24, cho phép 1–168. Chữ ký sai, DB khác, thời gian tương lai, retention hết hạn hoặc file lớn hơn 8 KiB trả UNKNOWN; archive quá ngưỡng tuổi trả STALE.
- `restoreVerified=false` luôn giữ nguyên ở projection này. Chỉ có checksum/authenticated archive và durable receipt không chứng minh restore được: operator vẫn cần rehearsal trên database test riêng và bằng chứng kiểm tra dữ liệu sau restore.

## Search và moderation QA

- Global search: `kind` tùy chọn, `page` 1–100, `limit` 1–50; metadata phân trang nằm trên từng group. LEASE yêu cầu `admin.support.read`, PAYMENT/INVOICE yêu cầu `admin.finance.read`; demo finance không được trả.
- Deep link read-only: `/admin/search?q=<id>&kind=LEASE|PAYMENT|INVOICE|ROOM|TENANT&resourceId=<id>`. Mở tài nguyên recheck backend permission; link không cấp quyền.
- Moderation quality: `from/to` là cặp ISO8601 có Z/offset rõ ràng, khoảng `[from,to)` tối đa 93 ngày, `timezone` IANA là ngữ cảnh trình bày (không tự diễn giải lại UTC instant).
- QA sample chỉ đọc evidence theo quyền loại nội dung, loại trừ quyết định của chính reviewer. Review yêu cầu reason/version và duy nhất một review mỗi decision; không dùng endpoint QA để đảo quyết định hoặc áp chế tài. Nếu cần sửa quyết định, dùng appeal workflow hiện có với reviewer độc lập.
- Migration `20261027180000_admin_moderation_quality` phải được rehearsal ở DB test cô lập trước release. Lượt triển khai này chỉ sinh source/client, không apply migration lên working/staging/production DB.

## Rollback

- Dừng release nếu readiness, authorization, audit hoặc backup evidence fail.
- Không reset DB, không xóa audit/evidence và không tự chỉnh migration production.
- Nếu đã có saved build, rollback theo quy trình deployment của môi trường; giữ nguyên audit incident và evidence để điều tra.
