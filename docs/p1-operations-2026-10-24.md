# P1: vận hành, thanh toán và thông báo

Cập nhật ngày 25/10/2026. Flutter nằm tại `/Users/hoang/Rental_room_management`,
backend NestJS tại `backend`.

## Điểm vào trong ứng dụng

- Chủ trọ/nhân viên: **Cài đặt → Vận hành → Trung tâm vận hành**
  (`/operations/p1`). Trung tâm có các mục trả phòng, checklist, lịch định kỳ
  và thông báo. Quyền nhân viên quyết định mục nào được xem hoặc thay đổi.
- Người thuê: mở chi tiết hóa đơn còn dư nợ rồi chọn **Thanh toán thẻ demo**.
- Người thuê: vào màn hình thông báo và chọn **Chủ trọ** để đọc announcement;
  bấm **Xác nhận đã đọc** để gửi xác nhận, không tự xác nhận khi chỉ mở màn hình.
- Chủ trọ: từ chi tiết hóa đơn mở lịch sử giao dịch online để xem xác nhận demo;
  giao dịch ngân hàng cũ được giữ read-only, không phân bổ qua cổng demo.

## 1. Quy trình trả phòng

Kết thúc hợp đồng tạo quy trình trong cùng transaction:

`RETURNED → INSPECTION → REPAIR → CLEANING → READY`.

Phòng chuyển sang `MAINTENANCE`, xóa tên người đang thuê và ẩn tin đăng đang
công khai. Không thể tạo hợp đồng mới hoặc đổi phòng thành trống khi quy trình
chưa hoàn thành. Từng bước yêu cầu ghi chú và `version` hiện tại; yêu cầu cũ
hoặc bỏ bước trả HTTP 409. Bước sửa chữa/hoàn tất bị chặn nếu phòng còn phiếu
bảo trì `OPEN` hoặc `IN_PROGRESS`. Hoàn tất chuyển phòng về `VACANT`; tin đăng
không tự công khai trở lại.

## 2. Checklist định kỳ

Tạo lịch cho một khu hoặc phòng với loại việc ghi điện nước, kiểm tra, thu tiền,
vệ sinh hoặc gia hạn. Chọn tần suất và ngày bắt đầu, nhập từng mục checklist
trên một dòng. Có thể tạm dừng/bật lại lịch mà không xóa lịch sử công việc.

Worker backend chạy mỗi phút và khi khởi động. Việc sinh công việc dùng khóa
database cùng unique key theo lịch/ngày đến hạn, tránh tạo trùng khi chạy nhiều
instance. Cập nhật checklist dùng optimistic locking. Lịch tháng giữ ngày neo
theo giờ Việt Nam, rút về ngày cuối tháng nếu cần. Mỗi lượt xử lý tối đa 100 lịch
và 32 kỳ còn thiếu cho mỗi lịch; phần còn lại tiếp tục ở lượt sau.

Worker mặc định bật ngoài `NODE_ENV=test`. Đặt
`OPERATIONS_SCHEDULER_ENABLED=false` để tắt cả sinh checklist và gửi thông báo
đến hạn. Đây là worker trong tiến trình API; API phải chạy để thực hiện lịch.

## 3. Checkout QR thẻ demo nội bộ

Đây là mô phỏng khép kín để demo UX, không phải cổng Visa, VietQR, ngân hàng
hoặc webhook bên ngoài. Không cần đăng ký tài khoản, API key hay chuyển tiền.

```dotenv
OPERATIONS_SCHEDULER_ENABLED=true
DEMO_PAYMENTS_ENABLED=true
DEMO_PAYMENT_BASE_URL="http://localhost:3000"
DEMO_CHECKOUT_SECRET="một-khóa-random-dài-ít-nhất-32-ký-tự"
```

Luồng demo:

1. Người thuê mở hóa đơn và chọn **Thanh toán thẻ demo**.
2. Nếu là hóa đơn thật, app đề nghị tạo **hóa đơn demo riêng 10.000 VND**;
   hóa đơn thật không bị đổi và không thể nhận thẻ demo.
3. Backend tạo session 30 phút, QR chứa URL checkout nội bộ. Quét QR chỉ mở
   trang của ứng dụng; không mở app ngân hàng và không tạo giao dịch thật.
