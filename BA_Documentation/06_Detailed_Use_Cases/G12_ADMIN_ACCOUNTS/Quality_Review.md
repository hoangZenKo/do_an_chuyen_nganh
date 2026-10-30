# Rà soát G12 — Tài khoản và tài nguyên nền tảng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 12/12 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Admin là một Actor; preset/capability không tạo loại Actor mới. Quyền đọc accounts.view khác đường landlords cũ accounts.manage; không grant vì chung service.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-ADM-02 | Không mở PII đầy đủ chỉ từ accounts.view. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` |
| UC-ADM-03.1 | Production cấm createLandlord trực tiếp, phải dùng lời mời. | Một phần | `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:90` |
| UC-ADM-03.2 | Không sửa email/mật khẩu/quyền qua đường này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:114` |
| UC-ADM-04.1 | Khôi phục không phục hồi refresh/session đã thu hồi. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:56` |
| UC-ADM-04.3 | Không dùng quyền thu hồi phiên mình để suy thu hồi người khác. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:79` |
| UC-ADM-05.1 | Reveal không phải xuất toàn bộ dữ liệu User; dùng projection được lựa chọn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:93` |
| UC-ADM-05.2 | Không làm UC này thành Admin biết mật khẩu người dùng; giao link ngoài chưa xác minh. | Một phần | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:192` |
| UC-ADM-06.1 | Preset không tạo Actor mới; quyền Admin không mặc định gồm quyền chủ trọ. | Một phần | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` |
| UC-ADM-06.2 | Rà soát không tự đổi quyền hoặc thu hồi phiên. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.service.ts:12` |
| UC-ADM-08 | Tra toàn nền tảng là API Admin riêng; không thừa hưởng landlordScope. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:133` |
| UC-ADM-09 | Không suy ra chuyển quyền sở hữu khu từ updateProperty chỉ sửa name/address. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:147` |
| UC-ADM-10 | ROOM/TENANT/LEASE/INVOICE/PAYMENT có kiểm quyền riêng; tìm kiếm không mở quyền chỉnh sửa. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.service.ts:35` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 12 UC đều được phủ đủ.

## Khoảng chưa xác minh

- UC-ADM-03.1 — Một phần:  Nhánh mật khẩu trực tiếp giới hạn môi trường dev; nhánh lời mời phụ thuộc giao link ngoài.
- UC-ADM-05.2 — Một phần:  Xếp hàng yêu cầu khôi phục; chưa xác nhận email thực.
- UC-ADM-06.1 — Một phần:  Có cấp quyền/lời mời/gửi lại; giao nhận kích hoạt bên ngoài chưa được kiểm chứng.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Admin là một Actor; preset/capability không tạo loại Actor mới. Quyền đọc accounts.view khác đường landlords cũ accounts.manage; không grant vì chung service. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
