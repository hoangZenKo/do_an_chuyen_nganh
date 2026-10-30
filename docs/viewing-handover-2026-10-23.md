# Mục 3: từ đặt lịch đến nhận phòng

Cập nhật ngày 23/10/2026. Mở rộng hành trình hiện có, không thay thế yêu thích, hợp đồng, hóa đơn hoặc sổ cọc.

## Cách dùng

### Chủ trọ

1. Vào **Tin đăng của tôi → Khung giờ xem → Mở khung 30 phút**. Chọn ngày và giờ theo thiết bị, tối thiểu cách hiện tại 15 phút và trong 90 ngày tới.
2. Sau lần mở đầu tiên, tin chỉ nhận các khung đã mở; xóa hết khung không tự mở lại chế độ chọn giờ tự do. Mỗi tin tối đa 200 khung sắp tới. API hỗ trợ thời lượng 15–120 phút, giao diện hiện mở khung 30 phút.
3. Xem yêu cầu ở **Lịch xem phòng**. Lịch chờ xác nhận cũng giữ chỗ; lịch của cùng chủ trọ ở phòng khác hoặc của sinh viên ở chủ trọ khác đều được kiểm tra trùng thời gian.
4. Khi sinh viên đổi giờ, yêu cầu trở về **Chờ xác nhận**. Xác nhận lại trước khi sinh viên tới. Hủy lịch có lý do hiển thị cho bên còn lại.
5. Sau khi xác nhận lịch, có thể chọn **Đã xem phòng** ngay nếu hai bên đã thực sự xem sớm, không cần chờ tới giờ hẹn. Hộp thoại cảnh báo trước khi lưu; chỉ chủ trọ sở hữu được thực hiện. Với demo, dùng dữ liệu thử riêng. Tạo hợp đồng vẫn là thao tác riêng sau đó. Sau khi tạo hợp đồng, mở **Bàn giao & tiền cọc** ngay trên lịch; hoặc vào hồ sơ người thuê, tại thẻ hợp đồng chọn cùng nút.
6. Nhập chỉ số điện/nước nguyên không âm, mô tả hiện trạng và tối đa 12 ảnh riêng tư, mỗi ảnh tối đa 8 MB. Lưu biên bản để người thuê kiểm tra. Chủ trọ không được xác nhận thay người thuê.

### Sinh viên

1. Mở chi tiết tin → **Đặt lịch xem phòng**. Chọn khung còn trống. Tin chưa từng cấu hình khung vẫn cho đề xuất giờ, thời lượng mặc định 30 phút để tương thích luồng cũ.
2. Vào **Lịch xem phòng → Đổi lịch** để gửi giờ mới. Lịch cũ chỉ thay thế khi giao dịch thành công; giờ mới cần được xác nhận lại. Có thể hủy lịch và ghi lý do.
3. Nhắc hẹn xuất hiện ở **Thông báo xem phòng** trong 24 giờ trước lịch đã xác nhận. Đây là thông báo trong app, không phải push/SMS/email; mở hoặc làm mới màn hình để xem.
4. Khi hợp đồng được tạo từ lịch xem, hồ sơ hiển thị **Chờ bàn giao**, chưa khẳng định đã nhận phòng. Mở **Bàn giao & tiền cọc** từ trang Phòng của tôi hoặc chi tiết hợp đồng.
5. Kiểm tra chỉ số, mô tả và ảnh (có thể phóng to). Chỉ tích xác nhận khi đã thực sự nhận phòng. Không xác nhận trước ngày bắt đầu hợp đồng. Sau xác nhận, trạng thái trở thành **Đang thuê** và biên bản khóa chỉnh sửa.
6. Đối chiếu riêng **cọc thỏa thuận / đã thu / đã hoàn / đã khấu trừ / điều chỉnh / cọc đang giữ**. Không có giao dịch thì tiền thực giữ bằng 0, dù hợp đồng có mức cọc.

## API

Prefix `/api/v1/housing`, yêu cầu JWT và quyền tương ứng.

