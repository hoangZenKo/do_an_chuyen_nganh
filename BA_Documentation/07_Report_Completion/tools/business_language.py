import re


TERMS = {}


def add_terms(source):
    for line in source.strip().splitlines():
        key, value = line.split('|', 1)
        TERMS[key] = value


add_terms('''
Actor.userId|tài khoản người thực hiện
DemoCardGateway.validateCard|kiểm tra thông tin thẻ thử nghiệm
Tenant.isActive|trạng thái hoạt động của hồ sơ người thuê
Tenant.userId|tài khoản gắn với hồ sơ người thuê
User.isActive|trạng thái hoạt động của tài khoản
invoice.paidAmount|số tiền đã thu của hóa đơn
receipt.availableAmount|số tiền khoản thu còn có thể sử dụng
proposal.lineVersion|phiên bản dòng sao kê khi lập đề xuất
automation.isEnabled|cấu hình lập hóa đơn đã được bật
service.manage|quyền xử lý nghiệp vụ
Service.manage|quyền xử lý hồ sơ
room/cost/landlord/area|phòng ở, chi phí, chủ trọ và khu vực
tenantUnallocatedCredit=null|không phân chia số tiền chưa phân bổ của người thuê cho một phòng
additionalActionChecksApply=true|vẫn cần kiểm tra điều kiện của từng hành động thực tế
recordDeposit=false|không ghi thu cọc thêm lần nữa
activeLeaseRequired=true|chỉ áp dụng cho hợp đồng đang hiệu lực
productionAccepted=false|chưa được xác nhận đủ điều kiện vận hành thực tế
enforcementUnchanged=true|không thay đổi quyết định xử lý nội dung
automaticSanctions=false|không tự áp dụng chế tài
platformRevenueAvailable=false|chưa cung cấp doanh thu bán gói
requiresLeaseAction=true|còn cần thực hiện thay đổi hợp đồng
scope=module-and-property|phạm vi đánh giá theo nhóm quyền và khu được giao
cardLast4=4242|bốn số cuối hiển thị là 4242 cho thẻ thử nghiệm
available=false|tin không còn khả dụng
idempotent=true|trả kết quả đã ghi nhận trước đó, không ghi lần hai
idempotent=false|ghi nhận lần thực hiện mới
retryable=false|không cho gửi lại từ chức năng này
queued=true|đã đưa yêu cầu vào danh sách chờ gửi
allowed=true|kết quả kiểm tra là được phép
allowed=false|kết quả kiểm tra là không được phép
checked=null|chưa có quyền cụ thể được chọn để kiểm tra
status=existing|kết quả là đã có hóa đơn
decision=PENDING|quyết định vẫn là chờ xử lý
data=null|chưa có kết quả quyết toán
expectedVersion|phiên bản thông tin đang được sử dụng
targetVersion|phiên bản của hồ sơ đích
previewFingerprint|dấu đối chiếu của bản xem trước
idempotencyKey|mã đối chiếu lần xác nhận
requestKey|mã đối chiếu yêu cầu
requestHash|nội dung yêu cầu đã được đối chiếu
lineVersion|phiên bản dòng sao kê
reviewVersion|phiên bản rà soát quyền
sessionVersion|mốc hiệu lực truy cập
resultLeaseId|mã hợp đồng kết quả
landlordId|mã chủ trọ
propertyIds|các khu được giao
propertyId|mã khu trọ
roomId|mã phòng
roomIds|danh sách mã phòng
tenantId|mã người thuê
tenantIds|danh sách người thuê
TenantIds|danh sách người thuê
tenantScope|phạm vi hồ sơ người thuê được giao
landlordScope|phạm vi quản lý của chủ trọ
propertyScope|phạm vi khu được giao
roomScope|phạm vi phòng được phép truy cập
leaseIds|danh sách mã hợp đồng
leaseId|mã hợp đồng
LeaseId|mã hợp đồng
userId|mã tài khoản
UserId|mã tài khoản
accountId|mã tài khoản
adminId|mã quản trị viên
AdminId|mã quản trị viên
listingId|mã tin đăng
viewingId|mã lịch xem
slotId|mã khung giờ
assetId|mã tài sản
inspectionId|mã lần kiểm tra phòng
feeId|mã khoản phí
occupantId|mã người ở cùng
requestId|mã yêu cầu
invoiceId|mã hóa đơn
receiptId|mã khoản thu
paymentId|mã lần thanh toán
allocationId|mã lần phân bổ
proofId|mã chứng từ chuyển khoản
tariffId|mã đề xuất biểu phí
eventId|mã thông báo
turnoverId|mã hồ sơ chuẩn bị lại phòng
taskId|mã công việc
announcementId|mã thông báo chung
sourceId|mã nguồn hướng dẫn
runId|mã lần tạo báo cáo
resourceId|mã đối tượng nghiệp vụ
actorId|mã người thực hiện
incidentId|mã sự cố
deliveryId|mã lần gửi
teamId|mã nhóm
reviewId|mã đánh giá
ReviewId|mã đánh giá
reportId|mã báo cáo vi phạm
appealId|mã kháng nghị
assigneeId|mã người được phân công
templateId|mã mẫu trả lời
targetId|mã hồ sơ đích
savedViewId|mã bộ lọc đã lưu
verificationId|mã hồ sơ xác minh
planId|mã gói dịch vụ
subscriptionId|mã lần cấp gói
proposalId|mã đề xuất
campusId|mã cơ sở trường
CampusId|mã cơ sở trường
fullName|họ tên
monthlyRent|tiền thuê tháng
basePrice|giá cơ sở của phòng
billingMonth|kỳ thanh toán
dueDate|hạn thanh toán
moveOutDate|ngày trả phòng
startDate|ngày bắt đầu hợp đồng
endDate|ngày kết thúc hợp đồng
requestedStart|ngày bắt đầu đề nghị
requestedEnd|ngày kết thúc đề nghị
requestedRoomId|phòng đề nghị chuyển đến
expectedUpdatedAt|mốc cập nhật gần nhất dùng để đối chiếu
createdAt|thời điểm tạo
updatedAt|thời điểm cập nhật
reviewedAt|thời điểm xét duyệt
checkedAt|mốc bắt đầu theo dõi
sentAt|thời điểm gửi
sendAt|thời điểm dự kiến gửi
completedAt|thời điểm hoàn thành
lastRunMonth|kỳ chạy gần nhất
lastRunAt|thời điểm chạy gần nhất
nextRunAt|thời điểm chạy kế tiếp
scheduledFor|thời điểm dự kiến thực hiện
snoozedUntil|thời điểm hết tạm hoãn
lastActiveAt|thời điểm hoạt động gần nhất
accessReviewedAt|thời điểm rà soát quyền gần nhất
nextAccessReviewAt|hạn rà soát quyền tiếp theo
releasedAt|thời điểm giải phóng phân bổ
landlordVerifiedAt|thời điểm xác minh chủ trọ
inspectedAt|thời điểm kiểm tra phòng
escalatedAt|thời điểm chuyển cấp xử lý
expiresAt|thời điểm hết hạn
availableAt|thời điểm được gửi lại
expiresInMinutes|số phút hiệu lực
currentReading|chỉ số hiện tại
previousReading|chỉ số trước
unitPrice|đơn giá
utilityType|loại điện hoặc nước
meterReadings|các chỉ số điện nước
meterReading|chỉ số điện nước
usage|mức tiêu thụ
paidAmount|số tiền đã thu
totalAmount|tổng tiền hóa đơn
otherAmount|khoản thu khác
availableAmount|số tiền chưa phân bổ còn có thể sử dụng
refundedAmount|số tiền đã hoàn
refundAmount|số tiền phải hoàn
depositApplied|tiền cọc dùng bù trừ
totalCharges|tổng khoản quyết toán
depositBalance|số dư cọc
balanceCoc|số dư cọc
tenantUnallocatedCredit|tiền của người thuê chưa phân bổ
unallocated|chưa phân bổ
serviceKey|mã loại phí
effectiveFrom|kỳ bắt đầu áp dụng
electricityKwh|mức điện dự kiến
waterM3|mức nước dự kiến
electricityPrice|đơn giá điện
waterPrice|đơn giá nước
serviceFee|phí dịch vụ
parkingFee|phí gửi xe
freshOnly|lọc tin mới xác nhận còn phòng
maxBudget|ngân sách tối đa
maxProperties|hạn mức khu trọ
maxRooms|hạn mức phòng
maxOpen|số hồ sơ đang xử lý tối đa
isActive|trạng thái hoạt động
isDemo|dấu dữ liệu thử nghiệm
isEnabled|trạng thái bật
isInternal|phạm vi trao đổi nội bộ
isRead|trạng thái đã đọc
pageSize|số mục trên trang
beforeDays|các mốc trước hạn
onDueDate|nhắc vào ngày đến hạn
overdueDays|các mốc quá hạn
businessDay|ngày nghiệp vụ
eventKey|mã thông báo chống lặp
lastError|lỗi gửi gần nhất
pendingAmount|số tiền chứng từ đang chờ duyệt
blockingReasons|các lý do chưa thể duyệt
canApprove|kết quả kiểm tra đủ điều kiện duyệt
reviewReason|lý do xét duyệt
reviewNote|ghi chú xét duyệt
decisionNote|ghi chú quyết định
downloadLink|liên kết tải kết quả
downloadUrl|liên kết tải
checkoutUrl|liên kết trang thanh toán thử nghiệm
mfaCode|mã xác thực nhiều yếu tố
cardNumber|số thẻ thử nghiệm
cardLast4|bốn số cuối thẻ thử nghiệm
cardBrand|nhãn thẻ thử nghiệm
expiry|tháng năm hết hạn
cvc|mã bảo mật thẻ thử nghiệm
channel|kênh nhận
channels|các kênh nhận
responseMinutes|thời hạn phản hồi tính bằng phút
resolutionMinutes|thời hạn giải quyết tính bằng phút
escalationMinutes|mốc chuyển cấp tính bằng phút
newTicketsOnly|chỉ áp dụng hồ sơ tạo mới
enforcementUnchanged|quyết định xử lý nội dung giữ nguyên
automaticSanctions|tự áp dụng chế tài
roomInspected|trạng thái kiểm tra phòng
landlordVerified|trạng thái xác minh chủ trọ
landlordVerification|hồ sơ xác minh chủ trọ
mergedIntoId|mã hồ sơ được hợp nhất vào
requesterId|người yêu cầu
feedbackAt|thời điểm đánh giá
contentHash|dấu đối chiếu nội dung
accountKey|mã nhận diện tài khoản nhận tiền
occurredAt|thời điểm phát sinh
invoicePaidSnapshot|số đã thu đang thể hiện trên hóa đơn
platformRevenueAvailable|khả năng cung cấp doanh thu bán gói
productionAccepted|kết quả xác nhận vận hành thực tế
conditionActive|nguyên nhân sự cố còn tồn tại
additionalActionChecksApply|còn cần kiểm tra điều kiện hành động
billingMode|cách ghi nhận gói
planVersion|phiên bản điều khoản gói
jobStatus|trạng thái gửi
resourceType|loại đối tượng nghiệp vụ
readOnly|chỉ đọc
minPrice|giá thấp nhất
maxPrice|giá cao nhất
asOf|ngày chốt số liệu
groupBy|cách nhóm kết quả
feedbackList|danh sách phản hồi thử nghiệm
monthlyExport|báo cáo tháng
billingAnalytics|báo cáo hóa đơn
auditMetadata|nội dung nhật ký liên quan
AccountAccess|hồ sơ cấp quyền truy cập qua lời mời
AuthSession|phiên truy cập
RefreshToken|thông tin duy trì phiên
User|tài khoản
Tenant|hồ sơ người thuê
Property|khu trọ
Room|phòng
Lease|hợp đồng
Invoice|hóa đơn
Payment|giao dịch thanh toán
Expense|khoản chi
Ledger|sổ giao dịch
Receipt|khoản thu
Allocation|khoản phân bổ
Settlement|quyết toán
Request|yêu cầu
RoomListing|tin cho thuê
RoomViewing|lịch xem phòng
RoomAsset|tài sản phòng
RoomInspection|lần kiểm tra phòng
TenantOccupant|người ở cùng hợp đồng
DepositTransaction|giao dịch cọc
TenantLifecycleRequest|yêu cầu thay đổi việc thuê
TenantLifecycleExecution|kết quả thực hiện thay đổi việc thuê
MeterReading|chỉ số điện nước
BillingReceipt|khoản thu của người thuê
BillingRefund|giao dịch hoàn tiền
BillingTariffVersion|phiên bản biểu phí
BillingPeriodLock|khóa kỳ thanh toán
BillingAutomation|cấu hình lập hóa đơn định kỳ
InvoiceAdjustment|chứng từ điều chỉnh hóa đơn
PaymentAllocation|phân bổ khoản thu
PaymentProof|chứng từ chuyển khoản
NotificationDelivery|lần giao thông báo
NotificationRead|trạng thái đã đọc thông báo
Notification|thông báo
TenantNotificationPreference|lựa chọn nhận nhắc nợ
UserNotificationPreference|lựa chọn nhận thông báo cá nhân
MaintenanceTicket|yêu cầu bảo trì
MaintenanceComment|trao đổi bảo trì
RecurringOperation|công việc định kỳ
Announcement|thông báo chung
SavedSearch|bộ lọc đã lưu
ListingReport|báo cáo vi phạm tin đăng
RoomReview|đánh giá phòng
PilotFeedback|phản hồi thử nghiệm
SchoolCampus|cơ sở trường
ModerationPolicy|chính sách kiểm duyệt
ModerationQualityReview|đánh giá chất lượng kiểm duyệt
SupportAgentSkill|năng lực người xử lý hỗ trợ
SupportMessage|trao đổi hỗ trợ
SupportAttachment|tệp đính kèm hỗ trợ
SupportTemplate|mẫu trả lời hỗ trợ
SupportSavedView|bộ lọc hỗ trợ đã lưu
LandlordVerification|hồ sơ xác minh chủ trọ
ServicePlan|gói dịch vụ
SubscriptionEvent|lịch sử cấp gói
AdminProfile|hồ sơ quyền quản trị
AdminReportRun|lần tạo báo cáo quản trị
DeliveryJob|yêu cầu giao liên kết
TenantInvitesController|chức năng mời người thuê
StaffController|chức năng nhân sự
NotificationsController|chức năng gửi thông báo riêng
BillingController|chức năng hóa đơn
AuditController|chức năng nhật ký
OperationsController|chức năng điều hành công việc
P1OperationsController|chức năng công việc định kỳ
HousingController|chức năng tiếp nhận thuê
SupportController|chức năng hỗ trợ
CreateLeaseDto|quy định nhập hợp đồng
UpdateLeaseDto|quy định cập nhật hợp đồng
UpdateRoomDto|quy định cập nhật phòng
CreateTenantAccountDto|quy định tạo tài khoản người thuê
BillingAutomationDto|quy định cấu hình lập hóa đơn
PilotFeedbackDto|quy định nhập phản hồi thử nghiệm
BillingCommands|cơ chế đối chiếu yêu cầu đã thực hiện
renewWithinTransaction|thực hiện gia hạn hợp đồng
reviewTariff|xét duyệt biểu phí
updateProperty|cập nhật khu trọ
updateServiceFee|cập nhật phí phòng
recordDeposit|ghi nhận tiền cọc
tenantHasHistory|kiểm tra lịch sử người thuê
shareLeasePdf|chia sẻ bản hợp đồng
getSource|xem nguồn hướng dẫn
findCandidate|tìm giao dịch đối chiếu
findOwned|tìm đối tượng thuộc quyền quản lý
markAllRead|đánh dấu tất cả đã đọc
roomTurnover|hồ sơ chuẩn bị lại phòng
leaseWhere|phạm vi hợp đồng được xem
accountView|thông tin tài khoản đã che dữ liệu riêng tư
receiptView|thông tin khoản thu sau cập nhật
visibleWhere|điều kiện hiển thị công khai
ACTIVE|đang hiệu lực
INACTIVE|ngừng hoạt động
VACANT|trống
OCCUPIED|đang có người thuê
MAINTENANCE|đang bảo trì
ARCHIVED|đã lưu trữ
DRAFT|bản nháp
PUBLISHED|đã công khai
HIDDEN|đã ẩn
PENDING|chờ xử lý
PROPOSED|đã đề xuất
APPROVED|đã chấp thuận
REJECTED|đã từ chối
CANCELLED|đã hủy
CONFIRMED|đã xác nhận
REQUESTED|đã đề nghị
COMPLETED|đã hoàn thành
LEASED|đã chuyển thành hợp đồng
ENDED|đã kết thúc
UNPAID|chưa thanh toán
PARTIAL|thanh toán một phần
PAID|đã thanh toán
COLLECTED|đã thu
REFUNDED|đã hoàn
DEDUCTED|đã khấu trừ
RENEWAL|gia hạn
TRANSFER_ROOM|chuyển phòng
CHECKOUT|trả phòng
INSPECTION|kiểm tra
CLEANING|vệ sinh
REPAIR|sửa chữa
READY|sẵn sàng
OPEN|mới tiếp nhận
IN_PROGRESS|đang xử lý
WAITING_FOR_USER|chờ người yêu cầu phản hồi
RESOLVED|đã giải quyết
CLOSED|đã đóng
SCHEDULED|đã lên lịch
DONE|đã xong
SENT|đã gửi theo kênh đang sử dụng
FAILED|gửi thất bại
DEAD|đã hết lượt gửi tự động
STORED|đã lưu chờ xử lý
EXPIRED|đã hết hạn
INVALIDATED|đã mất hiệu lực
NEEDS_INFO|cần bổ sung thông tin
NEEDS_REVIEW|cần kiểm tra thêm
DISMISSED|không chấp nhận phản ánh
REOPENED|đã mở lại
RETIRED|đã ngừng áp dụng
UPHELD|giữ nguyên quyết định
SUPERSEDED|đã được thay thế
MATCHED|đã đối soát khớp
UNMATCHED|chưa ghép đối soát
ACKNOWLEDGE|ghi nhận đã tiếp nhận
ASSIGN|phân công xử lý
SNOOZE|tạm hoãn
REOPEN|mở lại
RESOLVE|kết thúc xử lý
PUBLISH|công khai
HIDE|ẩn nội dung
REJECT|từ chối
MATCH_PAYMENT|ghép giao dịch thanh toán
MATCH_RECEIPT|ghép khoản thu
MARK_REVIEWED|đánh dấu cần kiểm tra
UNMATCH|bỏ ghép
PAYMENT|thanh toán
LINK|liên kết thanh toán
WEBHOOK|thông tin xác nhận thanh toán
BANK_TRANSFER|chuyển khoản ngân hàng
MANUAL_BANK_TRANSFER|chuyển khoản có đối chiếu chứng từ
REVERSAL|bút toán đảo
ADJUSTMENT|điều chỉnh
SURCHARGE|thu thêm
TENANT_WAIVER|miễn giảm cho người thuê
CREDIT|giảm phải thu
DEBIT|tăng phải thu
DISCOUNT|giảm giá
LATE_FEE|phí chậm trả
SERVICE|phí dịch vụ
PRIVATE|nội bộ
GLOBAL|toàn hệ thống
PROPERTY|theo khu trọ
ROOM|phòng
LEASE|hợp đồng
INVOICE|hóa đơn
APP|thông báo trong ứng dụng
EMAIL|thư điện tử
ZALO|Zalo
SMS|tin nhắn điện thoại
DEMO_CARD|thẻ thử nghiệm
UNAVAILABLE|chưa khả dụng
PILOT_AREA|khu vực thử nghiệm
ADMINISTRATIVE_ENTITLEMENTS|cấp quyền sử dụng theo quyết định quản trị
SUBSCRIPTION_BILLING_NOT_IMPLEMENTED|chưa cung cấp nghiệp vụ thu tiền gói dịch vụ
MANUAL_ACCEPTANCE_REQUIRED|còn cần nghiệm thu vận hành
STAFF_INACTIVE|nhân viên đã ngừng hoạt động
MODULE_PERMISSION_MISSING|thiếu quyền nghiệp vụ
PROPERTY_NOT_ASSIGNED|khu chưa được giao
PROPERTY_ARCHIVED|khu đã lưu trữ
LANDLORD_ONLY_ACTION|hành động chỉ dành cho chủ trọ
PROPERTY_HAS_RELATED_HISTORY|khu còn lịch sử liên quan
ROOM_HAS_HISTORY|phòng còn lịch sử liên quan
TARIFF_VERSION_CHANGED|phiên bản biểu phí đã thay đổi
TARIFF_DATE_CONFLICT|kỳ hiệu lực biểu phí bị trùng
BILLING_PERIOD_LOCKED|kỳ thanh toán đã khóa
PAYMENT_LEDGER_INCONSISTENT|sổ thanh toán không khớp
PAYMENT_ALLOCATION_MANAGED|thanh toán đang thuộc phân bổ khoản thu
REFUND_EXCEEDS_AVAILABLE|số tiền hoàn vượt số còn khả dụng
AI_DISABLED|trợ lý chưa được bật
AI_INVALID_INPUT|nội dung hỏi không hợp lệ
AI_BUSY|trợ lý đang bận
AI_TIMEOUT|quá thời gian trả lời
P2002|thông tin trùng đã có
P2003|còn dữ liệu lịch sử phụ thuộc
FEATURE_KEYS|danh mục tính năng được phép cấu hình
LANDLORD|Chủ trọ
STAFF|Nhân viên vận hành
TENANT|Người tìm phòng hoặc người thuê
ADMIN|Quản trị viên nền tảng
super_admin|quản trị viên toàn quyền
moderator|nhân sự kiểm duyệt
analyst|nhân sự phân tích
support|nhân sự hỗ trợ
Actor|Tác nhân
Admin|Quản trị viên
Account|tài khoản
Agent|người xử lý hỗ trợ
Assignee|người được giao
Audience|nhóm người nhận
Audit|nhật ký
Automation|lập hóa đơn định kỳ
Batch|tập yêu cầu
Bulk|lập hóa đơn hàng loạt
Checklist|danh sách việc cần làm
Controller|chức năng tương ứng
Cost|chi phí
Dashboard|tổng quan
Database|hồ sơ liên quan
Delivery|giao nhận
Enqueue|đưa vào danh sách chờ gửi
Entitlement|quyền sử dụng gói
Event|thông báo nghiệp vụ
Evidence|bằng chứng
Execution|lần thực hiện
Favorite|tin yêu thích
Feature|tính năng
Feed|danh sách công việc
Fingerprint|dấu đối chiếu bản xem trước
Flag|thiết lập bật tắt
Input|dữ liệu nhập
Key|mã đối chiếu
Line|dòng sao kê
Lines|các khoản tính tiền
Link|liên kết
Membership|thành viên nhóm
Notification|thông báo
Outbox|danh sách thông báo chờ gửi
Pilot|thử nghiệm
Plan|gói dịch vụ
Platform|nền tảng
Policy|chính sách
Preference|lựa chọn nhận thông báo
Preflight|kiểm tra trước khi lập
Preset|mẫu quyền
Preview|xem trước
Production|môi trường vận hành chính thức
Projection|thông tin được phép xem
Proof|chứng từ chuyển khoản
Quota|hạn mức
Queued|đã chờ gửi
Recipient|người nhận
Release|đánh giá sẵn sàng vận hành
Report|báo cáo
Resource|đối tượng nghiệp vụ
Retry|gửi lại
Reveal|xem thông tin đã che
Review|đánh giá
Riverpod|Hệ thống
Role|vai trò
Run|lần tạo báo cáo
Scanner|dịch vụ kiểm tra an toàn tệp
Scope|phạm vi được phép
Session|phiên truy cập
Skills|năng lực
Slot|khung giờ
State|trạng thái
Statement|sao kê
Target|đối tượng đối chiếu
Task|công việc
Team|nhóm quản trị
Ticket|hồ sơ hỗ trợ
Token|mã truy cập
Unique|quy tắc không trùng
Validation|kiểm tra thông tin
Workflow|quy trình xử lý
Worker|Hệ thống
API|chức năng
DTO|quy định nhập liệu
JWT|phiên đăng nhập hợp lệ
RBAC|quyền theo vai trò
MFA|xác thực nhiều yếu tố
PII|thông tin cá nhân
SLA|thời hạn hỗ trợ
UI|giao diện
DB|hồ sơ nghiệp vụ
CRUD|quản lý danh mục
QA|đánh giá chất lượng
HTML|trang thanh toán
JSON|kết quả trên ứng dụng
HMAC|mã bảo vệ liên kết
UUID|mã đối chiếu duy nhất
URL|địa chỉ truy cập
MIME|định dạng tệp
BOM|dấu nhận diện mã hóa tệp
CSV|bảng dữ liệu
UTC|giờ quốc tế
''')

