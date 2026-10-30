# Admin account setup

Frontend không truy cập trực tiếp database; backend NestJS hiện nằm ở `backend/` trong cùng repository. Public registration luôn tạo tài khoản `landlord`; admin phải được tạo bằng CLI bootstrap. Sau khi đăng nhập, admin dùng nhóm endpoint `/api/v1/admin/...` hiện có để quản lý landlords/properties ở phạm vi platform. Khi tạo property từ màn admin, Flutter hiện chọn landlord active bằng search/selector thay vì nhập raw UUID.

## Admin MVP - 3 giai đoạn (24/10/2026)

### 1. Phân quyền và bảo mật

- Preset `super_admin`, `support`, `moderator`, `analyst`; API kiểm tra capability ở backend, không chỉ ẩn menu Flutter.
- Admin workspace responsive tại `/admin`, sidebar trên màn hình lớn và drawer trên màn hình nhỏ.
- `/admin/security`: tạo TOTP, quét QR, xác nhận mã và lưu recovery codes một lần. Bật MFA sẽ thu hồi phiên cũ; đăng nhập lại bằng mật khẩu + mã TOTP/recovery.
- `/admin/admins`: xem admin và thay đổi profile/quyền theo capability; thay đổi quyền yêu cầu phiên đã xác thực MFA.
- `/admin/audit-logs`: đọc nhật ký thao tác; không có API sửa/xóa audit.

### 2. Tài khoản và hỗ trợ

- `/admin/accounts`: tìm kiếm, lọc role/trạng thái, phân trang và xem chi tiết.
- Khóa/mở khóa cần lý do và version chống ghi đè; revoke sessions, gửi reset mật khẩu và PII reveal được kiểm soát capability và ghi audit.
- Khóa landlord chặn truy cập staff liên quan nhưng không xóa hợp đồng/hóa đơn hay khóa tài khoản tenant.
- `/admin/support`: xem context hỗ trợ chỉ đọc; không đăng nhập giả người dùng hoặc sửa dữ liệu tài chính.
- Invite/reset dùng token một lần, lưu hash, hết hạn sau 30 phút; người nhận tự đặt mật khẩu ở `/account/activate`.

### 3. Moderation và dashboard

- `/admin/moderation`: queue listing/report/review/reply, lọc assignment/priority/quá hạn, xem chi tiết, giao việc, đặt hạn xử lý và ghi chú nội bộ.
- Kiểm tra version và khóa transaction khi assignment; chỉ người được giao hoặc super admin được quyết định trên nội dung đã phân công.
- Dashboard có analytics tổng hợp, xu hướng tài khoản/tin đăng và số lượng hàng đợi theo quyền.
- Admin không có quyền sửa/xóa trực tiếp invoice, payment, payment proof, lease, deposit hoặc audit log.

### Cấu hình và rollout an toàn

Runbook backup/restore, guarded migration, delivery retry, incident monitor và staging smoke: `docs/production-safety-2026-10-25.md`.

Migration admin foundation: `20261024150000_admin_console_foundation`; Production Safety: `20261025160000_production_safety`. Đã kiểm tra trên database test riêng; chưa áp dụng vào database làm việc/production.
Trước rollout cần backup, kiểm tra migration status và thử trên staging. Không chạy E2E vào database có dữ liệu thật vì test reset dữ liệu.

Thiết lập các biến trong môi trường backend:

