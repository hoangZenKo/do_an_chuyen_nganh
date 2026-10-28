# Production safety runbook

Runbook này áp dụng cho backend tại `/Users/hoang/Rental_room_management/backend` và Sprint 1 Production Safety. Không chạy E2E/reset trên database có dữ liệu thật.

## Mục tiêu và giới hạn

- Invite và password reset được xếp hàng vào durable outbox; API trả `queued: true`, không có nghĩa provider đã gửi thành công.
- Delivery worker dùng at-least-once delivery. Receiver phải deduplicate bằng `Idempotency-Key` chính là `DeliveryJob.id`.
- Payload delivery được mã hóa AES-256-GCM; token/email không nằm plaintext trong `DeliveryJob.payload`.
- Audit log chỉ đọc, có filter/detail/export có lý do; export tối đa 5.000 dòng trong khoảng rõ ràng không quá 31 ngày.
- Operations monitor tạo incident có deduplication, acknowledge theo version và auto-resolve. Đây không thay thế uptime monitor bên ngoài khi process hoặc database không phản hồi.
- `ops:preflight` chỉ kiểm tra migration history, checksum và migration chưa áp dụng. Đây không phải schema drift detector và không phải dry-run migration.

## Secrets và biến môi trường

Tạo key riêng cho từng môi trường, không commit vào `.env`, không dùng lại giữa backup, MFA và delivery:

```bash
openssl rand -base64 32 # ADMIN_MFA_ENCRYPTION_KEY
openssl rand -base64 32 # DELIVERY_ENCRYPTION_KEY
openssl rand -base64 32 # BACKUP_ENCRYPTION_KEY
```

Production/staging tối thiểu cần cấu hình:

| Biến | Yêu cầu |
| --- | --- |
| `DATABASE_URL` | PostgreSQL URL của đúng môi trường |
| `NODE_ENV` | `production` trên production |
| `JWT_ACCESS_SECRET` | Secret dài, quản lý bởi secret manager |
| `ADMIN_MFA_REQUIRED` | `true`; không copy giá trị local `false` |
| `ADMIN_MFA_ENCRYPTION_KEY` | Base64 của đúng 32 bytes |
| `ADMIN_STEP_UP_REQUIRED` | `true` để bật step-up cho hành động admin nhạy cảm ngoài production |
| `SUPPORT_SLA_WORKER_ENABLED` | `true` để chạy worker SLA; tắt có chủ đích ở test/local |
| `AUTH_PUBLIC_APP_URL` | HTTPS URL của app để tạo link activate/reset |
| `AUTH_DELIVERY_WEBHOOK_URL` | HTTPS endpoint nhận invite/reset |
| `AUTH_DELIVERY_WEBHOOK_SECRET` | Bearer secret của delivery receiver |
| `DELIVERY_ENCRYPTION_KEY` | Base64 của đúng 32 bytes |
| `OPERATIONS_ALERT_WEBHOOK_URL` | HTTPS endpoint nhận incident alert |
| `OPERATIONS_ALERT_WEBHOOK_SECRET` | Bearer secret của alert receiver |
| `BACKUP_ENCRYPTION_KEY` | Base64 của đúng 32 bytes, lưu tách archive |
| `BACKUP_DIR` | Thư mục private, có off-host replication |

Giữ các worker bật theo runbook của môi trường. Không đổi `ADMIN_MFA_ENCRYPTION_KEY` sau khi admin enroll nếu chưa có kế hoạch re-enrollment.

## Backup và restore drill

Backup không tự xóa và không tự đẩy off-host. Cần scheduler/supervisor bên ngoài để chạy worker và copy archive sang storage tách biệt. Archive được mã hóa trước khi ghi; manifest checksum phải đi cùng archive nhưng key phải lưu riêng.

```bash
cd /Users/hoang/Rental_room_management/backend
npm ci
npm run ops:backup
npm run ops:backup-worker
```

`ops:backup-worker` chạy ngay khi khởi động, sau đó theo `BACKUP_INTERVAL_HOURS` (mặc định 24 giờ, tính từ lần chạy xong); chạy dưới systemd/container supervisor. Đặt alert cho log `BACKUP_FAILED`, lỗi khởi động, backup quá hạn và process exit; worker vẫn chờ lịch kế tiếp sau một lần backup lỗi. Chính sách retention phải được phê duyệt và triển khai ở storage layer; code hiện tại không tự xóa backup. PostgreSQL client tools phải tương thích server; cấu hình `PG_BIN_DIR` nếu chúng không nằm trên PATH.