add_terms('''
scope|phạm vi được phép
ownership|quyền quản lý đối tượng
permission|quyền nghiệp vụ
permissions|các quyền nghiệp vụ
capability|quyền quản trị
capabilities|các quyền quản trị
preset|mẫu quyền
presets|danh mục mẫu quyền
role|vai trò
roles|các vai trò
user|tài khoản
profile|hồ sơ
tenant|người thuê
lease|hợp đồng
invoice|hóa đơn
payment|giao dịch thanh toán
receipt|khoản thu
allocation|phân bổ khoản thu
allocations|danh sách phân bổ
refund|hoàn tiền
settlement|quyết toán
ledger|sổ giao dịch
property|khu trọ
properties|các khu trọ
room|phòng
listing|tin đăng
favorite|tin yêu thích
viewing|lịch xem
slot|khung giờ
occupant|người ở cùng
campus|cơ sở trường
preview|xem trước
preflight|kiểm tra trước khi lập
automation|cấu hình lập hóa đơn định kỳ
reminder|nhắc nợ
tariff|biểu phí
turnover|chuẩn bị lại phòng
checklist|danh sách kiểm tra
notification|thông báo
announcement|thông báo chung
delivery|giao nhận
outbox|danh sách thông báo chờ gửi
worker|hệ thống
service|quy tắc nghiệp vụ
endpoint|chức năng
handler|hành động
controller|nhóm chức năng
interceptor|kiểm tra phạm vi được giao
guard|kiểm tra quyền truy cập
allowlist|danh mục được phép
whitelist|danh mục được phép
ownership|quyền quản lý đối tượng
transaction|lần ghi nhận đồng thời các thay đổi
rollback|không lưu các thay đổi của lần xác nhận
upsert|lưu mới hoặc cập nhật
deleteMany|xóa liên kết
createMany|tạo các thông báo
delete|xóa
update|cập nhật
serialize|cung cấp thông tin theo phạm vi được xem
serializer|thông tin được phép xem
hash|nội dung đối chiếu
tokenHash|mã bảo vệ phiên
token|mã truy cập
refresh|thông tin duy trì phiên
session|phiên truy cập
access|truy cập
version|phiên bản thông tin
timestamp|mốc cập nhật
snapshot|thông tin được ghi nhận tại thời điểm xử lý
line item|khoản mục hóa đơn
line items|các khoản mục hóa đơn
line|dòng
lines|các khoản bổ sung
tiers|các bậc tính phí
kind|loại nghiệp vụ
type|loại
status|trạng thái
state|trạng thái
input|dữ liệu nhập
payload|thông tin gửi
output|kết quả
query|điều kiện tra cứu
route|chức năng
path|chức năng
resource|đối tượng nghiệp vụ
object|đối tượng
record|thông tin đã lưu
records|các thông tin đã lưu
key|mã
id|mã
ids|các mã
name|tên
code|mã
phone|số điện thoại
email|thư điện tử
password|mật khẩu
reason|lý do
reference|mã tham chiếu
note|ghi chú
body|nội dung
subject|tiêu đề
title|tiêu đề
description|mô tả
label|nhãn
labels|các nhãn
category|nhóm yêu cầu
priority|mức ưu tiên
search|từ khóa
sort|cách sắp xếp
page|trang
limit|số mục trên trang
from|từ ngày
to|đến ngày
format|định dạng
amount|số tiền
price|giá
unit|đơn vị tính
balance|số dư
enabled|bật theo dõi
available|tình trạng khả dụng
inherited|được kế thừa từ chính sách chung
attempts|số lần đã gửi
completed|đã hoàn thành
summary|tổng hợp
data|kết quả
meta|thông tin trang kết quả
counts|số lượng theo trạng thái
unread|chưa đọc
match|tin khớp bộ lọc
matches|các tin khớp bộ lọc
feedback|phản hồi
pilot|thử nghiệm
review|đánh giá
reply|phản hồi
replyBody|nội dung trả lời
replyStatus|trạng thái trả lời
proof|chứng từ chuyển khoản
request|yêu cầu
decision|quyết định
action|hành động
actions|các hành động
maker|người lập đề xuất
checker|người xét duyệt
reviewer|người xét duyệt
assignee|người được phân công
requester|người yêu cầu
owner|người phụ trách
member|thành viên
membership|thành viên nhóm
team|nhóm
ticket|hồ sơ hỗ trợ
tickets|các hồ sơ hỗ trợ
template|mẫu nội dung
internal|nội bộ
attachment|tệp đính kèm
attachments|các tệp đính kèm
message|trao đổi
messages|các trao đổi
skill|năng lực
skills|năng lực
policy|chính sách
audit|nhật ký
auditLog|nhật ký
adminAudit|nhật ký quản trị
report|báo cáo
incident|sự cố
incidents|các sự cố
flag|thiết lập bật tắt
flags|các thiết lập bật tắt
rollout|phạm vi áp dụng thử
entitlement|quyền sử dụng gói
subscription|lần cấp gói
override|giá riêng
quota|hạn mức
proposed|đề xuất
proposal|đề xuất
proposals|các đề xuất
governance|kiểm tra quản trị
finance|tài chính
reconciliation|đối soát
statement|sao kê
mismatch|chênh lệch
mismatches|các chênh lệch
projection|thông tin được phép xem
cache|thông tin tạm
state|danh sách đang chọn
clear state|xóa danh sách đang chọn
toggle|thao tác chọn hoặc bỏ chọn
true|có
false|không
null|chưa có
min|giá trị nhỏ hơn
applied|số cọc đã bù trừ
balanceCoc|số dư cọc
capacity|sức chứa
archived|đã lưu trữ
active|đang hoạt động
activeLease|hợp đồng đang hiệu lực
soft delete|ngừng sử dụng nhưng giữ lịch sử
hard delete|xóa khỏi danh mục
webhook|thông tin xác nhận từ bên ngoài
provider|đơn vị cung cấp dịch vụ
runtime|vận hành thực tế
acceptance|nghiệm thu
production|môi trường vận hành chính thức
dev|môi trường thử nghiệm
demo|mô phỏng
mock|mô phỏng
frontend|giao diện
backend|hệ thống
local|trong phiên sử dụng
client|ứng dụng
database|hồ sơ nghiệp vụ
endpoint|chức năng
not found|không tìm thấy trong phạm vi được phép
conflict|xung đột thông tin hoặc trạng thái
validation|kiểm tra dữ liệu
step-up|xác nhận bảo mật bổ sung
reset|đặt lại
revoke|thu hồi
trim|loại khoảng trắng thừa ở đầu và cuối
lowercase|chuyển về chữ thường
hash mật khẩu|bảo vệ mật khẩu
sort|sắp xếp
filtered|theo bộ lọc
dead letters|các thông báo đã hết lượt gửi
response|kết quả phản hồi
queued|đã được đưa vào danh sách chờ gửi
retry|gửi lại
scope|phạm vi được phép
idempotency|không ghi nhận lặp cùng yêu cầu
idempotent|kết quả của lần thực hiện trước
lock|đối chiếu thông tin mới nhất
lockForUpdate|đối chiếu thông tin trước khi lưu
expiry|hạn sử dụng
link|liên kết
form|biểu mẫu
form-data|biểu mẫu tệp
multipart|biểu mẫu đính kèm
bank|ngân hàng
evidence|bằng chứng
history|lịch sử
read|xem
write|ghi nhận
manage|quản lý
view|xem
list|danh sách
retryable|được phép gửi lại
origin|nguồn trang gửi yêu cầu
Origin|nguồn trang gửi yêu cầu
Sec-Fetch-Site|nguồn trang gửi yêu cầu
Sec|nguồn trang gửi yêu cầu
Fetch|truy cập
Site|trang
canSubmit|đủ điều kiện xác nhận
canCreateLink|đủ điều kiện tạo liên kết
tokenHash|mã bảo vệ phiên
checkout|thanh toán thử nghiệm
duplicate|đã ghi nhận trước đó
''')

