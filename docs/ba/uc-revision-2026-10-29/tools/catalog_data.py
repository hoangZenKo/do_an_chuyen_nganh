GROUPS = {
    'SYS': 'Tài khoản và phiên làm việc', 'DIS': 'Khám phá và tìm thuê phòng',
    'OPT': 'Khu trọ và phòng', 'TNT': 'Người thuê và hợp đồng',
    'BIL': 'Hóa đơn và sổ thu chi', 'OPS': 'Vận hành nhà trọ',
    'TEN': 'Cổng người thuê', 'ADM': 'Quản trị nền tảng',
    'SUP': 'Hỗ trợ và giám sát', 'STF': 'Nhân viên của chủ trọ',
}

DATA = r'''
SYS-01|Đăng ký tài khoản chủ trọ|Khách|Tạo User LANDLORD và nhận phiên đăng nhập|AuthController.register
SYS-02|Đăng ký tài khoản tìm phòng|Khách|Tạo User TENANT chưa tự sinh Tenant hay Lease|AuthController.registerSeeker
SYS-03|Đăng nhập|Người có tài khoản|Nhận phiên đúng danh tính và điều hướng theo vai trò|AuthController.login
SYS-05.1|Đăng xuất phiên hiện tại|Người đã đăng nhập|Thu hồi phiên gắn refresh token và rời phiên cục bộ|AuthController.logout
SYS-05.2|Xem và thu hồi các phiên của mình|Người đã đăng nhập|Kiểm soát thiết bị đang truy cập tài khoản|AuthController.sessions,revokeSession,revokeOtherSessions
SYS-06|Khôi phục mật khẩu bằng liên kết một lần|Người có tài khoản|Đặt lại mật khẩu qua token giao nhận riêng|AccountAccessController.forgot,redeem
SYS-07|Đổi mật khẩu khi đang đăng nhập|Người đã đăng nhập|Thay mật khẩu sau khi xác minh mật khẩu hiện tại|AuthController.changePassword
SYS-08|Kích hoạt tài khoản người thuê từ lời mời|Người nhận lời mời|Tạo User TENANT gắn Tenant đã được mời|TenantInvitesController.accept
SYS-09|Kích hoạt tài khoản nhân viên từ lời mời|Người nhận lời mời|Nhận tài khoản STAFF và phạm vi đã được chủ trọ cấp|StaffController.accept
DIS-01|Tìm và lọc tin phòng công khai|Khách hoặc Người tìm phòng|Tìm tin công khai theo bộ lọc và cơ sở trường|PublicListingsController.list;PublicCampusesController.list
DIS-02|Xem chi tiết tin và đánh giá công khai|Khách hoặc Người tìm phòng|Đọc nội dung tin còn hiển thị cùng đánh giá được duyệt|PublicListingsController.detail;PublicRoomReviewsController.list
DIS-03|Lưu và bỏ lưu phòng yêu thích|TENANT|Duy trì danh sách tin quan tâm của mình|HousingController.favorites,favorite,save,remove
DIS-04|Lưu bộ lọc và theo dõi tin khớp|TENANT|Lưu tối đa 10 tìm kiếm và đọc cảnh báo kết quả mới|SavedSearchesController.list,create,alerts,read,status,remove
DIS-05|Soạn và sửa bản nháp tin cho thuê|LANDLORD|Chuẩn bị nội dung tin của phòng thuộc mình|LandlordListingsController.list,create,update
DIS-06.1|Gửi tin cho thuê để kiểm duyệt|LANDLORD|Chuyển bản tin đủ điều kiện sang PENDING|LandlordListingsController.submit
DIS-06.2|Ẩn tin cho thuê của mình|LANDLORD|Ngừng công khai tin mà không xóa lịch sử|LandlordListingsController.hide
DIS-06.3|Xác nhận lại tình trạng còn phòng|LANDLORD|Ghi nhận lần xác nhận khả dụng của tin|LandlordListingsController.confirm
DIS-07|Báo cáo tin phòng không phù hợp|TENANT|Gửi ListingReport để admin xử lý|StudentListingsController.report
DIS-08|Quản lý khung giờ xem phòng|LANDLORD|Mở hoặc gỡ khung giờ cho lịch xem tin của mình|HousingController.slots,addSlot,removeSlot
DIS-09|Đặt và theo dõi lịch xem phòng|TENANT|Gửi RoomViewing cho tin và lịch hợp lệ|HousingController.book,viewings,viewing
DIS-10|Đổi lịch hủy và xử lý lịch xem|TENANT hoặc LANDLORD|Cập nhật lịch theo tác nhân trạng thái và version|HousingController.reschedule,update
DIS-11|Tạo hợp đồng từ lịch xem đã hoàn thành|LANDLORD|Chuyển lịch COMPLETED thành LEASED và ẩn tin|HousingController.lease
DIS-12|Viết sửa và rút đánh giá phòng đã thuê|TENANT|Gửi nội dung gắn hợp đồng đủ điều kiện để kiểm duyệt|RoomReviewsController.context,create,update,withdraw
DIS-13.1|Trả lời đánh giá phòng|LANDLORD|Gửi phản hồi của chủ trọ qua kiểm duyệt riêng|RoomReviewsController.landlord,reply
DIS-13.2|Gửi phản hồi về thử nghiệm tìm phòng|TENANT hoặc LANDLORD|Ghi PilotFeedback khi khu vực thử nghiệm được mở|HousingController.pilot,feedback
DIS-14|Xem thông báo hành trình tìm thuê|TENANT hoặc LANDLORD|Đọc thông báo lịch xem của chính tài khoản|HousingController.notifications,read
DIS-15|Xem quyết định và gửi kháng nghị kiểm duyệt|TENANT hoặc LANDLORD|Đề nghị xem lại quyết định thuộc tài nguyên của mình|MyModerationController.decisions,appeals,appeal,features
OPT-01|Xem dashboard và bản đồ phòng|LANDLORD hoặc STAFF có report.view|Theo dõi chỉ số và mở phòng trong phạm vi được cấp|DashboardController.metrics
OPT-02|Tra cứu và chọn khu trọ|LANDLORD hoặc STAFF có property.view|Đọc khu trọ theo bộ lọc lifecycle và phạm vi|PropertiesController.list,getById
OPT-03.1|Tạo khu trọ|LANDLORD|Thêm Property chưa lưu trữ trong hạn mức gói|PropertiesController.create
OPT-03.2|Cập nhật thông tin khu trọ|LANDLORD hoặc STAFF có property.manage|Sửa tên và địa chỉ khu thuộc phạm vi|PropertiesController.update
OPT-04.1|Lưu trữ khu trọ|LANDLORD hoặc STAFF có property.manage|Đặt isArchived khi không còn hợp đồng ACTIVE|PropertiesController.updateStatus
OPT-04.2|Khôi phục khu trọ đã lưu trữ|LANDLORD hoặc STAFF có property.manage|Bỏ lưu trữ sau kiểm tra hạn mức khu và phòng|PropertiesController.updateStatus
OPT-04.3|Xóa khu trọ chưa có phòng và lịch sử xét duyệt|LANDLORD hoặc STAFF có property.manage|Xóa vật lý khi các ràng buộc phụ thuộc cho phép|PropertiesController.remove
OPT-05|Tra cứu phòng và lịch sử liên quan|LANDLORD hoặc STAFF có room.view|Đọc phòng trong khu được cấp quyền|PropertyRoomsController.list;RoomsController.getById
OPT-06.1|Tạo phòng|LANDLORD hoặc STAFF có room.manage|Thêm Room vào khu hoạt động trong hạn mức|PropertyRoomsController.create
OPT-06.2|Cập nhật thông tin phòng|LANDLORD hoặc STAFF có room.manage|Sửa metadata không tự sửa giá thuê của hợp đồng cũ|RoomsController.update
OPT-07.1|Đổi trạng thái sử dụng phòng|LANDLORD hoặc STAFF có room.manage|Đặt trạng thái phòng không trái hợp đồng và turnover|RoomsController.update
OPT-07.2|Vô hiệu hóa hoặc khôi phục phòng|LANDLORD hoặc STAFF có room.manage|Đổi isActive và giữ lịch sử phòng|RoomsController.updateStatus
OPT-07.3|Xóa phòng chưa có lịch sử nghiệp vụ|LANDLORD hoặc STAFF có room.manage|Xóa phòng sau kiểm tra hợp đồng chỉ số hóa đơn lịch xem turnover|RoomsController.remove
OPT-08.1|Quản lý tài sản phòng|LANDLORD hoặc STAFF có room.manage|Duy trì RoomAsset của phòng thuộc phạm vi|RoomsController.assets,createAsset,updateAsset,removeAsset
OPT-08.2|Theo dõi lịch kiểm tra phòng|LANDLORD hoặc STAFF có room.manage|Lập sửa hoàn tất hoặc xóa RoomInspection|RoomsController.inspections,createInspection,updateInspection,completeInspection,removeInspection
OPT-09|Quản lý phiên bản phí dịch vụ phòng|LANDLORD hoặc STAFF có room.manage|Lưu lịch sử mức phí và tháng hiệu lực tại phòng|RoomsController.serviceFees,createServiceFee,updateServiceFee,tariffVersions,removeServiceFee
TNT-01|Tra cứu hồ sơ người thuê và tổng quan|LANDLORD hoặc STAFF có tenant.view|Đọc Tenant và tóm tắt lịch sử đúng phạm vi|TenantsController.list,getById,overview
TNT-02.1|Tạo hồ sơ người thuê|LANDLORD hoặc STAFF có tenant.manage|Tạo Tenant nghiệp vụ chưa mặc nhiên có User|TenantsController.create
TNT-02.2|Cập nhật hồ sơ người thuê|LANDLORD hoặc STAFF có tenant.manage|Sửa dữ liệu hồ sơ thuộc chủ trọ|TenantsController.update
TNT-02.3|Vô hiệu hóa hoặc khôi phục người thuê|LANDLORD hoặc STAFF có tenant.manage|Đổi isActive theo điều kiện hợp đồng|TenantsController.updateStatus
TNT-02.4|Xóa hồ sơ người thuê chưa có lịch sử|LANDLORD hoặc STAFF có tenant.manage|Xóa Tenant khi không còn ràng buộc nghiệp vụ|TenantsController.remove
TNT-03|Tạo lời mời truy cập cổng người thuê|LANDLORD|Nhận mã kích hoạt dùng một lần cho Tenant chưa có User|TenantInvitesController.create
TNT-03.1|Tạo trực tiếp tài khoản cho hồ sơ người thuê|LANDLORD hoặc STAFF có tenant.manage|Liên kết tài khoản đăng nhập mới với Tenant|TenantsController.createAccount
TNT-04|Tra cứu hợp đồng và cảnh báo hết hạn|LANDLORD hoặc STAFF có lease.view|Đọc hợp đồng theo phòng người thuê và số ngày cảnh báo|LeasesController.expiring;RoomLeasesController.list;TenantLeasesController.list
TNT-05|Tạo hợp đồng và ghi nhận cọc ban đầu|LANDLORD hoặc STAFF có lease.manage|Tạo Lease ACTIVE và chuyển phòng OCCUPIED trong transaction|LeasesController.create
TNT-06.1|Cập nhật điều khoản hợp đồng|LANDLORD hoặc STAFF có lease.manage|Lưu thay đổi điều khoản cùng LeaseChange|LeasesController.update
TNT-06.2|Gia hạn hợp đồng|LANDLORD hoặc STAFF có lease.manage|Đặt ngày kết thúc muộn hơn khi chưa quyết toán|LeasesController.renew
TNT-06.3|Kết thúc hợp đồng|LANDLORD hoặc STAFF có lease.manage|Đặt ENDED và khởi tạo turnover phòng|LeasesController.end
TNT-07|Tra cứu và ghi giao dịch cọc|LANDLORD hoặc STAFF có lease.manage khi ghi|Ghi thu hoàn khấu trừ hoặc điều chỉnh số dư cọc|LeasesController.deposits,createDeposit
TNT-08|Xem trước và xác nhận quyết toán trả phòng|LANDLORD|Chốt snapshot chi phí cọc và nghĩa vụ còn lại không tự chuyển tiền|LeasesController.settlement,previewSettlement,confirmSettlement
TNT-09|Ghi nhận đã hoàn cọc theo quyết toán|LANDLORD|Ghi REFUNDED và trạng thái hoàn cọc đã trả|LeasesController.recordSettlementRefund
TNT-10|Xét duyệt yêu cầu vòng đời thuê|LANDLORD hoặc STAFF có lease.manage|Đặt APPROVED hoặc REJECTED chưa tự đổi hợp đồng|TenantLifecycleController.requests,review
TNT-11|Thực thi yêu cầu vòng đời đã duyệt|LANDLORD hoặc STAFF có lease.manage|Thực hiện yêu cầu một lần theo requestKey và điều kiện Lease|TenantLifecycleController.execute
TNT-12.1|Quản lý người ở cùng hợp đồng|LANDLORD hoặc STAFF có lease.manage khi ghi|Thêm hoặc kết thúc người ở trong sức chứa phòng|TenantLifecycleController.occupants,addOccupant,removeOccupant
TNT-12.2|Lập biên bản bàn giao nhận phòng|LANDLORD|Lưu chỉ số hiện trạng và ảnh trước khi người thuê xác nhận|HousingController.handover,saveHandover
TNT-12.3|Xác nhận biên bản bàn giao nhận phòng|TENANT|Chấp nhận đúng version khi hợp đồng đến ngày hiệu lực|HousingController.acceptHandover
TNT-13|Xuất hoặc chia sẻ hợp đồng PDF|LANDLORD hoặc người được UI cho phép|Dựng PDF tại Flutter không phát sinh chữ ký số|LOCAL.leasePdf
BIL-01|Ghi chỉ số điện nước theo kỳ|LANDLORD hoặc STAFF có billing.create|Lưu lượng tiêu thụ và số tiền của phòng loại tiện ích kỳ|BillingController.meterReadings,createMeterReading
BIL-02|Xem trước và lập hóa đơn một hợp đồng|LANDLORD hoặc STAFF có billing.create|Phát hành hóa đơn với các dòng giá chụp tại kỳ lập|BillingController.activeLeases,previewInvoice,createInvoice
BIL-03|Lập hóa đơn hàng loạt|LANDLORD hoặc STAFF có billing.create|Kiểm tra trước và tạo kết quả cho từng hợp đồng đủ điều kiện|BillingController.bulkInvoicePreflight,createBulkInvoices
BIL-04|Tra cứu hóa đơn và tuổi nợ|LANDLORD hoặc STAFF có billing.view|Đọc số còn phải thu và nhóm ngày quá hạn|BillingController.invoices,invoice,aging,reminders
BIL-05|Sửa hạn thanh toán hoặc ghi chú hóa đơn|LANDLORD hoặc STAFF có billing.create|Đổi hạn và ghi chú mà không ghi đè dòng tiền|BillingController.updateInvoice
BIL-06|Thay thế hóa đơn chưa có lịch sử thanh toán|LANDLORD hoặc STAFF có billing.adjust|Hủy bản gốc và tạo revision mới có liên kết truy vết|BillingController.replaceInvoice
BIL-07|Phát hành credit note hoặc debit note|LANDLORD hoặc STAFF có billing.adjust|Điều chỉnh nghĩa vụ theo số tiền hoặc basisPoints|BillingController.adjustInvoice
BIL-08.1|Hủy hóa đơn đủ điều kiện|LANDLORD hoặc STAFF có billing.cancel|Đặt CANCELLED khi chưa có bản ghi Payment|BillingController.cancelInvoice
BIL-08.2|Xuất hoặc chia sẻ hóa đơn PDF|Người được quyền xem hóa đơn|Dựng bản PDF từ dữ liệu hóa đơn tại Flutter|LOCAL.invoicePdf
BIL-09|Ghi nhận thanh toán trực tiếp|LANDLORD hoặc STAFF có billing.record_payment|Thêm Payment dương không vượt dư của hóa đơn thật|BillingController.recordPayment
BIL-10|Tạo khoản thu cho người thuê|LANDLORD hoặc STAFF có billing.record_payment|Tạo BillingReceipt và giữ phần tiền chưa phân bổ|BillingController.receipts,createReceipt
BIL-11|Phân bổ khoản thu cho hóa đơn|LANDLORD hoặc STAFF có billing.record_payment|Đưa số tiền khả dụng vào hóa đơn cùng Tenant|BillingController.allocateReceipt
BIL-12.1|Giải phóng phân bổ khoản thu|LANDLORD hoặc STAFF có billing.reverse_payment|Đảo Payment của allocation và trả tiền về khả dụng|BillingController.releaseAllocation
BIL-12.2|Đảo thanh toán trực tiếp|LANDLORD hoặc STAFF có billing.reverse_payment|Ghi Payment REVERSAL cho khoản gốc chưa bị đảo|BillingController.reversePayment
BIL-13|Ghi nhận hoàn tiền từ khoản thu|LANDLORD hoặc STAFF có billing.refund|Giảm tiền khả dụng bằng ReceiptRefund có tham chiếu|BillingController.refundReceipt
BIL-14|Xét duyệt chứng từ thanh toán|LANDLORD hoặc STAFF có billing.approve_payment_proof|Chấp thuận tạo Payment hoặc từ chối không tăng paidAmount|BillingController.paymentProofs,reviewPaymentProof
BIL-15|Đề xuất biểu phí theo kỳ hiệu lực|LANDLORD hoặc STAFF có billing.create|Lưu BillingTariffVersion ở trạng thái PROPOSED|BillingController.tariffsList,proposeTariff
BIL-16|Phân tích tác động và duyệt biểu phí|LANDLORD|Duyệt hoặc từ chối đề xuất sau kiểm tra kỳ đã phát hành hoặc khóa|BillingController.tariffImpact,reviewTariff
BIL-17.1|Cấu hình lập hóa đơn định kỳ|LANDLORD hoặc STAFF có billing.create|Lưu lịch lập hóa đơn theo khu|BillingController.billingAutomation,updateBillingAutomation
BIL-17.2|Xem trước và chạy đợt lập hóa đơn|LANDLORD hoặc STAFF có billing.create|Chạy kỳ theo cấu hình và ghi kết quả BillingRun|BillingController.billingAutomationPreview,runBillingAutomation
BIL-18.1|Cấu hình chính sách nhắc nợ|LANDLORD hoặc STAFF có billing.policy và khu cụ thể|Lưu chính sách mặc định hoặc ghi đè theo khu|BillingController.reminderPolicy,updateReminderPolicy
BIL-18.2|Xếp hàng nhắc nợ theo chính sách|LANDLORD hoặc STAFF có billing.policy và khu cụ thể|Tạo tác vụ gửi phù hợp sở thích người thuê|BillingController.runReminders,enqueueReminders
BIL-18.3|Theo dõi và thử lại outbox hóa đơn|LANDLORD|Đọc sự kiện và yêu cầu thử lại theo trạng thái được phép|BillingController.outboxEvents,retryOutbox
BIL-19|Quản lý khoản chi vận hành|LANDLORD hoặc STAFF có expense.manage khi ghi|Lưu khoản Expense riêng với tiền thuê và tiền cọc|ExpensesController.list,create,getById,update,remove
BIL-20|Xem báo cáo tháng và chỉ số phân tích|LANDLORD hoặc STAFF có report.view|Đọc thu ròng chi phí công suất và công nợ theo định nghĩa code|ReportsController.monthly,analytics
BIL-21|Xuất nội dung báo cáo tháng CSV|LANDLORD hoặc STAFF có report.export|Nhận CSV và sao chép nội dung tại giao diện|ReportsController.monthlyExport
BIL-22|Khóa kỳ thanh toán của khu|LANDLORD|Lưu BillingPeriodLock ngăn các thao tác thuộc quy tắc khóa|BillingController.lockPeriod
BIL-23|Cấu hình tài khoản nhận chuyển khoản|LANDLORD|Lưu ngân hàng tài khoản và QR riêng theo version|TransferAccountController.account,save
OPS-01|Tiếp nhận và theo dõi phiếu bảo trì|LANDLORD hoặc STAFF có maintenance.manage khi ghi|Duy trì ticket nội dung bình luận và xóa theo điều kiện|MaintenanceController.list,create,getById,addComment,remove
OPS-02|Phân công và cập nhật bảo trì|LANDLORD hoặc STAFF có maintenance.manage trừ escalate|Gán nhân viên tiến độ hạn xử lý và chạy kiểm tra SLA|MaintenanceController.assignees,update,updateStatus,escalate
OPS-03|Hoàn tất bảo trì và liên kết khoản chi|LANDLORD hoặc STAFF có maintenance.complete|Đặt DONE và tùy chọn tạo Expense REPAIR một lần|MaintenanceController.complete
OPS-04|Theo dõi việc cần xử lý|LANDLORD|Đọc action items và đánh dấu đã xem theo tài khoản|OperationsController.actionItems,markRead
OPS-05|Chuẩn bị phòng sau trả phòng|LANDLORD|Đi qua RETURNED INSPECTION REPAIR CLEANING READY|P1OperationsController.list,create,advance
OPS-06|Quản lý việc định kỳ và checklist|LANDLORD|Lập RecurringOperation và cập nhật OperationTask phát sinh|P1OperationsController.templates,createRecurring,toggle,tasks,check
OPS-07|Soạn và phát thông báo người thuê|LANDLORD|Lưu mẫu nhóm lịch thông báo và theo dõi lượt đọc|AnnouncementsController.list,templates,groups,createTemplate,createGroup,create,receipts,cancel
OPS-08|Theo dõi lượt gửi và gửi nhắc Zalo|LANDLORD|Đọc delivery log và gửi nhắc qua chế độ cấu hình thực tế|NotificationsController.list,markRead,deliveryLogs,sendInvoiceRemindersZalo,createZaloTestMessage,createZaloManualMessage
OPS-09|Tra cứu nhật ký vận hành|LANDLORD|Đọc AuditLog thuộc chủ trọ theo bộ lọc|AuditController.list
TEN-01|Xem hồ sơ và tổng quan thuê của mình|TENANT có hồ sơ liên kết|Đọc thông tin thuê chỉ thuộc Tenant của tài khoản|TenantPortalController.me,dashboard
TEN-02|Xem hợp đồng cọc và quyết toán của mình|TENANT có hồ sơ liên kết|Đọc Lease và settlement không được sửa điều khoản|TenantPortalController.leases;TenantLifecyclePortalController.settlement
TEN-03|Xem hóa đơn và PDF của mình|TENANT có hồ sơ liên kết|Đọc hóa đơn đúng Tenant trước khi dựng PDF cục bộ|TenantPortalController.invoices,invoice
TEN-04|Gửi chứng từ thanh toán|TENANT có hồ sơ liên kết|Tạo PaymentProof PENDING không tự giảm công nợ|TenantPortalController.submitPaymentProof
TEN-05|Thanh toán bằng thẻ mô phỏng|TENANT ở môi trường demo|Thanh toán hóa đơn isDemo qua checkout nội bộ không dùng tiền thật|TenantOnlinePaymentsController.create,demoInvoice,status;DemoCardPaymentController.checkout,confirm
TEN-06|Gửi và trao đổi yêu cầu bảo trì|TENANT có hồ sơ liên kết|Tạo ticket và bình luận cho phòng gắn hợp đồng của mình|TenantPortalController.maintenance,createMaintenance,addMaintenanceComment
TEN-07|Gửi hủy và theo dõi yêu cầu vòng đời thuê|TENANT có hồ sơ liên kết|Đề nghị RENEWAL TRANSFER_ROOM CHECKOUT chưa sửa trực tiếp Lease|TenantLifecyclePortalController.requests,create,cancel,transferRooms
TEN-08.1|Xem người ở cùng hợp đồng|TENANT có hồ sơ liên kết|Đọc occupants nhưng không tự thêm hoặc xóa|TenantLifecyclePortalController.occupants
TEN-08.2|Thiết lập sở thích nhắc nợ|TENANT có hồ sơ liên kết|Đặt enabled và các kênh nhắc nợ được hỗ trợ|TenantLifecyclePortalController.preference,savePreference
TEN-09.1|Đọc thông báo cổng người thuê|TENANT có hồ sơ liên kết|Đánh dấu notification của mình đã đọc|TenantPortalController.notifications,markNotificationRead
TEN-09.2|Trao đổi tin nhắn mô phỏng Zalo trong portal|TENANT có hồ sơ liên kết|Lưu và đọc hội thoại trong ứng dụng không mặc nhiên gửi Zalo OA|TenantPortalController.zaloMessages,createZaloMessage,markZaloMessageRead
TEN-09.3|Đọc và xác nhận thông báo chủ trọ|TENANT có hồ sơ liên kết|Ghi lượt đọc hoặc acknowledgement Announcement|TenantAnnouncementsController.list,read
TEN-10|Xem hướng dẫn chuyển khoản của hóa đơn|TENANT có hồ sơ liên kết|Đọc tài khoản và QR chủ trọ trước khi gửi chứng từ|TransferInstructionsController.instructions
ADM-01|Xem tổng quan và phân tích nền tảng|ADMIN có admin.dashboard.view|Đọc overview analytics và công việc chờ theo quyền|AdminController.overview;AdminOverviewAnalyticsController.overview;AdminConsoleController.analytics;AdminWorkspaceController.summary,actionItems
ADM-02|Tra cứu tài khoản nền tảng|ADMIN có quyền đọc tương ứng|Đọc thông tin khách hàng được che theo projection|AdminConsoleController.accounts,account;AdminController.listLandlords,getLandlord
ADM-03.1|Tạo hoặc mời tài khoản chủ trọ|ADMIN có admin.accounts.manage|Tạo tài khoản LANDLORD hoặc công việc kích hoạt theo endpoint|AdminController.createLandlord
ADM-03.2|Cập nhật hồ sơ chủ trọ|ADMIN có admin.accounts.manage|Sửa dữ liệu chủ trọ không thay quyền Admin|AdminController.updateLandlord
ADM-04.1|Đình chỉ tài khoản và vô hiệu phiên|ADMIN có admin.accounts.suspend|Đặt inactive và tăng sessionVersion có tác động nhân viên phụ thuộc|AdminConsoleController.suspend;AdminController.updateLandlordStatus
ADM-04.2|Khôi phục tài khoản bị đình chỉ|ADMIN có admin.accounts.suspend|Đặt active không làm token đã thu hồi sống lại|AdminConsoleController.restore
ADM-04.3|Thu hồi phiên của tài khoản khách hàng|ADMIN có admin.sessions.revoke|Vô hiệu session và refresh token không xóa dữ liệu tài chính|AdminConsoleController.revoke
ADM-05.1|Mở thông tin cá nhân được che|ADMIN có admin.pii.reveal|Đọc email điện thoại có lý do và audit|AdminConsoleController.reveal
ADM-05.2|Yêu cầu khôi phục truy cập cho tài khoản|ADMIN có admin.accounts.manage|Xếp hàng liên kết đặt mật khẩu không trả mật khẩu mới|AdminConsoleController.reset
ADM-06.1|Quản lý hồ sơ và quyền Admin|ADMIN có admin.admins.manage và điều kiện cấp quyền|Cập nhật preset hoặc quyền trong tập được phép ủy quyền|AdminConsoleController.admins,adminAccess,profile,invite
ADM-06.2|Rà soát quyền Admin định kỳ|ADMIN có admin.admins.manage|Lưu kết quả rà soát và hạn rà soát tiếp theo cho người khác|AdminAccessReviewController.catalog,list,review
ADM-07.1|Thiết lập MFA Admin|ADMIN có phiên hợp lệ|Tạo và xác nhận cấu hình MFA với mã khôi phục|AdminSecurityController.status,enroll,confirm
ADM-07.2|Xác minh tăng cường cho thao tác nhạy cảm|ADMIN có quyền của thao tác đích|Nhận token step-up gắn session method path payload|AdminStepUpController.issue
ADM-08|Tra cứu khu và phòng toàn nền tảng|ADMIN có quyền inventory tương ứng|Đọc kho phòng và trạng thái tin tách biệt|AdminController.listProperties,getProperty,rooms
ADM-09|Tạo hoặc cập nhật khu thay chủ trọ|ADMIN có admin.properties.manage|Ghi Property của landlord đích qua luồng quản trị|AdminController.createProperty,updateProperty
ADM-10|Tìm kiếm và định vị tài nguyên|ADMIN có quyền theo loại tài nguyên|Trả kết quả từng loại được quyền đọc không vượt capability|AdminSearchController.searchAll,resources,detail
ADM-11|Nhận việc và kiểm duyệt tin đăng|ADMIN có quyền tin đăng|Nhận ModerationWorkItem và xét trạng thái tin hoặc batch theo quyền|AdminConsoleController.queue,work,item;AdminListingsController.list,review,verify;ModerationV2Controller.bulk,preview
ADM-12|Kiểm duyệt đánh giá và báo cáo vi phạm|ADMIN có quyền theo loại nội dung|Duyệt review reply hoặc xử lý ListingReport|AdminRoomReviewsController.queue,moderate,reply;AdminListingsController.reports,reviewReport
ADM-13.1|Quản lý chính sách kiểm duyệt|ADMIN có quyền chính sách|Tạo phiên bản và kích hoạt ModerationPolicy|ModerationPolicyController.list,create,activate
ADM-13.2|Xử lý kháng nghị kiểm duyệt|ADMIN có quyền kháng nghị và nội dung|Phân công và giải quyết ModerationAppeal|ModerationV2Controller.decisions,history,appeals,assign,resolve,reports
ADM-13.3|Đánh giá chất lượng kiểm duyệt|ADMIN có quyền đánh giá chất lượng|Lấy mẫu và đánh giá quyết định không tự đánh giá mình|ModerationPolicyController.quality,samples,sample,review
ADM-14|Tra cứu và xuất nhật ký quản trị|ADMIN có admin.audit.view và thêm admin.audit.export khi xuất|Đọc audit và xuất dữ liệu trong phạm vi capability|AdminConsoleController.audit,auditDetail,auditExport
ADM-15|Đối soát sao kê theo maker checker|ADMIN có admin.finance.reconcile|Nhập sao kê ghép chứng từ và duyệt đề xuất bởi người khác|FinanceReconciliationController.importStatement,lines,propose,candidates,proposals,approve,reject
ADM-16|Quản lý lịch và tải báo cáo Admin|ADMIN có admin.reports.manage và quyền nội dung|Lập lịch theo timezone chạy và tải kết quả của mình|GovernanceController.schedules,createSchedule,updateSchedule,runSchedule,runs,download,link,retry
ADM-17.1|Quản lý feature flags nghiệp vụ|ADMIN có quyền feature flags|Đổi enabled rollout roles theo version cho key cho phép|GovernanceController.flagsList,effective,flagsUpdate
ADM-17.2|Quản lý nhóm Admin|ADMIN có quyền nhóm|Duy trì nhóm thành viên và trạng thái hoạt động|GovernanceController.team,teams,createTeam,addMember,updateTeam,removeMember
ADM-18|Nộp và xét duyệt xác minh chủ trọ|LANDLORD nộp hoặc ADMIN có quyền xác minh và support.read|Lưu hồ sơ gắn ticket minh chứng và quyết định có version|LandlordVerificationController.own,submit;AdminRegistryController.verifications,submitVerification,reviewVerification
ADM-19|Trình và xét duyệt hồ sơ khu trọ|ADMIN có admin.properties.manage|Duyệt snapshot khu khi thông tin chưa thay đổi|AdminRegistryController.propertyReviews,submitProperty,reviewProperty
ADM-20|Quản lý danh mục gói dịch vụ|ADMIN có quyền plans|Lưu ServicePlan có giới hạn và version|AdminRegistryController.servicePlans,savePlan
ADM-21|Gán gói và xem lịch sử đăng ký|ADMIN có quyền plans|Ghi planSnapshot và SubscriptionEvent cho landlord|AdminRegistryController.subscriptions,subscriptionEvents,assignSubscription
ADM-22|Hủy quyền sử dụng gói đang hiệu lực|ADMIN có admin.plans.manage|Kết thúc hiệu lực không tự hoàn tiền hoặc xóa khu phòng|AdminRegistryController.cancelSubscription
ADM-23|Quản lý danh mục cơ sở trường|ADMIN có admin.campuses.manage|Duy trì SchoolCampus làm bộ lọc vị trí tìm phòng|AdminCampusesController.list,create,update
ADM-24|Tra cứu giao dịch tài chính nền tảng|ADMIN có admin.finance.read|Đọc dữ liệu giao dịch theo projection quản trị|AdminRegistryController.transactionList;GovernanceController.finance
ADM-25|Theo dõi kích hoạt và thu hồi phiên Admin|ADMIN có quyền quản trị Admin và phiên tương ứng|Xem lifecycle gửi lại lời mời hoặc thu hồi phiên Admin khác|AdminLifecycleController.detail,resend,revoke
ADM-26|Mô phỏng quyền Admin|ADMIN có admin.permissions.simulate|Tính quyền được phép không thay hồ sơ cấp quyền|GovernanceController.simulate
ADM-27|Đọc phản hồi thử nghiệm tìm phòng|ADMIN có admin.listings.moderate|Đọc PilotFeedback và thống kê theo trang|HousingController.feedbackList
SUP-01|Tạo và trao đổi hồ sơ hỗ trợ|LANDLORD TENANT hoặc ADMIN có quyền hỗ trợ|Theo dõi ticket công khai còn ghi chú nội bộ chỉ cho admin được cấp|SupportController.create,list,assignees,teams,detail,reply,note,assign,status;AdminConsoleController.context
SUP-02.1|Cấu hình phân công tự động hỗ trợ|ADMIN có quyền support tương ứng|Đặt skills và phân công theo khả dụng của người xử lý|SupportWorkflowController.skills,setSkills,autoAssign
SUP-02.2|Cấu hình và theo dõi SLA hỗ trợ|ADMIN có quyền SLA|Lưu lịch giờ làm và chính sách thời hạn hỗ trợ|SupportSlaController.policy,update
SUP-03.1|Đính kèm tệp vào ticket hỗ trợ|LANDLORD TENANT hoặc ADMIN theo quyền ticket|Quét tệp và gắn attachment vào ticket đọc được|SupportAttachmentController.upload
SUP-03.2|Quản lý mẫu nhãn và hợp nhất ticket|ADMIN có quyền support|Duy trì mẫu trả lời nhãn và liên kết ticket hợp nhất|SupportToolsController.templates,create,update,labels,merge,feedback
SUP-03.3|Lưu bộ lọc xử lý ticket|ADMIN có quyền support|Duy trì SupportSavedView thuộc tài khoản|SupportWorkflowController.views,createView,updateView,deleteView
SUP-03.4|Liên kết và xem dòng thời gian hồ sơ hỗ trợ|ADMIN có quyền hồ sơ hỗ trợ|Gắn tài nguyên được phép và xem sự kiện theo quyền|SupportCaseController.timeline,link
SUP-04|Quản lý trung tâm thông báo cá nhân|LANDLORD TENANT hoặc ADMIN theo endpoint|Đọc thông báo và thiết lập sở thích của chính tài khoản|NotificationCenterController.list,preferences,updatePreferences,markRead,markAllRead;SupportController.listNotifications,markNotification,markAllNotifications
SUP-05.1|Giám sát và xử lý sự cố vận hành|ADMIN có quyền operations|Đọc sự cố và thực hiện action đúng trạng thái|IncidentWorkflowController.list,assignees,detail,action;AdminConsoleController.operationsHealth,acknowledgeIncident
SUP-05.2|Theo dõi hàng đợi giao nhận|ADMIN có quyền operations|Đọc metadata job và thử lại notification đủ điều kiện|OperationsQueueController.list;NotificationDeliveryController.queue,retry
SUP-06|Hỏi trợ lý AI và đọc nguồn hướng dẫn|LANDLORD|Nhận câu trả lời từ tri thức theo scope hoặc thiếu bằng chứng|ChatbotController.ask,source
STF-01|Mời nhân viên và cấp phạm vi khu trọ|LANDLORD|Tạo lời mời với tập quyền và propertyIds thuộc mình|StaffController.presets,list,createInvite
STF-02|Cập nhật quyền trạng thái và phạm vi nhân viên|LANDLORD|Đổi quyền preset khu được cấp và trạng thái nhân viên|StaffController.update
STF-03|Mô phỏng quyền nhân viên|LANDLORD|Kiểm tra quyền hiệu lực mà không đổi cấp quyền|StaffController.simulate
'''

