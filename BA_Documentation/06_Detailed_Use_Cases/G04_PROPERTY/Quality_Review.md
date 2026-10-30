# Rà soát G04 — Khu trọ và cơ sở vật chất

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 14/14 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

UC-OPT-06.2 và UC-OPT-07.1 dùng cùng PATCH nhưng dữ liệu mô tả phòng và chuyển status có quy tắc khác. Tắt isActive khác status; delete có kiểm lịch sử. Chưa cần đổi mã/gộp.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-OPT-02 | Quyền xem không bao gồm tạo khu. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:42` |
| UC-OPT-03.1 | STAFF bị chặn create ở interceptor dù có decorator quyền. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:61` |
| UC-OPT-03.2 | Cập nhật thông tin không thay landlordId hoặc tự lưu trữ khu. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:76` |
| UC-OPT-04.1 | Lưu trữ không xóa khu/phòng; khôi phục vẫn chịu quota đang có hiệu lực. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:89` |
| UC-OPT-04.3 | Không xóa dây chuyền lịch sử để ép xóa khu. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:116` |
| UC-OPT-05 | Tra phòng không tạo lease hoặc sửa trạng thái. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:92` |
| UC-OPT-06.1 | OCCUPIED phải được ràng buộc với hợp đồng; không tạo người thuê theo tenantName nhập tự do. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:115` |
| UC-OPT-06.2 | Không có bằng chứng tự điều chỉnh giá các lease/hóa đơn cũ khi đổi basePrice. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:141` |
| UC-OPT-07.1 | Không có endpoint status riêng; không nhầm status với isActive. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:141` |
| UC-OPT-07.2 | Tắt phòng không xóa lịch sử; không thay thế kết thúc lease. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:166` |
| UC-OPT-07.3 | Không hủy chứng từ hoặc lease để phục vụ xóa phòng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:190` |
| UC-OPT-08.1 | Đây là sổ tài sản, không tự tạo Expense hoặc khấu trừ cọc. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:203` |
| UC-OPT-08.2 | Lịch kiểm tra không tự trở thành phiếu bảo trì hoặc khoản chi. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:268` |
| UC-OPT-09 | STAFF room.view+scope chỉ đọc; mutation chỉ LANDLORD. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:340` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 14 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. UC-OPT-06.2 và UC-OPT-07.1 dùng cùng PATCH nhưng dữ liệu mô tả phòng và chuyển status có quy tắc khác. Tắt isActive khác status; delete có kiểm lịch sử. Chưa cần đổi mã/gộp. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