PHRASES = {
    'depositApplied=min(balanceCoc,totalCharges); refund=balanceCoc−applied.': 'Tiền cọc bù trừ không vượt số dư cọc và tổng khoản quyết toán; phần cọc còn lại là khoản phải hoàn.',
    'RepeatableRead': 'đối chiếu số liệu nhất quán',
    'Serializable': 'kiểm soát thay đổi đồng thời',
    'theo DTO': 'theo quy định nhập liệu',
    'đúng DTO': 'đúng quy định nhập liệu',
    'DTO bulk': 'quy định lập hàng loạt',
    'khóa ngoại': 'lịch sử liên quan',
    'khóa theo User': 'kiểm tra lại tài khoản',
    'khóa theo key': 'đối chiếu cấu hình hiện hành',
    'khóa Room/Lease': 'đối chiếu phòng và hợp đồng',
    'trong transaction': 'trong cùng lần ghi nhận',
    'Trong transaction': 'Trong cùng lần ghi nhận',
    'transaction của batch theo service': 'toàn bộ thay đổi thuộc lần lập hàng loạt',
    'sửa DB': 'sửa dữ liệu nghiệp vụ',
    'lease ACTIVE': 'hợp đồng đang hiệu lực',
    'lease ENDED': 'hợp đồng đã kết thúc',
    'Room.basePrice': 'giá cơ sở của phòng',
    'RoomListing.monthlyRent': 'giá thuê trên tin đăng',
    'refresh/session': 'phiên truy cập và thông tin duy trì phiên',
    'guard/interceptor': 'quyền và phạm vi được giao',
    'handler/interceptor': 'hành động và phạm vi được giao',
    'guard/JWT': 'hiệu lực truy cập',
    'capability/RBAC': 'quyền theo vai trò',
    'phía server': 'tại thời điểm xác nhận',
    'scope +': 'phạm vi được giao và',
    'source': 'kết quả đối chiếu hiện trạng',
    'endpoint': 'chức năng',
    'explore-preview': 'minh họa thử nghiệm tìm phòng',
    'createLandlord': 'tạo trực tiếp chủ trọ',
    'createInvite': 'tạo lời mời',
    'feedbackList': 'danh sách phản hồi',
    'emailAlreadyRegistered': 'thư điện tử đã được đăng ký',
    'MERGE': 'hợp nhất',
    'cùng requestKey/hash': 'cùng mã đối chiếu và nội dung đã xác nhận',
    'input của Actor': 'thông tin người thực hiện cung cấp',
}