TECH = {
    'AuthController.me': 'SP-SYS-01 Đọc và kiểm chứng danh tính để phục hồi phiên',
    'AuthController.refresh': 'SP-SYS-02 Luân chuyển refresh token hỗ trợ phiên',
    'AdminConsoleController.capabilities': 'SP-ADM-01 Cấp capability cho giao diện Admin',
    'P1OperationsController.options': 'SP-OPS-01 Nạp lựa chọn khu phòng cho biểu mẫu vận hành',
    'UploadsController.upload': 'SP-FILE-01 Tải tệp riêng hỗ trợ UC có đính kèm',
    'UploadsController.access': 'SP-FILE-02 Cấp URL truy cập tệp theo quyền',
    'HealthController.check': 'SP-HEALTH-01 Kiểm tra kết nối cơ sở dữ liệu',
    'HealthController.live': 'SP-HEALTH-02 Kiểm tra tiến trình đang sống',
    'HealthController.ready': 'SP-HEALTH-03 Kiểm tra readiness và migration',
    'LandlordOnlinePaymentsController.status': 'SP-PAY-01 Đọc trạng thái link thanh toán từ màn hình hóa đơn',
    'LandlordOnlinePaymentsController.events': 'SP-PAY-02 Đọc sự kiện thanh toán demo',
    'LandlordOnlinePaymentsController.reconcile': 'SP-PAY-03 Đối soát sự kiện demo không xử lý giao dịch ngân hàng thật',
}

