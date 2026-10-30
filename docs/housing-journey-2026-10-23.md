# Tìm phòng, xem phòng và quản lý sau khi thuê

Cập nhật luồng xác nhận đã xem: 30/10/2026. Áp dụng cho Flutter và backend trong cùng repository; backend nằm ở `backend/`.

Phần mở rộng khung giờ, đổi lịch, nhắc hẹn và bàn giao đã triển khai tiếp trong `viewing-handover-2026-10-23.md`. Các giới hạn lịch rảnh và trạng thái migration trong tài liệu này là ghi nhận của phiên bản ban đầu; xem tài liệu mới cho hiện trạng local.

## Phạm vi triển khai

| Giai đoạn | Tình trạng trong source |
| --- | --- |
| Tìm phòng | Giữ bộ lọc trường/cơ sở, bán kính, giá, diện tích, tiện ích; dự toán điện/nước/phí và so sánh tối đa 3 phòng đã có. Thêm yêu thích lưu trên server theo tài khoản, phân trang, bỏ lưu và đánh dấu tin không còn nhận khách. |
| Kết nối | Thêm đặt lịch, chủ trọ xác nhận, hai bên hủy, chủ trọ đánh dấu đã xem sau khi lịch được xác nhận (kể cả xem sớm), thông báo trong app và tạo hợp đồng từ lịch đã xem. |
| Đang thuê | Tái sử dụng hóa đơn, chứng từ thanh toán, bảo trì và lịch sử hợp đồng hiện có. Sửa validation để nhận đường dẫn `/uploads/...` do chính API upload trả về cho chứng từ/ảnh bảo trì/bình luận. Bổ sung lịch sử thu/hoàn/khấu trừ/điều chỉnh cọc và số dư đã ghi nhận cho người thuê. |
| Thử nghiệm | Thêm cấu hình một khu vực, form đánh giá 1–5 và phản hồi theo giai đoạn; admin đọc phản hồi phân trang và API tổng hợp. Chưa mời người thật hoặc thu thập phản hồi thực tế. |

Không tạo backend giả hoặc chỉ lưu yêu thích bằng bộ nhớ thiết bị. Thông báo lịch xem được lưu trong database; đây chưa phải push notification, email hoặc SMS. Người dùng tải lại hoặc kéo để làm mới.

## Cách dùng

### Sinh viên / người tìm phòng

1. Đăng nhập bằng tài khoản người tìm phòng, mở chi tiết một tin thật.
2. Chọn **Lưu yêu thích**; danh sách nằm tại **Tài khoản → Phòng yêu thích**.
3. Chọn **Đặt lịch xem phòng**, chọn ngày/giờ theo múi giờ thiết bị và thêm lời nhắn. Tên tài khoản và lời nhắn được chia sẻ với chủ trọ của tin.
4. Theo dõi tại **Tài khoản → Lịch xem phòng** và **Thông báo xem phòng**. Chờ chủ trọ xác nhận trước khi tới.
5. Sau khi chủ trọ tạo hợp đồng, chọn **Phòng đang thuê** từ lịch để tải lại hồ sơ thuê. Nếu đang ở trang chưa liên kết phòng, chọn **Kiểm tra liên kết hợp đồng**.
6. Xem **Hợp đồng của tôi → chi tiết hợp đồng → Lịch sử tiền cọc**; các luồng hóa đơn/chứng từ/bảo trì giữ nguyên.

### Chủ trọ

1. Mở **Tin đăng của tôi → biểu tượng lịch** để thấy các yêu cầu thuộc tin của mình.
2. Xác nhận và ghi điểm hẹn/cách liên hệ, hoặc hủy kèm lý do.
3. Khi hai bên đã xem phòng, chọn **Đã xem phòng** và xác nhận trong hộp thoại. Có thể xác nhận trước giờ hẹn nếu buổi xem diễn ra sớm; giao diện cảnh báo khi chưa tới giờ. Demo chỉ thực hiện trên dữ liệu thử.
4. Chọn **Tạo hợp đồng**, xác nhận ngày bắt đầu, tiền thuê và cọc thỏa thuận. Thao tác này tạo hợp đồng có hiệu lực, không phải bản nháp hay chữ ký điện tử.
5. Server tạo/liên kết hồ sơ người thuê với tài khoản đã đặt lịch, tạo hợp đồng và đánh dấu phòng đã có người ở trong cùng transaction. Tin được ẩn; các lịch đang chờ/đã xác nhận khác của phòng này được hủy và thông báo.
6. Khi thực nhận tiền, ghi giao dịch cọc tại luồng hợp đồng hiện có. Luồng chuyển từ lịch xem **không tự ghi nhận đã thu cọc**.

## Quy tắc và an toàn dữ liệu

