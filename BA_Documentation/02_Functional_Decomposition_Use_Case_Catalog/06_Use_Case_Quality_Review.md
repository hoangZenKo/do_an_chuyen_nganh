# Báo cáo rà soát gộp/tách và chất lượng Use Case

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Kết luận chuẩn hóa

162 UC, 16 nhóm. So với catalog 164: giữ 147 mã, bổ sung 15 mã cho mục tiêu tách/làm rõ hoặc chức năng đã có code, 17 mã cũ chuyển hướng/phân loại lại. **164 − 17 + 15 = 162**. Không xóa chức năng ứng dụng. 395/405 endpoint liên kết UC, 10 endpoint thuộc 9 nhóm cơ chế kỹ thuật; không là bằng chứng chạy end-to-end.

## 2. Rà soát tám câu hỏi

| Câu hỏi | Phát hiện và xử lý | Truy vết |
| --- | --- | --- |
| 1. UC chia quá nhỏ? | Restore khu, gửi duyệt/xác nhận còn phòng, PDF/CSV, hướng dẫn chuyển khoản, read notification, attachment/timeline và step-up từng bị tách quá mức; chuyển vào mục tiêu cha/kỹ thuật. | Dòng Gộp/Phân loại tại mục 3. |
| 2. UC nên gộp? | Tạo hợp đồng trực tiếp/từ lịch cùng đích quan hệ thuê; giữ biến thể Actor và lịch. Thông báo cá nhân gộp mục tiêu, không gộp bảng dữ liệu. | UC-DIS-11 → UC-TNT-05; DIS-14/TEN-09.1 → SUP-04. |
| 3. UC cần tách? | Gia hạn/chuyển/trả là ba đích riêng; requester khác người xử lý; maker khác checker; nộp khác xét; review khác báo cáo tin; mẫu trả lời khác hợp nhất/đánh giá. | 8 quyết định Tách ở mục 3. |
| 4. UC trùng? | Loại mã hợp đồng trùng, gộp đầu ra PDF/CSV, không tạo thêm UC cho từng API hộp thư. | Không còn trùng đã xác nhận mà không lý do; cặp gần nhau có lý do mục 4. |
| 5. UC thiếu bằng chứng? | Mọi UC có controller/service hoặc logic Flutter được đọc. 3 ứng viên chưa đủ bằng chứng ngoài catalog; 9 UC một phần. | GAP-01…03, giới hạn mục 6; file/provider adapter không đồng nghĩa runtime đạt. |
| 6. Actor sai? | Chặn STAFF đúng interceptor; sửa quyền phí/duyệt/khóa; không tạo role seeker; support phải qua service.manage. | Actor Catalog; matrix và ACL handler. |
| 7. Nhóm sai? | Chi phí G09, báo cáo G11, nội dung G13, hỗ trợ G14, chính sách/đối soát/phản hồi thử nghiệm G16; giữ prefix để truy vết. | FDD mỗi UC một nơi. |
| 8. Thao tác kỹ thuật? | Refresh, /me, capability, step-up, health, upload, CLI tri thức, onboarding, backup, demo reconcile không tạo UC mới. | 9 nhóm TECH; giám sát incident/retry có đích quản trị nên vẫn giữ UC. |

## 3. Nhật ký quyết định

Đã áp dụng các đề xuất vào catalog dự thảo để chỉ có một baseline. Đây là sửa tài liệu, không sửa ứng dụng. Số quyết định khác số UC thay đổi: một trường hợp có thể giữ mã cha hoặc sinh nhiều mã con. Người dùng duyệt trước Giai đoạn 3.

| Loại | Số trường hợp |
| --- | --- |
| Gộp | 13 |
| Phân bổ lại | 2 |
| Phân loại lại | 1 |
| Tái phân ranh giới | 1 |
| Tách | 8 |
| Bổ sung từ code | 2 |