| Biến | Yêu cầu |
|---|---|
| `ADMIN_MFA_REQUIRED` | Đặt `true` trên staging/production; mặc định code là `true` khi `NODE_ENV=production` |
| `ADMIN_MFA_ENCRYPTION_KEY` | Base64 của 32 byte ngẫu nhiên; sinh bằng `openssl rand -base64 32`, lưu trong secret manager và không commit |
| `AUTH_PUBLIC_APP_URL` | URL HTTPS của Flutter app để mở `/account/activate` |
| `AUTH_DELIVERY_WEBHOOK_URL` | HTTPS endpoint của dịch vụ gửi email/lời mời; không có thì invite/reset không gửi được |
| `AUTH_DELIVERY_WEBHOOK_SECRET` | Bearer secret xác thực dịch vụ nhận webhook; phải cấu hình và kiểm tra ở phía nhận |
| `DELIVERY_ENCRYPTION_KEY` | Base64 của 32 byte ngẫu nhiên, dùng key riêng để mã hóa payload outbox |
| `OPERATIONS_ALERT_WEBHOOK_URL` / `OPERATIONS_ALERT_WEBHOOK_SECRET` | HTTPS receiver và Bearer secret nhận incident alerts |

Webhook nhận JSON gồm `email`, `purpose`, `actionUrl`, `expiresAt`; trả HTTP 2xx khi đã nhận durable. API `queued: true` không đồng nghĩa đã gửi email; receiver phải dedupe theo `Idempotency-Key`. Worker retry network/408/429/5xx tối đa 6 lần; lỗi terminal vô hiệu hóa token và xóa payload. `actionUrl` chứa token trong URL fragment: không ghi log, không trả token cho admin, không dùng analytics theo dõi link chứa token.

`/admin/operations` xem health, workers, delivery counts và incident; acknowledge cần `admin.operations.manage`, lý do và version. `/admin/audit-logs` hỗ trợ bộ lọc, chi tiết đã che dữ liệu nhạy cảm và sao chép CSV; export cần `admin.audit.export`.

Không đổi/xóa MFA encryption key khi đã có admin enroll nếu chưa có kế hoạch re-enrollment; mất key khiến không giải mã được TOTP secret.
Admin cũ chưa có profile cần được provision qua bootstrap trước khi truy cập. Tài khoản chưa enroll khi MFA bắt buộc chỉ được vào luồng security để thiết lập; không tắt MFA production để bỏ qua bước này.

### Kết quả kiểm tra local

- Backend build pass; unit tests: 201 pass, 7 skip.
- Full backend E2E: 17 suites, 134 tests pass trên database test riêng; có kiểm tra quyền/MFA, account flow, moderation và Production Safety.
- Flutter targeted tests: 23 pass cho auth navigation, admin API và Production Safety UI.
- Flutter full suite chưa xanh: lượt trước còn lỗi dashboard/layout ngoài phạm vi admin; không coi đây là xác nhận full regression pass.
- Cần manual smoke test UI trên trình duyệt/mobile, kiểm tra gửi email qua webhook thật và xác minh secrets/migration trên staging trước production.

= Email: admin@rental.local
= Mật khẩu: Admin-a9161ba7cc0e5b180cd48b2ded1380b3555f
= Quyền: super_admin

## Local demo landlord account

Nếu đã chạy seed demo trong backend, có thể đăng nhập tài khoản landlord demo:

- Email: landlord@demo.com
- Password: DemoLandlord!2026
- Role: `landlord`

Đây chỉ là tài khoản demo local để test flow landlord/dashboard; không dùng cho production và không phải tài khoản admin.

## Local demo tenant account

Tenant account không tự sinh từ public registration. Chủ trọ tạo hồ sơ người thuê trước, sau đó tạo mã mời từ màn chi tiết người thuê. Tenant mở link/mã kích hoạt và tự đặt mật khẩu.

Credential demo nên dùng để dễ test local:

- Email: tenant@demo.com
- Password: DemoTenant!2026
- Role: `tenant`

Cách tạo bằng Flutter:

```text
1. Đăng nhập landlord: landlord@demo.com / DemoLandlord!2026
2. Vào Người thuê
3. Chọn hoặc tạo một người thuê
4. Nếu người thuê chưa có hợp đồng, tạo hợp đồng thuê phòng
5. Trong Chi tiết người thuê, bấm Tạo mã mời tenant
6. Nhập tenant@demo.com
7. Copy link/mã kích hoạt app trả về
8. Đăng xuất landlord, mở /tenant/activate?code=<invite-code>
9. Đặt mật khẩu DemoTenant!2026
10. Sau khi kích hoạt, tenant được đưa về /tenant
```

