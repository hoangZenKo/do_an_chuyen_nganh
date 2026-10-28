# Đặc tả Use Case AS IS đợt 1

Ngày 29/10/2026. Bản thay thế phần UC của báo cáo cũ; không phải xác nhận hoàn tất 164 UC.

## 1 Phạm vi sửa đổi và kết luận AS IS

Tài liệu này viết lại phần Use Case của hệ thống Quản lý nhà trọ dựa trên mã nguồn hiện có, không phải mô tả hệ thống tương lai. Đây là đợt 1: hoàn thành báo cáo phân tích hệ thống, catalog chức năng và đặc tả chi tiết nhóm tài khoản. Các nhóm nghiệp vụ còn lại mới ở mức catalog, chưa phải bộ đặc tả hoàn chỉnh để nghiệm thu toàn hệ thống.

| Nội dung | Phạm vi và trạng thái |
| --- | --- |
| Báo cáo đối chiếu | Bao_cao_Quan_ly_Nha_tro_V3_2026-10-28.docx; 131 mã UC cũ. Bản gốc không bị ghi đè. |
| Mã nguồn chuẩn phân tích | Snapshot working tree ngày 29/10/2026, gồm cả thay đổi chưa commit. Base commit 2d1ec6444ff8a84fb1de4487f4cc7514354076cc không đại diện toàn bộ snapshot. |
| Gói bằng chứng | 853 tệp trong source-snapshot.zip; SHA-256 từng tệp ở source-manifest.json; không lấy .env, credentials hoặc dữ liệu DB đang chạy. |
| Kết quả kiểm kê | 405 endpoint; 70 controller có route; 110 Prisma models; 30 enum. Đây là số lượng cấu trúc tĩnh, không phải 405 chức năng người dùng. |
| Catalog mới | 164 UC theo mục tiêu; 393 endpoint ánh xạ UC và 12 endpoint hỗ trợ/kỹ thuật. Ánh xạ route không tự chứng minh đầy đủ hành vi hay UI. |
| Đặc tả được kiểm tra chéo | 9 UC tài khoản theo A–J và 2 tiến trình hỗ trợ phiên. 155 UC còn lại cần đặc tả ở đợt tiếp theo; không tái sử dụng bảng cũ như đã xác nhận. |
| Kiểm thử thực thi | 31 backend tests trong 7 suites và 48 Flutter tests đạt. Tệp thuộc vùng kiểm thử đối chiếu hash trùng snapshot. Không chạy E2E DB hoặc thử giao dịch, email, storage thực. |

Phần UC của báo cáo cũ cần được thay bằng tài liệu này theo đúng mức hoàn thành. Sơ đồ Use Case, tuần tự và kết quả kiểm thử trong báo cáo cũ là tài liệu lịch sử; chưa được tái xác nhận toàn bộ ở đợt này. Không được coi việc giữ mã UC cũ là xác nhận nội dung mô tả cũ.

### 1.1 Quy ước bằng chứng

| Nhãn | Ý nghĩa sử dụng |
| --- | --- |
| Xác nhận | Đã đọc hành vi ở lớp liên quan và có nguồn định vị. Không đồng nghĩa đã kiểm thử tích hợp hoặc triển khai production. |
| Suy luận có căn cứ | Cách diễn giải từ cấu trúc hoặc nối dây triển khai; thiếu kiểm chứng để kết luận nghiệp vụ đầy đủ. |
| Chưa đủ bằng chứng | Chưa truy vết đủ lớp, chưa thấy UI/test hoặc chưa có cấu hình/runtime cần thiết. Không đồng nghĩa chức năng không tồn tại. |
| Một phần | Có phần triển khai nhưng mục tiêu rộng hơn chưa được đáp ứng hoặc đã có hạn chế xác nhận; phải chỉ rõ giới hạn. |
| Đề xuất | Không thuộc AS-IS và không được viết thành bước hiện có. |

Ký hiệu E là nguồn hành vi được định vị ở mục 7; R là endpoint trong Requirements Traceability Matrix đi kèm. Đường dẫn đều tính từ gốc repository và số dòng ứng với snapshot, không theo tệp đang tiếp tục chỉnh sửa. Khi backend không có controller/service tách riêng, bảng truy vết ghi đúng cấu trúc thực tế, không dựng thêm lớp giả.

### 1.2 Tổng quan nghiệp vụ và kiến trúc

Hệ thống kết hợp quản lý vận hành khu trọ của chủ trọ và nhân viên, cổng người thuê, hành trình khám phá phòng công khai và quản trị nền tảng. Người tìm phòng và người thuê có hợp đồng cùng dùng vai trò TENANT nhưng có dữ liệu và khả năng thực thi khác nhau. [E037] [E038] [E054]

| Lớp | Triển khai và trách nhiệm | Nguồn |
| --- | --- | --- |
| Ứng dụng | Flutter; Riverpod quản lý trạng thái; GoRouter điều hướng. API repositories tách khỏi màn hình; Dio gửi request và xử lý 401. | lib/app/app.dart; lib/features/auth/auth_providers.dart; lib/data; lib/core/network/api_client.dart |
| API | NestJS modular monolith, các module đăng ký trong AppModule; prefix /api/v1; DTO validation whitelist, forbidNonWhitelisted và transform. | [E057] [E058] |
| Nghiệp vụ | Controller nhận request và kiểm quyền; services xử lý transaction, kiểm trạng thái và phạm vi sở hữu. Không suy luật từ tên endpoint. | backend/src; analysis-index.json chứa lời gọi service từng route |
| Dữ liệu | Prisma/PostgreSQL; schema hiện có 110 models và 30 enum; migrations là bằng chứng tiến hóa schema, chưa chứng minh DB đang chạy áp đủ migrations. | backend/prisma/schema.prisma; backend/prisma/migrations |
| Định danh và bảo vệ | Access JWT, refresh rotation, AuthSession; role/admin permissions/staff permissions và interceptor phạm vi khu. | E tham chiếu tại mục 2; backend/src/common |
| Tác vụ nền và tích hợp | Có outbox/delivery/support workers, tệp riêng và thanh toán demo; trạng thái sẵn sàng phụ thuộc cấu hình. Không xác nhận kết nối nhà cung cấp thực từ source. | backend/src/delivery; backend/src/billing/online-payments.service.ts; backend/src/support |

Điểm nối chính: màn hình → provider/repository → Dio → controller/guard/interceptor → service → Prisma → PostgreSQL. Luồng background được enqueue qua bảng job/outbox; request thành công không mặc định đồng nghĩa email đã giao hoặc job đã hoàn tất. [E052] [E056] [E057] [E019]

### 1.3 Các đối tượng dữ liệu chính

| Nhóm | Đối tượng và quan hệ thực tế |
| --- | --- |
| Danh tính | User giữ role, isActive, passwordHash, sessionVersion; AuthSession/RefreshToken thuộc User; AdminProfile hoặc StaffProfile mở rộng danh tính. Tenant có thể chưa có userId. |
| Phân quyền nhân viên | StaffProfile thuộc landlord; StaffPropertyScope gắn nhân viên với khu; lời mời STAFF chứa preset, permissions và propertyIds. |
| Tài sản thuê | Property → Room; Tenant thuộc landlord; Lease nối Tenant và Room. Nhiều ràng buộc trạng thái nằm trong service, không phải chỉ quan hệ schema. |
| Tài chính | Invoice/InvoiceLineItem lưu nợ và snapshot dòng; Payment là giao dịch gắn hóa đơn; receipt, allocation, proof, reversal và refund là những đối tượng/luồng khác nhau. |
| Vận hành | Chỉ số điện nước, maintenance, turnover, settlement, lifecycle request và tác vụ nhắc nhở; trạng thái duyệt không đồng nghĩa đã thực thi chuyển/đóng hợp đồng. |
| Khám phá | Listing thuộc phòng; slots/viewings hỗ trợ xem phòng; favorites, saved searches, reviews, moderation/report/appeal lưu hành trình riêng. |
| Nền tảng | Support ticket/messages/attachments; audit; plans/subscriptions; feature flags và dữ liệu governance. Chưa trình bày schema đầy đủ như đặc tả UC đã nghiệm thu. |

Nguồn đối tượng: backend/prisma/schema.prisma; phần định nghĩa đầy đủ trong evidence database của đợt kiểm kê trước chỉ dùng tham khảo, nguồn chuẩn vẫn là schema thuộc source-snapshot.zip. Ma trận route ở đợt này không đại diện ERD toàn hệ thống.

### 1.4 Ranh giới tích hợp và xử lý lỗi

Validation toàn cục loại trường ngoài DTO thay vì âm thầm lưu. ApiErrorFilter chuẩn hóa lỗi máy chủ từ 500 thành INTERNAL_SERVER_ERROR và gắn requestId; lỗi validation dạng mảng thành VALIDATION_ERROR. Không biến mọi lỗi kỹ thuật giả định thành nhánh nghiệp vụ. Bảo đảm rollback chỉ ghi khi thao tác thực sự nằm trong transaction. [E057] [E059] [E007] [E018]

## 2 Ma trận tác nhân và quyền hiệu lực

| Tác nhân | Xác thực và dữ liệu | Quyền và giới hạn AS IS |
| --- | --- | --- |
| Khách | Không JWT; API công khai | Xem tin/cơ sở trường/đánh giá công khai; đăng ký, đăng nhập, forgot/redeem, accept invite. Không có quyền quản lý khu hay tự chọn role ADMIN. |
| Người tìm phòng | User.role TENANT; chưa chắc có Tenant/Lease | Có API hành trình tìm phòng; quyền vào cổng người thuê phụ thuộc liên kết và dữ liệu, không phải role TENANT đơn lẻ. |
| Người thuê | User TENANT gắn Tenant theo dữ liệu | Chỉ dữ liệu cổng thuê theo identity liên kết; không được coi có quyền sửa dữ liệu thuê của Tenant khác. |
| Chủ trọ | User LANDLORD active | Dữ liệu theo landlordId. Quản lý tài sản/người thuê/tài chính/vận hành thuộc mình; không suy quyền ADMIN từ quyền sở hữu khu. |
| Nhân viên | User STAFF, profile active, landlord active | Cần permission và phạm vi khu, đồng thời controller/action phải được interceptor cho phép. RequirePermissions nhiều mã áp ANY, không phải ALL. |
| Quản trị viên | User ADMIN, AdminProfile/permissions và MFA theo guard | AdminPermissions yêu cầu ALL quyền được liệt kê; thiếu required metadata bị từ chối theo cơ chế admin-access. Không đồng nghĩa mọi ADMIN có toàn bộ quyền. |
| Worker nội bộ | Không phải vai trò User thứ năm | Thực thi job/delivery/outbox theo module và cấu hình; không mô hình hóa worker thành quyền truy cập UI. |

Nguồn xác thực và quyền: [E033] [E034] [E036] [E035] [E037]. Ma trận này là mô tả bộ lọc quyền thực tế, không chỉ sao chép decorator ở controller.

### 2.1 Giao của các bộ lọc quyền nhân viên

Quyền hiệu lực STAFF = trạng thái danh tính hợp lệ ∩ role được cho phép ∩ permission phù hợp ∩ controller/action trong allowlist ∩ dữ liệu nằm trong khu được cấp. Không khẳng định quyền thực thi chỉ từ @Roles(STAFF). [E033] [E034] [E035]

| Phạm vi | Được xác nhận từ interceptor |
| --- | --- |
| Allowlist controller | PropertiesController, PropertyRoomsController, RoomsController, TenantsController, LeasesController, RoomLeasesController, TenantLeasesController, BillingController, ExpensesController, MaintenanceController, ReportsController, DashboardController, TenantLifecycleController. |
| Ngoại lệ Auth và Staff | AuthController được đi qua. StaffController chỉ list và presets; cập nhật quyền, tạo invite không được mở cho STAFF chỉ vì decorator có staff.manage. |
| Chặn action cụ thể | PropertiesController.create; MaintenanceController.escalate; BillingController.outboxEvents và retryOutbox. |
| Controller ngoài allowlist | P1OperationsController, AnnouncementsController, NotificationsController, OperationsController, AuditController, TenantInvitesController và support controllers không được STAFF truy cập theo interceptor hiện có. |
| Nhắc phí và dữ liệu Tenant | Reminder cần propertyId cụ thể thuộc scope. tenantScope yêu cầu có lease trong khu được cấp và không có lease/invoice ngoài khu; Tenant mới chưa lease có thể không còn hiện ở truy vấn scoped. |

Các UC ngoài nhóm SYS chưa có ma trận endpoint–permission hoàn chỉnh bằng hành vi UI; thông tin Roles/AdminPermissions/RequirePermissions thô của từng route được lưu trong Requirements_Traceability_Matrix.tsv, nhưng không thay thế kết luận hiệu lực ở mục này.

## 3 Phân rã chức năng và catalog Use Case

| Module | Mục tiêu nghiệp vụ | Số UC | Mức hoàn thành |
| --- | --- | --- | --- |
| Tài khoản và phiên làm việc | Đăng ký, đăng nhập, quản lý phiên và khôi phục truy cập | 9 | A–J: 9 UC |
| Khám phá và tìm thuê phòng | Khám phá, đăng tin, lịch xem, đánh giá và kiểm duyệt cá nhân | 18 | Catalog; chưa đặc tả A–J |
| Khu trọ và phòng | Khu trọ, phòng, tiện ích, giá và trạng thái tài sản | 16 | Catalog; chưa đặc tả A–J |
| Người thuê và hợp đồng | Hồ sơ người thuê, hợp đồng, thanh lý và vòng đời thuê | 21 | Catalog; chưa đặc tả A–J |
| Hóa đơn và sổ thu chi | Hóa đơn, công nợ, chứng từ, thu tiền, phân bổ và báo cáo | 28 | Catalog; chưa đặc tả A–J |
| Vận hành nhà trọ | Bảo trì, điện nước, thông báo và vận hành khác | 9 | Catalog; chưa đặc tả A–J |
| Cổng người thuê | Tra cứu và tương tác của người thuê theo danh tính | 13 | Catalog; chưa đặc tả A–J |
| Quản trị nền tảng | Tài khoản quản trị, kiểm duyệt, registry, tài chính và governance | 36 | Catalog; chưa đặc tả A–J |
| Hỗ trợ và giám sát | Ticket, trao đổi, tệp, phân công và SLA hỗ trợ | 11 | Catalog; chưa đặc tả A–J |
| Nhân viên của chủ trọ | Mời nhân viên, cấp scope và mô phỏng quyền | 3 | Catalog; chưa đặc tả A–J |

Trong catalog: XN = đã xác nhận nhóm tài khoản qua các lớp; CB = có route/service wiring nhưng chưa đủ đối chiếu chi tiết ở đợt này; MP = một phần với giới hạn đã phát hiện (thanh toán demo). CB không được dùng làm bằng chứng rằng mọi bước của bản cũ là đúng. Mô tả ngắn chính là mục tiêu và giới hạn ở từng dòng; API thể hiện định danh controller.method để tra route chính xác trong ma trận R.

### 3.1 Tài khoản và phiên làm việc

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-SYS-01<br>Đăng ký tài khoản chủ trọ | Khách<br>Tạo User LANDLORD và nhận phiên đăng nhập | AuthController.register [R0068] | XN |
| UC-SYS-02<br>Đăng ký tài khoản tìm phòng | Khách<br>Tạo User TENANT chưa tự sinh Tenant hay Lease | AuthController.registerSeeker [R0069] | XN |
| UC-SYS-03<br>Đăng nhập | Người có tài khoản<br>Nhận phiên đúng danh tính và điều hướng theo vai trò | AuthController.login [R0070] | XN |
| UC-SYS-05.1<br>Đăng xuất phiên hiện tại | Người đã đăng nhập<br>Thu hồi phiên gắn refresh token và rời phiên cục bộ | AuthController.logout [R0072] | XN |
| UC-SYS-05.2<br>Xem và thu hồi các phiên của mình | Người đã đăng nhập<br>Kiểm soát thiết bị đang truy cập tài khoản | AuthController.sessions [R0074]<br>AuthController.revokeSession [R0075]<br>AuthController.revokeOtherSessions [R0076] | XN |
| UC-SYS-06<br>Khôi phục mật khẩu bằng liên kết một lần | Người có tài khoản<br>Đặt lại mật khẩu qua token giao nhận riêng | AccountAccessController.forgot [R0062]<br>AccountAccessController.redeem [R0063] | XN |
| UC-SYS-07<br>Đổi mật khẩu khi đang đăng nhập | Người đã đăng nhập<br>Thay mật khẩu sau khi xác minh mật khẩu hiện tại | AuthController.changePassword [R0077] | XN |
| UC-SYS-08<br>Kích hoạt tài khoản người thuê từ lời mời | Người nhận lời mời<br>Tạo User TENANT gắn Tenant đã được mời | TenantInvitesController.accept [R0395] | XN |
| UC-SYS-09<br>Kích hoạt tài khoản nhân viên từ lời mời | Người nhận lời mời<br>Nhận tài khoản STAFF và phạm vi đã được chủ trọ cấp | StaffController.accept [R0328] | XN |

UC-SYS-01: Tạo User và cấp phiên là hai đơn vị ghi khác nhau; lỗi cấp phiên sau khi tạo có thể để lại User.

UC-SYS-09: Bổ sung vì bản V3 chưa tách mục tiêu kích hoạt STAFF.

### 3.2 Khám phá và tìm thuê phòng

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-DIS-01<br>Tìm và lọc tin phòng công khai | Khách hoặc Người tìm phòng<br>Tìm tin công khai theo bộ lọc và cơ sở trường | PublicListingsController.list [R0183]<br>PublicCampusesController.list [R0178] | CB |
| UC-DIS-02<br>Xem chi tiết tin và đánh giá công khai | Khách hoặc Người tìm phòng<br>Đọc nội dung tin còn hiển thị cùng đánh giá được duyệt | PublicListingsController.detail [R0184]<br>PublicRoomReviewsController.list [R0293] | CB |
| UC-DIS-03<br>Lưu và bỏ lưu phòng yêu thích | TENANT<br>Duy trì danh sách tin quan tâm của mình | HousingController.favorites [R0151]<br>HousingController.favorite [R0152]<br>HousingController.save [R0153]<br>HousingController.remove [R0154] | CB |
| UC-DIS-04<br>Lưu bộ lọc và theo dõi tin khớp | TENANT<br>Lưu tối đa 10 tìm kiếm và đọc cảnh báo kết quả mới | SavedSearchesController.list [R0196]<br>SavedSearchesController.create [R0197]<br>SavedSearchesController.alerts [R0198]<br>SavedSearchesController.read [R0199]<br>SavedSearchesController.status [R0200]<br>SavedSearchesController.remove [R0201] | CB |
| UC-DIS-05<br>Soạn và sửa bản nháp tin cho thuê | LANDLORD<br>Chuẩn bị nội dung tin của phòng thuộc mình | LandlordListingsController.list [R0185]<br>LandlordListingsController.create [R0186]<br>LandlordListingsController.update [R0187] | CB |
| UC-DIS-06.1<br>Gửi tin cho thuê để kiểm duyệt | LANDLORD<br>Chuyển bản tin đủ điều kiện sang PENDING | LandlordListingsController.submit [R0188] | CB |
| UC-DIS-06.2<br>Ẩn tin cho thuê của mình | LANDLORD<br>Ngừng công khai tin mà không xóa lịch sử | LandlordListingsController.hide [R0189] | CB |
| UC-DIS-06.3<br>Xác nhận lại tình trạng còn phòng | LANDLORD<br>Ghi nhận lần xác nhận khả dụng của tin | LandlordListingsController.confirm [R0190] | CB |
| UC-DIS-07<br>Báo cáo tin phòng không phù hợp | TENANT<br>Gửi ListingReport để admin xử lý | StudentListingsController.report [R0182] | CB |
| UC-DIS-08<br>Quản lý khung giờ xem phòng | LANDLORD<br>Mở hoặc gỡ khung giờ cho lịch xem tin của mình | HousingController.slots [R0144]<br>HousingController.addSlot [R0145]<br>HousingController.removeSlot [R0146] | CB |
| UC-DIS-09<br>Đặt và theo dõi lịch xem phòng | TENANT<br>Gửi RoomViewing cho tin và lịch hợp lệ | HousingController.book [R0156]<br>HousingController.viewings [R0155]<br>HousingController.viewing [R0157] | CB |
| UC-DIS-10<br>Đổi lịch hủy và xử lý lịch xem | TENANT hoặc LANDLORD<br>Cập nhật lịch theo tác nhân trạng thái và version | HousingController.reschedule [R0147]<br>HousingController.update [R0158] | CB |
| UC-DIS-11<br>Tạo hợp đồng từ lịch xem đã hoàn thành | LANDLORD<br>Chuyển lịch COMPLETED thành LEASED và ẩn tin | HousingController.lease [R0159] | CB |
| UC-DIS-12<br>Viết sửa và rút đánh giá phòng đã thuê | TENANT<br>Gửi nội dung gắn hợp đồng đủ điều kiện để kiểm duyệt | RoomReviewsController.context [R0294]<br>RoomReviewsController.create [R0295]<br>RoomReviewsController.update [R0296]<br>RoomReviewsController.withdraw [R0297] | CB |
| UC-DIS-13.1<br>Trả lời đánh giá phòng | LANDLORD<br>Gửi phản hồi của chủ trọ qua kiểm duyệt riêng | RoomReviewsController.landlord [R0298]<br>RoomReviewsController.reply [R0299] | CB |
| UC-DIS-13.2<br>Gửi phản hồi về thử nghiệm tìm phòng | TENANT hoặc LANDLORD<br>Ghi PilotFeedback khi khu vực thử nghiệm được mở | HousingController.pilot [R0162]<br>HousingController.feedback [R0163] | CB |
| UC-DIS-14<br>Xem thông báo hành trình tìm thuê | TENANT hoặc LANDLORD<br>Đọc thông báo lịch xem của chính tài khoản | HousingController.notifications [R0160]<br>HousingController.read [R0161] | CB |
| UC-DIS-15<br>Xem quyết định và gửi kháng nghị kiểm duyệt | TENANT hoặc LANDLORD<br>Đề nghị xem lại quyết định thuộc tài nguyên của mình | MyModerationController.decisions [R0272]<br>MyModerationController.appeals [R0273]<br>MyModerationController.appeal [R0274]<br>MyModerationController.features [R0275] | CB |