| Loại | Mã cũ | Mã giữ/đích | Lý do | Bằng chứng |
| --- | --- | --- | --- | --- |
| Gộp | UC-OPT-04.2 | UC-OPT-04.1 | Lưu trữ/khôi phục là hai chiều của mục tiêu quản lý vòng đời khu, cùng quyền; vẫn giữ hai nhánh kiểm tra điều kiện. | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:87` (PropertiesController.updateStatus)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:89` (PropertiesService.updateStatus) |
| Gộp | UC-TNT-13 | UC-TNT-04 | PDF là đầu ra của tra cứu hợp đồng ở tenant_detail_screen cho chủ trọ/nhân viên; chưa thấy cổng TENANT nối shareLeasePdf. Không tạo UC xuất/ký số độc lập. | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:50` (LeasesController.expiring)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:271` (LeasesService.expiring)<br>`/Users/hoang/Rental_room_management/lib/features/tenants/lease_pdf.dart:1` |
| Gộp | UC-BIL-08.2 | UC-BIL-04, UC-TEN-03 | Xuất/chia sẻ PDF là lựa chọn đầu ra sau khi được đọc hóa đơn, không phải nghĩa vụ thanh toán mới. | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:90` (BillingController.invoices)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:794` (BillingService.listInvoices)<br>`/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1` |
| Gộp | UC-TEN-10 | UC-TEN-04 | Xem tài khoản/QR là bước chuẩn bị gửi chứng từ chuyển khoản của cùng hóa đơn; không phải thanh toán tự động. | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:70` (TenantPortalController.submitPaymentProof)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:426` (TenantPortalService.submitPaymentProof) |
| Gộp | UC-DIS-06.1 | UC-DIS-05 | Soạn/sửa và gửi kiểm duyệt cùng phục vụ đưa tin của mình ra công khai; gửi duyệt không tạo mục tiêu độc lập ở mức catalog. | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:55` (LandlordListingsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList) |
| Gộp | UC-DIS-06.3 | UC-DIS-05 | Xác nhận còn phòng là nhánh duy trì tin cho thuê, không tạo UC chỉ cho một nút cập nhật thời điểm. | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:55` (LandlordListingsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList) |
| Gộp | UC-ADM-04.2 | UC-ADM-04.1 | Đình chỉ/khôi phục là hai chiều của quản lý quyền hoạt động tài khoản với cùng capability; không phục hồi token đã bị thu hồi. | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:25` (AdminConsoleController.suspend)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:56` (AdminConsoleService.status) |
| Phân bổ lại | UC-ADM-25 | UC-ADM-06.1, UC-ADM-04.3 | Tra cứu/gửi lại lời mời thuộc cấp tài khoản Admin; thu hồi phiên thuộc mục tiêu kiểm soát truy cập, không tạo UC lifecycle tổng hợp. | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:39` (AdminConsoleController.admins)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` (AdminConsoleService.accounts) |
| Phân loại lại | UC-ADM-07.2 | TECH-03 | Cấp token step-up chỉ hỗ trợ thao tác nhạy cảm; không là mục tiêu nghiệp vụ độc lập. MFA thiết lập vẫn giữ UC. | `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.service.ts:1` |
| Gộp | UC-DIS-14 | UC-SUP-04 | Đọc/đánh dấu thông báo cá nhân là cùng mục tiêu; giữ nguồn dữ liệu và phạm vi endpoint thành các biến thể, không gộp bảng dữ liệu. | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:14` (NotificationCenterController.list)<br>`/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` (PlatformNotificationService.list) |
| Gộp | UC-TEN-09.1 | UC-SUP-04 | Đọc/đánh dấu thông báo cá nhân là cùng mục tiêu; giữ nguồn dữ liệu và phạm vi endpoint thành các biến thể, không gộp bảng dữ liệu. | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:14` (NotificationCenterController.list)<br>`/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` (PlatformNotificationService.list) |
| Phân bổ lại | UC-OPS-08 | UC-SUP-04, UC-BIL-18.2, UC-TEN-09.2 | UC cũ trộn hộp thông báo, nhắc nợ provider và tin test mô phỏng; chuyển về đúng mục tiêu, không mất hành vi. | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:14` (NotificationCenterController.list)<br>`/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` (PlatformNotificationService.list) |
| Gộp | UC-BIL-21 | UC-BIL-20 | CSV là đầu ra của mục tiêu xem báo cáo tháng; giữ quyền report.export riêng cho biến thể xuất. | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:18` (ReportsController.monthly)<br>`/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:18` (ReportsService.monthly) |
| Tái phân ranh giới | UC-DIS-09, UC-DIS-10 | UC-DIS-09, UC-DIS-10 | Tách mục tiêu người đặt và chủ trọ; đổi/hủy là biến thể, không tạo UC riêng cho từng trạng thái. | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:68` (HousingController.book)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:83` (HousingService.book) |
| Tách | UC-OPS-06 | UC-OPS-06, UC-OPS-06.1 | Thiết lập lịch và thực hiện công việc có kết quả bền vững khác nhau; tác vụ sinh tự động không thành Actor hệ thống. | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:28` (P1OperationsController.templates)<br>`/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:41` (RecurringService.templates) |
| Tách | UC-SUP-01 | UC-SUP-01, UC-SUP-01.1 | Người yêu cầu chỉ trao đổi ticket của mình; nhân sự hỗ trợ là ADMIN có capability, quyền nội bộ và mục tiêu xử lý riêng. | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:15` (SupportController.create)<br>`/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:46` (SupportService.create) |
| Gộp | UC-SUP-03.1 | UC-SUP-01, UC-SUP-01.1 | Tệp quét sạch là chứng cứ kèm trao đổi ticket; không tạo UC cho thao tác tải lên; điều kiện scanner giữ nguyên. | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:15` (SupportController.create)<br>`/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:46` (SupportService.create) |
| Gộp | UC-SUP-03.4 | UC-SUP-01.1 | Liên kết tài nguyên/timeline giúp xử lý cùng hồ sơ, không có mục tiêu nghiệp vụ độc lập với hồ sơ hỗ trợ. | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:16` (SupportController.list)<br>`/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:63` (SupportService.list) |
| Tách | UC-SUP-03.2 | UC-SUP-03.2, UC-SUP-03.2.1, UC-SUP-03.2.2, UC-SUP-01.1 | Mẫu trả lời, hợp nhất hồ sơ và đánh giá sau hỗ trợ có mục tiêu/Actor khác nhau; gán nhãn là nhánh xử lý hồ sơ. | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:18` (SupportToolsController.templates)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:71` (SupportToolsService.templates) |
| Tách | UC-ADM-12 | UC-ADM-12, UC-ADM-12.1 | Báo cáo tin và review/reply là đối tượng, quyết định và permission độc lập; không cấp quyền reviews cho người chỉ có listings. | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:52` (AdminRoomReviewsController.queue)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:140` (ReviewsService.queue) |
| Tách | UC-ADM-18 | UC-ADM-18.1, UC-ADM-18 | Chủ trọ tự nộp không có quyền xét; bên xét là quản trị có capability. Tách theo mục tiêu và thẩm quyền thực tế. | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:62` (LandlordVerificationController.own)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:15` (AdminVerificationService.own) |
| Tách | UC-ADM-15 | UC-ADM-15, UC-ADM-15.1 | Maker lập và checker duyệt tạo hai kết quả/điều kiện độc lập; cùng role ADMIN nhưng không được tự duyệt đề xuất. | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:14` (FinanceReconciliationController.importStatement)<br>`/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:18` (FinanceReconciliationService.importStatement) |
| Bổ sung từ code | Chưa có mã trong catalog 164 | UC-DIS-16, UC-DIS-17 | Catalog 164 chưa bao quát mục tiêu so sánh tối đa 3 tin và bộ ước tính chi phí có logic Flutter; không phải chức năng mới của ứng dụng. | `/Users/hoang/Rental_room_management/lib/features/listings/listing_comparison_screen.dart:1`<br>`/Users/hoang/Rental_room_management/lib/features/listings/listings_providers.dart:1` |
| Tách | UC-TEN-07 | UC-TEN-07.1, UC-TEN-07.2, UC-TEN-07.3 | Gia hạn, chuyển phòng và trả phòng là ba đích nghiệp vụ độc lập, chung hạ tầng request nhưng khác dữ liệu, điều kiện và kết quả. | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:15` (TenantLifecyclePortalController.requests)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` (TenantLifecycleService.requests) |
| Tách | UC-ADM-11 | UC-ADM-11, UC-ADM-11.1 | Xác minh thông tin và quyết định công khai là hai mục tiêu khác nhau; verified badge không tự thay thế xét duyệt đăng tin. | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:62` (AdminConsoleController.queue)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:238` (AdminConsoleService.queue) |
| Bổ sung từ code | Chưa có mã trong catalog 164 | UC-SYS-10, UC-STF-04 | Làm rõ hai mục tiêu đã có triển khai nhưng catalog cũ gộp vào reset hoặc mời: người nhận lời mời đặt mật khẩu; STAFF chỉ tra cứu nhân sự bằng staff.view. | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:20` (AccountAccessController.redeem)<br>`/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:54` (AccountAccessService.redeem) |
| Gộp | UC-DIS-11 | UC-TNT-05 | Tạo hợp đồng trực tiếp hoặc từ lịch xem cùng đích thiết lập quan hệ thuê. Giữ biến thể lịch COMPLETED → LEASED/ẩn tin, chỉ LANDLORD; không tạo UC hợp đồng trùng ở nhóm tìm phòng. | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:29` (LeasesController.create)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:87` (LeasesService.create) |