Cách tạo bằng API nếu muốn test nhanh:

```bash
# 1) Login landlord để lấy access token
curl -s http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"landlord@demo.com","password":"DemoLandlord!2026"}'

# 2) Dùng accessToken gọi endpoint tạo mã mời cho tenant đã có sẵn
curl http://localhost:3000/api/v1/tenants/<tenant-id>/invite \
  -H "Authorization: Bearer <landlord-access-token>" \
  -H "Content-Type: application/json" \
  -d '{"email":"tenant@demo.com"}'

# 3) Tenant accept invite và tự đặt mật khẩu
curl http://localhost:3000/api/v1/tenant-invites/accept \
  -H "Content-Type: application/json" \
  -d '{"inviteCode":"<invite-code>","password":"DemoTenant!2026"}'
```

Sau khi đăng nhập tenant, Flutter route tới `/tenant`. Tenant chỉ xem dữ liệu gắn với hồ sơ tenant của chính tài khoản đó: phòng/hợp đồng hiện tại, hóa đơn, công nợ, thông báo và yêu cầu sửa chữa. Tenant có thể đổi mật khẩu ở nút ổ khóa trên Tenant Portal.

Tenant portal hiện có thêm các flow vận hành:

- Tenant báo sửa chữa và upload ảnh/chứng từ thật qua `POST /api/v1/uploads`.
- Tenant xem thông báo chưa đọc và đánh dấu đã đọc.
- Tenant/landlord phản hồi qua comment trong ticket sửa chữa.
- Tenant gửi chứng từ thanh toán từ chi tiết hóa đơn; landlord duyệt ở chi tiết hóa đơn để ghi nhận payment.
- Landlord xuất PDF hợp đồng từ lịch sử hợp đồng trong chi tiết người thuê.

## Local staff account

Staff account không tự đăng ký public. Chủ trọ tạo mã mời staff, staff mở link/mã kích hoạt và tự đặt mật khẩu. Staff luôn thuộc một landlord và chỉ thao tác trong phạm vi dữ liệu của landlord đó.

Cách tạo bằng Flutter:

```text
1. Đăng nhập landlord: landlord@demo.com / DemoLandlord!2026
2. Vào Dashboard
3. Bấm icon Nhân viên
4. Bấm Mời nhân viên
5. Nhập họ tên, email, số điện thoại
6. Chọn nhóm quyền: Chỉ xem / Kế toán / Bảo trì / Quản lý vận hành
7. Copy mã hoặc link kích hoạt app trả về
8. Đăng xuất landlord, mở /staff/activate?code=<invite-code>
9. Đặt mật khẩu mạnh tối thiểu 12 ký tự
10. Sau khi kích hoạt, staff được route theo quyền được cấp
```

Các preset quyền MVP:

| Preset | Mục đích |
|---|---|
| `viewer` | Xem phòng, tenant, hợp đồng, hóa đơn, chi phí, bảo trì, báo cáo, thông báo |
| `accountant` | Xem/tạo hóa đơn, ghi nhận thanh toán, duyệt proof, quản lý chi phí, xem báo cáo/xuất CSV |
| `maintenance` | Xem phòng/tenant, quản lý bảo trì, xem thông báo/việc cần xử lý |
| `operator` | Quản lý vận hành phòng, tenant, hợp đồng, bảo trì, thông báo/việc cần xử lý |

Preset `operator`, `accountant`, `viewer` có thêm quyền `audit.view` để xem lịch sử hoạt động. Preset `maintenance` không có quyền này theo mặc định.

