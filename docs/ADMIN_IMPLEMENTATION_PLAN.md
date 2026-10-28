# Kế hoạch triển khai Admin Console

Ngày rà soát: 24/10/2026.

## 1. Mục tiêu và phạm vi

Admin là người vận hành nền tảng: quản lý truy cập, kiểm duyệt, xử lý phản ánh, hỗ trợ người dùng và theo dõi sức khỏe hệ thống. Admin không thay thế chủ trọ trong nghiệp vụ thu tiền, sửa hợp đồng hay quyết toán cọc.

Kế hoạch này dựa trên việc đọc source Flutter tại `/Users/hoang/Rental_room_management` và backend NestJS tại `backend`. Đây là đánh giá tĩnh, không phải xác nhận các chức năng đã chạy đúng trên production. Không thay đổi source chức năng, database hoặc cấu hình triển khai khi lập kế hoạch.

Ký hiệu ưu tiên:

- P0: nền tảng an toàn, cần trước khi mở rộng quyền hoặc vận hành nhiều admin.
- P1: chức năng cần cho một bản admin vận hành thực tế.
- P2: mở rộng sau khi bản đầu ổn định và có nhu cầu đã xác nhận.

## 2. Hiện trạng đã kiểm tra

| Nhóm | Source hiện có | Phần còn thiếu hoặc cần hoàn thiện |
| --- | --- | --- |
| Đăng nhập và điều hướng | Role `admin`, bootstrap CLI, route `/admin`, chặn admin đi vào luồng landlord/tenant | Chưa có phân quyền chức năng riêng cho admin, quản trị tài khoản admin, MFA và quản trị phiên trên UI |
| Tổng quan | Tổng landlord active/inactive, khu trọ, phòng, tenant, hợp đồng active; danh sách mới nhất | Chưa có số việc chờ xử lý, quá hạn, xu hướng theo kỳ, cảnh báo vận hành |
| Chủ trọ | Danh sách, tìm kiếm, lọc active/inactive, tạo, sửa tên/số điện thoại, khóa/mở | Chưa có phân trang, lý do/hồ sơ xử lý, lịch sử hỗ trợ, quy trình reset và thu hồi phiên từ admin |
| Khu trọ | Danh sách, tìm kiếm, lọc landlord, tạo, sửa, xem danh sách phòng/trạng thái | Chưa có phân trang, lọc archived trong contract admin hiện tại, tra cứu tenant/lease/invoice dành riêng cho hỗ trợ |
| Tin đăng | Admin duyệt/từ chối/ẩn tin, xác minh chủ trọ và khảo sát phòng | Cần mở rộng hàng đợi, người phụ trách, ưu tiên, SLA và khả năng truy vết hồ sơ xử lý |
| Báo cáo tin | API và màn hình xem báo cáo, đánh dấu xử lý/bỏ qua kèm ghi chú | Chưa có điều phối xử lý, lọc nâng cao trên UI, hồ sơ bằng chứng và liên kết chế tài tài khoản |
| Đánh giá sau thuê | Duyệt/từ chối/ẩn đánh giá và phản hồi; phân trang, lọc; version và khóa bản ghi | Cần điều phối hàng đợi, khiếu nại quyết định và thống kê thời gian xử lý; không xây lại workflow kiểm duyệt |
| Trường/cơ sở | API và UI quản lý campus, bật/tắt, thông tin vị trí, nhãn demo | Cần kiểm tra chất lượng dữ liệu và audit cho thao tác danh mục theo chính sách admin |
| Phản hồi pilot | Có endpoint admin đọc phản hồi và màn hình liên quan | Chưa có support ticket hoàn chỉnh: người phụ trách, phản hồi hai chiều, mức ưu tiên và SLA |
| Audit | Đã có bảng `AuditLog`; listing/review ghi audit; API xem audit hiện giới hạn landlord/staff | Chưa có console audit toàn nền tảng; các mutation trong `AdminService` chưa ghi audit |
| Báo cáo và thanh toán | Có báo cáo tháng landlord/staff; có payment event và reconcile theo scope landlord/staff | Chưa có báo cáo nền tảng và màn chẩn đoán thanh toán admin; không đồng nghĩa cần cấp admin quyền sửa tiền |
| Kiểm thử | Có Flutter AdminApi contract test, auth routing test và backend admin E2E | Cần thêm ma trận quyền admin, widget test admin, audit, bảo mật dữ liệu, concurrency và quy trình hỗ trợ |

Điểm cần sửa trong tài liệu sau khi triển khai: README/checklist có một số mô tả baseline cũ; ưu tiên source và tài liệu tính năng mới khi xác định chức năng đã tồn tại.

## 3. Nguyên tắc thiết kế bắt buộc

