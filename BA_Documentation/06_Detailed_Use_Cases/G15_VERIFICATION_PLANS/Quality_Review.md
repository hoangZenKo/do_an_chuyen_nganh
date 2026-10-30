# Rà soát G15 — Hồ sơ xác minh và gói dịch vụ

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 6/6 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Xác minh landlord, hồ sơ khu và verified listing khác nhau. Gói là entitlement hành chính, chưa có mua gói/doanh thu. Hủy không hoàn tiền/xóa inventory.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-ADM-18 | Xác minh hồ sơ khác xác minh tin đăng; có record evidence không chứng minh scanner ngoài hoạt động trong đợt này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:22` |
| UC-ADM-18.1 | Chủ trọ không có quyền xét duyệt; Admin và landlord dùng đường khác nhau. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:15` |
| UC-ADM-19 | Chưa có endpoint LANDLORD tự trình khu trong UC này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-property-review.service.ts:16` |
| UC-ADM-20 | platformRevenueAvailable=false; quản lý danh mục không có quy trình mua/thu tiền gói được xác minh. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:19` |
| UC-ADM-21 | Quota áp dụng khi đã có subscription; hết hạn chặn tăng inventory, không xóa khu/phòng cũ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:52` |
| UC-ADM-22 | Không hoàn tiền và không xóa inventory; không có subscription billing thực được xác nhận. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:109` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 6 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Xác minh landlord, hồ sơ khu và verified listing khác nhau. Gói là entitlement hành chính, chưa có mua gói/doanh thu. Hủy không hoàn tiền/xóa inventory. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