UC-DIS-04: Không có endpoint sửa filters của tìm kiếm đã lưu; chỉ tạo bật tắt xóa và đọc cảnh báo.

UC-DIS-11: Không gộp bàn giao vào tạo hợp đồng; bàn giao nằm ở TNT-12.2 và TNT-12.3.

### 3.3 Khu trọ và phòng

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-OPT-01<br>Xem dashboard và bản đồ phòng | LANDLORD hoặc STAFF có report.view<br>Theo dõi chỉ số và mở phòng trong phạm vi được cấp | DashboardController.metrics [R0130] | CB |
| UC-OPT-02<br>Tra cứu và chọn khu trọ | LANDLORD hoặc STAFF có property.view<br>Đọc khu trọ theo bộ lọc lifecycle và phạm vi | PropertiesController.list [R0284]<br>PropertiesController.getById [R0286] | CB |
| UC-OPT-03.1<br>Tạo khu trọ | LANDLORD<br>Thêm Property chưa lưu trữ trong hạn mức gói | PropertiesController.create [R0285] | CB |
| UC-OPT-03.2<br>Cập nhật thông tin khu trọ | LANDLORD hoặc STAFF có property.manage<br>Sửa tên và địa chỉ khu thuộc phạm vi | PropertiesController.update [R0287] | CB |
| UC-OPT-04.1<br>Lưu trữ khu trọ | LANDLORD hoặc STAFF có property.manage<br>Đặt isArchived khi không còn hợp đồng ACTIVE | PropertiesController.updateStatus [R0288] | CB |
| UC-OPT-04.2<br>Khôi phục khu trọ đã lưu trữ | LANDLORD hoặc STAFF có property.manage<br>Bỏ lưu trữ sau kiểm tra hạn mức khu và phòng | PropertiesController.updateStatus [R0288] | CB |
| UC-OPT-04.3<br>Xóa khu trọ chưa có phòng và lịch sử xét duyệt | LANDLORD hoặc STAFF có property.manage<br>Xóa vật lý khi các ràng buộc phụ thuộc cho phép | PropertiesController.remove [R0289] | CB |
| UC-OPT-05<br>Tra cứu phòng và lịch sử liên quan | LANDLORD hoặc STAFF có room.view<br>Đọc phòng trong khu được cấp quyền | PropertyRoomsController.list [R0303]<br>RoomsController.getById [R0305] | CB |
| UC-OPT-06.1<br>Tạo phòng | LANDLORD hoặc STAFF có room.manage<br>Thêm Room vào khu hoạt động trong hạn mức | PropertyRoomsController.create [R0304] | CB |
| UC-OPT-06.2<br>Cập nhật thông tin phòng | LANDLORD hoặc STAFF có room.manage<br>Sửa metadata không tự sửa giá thuê của hợp đồng cũ | RoomsController.update [R0306] | CB |
| UC-OPT-07.1<br>Đổi trạng thái sử dụng phòng | LANDLORD hoặc STAFF có room.manage<br>Đặt trạng thái phòng không trái hợp đồng và turnover | RoomsController.update [R0306] | CB |
| UC-OPT-07.2<br>Vô hiệu hóa hoặc khôi phục phòng | LANDLORD hoặc STAFF có room.manage<br>Đổi isActive và giữ lịch sử phòng | RoomsController.updateStatus [R0307] | CB |
| UC-OPT-07.3<br>Xóa phòng chưa có lịch sử nghiệp vụ | LANDLORD hoặc STAFF có room.manage<br>Xóa phòng sau kiểm tra hợp đồng chỉ số hóa đơn lịch xem turnover | RoomsController.remove [R0308] | CB |
| UC-OPT-08.1<br>Quản lý tài sản phòng | LANDLORD hoặc STAFF có room.manage<br>Duy trì RoomAsset của phòng thuộc phạm vi | RoomsController.assets [R0309]<br>RoomsController.createAsset [R0310]<br>RoomsController.updateAsset [R0311]<br>RoomsController.removeAsset [R0312] | CB |
| UC-OPT-08.2<br>Theo dõi lịch kiểm tra phòng | LANDLORD hoặc STAFF có room.manage<br>Lập sửa hoàn tất hoặc xóa RoomInspection | RoomsController.inspections [R0313]<br>RoomsController.createInspection [R0314]<br>RoomsController.updateInspection [R0315]<br>RoomsController.completeInspection [R0316]<br>RoomsController.removeInspection [R0317] | CB |
| UC-OPT-09<br>Quản lý phiên bản phí dịch vụ phòng | LANDLORD hoặc STAFF có room.manage<br>Lưu lịch sử mức phí và tháng hiệu lực tại phòng | RoomsController.serviceFees [R0318]<br>RoomsController.createServiceFee [R0319]<br>RoomsController.updateServiceFee [R0320]<br>RoomsController.tariffVersions [R0321]<br>RoomsController.removeServiceFee [R0322] | CB |

UC-OPT-07.1: Cùng PATCH với sửa phòng nhưng mục tiêu đổi trạng thái được giữ riêng; không có endpoint status nghiệp vụ riêng.

### 3.4 Người thuê và hợp đồng

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-TNT-01<br>Tra cứu hồ sơ người thuê và tổng quan | LANDLORD hoặc STAFF có tenant.view<br>Đọc Tenant và tóm tắt lịch sử đúng phạm vi | TenantsController.list [R0396]<br>TenantsController.getById [R0398]<br>TenantsController.overview [R0399] | CB |
| UC-TNT-02.1<br>Tạo hồ sơ người thuê | LANDLORD hoặc STAFF có tenant.manage<br>Tạo Tenant nghiệp vụ chưa mặc nhiên có User | TenantsController.create [R0397] | CB |
| UC-TNT-02.2<br>Cập nhật hồ sơ người thuê | LANDLORD hoặc STAFF có tenant.manage<br>Sửa dữ liệu hồ sơ thuộc chủ trọ | TenantsController.update [R0401] | CB |
| UC-TNT-02.3<br>Vô hiệu hóa hoặc khôi phục người thuê | LANDLORD hoặc STAFF có tenant.manage<br>Đổi isActive theo điều kiện hợp đồng | TenantsController.updateStatus [R0402] | CB |
| UC-TNT-02.4<br>Xóa hồ sơ người thuê chưa có lịch sử | LANDLORD hoặc STAFF có tenant.manage<br>Xóa Tenant khi không còn ràng buộc nghiệp vụ | TenantsController.remove [R0403] | CB |
| UC-TNT-03<br>Tạo lời mời truy cập cổng người thuê | LANDLORD<br>Nhận mã kích hoạt dùng một lần cho Tenant chưa có User | TenantInvitesController.create [R0394] | CB |
| UC-TNT-03.1<br>Tạo trực tiếp tài khoản cho hồ sơ người thuê | LANDLORD hoặc STAFF có tenant.manage<br>Liên kết tài khoản đăng nhập mới với Tenant | TenantsController.createAccount [R0400] | CB |
| UC-TNT-04<br>Tra cứu hợp đồng và cảnh báo hết hạn | LANDLORD hoặc STAFF có lease.view<br>Đọc hợp đồng theo phòng người thuê và số ngày cảnh báo | LeasesController.expiring [R0166]<br>RoomLeasesController.list [R0176]<br>TenantLeasesController.list [R0177] | CB |
| UC-TNT-05<br>Tạo hợp đồng và ghi nhận cọc ban đầu | LANDLORD hoặc STAFF có lease.manage<br>Tạo Lease ACTIVE và chuyển phòng OCCUPIED trong transaction | LeasesController.create [R0165] | CB |
| UC-TNT-06.1<br>Cập nhật điều khoản hợp đồng | LANDLORD hoặc STAFF có lease.manage<br>Lưu thay đổi điều khoản cùng LeaseChange | LeasesController.update [R0172] | CB |
| UC-TNT-06.2<br>Gia hạn hợp đồng | LANDLORD hoặc STAFF có lease.manage<br>Đặt ngày kết thúc muộn hơn khi chưa quyết toán | LeasesController.renew [R0173] | CB |
| UC-TNT-06.3<br>Kết thúc hợp đồng | LANDLORD hoặc STAFF có lease.manage<br>Đặt ENDED và khởi tạo turnover phòng | LeasesController.end [R0167] | CB |
| UC-TNT-07<br>Tra cứu và ghi giao dịch cọc | LANDLORD hoặc STAFF có lease.manage khi ghi<br>Ghi thu hoàn khấu trừ hoặc điều chỉnh số dư cọc | LeasesController.deposits [R0174]<br>LeasesController.createDeposit [R0175] | CB |
| UC-TNT-08<br>Xem trước và xác nhận quyết toán trả phòng | LANDLORD<br>Chốt snapshot chi phí cọc và nghĩa vụ còn lại không tự chuyển tiền | LeasesController.settlement [R0168]<br>LeasesController.previewSettlement [R0169]<br>LeasesController.confirmSettlement [R0170] | CB |
| UC-TNT-09<br>Ghi nhận đã hoàn cọc theo quyết toán | LANDLORD<br>Ghi REFUNDED và trạng thái hoàn cọc đã trả | LeasesController.recordSettlementRefund [R0171] | CB |
| UC-TNT-10<br>Xét duyệt yêu cầu vòng đời thuê | LANDLORD hoặc STAFF có lease.manage<br>Đặt APPROVED hoặc REJECTED chưa tự đổi hợp đồng | TenantLifecycleController.requests [R0374]<br>TenantLifecycleController.review [R0375] | CB |
| UC-TNT-11<br>Thực thi yêu cầu vòng đời đã duyệt | LANDLORD hoặc STAFF có lease.manage<br>Thực hiện yêu cầu một lần theo requestKey và điều kiện Lease | TenantLifecycleController.execute [R0376] | CB |
| UC-TNT-12.1<br>Quản lý người ở cùng hợp đồng | LANDLORD hoặc STAFF có lease.manage khi ghi<br>Thêm hoặc kết thúc người ở trong sức chứa phòng | TenantLifecycleController.occupants [R0377]<br>TenantLifecycleController.addOccupant [R0378]<br>TenantLifecycleController.removeOccupant [R0379] | CB |
| UC-TNT-12.2<br>Lập biên bản bàn giao nhận phòng | LANDLORD<br>Lưu chỉ số hiện trạng và ảnh trước khi người thuê xác nhận | HousingController.handover [R0148]<br>HousingController.saveHandover [R0149] | CB |
| UC-TNT-12.3<br>Xác nhận biên bản bàn giao nhận phòng | TENANT<br>Chấp nhận đúng version khi hợp đồng đến ngày hiệu lực | HousingController.acceptHandover [R0150] | CB |
| UC-TNT-13<br>Xuất hoặc chia sẻ hợp đồng PDF | LANDLORD hoặc người được UI cho phép<br>Dựng PDF tại Flutter không phát sinh chữ ký số | LOCAL.leasePdf (Flutter, không API riêng) | CB |

UC-TNT-03: Decorator nhận STAFF nhưng PropertyScopeInterceptor chặn TenantInvitesController; không mô tả STAFF thực thi được.

UC-TNT-13: Chức năng cục bộ; không bịa endpoint xuất PDF hoặc chữ ký điện tử.

### 3.5 Hóa đơn và sổ thu chi

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-BIL-01<br>Ghi chỉ số điện nước theo kỳ | LANDLORD hoặc STAFF có billing.create<br>Lưu lượng tiêu thụ và số tiền của phòng loại tiện ích kỳ | BillingController.meterReadings [R0079]<br>BillingController.createMeterReading [R0080] | CB |
| UC-BIL-02<br>Xem trước và lập hóa đơn một hợp đồng | LANDLORD hoặc STAFF có billing.create<br>Phát hành hóa đơn với các dòng giá chụp tại kỳ lập | BillingController.activeLeases [R0078]<br>BillingController.previewInvoice [R0112]<br>BillingController.createInvoice [R0090] | CB |
| UC-BIL-03<br>Lập hóa đơn hàng loạt | LANDLORD hoặc STAFF có billing.create<br>Kiểm tra trước và tạo kết quả cho từng hợp đồng đủ điều kiện | BillingController.bulkInvoicePreflight [R0084]<br>BillingController.createBulkInvoices [R0085] | CB |
| UC-BIL-04<br>Tra cứu hóa đơn và tuổi nợ | LANDLORD hoặc STAFF có billing.view<br>Đọc số còn phải thu và nhóm ngày quá hạn | BillingController.invoices [R0081]<br>BillingController.invoice [R0091]<br>BillingController.aging [R0096]<br>BillingController.reminders [R0082] | CB |
| UC-BIL-05<br>Sửa hạn thanh toán hoặc ghi chú hóa đơn | LANDLORD hoặc STAFF có billing.create<br>Đổi hạn và ghi chú mà không ghi đè dòng tiền | BillingController.updateInvoice [R0092] | CB |
| UC-BIL-06<br>Thay thế hóa đơn chưa có lịch sử thanh toán | LANDLORD hoặc STAFF có billing.adjust<br>Hủy bản gốc và tạo revision mới có liên kết truy vết | BillingController.replaceInvoice [R0094] | CB |
| UC-BIL-07<br>Phát hành credit note hoặc debit note | LANDLORD hoặc STAFF có billing.adjust<br>Điều chỉnh nghĩa vụ theo số tiền hoặc basisPoints | BillingController.adjustInvoice [R0095] | CB |
| UC-BIL-08.1<br>Hủy hóa đơn đủ điều kiện | LANDLORD hoặc STAFF có billing.cancel<br>Đặt CANCELLED khi chưa có bản ghi Payment | BillingController.cancelInvoice [R0093] | CB |
| UC-BIL-08.2<br>Xuất hoặc chia sẻ hóa đơn PDF | Người được quyền xem hóa đơn<br>Dựng bản PDF từ dữ liệu hóa đơn tại Flutter | LOCAL.invoicePdf (Flutter, không API riêng) | CB |
| UC-BIL-09<br>Ghi nhận thanh toán trực tiếp | LANDLORD hoặc STAFF có billing.record_payment<br>Thêm Payment dương không vượt dư của hóa đơn thật | BillingController.recordPayment [R0113] | CB |
| UC-BIL-10<br>Tạo khoản thu cho người thuê | LANDLORD hoặc STAFF có billing.record_payment<br>Tạo BillingReceipt và giữ phần tiền chưa phân bổ | BillingController.receipts [R0097]<br>BillingController.createReceipt [R0098] | CB |
| UC-BIL-11<br>Phân bổ khoản thu cho hóa đơn | LANDLORD hoặc STAFF có billing.record_payment<br>Đưa số tiền khả dụng vào hóa đơn cùng Tenant | BillingController.allocateReceipt [R0099] | CB |
| UC-BIL-12.1<br>Giải phóng phân bổ khoản thu | LANDLORD hoặc STAFF có billing.reverse_payment<br>Đảo Payment của allocation và trả tiền về khả dụng | BillingController.releaseAllocation [R0100] | CB |
| UC-BIL-12.2<br>Đảo thanh toán trực tiếp | LANDLORD hoặc STAFF có billing.reverse_payment<br>Ghi Payment REVERSAL cho khoản gốc chưa bị đảo | BillingController.reversePayment [R0116] | CB |
| UC-BIL-13<br>Ghi nhận hoàn tiền từ khoản thu | LANDLORD hoặc STAFF có billing.refund<br>Giảm tiền khả dụng bằng ReceiptRefund có tham chiếu | BillingController.refundReceipt [R0101] | CB |
| UC-BIL-14<br>Xét duyệt chứng từ thanh toán | LANDLORD hoặc STAFF có billing.approve_payment_proof<br>Chấp thuận tạo Payment hoặc từ chối không tăng paidAmount | BillingController.paymentProofs [R0114]<br>BillingController.reviewPaymentProof [R0115] | CB |
| UC-BIL-15<br>Đề xuất biểu phí theo kỳ hiệu lực | LANDLORD hoặc STAFF có billing.create<br>Lưu BillingTariffVersion ở trạng thái PROPOSED | BillingController.tariffsList [R0107]<br>BillingController.proposeTariff [R0108] | CB |
| UC-BIL-16<br>Phân tích tác động và duyệt biểu phí | LANDLORD<br>Duyệt hoặc từ chối đề xuất sau kiểm tra kỳ đã phát hành hoặc khóa | BillingController.tariffImpact [R0109]<br>BillingController.reviewTariff [R0110] | CB |
| UC-BIL-17.1<br>Cấu hình lập hóa đơn định kỳ | LANDLORD hoặc STAFF có billing.create<br>Lưu lịch lập hóa đơn theo khu | BillingController.billingAutomation [R0086]<br>BillingController.updateBillingAutomation [R0087] | CB |
| UC-BIL-17.2<br>Xem trước và chạy đợt lập hóa đơn | LANDLORD hoặc STAFF có billing.create<br>Chạy kỳ theo cấu hình và ghi kết quả BillingRun | BillingController.billingAutomationPreview [R0088]<br>BillingController.runBillingAutomation [R0089] | CB |
| UC-BIL-18.1<br>Cấu hình chính sách nhắc nợ | LANDLORD hoặc STAFF có billing.policy và khu cụ thể<br>Lưu chính sách mặc định hoặc ghi đè theo khu | BillingController.reminderPolicy [R0102]<br>BillingController.updateReminderPolicy [R0103] | CB |
| UC-BIL-18.2<br>Xếp hàng nhắc nợ theo chính sách | LANDLORD hoặc STAFF có billing.policy và khu cụ thể<br>Tạo tác vụ gửi phù hợp sở thích người thuê | BillingController.runReminders [R0083]<br>BillingController.enqueueReminders [R0104] | CB |
| UC-BIL-18.3<br>Theo dõi và thử lại outbox hóa đơn | LANDLORD<br>Đọc sự kiện và yêu cầu thử lại theo trạng thái được phép | BillingController.outboxEvents [R0105]<br>BillingController.retryOutbox [R0106] | CB |
| UC-BIL-19<br>Quản lý khoản chi vận hành | LANDLORD hoặc STAFF có expense.manage khi ghi<br>Lưu khoản Expense riêng với tiền thuê và tiền cọc | ExpensesController.list [R0131]<br>ExpensesController.create [R0132]<br>ExpensesController.getById [R0133]<br>ExpensesController.update [R0134]<br>ExpensesController.remove [R0135] | CB |
| UC-BIL-20<br>Xem báo cáo tháng và chỉ số phân tích | LANDLORD hoặc STAFF có report.view<br>Đọc thu ròng chi phí công suất và công nợ theo định nghĩa code | ReportsController.monthly [R0290]<br>ReportsController.analytics [R0292] | CB |
| UC-BIL-21<br>Xuất nội dung báo cáo tháng CSV | LANDLORD hoặc STAFF có report.export<br>Nhận CSV và sao chép nội dung tại giao diện | ReportsController.monthlyExport [R0291] | CB |
| UC-BIL-22<br>Khóa kỳ thanh toán của khu | LANDLORD<br>Lưu BillingPeriodLock ngăn các thao tác thuộc quy tắc khóa | BillingController.lockPeriod [R0111] | CB |
| UC-BIL-23<br>Cấu hình tài khoản nhận chuyển khoản | LANDLORD<br>Lưu ngân hàng tài khoản và QR riêng theo version | TransferAccountController.account [R0117]<br>TransferAccountController.save [R0118] | CB |

UC-BIL-08.2: Chức năng cục bộ Flutter; quyền xem dữ liệu nguồn vẫn phải do API thực thi.

UC-BIL-16: Controller reviewTariff là LANDLORD-only dù tồn tại tên permission billing.tariff_approve.

UC-BIL-18.3: Interceptor không cho STAFF dùng outboxEvents hoặc retryOutbox.

UC-BIL-21: UI sao chép CSV vào clipboard; không gọi đây là tải XLSX.