1. Tách quyền nền tảng khỏi quyền của nhân viên chủ trọ. Không dùng `StaffProfile` của landlord để đại diện nhân sự admin.
2. Giữ các endpoint nghiệp vụ landlord theo scope hiện tại. Tạo API `/admin/...` có DTO giới hạn dữ liệu thay vì thêm `ADMIN` vào mọi controller.
3. Đọc thông tin để hỗ trợ khác với quyền sửa dữ liệu. MVP chỉ đọc tenant/lease/invoice; không sửa payment, duyệt chứng từ, hoàn cọc, chuyển chủ sở hữu hoặc xóa dữ liệu tài chính.
4. Không xóa cứng tài khoản có lịch sử; không cho chỉnh/xóa audit qua Admin Console.
5. Mọi thao tác đặc quyền phải kiểm tra quyền ở backend, có lý do khi cần và có audit. Ẩn nút ở Flutter không phải biện pháp bảo mật.
6. Thao tác đặc quyền quan trọng và audit phải commit trong cùng transaction; không dựa vào `recordSafe()` nuốt lỗi audit cho các thao tác này.
7. Che thông tin cá nhân mặc định; quyền xem chi tiết phải riêng, có mục đích hỗ trợ, được ghi nhận và hết hiệu lực khi thu hồi quyền.
8. Tận dụng `sessionVersion`, refresh-token revocation, cơ chế version/HTTP 409 và workflow kiểm duyệt đang có.
9. Tất cả danh sách mới phải có phân trang phía server, giới hạn page size, thứ tự ổn định và truy vấn không tải toàn bộ quan hệ.
10. Migration cộng thêm; thử nghiệm bằng database riêng, không reset hoặc seed vào database đang dùng.

## 4. Nhóm chức năng và backlog chi tiết

### ADM-01 — Phân quyền chức năng cho admin [P0]

**Mục đích:** tránh mọi admin đều có thể khóa tài khoản, xem dữ liệu nhạy cảm hoặc cấp quyền cho nhau.

**Công việc:**

- Định nghĩa các preset: `super_admin`, `support`, `moderator`, `analyst`. Đây là đề xuất, không phải role đã có.
- Giữ `UserRole.ADMIN` để nhận diện nhân sự nền tảng; thêm hồ sơ/quyền admin độc lập, không cần thêm role vào mọi luồng tenant/landlord.
- Định nghĩa quyền theo hành động: `admin.accounts.view`, `admin.accounts.suspend`, `admin.sessions.revoke`, `admin.support.read`, `admin.pii.reveal`, `admin.listings.moderate`, `admin.reviews.moderate`, `admin.audit.view`, `admin.analytics.view`, `admin.exports.create`, `admin.settings.manage`, `admin.admins.manage`.
- Bổ sung guard/decorator admin với mặc định từ chối. Guard hiện tại chỉ kiểm tra permission cho `STAFF`, không được giả định tự áp cho admin.
- Giới hạn đặc biệt cho thao tác cấp quyền, khóa admin khác và thay đổi cấu hình; không cho tự nâng quyền, tự khóa tài khoản hoặc làm mất super admin hoạt động cuối cùng.
- Backfill tài khoản admin hiện có theo danh sách bootstrap được xác nhận; admin chưa có hồ sơ không tự nhận toàn quyền.
- Quyền lấy từ nguồn hiện hành khi request; thay đổi quyền/khóa tài khoản làm mất hiệu lực phiên theo chính sách.

**Dữ liệu/API đề xuất:** `AdminProfile`, `AdminInvite`; `GET /admin/me/capabilities`, `GET /admin/admins`, `POST /admin/admin-invites`, `PATCH /admin/admins/:id`, `POST /admin/admins/:id/revoke-sessions`. Invite chỉ dùng một lần, hết hạn, lưu hash token; có endpoint kích hoạt chuyên biệt nếu sử dụng invite.

**Nghiệm thu:** moderator không đọc invoice/PII hoặc khóa người dùng; support không duyệt tin; analyst không mutation; gọi API trực tiếp vẫn bị chặn; thay đổi quyền có hiệu lực ở request kế tiếp; kiểm thử đồng thời không vô hiệu hóa được tất cả super admin.

### ADM-02 — Nhật ký admin và truy vết an ninh [P0]

**Mục đích:** biết ai đã làm gì, cho đối tượng nào và vì sao.

**Công việc:**

- Mở API audit dành riêng cho admin, tận dụng `AuditLog` hiện có.
- Lọc theo khoảng ngày, actor, action, resource, landlord, request ID; phân trang có thứ tự `(createdAt, id)`.
- Ghi đủ create/update landlord/property, khóa/mở tài khoản, thu hồi phiên, xem PII, cấp quyền, kiểm duyệt, export và sửa cấu hình.
- Ghi thay đổi trước/sau theo allowlist, mã lý do, support ticket liên quan và correlation ID. Không lưu password/token/secret, nội dung giấy tờ hoặc bản sao dữ liệu cá nhân không cần thiết.
- Bổ sung ngữ cảnh người thực hiện cho các mutation admin hiện chưa nhận `CurrentUser`.
- Định nghĩa chính sách lưu trữ, truy cập và lưu archive; log ứng dụng và lịch sử nghiệp vụ là hai mục đích khác nhau.