Các thao tác nhạy cảm được tách quyền riêng ở backend: `billing.cancel`, `billing.reverse_payment`, `billing.approve_payment_proof`, `staff.manage`. Landlord luôn có toàn quyền trong dữ liệu của mình.

## Màn Cài đặt trong Flutter

Sau khi đăng nhập landlord/staff, vào Dashboard và bấm icon bánh răng ở góc trên để mở `/settings`.

Màn Cài đặt hiện gom các mục vận hành hay dùng:

- Tài khoản: xem thông tin đăng nhập, đổi mật khẩu, đăng xuất.
- Quản lý: nhà trọ, nhân viên/phân quyền, audit log theo quyền hiện có.
- Thông báo: notification center và trạng thái Zalo/ZNS.
- Thanh toán & hóa đơn: hóa đơn PDF, tự động lập hóa đơn, báo cáo/nhắc nợ.
- Ứng dụng: Ngôn ngữ `Tiếng Việt`, giao diện `Sáng`, font `Manrope`, API `Local/Production`.
- Công cụ thử nghiệm: `/settings/fake-zalo` là Zalo Simulator để xem inbox/chat mock từ notification delivery logs.

Cách test Zalo Simulator local:

```text
1. Đăng nhập landlord.
2. Vào Dashboard > icon bánh răng > Zalo/ZNS.
3. Nếu chưa có tin, bấm Tạo tin test.
4. Xem danh sách tin đã tạo, lọc trạng thái và bấm từng tin để mở giao diện chat giả lập.
5. Trong chat giả lập, có thể gõ tin nhắn thủ công rồi bấm gửi.
6. Đăng nhập tenant tương ứng, vào Tenant Portal để thấy card Zalo từ chủ trọ.
7. Bấm card Zalo để mở `/tenant/zalo`; bấm từng tin sẽ đánh dấu đã đọc.
```

Nút `Tạo tin test` và tin nhắn thủ công chỉ tạo notification delivery mock, không tạo hóa đơn thật và không sửa tiền thật. Backend sẽ tự chọn tenant active đã kích hoạt tài khoản trong phạm vi landlord cho tin test. Nếu chưa có tenant account, hãy tạo tenant, tạo mã mời tenant và kích hoạt tài khoản tenant trước.

Khi chưa cấu hình Zalo/ZNS thật, backend vẫn tạo delivery record rồi đánh dấu `Mock / bỏ qua` nếu thiếu template/token; điều này là bình thường để kiểm tra nội dung tin trước.

Tenant dùng chính số điện thoại trong hồ sơ tenant làm Zalo fake contact. Sau khi tenant account kích hoạt thành công, Tenant Portal sẽ hiển thị `Zalo: <số điện thoại>` trong thẻ hồ sơ nếu tenant có phone.

Admin hoặc tenant nếu mở trực tiếp `/settings` vẫn vào được phần cài đặt tài khoản/cấu hình app; các nhóm quản lý sẽ tự thay đổi theo role.

## Audit log landlord/staff

Sau khi đăng nhập landlord, vào Dashboard và bấm icon Lịch sử để mở `/audit`. Màn này hiển thị actor, action, loại tài nguyên, mô tả và thời gian của các thao tác nhạy cảm như tạo/sửa/xóa khu trọ/phòng/tenant, hợp đồng, hóa đơn/thanh toán, chi phí, bảo trì và staff.

Backend endpoint:

```text
GET /api/v1/audit-logs?take=80
```

Staff chỉ xem được nếu có permission `audit.view`; landlord luôn xem được lịch sử trong phạm vi dữ liệu của mình.

## Chức năng landlord 2-7 đã triển khai

Sau audit log, app đã có thêm các phần vận hành sau:

1. Notification center:
   - Flutter: Dashboard > icon Thông báo hoặc route `/notifications`.
   - Backend: `GET /api/v1/notifications`, `POST /api/v1/notifications/:id/read`.
   - Nguồn thông báo gồm hóa đơn quá hạn/sắp hạn, proof chờ duyệt, bảo trì khẩn cấp, hợp đồng sắp hết hạn và lịch kiểm tra phòng.

