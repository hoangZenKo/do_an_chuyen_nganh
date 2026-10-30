# Rà soát G11 — Báo cáo và giám sát vận hành

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 8/8 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Các dashboard có đối tượng/scope khác; giữ UC theo mục tiêu, không vì cùng chữ tổng quan mà gộp. Job queued không là file sẵn sàng. productionAccepted=false được giữ rõ.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-ADM-01 | Doanh thu mua gói trả available=false/SUBSCRIPTION_BILLING_NOT_IMPLEMENTED; không suy price gói thành doanh thu thật. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:64` |
| UC-ADM-14 | Xuất không tạo/xóa audit nguồn; escape CSV theo helper. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:202` |
| UC-ADM-16 | Kho ngoài là E05 tùy cấu hình; không suy link tải bỏ qua xác thực. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:92` |
| UC-BIL-20 | Loại demo khỏi dữ liệu invoice/payment; chỉ số theo định nghĩa billingAnalytics, không đồng nhất doanh thu nền tảng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:18` |
| UC-OPS-09 | Nhật ký là chỉ đọc; không có quyền sửa/xóa log trong UC này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:26` |
| UC-OPT-01 | Không coi trạng thái trên bản đồ là quyền đổi phòng tùy ý. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.ts:17` |
| UC-SUP-05.1 | Release summary productionAccepted=false, MANUAL_ACCEPTANCE_REQUIRED không phải đạt production. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.service.ts:18` |
| UC-SUP-05.2 | Queued không chứng minh provider ngoài đã gửi; mỗi loại job có quyền và cách retry riêng. | Một phần | `/Users/hoang/Rental_room_management/backend/src/health/operations-queue.service.ts:9` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 8 UC đều được phủ đủ.

## Khoảng chưa xác minh

- UC-SUP-05.2 — Một phần:  Theo dõi/retry job có code; chưa xác nhận dịch vụ giao nhận ngoài hệ thống.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Các dashboard có đối tượng/scope khác; giữ UC theo mục tiêu, không vì cùng chữ tổng quan mà gộp. Job queued không là file sẵn sàng. productionAccepted=false được giữ rõ. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