**Dữ liệu/API đề xuất:** bổ sung trường phù hợp cho `AuditLog` hoặc metadata có schema; `GET /admin/audit-logs`, `GET /admin/audit-logs/:id`. Export audit chỉ thêm khi có kiểm soát export của ADM-11.

**Nghiệm thu:** mỗi mutation nhạy cảm có đúng audit gắn transaction; không có API sửa/xóa log; metadata đã lọc bí mật; audit toàn nền tảng không làm rò dữ liệu vào API landlord.

### ADM-03 — Tài khoản chủ trọ, tenant và staff [P1]

**Mục đích:** tra cứu và xử lý vi phạm tài khoản ở phạm vi nền tảng.

**Công việc:**

- Nâng cấp danh sách landlord hiện có: phân trang, sắp xếp, lọc ngày tạo/trạng thái và hiển thị quan hệ khu trọ/phòng.
- Thêm danh sách tài khoản tenant/staff; phân biệt hồ sơ tenant nghiệp vụ chưa có tài khoản và tenant/seeker có tài khoản nhưng chưa có hợp đồng. Không gộp chúng bằng email.
- Hiển thị phạm vi dữ liệu và chủ trọ liên quan; không cho admin sửa permissions nghiệp vụ staff thay landlord trong MVP.
- Bổ sung khóa/mở có lý do, ghi chú nội bộ, mã hồ sơ hỗ trợ và lịch sử thay đổi.
- Thu hồi tất cả phiên; tăng `sessionVersion` và revoke refresh token trong transaction. Kiểm tra tình huống khóa rồi mở lại để token cũ không tự hoạt động trở lại.
- Chốt và triển khai tác động khi khóa landlord: quyền của staff liên quan, truy cập tenant vào hóa đơn/hợp đồng, tin công khai và công việc tự động. Không cascade khóa tenant hoặc xóa hợp đồng một cách mặc định.
- Reset mật khẩu theo luồng người dùng tự đặt lại; admin không xem hoặc gửi lại mật khẩu. Dùng hạ tầng ADM-04.
- Việc tạo landlord bằng mật khẩu hiện có cần đổi dần sang invite/đặt mật khẩu một lần; nếu giữ cho local phải tách khỏi quy trình production.

**Dữ liệu/API đề xuất:** lịch sử `AccountRestriction`; mở rộng DTO status có reason/version; `GET /admin/accounts`, `GET /admin/accounts/:id`, `POST /admin/accounts/:id/suspend`, `POST /admin/accounts/:id/restore`, `POST /admin/accounts/:id/revoke-sessions`.

**Nghiệm thu:** không mất lease/invoice; mọi trạng thái và phiên cập nhật nhất quán; support chỉ thấy trường được cấp quyền; không thể khóa admin qua endpoint tài khoản khách hàng; policy tài khoản phụ thuộc có E2E riêng.

### ADM-04 — Bảo mật tài khoản admin và khôi phục truy cập [P0/P1]

**Công việc:**

- Bắt buộc MFA với admin trước khi bật chức năng đặc quyền trên production; đề xuất TOTP kèm recovery code một lần.
- Mã hóa bí mật TOTP phía server, hash recovery code; reset MFA cần quy trình xác minh và audit, không cho bỏ qua bằng một nút support.
- Step-up authentication cho cấp quyền, khóa admin, thay đổi cấu hình nhạy cảm và export có PII.
- Thiết kế thử thách MFA ngắn hạn và refresh/session sao cho token đăng nhập chưa hoàn tất MFA không gọi được API admin.
- Giới hạn thử đăng nhập/MFA/reset, tránh account enumeration, đặt thời hạn token và thu hồi phiên sau đổi mật khẩu/reset.
- Quên mật khẩu dùng token ngẫu nhiên lưu hash, một lần, hết hạn; tích hợp kênh gửi thực trước khi công bố hoàn tất. Không log token hoặc đưa token vào response production.
- Hiển thị/thu hồi phiên nếu có đủ metadata; thiết bị/IP chỉ là dữ liệu hỗ trợ, không xem user-agent là định danh thiết bị tin cậy.

**Dữ liệu/API đề xuất:** MFA enrollment/challenge, recovery-code hash, password-reset token; metadata phiên tối thiểu. Thiết kế dưới `/auth/...` và `/admin/me/...` theo loại hành động, không sửa endpoint change-password hiện có khi không cần.

**Nghiệm thu:** không bypass MFA qua refresh/deep link; replay token/recovery code bị chặn; reset không tiết lộ tài khoản tồn tại; phải có phương án khôi phục super admin khi mất thiết bị.

### ADM-05 — Hàng đợi kiểm duyệt thống nhất [P1]