- Chỉ tài khoản `tenant` lưu yêu thích/đặt lịch; chưa cần có hồ sơ đang thuê.
- Lịch xem và thông báo chỉ dành cho `tenant`/`landlord` liên quan. Staff và admin không được đọc lịch cá nhân qua API này.
- Chỉ chủ trọ sở hữu lịch được xác nhận, hoàn tất và chuyển thành hợp đồng.
- Một tài khoản không có hai lịch đang chờ/đã xác nhận cho cùng tin. Hủy hoặc hoàn tất cho phép đặt lại.
- Giờ hẹn phải có timezone, cách hiện tại tối thiểu 15 phút và trong 90 ngày tới. Chủ trọ sở hữu được hoàn tất lịch đã xác nhận kể cả trước giờ hẹn; không thay đổi giờ hẹn, không tự tạo hợp đồng hoặc ghi nhận cọc. Lịch đã quá giờ phải hủy và đặt mới nếu cần xác nhận lại.
- Ngày bắt đầu hợp đồng là ngày lịch, gửi dưới dạng UTC midnight của chính ngày đã chọn; không chuyển local midnight thành ngày UTC hôm trước. Giờ xem phòng thì gửi như một thời điểm UTC và hiển thị theo giờ thiết bị.
- Trạng thái: `REQUESTED → CONFIRMED → COMPLETED → LEASED`; `REQUESTED`/`CONFIRMED` có thể chuyển `CANCELLED`.
- Mỗi cập nhật mang `version`; stale version trả 409. Tạo hợp đồng dùng row lock, transaction Serializable và retry có giới hạn; không tạo trùng khi gửi đồng thời.
- Không chuyển phòng không còn trống/tin đã ẩn/phòng ngừng hoạt động thành hợp đồng. Sai điều kiện rollback cả hồ sơ và hợp đồng.
- Tài khoản đã gắn hồ sơ thuộc chủ trọ khác cần được xử lý hồ sơ trước; không tự chiếm/chuyển liên kết. Đây là giới hạn quan hệ một tài khoản–một hồ sơ thuê hiện tại.
- Tin có nhãn dữ liệu mẫu `[explore-preview]` không nhận yêu thích/lịch xem ở API mới và không hiện nút đặt lịch thật.
- Không cho xóa phòng đã có lịch xem; giữ lịch sử và dùng ngừng hoạt động thay thế.
- Dữ liệu cache tự đổi theo tài khoản; form đang mở chặn gửi khi tài khoản thay đổi. Đăng nhập từ chi tiết phòng trở lại đúng tin, không nhận redirect tới URL ngoài.
- Số cọc trên hợp đồng là thỏa thuận. Số dư ledger là tổng thu/điều chỉnh trừ hoàn/khấu trừ; không có giao dịch thì số dư đã ghi nhận bằng 0. Thay đổi này cũng loại bỏ fallback coi cọc thỏa thuận là tiền đã giữ ở serializer hợp đồng chủ trọ. Dữ liệu cũ chưa có ledger cần được đối soát, không tự backfill giao dịch tiền thật.
- Lịch xem chưa có lịch rảnh/khóa khung giờ giữa nhiều phòng; chủ trọ phải kiểm tra lịch trước khi xác nhận.

## API mới

Prefix: `/api/v1/housing`. Các API đều yêu cầu JWT.

| API | Quyền |
| --- | --- |
| `GET /favorites?page=1` | tenant; 20 mục/trang |
| `GET /favorites/:listingId` | tenant; trạng thái đã lưu |
| `PUT /favorites/:listingId` | tenant; lưu idempotent |
| `DELETE /favorites/:listingId` | tenant; bỏ lưu idempotent |
| `GET /viewings?page=1` | tenant/landlord; lọc theo tài khoản |
| `GET /viewings/:id` | chỉ bên liên quan; mở đúng lịch từ thông báo, kể cả lịch cũ ngoài trang đầu |
| `POST /viewings` | tenant; `listingId`, `scheduledAt`, `note` tùy chọn |
| `PATCH /viewings/:id` | bên liên quan; `version`, `status`, `note` tùy chọn |
| `POST /viewings/:id/lease` | landlord sở hữu; `version`, `startDate`, `monthlyRent`, `deposit` |
| `GET /notifications?page=1` | tenant/landlord; dữ liệu riêng theo tài khoản, có `unreadCount` |
| `POST /notifications/:id/read` | tenant/landlord; chỉ cập nhật thông báo của mình |
| `GET /pilot` | tenant/landlord/admin; `enabled`, `area` |
| `POST /feedback` | tenant/landlord; `area`, `stage`, `rating`, `detail` |
| `GET /feedback?page=1` | admin; phân trang và tổng hợp theo khu vực/giai đoạn |

`GET /tenant/leases` và hồ sơ thuê trả thêm `depositBalance`, `depositTransactions`. Không thay đổi hợp đồng API chứng từ/hóa đơn/bảo trì.

## Migration và chạy local

Migration mới: `backend/prisma/migrations/20261023090000_housing_journey/migration.sql`.
Tạo `SavedListing`, `RoomViewing`, `HousingNotification`, `PilotFeedback` và enum `ViewingStatus`.

Đã áp dụng và kiểm thử trên database test riêng `rental_chatbot_test_journey_20261023`. **Chưa áp dụng lên database đang dùng của dự án, chưa restart API đang chạy và chưa triển khai production.**