### 3.6 Vận hành nhà trọ

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-OPS-01<br>Tiếp nhận và theo dõi phiếu bảo trì | LANDLORD hoặc STAFF có maintenance.manage khi ghi<br>Duy trì ticket nội dung bình luận và xóa theo điều kiện | MaintenanceController.list [R0202]<br>MaintenanceController.create [R0203]<br>MaintenanceController.getById [R0205]<br>MaintenanceController.addComment [R0210]<br>MaintenanceController.remove [R0211] | CB |
| UC-OPS-02<br>Phân công và cập nhật bảo trì | LANDLORD hoặc STAFF có maintenance.manage trừ escalate<br>Gán nhân viên tiến độ hạn xử lý và chạy kiểm tra SLA | MaintenanceController.assignees [R0204]<br>MaintenanceController.update [R0207]<br>MaintenanceController.updateStatus [R0208]<br>MaintenanceController.escalate [R0206] | CB |
| UC-OPS-03<br>Hoàn tất bảo trì và liên kết khoản chi | LANDLORD hoặc STAFF có maintenance.complete<br>Đặt DONE và tùy chọn tạo Expense REPAIR một lần | MaintenanceController.complete [R0209] | CB |
| UC-OPS-04<br>Theo dõi việc cần xử lý | LANDLORD<br>Đọc action items và đánh dấu đã xem theo tài khoản | OperationsController.actionItems [R0228]<br>OperationsController.markRead [R0229] | CB |
| UC-OPS-05<br>Chuẩn bị phòng sau trả phòng | LANDLORD<br>Đi qua RETURNED INSPECTION REPAIR CLEANING READY | P1OperationsController.list [R0231]<br>P1OperationsController.create [R0232]<br>P1OperationsController.advance [R0233] | CB |
| UC-OPS-06<br>Quản lý việc định kỳ và checklist | LANDLORD<br>Lập RecurringOperation và cập nhật OperationTask phát sinh | P1OperationsController.templates [R0234]<br>P1OperationsController.createRecurring [R0235]<br>P1OperationsController.toggle [R0236]<br>P1OperationsController.tasks [R0237]<br>P1OperationsController.check [R0238] | CB |
| UC-OPS-07<br>Soạn và phát thông báo người thuê | LANDLORD<br>Lưu mẫu nhóm lịch thông báo và theo dõi lượt đọc | AnnouncementsController.list [R0212]<br>AnnouncementsController.templates [R0213]<br>AnnouncementsController.groups [R0214]<br>AnnouncementsController.createTemplate [R0215]<br>AnnouncementsController.createGroup [R0216]<br>AnnouncementsController.create [R0217]<br>AnnouncementsController.receipts [R0218]<br>AnnouncementsController.cancel [R0219] | CB |
| UC-OPS-08<br>Theo dõi lượt gửi và gửi nhắc Zalo | LANDLORD<br>Đọc delivery log và gửi nhắc qua chế độ cấu hình thực tế | NotificationsController.list [R0222]<br>NotificationsController.markRead [R0223]<br>NotificationsController.deliveryLogs [R0224]<br>NotificationsController.sendInvoiceRemindersZalo [R0225]<br>NotificationsController.createZaloTestMessage [R0226]<br>NotificationsController.createZaloManualMessage [R0227] | CB |
| UC-OPS-09<br>Tra cứu nhật ký vận hành | LANDLORD<br>Đọc AuditLog thuộc chủ trọ theo bộ lọc | AuditController.list [R0061] | CB |

UC-OPS-02: STAFF được một số thao tác bảo trì nhưng bị chặn escalate ở interceptor.

UC-OPS-04: OperationsController không nằm trong allowlist của PropertyScopeInterceptor; STAFF bị từ chối.

UC-OPS-05: P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.

UC-OPS-06: P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.

UC-OPS-07: AnnouncementsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.

UC-OPS-08: NotificationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.

UC-OPS-09: AuditController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.

### 3.7 Cổng người thuê

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-TEN-01<br>Xem hồ sơ và tổng quan thuê của mình | TENANT có hồ sơ liên kết<br>Đọc thông tin thuê chỉ thuộc Tenant của tài khoản | TenantPortalController.me [R0380]<br>TenantPortalController.dashboard [R0381] | CB |
| UC-TEN-02<br>Xem hợp đồng cọc và quyết toán của mình | TENANT có hồ sơ liên kết<br>Đọc Lease và settlement không được sửa điều khoản | TenantPortalController.leases [R0383]<br>TenantLifecyclePortalController.settlement [R0370] | CB |
| UC-TEN-03<br>Xem hóa đơn và PDF của mình | TENANT có hồ sơ liên kết<br>Đọc hóa đơn đúng Tenant trước khi dựng PDF cục bộ | TenantPortalController.invoices [R0382]<br>TenantPortalController.invoice [R0384] | CB |
| UC-TEN-04<br>Gửi chứng từ thanh toán | TENANT có hồ sơ liên kết<br>Tạo PaymentProof PENDING không tự giảm công nợ | TenantPortalController.submitPaymentProof [R0390] | CB |
| UC-TEN-05<br>Thanh toán bằng thẻ mô phỏng | TENANT ở môi trường demo<br>Thanh toán hóa đơn isDemo qua checkout nội bộ không dùng tiền thật | TenantOnlinePaymentsController.create [R0120]<br>TenantOnlinePaymentsController.demoInvoice [R0121]<br>TenantOnlinePaymentsController.status [R0122]<br>DemoCardPaymentController.checkout [R0126]<br>DemoCardPaymentController.confirm [R0127] | MP |
| UC-TEN-06<br>Gửi và trao đổi yêu cầu bảo trì | TENANT có hồ sơ liên kết<br>Tạo ticket và bình luận cho phòng gắn hợp đồng của mình | TenantPortalController.maintenance [R0391]<br>TenantPortalController.createMaintenance [R0392]<br>TenantPortalController.addMaintenanceComment [R0393] | CB |
| UC-TEN-07<br>Gửi hủy và theo dõi yêu cầu vòng đời thuê | TENANT có hồ sơ liên kết<br>Đề nghị RENEWAL TRANSFER_ROOM CHECKOUT chưa sửa trực tiếp Lease | TenantLifecyclePortalController.requests [R0366]<br>TenantLifecyclePortalController.create [R0367]<br>TenantLifecyclePortalController.cancel [R0368]<br>TenantLifecyclePortalController.transferRooms [R0369] | CB |
| UC-TEN-08.1<br>Xem người ở cùng hợp đồng | TENANT có hồ sơ liên kết<br>Đọc occupants nhưng không tự thêm hoặc xóa | TenantLifecyclePortalController.occupants [R0371] | CB |
| UC-TEN-08.2<br>Thiết lập sở thích nhắc nợ | TENANT có hồ sơ liên kết<br>Đặt enabled và các kênh nhắc nợ được hỗ trợ | TenantLifecyclePortalController.preference [R0372]<br>TenantLifecyclePortalController.savePreference [R0373] | CB |
| UC-TEN-09.1<br>Đọc thông báo cổng người thuê | TENANT có hồ sơ liên kết<br>Đánh dấu notification của mình đã đọc | TenantPortalController.notifications [R0385]<br>TenantPortalController.markNotificationRead [R0386] | CB |
| UC-TEN-09.2<br>Trao đổi tin nhắn mô phỏng Zalo trong portal | TENANT có hồ sơ liên kết<br>Lưu và đọc hội thoại trong ứng dụng không mặc nhiên gửi Zalo OA | TenantPortalController.zaloMessages [R0387]<br>TenantPortalController.createZaloMessage [R0388]<br>TenantPortalController.markZaloMessageRead [R0389] | MP |
| UC-TEN-09.3<br>Đọc và xác nhận thông báo chủ trọ | TENANT có hồ sơ liên kết<br>Ghi lượt đọc hoặc acknowledgement Announcement | TenantAnnouncementsController.list [R0220]<br>TenantAnnouncementsController.read [R0221] | CB |
| UC-TEN-10<br>Xem hướng dẫn chuyển khoản của hóa đơn | TENANT có hồ sơ liên kết<br>Đọc tài khoản và QR chủ trọ trước khi gửi chứng từ | TransferInstructionsController.instructions [R0119] | CB |

UC-TEN-05: Chỉ bật ngoài production và DEMO_PAYMENTS_ENABLED=true; không có cổng thu thẻ tiền thật được xác nhận.

### 3.8 Quản trị nền tảng

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-ADM-01<br>Xem tổng quan và phân tích nền tảng | ADMIN có admin.dashboard.view<br>Đọc overview analytics và công việc chờ theo quyền | AdminController.overview [R0050]<br>AdminOverviewAnalyticsController.overview [R0029]<br>AdminConsoleController.analytics [R0023]<br>AdminWorkspaceController.summary [R0048]<br>AdminWorkspaceController.actionItems [R0049] | CB |
| UC-ADM-02<br>Tra cứu tài khoản nền tảng | ADMIN có quyền đọc tương ứng<br>Đọc thông tin khách hàng được che theo projection | AdminConsoleController.accounts [R0005]<br>AdminConsoleController.account [R0006]<br>AdminController.listLandlords [R0051]<br>AdminController.getLandlord [R0053] | CB |
| UC-ADM-03.1<br>Tạo hoặc mời tài khoản chủ trọ | ADMIN có admin.accounts.manage<br>Tạo tài khoản LANDLORD hoặc công việc kích hoạt theo endpoint | AdminController.createLandlord [R0052] | CB |
| UC-ADM-03.2<br>Cập nhật hồ sơ chủ trọ | ADMIN có admin.accounts.manage<br>Sửa dữ liệu chủ trọ không thay quyền Admin | AdminController.updateLandlord [R0054] | CB |
| UC-ADM-04.1<br>Đình chỉ tài khoản và vô hiệu phiên | ADMIN có admin.accounts.suspend<br>Đặt inactive và tăng sessionVersion có tác động nhân viên phụ thuộc | AdminConsoleController.suspend [R0007]<br>AdminController.updateLandlordStatus [R0055] | CB |
| UC-ADM-04.2<br>Khôi phục tài khoản bị đình chỉ | ADMIN có admin.accounts.suspend<br>Đặt active không làm token đã thu hồi sống lại | AdminConsoleController.restore [R0008] | CB |
| UC-ADM-04.3<br>Thu hồi phiên của tài khoản khách hàng | ADMIN có admin.sessions.revoke<br>Vô hiệu session và refresh token không xóa dữ liệu tài chính | AdminConsoleController.revoke [R0009] | CB |
| UC-ADM-05.1<br>Mở thông tin cá nhân được che | ADMIN có admin.pii.reveal<br>Đọc email điện thoại có lý do và audit | AdminConsoleController.reveal [R0010] | CB |
| UC-ADM-05.2<br>Yêu cầu khôi phục truy cập cho tài khoản | ADMIN có admin.accounts.manage<br>Xếp hàng liên kết đặt mật khẩu không trả mật khẩu mới | AdminConsoleController.reset [R0011] | CB |
| UC-ADM-06.1<br>Quản lý hồ sơ và quyền Admin | ADMIN có admin.admins.manage và điều kiện cấp quyền<br>Cập nhật preset hoặc quyền trong tập được phép ủy quyền | AdminConsoleController.admins [R0013]<br>AdminConsoleController.adminAccess [R0014]<br>AdminConsoleController.profile [R0015]<br>AdminConsoleController.invite [R0012] | CB |
| UC-ADM-06.2<br>Rà soát quyền Admin định kỳ | ADMIN có admin.admins.manage<br>Lưu kết quả rà soát và hạn rà soát tiếp theo cho người khác | AdminAccessReviewController.catalog [R0001]<br>AdminAccessReviewController.list [R0002]<br>AdminAccessReviewController.review [R0003] | CB |
| UC-ADM-07.1<br>Thiết lập MFA Admin | ADMIN có phiên hợp lệ<br>Tạo và xác nhận cấu hình MFA với mã khôi phục | AdminSecurityController.status [R0064]<br>AdminSecurityController.enroll [R0065]<br>AdminSecurityController.confirm [R0066] | CB |
| UC-ADM-07.2<br>Xác minh tăng cường cho thao tác nhạy cảm | ADMIN có quyền của thao tác đích<br>Nhận token step-up gắn session method path payload | AdminStepUpController.issue [R0067] | CB |
| UC-ADM-08<br>Tra cứu khu và phòng toàn nền tảng | ADMIN có quyền inventory tương ứng<br>Đọc kho phòng và trạng thái tin tách biệt | AdminController.listProperties [R0056]<br>AdminController.getProperty [R0058]<br>AdminController.rooms [R0059] | CB |
| UC-ADM-09<br>Tạo hoặc cập nhật khu thay chủ trọ | ADMIN có admin.properties.manage<br>Ghi Property của landlord đích qua luồng quản trị | AdminController.createProperty [R0057]<br>AdminController.updateProperty [R0060] | CB |
| UC-ADM-10<br>Tìm kiếm và định vị tài nguyên | ADMIN có quyền theo loại tài nguyên<br>Trả kết quả từng loại được quyền đọc không vượt capability | AdminSearchController.searchAll [R0045]<br>AdminSearchController.resources [R0046]<br>AdminSearchController.detail [R0047] | CB |
| UC-ADM-11<br>Nhận việc và kiểm duyệt tin đăng | ADMIN có quyền tin đăng<br>Nhận ModerationWorkItem và xét trạng thái tin hoặc batch theo quyền | AdminConsoleController.queue [R0020]<br>AdminConsoleController.work [R0021]<br>AdminConsoleController.item [R0022]<br>AdminListingsController.list [R0193]<br>AdminListingsController.review [R0194]<br>AdminListingsController.verify [R0195]<br>ModerationV2Controller.bulk [R0281]<br>ModerationV2Controller.preview [R0282] | CB |
| UC-ADM-12<br>Kiểm duyệt đánh giá và báo cáo vi phạm | ADMIN có quyền theo loại nội dung<br>Duyệt review reply hoặc xử lý ListingReport | AdminRoomReviewsController.queue [R0300]<br>AdminRoomReviewsController.moderate [R0301]<br>AdminRoomReviewsController.reply [R0302]<br>AdminListingsController.reports [R0191]<br>AdminListingsController.reviewReport [R0192] | CB |
| UC-ADM-13.1<br>Quản lý chính sách kiểm duyệt | ADMIN có quyền chính sách<br>Tạo phiên bản và kích hoạt ModerationPolicy | ModerationPolicyController.list [R0265]<br>ModerationPolicyController.create [R0270]<br>ModerationPolicyController.activate [R0271] | CB |
| UC-ADM-13.2<br>Xử lý kháng nghị kiểm duyệt | ADMIN có quyền kháng nghị và nội dung<br>Phân công và giải quyết ModerationAppeal | ModerationV2Controller.decisions [R0276]<br>ModerationV2Controller.history [R0277]<br>ModerationV2Controller.appeals [R0278]<br>ModerationV2Controller.assign [R0279]<br>ModerationV2Controller.resolve [R0280]<br>ModerationV2Controller.reports [R0283] | CB |
| UC-ADM-13.3<br>Đánh giá chất lượng kiểm duyệt | ADMIN có quyền đánh giá chất lượng<br>Lấy mẫu và đánh giá quyết định không tự đánh giá mình | ModerationPolicyController.quality [R0266]<br>ModerationPolicyController.samples [R0267]<br>ModerationPolicyController.sample [R0268]<br>ModerationPolicyController.review [R0269] | CB |
| UC-ADM-14<br>Tra cứu và xuất nhật ký quản trị | ADMIN có admin.audit.view và thêm admin.audit.export khi xuất<br>Đọc audit và xuất dữ liệu trong phạm vi capability | AdminConsoleController.audit [R0016]<br>AdminConsoleController.auditDetail [R0017]<br>AdminConsoleController.auditExport [R0018] | CB |
| UC-ADM-15<br>Đối soát sao kê theo maker checker | ADMIN có admin.finance.reconcile<br>Nhập sao kê ghép chứng từ và duyệt đề xuất bởi người khác | FinanceReconciliationController.importStatement [R0239]<br>FinanceReconciliationController.lines [R0240]<br>FinanceReconciliationController.propose [R0241]<br>FinanceReconciliationController.candidates [R0242]<br>FinanceReconciliationController.proposals [R0243]<br>FinanceReconciliationController.approve [R0244]<br>FinanceReconciliationController.reject [R0245] | CB |
| UC-ADM-16<br>Quản lý lịch và tải báo cáo Admin | ADMIN có admin.reports.manage và quyền nội dung<br>Lập lịch theo timezone chạy và tải kết quả của mình | GovernanceController.schedules [R0257]<br>GovernanceController.createSchedule [R0258]<br>GovernanceController.updateSchedule [R0259]<br>GovernanceController.runSchedule [R0260]<br>GovernanceController.runs [R0261]<br>GovernanceController.download [R0264]<br>GovernanceController.link [R0263]<br>GovernanceController.retry [R0262] | CB |
| UC-ADM-17.1<br>Quản lý feature flags nghiệp vụ | ADMIN có quyền feature flags<br>Đổi enabled rollout roles theo version cho key cho phép | GovernanceController.flagsList [R0253]<br>GovernanceController.effective [R0254]<br>GovernanceController.flagsUpdate [R0255] | CB |
| UC-ADM-17.2<br>Quản lý nhóm Admin | ADMIN có quyền nhóm<br>Duy trì nhóm thành viên và trạng thái hoạt động | GovernanceController.team [R0246]<br>GovernanceController.teams [R0247]<br>GovernanceController.createTeam [R0248]<br>GovernanceController.addMember [R0249]<br>GovernanceController.updateTeam [R0250]<br>GovernanceController.removeMember [R0251] | CB |
| UC-ADM-18<br>Nộp và xét duyệt xác minh chủ trọ | LANDLORD nộp hoặc ADMIN có quyền xác minh và support.read<br>Lưu hồ sơ gắn ticket minh chứng và quyết định có version | LandlordVerificationController.own [R0043]<br>LandlordVerificationController.submit [R0044]<br>AdminRegistryController.verifications [R0031]<br>AdminRegistryController.submitVerification [R0032]<br>AdminRegistryController.reviewVerification [R0033] | CB |
| UC-ADM-19<br>Trình và xét duyệt hồ sơ khu trọ | ADMIN có admin.properties.manage<br>Duyệt snapshot khu khi thông tin chưa thay đổi | AdminRegistryController.propertyReviews [R0034]<br>AdminRegistryController.submitProperty [R0035]<br>AdminRegistryController.reviewProperty [R0036] | CB |
| UC-ADM-20<br>Quản lý danh mục gói dịch vụ | ADMIN có quyền plans<br>Lưu ServicePlan có giới hạn và version | AdminRegistryController.servicePlans [R0037]<br>AdminRegistryController.savePlan [R0038] | CB |
| UC-ADM-21<br>Gán gói và xem lịch sử đăng ký | ADMIN có quyền plans<br>Ghi planSnapshot và SubscriptionEvent cho landlord | AdminRegistryController.subscriptions [R0039]<br>AdminRegistryController.subscriptionEvents [R0040]<br>AdminRegistryController.assignSubscription [R0041] | CB |
| UC-ADM-22<br>Hủy quyền sử dụng gói đang hiệu lực | ADMIN có admin.plans.manage<br>Kết thúc hiệu lực không tự hoàn tiền hoặc xóa khu phòng | AdminRegistryController.cancelSubscription [R0042] | CB |
| UC-ADM-23<br>Quản lý danh mục cơ sở trường | ADMIN có admin.campuses.manage<br>Duy trì SchoolCampus làm bộ lọc vị trí tìm phòng | AdminCampusesController.list [R0179]<br>AdminCampusesController.create [R0180]<br>AdminCampusesController.update [R0181] | CB |
| UC-ADM-24<br>Tra cứu giao dịch tài chính nền tảng | ADMIN có admin.finance.read<br>Đọc dữ liệu giao dịch theo projection quản trị | AdminRegistryController.transactionList [R0030]<br>GovernanceController.finance [R0256] | CB |
| UC-ADM-25<br>Theo dõi kích hoạt và thu hồi phiên Admin | ADMIN có quyền quản trị Admin và phiên tương ứng<br>Xem lifecycle gửi lại lời mời hoặc thu hồi phiên Admin khác | AdminLifecycleController.detail [R0026]<br>AdminLifecycleController.resend [R0027]<br>AdminLifecycleController.revoke [R0028] | CB |
| UC-ADM-26<br>Mô phỏng quyền Admin | ADMIN có admin.permissions.simulate<br>Tính quyền được phép không thay hồ sơ cấp quyền | GovernanceController.simulate [R0252] | CB |
| UC-ADM-27<br>Đọc phản hồi thử nghiệm tìm phòng | ADMIN có admin.listings.moderate<br>Đọc PilotFeedback và thống kê theo trang | HousingController.feedbackList [R0164] | CB |

UC-ADM-07.1: AdminSecurityController dùng JWT trực tiếp cho bước thiết lập MFA; không gán capability giả cho endpoint này.

UC-ADM-15: Đối soát tham chiếu khoản thu đã có; không đồng nghĩa tự nhận tiền ngân hàng hoặc tự ghi Payment.

UC-ADM-18: Hai vai trò dùng endpoint khác nhau; không gán quyền xét duyệt cho chủ trọ.

UC-ADM-19: Endpoint trình hồ sơ khu hiện dành ADMIN; không ghi bước này do LANDLORD thực hiện.

