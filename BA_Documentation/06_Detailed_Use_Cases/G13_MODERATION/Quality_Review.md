# Rà soát G13 — Kiểm duyệt và chất lượng nội dung

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 11/11 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Review, reply, listing, report dùng quyết định khác nhau. Kháng nghị mở lại không tự approve. QA không chế tài. Batch kiểm duyệt có thể thành công một phần.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-ADM-11 | Gán người khác cần admins.manage; không dùng quyền listing để tự quyết review/reply. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:238` |
| UC-ADM-11.1 | Đây là dấu xác minh tin, không thay thế hồ sơ landlordVerification/propertyApprovalReview. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` |
| UC-ADM-12 | Review và reply có hai trạng thái duyệt riêng, cùng tài nguyên không đồng nghĩa một quyết định cho cả hai. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:140` |
| UC-ADM-12.1 | Đóng báo cáo không mặc định ẩn/xóa tin đăng; thay trạng thái tin dùng quyền/luồng riêng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:230` |
| UC-ADM-13.1 | Một kind chuyển bản active bằng retirement; không sửa lại lịch sử quyết định cũ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:12` |
| UC-ADM-13.2 | Mở lại để kiểm duyệt, không trực tiếp công khai nội dung. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:27` |
| UC-ADM-13.3 | QA độc lập, không tự áp chế tài hoặc đổi trạng thái nội dung. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:40` |
| UC-DIS-07 | Gửi report không lập tức ẩn tin hoặc kết luận vi phạm. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:217` |
| UC-DIS-12 | Không viết review chỉ từ tài khoản tìm phòng chưa có lịch sử; sửa phải duyệt lại. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:41` |
| UC-DIS-13.1 | Phản hồi không công khai ngay và không sửa nội dung/rating người thuê. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:134` |
| UC-DIS-15 | ADMIN không mặc định là chủ tài nguyên để appeal hộ; STAFF controller bị chặn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:27` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 11 UC đều được phủ đủ.

## Khoảng chưa xác minh

- Không có trạng thái Một phần/DEMO/MÔ PHỎNG trong nhóm theo Catalog; vẫn chưa nghiệm thu runtime hoặc DB triển khai.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Review, reply, listing, report dùng quyết định khác nhau. Kháng nghị mở lại không tự approve. QA không chế tài. Batch kiểm duyệt có thể thành công một phần. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