def business_text(value):
    text = str(value or '')
    text = re.sub(r'\[[A-Z][A-Z0-9, -]*\]', '', text)
    text = re.sub(r'`([^`]+)`', r'\1', text)
    for source, replacement in sorted(PHRASES.items(), key=lambda pair: -len(pair[0])):
        text = re.sub(r'(?<!\w)' + re.escape(source) + r'(?!\w)', lambda match: replacement, text)
    pattern = r'(?<!\w)(' + '|'.join(re.escape(word) for word in sorted(TERMS, key=len, reverse=True)) + r')(?!\w)'
    text = re.sub(pattern, lambda match: TERMS[match.group(0)], text)
    text = re.sub(r'\b(?:HTTP\s*)?(?:400|401|403|404|409|429|503)(?:/(?:400|401|403|404|409|429|503))*\b', 'thông báo từ chối', text)
    text = text.replace('Tác nhân Chủ trọ', 'Chủ trọ').replace('Tác nhân Quản trị viên', 'Quản trị viên').replace('Tác nhân Người tìm phòng hoặc người thuê', 'Người thuê').replace('Tác nhân vận hành', 'Người vận hành').replace('Tác nhân chủ trọ', 'Chủ trọ')
    text = text.replace('Hệ thống khóa', 'Hệ thống kiểm tra lại').replace('hệ thống khóa', 'hệ thống kiểm tra lại')
    text = text.replace('trả thông báo từ chối', 'thông báo từ chối').replace('trả xung đột thông tin hoặc trạng thái', 'thông báo thông tin hoặc trạng thái đã thay đổi')
    text = text.replace('hệ thống cung cấp thông tin theo phạm vi được xem và trả kết quả', 'hệ thống trả thông tin được phép xem')
    text = re.sub(r'\s*;\s*', '; ', text)
    text = re.sub(r' +', ' ', text).strip()
    text = text.replace('..', '.').replace(',.', '.').replace(' ;', ';')
    return text


