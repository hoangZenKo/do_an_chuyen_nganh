# Admin operations release — 26/10/2026

Phạm vi là release admin đầu tiên trong `ADMIN_PRODUCT_ROADMAP_2026-10-26.md` (ADM-01 đến ADM-07), không phải toàn bộ Sprint A–J. Tái sử dụng support, notification delivery, moderation, audit và admin team đã có. Không mở quyền admin sửa ledger hoặc dữ liệu thuê của landlord.

## Trạng thái triển khai

| Ticket | Đã có code và automated coverage | Cần xác minh ngoài local |
| --- | --- | --- |
| ADM-01 | Route/capability metadata, permission revocation qua HTTP, access-review masking/version | Rà soát preset đang cấp trên staging |
| ADM-02 | Scoped step-up, MFA prompt/retry, hash token, expiry, session/action/payload binding và single-use consumption | MFA thật, browser/proxy headers và key của môi trường |
| ADM-03 | Incident assign, snooze, resolve/reopen, history/runbook, monitor recovery và row locking | Alert receiver và thao tác trên thiết bị thật |
| ADM-04 | Support case link và timeline lọc theo quyền/resource requester, audit read, no-store | Xác nhận phạm vi dữ liệu support với người vận hành |
| ADM-05 | Business calendar, holiday/timezone/DST, snapshot, pause/resume/reopen và form SLA | Phê duyệt lịch và SLA thực tế; mặc định chưa bật business-hours policy |
| ADM-06 | Multi-level escalation, deduplication, competing-worker E2E, notification outbox và heartbeat | Team/lead nhận thông báo thật, email/push delivery |
| ADM-07 | Backend/Flutter regression và runbook này | Staging migration rehearsal, backup/restore drill, device QA và provider smoke |

Không coi ADM-07 hoàn tất release gate chỉ vì automated tests pass.

## Bảo mật và compatibility

- Step-up bắt buộc trong production; ở local/staging không dùng `NODE_ENV=production`, bật bằng `ADMIN_STEP_UP_REQUIRED=true`.
- Grant có hiệu lực 5 phút, chỉ dùng một lần cho đúng session, action, method, path và payload. Database chỉ giữ SHA-256 của token. Không log token/MFA/recovery code.
- Danh mục hiện tại: PII reveal, account suspend, audit export, bulk moderation, access review và legacy `PATCH /admin/landlords/:id/status`. Legacy route cũng được bảo vệ để không trở thành đường vòng khóa tài khoản.
- Chuẩn hóa case/percent-encoding của URL tương ứng Express route matching, không để URL viết hoa bỏ qua step-up. Fingerprint vẫn phân biệt method/path/payload khác nhau.
- Admin invite/role change tiếp tục dùng workflow MFA đã có; không thay bằng quyền rộng hoặc bỏ kiểm tra MFA hiện hữu.
- Grant bị dùng ngay trước mutation; nếu request sau đó trả `409`/validation error hoặc timeout không rõ kết quả, tải lại dữ liệu trước khi xác thực và thử lại. Không tự replay một mutation chưa biết kết quả.
- Backend là nguồn quyết định quyền. Flutter chỉ bổ sung UX, giữ `expectedUserId` cho request và xóa/ẩn dữ liệu timeline khi session hoặc capability đổi.
- Access review không cho tự duyệt, dùng review version và audit snapshot. Đổi preset/status qua API hiện có làm mất hiệu lực review cũ.

## Migration và release gate

Hai migration mới theo thứ tự:

1. `20261026110000_admin_ops_stepup_sla`: step-up grants, access review, incident lifecycle, support case/SLA state.
2. `20261026120000_incident_snooze_constraint`: cho phép `SNOOZED` ở database CHECK constraint và backfill `conditionActive=false` cho incident đã resolved.

Không sửa checksum của migration đã áp dụng; migration thứ hai là bản forward-fix. `/api/v1/health/ready` yêu cầu migration thứ hai đã hoàn tất và không có migration đang dở.

Trong lần triển khai này chỉ migrate database cô lập `rental_chatbot_test_admin_ops_1792977054617`. Không migrate, seed hay reset working/production database.

Trước khi deploy môi trường có dữ liệu:

1. Tạo backup mới, xác minh checksum và restore drill theo `production-safety-2026-10-25.md`.
2. Chạy `ops:preflight`, xác minh đúng tên database và danh sách pending migrations.
3. Rehearse guarded migration trên staging, kiểm tra readiness và đăng nhập bằng ít nhất hai preset quyền.
4. Kiểm tra worker `support-sla` và `monitor`, notification outbox, lỗi scanner/provider và audit request ID.
5. Chỉ mở business-hours policy sau khi timezone, holidays, response/resolution targets và pause policy được người vận hành duyệt.