Sau khi xác nhận đúng `DATABASE_URL` và sao lưu dữ liệu cần giữ, chạy tại backend:

```sh
npx prisma generate
npx prisma migrate deploy
npm run build
npm run start:dev
```

Flutter tiếp tục dùng `API_BASE_URL` hiện có:

```sh
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

Thiết bị thật phải dùng địa chỉ backend truy cập được từ thiết bị, không dùng localhost của điện thoại.

## Runbook thử nghiệm thực tế

1. Chọn một khu vực và một nhóm nhỏ, gợi ý 5–10 sinh viên, 2–3 chủ trọ có phòng thật. Đây là đề xuất quy mô, không phải số người đã tham gia.
2. Xác minh quyền đăng tin, giá/phí, ảnh, tình trạng trống và cơ sở trường. Không dùng tin mẫu làm tin thật.
3. Mời thủ công qua kênh đã được người tham gia đồng ý, nêu mục đích thử nghiệm và người hỗ trợ. Chưa có hệ thống email mời pilot, danh sách cohort hay cơ chế hạn chế truy cập pilot theo lời mời.
4. Đặt `RENTAL_PILOT_AREA="<khu vực đã chọn>"` trong môi trường backend và restart. Để trống mặc định thì tắt thu phản hồi. Khi mở, mọi tài khoản tenant/landlord đã đăng nhập có thể gửi phản hồi cho khu vực này; không phải allowlist người được mời.
5. Người tham gia vào **Tài khoản → Thử nghiệm khu vực nhỏ**. Phản hồi gồm giai đoạn, mức hài lòng và điểm vướng; không gửi giấy tờ hay dữ liệu thanh toán nhạy cảm.
6. Admin mở **Kiểm duyệt tin đăng → biểu tượng phản hồi**, hoặc **Tài khoản → Phản hồi thử nghiệm**. Theo dõi số phản hồi, điểm hài lòng, lý do không chốt, lỗi lịch và lỗi sau khi thuê. API có tổng hợp số lượng/điểm trung bình; chưa có dashboard analytics funnel tự động.
7. Với giao dịch thử, dùng tài khoản và dữ liệu thử riêng. Không đánh dấu thu cọc/thanh toán thật nếu chưa thực nhận tiền. Nếu giao dịch thật, phải xác nhận rõ với hai bên trước khi tạo hợp đồng.
8. Dừng khi có lỗi lộ dữ liệu, ghi trùng hợp đồng/tiền, lịch sai múi giờ hoặc không thể gửi chứng từ. Tắt `RENTAL_PILOT_AREA`, giữ dữ liệu phục vụ đối soát, xử lý lỗi rồi mới mở lại.

## Kiểm chứng

Kết quả chạy ngày 23/10/2026:

| Kiểm tra | Kết quả |
| --- | --- |
| `flutter analyze` | Không có issue |
| Toàn bộ Flutter tests | 199 passed |
| Regression mới với `TZ=Asia/Ho_Chi_Minh` | 17 passed |
| iOS Simulator build từ `lib/main.dart` | Thành công |
| Prisma validate và NestJS build | Thành công |
| Backend unit tests | 164 passed, 7 skipped theo cấu hình sẵn có |
| E2E housing mới | 11/11 passed, gồm invoice → upload → duyệt chứng từ → bảo trì/bình luận sau khi tạo hợp đồng |
| Toàn bộ backend E2E | 52 passed, 2 failed ngoài luồng mới, chi tiết bên dưới |

Ảnh QA với dữ liệu minh họa: `docs/qa/housing-journey/iphone.png`, `docs/qa/housing-journey/ipad.png`.

- Flutter analyzer và toàn bộ Flutter tests được chạy lại sau tích hợp.
- Backend build, unit tests và toàn bộ E2E được chạy trên database test riêng; không dùng database hiện tại của người dùng.
- E2E mới bao phủ lưu yêu thích theo tài khoản, tin hết phòng, validation thời gian/timezone/phân trang, phân quyền, trùng lịch, stale version, cancellation, thông báo/đánh dấu đã đọc, tạo hợp đồng đồng thời, rollback, ledger cọc và feedback pilot.
- UI được build/kiểm tra trên iPhone và iPad Simulator bằng dữ liệu minh họa ghi rõ TIN MẪU; không phải bằng chứng thử nghiệm với người dùng thật. Widget tests kiểm tra cỡ chữ lớn và trạng thái lỗi/đổi tài khoản.
- Hai lỗi E2E ngoài luồng mới cần theo dõi riêng: `lease-billing-dashboard.e2e-spec.ts` tạo hóa đơn tháng 07/2026 nhưng kiểm tra `currentMonth` tại tháng 10/2026; `tenant-portal-priority.e2e-spec.ts` kỳ vọng tổng 3.650.000 nhưng API hiện trả 3.670.000. Không sửa công thức tiền hoặc expectation ngoài phạm vi để làm xanh test.
- Chưa kiểm thử push/email, chữ ký điện tử, thiết bị thật hoặc thực địa. Các chức năng này không được tuyên bố là đã triển khai.
