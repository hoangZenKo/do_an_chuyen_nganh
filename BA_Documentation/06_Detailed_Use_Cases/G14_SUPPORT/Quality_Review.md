# Rà soát G14 — Dịch vụ hỗ trợ khách hàng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 8/8 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Requester ticket và Admin xử lý là hai mục tiêu. Internal không lộ requester. Scanner thiếu phải fail-closed; không đồng nhất có endpoint upload với tích hợp vận hành đã sẵn sàng.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-SUP-01 | STAFF bị interceptor chặn SupportController. | Một phần | `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:46` |
| UC-SUP-01.1 | Service.manage mới quyết quyền xử lý, không dựa decorator đa role. | Một phần | `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:63` |
| UC-SUP-02.1 | Agent hỗ trợ là ADMIN có capability, không Role/User loại mới. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:43` |
| UC-SUP-02.2 | Chính sách mới chỉ ticket mới, không tự tính lại deadline các ticket cũ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-sla.service.ts:25` |
| UC-SUP-03.2 | Mẫu không tự gửi ticket reply khi mới lưu; không suy có xóa vật lý nếu chỉ isActive. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:71` |
| UC-SUP-03.2.1 | Không suy tự hợp nhất mọi quan hệ khác chỉ vì cùng ticket; code chỉ chuyển các quan hệ nêu rõ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:50` |
| UC-SUP-03.2.2 | Admin chỉ đánh giá nếu chính là requester, không thay khách hàng vì quyền support.manage. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:37` |
| UC-SUP-03.3 | Lưu view không mở rộng quyền support hay bỏ giới hạn requester. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:14` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 8 UC đều được phủ đủ.

## Khoảng chưa xác minh

- UC-SUP-01 — Một phần: Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Luồng ticket có triển khai; biến thể tệp đính kèm fail-closed khi scanner chưa có, chưa xác nhận scanner thật.
- UC-SUP-01.1 — Một phần: Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Quyền xử lý ticket có code; tệp kèm cần scanner/storage và chưa kiểm chứng runtime ngoài.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Requester ticket và Admin xử lý là hai mục tiêu. Internal không lộ requester. Scanner thiếu phải fail-closed; không đồng nhất có endpoint upload với tích hợp vận hành đã sẵn sàng. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