NOTES = {
    'SYS-01': 'Tạo User và cấp phiên là hai đơn vị ghi khác nhau; lỗi cấp phiên sau khi tạo có thể để lại User.',
    'SYS-09': 'Bổ sung vì bản V3 chưa tách mục tiêu kích hoạt STAFF.',
    'DIS-04': 'Không có endpoint sửa filters của tìm kiếm đã lưu; chỉ tạo bật tắt xóa và đọc cảnh báo.',
    'DIS-11': 'Không gộp bàn giao vào tạo hợp đồng; bàn giao nằm ở TNT-12.2 và TNT-12.3.',
    'OPT-07.1': 'Cùng PATCH với sửa phòng nhưng mục tiêu đổi trạng thái được giữ riêng; không có endpoint status nghiệp vụ riêng.',
    'TNT-03': 'Decorator nhận STAFF nhưng PropertyScopeInterceptor chặn TenantInvitesController; không mô tả STAFF thực thi được.',
    'TNT-13': 'Chức năng cục bộ; không bịa endpoint xuất PDF hoặc chữ ký điện tử.',
    'BIL-08.2': 'Chức năng cục bộ Flutter; quyền xem dữ liệu nguồn vẫn phải do API thực thi.',
    'BIL-16': 'Controller reviewTariff là LANDLORD-only dù tồn tại tên permission billing.tariff_approve.',
    'BIL-18.3': 'Interceptor không cho STAFF dùng outboxEvents hoặc retryOutbox.',
    'BIL-21': 'UI sao chép CSV vào clipboard; không gọi đây là tải XLSX.',
    'OPS-02': 'STAFF được một số thao tác bảo trì nhưng bị chặn escalate ở interceptor.',
    'OPS-04': 'OperationsController không nằm trong allowlist của PropertyScopeInterceptor; STAFF bị từ chối.',
    'OPS-05': 'P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.',
    'OPS-06': 'P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.',
    'OPS-07': 'AnnouncementsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.',
    'OPS-08': 'NotificationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.',
    'OPS-09': 'AuditController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF.',
    'TEN-05': 'Chỉ bật ngoài production và DEMO_PAYMENTS_ENABLED=true; không có cổng thu thẻ tiền thật được xác nhận.',
    'ADM-07.1': 'AdminSecurityController dùng JWT trực tiếp cho bước thiết lập MFA; không gán capability giả cho endpoint này.',
    'ADM-15': 'Đối soát tham chiếu khoản thu đã có; không đồng nghĩa tự nhận tiền ngân hàng hoặc tự ghi Payment.',
    'ADM-18': 'Hai vai trò dùng endpoint khác nhau; không gán quyền xét duyệt cho chủ trọ.',
    'ADM-19': 'Endpoint trình hồ sơ khu hiện dành ADMIN; không ghi bước này do LANDLORD thực hiện.',
    'SUP-01': 'Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator.',
    'SUP-03.1': 'Tệp hỗ trợ có bước quét malware riêng; không áp đồng nhất quy tắc đó cho mọi upload.',
    'SUP-04': 'Chỉ phần endpoint cho LANDLORD TENANT ADMIN được coi truy cập được; STAFF bị chặn bởi interceptor.',
    'STF-01': 'STAFF chỉ được list và presets khi có staff.view; không được tạo invite qua interceptor.',
    'STF-02': 'Dù decorator có STAFF và staff.manage, interceptor không cho STAFF tự cập nhật quyền.',
}