## 4. Xem xét nhưng không gộp thêm

| UC/cặp gần nhau | Lý do giữ và ranh giới |
| --- | --- |
| CRUD khu/phòng/Tenant | Tạo mới có uniqueness/quota/linkage khác duy trì hồ sơ hiện hữu; xóa/lifecycle có hậu quả và ràng buộc lịch sử khác. Không tách từng field. |
| UC-OPT-06.2 / 07.1 / 07.2 | Metadata, trạng thái vận hành và isActive có kết quả/điều kiện lease/turnover khác dù dùng PATCH; không coi VACANT/OCCUPIED chuyển tùy ý. |
| UC-TNT-06.2 / UC-TEN-07.1 / UC-TNT-10 / 11 | Thay điều khoản, đề nghị, xét và thực hiện có Actor/quyền/kết quả bền vững khác; APPROVED không mặc định execute. |
| UC-TNT-08 / 09 / UC-OPS-05 | Chốt nghĩa vụ, ghi thực trả cọc và chuẩn bị phòng là ba kết quả; không tự tất toán nợ cũ, chuyển tiền hay giải phóng phòng. |
| UC-BIL-02 / 03 / 17.1 / 17.2 | Đơn lẻ, hàng loạt, cấu hình quy tắc và chạy đợt có đơn vị nghiệp vụ/đầu ra khác; preview và chống trùng vẫn là bước/rule nội bộ. |
| Payment / receipt / allocation / reversal / refund | Payment gắn hóa đơn; receipt giữ số dư; allocation phân bổ; đảo/giải phân bổ/hoàn có sổ tiền và permission riêng. Không gom một UC Thanh toán. |
| UC-BIL-15 / 16 / UC-OPT-09 | Đề xuất, phê duyệt biểu phí và quản lý phí phòng khác quyền và kết quả; STAFF chỉ đọc impact. |
| UC-SUP-04 / UC-TEN-09.3 | Đọc hộp thư cá nhân khác acknowledgement Announcement có receipt theo đợt phát. |
| UC-OPS-01 / 02 / 03 / UC-TEN-06 | Người thuê gửi sự cố, bên vận hành theo dõi, điều phối và chốt/chi phí có Actor, quyền và kết quả khác. |
| UC-ADM-02 / 08 / 10 | Tra cứu tài khoản, kho phòng và tìm đa tài nguyên khác đích/ngữ cảnh; global search chỉ định vị read-only, không thay quyền dữ liệu. |
| UC-DIS-12 / UC-ADM-12; UC-ADM-11 / 11.1 | Người thuê viết và Admin xét review khác Actor; xác minh tin khác quyết định công khai. |
| UC-ADM-18 / 18.1; UC-ADM-19 | Nộp hồ sơ chủ trọ khác người xét; trình/xét khu hiện cùng ADMIN trong trách nhiệm registry. Không suy LANDLORD tự trình khu. |
| UC-OPS-06 / 06.1 | Thiết lập lịch khác xác nhận hoàn thành đầu việc. Sinh task nền không thành Actor/UC độc lập. |
| UC-SUP-05.1 / 05.2 / UC-BIL-18.3 | Khôi phục sự cố/giao nhận có Actor chủ động và kết quả lưu lại, khác helper cấp token hoặc probe hạ tầng. |