Restore drill chỉ được chạy trên database mới có `_test` hoặc `restore_check` trong tên, khác source database:

```bash
ALLOW_RESTORE_CHECK=true \
RESTORE_CHECK_DATABASE=rental_restore_check_YYYYMMDD \
npm run ops:restore-check -- /secure/backups/manifest.json
```

Script xác thực checksum và GCM authentication, giải mã hoàn toàn vào thư mục private trước khi `pg_restore`, kiểm tra `_prisma_migrations` và `User`, rồi chỉ drop database do chính drill tạo. Nếu drop fail, plaintext tạm vẫn phải được cleanup trong `finally`.

## Migration release gate

1. Deploy source và dependencies lên staging; kiểm tra `npm run build`.
2. Tạo backup mới và xác minh restore drill trên database staging/test.
3. Chạy preflight read-only:

   ```bash
   npm run ops:preflight
   ```

4. Chỉ chạy guarded migration khi manifest là backup của đúng database, tạo trong vòng 24 giờ:

   ```bash
   MIGRATION_CONFIRM_DATABASE=rental_management \
   npm run ops:migrate -- /secure/backups/manifest.json
   ```

   Lệnh có advisory lock riêng và Prisma migration lock. Nếu fail, dừng rollout và kiểm tra migration status; không tự chạy lại mù quáng.
5. Kiểm tra `GET /api/v1/health/ready`, Flutter `/admin/operations`, worker heartbeat, delivery queue và audit request ID.

## Delivery receiver checklist

- Chỉ nhận HTTPS, không redirect.
- Xác thực Bearer secret và validate schema.
- Dedupe theo `Idempotency-Key`; có thể nhận lại cùng job sau timeout.
- Trả 2xx sau khi đã nhận durable; 408/429/5xx sẽ retry với backoff, 4xx khác là dead-letter.
- Không log `actionUrl`, token, email nhạy cảm hoặc webhook secret.
- Test cả invite và reset; UI phải hiển thị trạng thái queued, không hiển thị “đã gửi” khi chưa có delivery confirmation.

## Monitoring và incident response

Monitor chạy mỗi 60 giây, với cửa sổ 15 phút:

- API: ít nhất 5 lỗi và error rate từ 5%.
- Login thất bại từ 20; MFA thất bại từ 10.
- PII reveal từ 20.
- Delivery pending quá 5 phút hoặc dead mới phát sinh trong 15 phút.
- Moderation quá hạn.
- Worker `FAILED`, `STALE` hoặc không heartbeat.

Khi incident mở: mở `/admin/operations`, kiểm tra database/receiver/worker/migration, acknowledge với lý do cụ thể, không xóa dead-letter để làm mất bằng chứng, rồi xác minh auto-resolve sau phục hồi. Cấu hình uptime monitor bên ngoài để phát hiện outage toàn phần.

## Staging security smoke

Smoke script cần token staging dành riêng cho admin, support và landlord:

```bash
STAGING_API_URL=https://staging.example.com \
STAGING_ADMIN_TOKEN=... \
STAGING_SUPPORT_TOKEN=... \
STAGING_LANDLORD_TOKEN=... \
npm run ops:smoke
```

Script kiểm tra health, auth boundary, audit request ID và cache headers. Trước production vẫn phải manual kiểm tra enroll/verify/recovery MFA, đổi quyền admin, invite/reset qua webhook thật, retry receiver, restore drill và UI mobile/desktop. Không ghi credential staging vào shell history hoặc repository.

## Verification Sprint 1

- Backend build pass; unit: 201 pass, 7 skip.
- Backend E2E: 17 suites, 134 tests pass trên database test riêng.
- Safety scripts: 4 pass, gồm cleanup plaintext khi dropdb thất bại và smoke-origin validation; backup/restore drill pass trên database test riêng.
- Flutter targeted admin/API/navigation: 23 pass.
- Smoke CLI: cả 9 checks pass khi chạy với local API/test database tách biệt. Đây không phải xác nhận staging thật.
- Flutter analyze còn 4 issues cũ trong `lib/features/dashboard/dashboard_screen.dart` (2 info, 2 warning); không có issue trong các file Production Safety.
- Chưa migrate database working/production và chưa chạy smoke trên staging thật vì chưa có credential staging.

## CSV audit hiện tại

Do `file_picker` bản đang dùng không hỗ trợ `saveFile(bytes)` trên macOS, Flutter hiện dùng nút **Sao chép CSV** để đưa CSV vào clipboard. Người vận hành cần dán vào file cục bộ trong thư mục được kiểm soát; đây không phải download tự động.