**Mục đích:** phát triển trên kiểm duyệt tin, báo cáo và đánh giá đã có, không viết một hệ thống kiểm duyệt mới song song.

**Công việc:**

- Tạo trang công việc với tab tin chờ duyệt, báo cáo tin, đánh giá và phản hồi chủ trọ.
- Bổ sung badge số chờ/quá hạn, lọc thời gian/trạng thái, tìm theo mã tin/chủ trọ, ưu tiên và người phụ trách.
- Xem đủ nội dung và lịch sử quyết định; liên kết từ báo cáo sang tin nhưng không mở công khai dữ liệu reporter.
- Claim/unclaim, ghi chú nội bộ và deadline; giữ nguồn trạng thái nội dung ở các bảng listing/review hiện có.
- Mã lý do chuẩn cho duyệt/từ chối/ẩn; thông báo cho người gửi khi quyết định thay đổi theo chính sách được duyệt.
- Khiếu nại quyết định là hồ sơ có liên kết tới quyết định cũ, không tự ghi đè trạng thái nội dung.
- Tiếp tục dùng version/transaction hiện có, thêm kiểm tra claim/assignment khi cần; xung đột trả 409 và yêu cầu tải lại.
- Chưa làm bulk approve ở MVP; ưu tiên xem xét từng nội dung có bằng chứng.

**Dữ liệu/API đề xuất:** `ModerationWorkItem` chỉ lưu điều phối, tham chiếu đối tượng và trạng thái hồ sơ; read model `/admin/moderation/queue`, API assignment; tái sử dụng endpoint review/moderate hiện có.

**Nghiệm thu:** hai admin không ghi đè quyết định; queue không có trạng thái công khai riêng lệch với listing/review; thay đổi quyền giữa lúc mở form và gửi bị backend chặn; quyết định và audit nguyên tử.

### ADM-06 — Trung tâm hỗ trợ và khiếu nại [P1]

**Công việc:**

- Người dùng gửi yêu cầu theo nhóm: tài khoản, tin đăng, thuê phòng, hóa đơn/thanh toán, phản ánh khác.
- Ticket có người yêu cầu, đối tượng liên quan, ưu tiên, người phụ trách, thời hạn và trạng thái `OPEN -> IN_PROGRESS -> WAITING_USER -> RESOLVED -> CLOSED`; quy định rõ mở lại.
- Luồng phản hồi hai chiều và ghi chú nội bộ là hai loại riêng. Không trả internal note trong API người dùng.
- Tận dụng upload riêng tư nhưng bổ sung authorization theo ticket; không đính kèm file dựa vào URL bất kỳ hoặc bỏ kiểm tra vì actor là admin.
- Liên kết phản hồi pilot cũ với ticket khi cần; không tự chuyển mọi phản hồi thành ticket nếu chưa có chính sách.
- Thông báo trong app khi có phản hồi/thay đổi trạng thái, có chống trùng và deep link.
- Theo dõi first response/resolution time; quy ước rõ SLA khi `WAITING_USER`. Chốt giờ làm việc trước khi cam kết SLA theo giờ.

**Dữ liệu/API đề xuất:** `SupportTicket`, `SupportMessage`, `SupportAttachment`, lịch sử trạng thái/assignment; `/support/tickets` theo account ownership và `/admin/support-tickets` theo quyền admin.

**Nghiệm thu:** người dùng chỉ đọc ticket của mình; admin không đủ quyền không thấy file/PII; ghi chú nội bộ không lọt ra notification; gửi lặp không tạo ticket/message trùng khi client retry.

### ADM-07 — Tra cứu dữ liệu hỗ trợ chỉ đọc [P1]

**Công việc:**

- Từ account/ticket đi tới khu trọ, phòng, tenant, lease, invoice và sự kiện thanh toán liên quan.
- Tìm theo ID/mã nghiệp vụ và phạm vi hỗ trợ cụ thể; tránh một ô tìm kiếm trả toàn bộ dữ liệu nhạy cảm.
- DTO theo allowlist; che email/số điện thoại, không trả CCCD, tài khoản ngân hàng hoặc file gốc trong kết quả tổng quát.
- Xem thêm PII cần quyền riêng, lý do/ticket, thời hạn ngắn và audit; không cache lâu thông tin đã reveal.
- Với tài chính chỉ hiển thị trạng thái, tổng hợp và dòng thời gian; không tạo/sửa/xóa payment, duyệt proof hoặc refund từ admin.
- Thêm read audit cho tra cứu nhạy cảm, rate limit và giới hạn export.

**API đề xuất:** `GET /admin/support-context?...`, `GET /admin/rooms/:id`, `GET /admin/tenants/:id`, `GET /admin/leases/:id`, `GET /admin/invoices/:id`; quyền reveal dùng endpoint/action riêng, không để client tự bật một boolean để bỏ masking.

**Nghiệm thu:** admin không thể dùng API landlord để vượt hạn chế; direct ID, private download và refresh sau thu hồi quyền đều bị kiểm soát; không có dữ liệu của landlord khác lẫn vào ngữ cảnh đang mở.

