# Rà soát G03 — Đăng tin, lịch xem và nhận phòng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 7/7 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Ẩn tin chủ trọ khác quyết định ẩn của Admin; quản lý slot khác đặt lịch. Bàn giao có hai Actor/mục tiêu độc lập; không gộp accept vào save.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-DIS-05 | Sửa nội dung làm mất xác minh trước đó; chủ trọ không tự PUBLISH tin. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` |
| UC-DIS-06.2 | Không suy ra điều kiện chỉ PUBLISHED từ luồng HIDE của Admin: đường hide chủ trọ dùng mutate riêng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:124` |
| UC-DIS-08 | Xóa hết slot không có bằng chứng tự tắt viewingSlotsRequired. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:102` |
| UC-DIS-09 | TENANT không được xác nhận/hoàn tất thay chủ trọ và không đổi sang tin khác qua reschedule. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:83` |
| UC-DIS-10 | COMPLETED không tự lập lease; xác nhận phải kiểm lại điều kiện phòng và chồng lịch. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:67` |
| UC-TNT-12.2 | Lưu biên bản không đồng nghĩa người thuê đã nhận phòng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:22` |
| UC-TNT-12.3 | Xác nhận là bằng chứng lịch sử thuê cho xét điều kiện review; không tạo thanh toán. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:58` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 7 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Ẩn tin chủ trọ khác quyết định ẩn của Admin; quản lý slot khác đặt lịch. Bàn giao có hai Actor/mục tiêu độc lập; không gộp accept vào save. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