### 3.9 Hỗ trợ và giám sát

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-SUP-01<br>Tạo và trao đổi hồ sơ hỗ trợ | LANDLORD TENANT hoặc ADMIN có quyền hỗ trợ<br>Theo dõi ticket công khai còn ghi chú nội bộ chỉ cho admin được cấp | SupportController.create [R0354]<br>SupportController.list [R0355]<br>SupportController.assignees [R0356]<br>SupportController.teams [R0357]<br>SupportController.detail [R0358]<br>SupportController.reply [R0359]<br>SupportController.note [R0360]<br>SupportController.assign [R0361]<br>SupportController.status [R0362]<br>AdminConsoleController.context [R0019] | CB |
| UC-SUP-02.1<br>Cấu hình phân công tự động hỗ trợ | ADMIN có quyền support tương ứng<br>Đặt skills và phân công theo khả dụng của người xử lý | SupportWorkflowController.skills [R0351]<br>SupportWorkflowController.setSkills [R0352]<br>SupportWorkflowController.autoAssign [R0353] | CB |
| UC-SUP-02.2<br>Cấu hình và theo dõi SLA hỗ trợ | ADMIN có quyền SLA<br>Lưu lịch giờ làm và chính sách thời hạn hỗ trợ | SupportSlaController.policy [R0339]<br>SupportSlaController.update [R0340] | CB |
| UC-SUP-03.1<br>Đính kèm tệp vào ticket hỗ trợ | LANDLORD TENANT hoặc ADMIN theo quyền ticket<br>Quét tệp và gắn attachment vào ticket đọc được | SupportAttachmentController.upload [R0336] | CB |
| UC-SUP-03.2<br>Quản lý mẫu nhãn và hợp nhất ticket | ADMIN có quyền support<br>Duy trì mẫu trả lời nhãn và liên kết ticket hợp nhất | SupportToolsController.templates [R0341]<br>SupportToolsController.create [R0342]<br>SupportToolsController.update [R0343]<br>SupportToolsController.labels [R0344]<br>SupportToolsController.merge [R0345]<br>SupportToolsController.feedback [R0346] | CB |
| UC-SUP-03.3<br>Lưu bộ lọc xử lý ticket | ADMIN có quyền support<br>Duy trì SupportSavedView thuộc tài khoản | SupportWorkflowController.views [R0347]<br>SupportWorkflowController.createView [R0348]<br>SupportWorkflowController.updateView [R0349]<br>SupportWorkflowController.deleteView [R0350] | CB |
| UC-SUP-03.4<br>Liên kết và xem dòng thời gian hồ sơ hỗ trợ | ADMIN có quyền hồ sơ hỗ trợ<br>Gắn tài nguyên được phép và xem sự kiện theo quyền | SupportCaseController.timeline [R0337]<br>SupportCaseController.link [R0338] | CB |
| UC-SUP-04<br>Quản lý trung tâm thông báo cá nhân | LANDLORD TENANT hoặc ADMIN theo endpoint<br>Đọc thông báo và thiết lập sở thích của chính tài khoản | NotificationCenterController.list [R0329]<br>NotificationCenterController.preferences [R0330]<br>NotificationCenterController.updatePreferences [R0331]<br>NotificationCenterController.markRead [R0332]<br>NotificationCenterController.markAllRead [R0333]<br>SupportController.listNotifications [R0363]<br>SupportController.markNotification [R0364]<br>SupportController.markAllNotifications [R0365] | CB |
| UC-SUP-05.1<br>Giám sát và xử lý sự cố vận hành | ADMIN có quyền operations<br>Đọc sự cố và thực hiện action đúng trạng thái | IncidentWorkflowController.list [R0139]<br>IncidentWorkflowController.assignees [R0140]<br>IncidentWorkflowController.detail [R0141]<br>IncidentWorkflowController.action [R0142]<br>AdminConsoleController.operationsHealth [R0024]<br>AdminConsoleController.acknowledgeIncident [R0025] | CB |
| UC-SUP-05.2<br>Theo dõi hàng đợi giao nhận | ADMIN có quyền operations<br>Đọc metadata job và thử lại notification đủ điều kiện | OperationsQueueController.list [R0143]<br>NotificationDeliveryController.queue [R0334]<br>NotificationDeliveryController.retry [R0335] | CB |
| UC-SUP-06<br>Hỏi trợ lý AI và đọc nguồn hướng dẫn | LANDLORD<br>Nhận câu trả lời từ tri thức theo scope hoặc thiếu bằng chứng | ChatbotController.ask [R0128]<br>ChatbotController.source [R0129] | CB |

UC-SUP-01: Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator.

UC-SUP-03.1: Tệp hỗ trợ có bước quét malware riêng; không áp đồng nhất quy tắc đó cho mọi upload.

UC-SUP-04: Chỉ phần endpoint cho LANDLORD TENANT ADMIN được coi truy cập được; STAFF bị chặn bởi interceptor.

### 3.10 Nhân viên của chủ trọ

| Mã và tên | Tác nhân và mục tiêu | API hoặc hàm liên quan | TT |
| --- | --- | --- | --- |
| UC-STF-01<br>Mời nhân viên và cấp phạm vi khu trọ | LANDLORD<br>Tạo lời mời với tập quyền và propertyIds thuộc mình | StaffController.presets [R0323]<br>StaffController.list [R0324]<br>StaffController.createInvite [R0325] | CB |
| UC-STF-02<br>Cập nhật quyền trạng thái và phạm vi nhân viên | LANDLORD<br>Đổi quyền preset khu được cấp và trạng thái nhân viên | StaffController.update [R0326] | CB |
| UC-STF-03<br>Mô phỏng quyền nhân viên | LANDLORD<br>Kiểm tra quyền hiệu lực mà không đổi cấp quyền | StaffController.simulate [R0327] | CB |

UC-STF-01: STAFF chỉ được list và presets khi có staff.view; không được tạo invite qua interceptor.

UC-STF-02: Dù decorator có STAFF và staff.manage, interceptor không cho STAFF tự cập nhật quyền.

### 3.11 Quan hệ giữa các Use Case

Không gán include/extend chỉ vì chung service/DTO: issueSession dùng chung là tái sử dụng kỹ thuật. UC-SYS-04 cũ chuyển thành SP-SYS-01 và SP-SYS-02, không mất chức năng phục hồi phiên. Chưa xác nhận generalization hoặc các mũi tên ở sơ đồ cũ; cần cập nhật sơ đồ theo catalog trước khi nghiệm thu.

## 4 Đặc tả chi tiết nhóm tài khoản

Chín UC dưới đây đã được đối chiếu frontend, API, service, validation, dữ liệu và test khi có. Test scenarios tại mục J là kịch bản nghiệm thu suy ra từ AS-IS, không phải cam kết mọi kịch bản đều có test tự động hoặc đã chạy E2E. Mỗi số bước là cục bộ trong UC; mã BR dùng chung và truy vết ở mục 6.

### UC-SYS-01 Đăng ký tài khoản chủ trọ

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-01 — Đăng ký tài khoản chủ trọ |
| Mô tả nghiệp vụ | Khách tự tạo tài khoản để quản lý nhà trọ. Máy chủ ấn định LANDLORD; không phải quy trình duyệt hay xác minh chủ trọ. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Khách chưa đăng nhập |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Tạo User LANDLORD và nhận phiên đăng nhập |
| Kích hoạt | Chọn mục đích làm chủ trọ trên màn hình đăng ký và bấm Đăng ký. |
| Điều kiện trước | Truy cập được màn hình đăng ký và API; email chưa thuộc User khác. Không có điều kiện phải xác minh email trước khi cấp phiên trong luồng này. |
| Hậu điều kiện thành công | User LANDLORD được tạo, API trả phiên; ứng dụng lưu phiên an toàn và chuyển tới trang chủ của chủ trọ. |
| Bảo đảm tối thiểu | Lỗi DTO hoặc trùng email không tạo thêm User. Nếu lỗi cấp phiên hoặc lưu phiên cục bộ xảy ra sau khi User đã tạo thì User có thể vẫn tồn tại; không có rollback xuyên API và thiết bị. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| fullName | string; bắt buộc | IsNotEmpty, tối đa 120; dịch vụ trim trước khi lưu. UI chặn tên chỉ có khoảng trắng; backend không có validator trim-nonblank tương đương. | Không mặc định; User.fullName |
| email | string; bắt buộc | IsEmail; dịch vụ trim và lowercase; ràng buộc unique trên User.email. DTO này không có MaxLength email. | Không mặc định; User.email |
| phone | string; bắt buộc | IsPhoneNumber; UI chuẩn hóa số Việt Nam và loại khoảng trắng, dấu chấm, gạch, ngoặc trước khi gửi. | Không mặc định; User.phone |
| password | string; bắt buộc | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | Lưu passwordHash Argon2, không lưu bản rõ |
| confirmPassword; đồng ý điều khoản | Chỉ có trên UI | Nhập lại phải trùng; ô đồng ý phải được chọn để gửi biểu mẫu. | Không thuộc request; không có bằng chứng lưu thời điểm đồng ý |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Khách | Chọn đăng ký làm chủ trọ; nhập họ tên, email, điện thoại, mật khẩu và xác nhận. | Biểu mẫu hiển thị lỗi ngay tại trường khi không đạt điều kiện UI. |
| 2 | Khách | Đồng ý điều khoản rồi gửi biểu mẫu hợp lệ. | UI chuẩn hóa tên và điện thoại; gọi POST /api/v1/auth/register. |
| 3 | Hệ thống | Áp dụng DTO, chuẩn hóa email; băm mật khẩu rồi tạo User LANDLORD. | Email duy nhất; không tạo Property, Room hoặc Lease trong thao tác này. |
| 4 | Hệ thống | Cấp AuthSession, access token và refresh token cho User vừa tạo. | Trả HTTP 201 với danh tính và cặp token. |
| 5 | Ứng dụng | Kiểm tra vai trò hỗ trợ, ghi secure storage và cập nhật trạng thái đăng nhập. | Điều hướng tới homeRouteForSession của LANDLORD; đây là điểm thành công trên UI. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 1 | Chọn mục đích tìm phòng | Dùng UC-SYS-02 với endpoint register-seeker, không gửi trường role cho endpoint đăng ký chủ trọ. | Kết thúc nhánh này; sang UC-SYS-02. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2–3 | Trường thiếu, sai định dạng hoặc trường role tự chèn | UI chặn; nếu gọi API trực tiếp thì HTTP 400 từ validation/whitelist. | Không tạo User. |
| E2 / 3 | Email đã tồn tại; Prisma P2002 | HTTP 409 EMAIL_ALREADY_REGISTERED; UI cho sửa email. | User cũ không thay đổi. |
| E3 / 2 | Vượt 5 yêu cầu trong 60 giây ở endpoint | Throttle từ chối HTTP 429. | Yêu cầu bị từ chối trước nghiệp vụ. |
| E4 / 4–5 | Cấp phiên hoặc lưu secure storage thất bại | Lỗi được truyền về; UI có thông báo thất bại, không được khẳng định đã đăng nhập. | User có thể đã được tạo; lỗi máy chủ từ 500 được filter chuẩn hóa. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-01 | registerAccount luôn dùng UserRole.LANDLORD cho endpoint register; input không quyết định vai trò. | [E007] |
| BR-02 | Email được lowercase và trim trước khi tạo; email trùng bị từ chối. | [E007] |
| BR-03 | Mật khẩu mới phải đạt đủ bốn nhóm ký tự và 12–128 ký tự tại backend. | [E027] |

#### G Phân quyền và bảo mật

Endpoint công khai, không cần JWT. Không có quyền đăng ký ADMIN hoặc STAFF qua endpoint này. Terms và xác nhận mật khẩu là kiểm tra UI, không phải bằng chứng chấp thuận được lưu tại backend.

#### H Kết quả và dữ liệu sau thao tác

Tạo User rồi cấp phiên qua một bước riêng. Chưa tạo khu trọ, hồ sơ xác minh, gói trả phí hoặc hợp đồng. Phiên được lưu cục bộ chỉ sau phản hồi hợp lệ.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E043 | lib/features/auth/register_screen.dart:79 | RegisterScreen._submit |
| E001 | backend/src/auth/auth.controller.ts:18 | AuthController.register |
| E007 | backend/src/auth/auth.service.ts:45 | AuthService.registerAccount |
| E027 | backend/src/auth/dto/register.dto.ts:4 | RegisterDto |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E054 | lib/features/auth/auth_navigation.dart:264 | homeRouteForSession |
| E037 | backend/prisma/schema.prisma:177 | User |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |
| E069 | test/features/auth/register_screen_test.dart:152 | RegisterScreen tests; validate/register two purposes |
| E070 | backend/src/auth/auth.service.spec.ts:57 | AuthService tests; register, duplicate, inactive, change password |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-01-AC1 | Dữ liệu hợp lệ và email mới | Nhận 201, User.role LANDLORD, passwordHash không bằng mật khẩu, UI tới dashboard. |
| UC-SYS-01-AC2 | Thiếu một nhóm ký tự hoặc mật khẩu 11 ký tự | UI không gửi; gọi API trực tiếp bị 400; không tạo User. |
| UC-SYS-01-AC3 | Email đã tồn tại | 409 EMAIL_ALREADY_REGISTERED, không tăng số User. |
| UC-SYS-01-AC4 | Gửi role=ADMIN trực tiếp | 400 do forbidNonWhitelisted; không tạo ADMIN. |
| UC-SYS-01-AC5 | Gây lỗi bước cấp phiên sau khi tạo User | Không giả định rollback User; kiểm tra User có thể tồn tại và chưa có phiên sử dụng được. |

### UC-SYS-02 Đăng ký tài khoản tìm phòng

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-02 — Đăng ký tài khoản tìm phòng |
| Mô tả nghiệp vụ | Khách tạo tài khoản để lưu tin và tham gia hành trình tìm phòng. Tên nghiệp vụ là người tìm phòng nhưng vai trò lưu trong User là TENANT. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Khách tìm phòng |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Tạo User TENANT chưa tự sinh Tenant hay Lease |
| Kích hoạt | Giữ lựa chọn mặc định tìm phòng và gửi đăng ký. |
| Điều kiện trước | Email chưa có User. Không yêu cầu có hồ sơ Tenant hay hợp đồng trước khi đăng ký. |
| Hậu điều kiện thành công | User TENANT được tạo, ứng dụng lưu phiên và mở trang khám phá. Không tự liên kết hồ sơ người thuê của một chủ trọ. |
| Bảo đảm tối thiểu | Lỗi trước khi tạo không sinh User; lỗi cấp/lưu phiên sau tạo không bảo đảm xóa User vừa tạo. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| fullName | string; bắt buộc | IsNotEmpty, tối đa 120; trim khi lưu; cùng chênh lệch whitespace giữa UI và backend như UC-SYS-01. | User.fullName |
| email | string; bắt buộc | IsEmail; trim + lowercase khi lưu; unique. Không có MaxLength tại RegisterDto. | User.email |
| phone | string; bắt buộc | IsPhoneNumber; UI chuẩn hóa số trước gửi. | User.phone |
| password | string; bắt buộc | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | Argon2 trong User.passwordHash |
| confirmPassword; đồng ý điều khoản | UI; bắt buộc để gửi | Nhập lại trùng và chọn đồng ý; không gửi hai trường này tới API. | Không có cột chấp thuận trong luồng |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Khách | Mở đăng ký, chọn tìm phòng, nhập thông tin và xác nhận mật khẩu. | Mục đích tìm phòng được chọn mặc định trong RegisterScreen. |
| 2 | Khách | Chọn đồng ý và gửi. | UI kiểm tra biểu mẫu rồi gọi POST /api/v1/auth/register-seeker. |
| 3 | Hệ thống | Xác thực DTO, chuẩn hóa email và băm mật khẩu. | Tạo duy nhất User với role TENANT. |
| 4 | Hệ thống | Cấp phiên cho danh tính vừa tạo. | HTTP 201 chứa token và user; không tạo Tenant, Lease, đặt cọc hay quyền vào khu trọ. |
| 5 | Ứng dụng | Lưu phiên và áp dụng homeRouteForSession. | Mở trang explore; người dùng có tài khoản tìm phòng, chưa đồng nghĩa người thuê có hợp đồng. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 1 | Người dùng thực sự cần tài khoản chủ trọ | Đổi lựa chọn sang chủ trọ và thực hiện UC-SYS-01. | Chuyển UC; không đổi role bằng tham số API. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2–3 | Đầu vào sai DTO hoặc trường ngoài danh sách | 400; UI thường chặn trước khi gửi. | Không tạo User. |
| E2 / 3 | Email của seeker, landlord, staff hay admin đã tồn tại | 409 EMAIL_ALREADY_REGISTERED; không hợp nhất hay chuyển vai trò. | Tài khoản có sẵn giữ nguyên. |
| E3 / 2 | Vượt throttle 5 lần/60 giây | 429; UI báo chờ gửi lại. | Không tạo User cho request bị chặn. |
| E4 / 4–5 | Cấp phiên/lưu cục bộ thất bại | Thông báo lỗi; 5xx backend qua ApiErrorFilter. | User có thể đã tồn tại sau bước 3. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-04 | register-seeker ấn định UserRole.TENANT, không có role SEEKER trong schema. | [E008] |
| BR-05 | Luồng đăng ký tìm phòng không tự tạo Tenant và Lease. | [E007] |
| BR-06 | Home của TENANT là trang khám phá; điều kiện nghiệp vụ các màn hình cổng thuê được xét riêng. | [E054] |

#### G Phân quyền và bảo mật

Công khai; không được tự chỉ định chủ trọ hoặc phòng. Đăng ký email đã thuộc hồ sơ được mời không tự gắn hồ sơ Tenant; luồng accept riêng không tự merge tài khoản seeker.

#### H Kết quả và dữ liệu sau thao tác

Chỉ danh tính và phiên được tạo; không có ràng buộc thuê nhà mới. Cần phân biệt User TENANT với bản ghi Tenant gắn landlordId.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E043 | lib/features/auth/register_screen.dart:79 | RegisterScreen._submit |
| E002 | backend/src/auth/auth.controller.ts:25 | AuthController.registerSeeker |
| E008 | backend/src/auth/auth.service.ts:41 | AuthService.registerSeeker |
| E007 | backend/src/auth/auth.service.ts:45 | AuthService.registerAccount |
| E027 | backend/src/auth/dto/register.dto.ts:4 | RegisterDto |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E054 | lib/features/auth/auth_navigation.dart:264 | homeRouteForSession |
| E037 | backend/prisma/schema.prisma:177 | User |
| E038 | backend/prisma/schema.prisma:816 | Tenant |
| E069 | test/features/auth/register_screen_test.dart:152 | RegisterScreen tests; validate/register two purposes |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-02-AC1 | Đăng ký seeker hợp lệ | User TENANT, không tự có Tenant/Lease, điều hướng explore. |
| UC-SYS-02-AC2 | Gửi email đã dùng ở vai trò khác | 409; không chuyển vai trò hoặc gộp danh tính. |
| UC-SYS-02-AC3 | Bỏ chọn điều khoản hoặc xác nhận khác mật khẩu | UI không gửi request; đây không phải kiểm tra được lưu backend. |
| UC-SYS-02-AC4 | Gửi tên chỉ toàn khoảng trắng qua API | Ghi nhận khác biệt: DTO IsNotEmpty không trim, dịch vụ lưu chuỗi đã trim; không kỳ vọng lỗi nonblank chưa triển khai. |