TITLE_OVERRIDES = {
    'UC-ADM-10': 'Tìm kiếm hồ sơ nghiệp vụ',
    'UC-SUP-05.2': 'Theo dõi và gửi lại thông báo cần chuyển',
    'UC-ADM-07.1': 'Thiết lập xác thực nhiều yếu tố cho quản trị viên',
    'UC-SYS-05.1': 'Đăng xuất khỏi phiên đang sử dụng',
    'UC-SYS-05.2': 'Xem và thu hồi phiên truy cập của mình',
    'UC-BIL-18.3': 'Theo dõi và gửi lại thông báo hóa đơn',
    'UC-SUP-02.2': 'Thiết lập và theo dõi thời hạn hỗ trợ',
    'UC-SUP-04': 'Quản lý thông báo cá nhân',
    'UC-SUP-06': 'Hỏi trợ lý và tra cứu hướng dẫn sử dụng',
    'UC-ADM-01': 'Xem tổng quan hoạt động nền tảng',
    'UC-ADM-14': 'Tra cứu nhật ký quản trị',
    'UC-ADM-16': 'Lập lịch và tải báo cáo quản trị',
    'UC-ADM-17.2': 'Quản lý nhóm quản trị viên',
    'UC-ADM-26': 'Kiểm tra mô phỏng quyền quản trị',
    'UC-TEN-09.2': 'Trao đổi qua kênh Zalo mô phỏng',
}