2. Action items:
   - Flutter: Dashboard > icon Việc cần xử lý hoặc route `/actions`.
   - Backend: `GET /api/v1/operations/action-items`.
   - Hiển thị count nhanh cho quá hạn, proof chờ duyệt, hợp đồng sắp hết hạn và lịch kiểm tra phòng.

3. Export báo cáo CSV:
   - Flutter: Dashboard > Báo cáo > icon Xuất CSV.
   - Backend: `GET /api/v1/reports/monthly/export?month=<ISO-date>&propertyId=<property-id>`.
   - MVP hiện copy nội dung CSV vào clipboard để test nhanh.

4. Hợp đồng sắp hết hạn:
   - Flutter: Dashboard > icon Hợp đồng sắp hết hạn hoặc route `/lease-expiry`.
   - Backend: `GET /api/v1/leases/expiring?days=30`.

5. Tài sản/phụ kiện phòng:
   - Flutter: Chi tiết phòng > Tài sản phòng.
   - Backend: `/api/v1/rooms/:id/assets`.
   - Hỗ trợ thêm/xóa trong UI; backend đã có thêm/sửa/xóa.

6. Lịch kiểm tra phòng:
   - Flutter: Chi tiết phòng > Lịch kiểm tra phòng.
   - Backend: `/api/v1/rooms/:id/inspections`.
   - Hỗ trợ lên lịch và đánh dấu hoàn tất trong UI; lịch sắp đến hạn sẽ xuất hiện ở notifications/action items.

7. Phí cố định/dịch vụ phòng:
   - Flutter: Chi tiết phòng > Phí cố định hàng tháng.
   - Backend: `/api/v1/rooms/:id/service-fees`.
   - Ví dụ: Internet, rác, gửi xe, vệ sinh.
   - Khi tạo hóa đơn lẻ hoặc hóa đơn hàng loạt, các phí đang bật sẽ tự cộng vào `otherAmount` và ghi breakdown trong note hóa đơn.
   - Với hóa đơn lẻ, ô `Phí khác` nhập tay vẫn được cộng thêm phía trên khoản phí cố định.

8. Tự động lập hóa đơn tháng:
   - Flutter landlord: Dashboard > Tạo hóa đơn tháng.
   - Backend: `/api/v1/billing/automation`, `/api/v1/billing/automation/preview`, `/api/v1/billing/automation/run`.
   - Mỗi khu trọ có cấu hình riêng: bật/tắt, ngày lập hóa đơn và hạn thanh toán.
   - Preview cho biết số hóa đơn sẽ tạo, hóa đơn đã tồn tại và chỉ số điện/nước còn thiếu.
   - Khi chạy, hệ thống dùng lại bulk invoice flow nên vẫn tự cộng phí cố định và bỏ qua hóa đơn đã tồn tại.

9. Tenant portal nâng cấp:
   - Flutter tenant: đăng nhập tenant và vào `/tenant`.
   - Backend: `GET /api/v1/tenant/leases`, `GET /api/v1/tenant/invoices/:id`.
   - Tenant xem được hợp đồng đang thuê/lịch sử hợp đồng và tải/chia sẻ PDF từ chi tiết hóa đơn.

10. Quản lý tenant nâng cấp:
   - Flutter landlord: Danh sách người thuê > Chi tiết người thuê.
   - Backend: `GET /api/v1/tenants/:id/overview`.
   - Chi tiết tenant hiển thị tổng quan công nợ, quá hạn, đã thu, số dư cọc, proof chờ duyệt, sửa chữa mở và trạng thái tài khoản tenant.
   - Timeline vận hành gom các sự kiện hợp đồng, hóa đơn, thanh toán, proof, giao dịch cọc và bảo trì.

