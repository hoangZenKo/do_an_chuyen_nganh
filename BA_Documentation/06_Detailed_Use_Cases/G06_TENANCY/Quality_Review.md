# Rà soát G06 — Hồ sơ thuê, hợp đồng và tiền cọc

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 17/17 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Tạo User trực tiếp và mời qua invite là hai cơ chế khác, quyền STAFF khác. TENANT đọc lease không có bằng chứng UI shareLeasePdf; xuất thuộc vận hành. Kết thúc lease không tự quyết toán.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-TEN-01 | Tài khoản TENANT không đồng nghĩa đã ký hợp đồng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:91` |
| UC-TEN-02 | Chưa thấy UI TENANT nối shareLeasePdf; không gán khả năng xuất PDF chỉ vì dùng chung model. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:181` |
| UC-TEN-08.1 | TENANT chỉ đọc, không thêm/xóa người ở cùng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205` |
| UC-TNT-01 | Scope hồ sơ của STAFF không được suy chỉ từ landlordId chung. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:116` |
| UC-TNT-02.1 | Tạo Tenant không tự tạo User hoặc lease. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:209` |
| UC-TNT-02.2 | Sửa profile không đổi role hoặc tự tạo tài khoản cổng thuê. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:255` |
| UC-TNT-02.3 | Đây là Tenant.isActive; không đồng nhất với thao tác đình chỉ User của Admin. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:279` |
| UC-TNT-02.4 | Không xóa lịch sử thuê/hóa đơn để xóa hồ sơ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:296` |
| UC-TNT-03 | Không có bằng chứng đường này tự gửi email; STAFF bị chặn TenantInvitesController. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.service.ts:54` |
| UC-TNT-03.1 | STAFF tenant.manage có đường trực tiếp trong whitelist; không vì UC mời bị chặn mà phủ nhận đường này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:222` |
| UC-TNT-04 | Xuất phía client không chứng minh chữ ký số hoặc giá trị hợp đồng điện tử. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:271` |
| UC-TNT-05 | CreateLeaseDto không nhận endDate; không tự thêm ngày kết thúc. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:87` |
| UC-TNT-06.1 | Không tự điều chỉnh hóa đơn đã phát hành theo điều khoản mới. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:198` |
| UC-TNT-06.2 | Không tự thu cọc/nợ khi gia hạn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:224` |
| UC-TNT-06.3 | Không tự chốt quyết toán/hoàn cọc; phòng không tự VACANT. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:160` |
| UC-TNT-07 | Ghi sổ cọc không thực hiện chuyển tiền ngân hàng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:262` |
| UC-TNT-12.1 | TENANT không có quyền thêm/xóa; capacity tính cả người thuê chính. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 17 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Tạo User trực tiếp và mời qua invite là hai cơ chế khác, quyền STAFF khác. TENANT đọc lease không có bằng chứng UI shareLeasePdf; xuất thuộc vận hành. Kết thúc lease không tự quyết toán. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