### UC-SYS-03 Đăng nhập

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-03 — Đăng nhập |
| Mô tả nghiệp vụ | Xác minh thông tin đăng nhập, áp dụng MFA cho Admin đã bật, cấp phiên và điều hướng theo quyền thực tế. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người có tài khoản |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Nhận phiên đúng danh tính và điều hướng theo vai trò |
| Kích hoạt | Bấm Đăng nhập trên LoginScreen. |
| Điều kiện trước | User tồn tại và isActive=true; biết mật khẩu; Admin đã bật MFA cần mã hợp lệ. Không suy rằng STAFF bị khóa profile sẽ bị chặn ngay tại bước login. |
| Hậu điều kiện thành công | Nhận phiên, lưu phiên và tới màn hình hợp lệ với vai trò. Admin chưa hoàn tất MFA bắt buộc có thể được dẫn tới trang bảo mật thay vì nghiệp vụ quản trị. |
| Bảo đảm tối thiểu | Sai danh tính không cấp phiên mới; lỗi lưu cục bộ có thể xảy ra sau khi phiên backend đã tạo. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| email | string; bắt buộc | IsEmail; normalizeEmail trim và lowercase khi tìm User. | Không mặc định |
| password | string; bắt buộc | 1–128 ký tự; không áp quy tắc 12 ký tự của mật khẩu mới để loại tài khoản cũ. | Không lưu bản rõ |
| mfaCode | string; tùy chọn trong DTO | Nếu cung cấp: 6–64 ký tự; bắt buộc theo nghiệp vụ khi AdminProfile.mfaEnabled=true. | TOTP hoặc recovery code |
| Ghi nhớ đăng nhập; next | UI / điều hướng | Checkbox không truyền đến API, không quyết định TTL; next chỉ được dùng nếu là địa điểm khám phá công khai. | Secure storage vẫn được dùng khi login thành công |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người dùng | Nhập email và mật khẩu rồi gửi. | UI kiểm tra trường và gọi POST /api/v1/auth/login. |
| 2 | Hệ thống | Tìm User theo email chuẩn hóa; kiểm tra isActive và Argon2. | Không phân biệt lý do sai email, khóa User hay sai mật khẩu trong INVALID_CREDENTIALS. |
| 3 | Hệ thống | Nếu là ADMIN đã bật MFA, xác minh mfaCode trước khi cấp phiên. | Không cần mã cho tài khoản không thuộc điều kiện MFA này. |
| 4 | Hệ thống | Tạo phiên với sessionVersion hiện hành và trạng thái MFA. | Endpoint POST mặc định trả 201; không tự gán 200 vào đặc tả. |
| 5 | Ứng dụng | Ghi secure storage, cập nhật SessionController và điều hướng. | next công khai hợp lệ được ưu tiên; còn lại dùng homeRouteForSession, kể cả trang thiết lập MFA cho admin cần hoàn thiện. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 3 | Admin yêu cầu MFA | UI yêu cầu mã sau MFA_REQUIRED; gửi lại thông tin với mã; backend kiểm tra TOTP hoặc recovery code. | Hợp lệ quay lại bước 4. |
| A2 / 5 | ADMIN cần MFA nhưng chưa bật | Đã có phiên mfa=false; router dẫn tới trang bảo mật, guard nghiệp vụ quản trị tiếp tục kiểm soát MFA. | Kết thúc login; không khẳng định có đầy đủ quyền Admin. |
| A3 / 5 | Có next công khai hợp lệ | Điều hướng tới next; next không hợp lệ không được dùng để mở tùy ý màn hình nội bộ. | Kết thúc UC. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 1 | Sai DTO: email, password rỗng/quá 128, mã MFA ngoài 6–64 | HTTP 400 hoặc UI chặn. | Chưa cấp phiên. |
| E2 / 2 | Không tìm thấy User, User inactive hoặc mật khẩu sai | 401 INVALID_CREDENTIALS. | Không tạo AuthSession mới. |
| E3 / 3 | MFA thiếu, sai hoặc TOTP đã dùng | 401 MFA_REQUIRED hoặc INVALID_MFA_CODE. | Không cấp phiên login mới; recovery code hợp lệ được tiêu thụ khi kiểm chứng. |
| E4 / 1 | Vượt 10 lần/60 giây | 429. | Request bị chặn. |
| E5 / 5 | STAFF có profile hoặc chủ trọ đã inactive | JWT strategy từ chối khi gọi endpoint được bảo vệ; login không kiểm tra toàn bộ điều kiện này. | Không được coi phiên có thể thao tác STAFF chỉ vì login trả token. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-07 | User không có, inactive hoặc mật khẩu sai cùng nhận INVALID_CREDENTIALS. | [E009] |
| BR-08 | MFA cho Admin đã bật được kiểm chứng trước issueSession; TOTP có kiểm tra chống dùng lại. | [E026] |
| BR-09 | Checkbox ghi nhớ không thay đổi dữ liệu request hay thời hạn phiên. | [E044] |

#### G Phân quyền và bảo mật

Login là endpoint công khai. Quyền sau login còn phụ thuộc RolesGuard, AdminPermissions/MFA và PropertyScopeInterceptor; JWT strategy xét trạng thái STAFF/landlord tại request bảo vệ.

#### H Kết quả và dữ liệu sau thao tác

Tạo AuthSession và RefreshToken; access JWT mang sub, sid, ver, typ=access, mfa. Không sửa vai trò hoặc permissions chỉ vì nhập MFA.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E044 | lib/features/auth/login_screen.dart:37 | LoginScreen._submit |
| E003 | backend/src/auth/auth.controller.ts:32 | AuthController.login |
| E009 | backend/src/auth/auth.service.ts:71 | AuthService.login |
| E028 | backend/src/auth/dto/login.dto.ts:4 | LoginDto |
| E026 | backend/src/auth/admin-mfa.service.ts:66 | AdminMfaService.verify |
| E033 | backend/src/auth/jwt.strategy.ts:25 | JwtStrategy.validate |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E054 | lib/features/auth/auth_navigation.dart:264 | homeRouteForSession |
| E034 | backend/src/common/roles.guard.ts:23 | RolesGuard.canActivate |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |
| E070 | backend/src/auth/auth.service.spec.ts:57 | AuthService tests; register, duplicate, inactive, change password |
| E071 | backend/src/auth/jwt.strategy.spec.ts:20 | JwtStrategy tests |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-03-AC1 | Thông tin đúng của LANDLORD | 201, phiên được lưu, mở dashboard. |
| UC-SYS-03-AC2 | Email không có/sai mật khẩu/User inactive | Đều 401 INVALID_CREDENTIALS, không cấp phiên. |
| UC-SYS-03-AC3 | Admin đã bật MFA nhưng không gửi mã | MFA_REQUIRED; mã sai hoặc dùng lại bị INVALID_MFA_CODE. |
| UC-SYS-03-AC4 | Mật khẩu tài khoản cũ có ít hơn 12 ký tự nhưng đúng hash | Không bị DTO login loại chỉ vì quy tắc tạo mật khẩu mới. |
| UC-SYS-03-AC5 | Bỏ chọn ghi nhớ đăng nhập | Request không có rememberMe và cơ chế lưu phiên không đổi. |

### UC-SYS-05.1 Đăng xuất phiên hiện tại

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-05.1 — Đăng xuất phiên hiện tại |
| Mô tả nghiệp vụ | Rời phiên trên thiết bị hiện tại và yêu cầu máy chủ thu hồi phiên gắn với refresh token gửi lên. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người dùng đang có phiên trên ứng dụng |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Thu hồi phiên gắn refresh token và rời phiên cục bộ |
| Kích hoạt | Chọn Đăng xuất trong giao diện tài khoản. |
| Điều kiện trước | Ứng dụng có thể đọc phiên cục bộ; API logout không yêu cầu access JWT còn hiệu lực. |
| Hậu điều kiện thành công | Khi request tới máy chủ thành công: phiên liên quan và token của phiên bị thu hồi; bộ nhớ phiên cục bộ bị xóa, trạng thái chuyển chưa đăng nhập. |
| Bảo đảm tối thiểu | Mã ứng dụng dùng finally để dọn phiên kể cả request logout lỗi. Nếu mạng lỗi trước khi máy chủ xử lý, không bảo đảm phiên từ xa đã bị thu hồi. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| refreshToken | string; bắt buộc tại API | MinLength 32; DTO không quy định MaxLength. Token được hash để tra cứu. | Lấy từ secure storage; không cho nhập thủ công trên UI |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người dùng | Chọn Đăng xuất. | SessionController gọi AuthRepository.logout; không giả định có hộp thoại xác nhận. |
| 2 | Ứng dụng | Đọc phiên và gửi refreshToken nếu có. | POST /api/v1/auth/logout; không cần Authorization hợp lệ. |
| 3 | Hệ thống | Tra token; thu hồi phiên sid và các refresh token của phiên đó nếu tìm thấy. | HTTP 204 không body; token không tìm thấy vẫn kết thúc không lỗi. |
| 4 | Ứng dụng | Trong finally, xóa secure storage; chuyển SessionController về chưa đăng nhập. | Không còn phiên cục bộ sử dụng cho các request tiếp theo. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 2 | Không còn phiên trong storage | Bỏ qua gọi API; vẫn dọn storage và cập nhật trạng thái. | Kết thúc ở bước 4. |
| A2 / 3 | Token không có trong DB nhưng đạt DTO | Không tạo hay sửa phiên; vẫn trả 204. | Sang bước 4. |
| A3 / 3 | Token cũ không gắn sessionId | Chỉ revoke token legacy này; không suy ra thu hồi tất cả thiết bị. | Sang bước 4. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2 | refreshToken sai DTO | 400; cuối cùng ứng dụng vẫn dọn phiên cục bộ. | Không có chứng cứ remote revoke thành công. |
| E2 / 2–3 | Lỗi mạng hoặc 5xx | Lỗi truyền về, nhưng finally ở repository/controller vẫn chạy. | Local logout; remote session có thể còn hiệu lực. |
| E3 / 2 | Vượt 20 yêu cầu/60 giây | 429. | Local vẫn bị xóa; request này không revoke remote. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-10 | Logout theo refresh token, không phải xóa tài khoản hay mặc định đăng xuất tất cả thiết bị. | [E010] |
| BR-11 | Luồng finally dọn phiên local không chứng minh backend đã revoke thành công. | [E052] |

#### G Phân quyền và bảo mật

API công khai nhưng cần possession refresh token để tác động phiên tương ứng. Không cho chọn userId của tài khoản khác; access token hết hạn không ngăn yêu cầu logout.

#### H Kết quả và dữ liệu sau thao tác

Máy chủ cập nhật revokedAt; không xóa User và dữ liệu kinh doanh. Phiên khác không bị revoke bởi logout theo sid hiện tại.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E045 | lib/features/auth/auth_providers.dart:116 | SessionController.logout |
| E004 | backend/src/auth/auth.controller.ts:44 | AuthController.logout |
| E010 | backend/src/auth/auth.service.ts:137 | AuthService.logout |
| E030 | backend/src/auth/dto/refresh.dto.ts:4 | RefreshDto |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E053 | lib/features/auth/auth_providers.dart:52 | SessionController |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-05.1-AC1 | Refresh token của phiên A hợp lệ | 204, A bị thu hồi, phiên B của cùng User không bị thu hồi, local trống. |
| UC-SYS-05.1-AC2 | Token đúng độ dài nhưng không tồn tại | 204, không phát sinh bản ghi mới. |
| UC-SYS-05.1-AC3 | Ngắt mạng trước logout | Local chuyển chưa đăng nhập; không ghi nhận remote revoke là đã đạt. |
| UC-SYS-05.1-AC4 | Storage không có phiên | Không gọi API; trạng thái vẫn chưa đăng nhập. |

### UC-SYS-05.2 Xem và thu hồi các phiên của mình

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-05.2 — Xem và thu hồi các phiên của mình |
| Mô tả nghiệp vụ | Người dùng kiểm soát phiên của chính mình. API áp dụng mọi vai trò đã xác thực; màn hình quản lý phiên được xác nhận tại khu vực Admin. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người đã đăng nhập; UI đã xác nhận cho ADMIN |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Kiểm soát thiết bị đang truy cập tài khoản |
| Kích hoạt | Mở màn hình phiên, chọn thu hồi một thiết bị hoặc Đăng xuất thiết bị khác. |
| Điều kiện trước | JWT hợp lệ. Tác vụ thu hồi các phiên khác yêu cầu JWT có sid. ID phiên riêng phải là UUID. |
| Hậu điều kiện thành công | Danh sách được tải; với thao tác thu hồi, AuthSession và refresh token tương ứng được revoke và UI tải lại danh sách. |
| Bảo đảm tối thiểu | Thu hồi và audit nằm trong transaction; không được thu hồi phiên của người khác. Lỗi reload sau commit không tự hoàn tác revoke. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| id | UUID path; bắt buộc khi revoke riêng | ParseUUIDPipe; phiên phải thuộc user hiện hành và chưa revoked. | Không nhận userId từ UI |
| Dữ liệu danh sách | Read-only | Tối đa 100 phiên còn hiệu lực, userVersion hiện hành, sắp lastSeenAt giảm dần. | id, current, device, ip, thời gian |
| sid | Claim JWT | Cần cho revokeOtherSessions để giữ thiết bị hiện tại. | Không có sid: từ chối thu hồi hàng loạt |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người dùng | Mở màn hình quản lý phiên Admin. | UI gọi GET /api/v1/auth/sessions; hiển thị thiết bị hiện tại và thiết bị khác. |
| 2 | Người dùng | Chọn Thu hồi phiên này tại một thiết bị khác. | UI mở hộp thoại xác nhận; không hiển thị nút revoke cho dòng current. |
| 3 | Người dùng | Xác nhận thu hồi. | Gửi POST /api/v1/auth/sessions/:id/revoke. |
| 4 | Hệ thống | Kiểm tra phiên thuộc user và chưa revoke; thu hồi cùng refresh tokens trong transaction. | Trả data có revoked=true và sessionId. |
| 5 | Ứng dụng | Tải lại danh sách. | Thiết bị bị thu hồi không còn trong danh sách phiên active; UI hiện kết quả thao tác. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 2 | Chọn Đăng xuất thiết bị khác | Xác nhận; gọi POST sessions/revoke-all; backend giữ sid hiện tại, revoke phiên khác và refresh legacy không sid. | Trả số lượng; sang bước 5. |
| A2 / 3 | Hủy hộp thoại xác nhận | Không gọi revoke. | Quay lại danh sách bước 1. |
| A3 / 3 | Gọi API trực tiếp với ID phiên hiện tại | API không cấm revoke own current; UI thì ẩn nút này. | Phiên hiện tại mất quyền ở request bảo vệ sau. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 1–4 | JWT thiếu/hết hiệu lực/phiên bị revoke | 401 từ JWT strategy. | Không đọc hoặc sửa phiên. |
| E2 / 3 | id không là UUID | 400. | Chưa cập nhật DB. |
| E3 / 4 | Phiên của user khác, không tồn tại hoặc đã revoked | 404 SESSION_NOT_FOUND. | Không ảnh hưởng phiên người khác. |
| E4 / A1 | JWT legacy không sid | 401 với thông báo yêu cầu đăng nhập lại để quản lý phiên. | Không revoke hàng loạt. |
| E5 / 5 | Reload danh sách lỗi sau commit | UI báo lỗi tải; transaction thu hồi đã hoàn thành không bị rollback. | Phiên mục tiêu vẫn bị thu hồi. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-12 | Danh sách không trả phiên hết hạn, revoked hay userVersion cũ; giới hạn take=100. | [E011] |
| BR-13 | Revoke-all thực chất giữ sid hiện tại, không đồng nghĩa đăng xuất toàn bộ thiết bị. | [E013] |
| BR-14 | Mọi thao tác chỉ tác động phiên có userId bằng current user. | [E012] |

#### G Phân quyền và bảo mật

AuthGuard(jwt), không có role decorator riêng. Endpoint quản lý own sessions được PropertyScopeInterceptor cho phép qua AuthController. Chưa xác nhận UI phiên tương đương cho LANDLORD/TENANT/STAFF.

#### H Kết quả và dữ liệu sau thao tác

Chỉ thay revokedAt ở phiên/token và audit. Không sửa passwordHash hoặc tăng sessionVersion bởi thao tác này.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E046 | lib/features/admin/admin_sessions_screen.dart:10 | AdminSessionsScreen |
| E005 | backend/src/auth/auth.controller.ts:59 | AuthController.sessions |
| E011 | backend/src/auth/auth.service.ts:212 | AuthService.sessions |
| E012 | backend/src/auth/auth.service.ts:232 | AuthService.revokeSession |
| E013 | backend/src/auth/auth.service.ts:244 | AuthService.revokeOtherSessions |
| E033 | backend/src/auth/jwt.strategy.ts:25 | JwtStrategy.validate |
| E035 | backend/src/common/property-scope.ts:44 | PropertyScopeInterceptor |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |
| E077 | backend/test/e2e/admin-next-sprints.e2e-spec.ts:42 | Own-session revoke E2E source; chưa chạy |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-05.2-AC1 | User A đọc phiên | Chỉ tối đa 100 active sessions của A; IP đã mask theo cơ chế cấp phiên. |
| UC-SYS-05.2-AC2 | A gửi UUID phiên B | 404 SESSION_NOT_FOUND; B giữ nguyên. |
| UC-SYS-05.2-AC3 | Thu hồi thiết bị khác | Phiên hiện tại giữ hiệu lực; phiên bị revoke thất bại ở request bảo vệ tiếp theo. |
| UC-SYS-05.2-AC4 | Hủy hộp thoại | Không có request revoke. |
| UC-SYS-05.2-AC5 | Gọi revoke-all bằng JWT không sid | 401; không revoke dữ liệu. |

### UC-SYS-06 Khôi phục mật khẩu bằng liên kết một lần

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-06 — Khôi phục mật khẩu bằng liên kết một lần |
| Mô tả nghiệp vụ | Yêu cầu liên kết khôi phục bằng email và đổi mật khẩu khi sở hữu token còn hiệu lực. Phản hồi yêu cầu gửi thư không xác nhận tài khoản tồn tại hoặc thư đã được gửi. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người có tài khoản và người sở hữu liên kết một lần |
| Tác nhân phối hợp | Dịch vụ giao nhận email nếu được cấu hình; chỉ ở nhánh gửi của UC-SYS-06. Không coi email đã giao khi mới enqueue. |
| Mục tiêu | Đặt lại mật khẩu qua token giao nhận riêng |
| Kích hoạt | Chọn Quên mật khẩu; sau đó mở liên kết hoặc nhập token trên màn hình đặt mật khẩu. |
| Điều kiện trước | Giai đoạn yêu cầu: email hợp lệ. Để thực sự enqueue: User active, DeliveryService configured và AUTH_PUBLIC_APP_URL là HTTPS. Để redeem: token hợp lệ, chưa dùng, chưa hết hạn và User active. |
| Hậu điều kiện thành công | PasswordHash được đổi trong transaction; token được tiêu thụ; sessionVersion tăng, refresh token bị revoke. UI yêu cầu đăng nhập lại khi toàn bộ chuỗi giao diện kết thúc không lỗi. |
| Bảo đảm tối thiểu | Token sai hoặc lỗi trong transaction không đổi password. Lỗi logout/UI sau khi redeem đã commit không hoàn tác mật khẩu mới. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| email | string; bắt buộc ở forgot | IsEmail, tối đa 254. Chuẩn hóa khi tra User. | Không mặc định |
| token | string; bắt buộc ở redeem | 32–128 ký tự; backend tra tokenHash; expiresAt phải trong tương lai, consumedAt null. | Token sinh 32 random bytes, không lưu bản rõ ở AccountAccessToken |
| password | string; bắt buộc ở redeem | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | User.passwordHash |
| confirmPassword | UI-only | Phải trùng mật khẩu mới; không gửi API. | Không lưu DB |
| expiresAt | Timestamp; máy chủ sinh | Token được enqueue có thời hạn 30 phút; liên kết đặt token trong fragment. | AccountAccessToken, DeliveryJob mã hóa payload |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người dùng | Mở Quên mật khẩu, nhập email và yêu cầu gửi. | UI gọi POST /api/v1/auth/account-access/forgot. |
| 2 | Hệ thống | Nếu User active và kênh sẵn sàng thì tạo token, vô hiệu token cũ cùng purpose, enqueue DeliveryJob. | Luôn trả cùng thông báo trung tính cho trường hợp không có User hoặc không gửi được; không khẳng định đã giao email. |
| 3 | Người dùng | Mở liên kết nhận được; nhập mật khẩu mới và nhập lại. | UI kiểm tra token/mật khẩu rồi gọi POST /api/v1/auth/account-access/redeem. |
| 4 | Hệ thống | Kiểm tra token và User; tiêu thụ có điều kiện trong transaction, đổi passwordHash, tăng sessionVersion, revoke refresh và dọn token/job còn lại. | Trả data.signInAgain=true; không cấp cặp token đăng nhập mới. |
| 5 | Ứng dụng | Gọi logout, dọn local session và hiển thị thông báo mật khẩu đã cập nhật khi không lỗi. | Người dùng bấm Đăng nhập; các phiên theo version cũ không dùng tiếp được. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 2 | Email không có/inactive, kênh chưa cấu hình hoặc lỗi gửi | Không tiết lộ lý do; trả cùng thông báo. | Kết thúc yêu cầu; chưa đổi mật khẩu. |
| A2 / 2 | Non-admin yêu cầu gửi lại quá sớm hoặc đã 5 lần/giờ | enqueue phát sinh rate-limit nội bộ nhưng forgot bắt và không tiết lộ qua phản hồi trung tính. | Không hứa thư mới được tạo. |
| A3 / 3 | Có token account activation thay vì reset | redeem dùng chung AccountAccessToken, không kiểm tra purpose riêng ở thao tác redeem. | Nếu hợp lệ vẫn đi bước 4; ghi nhận AS-IS thay vì bịa purpose-specific validation. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 1 hoặc 3 | Email quá 254, token ngoài 32–128 hoặc password sai | 400 tại DTO; UI có kiểm tra trường. | Chưa đổi mật khẩu. |
| E2 / 4 | Token không tồn tại/đã dùng/hết hạn hoặc User inactive | 401 từ redeem. | Không đổi password trong giao dịch thất bại. |
| E3 / 4 | Token bị tiêu thụ đồng thời; updateMany count=0 | 409 conflict. | Chỉ một lần tiêu thụ được commit. |
| E4 / 1 hoặc 3 | Vượt endpoint throttle 5 lần/60 giây | 429 tại controller throttle; khác rate-limit gửi nội bộ bị swallowed. | Request bị chặn trước service. |
| E5 / 5 | Logout sau redeem thành công bị lỗi mạng | UI hiển thị thông báo lỗi chung về liên kết/dịch vụ. | Password đã đổi; không được ghi bảo đảm password cũ còn dùng. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-15 | Forgot không tiết lộ email có trong hệ thống hoặc kết quả enqueue. | [E017] |
| BR-16 | Token enqueue có thời hạn 30 phút; một lần sử dụng nhờ tiêu thụ có điều kiện trong transaction. | [E018] |
| BR-17 | Redeem tăng sessionVersion và revoke refresh, không tự đăng nhập lại. | [E018] |

