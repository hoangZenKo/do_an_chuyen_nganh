# Rà soát G07 — Vòng đời thuê và quyết toán

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 7/7 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Gửi đề nghị, xét duyệt, thực thi có mục tiêu/trạng thái và actor khác; không gộp. Quyết toán không tự cấn nợ invoice cũ; hoàn cọc là ghi nhận, không chuyển ngân hàng.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-TEN-07.1 | Gửi đề nghị không tự thực thi thay đổi lease. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` |
| UC-TEN-07.2 | Gửi đề nghị không tự thực thi thay đổi lease. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` |
| UC-TEN-07.3 | Gửi đề nghị không tự thực thi thay đổi lease. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` |
| UC-TNT-08 | depositApplied=min(balanceCoc,totalCharges); refund=balanceCoc−applied. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:39` |
| UC-TNT-09 | Đây là ghi nhận, không lệnh chuyển tiền qua ngân hàng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:101` |
| UC-TNT-10 | Duyệt không tự thực hiện trả/chuyển/gia hạn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` |
| UC-TNT-11 | Không tự chốt quyết toán để vượt tiền điều kiện; không thu lại cọc khi tạo lease chuyển. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 7 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Gửi đề nghị, xét duyệt, thực thi có mục tiêu/trạng thái và actor khác; không gộp. Quyết toán không tự cấn nợ invoice cũ; hoàn cọc là ghi nhận, không chuyển ngân hàng. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
