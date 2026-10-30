# Rà soát G05 — Nhân sự và ủy quyền vận hành

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 4/4 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Mô phỏng quyền chỉ module/scope, chưa là authorization đầy đủ từng action. STAFF chỉ đọc list/presets, không dùng staff.manage để tự sửa quyền.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-STF-01 | Không có gửi email được chứng minh ở đường createInvite. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:200` |
| UC-STF-02 | JWT đọc profile/owner sống; STAFF không được tự quản lý nhân sự qua decorator staff.manage. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:161` |
| UC-STF-03 | Mô phỏng không thay thế guard/interceptor và kiểm tra nghiệp vụ từng API. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:211` |
| UC-STF-04 | StaffController chỉ list/presets được allowlist cho STAFF; không suy thêm quyền create/update. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:54` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 4 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Mô phỏng quyền chỉ module/scope, chưa là authorization đầy đủ từng action. STAFF chỉ đọc list/presets, không dùng staff.manage để tự sửa quyền. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