## 5. Quy tắc CRUD và cơ chế kỹ thuật

Không chọn một quy tắc CRUD duy nhất cho mọi đối tượng: khu/phòng/Tenant có tạo định danh, quota/lịch sử và lifecycle nên giữ mục tiêu riêng; chi phí, tài sản, slot, mẫu và bộ lọc cá nhân là quản lý một đối tượng gắn kết nên không tách từng API. Điều chỉnh, đảo/hoàn, duyệt và cấp quyền không gom CRUD vì luật tiền/quyền độc lập. Không đếm API hay màn hình thành UC.

## 6. Mức xác minh và giới hạn

| UC một phần | Giới hạn |
| --- | --- |
| UC-SYS-06 — Khôi phục mật khẩu bằng liên kết một lần | Đã có token, thu hồi phiên và job giao link; chưa kiểm chứng email/provider thật. |
| UC-BIL-18.2 — Gửi nhắc nợ theo chính sách | APP/outbox có triển khai; EMAIL/ZALO/webhook/ZNS phụ thuộc cấu hình và chưa xác nhận giao thực. |
| UC-SUP-06 — Hỏi trợ lý AI và đọc nguồn hướng dẫn | Retrieval, scope và fallback có code/test; chưa gọi model Ollama thật trong khảo sát. |
| UC-SUP-05.2 — Theo dõi hàng đợi giao nhận | Theo dõi/retry job có code; chưa xác nhận dịch vụ giao nhận ngoài hệ thống. |
| UC-ADM-03.1 — Tạo hoặc mời tài khoản chủ trọ | Nhánh mật khẩu trực tiếp giới hạn môi trường dev; nhánh lời mời phụ thuộc giao link ngoài. |
| UC-ADM-05.2 — Yêu cầu khôi phục truy cập cho tài khoản | Xếp hàng yêu cầu khôi phục; chưa xác nhận email thực. |
| UC-ADM-06.1 — Cấp và quản lý quyền quản trị viên | Có cấp quyền/lời mời/gửi lại; giao nhận kích hoạt bên ngoài chưa được kiểm chứng. |
| UC-SUP-01 — Gửi và theo dõi yêu cầu hỗ trợ | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Luồng ticket có triển khai; biến thể tệp đính kèm fail-closed khi scanner chưa có, chưa xác nhận scanner thật. |
| UC-SUP-01.1 — Tiếp nhận và xử lý hồ sơ hỗ trợ | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Quyền xử lý ticket có code; tệp kèm cần scanner/storage và chưa kiểm chứng runtime ngoài. |