#### G Phân quyền và bảo mật

Cả hai endpoint công khai. Quyền đổi mật khẩu dựa trên possession token, không dựa trên role được gửi trong request. Không lưu token bản rõ trong AccountAccessToken; payload giao nhận được mã hóa.

#### H Kết quả và dữ liệu sau thao tác

Thay User.passwordHash và sessionVersion; consumedAt các token, revokedAt refresh, cancellation các job chưa hoàn thành và audit trong transaction. AuthSession cũ bị vô hiệu qua version, không khẳng định tất cả rows đã gán revokedAt.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E048 | lib/features/auth/password_recovery_dialog.dart:12 | PasswordRecoveryDialog |
| E049 | lib/features/auth/account_access_screen.dart:32 | AccountAccessScreen._submit |
| E020 | backend/src/auth/account-access.controller.ts:19 | AccountAccessController.forgot |
| E017 | backend/src/auth/account-access.service.ts:47 | AccountAccessService.forgot |
| E018 | backend/src/auth/account-access.service.ts:54 | AccountAccessService.redeem |
| E040 | backend/prisma/schema.prisma:1771 | AccountAccessToken |
| E070 | backend/src/auth/auth.service.spec.ts:57 | AuthService tests; register, duplicate, inactive, change password |
| E073 | backend/src/auth/account-access.service.spec.ts:4 | Account access send rate-limit unit test |
| E074 | test/features/auth/account_access_test.dart:10 | Account access link parsing and recovery UI tests |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-06-AC1 | User active, kênh sẵn sàng, token mới | Tạo job và token 30 phút; redeem đúng đổi hash, version tăng, signInAgain=true. |
| UC-SYS-06-AC2 | Email không tồn tại so với tồn tại | Cùng thông báo forgot; không dùng response để suy thư đã giao. |
| UC-SYS-06-AC3 | Token hết hạn hoặc dùng lại | 401; hash/version không đổi bởi request thất bại. |
| UC-SYS-06-AC4 | Hai redeem đồng thời | Tối đa một lần commit; request thua bị từ chối. |
| UC-SYS-06-AC5 | Redeem commit rồi logout lỗi | Mật khẩu mới có hiệu lực dù UI báo lỗi chung; phải kiểm tra trạng thái thực tế. |

### UC-SYS-07 Đổi mật khẩu khi đang đăng nhập

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-07 — Đổi mật khẩu khi đang đăng nhập |
| Mô tả nghiệp vụ | Người đã xác thực thay mật khẩu bằng cách chứng minh mật khẩu hiện tại, sau đó phải đăng nhập lại. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người đã đăng nhập ở bất kỳ vai trò được hỗ trợ |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Thay mật khẩu sau khi xác minh mật khẩu hiện tại |
| Kích hoạt | Mở chức năng đổi mật khẩu và gửi mật khẩu hiện tại cùng mật khẩu mới. |
| Điều kiện trước | JWT hợp lệ; User active; biết mật khẩu hiện tại. Không yêu cầu quyền quản trị hay truyền userId. |
| Hậu điều kiện thành công | PasswordHash mới được commit, sessionVersion tăng và refresh tokens của User bị revoke; ứng dụng dọn phiên và yêu cầu đăng nhập lại. |
| Bảo đảm tối thiểu | Sai mật khẩu hoặc hash bị đổi trước khi khóa giao dịch: không cập nhật mật khẩu bởi yêu cầu này. Lỗi sau commit không hoàn tác hash mới. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| currentPassword | string; bắt buộc | 1–128 ký tự; phải khớp Argon2 của User hiện hành. | Không trim tự ý |
| newPassword | string; bắt buộc | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | Không có quy tắc bắt buộc khác mật khẩu cũ trong DTO/service |
| Biểu mẫu người thuê | Hai trường current và next | TenantChangePasswordScreen không có trường nhập lại; UI chỉ chặn current rỗng và next ngắn hơn 12. Các nhóm ký tự và tối đa 128 do backend kiểm soát. | Không tự thêm bước xác nhận chưa có |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người dùng | Nhập mật khẩu hiện tại và mật khẩu mới trên màn hình đổi mật khẩu. | Biểu mẫu thông báo lỗi trường trước khi gửi nếu không hợp lệ. |
| 2 | Ứng dụng | Gửi request đã xác thực. | POST /api/v1/auth/change-password không nhận userId đích. |
| 3 | Hệ thống | Đọc User active, kiểm chứng mật khẩu hiện tại; khóa User và kiểm tra hash vẫn như đã kiểm chứng. | Sai hoặc thay đổi đồng thời bị INVALID_CREDENTIALS. |
| 4 | Hệ thống | Cập nhật hash, tăng sessionVersion và revoke mọi refresh của User trong transaction. | HTTP 204; không trả phiên mới. |
| 5 | Ứng dụng | SessionController gọi logout rồi chuyển chưa đăng nhập; bỏ qua lỗi remote logout trong chuỗi changePassword. | Người dùng được yêu cầu đăng nhập lại bằng mật khẩu mới. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 4 | Mật khẩu mới bằng mật khẩu hiện tại nhưng đạt chính sách tạo mới | Không thấy kiểm tra khác mật khẩu cũ; vẫn có thể đổi hash và tăng version. | Tiếp tục bước 5; không thêm lỗi PASSWORD_UNCHANGED chưa có. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2 | JWT thiếu/hết hạn/đã mất hiệu lực | 401. | Không cập nhật User. |
| E2 / 2 | currentPassword rỗng hoặc newPassword không đạt DTO | 400. | Chưa đổi mật khẩu. |
| E3 / 3 | User inactive, mật khẩu hiện tại sai hoặc hash thay đổi đồng thời | 401 INVALID_CREDENTIALS. | Không commit thay đổi của request này. |
| E4 / 4 | Lỗi giao dịch cập nhật/revoke | Exception qua filter 5xx; transaction rollback. | Không có commit một phần trong transaction; không suy lý do DB cụ thể chưa có mapping. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-18 | Đổi mật khẩu chỉ áp dụng current user; không nhận userId đích. | [E006] |
| BR-19 | Hash phải còn đúng như lúc xác minh sau khi khóa User trước cập nhật. | [E014] |
| BR-20 | sessionVersion tăng và refresh revoke buộc các phiên version cũ bị từ chối về sau. | [E014] |

#### G Phân quyền và bảo mật

AuthGuard(jwt), không role-specific permission; STAFF vẫn có đường AuthController được cho phép. Không chứng minh chức năng yêu cầu MFA riêng tại endpoint này.

#### H Kết quả và dữ liệu sau thao tác

Không xóa AuthSession rows; version cũ làm mất hiệu lực. Không sửa email/role/hợp đồng. UI xóa phiên local sau backend success; lỗi remote logout không phục hồi mật khẩu cũ.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E047 | lib/features/tenant_portal/tenant_change_password_screen.dart:8 | TenantChangePasswordScreen |
| E006 | backend/src/auth/auth.controller.ts:80 | AuthController.changePassword |
| E014 | backend/src/auth/auth.service.ts:159 | AuthService.changePassword |
| E029 | backend/src/auth/dto/change-password.dto.ts:4 | ChangePasswordDto |
| E053 | lib/features/auth/auth_providers.dart:52 | SessionController |
| E033 | backend/src/auth/jwt.strategy.ts:25 | JwtStrategy.validate |
| E037 | backend/prisma/schema.prisma:177 | User |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |
| E070 | backend/src/auth/auth.service.spec.ts:57 | AuthService tests; register, duplicate, inactive, change password |
| E072 | test/features/auth/session_cache_isolation_test.dart:113 | Password change and cache isolation tests |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-07-AC1 | JWT và mật khẩu hiện tại đúng; mật khẩu mới đạt | 204; hash thay đổi, version+1, refresh bị revoke, local chưa đăng nhập. |
| UC-SYS-07-AC2 | Mật khẩu hiện tại sai | 401; hash/version không đổi. |
| UC-SYS-07-AC3 | Không JWT | 401; không cập nhật. |
| UC-SYS-07-AC4 | Mật khẩu mới đủ 12 ký tự nhưng thiếu ký tự đặc biệt | UI người thuê có thể gửi vì chỉ kiểm tra độ dài tối thiểu; backend trả 400. |
| UC-SYS-07-AC5 | Đổi đồng thời với một thao tác đã thay hash | Yêu cầu không còn khớp hash sau khóa bị từ chối, không ghi đè thay đổi trước. |

### UC-SYS-08 Kích hoạt tài khoản người thuê từ lời mời

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-08 — Kích hoạt tài khoản người thuê từ lời mời |
| Mô tả nghiệp vụ | Người nhận dùng mã mời để tạo User TENANT và gắn vào hồ sơ Tenant do chủ trọ đã tạo. Không phải đăng ký seeker hay gộp tài khoản có sẵn. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người sở hữu mã lời mời người thuê |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Tạo User TENANT gắn Tenant đã được mời |
| Kích hoạt | Mở màn hình nhận lời mời, điền mã và mật khẩu rồi xác nhận. |
| Điều kiện trước | TenantInvite chưa chấp nhận và chưa hết hạn; Tenant active, chưa có userId; landlord active. Email lời mời chưa tồn tại trong User. |
| Hậu điều kiện thành công | Trong transaction tạo User TENANT, gắn Tenant.userId và acceptedAt; sau commit cấp phiên, UI lưu và điều hướng theo vai trò. |
| Bảo đảm tối thiểu | Lời mời sai hoặc email trùng làm transaction không commit. Lỗi issueSession sau commit không hoàn tác liên kết Tenant đã kích hoạt. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| inviteCode | string; bắt buộc | 16–256 ký tự theo DTO; server hash trước tra; không nhận tenantId/userId tùy ý. | TenantInvite.tokenHash |
| password | string; bắt buộc | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | User.passwordHash Argon2 |
| email, fullName, phone | Không nhập mới trong request accept | Lấy từ invitation và hồ sơ Tenant theo service; không cho đổi email tùy ý tại accept. | User mới; liên kết Tenant.userId |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người nhận | Mở TenantInviteScreen với mã có sẵn hoặc nhập mã, đặt mật khẩu. | UI kiểm tra trường; không có trường nhập lại mật khẩu trong màn hình này. |
| 2 | Người nhận | Gửi chấp nhận lời mời. | POST /api/v1/tenant-invites/accept công khai. |
| 3 | Hệ thống | Tra mã hash; khóa Tenant, đọc lại lời mời và kiểm tra các điều kiện còn hiệu lực. | Lời mời bị từ chối nếu Tenant đã liên kết User hoặc chủ trọ/tenant inactive. |
| 4 | Hệ thống | Tạo User TENANT từ dữ liệu hồ sơ, liên kết Tenant.userId và đặt acceptedAt trong transaction. | Commit kích hoạt; không tự tạo hợp đồng hoặc ghi nhận tiền. |
| 5 | Hệ thống và ứng dụng | Cấp phiên sau commit; UI lưu phiên và mở home của TENANT. | Người dùng đã có danh tính gắn hồ sơ thuê; quyền cổng thuê còn theo dữ liệu liên quan. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 1 | Mã không được truyền sẵn từ link | Người nhận nhập mã vào biểu mẫu. | Tiếp tục bước 2. |
| A2 / 4 | Email đã thuộc một User seeker | Không merge tự động; nhận xung đột như email đã đăng ký. | Kết thúc thất bại, chưa gắn User cũ. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2 | Code ngoài 16–256 hoặc password sai DTO | 400. | Không tạo User/link. |
| E2 / 3 | Mã sai, hết hạn, đã nhận, Tenant có userId/inactive hoặc landlord inactive | 401 INVALID_TENANT_INVITE. | Transaction không commit. |
| E3 / 4 | Unique email vi phạm P2002 | 409 EMAIL_ALREADY_REGISTERED. | Rollback tạo User và cập nhật lời mời/link. |
| E4 / 5 | Cấp phiên hoặc lưu local lỗi sau kích hoạt | Thông báo lỗi theo tầng gọi. | User/link/acceptedAt có thể đã commit; mã không được coi còn dùng lại. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-21 | Chấp nhận lời mời gắn Tenant vào User mới; không tái sử dụng User có cùng email. | [E022] |
| BR-22 | Phải đọc lại dữ liệu dưới khóa Tenant để ngăn chấp nhận lặp. | [E022] |
| BR-23 | Tạo lời mời trả code/path; không có enqueue email trong create của TenantInvitesService. | [E023] |

#### G Phân quyền và bảo mật

Accept công khai; possession mã là điều kiện truy cập. Tạo mã là tác vụ khác của chủ trọ (endpoint tạo mời STAFF bị interceptor chặn dù decorator cho STAFF). Accept dùng throttle global; không có override riêng ở controller này.

#### H Kết quả và dữ liệu sau thao tác

User, Tenant.userId và TenantInvite.acceptedAt được ghi cùng transaction. issueSession gọi sau transaction. Thời hạn mời ở create là 7 ngày, khác AccountAccessToken 30 phút; không dùng lẫn hai cơ chế.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E050 | lib/features/auth/tenant_invite_screen.dart:39 | TenantInviteScreen._submit |
| E021 | backend/src/tenants/tenant-invites.controller.ts:45 | TenantInvitesController.accept |
| E022 | backend/src/tenants/tenant-invites.service.ts:97 | TenantInvitesService.accept |
| E023 | backend/src/tenants/tenant-invites.service.ts:54 | TenantInvitesService.create |
| E031 | backend/src/tenants/dto/accept-tenant-invite.dto.ts:3 | AcceptTenantInviteDto |
| E041 | backend/prisma/schema.prisma:910 | TenantInvite |
| E038 | backend/prisma/schema.prisma:816 | Tenant |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E075 | backend/src/tenants/tenant-invites.service.spec.ts:32 | Tenant invite create tests, không phải accept E2E |
| E076 | backend/test/e2e/app-functional.e2e-spec.ts:151 | Tenant and STAFF accept E2E source; chưa chạy |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-08-AC1 | Mời hợp lệ và email mới | Tạo đúng User TENANT, gắn Tenant.userId, acceptedAt có giá trị; không tự tạo Lease. |
| UC-SYS-08-AC2 | Mời hết hạn/đã nhận | 401 INVALID_TENANT_INVITE; không tạo thêm User. |
| UC-SYS-08-AC3 | Email đã có User seeker | 409; không merge User seeker vào Tenant. |
| UC-SYS-08-AC4 | issueSession lỗi sau transaction | Kiểm tra link đã commit; không khẳng định retry code sẽ thành công. |
| UC-SYS-08-AC5 | Landlord bị vô hiệu trước accept | 401; không kích hoạt tài khoản từ lời mời đó. |

### UC-SYS-09 Kích hoạt tài khoản nhân viên từ lời mời

#### A Thông tin tổng quan

| Thuộc tính | Đặc tả |
| --- | --- |
| Mã và tên | UC-SYS-09 — Kích hoạt tài khoản nhân viên từ lời mời |
| Mô tả nghiệp vụ | Người được chủ trọ mời tạo tài khoản STAFF và nhận preset, permissions, phạm vi khu được lưu trong lời mời. |
| Phạm vi và cấp độ | Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc. |
| Tác nhân chính | Người sở hữu mã lời mời nhân viên |
| Tác nhân phối hợp | Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống. |
| Mục tiêu | Nhận tài khoản STAFF và phạm vi đã được chủ trọ cấp |
| Kích hoạt | Mở StaffInviteScreen, nhập mã cùng mật khẩu và gửi chấp nhận. |
| Điều kiện trước | StaffInvite chưa nhận, còn hạn; landlord active; email chưa có User; mọi propertyId trong lời mời vẫn thuộc landlord và chưa archive. |
| Hậu điều kiện thành công | Tạo User STAFF, StaffProfile, StaffPropertyScope, cập nhật acceptedAt và audit trong transaction; sau đó cấp và lưu phiên. |
| Bảo đảm tối thiểu | Nếu phạm vi khu không còn đúng, transaction rollback cả User vừa tạo. Nếu cấp phiên sau commit thất bại, tài khoản nhân viên đã kích hoạt vẫn có thể tồn tại. |

#### B Dữ liệu và ràng buộc

| Trường | Kiểu và bắt buộc | Điều kiện hợp lệ và giới hạn | Mặc định và quan hệ |
| --- | --- | --- | --- |
| inviteCode | string; bắt buộc | 16–256 ký tự; hash để tra StaffInvite. | Không nhận permissions/preset từ client accept |
| password | string; bắt buộc | Chuỗi 12–128 ký tự; có ít nhất một chữ hoa A–Z, một chữ thường a–z, một chữ số 0–9 và một ký tự ngoài A–Za–z0–9. Không tự thêm yêu cầu không có khoảng trắng. | Argon2 trong User |
| preset, permissions, propertyIds | Từ invitation, không nhập trong accept | Sao chép vào StaffProfile/StaffPropertyScope. Mảng propertyIds rỗng có thể hợp lệ; không tự thêm ít nhất một khu. | StaffInvite; StaffProfile; StaffPropertyScope |

#### C Luồng thành công chính

| Bước | Tác nhân | Hành động | Phản hồi hoặc kết quả |
| --- | --- | --- | --- |
| 1 | Người nhận | Mở màn hình nhận lời mời nhân viên; nhập mã và mật khẩu. | UI kiểm tra trường; không có confirmPassword trong biểu mẫu nhận mời này. |
| 2 | Người nhận | Gửi chấp nhận. | POST /api/v1/staff/invites/accept công khai. |
| 3 | Hệ thống | Khóa StaffInvite, đọc lại; kiểm tra expiry, acceptedAt và landlord active. | Mã không hợp lệ bị từ chối trước hoàn tất kích hoạt. |
| 4 | Hệ thống | Tạo User STAFF; kiểm tra số khu còn hợp lệ bằng số propertyIds; tạo profile, scopes, audit và acceptedAt trong transaction. | Tất cả thay đổi trong transaction commit cùng nhau. |
| 5 | Hệ thống và ứng dụng | Cấp phiên sau commit; lưu secure storage và chọn home theo permissions. | Nhân viên đăng nhập; quyền thực thi vẫn bị giới hạn bởi guard và interceptor. |

#### D Luồng thay thế

| Mã và bước | Điều kiện | Trình tự xử lý | Kết quả và điểm trở lại |
| --- | --- | --- | --- |
| A1 / 4 | propertyIds rỗng trong lời mời | Kiểm tra count=0 bằng length=0; không có bằng chứng bắt buộc phải có khu. | Tạo profile không có scope khu; tiếp tục bước 5. |

#### E Luồng ngoại lệ

| Mã và bước | Điều kiện | Hệ thống xử lý | Trạng thái sau lỗi |
| --- | --- | --- | --- |
| E1 / 2 | Sai DTO code hoặc password | 400. | Không tạo tài khoản. |
| E2 / 3–4 | Mã hết hạn/đã dùng, landlord inactive hoặc scope khu không còn hợp lệ | 401 INVALID_STAFF_INVITE. | Rollback transaction kể cả User đã insert trong transaction. |
| E3 / 4 | Email đã tồn tại | 409 EMAIL_ALREADY_REGISTERED. | Không tạo profile/link thứ hai. |
| E4 / 5 | issueSession/lưu local thất bại | Không hiển thị thành công đăng nhập. | User/profile/scopes và acceptedAt có thể đã commit. |

#### F Quy tắc nghiệp vụ

| Mã | Quy tắc có thể kiểm thử | Nguồn |
| --- | --- | --- |
| BR-24 | Quyền nhận khi accept lấy từ bản mời, không lấy từ trường client tự gửi. | [E025] |
| BR-25 | Mọi khu trong invitation phải còn thuộc landlord và isArchived=false khi accept. | [E025] |
| BR-26 | Tạo tài khoản STAFF không vượt được allowlist controller và property scope ở request bảo vệ. | [E035] |

#### G Phân quyền và bảo mật

Accept công khai theo possession code, throttle global không override riêng. Các endpoint STAFF sau login chịu active User/profile/landlord, permissions và property scope; không đồng nhất permissions có tên với khả năng thực thi mọi controller.

#### H Kết quả và dữ liệu sau thao tác

Ghi User, StaffProfile, StaffPropertyScope, StaffInvite.acceptedAt và audit trong transaction. Không tạo khu/phòng mới; không nâng quyền ADMIN. Session là bước sau commit.

#### I Truy vết source code

| Nguồn | File và dòng | Hàm API hoặc bằng chứng |
| --- | --- | --- |
| E051 | lib/features/auth/staff_invite_screen.dart:39 | StaffInviteScreen._submit |
| E024 | backend/src/staff/staff.controller.ts:96 | StaffController.accept |
| E025 | backend/src/staff/staff.service.ts:104 | StaffService.accept |
| E032 | backend/src/staff/dto/accept-staff-invite.dto.ts:3 | AcceptStaffInviteDto |
| E042 | backend/prisma/schema.prisma:291 | StaffProfile; StaffInvite; StaffPropertyScope |
| E035 | backend/src/common/property-scope.ts:44 | PropertyScopeInterceptor |
| E033 | backend/src/auth/jwt.strategy.ts:25 | JwtStrategy.validate |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E076 | backend/test/e2e/app-functional.e2e-spec.ts:151 | Tenant and STAFF accept E2E source; chưa chạy |