def business_title(record):
    return TITLE_OVERRIDES.get(record['id'], business_text(record['title']))


add_terms('''
acceptedAt|thời điểm chấp nhận
activatedBy|người đưa chính sách vào áp dụng
activationPath|đường dẫn kích hoạt
activeKey|dấu xác định yêu cầu đang chờ
activeLeaseRequired|điều kiện phải có hợp đồng hiệu lực
actualCost|chi phí thực tế
autoAssign|tự phân công
availabilityConfirmedAt|thời điểm xác nhận còn phòng
basisPoints|tỷ lệ phần trăm theo đơn vị một phần vạn
createExpense|ghi nhận khoản chi
csvCell|nội dung ô trong tệp bảng dữ liệu
decisionId|mã quyết định
dueAt|thời hạn hoàn thành
endsAt|thời điểm kết thúc
expenseDate|ngày chi
expenseId|mã khoản chi
externalId|mã tham chiếu bên ngoài
hourUtc|giờ chạy theo giờ quốc tế
importKey|mã đối chiếu lần nhập
inviteCode|mã lời mời
isArchived|trạng thái lưu trữ
missingUtilities|các chỉ số điện nước còn thiếu
needsAvailabilityConfirmation|cần xác nhận còn phòng
nextReviewAt|hạn rà soát tiếp theo
notificationId|mã thông báo
ownerId|mã người phụ trách
paidAt|thời điểm thanh toán
pendingCount|số mục đang chờ
privateView|quyền xem trao đổi nội bộ
propertyApprovalReview|lịch sử xét duyệt khu
publishedAt|thời điểm công khai
qualityReview|đánh giá chất lượng
reporterId|mã người phản ánh
reversalPayment|bút toán đảo của thanh toán
scheduleId|mã lịch báo cáo
scheduledAt|thời điểm đã lên lịch
setState|cập nhật thông tin đang hiển thị
staffId|mã nhân viên
startsAt|thời điểm bắt đầu
studentId|mã sinh viên
tenantName|tên người thuê
ticketId|mã hồ sơ hỗ trợ
toStatus|trạng thái sau quyết định
updateMany|cập nhật các mục phù hợp
viewingSlotsRequired|điều kiện phải có khung giờ xem
withdrawnAt|thời điểm rút đánh giá
RETURNED|đã tiếp nhận phòng trả lại
FREE|Cơ bản
PRO|Nâng cao
PREMIUM|Cao cấp
PATCH|cập nhật thông tin
DEFAULT|mặc định
NORMAL|bình thường
LOW|thấp
HIGH|cao
URGENT|khẩn cấp
GENERAL|chung
BILLING|thanh toán
ACCOUNT|tài khoản
SAFETY|an toàn
ELECTRICITY|điện
WATER|nước
OTHER|khác
CASH|tiền mặt
TRANSFER|chuyển khoản
HOURLY|theo giờ
DAILY|hằng ngày
WEEKLY|hằng tuần
MONTHLY|hằng tháng
PUBLIC|công khai
ALL|tất cả
RENT|tiền thuê
UTILITY|điện nước
MINOR|nhẹ
MAJOR|nghiêm trọng
CRITICAL|khẩn cấp
YES|có
NO|không
all|tất cả
mine|của tôi
unassigned|chưa phân công
overdue|quá hạn
due_soon|sắp đến hạn
paused|tạm dừng tính hạn
recent|mới nhất
oldest|cũ nhất
resolution_due|theo hạn giải quyết
support.user_tickets|quyền gửi yêu cầu hỗ trợ
billing.approve_payment_proof|quyền duyệt chứng từ thanh toán
billing.tariff_approve|quyền duyệt biểu phí được ghi trong danh mục quyền
''')