151 UC xác minh tĩnh, 9 một phần, 1 DEMO, 1 MÔ PHỎNG. Tệp test không tự nâng trạng thái. Tenant/staff invite trả inviteCode/activationPath nên không đánh một phần chỉ vì thiếu email: code không hứa tự gửi email. Biến thể STAFF bị chặn được ghi thành gap; UC LANDLORD tương ứng vẫn có thể xác minh tĩnh.

## 7. Kiểm tra cuối

- Mỗi UC có mã, tên, mục tiêu, Actor, nhóm, bằng chứng và trạng thái; hai mục tiêu so sánh/ước tính chỉ có Flutter, không bịa backend/DB.
- Tập mã 162 UC trùng giữa catalog, matrix, JSON và FDD; mỗi UC một nơi trong cây.
- 164 mã gần nhất và 63 mã lịch sử có crosswalk; 180 mục khảo sát và 405 endpoint có disposition.
- Không viết đặc tả chi tiết hay UML Use Case Diagram; WBS/SVG chỉ phân cấp. Kết quả lệnh kiểm tra thực tế nằm Validation_Result.json, không thay kiểm thử hành vi ứng dụng.

## 8. Các điểm cần người dùng duyệt trước Giai đoạn 3

1. Duyệt 13 quyết định gộp, 8 tách, 2 phân bổ lại, 1 phân loại kỹ thuật, 1 tái phân ranh giới và 2 bổ sung từ code; không nhầm số trường hợp với số mã.
2. Duyệt 5 Actor chính và 5 bên phối hợp có điều kiện. Seeker/renter là ngữ cảnh TENANT; support/moderator/maker/checker là trách nhiệm ADMIN, không role mới.
3. Giữ 9 UC một phần và 2 demo/mô phỏng với nhãn giới hạn; không viết như provider thực đã giao dịch thành công.
4. Giữ hạn chế STAFF operation/notification/audit/support/invite/upload như AS-IS; không sửa code hoặc âm thầm chuyển tài liệu sang TO-BE.
5. Giữ 3 GAP ngoài catalog: thanh toán thật, ký số pháp lý, tự sửa hồ sơ. Cần bằng chứng khác nếu muốn đưa vào phạm vi, không đề xuất chúng như chức năng hiện có.
6. Nếu cần khác quyền/vận hành hiện tại, lập yêu cầu TO-BE riêng sau khi duyệt baseline; bước này chưa yêu cầu quyết định thay đổi ứng dụng.
