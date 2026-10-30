# Rà soát G16 — Quản trị chính sách và đối soát nền tảng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 9/9 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Nhập sao kê không tích hợp ngân hàng; proposal maker/checker độc lập, không ghi Payment mới. Flag không thay quyền; mô phỏng Admin không bỏ MFA/scope.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-DIS-13.2 | ADMIN có thể đọc cấu hình nhưng endpoint feedback chỉ LANDLORD/TENANT. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:316` |
| UC-ADM-15 | Nhập và ghép tham chiếu khoản thu đã có, không kết nối ngân hàng hay tự thu tiền. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:18` |
| UC-ADM-15.1 | Duyệt proposal không tạo thu ngân hàng hoặc Payment mới. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:126` |
| UC-ADM-17.1 | Flag không thay thế authentication/authorization; effective theo rollout không phải quyền RBAC. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:70` |
| UC-ADM-17.2 | Membership không tự biến thành quyền Admin capability mới; preset vẫn ở AdminProfile. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:16` |
| UC-ADM-23 | Không suy có endpoint xóa vật lý campus từ CRUD tên chung. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:182` |
| UC-ADM-24 | Tra cứu khác đối soát sao kê duyệt kép và không có quyền tự sửa tiền từ báo cáo mismatch. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-transactions.service.ts:24` |
| UC-ADM-26 | Kết quả RBAC không bỏ qua MFA, trạng thái và scope kiểm tại API thật. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:62` |
| UC-ADM-27 | Đọc feedback không tự mở khu pilot hoặc gửi feedback thay Actor khác. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:327` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 9 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Nhập sao kê không tích hợp ngân hàng; proposal maker/checker độc lập, không ghi Payment mới. Flag không thay quyền; mô phỏng Admin không bỏ MFA/scope. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
