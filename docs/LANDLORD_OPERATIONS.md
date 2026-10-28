# Phần 5 - Bảng điều hành công việc chủ trọ

Hoàn thiện ngày 24/10/2026. Phạm vi: tổng hợp công việc thực tế và mở đúng
màn hình xử lý, không tạo thêm dữ liệu giả trong cơ sở dữ liệu đang sử dụng.

## Cách sử dụng

- Dashboard có thẻ **Việc cần xử lý**, số việc/chưa đọc và tối đa ba việc ưu tiên.
- Thẻ tuân theo khu trọ đang hiển thị trên dashboard. Menu quản lý mở danh sách
  tất cả khu trọ.
- Trang `/actions` cho lọc theo khu trọ, nhóm công việc, phân trang 12 việc,
  kéo để làm mới và thử lại khi tải thất bại.
- Chạm công việc đánh dấu đã đọc và mở nơi xử lý. Nếu lưu trạng thái đọc lỗi,
  ứng dụng thông báo nhưng không chặn điều hướng.
- Quay lại từ màn hình xử lý sẽ tải lại danh sách và số lượng. **Đã đọc không
  đồng nghĩa hoàn thành**; việc chỉ biến mất khi dữ liệu nghiệp vụ được xử lý.

## Công việc và đích xử lý

| Nhóm | Điều kiện | Màn hình |
| --- | --- | --- |
| Lịch xem | `REQUESTED`, kể cả lịch đã lỡ giờ | Lịch xem, chọn đúng yêu cầu |
| Chứng từ | `PENDING`, hóa đơn còn tiền chưa thanh toán | Chi tiết hóa đơn và chứng từ |
| Hóa đơn | `UNPAID`/`PARTIAL`, còn dư nợ, quá hạn hoặc đến hạn trong bảy ngày | Chi tiết hóa đơn |
| Sửa chữa | `OPEN`/`IN_PROGRESS`, mọi mức ưu tiên | Đúng phiếu sửa chữa, độc lập khu trọ đang chọn |
| Hợp đồng | `ACTIVE`, ngày kết thúc trong 30 ngày hoặc đã quá hạn | Chi tiết khách thuê có thao tác gia hạn/kết thúc |
| Kiểm tra phòng | Chưa hoàn thành, đến hạn trong bảy ngày hoặc quá hạn | Chi tiết phòng, mở tab Lịch |

Thứ tự: mức độ `danger`, `warning`, `info`, rồi hạn xử lý/thời gian tạo và ID
để phân trang ổn định. Hạn hóa đơn/hợp đồng/kiểm tra dùng mốc ngày UTC hiện có;
lịch xem so với thời gian hiện tại. Hóa đơn không có ngày hạn không thuộc nhóm
nhắc hạn. Đọc một việc không ảnh hưởng trạng thái đọc của tài khoản khác.

## API

Backend tại `backend`:

- `GET /api/v1/operations/action-items`
- Query: `page` (1-10000), `limit` (1-50), `category`
  (`all`, `viewing`, `payment`, `invoice`, `maintenance`, `lease`, `inspection`),
  `propertyId` (UUID, tùy chọn).
- Response: `data.items`, `data.summary`, `data.categories`, `meta.total/page/limit`.
  `summary` tổng hợp trong khu trọ và quyền hiện tại, không thay đổi khi chỉ lọc
  nhóm hoặc đổi trang; `meta.total` là số việc sau khi lọc nhóm.
- `POST /api/v1/operations/action-items/:id/read`: idempotent, kiểm tra ID thuộc
  chủ trọ và nhóm mà tài khoản được xem; sử dụng bảng `NotificationRead` sẵn có.
  Không cần migration mới.

Landlord xem toàn bộ công việc của mình. Staff cần `operation.view` và quyền
tài nguyên tương ứng: `billing.view`, `maintenance.view`, `lease.view` cùng
`tenant.view`, hoặc `room.view`. Lịch xem chỉ dành cho landlord. Nhóm không đủ
quyền bị loại khỏi cả dữ liệu lẫn số đếm; yêu cầu trực tiếp nhóm đó trả `403`.
Property không thuộc chủ trọ trả `404`. Admin/tenant không được vào API này.
Đánh dấu đã đọc sử dụng quyền operation, không phụ thuộc `notification.view`.

## Kiểm thử và giới hạn xác minh

- Flutter analyzer: không có issue; toàn bộ 251 test qua.
- Backend: build thành công; 164 unit test qua (bảy test vốn được skip);
  98 E2E qua, gồm 16 ca riêng cho operations.
- iOS simulator debug build thành công; không thực hiện thao tác thủ công trên
  ứng dụng hoặc gửi thông báo ngoài hệ thống.
- Widget tests bao phủ lọc/phân trang, lỗi/retry, điều hướng và đánh dấu đọc,
  bộ lọc khu trọ, mobile 320px/chữ lớn, phiếu sửa chữa khác khu trọ đang chọn
  và tab kiểm tra phòng.
- E2E dùng riêng `rental_chatbot_test_audit_20261023`; tuyệt đối không chạy
  reset/seed test lên database đang làm việc.
- Đã đọc lại số lượng dữ liệu local: bốn tài khoản, 600 tin đăng, sáu campus,
  hai hợp đồng và không có review. Không chỉnh sửa các dữ liệu này.

Để chạy lại, dùng `flutter analyze`, `flutter test` ở repo Flutter; `npm run build`,
`npm test -- --runInBand` và `NODE_ENV=test DATABASE_URL=<test-db-url> npm run test:e2e`
ở backend. Không thay `DATABASE_URL` bằng database demo/production.
