# Rà soát G09 — Bảo trì và chi phí vận hành

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 5/5 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Expense từ complete là bước có điều kiện, không UC mới; actualCost liên kết chi không được sửa bất nhất. STAFF bị chặn escalate nhưng có các thao tác khác theo scope.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-BIL-19 | Khoản chi độc lập không tự thanh toán nhà cung cấp hoặc điều chỉnh invoice. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:34` |
| UC-OPS-01 | Tạo/comment không đồng nghĩa bảo trì đã hoàn thành hoặc có khoản chi. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:60` |
| UC-OPS-02 | STAFF không dùng escalate vì interceptor; worker SLA không là Actor ngoài. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:54` |
| UC-OPS-03 | Tạo chi tối đa một lần qua expenseId, không mô tả mọi lần complete đều tạo Expense. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:227` |
| UC-TEN-06 | TENANT không được hoàn tất/gắn chi thay quyền vận hành. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:371` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 5 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Expense từ complete là bước có điều kiện, không UC mới; actualCost liên kết chi không được sửa bất nhất. STAFF bị chặn escalate nhưng có các thao tác khác theo scope. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