### ADM-08 — Dashboard vận hành [P1]

**Công việc:**

- Giữ số liệu nền tảng đang có; thêm tin/đánh giá chờ duyệt, báo cáo mở, ticket chưa xử lý và công việc quá hạn.
- Bộ lọc 7/30/90 ngày, kỳ so sánh và thời điểm cập nhật; biểu đồ người dùng mới, tin gửi/duyệt, tốc độ xử lý.
- Card dẫn tới danh sách có bộ lọc tương ứng. Không để số tổng và danh sách sử dụng định nghĩa khác nhau.
- Chốt rõ metric: tài khoản tenant khác hồ sơ tenant; thuê active khác phòng occupied; phòng bảo trì không tính là phòng trống sẵn sàng cho thuê.
- Tổng hợp theo database, index và cache có TTL; không tải toàn bộ phòng về Node/Flutter để đếm.
- Không gọi tiền thuê thu hộ là doanh thu nền tảng. Chỉ có metric doanh thu nền tảng khi đã có mô hình phí và dữ liệu tương ứng.

**API đề xuất:** mở rộng `/admin/overview` theo contract tương thích hoặc thêm `/admin/analytics/summary` và `/admin/analytics/trends`.

**Nghiệm thu:** chỉ số khớp dữ liệu mẫu và drill-down, timezone thống nhất theo kỳ; nêu rõ dữ liệu cache; không lộ PII trong response tổng hợp.

### ADM-09 — Giám sát tích hợp và công việc nền [P1/P2]

**Công việc:**

- Hiển thị trạng thái API/database/storage; lần chạy gần nhất, kết quả và số lỗi của billing automation, saved-search matching, thông báo và lịch gửi.
- Chẩn đoán payment webhook/event theo landlord/invoice bằng dữ liệu đã lọc; mặc định chỉ đọc. Payment-event/reconcile hiện có của landlord được giữ nguyên quyền.
- Phân biệt payment pending bình thường với lỗi chữ ký, duplicate, mismatch và provider failure; không lưu/hiện merchant secret, access token hoặc raw payload chứa PII.
- Ghi job run/heartbeat và thời gian xử lý; chỉ hiển thị metric khi có nguồn đo thật, không dùng số trạng thái mô phỏng.
- Retry/replay nếu triển khai ở P2 phải có idempotency, giới hạn số lần, backoff, lock và audit; không có nút chạy lại mọi job hoặc đổi payment thành paid.
- Liên kết correlation ID tới log vận hành; không biến UI admin thành công cụ chạy SQL/shell.

**Dữ liệu/API đề xuất:** `JobRun`, delivery/payment diagnostic view, `/admin/operations/health`, `/admin/operations/jobs`, `/admin/operations/payment-events`; retry endpoint chỉ mở sau khi có cơ chế chống tác động kép.

**Nghiệm thu:** provider lỗi phải xuất hiện đúng trạng thái; retry đồng thời không gửi trùng thông báo hoặc ghi nhận tiền hai lần; health response không tiết lộ cấu hình nội bộ.

### ADM-10 — Danh mục và cấu hình vận hành [P1/P2]

**Công việc:**

- Đưa campus management hiện có vào menu rõ ràng; lọc theo thành phố/active/demo, kiểm tra tọa độ, địa chỉ và nguồn xác minh.
- Chuẩn hóa mã lý do kiểm duyệt, nhóm ticket và giá trị SLA; cố định trong code trước nếu chưa có nhu cầu cấu hình động.
- Nếu cần runtime settings: schema có kiểu, validation, version, lịch sử và rollback cấu hình an toàn.
- Feature flag chỉ cho phép key được khai báo; rollout và tắt khẩn cấp phải có audit. Không mở editor JSON tùy ý cho cấu hình hệ thống.
- Merchant/JWT/database secrets tiếp tục quản lý ở môi trường/secret store, không đưa vào Admin Console.

**Nghiệm thu:** dữ liệu demo vẫn có nhãn; tắt campus có hành vi đã xác định với saved search; thay đổi cấu hình không ảnh hưởng ngoài phạm vi được duyệt.

### ADM-11 — Báo cáo và export nền tảng [P2]

**Công việc:**

- Báo cáo tăng trưởng account, nguồn cung phòng, funnel tin gửi/duyệt, vi phạm và hiệu suất hỗ trợ/kiểm duyệt.
- Lọc kỳ, khu vực và nhóm dữ liệu; xuất CSV trước, chưa cần Excel/PDF nếu không có yêu cầu.
- Export có quyền riêng, hạn mức dòng/thời gian, che PII, audit request/download và link tải riêng tư hết hạn.
- Dataset lớn xử lý qua job, không giữ request đồng bộ dài; áp dụng quyền lại khi tải kết quả.
- Chống CSV formula injection, quy ước timezone và cột dữ liệu; thống nhất định nghĩa metric với ADM-08.