PERMISSION_LABELS = {
    'property.view': 'xem khu trọ', 'property.manage': 'quản lý khu trọ',
    'room.view': 'xem phòng', 'room.manage': 'quản lý phòng',
    'tenant.view': 'xem hồ sơ người thuê', 'tenant.manage': 'quản lý hồ sơ người thuê',
    'lease.view': 'xem hợp đồng', 'lease.manage': 'quản lý hợp đồng',
    'billing.view': 'xem hóa đơn', 'billing.create': 'lập hóa đơn',
    'billing.record_payment': 'ghi nhận thu tiền', 'billing.cancel': 'hủy hóa đơn',
    'billing.reverse_payment': 'đảo thanh toán', 'billing.approve_payment_proof': 'duyệt chứng từ thanh toán',
    'billing.adjust': 'điều chỉnh hóa đơn', 'billing.refund': 'ghi nhận hoàn tiền',
    'billing.policy': 'quản lý chính sách nhắc nợ', 'billing.tariff_approve': 'duyệt biểu phí',
    'expense.view': 'xem chi phí', 'expense.manage': 'quản lý chi phí',
    'maintenance.view': 'xem bảo trì', 'maintenance.manage': 'xử lý bảo trì',
    'maintenance.complete': 'hoàn tất bảo trì', 'report.view': 'xem báo cáo',
    'report.export': 'xuất báo cáo', 'staff.view': 'xem nhân sự', 'staff.manage': 'quản lý nhân sự',
    'audit.view': 'xem nhật ký', 'notification.view': 'xem thông báo',
    'notification.manage': 'quản lý thông báo', 'operation.view': 'xem công việc',
    'operation.manage': 'quản lý công việc',
    'admin.dashboard.view': 'xem tổng quan nền tảng', 'admin.accounts.view': 'xem tài khoản',
    'admin.accounts.manage': 'quản lý tài khoản', 'admin.accounts.suspend': 'đình chỉ hoặc khôi phục tài khoản',
    'admin.sessions.revoke': 'thu hồi phiên truy cập của tài khoản khác',
    'admin.properties.view': 'xem khu và phòng toàn nền tảng', 'admin.properties.manage': 'quản lý khu thay chủ trọ',
    'admin.support.read': 'xem hồ sơ hỗ trợ', 'admin.support.manage': 'xử lý hồ sơ hỗ trợ',
    'admin.pii.reveal': 'xem thông tin cá nhân được che',
    'admin.listings.moderate': 'kiểm duyệt tin cho thuê', 'admin.reviews.moderate': 'kiểm duyệt đánh giá',
    'admin.audit.view': 'xem nhật ký quản trị', 'admin.audit.export': 'xuất nhật ký quản trị',
    'admin.campuses.manage': 'quản lý danh mục cơ sở trường',
    'admin.admins.manage': 'quản lý quyền quản trị viên',
    'admin.operations.view': 'xem hoạt động và sự cố', 'admin.operations.manage': 'xử lý sự cố',
    'admin.notifications.view': 'xem thông báo quản trị', 'admin.moderation.appeals': 'xét kháng nghị',
    'admin.moderation.bulk': 'kiểm duyệt hàng loạt', 'admin.moderation.reports': 'xem báo cáo kiểm duyệt',
    'admin.flags.manage': 'quản lý việc bật tắt tính năng', 'admin.teams.manage': 'quản lý nhóm quản trị',
    'admin.permissions.simulate': 'kiểm tra mô phỏng quyền', 'admin.finance.read': 'xem thông tin tài chính',
    'admin.finance.reconcile': 'lập và xét duyệt đối soát', 'admin.reports.manage': 'quản lý báo cáo quản trị',
    'admin.verifications.view': 'xem hồ sơ xác minh', 'admin.verifications.manage': 'xét duyệt hồ sơ xác minh',
    'admin.plans.view': 'xem gói dịch vụ', 'admin.plans.manage': 'quản lý và cấp gói dịch vụ',
}

TERMS.update(PERMISSION_LABELS)
add_terms('''
AuditLog|nhật ký nghiệp vụ
HousingNotification|thông báo lịch xem
PlatformNotification|thông báo nền tảng
ReceiptRefund|hoàn tiền từ khoản thu
TenantsController|chức năng hồ sơ người thuê
outboxEvents|xem thông báo chờ gửi
retryOutbox|gửi lại thông báo hóa đơn
readAt|thời điểm đọc
job|yêu cầu đang chờ thực hiện
jobs|các yêu cầu đang chờ thực hiện
queue|danh sách chờ xử lý
queues|các danh sách chờ xử lý
metadata|thông tin tham chiếu
model|thông tin nghiệp vụ
schema|tình trạng dữ liệu
heartbeat|tình trạng hoạt động định kỳ
release blockers|các điều kiện chưa đủ để vận hành
runbook|hướng dẫn xử lý
run|lần thực hiện
storage|nơi lưu giữ
scanner|dịch vụ kiểm tra an toàn tệp
fail-closed|không chấp nhận tệp khi chưa xác nhận an toàn
Retrieval|tra cứu nguồn hướng dẫn
fallback|câu trả lời dự phòng
Ollama|dịch vụ trả lời tự động
TTL|thời hạn sử dụng
decorator|danh mục vai trò khai báo
filter|bộ lọc
withdrawn|đã rút
upload|tải tệp lên
download|tải tệp xuống
feature|tính năng
hash|dấu đối chiếu nội dung
CLEAN|đã xác nhận an toàn
pending|chờ xử lý
feed|danh sách công việc
system|hệ thống
candidate|giao dịch phù hợp để đối chiếu
candidateCount|số giao dịch phù hợp
override|mức phí riêng
unallocated credit|tiền chưa phân bổ
clear|xóa danh sách đang chọn
notes|ghi chú
duration|thời lượng
items|các mục
success|thành công
source|nguồn hướng dẫn
accept|chấp nhận
update|cập nhật
create|tạo
delete|xóa
any|ít nhất một quyền trong nhóm theo từng thao tác
all|tất cả
view|xem
manage|quản lý
read|xem
write|ghi nhận
scope|phạm vi được phép
mode|cách thực hiện
unique|quy định không trùng
reasons|các lý do
period|kỳ
lowercase|chuyển về chữ thường
limit|số mục trên trang
backfill|bổ sung dữ liệu lịch sử
soft|giữ lịch sử
hard|xóa khỏi danh mục
existing|đã tồn tại
ready|sẵn sàng
new|mới
readable|được phép đọc
active|đang hoạt động
archived|đã lưu trữ
''')