#### J Kịch bản nghiệm thu từ hành vi đã xác nhận

| Mã | Điều kiện hoặc thao tác | Kết quả phải kiểm chứng |
| --- | --- | --- |
| UC-SYS-09-AC1 | Lời mời hợp lệ với hai khu thuộc landlord | Tạo STAFF, profile đúng permissions, hai scopes; acceptedAt được ghi. |
| UC-SYS-09-AC2 | Một khu đã archive trước accept | 401 INVALID_STAFF_INVITE; không còn User/profile mới từ transaction thất bại. |
| UC-SYS-09-AC3 | Chèn permissions vào payload accept | 400 do whitelist; không cấp quyền tùy ý. |
| UC-SYS-09-AC4 | Mã đã dùng/email đã có | Lần lượt INVALID_STAFF_INVITE hoặc EMAIL_ALREADY_REGISTERED theo nhánh kiểm tra; không tạo thêm tài khoản. |
| UC-SYS-09-AC5 | STAFF gọi controller ngoài allowlist dù có permission | Bị interceptor từ chối; nhận token không đồng nghĩa quyền truy cập toàn bộ ứng dụng. |

### 4.1 Checklist kiểm tra chéo nhóm tài khoản

| Tiêu chí | Kết quả rà soát và giới hạn |
| --- | --- |
| Đúng nghiệp vụ | Tách seeker/User TENANT khỏi hồ sơ Tenant; tách mời Tenant và STAFF; không có quyền tự chọn ADMIN. |
| Đầy đủ | 9 UC có A–J; phiên kỹ thuật được đặc tả riêng. Nhóm ngoài tài khoản chưa được đánh dấu hoàn tất. |
| Rõ ràng | Đã ghi DTO riêng của từng endpoint, HTTP/status/code và kết quả UI; không dùng nhánh lỗi chung giả lập cho mọi UC. |
| Nhất quán | BR-01–26 dùng chung; TTL cấu hình tách khỏi token mời 7 ngày và token khôi phục 30 phút. |
| Có thể kiểm thử | Mỗi UC có success, invalid data và nhánh từ chối thực tế; endpoint công khai không tự thêm lỗi thiếu JWT. |
| Có thể truy vết | Nguồn E có file, dòng và hàm, đối chiếu snapshot. Không tuyên bố tất cả acceptance scenarios đã chạy. |

## 5 Các tiến trình hỗ trợ phiên

### 5.1 SP SYS 01 Phục hồi phiên ứng dụng

Thay thế phần phục hồi danh tính của UC-SYS-04 cũ. Kích hoạt khi SessionController khởi tạo, không phải thao tác đăng nhập mới của người dùng. Nguồn: [E052] [E053] [E033] [E054] [E072]

| Bước | Thực hiện | Kết quả và nhánh |
| --- | --- | --- |
| 1 | Đọc secure storage | Không có phiên: trả null, ứng dụng ở trạng thái chưa đăng nhập. |
| 2 | Gọi GET /api/v1/auth/me bằng JWT | Kiểm chứng active User/session/version và serialize quyền; nếu hợp lệ giữ token hiện hành, cập nhật user. |
| 3 | Đọc lại storage trước ghi | Nếu đã logout: không phục hồi. Nếu user đã đổi: trả phiên mới, không ghi đè danh tính khác. |
| 4 | Nếu /me nhận 401 | Thử refresh bằng token hiện hành; trước/sau request kiểm tra lại user và refreshToken còn như cũ. |
| 5 | Xử lý refresh | 401 refresh: xóa đúng phiên matching; non-401: rethrow và giữ storage. Không coi mọi lỗi mạng là mất quyền vĩnh viễn. |

Dữ liệu sau thao tác: có thể cập nhật thông tin user và token, không tạo User hay Tenant. JWT sid có thể vắng ở phiên legacy; không mô tả sid là bắt buộc cho mọi token AS-IS. Kịch bản cần kiểm chứng: /me thành công, refresh hết hạn, lỗi 5xx, logout giữa request và đổi tài khoản giữa request; kết quả không được khôi phục phiên đã rời.

### 5.2 SP SYS 02 Luân chuyển refresh token

Kích hoạt khi khôi phục phiên hoặc request bảo vệ bị 401. API POST /api/v1/auth/refresh công khai, body refreshToken string tối thiểu 32 ký tự, throttle 20/60 giây; mặc định POST trả 201. Nguồn: [E030] [E016] [E055] [E056] [E039] [E015]

| Bước | Thực hiện | Kết quả và kiểm soát |
| --- | --- | --- |
| 1 | Client phối hợp refresh | TokenRefreshCoordinator gộp request đồng thời trong instance; API client chỉ authRetry một lần cho request lỗi 401. |
| 2 | Server hash token, tìm candidate và khóa User | Kiểm token tồn tại, chưa revoked, chưa hết hạn, User active. Nếu có sid: AuthSession chưa revoke/hết hạn và userVersion trùng hiện hành. |
| 3 | Tiêu thụ token có điều kiện trong transaction | Token cũ được revoke và trỏ replacedByTokenId; tạo replacement cùng sid; trả token mới. |
| 4 | Client kiểm tra lại phiên trước ghi | Không ghi đè user mới hoặc token đã được thay; không phục sinh phiên đã logout. |
| 5 | Từ chối và lỗi | Sai/hết hạn/dùng lại: 401 INVALID_REFRESH_TOKEN. Non-401 không tự xóa phiên. Không thấy revoke toàn bộ token family chỉ do replay. |

Cấp phiên mới dùng access TTL từ cấu hình (mặc định 15m) và refresh TTL mặc định 30 ngày theo cơ chế fallback, không phải chính sách bất biến. Rotation không gia hạn expiresAt của AuthSession: hạn token thay thế bị giới hạn bởi hạn phiên. Kiểm thử suy ra: token một lần, hai refresh cạnh tranh, storage đã đổi, lỗi 5xx và session revoked. Nguồn E2E xoay token/logout có tại [E078] nhưng chưa chạy. Không có bảo đảm request nghiệp vụ gốc thành công sau refresh nếu quyền dữ liệu đã thay đổi.

## 6 Danh mục quy tắc nghiệp vụ và phát hiện hệ thống

| Mã | Điều kiện và quy tắc | UC và bằng chứng |
| --- | --- | --- |
| BR-01 | registerAccount luôn dùng UserRole.LANDLORD cho endpoint register; input không quyết định vai trò. | UC-SYS-01 [E007] |
| BR-02 | Email được lowercase và trim trước khi tạo; email trùng bị từ chối. | UC-SYS-01 [E007] |
| BR-03 | Mật khẩu mới phải đạt đủ bốn nhóm ký tự và 12–128 ký tự tại backend. | UC-SYS-01 [E027] |
| BR-04 | register-seeker ấn định UserRole.TENANT, không có role SEEKER trong schema. | UC-SYS-02 [E008] |
| BR-05 | Luồng đăng ký tìm phòng không tự tạo Tenant và Lease. | UC-SYS-02 [E007] |
| BR-06 | Home của TENANT là trang khám phá; điều kiện nghiệp vụ các màn hình cổng thuê được xét riêng. | UC-SYS-02 [E054] |
| BR-07 | User không có, inactive hoặc mật khẩu sai cùng nhận INVALID_CREDENTIALS. | UC-SYS-03 [E009] |
| BR-08 | MFA cho Admin đã bật được kiểm chứng trước issueSession; TOTP có kiểm tra chống dùng lại. | UC-SYS-03 [E026] |
| BR-09 | Checkbox ghi nhớ không thay đổi dữ liệu request hay thời hạn phiên. | UC-SYS-03 [E044] |
| BR-10 | Logout theo refresh token, không phải xóa tài khoản hay mặc định đăng xuất tất cả thiết bị. | UC-SYS-05.1 [E010] |
| BR-11 | Luồng finally dọn phiên local không chứng minh backend đã revoke thành công. | UC-SYS-05.1 [E052] |
| BR-12 | Danh sách không trả phiên hết hạn, revoked hay userVersion cũ; giới hạn take=100. | UC-SYS-05.2 [E011] |
| BR-13 | Revoke-all thực chất giữ sid hiện tại, không đồng nghĩa đăng xuất toàn bộ thiết bị. | UC-SYS-05.2 [E013] |
| BR-14 | Mọi thao tác chỉ tác động phiên có userId bằng current user. | UC-SYS-05.2 [E012] |
| BR-15 | Forgot không tiết lộ email có trong hệ thống hoặc kết quả enqueue. | UC-SYS-06 [E017] |
| BR-16 | Token enqueue có thời hạn 30 phút; một lần sử dụng nhờ tiêu thụ có điều kiện trong transaction. | UC-SYS-06 [E018] |
| BR-17 | Redeem tăng sessionVersion và revoke refresh, không tự đăng nhập lại. | UC-SYS-06 [E018] |
| BR-18 | Đổi mật khẩu chỉ áp dụng current user; không nhận userId đích. | UC-SYS-07 [E006] |
| BR-19 | Hash phải còn đúng như lúc xác minh sau khi khóa User trước cập nhật. | UC-SYS-07 [E014] |
| BR-20 | sessionVersion tăng và refresh revoke buộc các phiên version cũ bị từ chối về sau. | UC-SYS-07 [E014] |
| BR-21 | Chấp nhận lời mời gắn Tenant vào User mới; không tái sử dụng User có cùng email. | UC-SYS-08 [E022] |
| BR-22 | Phải đọc lại dữ liệu dưới khóa Tenant để ngăn chấp nhận lặp. | UC-SYS-08 [E022] |
| BR-23 | Tạo lời mời trả code/path; không có enqueue email trong create của TenantInvitesService. | UC-SYS-08 [E023] |
| BR-24 | Quyền nhận khi accept lấy từ bản mời, không lấy từ trường client tự gửi. | UC-SYS-09 [E025] |
| BR-25 | Mọi khu trong invitation phải còn thuộc landlord và isArchived=false khi accept. | UC-SYS-09 [E025] |
| BR-26 | Tạo tài khoản STAFF không vượt được allowlist controller và property scope ở request bảo vệ. | UC-SYS-09 [E035] |

Các phát hiện ngoài SYS sau đây là ranh giới đã đọc trong service để hiệu chỉnh catalog; chưa thay thế đặc tả A–J. Nguồn là các service/phương thức được ghi từng dòng. Cần bổ sung trường dữ liệu, thứ tự UI và ma trận test khi đặc tả nhóm tương ứng.

Phòng và hợp đồng: Kết thúc lease không làm phòng VACANT ngay: chuyển MAINTENANCE và bắt đầu turnover. Tạo lease bị chặn bởi lease ACTIVE/turnover chưa xong và điều kiện phòng; deposit dương được ghi COLLECTED. [E079] [E080] [E061]

Thu hồi phòng: Turnover qua RETURNED, INSPECTION, REPAIR, CLEANING, READY; sửa chữa chưa xong chặn bước hoàn tất; chỉ khi sẵn sàng mới VACANT. [E081] [E061]

Thanh lý và hoàn cọc: Settlement có preview/fingerprint và idempotency; không chứng minh thực hiện chuyển khoản ngân hàng. Ghi hoàn tiền cọc là luồng riêng; không tự nhập chung hóa đơn cũ vào settlement. [E082] [E083] [E084]

Vòng đời hợp đồng: Request APPROVED chưa tự đồng nghĩa đã chuyển/checkout/renew. TRANSFER/CHECKOUT có điều kiện ended+settled và thực thi riêng. [E085]

Tài chính: Proof PENDING không phải Payment. Approve tạo payment theo số nợ còn; cancel invoice bị chặn bởi lịch sử payment kể cả đã đảo về net zero. Payment được quản lý allocation không đảo trực tiếp. [E086] [E087] [E088]

Thanh toán thẻ: DemoCardGateway chỉ bật khi NODE_ENV khác production và DEMO_PAYMENTS_ENABLED=true; không xác nhận cổng ngân hàng thật. QR/chuyển khoản thủ công không đồng nghĩa webhook xác nhận tiền tự động. [E062]

Báo cáo thu: Báo cáo tháng cộng net Payment, không mặc định toàn bộ tiền receipt. Xuất CSV tại UI qua clipboard không phải tính năng tải XLSX. [E089] [E063]

Tin công khai: Phải PUBLISHED, Room active VACANT, Property không archived và landlord active. Sửa nội dung có thể đưa tin về DRAFT, không đồng nghĩa sửa xong vẫn xuất bản. [E090] [E091]

Lịch xem: Chuyển thành lease chỉ khi viewing COMPLETED; có transaction và version/capacity checks. Saved searches có giới hạn 10; không tìm thấy endpoint sửa toàn bộ bộ lọc đã lưu. [E092] [E094]

Gói dịch vụ: Không có subscription row không mặc định bằng gói hạn mức 0. Hết hạn gói chặn tăng trưởng theo service; không đồng nghĩa xóa dữ liệu thuê đang tồn tại. [E064]

Hỗ trợ và chatbot: Tệp hỗ trợ có quét malware riêng; không suy mọi upload được quét. Chatbot LANDLORD-only, mặc định tắt; không có bằng chứng truy vấn dữ liệu kinh doanh sống cho mọi câu hỏi. [E093] [E065] [E066]

## 7 Ma trận truy vết yêu cầu

Requirements_Traceability_Matrix.tsv là ma trận đầy đủ 405 endpoint: mã R, HTTP/path, controller.method, file/dòng, role/permission metadata, DTO và lời gọi service có thể phân giải, UC hoặc tiến trình hỗ trợ. Đây là bằng chứng cấu trúc; các service gọi tiếp, scope interceptor và UI vẫn cần đọc để xác nhận hành vi. Ký hiệu LOCAL không bị gán API giả.

Số 405 chỉ đếm route khai báo bằng HTTP decorator trong controller. Handler middleware /uploads và Swagger /docs có điều kiện cấu hình trong app.bootstrap.ts không nằm trong số đếm này. Không suy 405 là toàn bộ bề mặt HTTP của mọi cấu hình triển khai. [E057]

Xuất PDF cục bộ: LOCAL.leasePdf [E067]; LOCAL.invoicePdf [E068]. Hai hàm nằm phía Flutter; dữ liệu đầu vào phải lấy qua UC xem đối tượng đã được kiểm quyền, không tạo chữ ký số qua việc dựng PDF.

| Nguồn | File và dòng | Hàm hoặc thành phần |
| --- | --- | --- |
| E001 | backend/src/auth/auth.controller.ts:18 | AuthController.register |
| E002 | backend/src/auth/auth.controller.ts:25 | AuthController.registerSeeker |
| E003 | backend/src/auth/auth.controller.ts:32 | AuthController.login |
| E004 | backend/src/auth/auth.controller.ts:44 | AuthController.logout |
| E005 | backend/src/auth/auth.controller.ts:59 | AuthController.sessions |
| E006 | backend/src/auth/auth.controller.ts:80 | AuthController.changePassword |
| E007 | backend/src/auth/auth.service.ts:45 | AuthService.registerAccount |
| E008 | backend/src/auth/auth.service.ts:41 | AuthService.registerSeeker |
| E009 | backend/src/auth/auth.service.ts:71 | AuthService.login |
| E010 | backend/src/auth/auth.service.ts:137 | AuthService.logout |
| E011 | backend/src/auth/auth.service.ts:212 | AuthService.sessions |
| E012 | backend/src/auth/auth.service.ts:232 | AuthService.revokeSession |
| E013 | backend/src/auth/auth.service.ts:244 | AuthService.revokeOtherSessions |
| E014 | backend/src/auth/auth.service.ts:159 | AuthService.changePassword |
| E015 | backend/src/auth/auth.service.ts:179 | AuthService.issueSession |
| E016 | backend/src/auth/auth.service.ts:91 | AuthService.refresh |
| E017 | backend/src/auth/account-access.service.ts:47 | AccountAccessService.forgot |
| E018 | backend/src/auth/account-access.service.ts:54 | AccountAccessService.redeem |
| E019 | backend/src/auth/account-access.service.ts:23 | AccountAccessService.enqueue |
| E020 | backend/src/auth/account-access.controller.ts:19 | AccountAccessController.forgot |
| E021 | backend/src/tenants/tenant-invites.controller.ts:45 | TenantInvitesController.accept |
| E022 | backend/src/tenants/tenant-invites.service.ts:97 | TenantInvitesService.accept |
| E023 | backend/src/tenants/tenant-invites.service.ts:54 | TenantInvitesService.create |
| E024 | backend/src/staff/staff.controller.ts:96 | StaffController.accept |
| E025 | backend/src/staff/staff.service.ts:104 | StaffService.accept |
| E026 | backend/src/auth/admin-mfa.service.ts:66 | AdminMfaService.verify |
| E027 | backend/src/auth/dto/register.dto.ts:4 | RegisterDto |
| E028 | backend/src/auth/dto/login.dto.ts:4 | LoginDto |
| E029 | backend/src/auth/dto/change-password.dto.ts:4 | ChangePasswordDto |
| E030 | backend/src/auth/dto/refresh.dto.ts:4 | RefreshDto |
| E031 | backend/src/tenants/dto/accept-tenant-invite.dto.ts:3 | AcceptTenantInviteDto |
| E032 | backend/src/staff/dto/accept-staff-invite.dto.ts:3 | AcceptStaffInviteDto |
| E033 | backend/src/auth/jwt.strategy.ts:25 | JwtStrategy.validate |
| E034 | backend/src/common/roles.guard.ts:23 | RolesGuard.canActivate |
| E035 | backend/src/common/property-scope.ts:44 | PropertyScopeInterceptor |
| E036 | backend/src/common/admin-access.ts:1 | Admin access predicates |
| E037 | backend/prisma/schema.prisma:177 | User |
| E038 | backend/prisma/schema.prisma:816 | Tenant |
| E039 | backend/prisma/schema.prisma:1738 | AuthSession; RefreshToken trong cùng schema |
| E040 | backend/prisma/schema.prisma:1771 | AccountAccessToken |
| E041 | backend/prisma/schema.prisma:910 | TenantInvite |
| E042 | backend/prisma/schema.prisma:291 | StaffProfile; StaffInvite; StaffPropertyScope |
| E043 | lib/features/auth/register_screen.dart:79 | RegisterScreen._submit |
| E044 | lib/features/auth/login_screen.dart:37 | LoginScreen._submit |
| E045 | lib/features/auth/auth_providers.dart:116 | SessionController.logout |
| E046 | lib/features/admin/admin_sessions_screen.dart:10 | AdminSessionsScreen |
| E047 | lib/features/tenant_portal/tenant_change_password_screen.dart:8 | TenantChangePasswordScreen |
| E048 | lib/features/auth/password_recovery_dialog.dart:12 | PasswordRecoveryDialog |
| E049 | lib/features/auth/account_access_screen.dart:32 | AccountAccessScreen._submit |
| E050 | lib/features/auth/tenant_invite_screen.dart:39 | TenantInviteScreen._submit |
| E051 | lib/features/auth/staff_invite_screen.dart:39 | StaffInviteScreen._submit |
| E052 | lib/data/auth/auth_repository.dart:6 | AuthRepository login/register/logout/restore |
| E053 | lib/features/auth/auth_providers.dart:52 | SessionController |
| E054 | lib/features/auth/auth_navigation.dart:264 | homeRouteForSession |
| E055 | lib/data/auth/token_refresh_coordinator.dart:8 | TokenRefreshCoordinator |
| E056 | lib/core/network/api_client.dart:52 | API client retry 401 |
| E057 | backend/src/app.bootstrap.ts:1 | Global validation and API prefix |
| E058 | backend/src/app.module.ts:37 | Module registrations and global interceptors |
| E059 | backend/src/common/api-error.filter.ts:18 | ApiErrorFilter |
| E060 | lib/app/app.dart:80 | Flutter routing |
| E061 | backend/src/operations/turnover.workflow.ts:4 | Turnover stages and beginTurnover |
| E062 | backend/src/billing/demo-card.gateway.ts:7 | DemoCardGateway.assertEnabled; validateCard |
| E063 | lib/features/reports/reports_screen.dart:96 | ReportsScreen CSV clipboard |
| E064 | backend/src/common/subscription-entitlements.ts:4 | Inventory subscription entitlements |
| E065 | backend/src/chatbot/chatbot.config.ts:19 | Chatbot default disabled |
| E066 | backend/src/chatbot/chatbot.controller.ts:14 | Chatbot role |
| E067 | lib/features/tenants/lease_pdf.dart:1 | Local lease PDF |
| E068 | lib/features/billing/invoice_pdf.dart:1 | Local invoice PDF |
| E069 | test/features/auth/register_screen_test.dart:152 | RegisterScreen tests; validate/register two purposes |
| E070 | backend/src/auth/auth.service.spec.ts:57 | AuthService tests; register, duplicate, inactive, change password |
| E071 | backend/src/auth/jwt.strategy.spec.ts:20 | JwtStrategy tests |
| E072 | test/features/auth/session_cache_isolation_test.dart:113 | Password change and cache isolation tests |
| E073 | backend/src/auth/account-access.service.spec.ts:4 | Account access send rate-limit unit test |
| E074 | test/features/auth/account_access_test.dart:10 | Account access link parsing and recovery UI tests |
| E075 | backend/src/tenants/tenant-invites.service.spec.ts:32 | Tenant invite create tests, không phải accept E2E |
| E076 | backend/test/e2e/app-functional.e2e-spec.ts:151 | Tenant and STAFF accept E2E source; chưa chạy |
| E077 | backend/test/e2e/admin-next-sprints.e2e-spec.ts:42 | Own-session revoke E2E source; chưa chạy |
| E078 | backend/test/e2e/auth.e2e-spec.ts:58 | Auth refresh/logout E2E source; chưa chạy |
| E079 | backend/src/leases/leases.service.ts:87 | LeasesService.create |
| E080 | backend/src/leases/leases.service.ts:160 | LeasesService.end |
| E081 | backend/src/operations/turnovers.service.ts:35 | TurnoversService.advance |
| E082 | backend/src/leases/settlements.service.ts:61 | LeaseSettlementsService.confirm |
| E083 | backend/src/leases/settlements.service.ts:53 | LeaseSettlementsService.preview |
| E084 | backend/src/leases/settlements.service.ts:101 | LeaseSettlementsService.recordRefund |
| E085 | backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148 | TenantLifecycleService.executeRequest |
| E086 | backend/src/billing/billing.service.ts:1053 | BillingService.reviewPaymentProof |
| E087 | backend/src/billing/billing.service.ts:1245 | BillingService.cancelInvoice |
| E088 | backend/src/billing/billing.service.ts:1185 | BillingService.reversePayment |
| E089 | backend/src/reports/reports.service.ts:18 | ReportsService.monthly |
| E090 | backend/src/listings/listings.service.ts:290 | ListingsService.visibleWhere |
| E091 | backend/src/listings/listings.service.ts:104 | ListingsService.update |
| E092 | backend/src/listings/saved-searches.service.ts:25 | SavedSearchesService.create |
| E093 | backend/src/support/support-attachment.service.ts:25 | SupportAttachmentService.upload |
| E094 | backend/src/housing/housing.service.ts:240 | HousingService.createLease |