## Chức năng ưu tiên cao đã triển khai

5 phần vận hành nên test tiếp theo sau khi đăng nhập landlord/tenant:

1. Quản lý tiền cọc:
   - Backend: `POST /api/v1/leases/:id/deposits`, `GET /api/v1/leases/:id/deposits`.
   - Flutter landlord: vào Chi tiết người thuê > hợp đồng active > Cọc.
   - Hỗ trợ thu cọc, hoàn cọc, khấu trừ và điều chỉnh. Hợp đồng hiển thị `Số dư cọc`.

2. Gia hạn/cập nhật hợp đồng:
   - Backend: `PATCH /api/v1/leases/:id`, `POST /api/v1/leases/:id/renew`.
   - Flutter landlord: vào Chi tiết người thuê > hợp đồng active > Gia hạn.
   - Lưu lịch sử thay đổi hợp đồng để sau này mở rộng audit/preview.

3. Nhắc nợ tự động:
   - Backend: `GET /api/v1/billing/reminders`, `POST /api/v1/billing/reminders/run`.
   - Flutter landlord: vào Dashboard > Báo cáo, mục Nhắc nợ tự động.
   - Hệ thống tự gom hóa đơn chưa thu/thu một phần, quá hạn hoặc sắp đến hạn, kèm nội dung nhắc để copy gửi tenant.

4. Tenant dashboard:
   - Backend: `GET /api/v1/tenant/dashboard`.
   - Flutter tenant: đăng nhập tài khoản tenant và vào `/tenant`.
   - Hiển thị tổng nợ, số hóa đơn còn mở, quá hạn, sắp hạn, yêu cầu sửa chữa mở và thông báo chưa đọc.

5. Báo cáo doanh thu/chi phí:
   - Backend: `GET /api/v1/reports/monthly?month=<ISO-date>&propertyId=<property-id>`.
   - Flutter landlord: Dashboard > Báo cáo.
   - Có tổng đã lập hóa đơn, đã thu, công nợ, chi phí, lợi nhuận ước tính, thu/hoàn cọc và danh sách hóa đơn còn nợ.

## Local admin bootstrap

Quy trình local mặc định dùng PostgreSQL 16 native. Nếu trước đây từng dùng Docker database, admin trong Docker volume không tự xuất hiện trong native database; cần bootstrap lại trên đúng `DATABASE_URL`.

```bash
cd /Users/hoang/Rental_room_management/backend
brew services start postgresql@16

export ADMIN_BOOTSTRAP_EMAIL="<unique-admin-email>"
export ADMIN_BOOTSTRAP_NAME="<admin-full-name>"
read -s ADMIN_BOOTSTRAP_PASSWORD
export ADMIN_BOOTSTRAP_PASSWORD

npm run admin:bootstrap
```

Dùng email admin riêng, không dùng email/password demo landlord trong `prisma/seed.ts`. Password phải là secret riêng, tối thiểu 12 ký tự theo bootstrap policy và nên có chữ hoa, chữ thường, số và ký hiệu. Không ghi password thật vào tài liệu, `.env.example`, source control, API URL hoặc Flutter configuration.

Script đọc `DATABASE_URL` từ `backend/.env`, lưu password dưới dạng Argon2id hash và in xác nhận khi thành công. Validation hiện tại của script không nên được hiểu là một password-complexity policy đầy đủ; vẫn phải dùng password mạnh do secret manager hoặc người vận hành cung cấp.

### Behavior khi chạy lại

- Email chưa tồn tại: tạo admin mới.
- Email đã thuộc admin: cập nhật tên/password và kích hoạt lại tài khoản.
- Email đã thuộc landlord: script từ chối, không tự nâng landlord thành admin.

Vì vậy cần kiểm tra email và môi trường database trước khi chạy lại bootstrap. Sau khi chạy xong, xóa biến password khỏi session hoặc đóng terminal.

## Start API và verify