add_terms('''
Version|phiên bản thông tin
inventory|danh mục khu và phòng
task|công việc
field|trường thông tin
landlord|chủ trọ
dashboard|tổng quan
timezone|múi giờ
admins|quản trị viên
appeal|kháng nghị
lifecycle|trạng thái sử dụng
pipeline|quá trình xử lý
batch|lần xử lý nhiều mục
bulk|lập hàng loạt
recipient|người nhận
log|nhật ký
cursor|mốc tra cứu trang tiếp theo
stage|giai đoạn
accounts|tài khoản
assignment|phân công
merged|đã hợp nhất
accepted|đã chấp nhận
inactive|ngừng hoạt động
Email|thư điện tử
portal|cổng người thuê
fingerprint|dấu đối chiếu bản xem trước
revision|phiên bản cập nhật
event|thông báo nghiệp vụ
command|lần xác nhận nghiệp vụ
preference|lựa chọn nhận thông báo
checked|kết quả kiểm tra
platform|nền tảng
analytics|số liệu tổng hợp
admin|quản trị viên
effective|đang áp dụng
mutate|làm thay đổi dữ liệu
area|khu vực
asset|tài sản
credit|tiền còn chưa phân bổ
remaining|số tiền còn lại
by|theo
enqueue|đưa vào danh sách chờ
expense|chi phí
comment|nội dung trao đổi
escalate|chuyển cấp xử lý
cost|chi phí
recipients|người nhận
file|tệp
landlords|chủ trọ
invite|lời mời
sessions|phiên truy cập
reveal|xem thông tin đã che
publish|công khai
outcome|kết luận
enforcement|quyết định xử lý nội dung
context|bối cảnh sử dụng
rating|điểm đánh giá
private|nội bộ
hide|ẩn
deleted|đã xóa
config|thiết lập
boolean|lựa chọn có hoặc không
helper|kiểm tra điều kiện liên quan
mutation|thao tác thay đổi dữ liệu
allowed|kết quả được phép
occupants|người ở cùng
deposit|tiền cọc
execution|kết quả thực hiện
replacement|hóa đơn thay thế
method|phương thức
retried|kết quả đưa lại vào danh sách chờ
month|tháng
gateway|cổng thanh toán thử nghiệm
escalated|đã chuyển cấp
step|bước
cadence|chu kỳ thực hiện
index|thứ tự
audience|nhóm người nhận
resolve|hoàn tất xử lý
deadline|hạn xử lý
test|kiểm chứng
acknowledgement|xác nhận đã nhận
overview|tổng quan
monthly|hằng tháng
take|số mục lấy ra
error|lỗi
Invite|lời mời
catalog|danh mục
detail|chi tiết
kinds|các loại
time|thời gian
Appeal|kháng nghị
notify|thông báo
Decorator|danh mục vai trò khai báo
timeline|dòng thời gian xử lý
saved views|bộ lọc đã lưu
filters|các bộ lọc
approved|đã chấp thuận
verified|đã xác minh
plans|gói dịch vụ
alias|tên thay thế
identity|thông tin nhận diện
Explore|khu vực tìm phòng
estimate|ước tính
ceil|làm tròn lên
reschedule|đổi lịch
uploader|người tải tệp
inspection|kiểm tra phòng
remove|gỡ bỏ
fees|phí
versions|các phiên bản
viewer|người xem
Create|tạo mới
parse|đọc thông tin
removed|đã gỡ
migration|thay đổi dữ liệu
concurrency|thay đổi đồng thời
aging|tuổi nợ
events|các lần xác nhận thanh toán
payments|các lần thanh toán
debit|khoản tăng phải thu
total|tổng số
receipts|các khoản thu
callback|bước ghi sổ
released|đã giải phóng
impact|phân tích tác động
before|trước
enum|danh mục được chọn
disabled|đã tắt
uploads|chức năng tệp đính kèm
paid|đã thanh toán
class|biểu mẫu riêng
unknown|chưa định trước
render|hiển thị
cross-site|gửi từ trang khác
public|công khai
claim|thông tin xác nhận
complete|hoàn tất
severity|mức độ nghiêm trọng
templates|các mẫu nội dung
actor|người thực hiện
group|nhóm
housing|tiếp nhận thuê
namespace|nhóm thông tin
marked|đã đánh dấu
busy|đang xử lý
timeout|quá thời gian phản hồi
answer|câu trả lời
sources|các nguồn hướng dẫn
abort|dừng yêu cầu
workspace|phạm vi làm việc
escape|bảo vệ nội dung ô
reports.scheduled|thông báo báo cáo theo lịch
runs|các lần thực hiện
export|xuất báo cáo
logs|nhật ký
metrics|chỉ số hoạt động
transition|chuyển trạng thái
release|đánh giá sẵn sàng vận hành
console|khu vực quản trị
non-admin|không phải quản trị viên
Console|khu vực quản trị
revoked|đã thu hồi
updated|đã cập nhật
reviewed|đã rà soát
address|địa chỉ
q|từ khóa tìm
reject|từ chối
retirement|ngừng áp dụng
appeals|các kháng nghị
Reviewer|người xét duyệt
cleanup|dọn liên kết
links|các liên kết
state machine|quy định chuyển trạng thái
clock|thời hạn đang tính
supervisor|người giám sát
categories|các nhóm yêu cầu
agent|người xử lý
holidays|ngày nghỉ
escalation|chuyển cấp
resolution|giải quyết
Requester|người yêu cầu
own|của mình
plan|gói dịch vụ
billing|thanh toán
matched|đã ghép
unmatched|chưa ghép
target|đối tượng đích
Checker|người duyệt
authentication|xác minh danh tính
authorization|quyền sử dụng
city|tỉnh hoặc thành phố
state|trạng thái
toStatus|trạng thái sau quyết định
''')

PHRASES.update({
    'dashboard.view': 'quyền xem tổng quan',
    'accounts.view': 'quyền xem tài khoản',
    'accounts.manage': 'quyền quản lý tài khoản',
    'admins.manage': 'quyền quản lý quản trị viên',
    'support.read/manage': 'quyền xem và xử lý hỗ trợ',
    'support.read': 'quyền xem hỗ trợ',
    'support.manage': 'quyền xử lý hỗ trợ',
    'flags.manage': 'quyền thiết lập bật tắt tính năng',
    'plans.view': 'quyền xem gói dịch vụ',
    'plans.manage': 'quyền quản lý gói dịch vụ',
    'sessions.revoke': 'quyền thu hồi phiên',
    'state machine': 'quy định chuyển trạng thái',
    'thu.created': 'ghi nhận khoản thu',
    'mã/test': 'bằng chứng đối chiếu',
    'mã nguồn/test': 'bằng chứng đối chiếu',
})