**Nghiệm thu:** không export vượt quyền, không dùng link của người khác; thu hồi quyền ngăn tải file cũ; số liệu báo cáo khớp API tổng hợp và fixture.

### ADM-12 — Điều hướng và trải nghiệm admin [P1]

**Công việc:**

- Admin shell riêng, navigation theo capability; desktop/tablet dùng sidebar, mobile dùng drawer/menu phù hợp.
- Đề xuất nhóm menu: Tổng quan; Công việc kiểm duyệt; Tài khoản; Khu trọ; Hỗ trợ; Nhật ký; Vận hành; Danh mục; Báo cáo; Quản trị admin.
- Chuẩn hóa tiếng Việt thay các màn trộn Anh/Việt hiện tại; dùng thuật ngữ thống nhất: chủ trọ, khu trọ, phòng, tài khoản người thuê.
- Bảo toàn bộ lọc/trang khi quay lại; debounce tìm kiếm, hủy/loại kết quả request cũ và cảnh báo form chưa lưu.
- Loading, empty, lỗi, retry, 403, 404, 409, offline và expired session đều có trạng thái rõ ràng.
- Đổi tài khoản/logout/thu hồi quyền phải xóa cache admin, đóng hoặc vô hiệu hóa form cũ và private attachment link đã giữ ở UI.
- Xác nhận thao tác nguy hiểm phải nói rõ đối tượng, tác động và lý do; không chỉ hiển thị hộp thoại chung chung.

**Nghiệm thu:** route và nút khớp quyền backend; deep link không vượt quyền; không lộ dữ liệu account trước khi đổi tài khoản; màn chính sử dụng được trên mobile và desktop.

## 5. Lộ trình theo giai đoạn

Ước lượng là ngày công của một lập trình viên full-stack đã quen Flutter/NestJS, gồm kiểm thử theo ticket; không phải cam kết lịch giao. Chưa gồm chờ chốt nghiệp vụ, chờ kênh gửi email/MFA hoặc đánh giá an ninh độc lập. Dự trù thêm 20–30% cho tích hợp và vấn đề phát sinh.

| Giai đoạn | Nội dung | Phụ thuộc | Ước lượng |
| --- | --- | --- | --- |
| G0 — Chốt baseline | Ma trận quyền, policy khóa tài khoản, danh sách metric, contract phân trang, fixtures và baseline test | Không | 1–2 ngày |
| G1 — Nền tảng an toàn | ADM-01, ADM-02, phần MFA/thu hồi phiên của ADM-04; shell tối thiểu ADM-12 | G0 | 6–9 ngày |
| G2 — Tài khoản và dữ liệu | ADM-03, ADM-07; hoàn thiện reset/invite ADM-04 khi kênh gửi sẵn sàng; phân trang landlord/property | G1 | 5–8 ngày |
| G3 — Kiểm duyệt và dashboard | ADM-05, ADM-08; điều hướng tới campus/report/review/pilot đã có | G1; nhận số liệu tài khoản từ G2 | 5–7 ngày |
| G4 — Hỗ trợ | ADM-06, quyền file theo ticket, thông báo, SLA và hồ sơ khiếu nại | G1, G2; liên kết G3 nếu là khiếu nại kiểm duyệt | 6–9 ngày |
| G5 — Vận hành và chất lượng | Phần read-only ADM-09, danh mục ADM-10, hardening ADM-12, kiểm thử tích hợp các luồng admin | G1–G4 | 5–8 ngày |
| G6 — Mở rộng có kiểm soát | ADM-11, retry an toàn, settings/flag động, báo cáo nâng cao và tối ưu tải | G5, nhu cầu thực tế | 7–12 ngày |

Tổng dự kiến: 35–55 ngày công trước dự phòng. Có thể giảm scope nếu chỉ cần quản lý tài khoản và kiểm duyệt, nhưng không cắt quyền/audit để lấy tiến độ.

### Mốc bàn giao

- **Mốc A — Admin nền tảng/kiểm duyệt:** G0–G3, khoảng 17–26 ngày công trước dự phòng. Có quyền riêng, audit, MFA, quản lý tài khoản, tra cứu giới hạn, hàng đợi nội dung và dashboard. Nếu chưa có kênh gửi thật, reset/invite phải ẩn hoặc ghi rõ chưa khả dụng; không tuyên bố hoàn tất luồng đó.
- **Mốc B — Admin vận hành đầy đủ bản đầu:** G0–G5, khoảng 28–43 ngày công trước dự phòng. Có trung tâm hỗ trợ, file riêng tư theo ticket và giám sát chỉ đọc.
- **Mốc C — Mở rộng:** G6. Chỉ thêm export lớn, cấu hình động hoặc retry khi đã có nhu cầu và số liệu đo.

### Ticket triển khai đầu tiên