```bash
cd /Users/hoang/Rental_room_management/backend
npm run start:dev
curl http://localhost:3000/api/v1/health
```

Chạy Flutter bằng local API:

```bash
cd /Users/hoang/Rental_room_management
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Nếu vừa pull code mới có upload file, chạy thêm:

```bash
flutter pub get
```

Đăng nhập bằng email/password vừa bootstrap. User role `admin` được client route tới `/admin`; landlord được route tới `/dashboard`. Route guard phía Flutter chỉ là UX guard; backend enforce admin endpoints bằng `@Roles(AuthRole.ADMIN)`.

## Seed demo và database

Backend có `prisma/seed.ts` cho dữ liệu demo landlord/property/room/tenant/lease. Seed demo không phải cơ chế tạo admin và không nên chứa production admin secret. Dùng `npm run admin:bootstrap` cho admin.

Áp migration đã commit bằng:

```bash
npm run prisma:generate
npm run prisma:deploy
npx prisma migrate status
```

Docker PostgreSQL chỉ là fallback; không chạy đồng thời native và Docker trên port `5432`.

## Admin REST API hiện có

Các Property/Room/Tenant/Lease/Billing API thông thường vẫn là resource API scope theo authenticated landlord. Admin dùng contract riêng dưới `/api/v1/admin/...` cho overview, landlord management và property management:

```http
GET    /api/v1/admin/overview
GET    /api/v1/admin/landlords?search=&status=all|active|inactive
POST   /api/v1/admin/landlords
GET    /api/v1/admin/landlords/:id
PATCH  /api/v1/admin/landlords/:id
PATCH  /api/v1/admin/landlords/:id/status
GET    /api/v1/admin/properties?search=&landlordId=
POST   /api/v1/admin/properties
GET    /api/v1/admin/properties/:id
PATCH  /api/v1/admin/properties/:id
```

Giới hạn có chủ đích: admin không CRUD trực tiếp rooms, tenants, leases, invoices, payments hoặc audit records. Quản lý admin profile/quyền, password reset request và audit admin operations đã có trong admin workspace.

## Expected login response

`POST /api/v1/auth/login` trả session envelope bình thường với role `admin`; thời gian hết hạn thay đổi theo runtime:

```json
{
  "data": {
    "user": {
      "id": "<user-id>",
      "fullName": "<admin-full-name>",
      "email": "<admin-email>",
      "role": "admin"
    },
    "accessToken": "<short-lived-token>",
    "refreshToken": "<rotating-refresh-token>",
    "accessTokenExpiresAt": "<ISO-8601 timestamp>",
    "refreshTokenExpiresAt": "<ISO-8601 timestamp>"
  }
}
```

Refresh token được quản lý ở backend bằng SHA-256 digest lookup và transactional rotation; password dùng Argon2id.

## Production rules

- Không commit `.env` thật hoặc admin password.
- Không dùng demo seed credentials trong production.
- Dùng secret manager và password duy nhất cho từng môi trường.
- Không expose PostgreSQL public.
- Bật HTTPS và CORS allowlist.
- Redact password, JWT, refresh token và `Authorization` header khỏi log.
- Giữ backend role guard cho mọi admin mutation và mở rộng test authorization khi thêm admin resource mới.

## Admin Sprints 2–4

- Tạo admin theo preset `support`, `moderator`, `analyst` hoặc `super_admin`; cấp thêm permission chỉ sau khi có reason/audit.
- `ADMIN_REPORT_WORKER_ENABLED` mặc định có thể tắt ở test; bật ở worker process production sau khi `DELIVERY_ENCRYPTION_KEY` hợp lệ.
- Chỉ grant `admin.finance.read` cho role cần xem số liệu; endpoint reconciliation không có thao tác ghi dữ liệu.
- Xem đầy đủ endpoint, matrix quyền và staging smoke checklist tại `docs/admin-sprints-234.md`.