Rollback ứng dụng không đồng nghĩa drop bảng/column hoặc mất audit: giữ dữ liệu/migration bổ sung, dừng flow mới khi cần và điều tra. Chỉ restore database theo kế hoạch được phê duyệt; không dùng `migrate reset` trên dữ liệu thật. Tắt policy SLA không thay snapshot đã gắn vào ticket cũ.

## Cấu hình và vận hành

| Thiết lập | Hành vi |
| --- | --- |
| `ADMIN_MFA_REQUIRED=true` | MFA đăng nhập admin; production phải cấu hình theo runbook |
| `ADMIN_MFA_ENCRYPTION_KEY` | Base64 của 32 byte, giữ trong secret manager, không đổi khi chưa có re-enrollment plan |
| `ADMIN_STEP_UP_REQUIRED=true` | Bật step-up ngoài production; production luôn yêu cầu cho danh mục nhạy cảm |
| `SUPPORT_SLA_WORKER_ENABLED=true` | Worker mỗi 60 giây; không tự chạy ở `NODE_ENV=test` |
| SLA policy `enabled=false` | Ticket mới giữ legacy elapsed-hour SLA, không tự áp lịch business-hours chưa được duyệt |

Incident được xử lý bằng version: acknowledge/assign/snooze/resolve/reopen đều có reason và audit. Snooze tối đa 24 giờ ở API; UI cung cấp 4 giờ. Snooze không xóa điều kiện lỗi. Khi hết snooze, monitor mở lại trạng thái cần xử lý; khi điều kiện phục hồi, monitor tự resolve. Manual resolve bị chặn khi `conditionActive=true`. Monitor và admin mutation khóa cùng incident row để không ghi đè snooze/version bằng dữ liệu cũ.

SLA policy mới chỉ áp dụng cho ticket tạo sau khi lưu. Reassign không khởi động lại đồng hồ; waiting pause chỉ áp dụng cho resolution nếu snapshot cho phép. Reply/reopen tiếp tục ngân sách còn lại, không xóa hạn đã quá. Escalation dùng unique key theo ticket/kind/deadline/level và advisory lock để không tạo thông báo trùng khi nhiều worker chạy.

## Kiểm thử

Backend (chạy từ thư mục `backend`):

```bash
npm test -- --runInBand
npm run build
```

E2E chỉ chạy sau khi đặt `DATABASE_URL` của database test cô lập đã migrate và `NODE_ENV=test`:

```bash
npx jest --config ./test/jest-e2e.json --runInBand \
  admin-operations-release.e2e-spec.ts admin-console.e2e-spec.ts \
  admin-support-tools.e2e-spec.ts admin-search.e2e-spec.ts \
  admin-moderation-policy.e2e-spec.ts production-safety.e2e-spec.ts
```

Flutter (chạy từ root):

```bash
flutter test test/data/admin test/features/admin
flutter analyze
```

Đã xác minh backend build, 328 backend unit tests, 29 E2E của 6 suite trên và 50 Flutter admin API/widget tests. Backend có 7 test skipped theo cấu hình hiện hữu. `flutter analyze` còn 2 `prefer_const_constructors` và 2 `unused_element` ở dashboard cũ, không có diagnostic mới ở admin.

Các test bổ sung gồm MFA cancellation/session change, payload snapshot/retry, legacy landlord reason/version, self-review guard, business-calendar/DST, SLA snapshot/pause/resume, competing worker deduplication, incident concurrency và timeline permission revocation.

## Checklist còn lại trước production

- [ ] Staging migration rehearsal và backup/restore được người vận hành xác nhận.
- [ ] MFA thật, role revocation khi đang mở form, logout/login tài khoản khác.
- [ ] Mobile/desktop với chữ lớn: incident menu, access review, SLA form và case timeline.
- [ ] Team lead/operations nhận escalation thật; provider retry không gửi trùng.
- [ ] Incident alert receiver, worker recovery, stale heartbeat và readiness monitor bên ngoài.
- [ ] Chốt owner/on-call, SLA lịch thực tế và kế hoạch rollback.

Phần tiếp theo của roadmap là mở rộng Moderation v3, Platform search, Admin team lifecycle, Finance governance, Governance/rollout và Analytics; tài liệu này không xác nhận các phần mở rộng đó đã hoàn tất.