### 7.1 Độ phủ truy vết theo nhóm

| Nhóm | UC | Độ sâu đã xác nhận |
| --- | --- | --- |
| SYS Tài khoản và phiên làm việc | 9 | Frontend → API → service → DTO → schema; test được ghi theo phạm vi. |
| DIS Khám phá và tìm thuê phòng | 18 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| OPT Khu trọ và phòng | 16 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| TNT Người thuê và hợp đồng | 21 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| BIL Hóa đơn và sổ thu chi | 28 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| OPS Vận hành nhà trọ | 9 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| TEN Cổng người thuê | 13 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| ADM Quản trị nền tảng | 36 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| SUP Hỗ trợ và giám sát | 11 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |
| STF Nhân viên của chủ trọ | 3 | API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC. |

Không đặt trạng thái “xác nhận toàn bộ” cho 155 UC còn lại chỉ vì có endpoint. Việc kiểm kê đủ 405 route kiểm soát bỏ sót đầu vào kỹ thuật; không chứng minh không còn chức năng local-only ngoài hai xuất PDF đã ghi nhận.

### 7.2 Đối chiếu mã Use Case cũ và mới

| Mã cũ | Tên trong báo cáo cũ | Mã đối chiếu mới | Cách xử lý |
| --- | --- | --- | --- |
| UC-SYS-01 | Đăng ký tài khoản chủ trọ | UC-SYS-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-02 | Đăng ký tài khoản người thuê đang tìm phòng | UC-SYS-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-03 | Đăng nhập và điều hướng theo vai trò | UC-SYS-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-04 | Khôi phục phiên và làm mới token | SP-SYS-01, SP-SYS-02 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | UC-SYS-05.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-05.2 | Xem và thu hồi phiên trên thiết bị khác | UC-SYS-05.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-06 | Khôi phục mật khẩu qua liên kết dùng một lần | UC-SYS-06 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | UC-SYS-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SYS-08 | Chấp nhận lời mời và kích hoạt tài khoản người thuê | UC-SYS-08 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | UC-DIS-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-02 | Xem chi tiết tin phòng và đánh giá công khai | UC-DIS-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-03 | Lưu và bỏ lưu phòng yêu thích | UC-DIS-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-04 | Lưu bộ lọc và xem cảnh báo tìm phòng | UC-DIS-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-05 | Tạo và cập nhật bản nháp tin cho thuê | UC-DIS-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-06 | Gửi duyệt và ẩn tin cho thuê | UC-DIS-06.1, UC-DIS-06.2, UC-DIS-06.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-DIS-07 | Báo cáo tin phòng không phù hợp | UC-DIS-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-08 | Quản lý khung giờ xem phòng | UC-DIS-08 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-09 | Đặt và theo dõi lịch xem phòng | UC-DIS-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-10 | Đổi lịch hủy và xử lý lịch xem phòng | UC-DIS-10 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-11 | Chuyển lịch xem thành hợp đồng và bàn giao | UC-DIS-11, UC-TNT-12.2, UC-TNT-12.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-DIS-12 | Viết sửa và rút đánh giá theo hợp đồng | UC-DIS-12 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-DIS-13 | Chủ trọ trả lời đánh giá và gửi phản hồi thử nghiệm | UC-DIS-13.1, UC-DIS-13.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-OPT-01 | Xem dashboard và bản đồ phòng tương tác | UC-OPT-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-02 | Tra cứu và chọn khu trọ | UC-OPT-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-03.1 | Tạo khu trọ | UC-OPT-03.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | UC-OPT-03.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-04.1 | Lưu trữ khu trọ | UC-OPT-04.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-04.2 | Khôi phục khu trọ đã lưu trữ | UC-OPT-04.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-04.3 | Xóa khu trọ chưa có phòng | UC-OPT-04.3 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | UC-OPT-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-06.1 | Tạo phòng | UC-OPT-06.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-06.2 | Cập nhật thông tin phòng | UC-OPT-06.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-07.1 | Chuyển trạng thái phòng trống hoặc bảo trì | UC-OPT-07.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | UC-OPT-07.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-07.3 | Xóa phòng chưa phát sinh nghiệp vụ | UC-OPT-07.3 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-08.1 | Quản lý tài sản phòng | UC-OPT-08.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | UC-OPT-08.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ tại phòng | UC-OPT-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | UC-TNT-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | UC-TNT-02.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | UC-TNT-02.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục hồ sơ người thuê | UC-TNT-02.3 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-02.4 | Xóa hồ sơ chưa có lịch sử nghiệp vụ | UC-TNT-02.4 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-03 | Mời người thuê truy cập cổng thông tin | UC-TNT-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-04 | Tra cứu hợp đồng và cảnh báo hết hạn | UC-TNT-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-05 | Tạo hợp đồng thuê và ghi nhận cọc ban đầu | UC-TNT-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | UC-TNT-06.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-06.2 | Gia hạn hợp đồng thuê | UC-TNT-06.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-06.3 | Kết thúc hợp đồng thuê | UC-TNT-06.3 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-07 | Tra cứu và ghi giao dịch tiền cọc | UC-TNT-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-08 | Xem trước và xác nhận quyết toán trả phòng | UC-TNT-08 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-09 | Ghi nhận hoàn tiền quyết toán | UC-TNT-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-10 | Duyệt yêu cầu gia hạn chuyển phòng trả phòng | UC-TNT-10 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã được duyệt | UC-TNT-11 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | UC-TNT-12.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TNT-12.2 | Lập và xác nhận biên bản bàn giao | UC-TNT-12.2, UC-TNT-12.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-TNT-13 | Xuất và chia sẻ hợp đồng PDF | UC-TNT-13 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-01 | Ghi chỉ số điện nước theo kỳ | UC-BIL-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-02 | Xem trước và lập hóa đơn một hợp đồng | UC-BIL-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-03 | Lập hóa đơn hàng loạt và kiểm tra trước | UC-BIL-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-04 | Tra cứu hóa đơn và tuổi nợ | UC-BIL-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-05 | Sửa hạn thanh toán hoặc ghi chú hóa đơn | UC-BIL-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-06 | Thay thế hóa đơn chưa có lịch sử thanh toán | UC-BIL-06 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-07 | Phát hành credit note hoặc debit note | UC-BIL-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-08.1 | Hủy hóa đơn theo điều kiện | UC-BIL-08.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-08.2 | Xuất hoặc chia sẻ hóa đơn PDF | UC-BIL-08.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-09 | Ghi nhận thanh toán trực tiếp cho hóa đơn | UC-BIL-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-10 | Tạo khoản thu và giữ số tiền chưa phân bổ | UC-BIL-10 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-11 | Phân bổ khoản thu cho nhiều hóa đơn | UC-BIL-11 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-12 | Giải phóng phân bổ và đảo khoản thanh toán | UC-BIL-12.1, UC-BIL-12.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-BIL-13 | Ghi nhận hoàn tiền từ khoản thu | UC-BIL-13 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-14 | Duyệt hoặc từ chối chứng từ thanh toán | UC-BIL-14 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-15 | Đề xuất biểu phí theo khu phòng và kỳ hiệu lực | UC-BIL-15 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-16 | Phân tích tác động và duyệt biểu phí | UC-BIL-16 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-17.1 | Cấu hình lập hóa đơn định kỳ | UC-BIL-17.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-17.2 | Chạy trước và thực hiện đợt lập hóa đơn | UC-BIL-17.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-18 | Cấu hình nhắc nợ và theo dõi outbox | UC-BIL-18.1, UC-BIL-18.2, UC-BIL-18.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-BIL-19 | Quản lý khoản chi vận hành | UC-BIL-19 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-20 | Xem báo cáo tháng và các chỉ số phân tích | UC-BIL-20 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-BIL-21 | Xuất nội dung báo cáo tháng CSV | UC-BIL-21 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-01 | Tra cứu tạo và theo dõi bảo trì | UC-OPS-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-02 | Phân công cập nhật tiến độ và SLA bảo trì | UC-OPS-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-03 | Hoàn tất bảo trì và liên kết khoản chi | UC-OPS-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-04 | Theo dõi việc cần xử lý và điểm đến | UC-OPS-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-05 | Quản lý quy trình chuẩn bị phòng sau trả | UC-OPS-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-06 | Quản lý công việc định kỳ và checklist | UC-OPS-06 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-07 | Soạn và phát thông báo cho người thuê | UC-OPS-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-OPS-08 | Tra cứu lượt gửi và gửi nhắc Zalo | UC-OPS-08 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-01 | Xem hồ sơ và tổng quan thuê của mình | UC-TEN-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-02 | Xem hợp đồng lịch sử cọc và quyết toán | UC-TEN-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-03 | Xem hóa đơn và chia sẻ PDF của mình | UC-TEN-03 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-04 | Tải tệp và gửi chứng từ thanh toán | UC-TEN-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-05 | Thanh toán qua cổng thẻ mô phỏng | UC-TEN-05 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-06 | Gửi và phản hồi yêu cầu bảo trì | UC-TEN-06 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-07 | Gửi hủy và theo dõi yêu cầu vòng đời thuê | UC-TEN-07 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-TEN-08 | Xem người ở cùng và sở thích nhận thông báo | UC-TEN-08.1, UC-TEN-08.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-TEN-09 | Đọc xác nhận thông báo và trao đổi trong portal | UC-TEN-09.1, UC-TEN-09.2, UC-TEN-09.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-OPS-09 | Tra cứu nhật ký vận hành | UC-OPS-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-01 | Xem tổng quan quản trị và phân tích nền tảng | UC-ADM-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-02 | Tra cứu và xem chi tiết tài khoản nền tảng | UC-ADM-02 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | UC-ADM-03.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-03.2 | Cập nhật hồ sơ tài khoản chủ trọ | UC-ADM-03.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-04.1 | Đình chỉ tài khoản và vô hiệu phiên | UC-ADM-04.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-04.2 | Khôi phục tài khoản bị đình chỉ | UC-ADM-04.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-04.3 | Thu hồi các phiên truy cập của tài khoản | UC-ADM-04.3 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-05.1 | Mở thông tin cá nhân nhạy cảm có kiểm soát | UC-ADM-05.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | UC-ADM-05.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-06.1 | Quản lý profile và quyền Admin | UC-ADM-06.1 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-06.2 | Rà soát quyền truy cập định kỳ | UC-ADM-06.2 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-07 | Thiết lập MFA và cấp quyền step-up | UC-ADM-07.1, UC-ADM-07.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-ADM-08 | Tra cứu khu trọ và phòng toàn nền tảng | UC-ADM-08 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-09 | Tạo và cập nhật khu trọ thay mặt chủ trọ | UC-ADM-09 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-10 | Tìm kiếm toàn cục và định vị tài nguyên | UC-ADM-10 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-11 | Nhận việc và kiểm duyệt tin đăng | UC-ADM-11 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-12 | Kiểm duyệt đánh giá phản hồi và báo cáo vi phạm | UC-ADM-12 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-13 | Quản lý chính sách kháng nghị và đánh giá chất lượng | UC-ADM-13.1, UC-ADM-13.2, UC-ADM-13.3 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-ADM-14 | Tra cứu và xuất nhật ký quản trị | UC-ADM-14 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-15 | Đối soát sao kê và duyệt maker checker | UC-ADM-15 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-16 | Quản lý lịch báo cáo và tải kết quả Admin | UC-ADM-16 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-17 | Quản lý feature flags và nhóm Admin | UC-ADM-17.1, UC-ADM-17.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-ADM-18 | Tiếp nhận và xét duyệt xác minh chủ trọ | UC-ADM-18 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-19 | Trình và xét duyệt hồ sơ khu trọ | UC-ADM-19 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-20 | Quản lý danh mục gói dịch vụ | UC-ADM-20 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-21 | Gán gói cho chủ trọ và tra cứu lịch sử đăng ký | UC-ADM-21 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-ADM-22 | Hủy quyền sử dụng gói dịch vụ đang hiệu lực | UC-ADM-22 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SUP-01 | Tạo và xử lý hồ sơ hỗ trợ nền tảng | UC-SUP-01 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SUP-02 | Phân công tự động SLA và escalation hỗ trợ | UC-SUP-02.1, UC-SUP-02.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-SUP-03 | Quản lý tệp mẫu trả lời và bộ lọc hỗ trợ | UC-SUP-03.1, UC-SUP-03.2, UC-SUP-03.3, UC-SUP-03.4 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-SUP-04 | Quản lý trung tâm thông báo Admin | UC-SUP-04 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |
| UC-SUP-05 | Giám sát hàng đợi sự cố và phục hồi worker | UC-SUP-05.1, UC-SUP-05.2 | Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng. |
| UC-SUP-06 | Hỏi trợ lý AI theo phạm vi chủ trọ | UC-SUP-06 | Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ. |

UC mới đáng chú ý: UC-SYS-09 nhận lời mời STAFF. Các trường hợp split được ghi từng dòng thay vì đánh lại toàn bộ mã, nhằm giữ khả năng so sánh với báo cáo và sơ đồ cũ. 164 là số catalog mới, không phải số đặc tả A–J đã hoàn tất.

## 8 Điểm chưa rõ khác biệt và kiểm thử

| Mã | Thực trạng hoặc điểm chưa xác định | Tác động và hướng xử lý |
| --- | --- | --- |
| GAP-01 | 155 UC ngoài SYS chưa hoàn tất A–J; catalog mới chỉ có wiring và ranh giới đọc ở service. | Không nghiệm thu toàn hệ thống từ đợt 1. Đặc tả tiếp theo nhóm, bắt đầu tài sản/hợp đồng và tài chính. |
| GAP-02 | Không có bộ yêu cầu chuẩn hoặc chính sách nghiệp vụ được phê duyệt độc lập. | Chỉ kết luận khác biệt so với báo cáo cũ, không tuyên bố code vi phạm yêu cầu khách hàng chưa được cung cấp. |
| GAP-03 | Không đọc DB runtime, secrets hoặc xác nhận migrations production. | Không bịa volume, dữ liệu thật, trạng thái triển khai, CORS thực, provider credentials hoặc SLA vận hành. |
| GAP-04 | STAFF decorator và interceptor có giao khác nhau; một số quyền mang tên có nhưng controller không được phép. | Báo cáo cũ không được mô tả đầy đủ quyền STAFF chỉ theo annotation. Xác nhận kỳ vọng người sở hữu nghiệp vụ trước khi sửa code. |
| GAP-05 | Register tạo User trước issueSession; accept invite commit trước issueSession. | Không viết bảo đảm thất bại luôn giữ nguyên dữ liệu. Xác định quy trình xử lý tài khoản đã tạo nhưng client chưa nhận phiên. |
| GAP-06 | Đặt lại mật khẩu có thể đã commit rồi UI báo lỗi do logout; UI không phân biệt lỗi hậu commit. | Đây là khác biệt hiển thị/trạng thái, không được mô tả rằng mật khẩu chưa đổi mỗi khi UI báo lỗi. |
| GAP-07 | Checkbox ghi nhớ và đồng ý điều khoản chưa có bằng chứng điều khiển TTL hoặc lưu chấp thuận backend. | Không thêm chính sách thời hạn theo checkbox hay bằng chứng pháp lý đã đồng ý. |
| GAP-08 | Thanh toán thẻ là demo; kênh gửi mail/storage/worker cần cấu hình. | Không nói đã tích hợp ngân hàng hoặc đã gửi thư khi chỉ có job; cần kiểm tra môi trường và nhà cung cấp riêng. |
| GAP-09 | Báo cáo cũ dùng nhánh thay thế/ngoại lệ chung và API mapping theo gợi ý tên; chưa đủ chứng cứ từng bước. | Thay riêng nhóm SYS; catalog mới route AST chính xác. Không tái gắn nhãn verified cho các bảng cũ. |
| GAP-10 | Không thấy tự merge seeker vào Tenant khi accept email đã tồn tại. | Email trùng trả conflict; không viết luồng tự hợp nhất. Nếu cần merge, đó là TO-BE riêng. |
| GAP-11 | Danh sách phiên API mọi vai trò; UI quản lý phiên được xác nhận tại Admin. | Không dựng thao tác trên màn hình landlord/tenant/staff chưa có bằng chứng. |
| GAP-12 | RegisterDto fullName IsNotEmpty kiểm tra trước trim; email register không có max như forgot. | Ghi ràng buộc endpoint cụ thể; không áp đồng loạt nonblank/max254 từ biểu mẫu khác. |

### 8.1 Bằng chứng kiểm thử đã thực thi

| Lệnh và phạm vi | Kết quả | Giới hạn chứng minh |
| --- | --- | --- |
| npm test -- --runInBand: auth.service, jwt.strategy, account-access.service, admin-mfa.service, roles.guard, property-scope, tenant-invites.service | 7 suites; 31 tests pass | Unit/mock tests; tenant-invites suite không tự chứng minh accept E2E, account-access suite tập trung rate-limit gửi. |
| flutter test --reporter expanded test/features/auth test/data/auth test/core/network/api_client_test.dart | 48 tests pass | Có đăng ký hai loại tài khoản, validation, duplicate/rate-limit/network, recovery UI, refresh/session isolation. Không phải thiết bị thật hay backend thật. |
| Hash vùng liên quan auth/common/tenants/staff và UI/data/network/tests | Trùng manifest tại thời điểm kiểm tra | Không suy các module ngoài vùng này đã được chạy với cùng độ phủ. |
| backend/test/e2e/app-functional.e2e-spec.ts và các E2E khác | Có source; chưa chạy | Có kịch bản nhận lời mời Tenant/STAFF đồng thời và hết hạn. Không kết luận transaction/lock/concurrency đã được xác minh bằng DB thực từ lần chạy unit này. |

Log nguyên trạng: evidence/auth-backend-tests.log và evidence/auth-flutter-tests.log. Các số chạy toàn bộ hệ thống ở đợt trước không dùng làm bằng chứng cho snapshot hiện tại. Acceptance scenarios mục J phải được thực thi độc lập để có kết luận nghiệm thu; báo cáo này không thay thế biên bản test.

### 8.2 Đề xuất cải tiến tách khỏi AS IS

Các mục sau chỉ là đề xuất, chưa phải hành vi hiện có: làm rõ trạng thái tạo tài khoản thành công nhưng cấp phiên thất bại; thông báo UI phân biệt redeem thành công và logout lỗi; quyết định chính sách merge seeker–Tenant; thống nhất ý định cấp quyền STAFF với interceptor; xác định có cần lưu chấp thuận điều khoản và ý nghĩa ghi nhớ đăng nhập. Không sửa code ứng dụng trong đợt tài liệu này.

### 8.3 Thứ tự hoàn thiện các đợt tiếp theo

| Ưu tiên | Nhóm | Đầu ra bắt buộc trước khi đánh dấu hoàn tất |
| --- | --- | --- |
| 1 | OPT và TNT | Đối chiếu UI–API–service–schema; lease/deposit/settlement/turnover/lifecycle theo trạng thái và transaction; A–J từng UC. |
| 2 | BIL và TEN | Hóa đơn, cash receipt/allocation/payment/proof/reversal/refund/demo; ma trận biến động số dư và lỗi hậu commit. |
| 3 | DIS | Tin, lịch xem, review, moderation và appeal; version/capacity/scope; cập nhật quan hệ và sơ đồ UC. |
| 4 | OPS, STF, ADM và SUP | Ma trận permission hiệu lực đến action, worker/config-dependent behavior; A–J, BR và test scenarios riêng từng mục tiêu. |