4. Nhập thẻ `4242 4242 4242 4242`, hạn tương lai `MM/YY`, CVC `123`, rồi bấm
   **Xác nhận thanh toán demo**. Backend khóa hóa đơn, chỉ ghi nhận một payment
   mô phỏng và cập nhật hóa đơn demo thành đã trả.
5. Session lưu token băm và chỉ lưu `VISA`/`4242`; không lưu số thẻ đầy đủ/CVC.
   Gửi lại form hoặc gọi lại endpoint không cộng tiền lần hai.

Chuẩn bị dữ liệu mẫu bằng `npm run demo:prepare`. Với thiết bị khác máy chạy API,
không dùng `localhost`: đặt backend `DEMO_PAYMENT_BASE_URL=http://192.168.1.8:3000`
và chạy Flutter với `--dart-define=API_BASE_URL=http://192.168.1.8:3000/api/v1`.
Thay IP ví dụ bằng IP máy chạy backend, hai thiết bị cần truy cập được nhau. Production luôn
chặn demo dù có bật biến môi trường. Hóa đơn demo bị loại khỏi báo cáo, số liệu
tài chính và nhắc nợ thật; giao diện luôn gắn nhãn **DEMO - không thu tiền thật**.

## 4. Trung tâm thông báo

Hỗ trợ gửi ngay hoặc lên lịch, mẫu nội dung và nhóm người thuê. Phạm vi gửi gồm
toàn bộ người thuê, khu trọ, phòng, nhóm hoặc danh sách người thuê được chọn.
Danh sách người nhận được chốt lúc tạo thông báo, không tự bổ sung người mới
vào một lịch đã tạo. Có thể hủy thông báo chưa gửi và xem xác nhận từng người.
Thông báo được phát trong ứng dụng; chưa tích hợp push/SMS/email cho announcement.

## Database và chạy backend

```bash
cd /Users/hoang/Rental_room_management/backend
npm ci
npm run prisma:generate
npm run prisma:deploy
npm run build
npm run demo:prepare
npm run start:dev
```

Các migration P1 và demo checkout đã áp dụng cho DB phát triển `rental_management`:

- `20261024100000_add_p1_operations_payments`
- `20261024110000_p1_group_owner_integrity`
- `20261024150000_demo_card_checkout`
- `20261025100000_isolate_demo_invoice_periods`

Migration thứ hai ràng buộc nhóm và mẫu thông báo với chủ trọ bằng foreign key.
Không chạy `resetDatabase()` hoặc E2E vào DB phát triển/production. Test P1
dùng database tách biệt `rental_management_p1_test`, `NODE_ENV=test` và worker tắt.

## Kiểm chứng local

- Backend build và unit suite hiện xanh: 193 test đạt, 7 test bị skip theo cấu
  hình có sẵn. E2E không-chatbot đạt 101/101 trên database test riêng, trong đó
  P1 + demo checkout đạt 16/16. Không chạy chatbot E2E yêu cầu môi trường riêng.
- Flutter analyzer scoped cho các file P1/demo không có lỗi; test Flutter scoped
  đạt 69/69 (P1, billing, tenant portal), gồm QR ở chiều rộng 320/430/1280 và
  lifecycle foreground/background. Build iOS Simulator đã thành công.
- Không thực hiện giao dịch ngân hàng thật, không gọi payOS/Stripe/Visa API và
  không có webhook bên ngoài. Đây là checkout mô phỏng nội bộ để demo UX.
- Chrome desktop/mobile đã thử form thật: từ chối thẻ sai, nhận thẻ demo và chỉ
  tạo một payment mô phỏng. Trang 320px không tràn ngang; session đã trả không
  hiển thị form nữa. Form `no-referrer` hỗ trợ `Origin: null`, còn
  `Sec-Fetch-Site: cross-site` luôn bị chặn; token ngẫu nhiên vẫn bắt buộc.
- Trước khi dùng dữ liệu thật, giữ `DEMO_PAYMENTS_ENABLED=false`, không dùng hóa
  đơn demo để kiểm thử số liệu tài chính và kiểm tra quyền tenant/landlord trên
  môi trường staging riêng.
