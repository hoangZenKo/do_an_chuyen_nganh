# Admin account setup

Flutter client không chứa backend/database. Backend hiện nằm ở `/Users/hoang/rental-room-api`. Public registration luôn tạo tài khoản `landlord`; admin phải được tạo bằng CLI bootstrap. Sau khi đăng nhập, admin dùng nhóm endpoint `/api/v1/admin/...` hiện có để quản lý landlords/properties ở phạm vi platform. Khi tạo property từ màn admin, Flutter hiện chọn landlord active bằng search/selector thay vì nhập raw UUID.

## Local demo landlord account

Nếu đã chạy seed demo trong backend, có thể đăng nhập tài khoản landlord demo:

- Email: `landlord@demo.com`
- Password: `DemoLandlord!2026`
- Role: `landlord`

Đây chỉ là tài khoản demo local để test flow landlord/dashboard; không dùng cho production và không phải tài khoản admin.

## Local demo tenant account

Tenant account không tự sinh từ public registration. Chủ trọ tạo hồ sơ người thuê trước, sau đó tạo mã mời từ màn chi tiết người thuê. Tenant mở link/mã kích hoạt và tự đặt mật khẩu.

Credential demo nên dùng để dễ test local:

- Email: `tenant@demo.com`
- Password: `DemoTenant!2026`
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
cd /Users/hoang/rental-room-api
brew services start postgresql@16

export ADMIN_BOOTSTRAP_EMAIL="<unique-admin-email>"
export ADMIN_BOOTSTRAP_NAME="<admin-full-name>"
read -s ADMIN_BOOTSTRAP_PASSWORD
export ADMIN_BOOTSTRAP_PASSWORD

npm run admin:bootstrap
```

Dùng email admin riêng, không dùng email/password demo landlord trong `prisma/seed.ts`. Password phải là secret riêng, tối thiểu 12 ký tự theo bootstrap policy và nên có chữ hoa, chữ thường, số và ký hiệu. Không ghi password thật vào tài liệu, `.env.example`, source control, API URL hoặc Flutter configuration.

Script đọc `DATABASE_URL` từ `/Users/hoang/rental-room-api/.env`, lưu password dưới dạng Argon2id hash và in xác nhận khi thành công. Validation hiện tại của script không nên được hiểu là một password-complexity policy đầy đủ; vẫn phải dùng password mạnh do secret manager hoặc người vận hành cung cấp.

### Behavior khi chạy lại

- Email chưa tồn tại: tạo admin mới.
- Email đã thuộc admin: cập nhật tên/password và kích hoạt lại tài khoản.
- Email đã thuộc landlord: script từ chối, không tự nâng landlord thành admin.

Vì vậy cần kiểm tra email và môi trường database trước khi chạy lại bootstrap. Sau khi chạy xong, xóa biến password khỏi session hoặc đóng terminal.

## Start API và verify

```bash
cd /Users/hoang/rental-room-api
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

Giới hạn hiện tại: chưa có admin CRUD cho rooms, tenants, leases, invoices, payments, audit records hoặc admin accounts; chưa có password reset hoặc audit log cho admin operations.

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
