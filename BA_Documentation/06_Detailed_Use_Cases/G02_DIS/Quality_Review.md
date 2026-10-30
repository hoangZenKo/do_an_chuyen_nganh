# Rà soát G02 — Tìm và lựa chọn phòng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 6/6 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Phân biệt yêu thích lưu DB với so sánh Riverpod cục bộ; ước tính không là hóa đơn. UI trực tiếp được bổ sung ở listing_detail_screen/student_listing_widgets thay liên kết màn hình chung của Catalog.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-DIS-01 | freshOnly chỉ nhận xác nhận phòng trong 14 ngày; không đồng nghĩa tin ngoài 14 ngày tự bị ẩn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:29` |
| UC-DIS-02 | Điểm tổng hợp dựa bốn tiêu chí room/cost/landlord/area. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:60` |
| UC-DIS-03 | Chỉ TENANT dùng các API favorite; trạng thái riêng từng tài khoản. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:31` |
| UC-DIS-04 | Không có endpoint sửa bộ tiêu chí đã lưu trong phạm vi đối chiếu. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:22` |
| UC-DIS-16 | Không có API lưu so sánh; state được tái tạo khi identity phiên thay đổi. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/lib/features/listings/listing_comparison_screen.dart:1` |
| UC-DIS-17 | Chia người và tháng đầu là dự tính; chưa gồm phí chưa kê khai, mua sắm/chuyển nhà. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/lib/features/listings/student_listing_widgets.dart:1` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 6 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Phân biệt yêu thích lưu DB với so sánh Riverpod cục bộ; ước tính không là hóa đơn. UI trực tiếp được bổ sung ở listing_detail_screen/student_listing_widgets thay liên kết màn hình chung của Catalog. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