1. `ADM-BASE-01`: ghi ma trận quyền, phạm vi PII và tác động suspend landlord; xác nhận account tenant khác tenant record.
2. `ADM-SEC-01`: schema/backfill `AdminProfile`, guard capability và E2E phủ toàn bộ admin controller hiện có.
3. `ADM-AUD-01`: mở admin audit read API và transaction audit cho landlord/property mutations.
4. `ADM-SEC-02`: MFA challenge, recovery và session revocation; khóa rồi mở lại không tái sử dụng token cũ.
5. `ADM-LIST-01`: phân trang server landlord/property, DTO `data + meta`, aggregation thay nested includes không giới hạn; cập nhật Flutter/parser/test cùng bản.
6. `ADM-ACC-01`: account search/detail, suspend/restore có reason/version và kiểm tra dữ liệu phụ thuộc.
7. `ADM-UI-01`: shell theo capability, route guard, cache isolation và menu kết nối chức năng đã có.
8. `ADM-MOD-01`: queue summary, phân công, SLA và drill-down; giữ endpoint quyết định nội dung đang dùng.

## 6. Phạm vi thay đổi kỹ thuật

### Backend

- `src/admin/`: phát triển capability, account/admin management, support context và read models; chia service/controller theo trách nhiệm khi module lớn lên.
- `src/common/`: guard/decorator admin riêng; không làm thay đổi ngầm semantics permission của staff.
- `src/auth/`: MFA, reset/invite, session invalidation và capability/session payload khi cần.
- `src/audit/`: truy vấn admin, metadata allowlist và khả năng ghi trong transaction của nghiệp vụ.
- `src/listings/`, `src/reviews/`, `src/housing/`: tái sử dụng kiểm duyệt/campus/feedback; chỉ thêm quyền và điều phối còn thiếu.
- Module support/operations-admin riêng khi cần; reuse dịch vụ domain có policy phù hợp, không copy service landlord rồi bỏ ownership check.
- `prisma/schema.prisma` và migration cộng thêm; tạo index theo filter thực tế, backfill có thể kiểm tra và rollback ứng dụng an toàn.
- `test/e2e/admin*.e2e-spec.ts` và unit tests tương ứng; database test riêng.

### Flutter

- `lib/data/admin/`: tách API theo nhóm khi cần, thêm typed DTO và model phân trang; không làm parser hiện tại âm thầm bỏ `meta`.
- `lib/models/admin_models.dart`: capabilities, paged response và model mới; tách file theo chức năng thay vì đưa toàn bộ vào một file lớn.
- `lib/features/admin/`: shell, dashboard, accounts, audit, support, operations; tái sử dụng UI listing/review/campus hiện có.
- `lib/features/auth/auth_navigation.dart` và `lib/app/app.dart`: route guard và entry theo capability; xử lý chưa tải quyền, lỗi tải quyền và quyền bị thu hồi.
- Provider invalidation khi mutation/đổi account; không chia sẻ cache thông tin đặc quyền với landlord/tenant.
- `test/data/admin/`, `test/features/admin/`, auth routing và session-isolation tests.

Không tạo branch hoặc commit, không đổi backend source khi người dùng mới yêu cầu kế hoạch.

## 7. Ma trận quyền khởi điểm đề xuất

| Hành động | Super admin | Support | Moderator | Analyst |
| --- | --- | --- | --- | --- |
| Xem dashboard tổng hợp | Có | Theo phạm vi hỗ trợ | Theo phạm vi kiểm duyệt | Có |
| Đọc account cơ bản | Có | Có | Chỉ ngữ cảnh vi phạm | Không mặc định |
| Khóa/mở tài khoản khách hàng | Có + lý do | Chỉ khi được cấp bổ sung | Không | Không |
| Xem tenant/lease/invoice | Theo nhu cầu hỗ trợ | Chỉ đọc + mục đích hỗ trợ | Không | Không |
| Xem PII chi tiết | Quyền riêng + audit | Quyền riêng + audit | Không | Không |
| Duyệt tin/đánh giá | Có | Không mặc định | Có | Không |
| Xử lý ticket | Có | Có | Chỉ ticket kiểm duyệt được giao | Không |
| Xem audit toàn nền tảng | Có | Giới hạn hồ sơ nếu cần | Giới hạn quyết định được phép | Không mặc định |
| Quản trị admin/cấu hình | Có + step-up | Không | Không | Không |
| Export | Quyền riêng | Không mặc định | Không mặc định | Chỉ dữ liệu tổng hợp được duyệt |
| Sửa/xóa payment hoặc hoàn cọc | Không trong phạm vi kế hoạch | Không | Không | Không |

Preset là điểm bắt đầu. Phải chuyển mỗi hàng thành permission/policy cụ thể, không hardcode quyền bằng nhãn hiển thị của preset.

## 8. Kiểm thử và Definition of Done

Mỗi ticket phải đạt:

- API có DTO validation, quyền server-side, pagination/limit nếu có list, error code và contract đã thống nhất.
- Unit test cho policy/domain; E2E HTTP-level cho 401/403, direct ID, access revocation và transaction.
- Kiểm tra actor ADMIN không đủ capability, landlord/staff/tenant giả gọi endpoint admin và admin giả gọi endpoint landlord.
- Mutation quan trọng có reason, version hoặc lock/idempotency thích hợp và audit nguyên tử; kiểm tra gửi lặp và hai admin thao tác đồng thời.
- Masking PII, internal note, file URL và export được kiểm tra ở response thực, không chỉ test widget ẩn nút.
- Flutter có loading/empty/retry/error/conflict; widget test, route test, cache isolation và form đang mở khi đổi account.
- Chạy analyzer/test/build Flutter và backend unit/E2E trên database riêng; không chạy fixture vào dữ liệu làm việc.
- Manual flow với admin có quyền khác nhau trên mobile và desktop, backend thật; MFA/reset/upload/notification phải test end-to-end khi thuộc ticket.
- Migration/backfill và rollout có hướng dẫn; backup/restore được kiểm tra trước production. Không dùng admin console làm công cụ restore database.
- Theo dõi metric truy vấn/job thật, định nghĩa ngân sách latency sau baseline; chốt bộ dữ liệu tải đại diện trước khi đặt ngưỡng nghiệm thu hiệu năng.
- Cập nhật README/checklist/status theo kết quả đã xác minh, không đánh dấu xong chỉ vì đã có màn hình.

## 9. Các quyết định cần chốt trước khi code

1. Admin ưu tiên quản lý phần mềm nội bộ hay vận hành marketplace công khai? Kế hoạch mặc định phục vụ cả hai nhưng dùng chung nền tảng quyền/audit.
2. Ai được khóa landlord/tenant/staff; có cần duyệt hai người cho chế tài tài khoản hoặc quyền admin không?
3. Khóa landlord ảnh hưởng thế nào tới staff, tin công khai, automation và quyền tenant đọc dữ liệu đã có? Đề xuất bảo toàn truy cập đọc hóa đơn/hợp đồng của tenant khi không có lý do an ninh khác.
4. Support được xem trường PII nào, trong bao lâu, có yêu cầu ticket/đồng ý của người dùng không?
5. Kênh gửi reset/invite, cấu hình MFA và quy trình khôi phục super admin do ai vận hành?
6. Mục tiêu first response/resolution, giờ làm việc, thời gian lưu audit/ticket/export và phạm vi pilot?
7. Có thật sự cần thu phí nền tảng/gói thuê bao không? Nếu chưa xác nhận thì chưa thêm subscription/payment-plan admin.

Không cần chốt mọi chi tiết P2 để bắt đầu; phải chốt câu 2–5 trước khi cấp quyền đặc biệt hoặc mở dữ liệu hỗ trợ.

## 10. Chưa nên triển khai trong đợt đầu

- CRUD toàn quyền rooms/tenants/leases/invoices/payments cho admin.
- Đăng nhập giả danh landlord/tenant hoặc nút xem mọi file riêng tư.
- Xóa cứng account có dữ liệu, sửa/xóa audit, reset database từ UI.
- Chuyển chủ sở hữu khu trọ, vì cần xác định tác động tới lease, tenant, cọc, invoice và merchant/payment.
- Tự động hoàn tiền, tự động khóa theo số report hoặc AI tự duyệt/xóa nội dung.
- Gói thuê bao, coupon, doanh thu SaaS khi chưa có mô hình kinh doanh được xác nhận.
- Raw SQL/log/secret viewer, runtime setting editor không có schema, mass replay webhook/job.

## 11. Source đối chiếu

- Flutter admin: `lib/features/admin/`, `lib/data/admin/`, `lib/models/admin_models.dart`.
- Navigation: `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart`.
- Marketplace admin: `lib/features/listings/manage_listings_screen.dart`, `manage_reviews_screen.dart`, `listing_reports_screen.dart`, `campus_management_screen.dart`.
- Backend admin: `src/admin/admin.controller.ts`, `src/admin/admin.service.ts`, DTO query và status trong cùng module.
- Quyền và phiên: `src/common/roles.guard.ts`, `src/auth/jwt.strategy.ts`, `prisma/schema.prisma`.
- Audit: `src/audit/`; kiểm duyệt ghi audit trong `src/listings/listings.service.ts` và `src/reviews/reviews.service.ts`.
- Billing/report scope: `src/billing/online-payments.controller.ts`, `src/reports/reports.controller.ts`.
- Kiểm thử hiện có: Flutter `test/data/admin/admin_api_test.dart`, `test/features/auth/auth_navigation_test.dart`; backend `test/e2e/admin.e2e-spec.ts`.
- Tài liệu bổ sung: `ADMIN_SETUP.md`, `IMPLEMENTATION_ROADMAP.md`, `docs/reviews-2026-10-24.md`, `docs/security-discovery-2026-10-23.md`.
