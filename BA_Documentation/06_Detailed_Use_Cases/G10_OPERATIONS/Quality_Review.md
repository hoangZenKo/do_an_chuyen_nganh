# Rà soát G10 — Công việc, thông tin và hỗ trợ sử dụng

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 9/9 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Thông báo platform/housing/portal/announcement không cùng namespace. Ghi SENT của Zalo mock không chứng minh provider. Chatbot chỉ hướng dẫn có nguồn, không thực hiện nghiệp vụ thuê.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-OPS-04 | STAFF bị chặn OperationsController; đọc feed không tự hoàn tất công việc nguồn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/operations/operations.service.ts:50` |
| UC-OPS-05 | Không cho VACANT khi pipeline chưa xong; không đổi stage tùy ý. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/operations/turnovers.service.ts:13` |
| UC-OPS-06 | STAFF bị chặn P1OperationsController; worker sinh task nội bộ không là actor riêng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:41` |
| UC-OPS-06.1 | Task thuộc chủ trọ; không tự hoàn tất bảo trì hoặc turnover nguồn khác. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:56` |
| UC-OPS-07 | SENT ở Announcement là thông báo nội bộ, không mặc định giao SMS/Zalo/email. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:46` |
| UC-SUP-04 | Quyền là hợp các handler thực tế; STAFF không được suy từ decorator NotificationsController bị chặn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` |
| UC-SUP-06 | Không có bằng chứng gọi Ollama thật trong đợt này; unit test mô phỏng không là acceptance model. | Một phần | `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.service.ts:24` |
| UC-TEN-09.2 | SENT của đường mock không chứng minh Zalo bên ngoài nhận; khác gửi ZNS thật có cấu hình. | Đã triển khai — MÔ PHỎNG | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:279` |
| UC-TEN-09.3 | Người thuê không đọc SCHEDULED/CANCELLED qua danh sách này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:53` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 9 UC đều được phủ đủ.

## Khoảng chưa xác minh

- UC-SUP-06 — Một phần:  Retrieval, scope và fallback có code/test; chưa gọi model Ollama thật trong khảo sát.
- UC-TEN-09.2 — Đã triển khai — MÔ PHỎNG:  Tin được lưu nội bộ, không mặc định gửi ra Zalo.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Thông báo platform/housing/portal/announcement không cùng namespace. Ghi SENT của Zalo mock không chứng minh provider. Chatbot chỉ hướng dẫn có nguồn, không thực hiện nghiệp vụ thuê. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