CROSSWALK = {
    'UC-SYS-04': ['SP-SYS-01', 'SP-SYS-02'],
    'UC-DIS-06': ['UC-DIS-06.1','UC-DIS-06.2','UC-DIS-06.3'],
    'UC-DIS-11': ['UC-DIS-11','UC-TNT-12.2','UC-TNT-12.3'],
    'UC-DIS-13': ['UC-DIS-13.1','UC-DIS-13.2'],
    'UC-TNT-12.2': ['UC-TNT-12.2','UC-TNT-12.3'],
    'UC-BIL-12': ['UC-BIL-12.1','UC-BIL-12.2'],
    'UC-BIL-18': ['UC-BIL-18.1','UC-BIL-18.2','UC-BIL-18.3'],
    'UC-TEN-08': ['UC-TEN-08.1','UC-TEN-08.2'],
    'UC-TEN-09': ['UC-TEN-09.1','UC-TEN-09.2','UC-TEN-09.3'],
    'UC-ADM-07': ['UC-ADM-07.1','UC-ADM-07.2'],
    'UC-ADM-13': ['UC-ADM-13.1','UC-ADM-13.2','UC-ADM-13.3'],
    'UC-ADM-17': ['UC-ADM-17.1','UC-ADM-17.2'],
    'UC-SUP-02': ['UC-SUP-02.1','UC-SUP-02.2'],
    'UC-SUP-03': ['UC-SUP-03.1','UC-SUP-03.2','UC-SUP-03.3','UC-SUP-03.4'],
    'UC-SUP-05': ['UC-SUP-05.1','UC-SUP-05.2'],
}

def cases():
    result = []
    for line in DATA.strip().splitlines():
        code, title, actor, goal, bindings = line.split('|')
        expanded = []
        for part in bindings.split(';'):
            owner, names = part.split('.', 1)
            expanded.extend(owner + '.' + name for name in names.split(','))
        result.append(dict(id='UC-' + code, code=code, group=code.split('-')[0],
                           title=title, actor=actor, goal=goal, bindings=expanded,
                           notes=NOTES.get(code,'')))
    return result