| Endpoint | Nội dung |
| --- | --- |
| `GET /listings/:id/slots` | tenant xem tin còn nhận khách; landlord xem tin của mình. Trả `required` và khung có cờ `available`, không lộ danh tính người đang giữ chỗ. |
| `POST /listings/:id/slots` | landlord sở hữu tin; `startsAt`, `endsAt` là ISO instant có timezone. |
| `DELETE /slots/:id` | landlord sở hữu; không xóa khung có yêu cầu chờ/đã xác nhận. |
| `POST /viewings` | thêm `slotId` tùy chọn; bắt buộc khi tin đã bật khung giờ, thời điểm phải khớp chính xác. |
| `PATCH /viewings/:id/reschedule` | chỉ sinh viên đã đặt; `version`, `listingId`, `scheduledAt`, `slotId` tùy chọn, `note` tùy chọn. |
| `GET /leases/:id/handover` | hai bên hợp đồng; biên bản, ngày bắt đầu và tổng hợp sổ cọc. |
| `PUT /leases/:id/handover` | landlord; `version` (0 khi chưa có), `electricity`, `water`, `condition`, `imageUrls`. |
| `POST /leases/:id/handover/accept` | tenant của hợp đồng; `version` hiện tại. Ghi thời điểm xác nhận từ server. |

`GET /tenant/me`, `/tenant/leases` trả thêm `requiresHandover`, `handedOverAt`. Hợp đồng cũ không gắn lịch xem giữ nguyên cách hiển thị để không đánh dấu lại toàn bộ khách đang ở là chưa nhận phòng.

## Đồng thời và quyền riêng tư

- Đặt/đổi/xác nhận lịch chạy trong transaction Serializable, khóa tài khoản hai bên theo thứ tự ổn định, kiểm tra khoảng `[start, end)`; hai lịch liền kề được phép. Retry có giới hạn khi xung đột, trả 409 để tải lại khi cần.
- Đổi lịch có optimistic version, không đổi sang phòng khác, không để lại thay đổi một phần nếu khung mới vừa bị đặt.
- Nhắc hẹn chạy mỗi 60 giây, tối đa 200 lịch/lượt; khóa bản ghi và ghi `reminderSentAt` cùng transaction với thông báo. Nhiều worker không gửi trùng. Đổi lịch xóa mốc này và chỉ nhắc lại sau khi chủ trọ xác nhận giờ mới. Khi đọc thông báo, hệ thống cũng kiểm tra lịch đến hạn của chính tài khoản.
- Đặt `VIEWING_REMINDER_WORKER_ENABLED=false` để tắt vòng chạy nền; không tắt kiểm tra khi đọc thông báo. Worker tự tắt trong `NODE_ENV=test`.
- Ảnh phải là upload `PRIVATE`, MIME ảnh, thuộc chủ trọ đang lập biên bản. Không nhận ảnh công khai của tin, URL ngoài, PDF hoặc file thuộc tài khoản khác. Tenant liên quan được cấp URL ảnh có hạn theo ACL upload hiện có; người không liên quan bị từ chối.
- Lưu/nhận bàn giao khóa hợp đồng, kiểm tra version, trạng thái và ngày bắt đầu; audit lưu thao tác. Biên bản đã được tenant xác nhận không bị ghi đè.
- Bàn giao chỉ lưu mốc chỉ số ban đầu, không tự tạo hóa đơn điện/nước hoặc ghi nhận thu cọc. Khi lập kỳ điện nước đầu tiên, dùng các mốc đã đối chiếu trong biên bản; các kỳ và biểu giá vẫn thuộc luồng hóa đơn hiện tại.
- Đây là biên bản xác nhận trong app, chưa tích hợp chữ ký số hoặc thanh toán ngân hàng.

## Migration và xác minh

- Backend: `prisma/migrations/20261023160000_viewing_handover/migration.sql`; thêm `ViewingSlot`, `LeaseHandover`, thông tin thời lượng/lý do hủy/mốc nhắc hẹn; backfill lịch cũ thành 30 phút và sao chép lý do hủy đã có.
- Đã áp dụng trước trên database test riêng `rental_chatbot_test_audit_20261023`, sau đó áp dụng additive lên database local `rental_management`. Không reset/seed, không test trên Simulator hoặc điều khiển app đang chạy.
- Trước/sau migration local: 4 tài khoản, 600 tin, 6 cơ sở học mẫu, 2 hợp đồng, 0 lịch xem; giữ nguyên số lượng. Các cơ sở học demo vẫn là dữ liệu hư cấu, không được xác thực thành trường thật.
- Kiểm thử: Flutter analyze sạch, 215 test Flutter; API build thành công, 164 unit test qua (7 skip có sẵn), 72 E2E qua trong 10 suite.
- Ca mới bao phủ tranh chỗ đồng thời giữa sinh viên/chủ trọ, khung liền kề, giữ chế độ khung khi xóa hết, rollback đổi lịch, stale version, hủy có lý do, nhắc hẹn chống trùng, nhận phòng đúng quyền/ngày, ảnh riêng tư, số dư cọc và giao diện điện thoại chữ lớn.
- Chưa deploy production.
