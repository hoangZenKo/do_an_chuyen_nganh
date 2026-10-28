import json
import re
from collections import Counter
from pathlib import Path
from catalog_data import cases, GROUPS, TECH, CROSSWALK
from auth_specs import SPECS

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[2]
SNAPSHOT = Path('/private/tmp/rrm-ba-uc-20261029')
INDEX = json.loads((BASE / 'evidence/analysis-index.json').read_text())
ROUTES = {r['id']: dict(r, ref=f'R{number:04d}') for number, r in enumerate(INDEX['routes'], 1)}
CLASSES = {c['name']: c for c in INDEX['classes']}
SOURCES = {}

def anchor(key, file, needle, label, kind='Source'):
    lines = (SNAPSHOT / file).read_text().splitlines()
    found = [number for number, text in enumerate(lines, 1) if needle in text]
    if not found:
        raise ValueError((key, file, needle))
    SOURCES[key] = dict(id=f'E{len(SOURCES)+1:03d}', file=file, line=found[0], needle=needle, label=label, kind=kind)

def method(key, owner, name, label=None):
    cls = CLASSES[owner]
    entry = next(m for m in cls['methods'] if m['name'] == name)
    anchor(key, cls['file'], f'{name}(', label or f'{owner}.{name}')
    SOURCES[key]['line'] = entry['line']

def ref(*keys):
    return ' '.join('[' + SOURCES[key]['id'] + ']' for key in keys)

def register_sources():
    for key, owner, name in [
        ('registerRoute','AuthController','register'), ('seekerRoute','AuthController','registerSeeker'),
        ('loginRoute','AuthController','login'), ('logoutRoute','AuthController','logout'),
        ('sessionsRoute','AuthController','sessions'), ('changeRoute','AuthController','changePassword'),
        ('registerService','AuthService','registerAccount'), ('seekerService','AuthService','registerSeeker'),
        ('loginService','AuthService','login'), ('logoutService','AuthService','logout'),
        ('sessionsService','AuthService','sessions'), ('revokeService','AuthService','revokeSession'),
        ('revokeOthers','AuthService','revokeOtherSessions'), ('changeService','AuthService','changePassword'),
        ('issueSession','AuthService','issueSession'), ('refreshService','AuthService','refresh'),
        ('forgotService','AccountAccessService','forgot'), ('redeemService','AccountAccessService','redeem'),
        ('accessEnqueue','AccountAccessService','enqueue'), ('recoveryRoute','AccountAccessController','forgot'),
        ('tenantAcceptRoute','TenantInvitesController','accept'), ('tenantAccept','TenantInvitesService','accept'),
        ('tenantCreate','TenantInvitesService','create'), ('staffAcceptRoute','StaffController','accept'),
        ('staffAccept','StaffService','accept'), ('mfaService','AdminMfaService','verify'),
    ]:
        method(key, owner, name)
    for key, file, needle, label in [
        ('registerDto','backend/src/auth/dto/register.dto.ts','export class RegisterDto','RegisterDto'),
        ('loginDto','backend/src/auth/dto/login.dto.ts','export class LoginDto','LoginDto'),
        ('changeDto','backend/src/auth/dto/change-password.dto.ts','export class ChangePasswordDto','ChangePasswordDto'),
        ('refreshDto','backend/src/auth/dto/refresh.dto.ts','export class RefreshDto','RefreshDto'),
        ('tenantAcceptDto','backend/src/tenants/dto/accept-tenant-invite.dto.ts','export class AcceptTenantInviteDto','AcceptTenantInviteDto'),
        ('staffAcceptDto','backend/src/staff/dto/accept-staff-invite.dto.ts','export class AcceptStaffInviteDto','AcceptStaffInviteDto'),
        ('jwt','backend/src/auth/jwt.strategy.ts','async validate','JwtStrategy.validate'),
        ('rolesGuard','backend/src/common/roles.guard.ts','canActivate','RolesGuard.canActivate'),
        ('propertyInterceptor','backend/src/common/property-scope.ts','class PropertyScopeInterceptor','PropertyScopeInterceptor'),
        ('adminAccess','backend/src/common/admin-access.ts','export','Admin access predicates'),
        ('userDb','backend/prisma/schema.prisma','model User {','User'),
        ('tenantDb','backend/prisma/schema.prisma','model Tenant {','Tenant'),
        ('sessionDb','backend/prisma/schema.prisma','model AuthSession {','AuthSession; RefreshToken trong cùng schema'),
        ('accessTokenDb','backend/prisma/schema.prisma','model AccountAccessToken {','AccountAccessToken'),
        ('tenantInviteDb','backend/prisma/schema.prisma','model TenantInvite {','TenantInvite'),
        ('staffDb','backend/prisma/schema.prisma','model StaffProfile {','StaffProfile; StaffInvite; StaffPropertyScope'),
        ('registerUi','lib/features/auth/register_screen.dart','Future<void> _submit','RegisterScreen._submit'),
        ('loginUi','lib/features/auth/login_screen.dart','Future<void> _submit','LoginScreen._submit'),
        ('logoutUi','lib/features/auth/auth_providers.dart','Future<void> logout','SessionController.logout'),
        ('sessionsUi','lib/features/admin/admin_sessions_screen.dart','class AdminSessionsScreen','AdminSessionsScreen'),
        ('changeUi','lib/features/tenant_portal/tenant_change_password_screen.dart','class TenantChangePasswordScreen','TenantChangePasswordScreen'),
        ('recoveryUi','lib/features/auth/password_recovery_dialog.dart','class PasswordRecoveryDialog','PasswordRecoveryDialog'),
        ('redeemUi','lib/features/auth/account_access_screen.dart','Future<void> _submit','AccountAccessScreen._submit'),
        ('tenantInviteUi','lib/features/auth/tenant_invite_screen.dart','Future<void> _submit','TenantInviteScreen._submit'),
        ('staffInviteUi','lib/features/auth/staff_invite_screen.dart','Future<void> _submit','StaffInviteScreen._submit'),
        ('authStorage','lib/data/auth/auth_repository.dart','class AuthRepository','AuthRepository login/register/logout/restore'),
        ('sessionController','lib/features/auth/auth_providers.dart','class SessionController','SessionController'),
        ('authNavigation','lib/features/auth/auth_navigation.dart','homeRouteForSession','homeRouteForSession'),
        ('tokenRefresh','lib/data/auth/token_refresh_coordinator.dart','class TokenRefreshCoordinator','TokenRefreshCoordinator'),
        ('network','lib/core/network/api_client.dart','authRetry','API client retry 401'),
        ('bootstrap','backend/src/app.bootstrap.ts','ValidationPipe','Global validation and API prefix'),
        ('appModule','backend/src/app.module.ts','@Module','Module registrations and global interceptors'),
        ('errorFilter','backend/src/common/api-error.filter.ts','class ApiErrorFilter','ApiErrorFilter'),
        ('flutterApp','lib/app/app.dart','GoRouter','Flutter routing'),
        ('turnover','backend/src/operations/turnover.workflow.ts','export const turnoverStages','Turnover stages and beginTurnover'),
        ('demoGateway','backend/src/billing/demo-card.gateway.ts','class DemoCardGateway','DemoCardGateway.assertEnabled; validateCard'),
        ('reportCsv','lib/features/reports/reports_screen.dart','Clipboard.setData(ClipboardData(text: export.content))','ReportsScreen CSV clipboard'),
        ('entitlements','backend/src/common/subscription-entitlements.ts','export','Inventory subscription entitlements'),
        ('chatbotConfig','backend/src/chatbot/chatbot.config.ts',"env.CHATBOT_ENABLED ?? 'false'",'Chatbot default disabled'),
        ('chatbotRole','backend/src/chatbot/chatbot.controller.ts','@Roles(AuthRole.LANDLORD)','Chatbot role'),
        ('leasePdf','lib/features/tenants/lease_pdf.dart','import','Local lease PDF'),
        ('invoicePdf','lib/features/billing/invoice_pdf.dart','import','Local invoice PDF'),
    ]:
        anchor(key,file,needle,label)
    for key,file,needle,label in [
        ('registerTests','test/features/auth/register_screen_test.dart','purpose selector matches','RegisterScreen tests; validate/register two purposes'),
        ('authTests','backend/src/auth/auth.service.spec.ts','registers as a landlord','AuthService tests; register, duplicate, inactive, change password'),
        ('jwtTests','backend/src/auth/jwt.strategy.spec.ts','maps an active landlord','JwtStrategy tests'),
        ('sessionTests','test/features/auth/session_cache_isolation_test.dart','password change clears','Password change and cache isolation tests'),
        ('accessTests','backend/src/auth/account-access.service.spec.ts','rate-limits repeated','Account access send rate-limit unit test'),
        ('recoveryTests','test/features/auth/account_access_test.dart','activation handles','Account access link parsing and recovery UI tests'),
        ('tenantTests','backend/src/tenants/tenant-invites.service.spec.ts','creates a hashed activation invite','Tenant invite create tests, không phải accept E2E'),
        ('inviteE2e','backend/test/e2e/app-functional.e2e-spec.ts','limits tenant invite resends','Tenant and STAFF accept E2E source; chưa chạy'),
        ('ownSessionsE2e','backend/test/e2e/admin-next-sprints.e2e-spec.ts','revokes other devices','Own-session revoke E2E source; chưa chạy'),
        ('refreshE2e','backend/test/e2e/auth.e2e-spec.ts','rotates refresh tokens','Auth refresh/logout E2E source; chưa chạy'),
    ]:
        anchor(key,file,needle,label,'Test source, không mặc định đã chạy mọi scenario')
    for key, owner, name in [
        ('leaseCreate','LeasesService','create'), ('leaseEnd','LeasesService','end'),
        ('turnoverAdvance','TurnoversService','advance'), ('settleConfirm','LeaseSettlementsService','confirm'),
        ('settlePreview','LeaseSettlementsService','preview'), ('settleRefund','LeaseSettlementsService','recordRefund'),
        ('lifecycleExecute','TenantLifecycleService','executeRequest'), ('proofReview','BillingService','reviewPaymentProof'),
        ('invoiceCancel','BillingService','cancelInvoice'), ('paymentReverse','BillingService','reversePayment'),
        ('monthlyReport','ReportsService','monthly'), ('listingVisible','ListingsService','visibleWhere'),
        ('listingUpdate','ListingsService','update'), ('savedSearchCreate','SavedSearchesService','create'),
        ('supportAttachment','SupportAttachmentService','upload'),
        ('viewingLease','HousingService','createLease'),
    ]:
        if owner in CLASSES and any(m['name']==name for m in CLASSES[owner]['methods']):
            method(key,owner,name)


BLOCKS = []
def heading(text, level=1): BLOCKS.append(('heading', level, text))
def paragraph(text): BLOCKS.append(('paragraph', text))
def table(headers, rows, widths=None): BLOCKS.append(('table', headers, rows, widths))
def pagebreak(): BLOCKS.append(('pagebreak',))

def system_report():
    heading('1 Phạm vi sửa đổi và kết luận AS IS')
    paragraph('Tài liệu này viết lại phần Use Case của hệ thống Quản lý nhà trọ dựa trên mã nguồn hiện có, không phải mô tả hệ thống tương lai. Đây là đợt 1: hoàn thành báo cáo phân tích hệ thống, catalog chức năng và đặc tả chi tiết nhóm tài khoản. Các nhóm nghiệp vụ còn lại mới ở mức catalog, chưa phải bộ đặc tả hoàn chỉnh để nghiệm thu toàn hệ thống.')
    table(['Nội dung','Phạm vi và trạng thái'],[
        ('Báo cáo đối chiếu','Bao_cao_Quan_ly_Nha_tro_V3_2026-10-28.docx; 131 mã UC cũ. Bản gốc không bị ghi đè.'),
        ('Mã nguồn chuẩn phân tích','Snapshot working tree ngày 29/10/2026, gồm cả thay đổi chưa commit. Base commit 2d1ec6444ff8a84fb1de4487f4cc7514354076cc không đại diện toàn bộ snapshot.'),
        ('Gói bằng chứng','853 tệp trong source-snapshot.zip; SHA-256 từng tệp ở source-manifest.json; không lấy .env, credentials hoặc dữ liệu DB đang chạy.'),
        ('Kết quả kiểm kê','405 endpoint; 70 controller có route; 110 Prisma models; 30 enum. Đây là số lượng cấu trúc tĩnh, không phải 405 chức năng người dùng.'),
        ('Catalog mới','164 UC theo mục tiêu; 393 endpoint ánh xạ UC và 12 endpoint hỗ trợ/kỹ thuật. Ánh xạ route không tự chứng minh đầy đủ hành vi hay UI.'),
        ('Đặc tả được kiểm tra chéo','9 UC tài khoản theo A–J và 2 tiến trình hỗ trợ phiên. 155 UC còn lại cần đặc tả ở đợt tiếp theo; không tái sử dụng bảng cũ như đã xác nhận.'),
        ('Kiểm thử thực thi','31 backend tests trong 7 suites và 48 Flutter tests đạt. Tệp thuộc vùng kiểm thử đối chiếu hash trùng snapshot. Không chạy E2E DB hoặc thử giao dịch, email, storage thực.'),
    ],[3.2,12.7])
    paragraph('Phần UC của báo cáo cũ cần được thay bằng tài liệu này theo đúng mức hoàn thành. Sơ đồ Use Case, tuần tự và kết quả kiểm thử trong báo cáo cũ là tài liệu lịch sử; chưa được tái xác nhận toàn bộ ở đợt này. Không được coi việc giữ mã UC cũ là xác nhận nội dung mô tả cũ.')
    heading('1.1 Quy ước bằng chứng',2)
    table(['Nhãn','Ý nghĩa sử dụng'],[
        ('Xác nhận','Đã đọc hành vi ở lớp liên quan và có nguồn định vị. Không đồng nghĩa đã kiểm thử tích hợp hoặc triển khai production.'),
        ('Suy luận có căn cứ','Cách diễn giải từ cấu trúc hoặc nối dây triển khai; thiếu kiểm chứng để kết luận nghiệp vụ đầy đủ.'),
        ('Chưa đủ bằng chứng','Chưa truy vết đủ lớp, chưa thấy UI/test hoặc chưa có cấu hình/runtime cần thiết. Không đồng nghĩa chức năng không tồn tại.'),
        ('Một phần','Có phần triển khai nhưng mục tiêu rộng hơn chưa được đáp ứng hoặc đã có hạn chế xác nhận; phải chỉ rõ giới hạn.'),
        ('Đề xuất','Không thuộc AS-IS và không được viết thành bước hiện có.'),
    ],[3.2,12.7])
    paragraph('Ký hiệu E là nguồn hành vi được định vị ở mục 7; R là endpoint trong Requirements Traceability Matrix đi kèm. Đường dẫn đều tính từ gốc repository và số dòng ứng với snapshot, không theo tệp đang tiếp tục chỉnh sửa. Khi backend không có controller/service tách riêng, bảng truy vết ghi đúng cấu trúc thực tế, không dựng thêm lớp giả.')
    heading('1.2 Tổng quan nghiệp vụ và kiến trúc',2)
    paragraph('Hệ thống kết hợp quản lý vận hành khu trọ của chủ trọ và nhân viên, cổng người thuê, hành trình khám phá phòng công khai và quản trị nền tảng. Người tìm phòng và người thuê có hợp đồng cùng dùng vai trò TENANT nhưng có dữ liệu và khả năng thực thi khác nhau. ' + ref('userDb','tenantDb','authNavigation'))
    table(['Lớp','Triển khai và trách nhiệm','Nguồn'],[
        ('Ứng dụng','Flutter; Riverpod quản lý trạng thái; GoRouter điều hướng. API repositories tách khỏi màn hình; Dio gửi request và xử lý 401.','lib/app/app.dart; lib/features/auth/auth_providers.dart; lib/data; lib/core/network/api_client.dart'),
        ('API','NestJS modular monolith, các module đăng ký trong AppModule; prefix /api/v1; DTO validation whitelist, forbidNonWhitelisted và transform.',ref('bootstrap','appModule')),
        ('Nghiệp vụ','Controller nhận request và kiểm quyền; services xử lý transaction, kiểm trạng thái và phạm vi sở hữu. Không suy luật từ tên endpoint.','backend/src; analysis-index.json chứa lời gọi service từng route'),
        ('Dữ liệu','Prisma/PostgreSQL; schema hiện có 110 models và 30 enum; migrations là bằng chứng tiến hóa schema, chưa chứng minh DB đang chạy áp đủ migrations.','backend/prisma/schema.prisma; backend/prisma/migrations'),
        ('Định danh và bảo vệ','Access JWT, refresh rotation, AuthSession; role/admin permissions/staff permissions và interceptor phạm vi khu.','E tham chiếu tại mục 2; backend/src/common'),
        ('Tác vụ nền và tích hợp','Có outbox/delivery/support workers, tệp riêng và thanh toán demo; trạng thái sẵn sàng phụ thuộc cấu hình. Không xác nhận kết nối nhà cung cấp thực từ source.','backend/src/delivery; backend/src/billing/online-payments.service.ts; backend/src/support'),
    ],[2.5,9.2,4.2])
    paragraph('Điểm nối chính: màn hình → provider/repository → Dio → controller/guard/interceptor → service → Prisma → PostgreSQL. Luồng background được enqueue qua bảng job/outbox; request thành công không mặc định đồng nghĩa email đã giao hoặc job đã hoàn tất. ' + ref('authStorage','network','bootstrap','accessEnqueue'))
    heading('1.3 Các đối tượng dữ liệu chính',2)
    table(['Nhóm','Đối tượng và quan hệ thực tế'],[
        ('Danh tính','User giữ role, isActive, passwordHash, sessionVersion; AuthSession/RefreshToken thuộc User; AdminProfile hoặc StaffProfile mở rộng danh tính. Tenant có thể chưa có userId.'),
        ('Phân quyền nhân viên','StaffProfile thuộc landlord; StaffPropertyScope gắn nhân viên với khu; lời mời STAFF chứa preset, permissions và propertyIds.'),
        ('Tài sản thuê','Property → Room; Tenant thuộc landlord; Lease nối Tenant và Room. Nhiều ràng buộc trạng thái nằm trong service, không phải chỉ quan hệ schema.'),
        ('Tài chính','Invoice/InvoiceLineItem lưu nợ và snapshot dòng; Payment là giao dịch gắn hóa đơn; receipt, allocation, proof, reversal và refund là những đối tượng/luồng khác nhau.'),
        ('Vận hành','Chỉ số điện nước, maintenance, turnover, settlement, lifecycle request và tác vụ nhắc nhở; trạng thái duyệt không đồng nghĩa đã thực thi chuyển/đóng hợp đồng.'),
        ('Khám phá','Listing thuộc phòng; slots/viewings hỗ trợ xem phòng; favorites, saved searches, reviews, moderation/report/appeal lưu hành trình riêng.'),
        ('Nền tảng','Support ticket/messages/attachments; audit; plans/subscriptions; feature flags và dữ liệu governance. Chưa trình bày schema đầy đủ như đặc tả UC đã nghiệm thu.'),
    ],[3.0,12.9])
    paragraph('Nguồn đối tượng: backend/prisma/schema.prisma; phần định nghĩa đầy đủ trong evidence database của đợt kiểm kê trước chỉ dùng tham khảo, nguồn chuẩn vẫn là schema thuộc source-snapshot.zip. Ma trận route ở đợt này không đại diện ERD toàn hệ thống.')
    heading('1.4 Ranh giới tích hợp và xử lý lỗi',2)
    paragraph('Validation toàn cục loại trường ngoài DTO thay vì âm thầm lưu. ApiErrorFilter chuẩn hóa lỗi máy chủ từ 500 thành INTERNAL_SERVER_ERROR và gắn requestId; lỗi validation dạng mảng thành VALIDATION_ERROR. Không biến mọi lỗi kỹ thuật giả định thành nhánh nghiệp vụ. Bảo đảm rollback chỉ ghi khi thao tác thực sự nằm trong transaction. ' + ref('bootstrap','errorFilter','registerService','redeemService'))

def actor_report():
    heading('2 Ma trận tác nhân và quyền hiệu lực')
    table(['Tác nhân','Xác thực và dữ liệu','Quyền và giới hạn AS IS'],[
        ('Khách','Không JWT; API công khai','Xem tin/cơ sở trường/đánh giá công khai; đăng ký, đăng nhập, forgot/redeem, accept invite. Không có quyền quản lý khu hay tự chọn role ADMIN.'),
        ('Người tìm phòng','User.role TENANT; chưa chắc có Tenant/Lease','Có API hành trình tìm phòng; quyền vào cổng người thuê phụ thuộc liên kết và dữ liệu, không phải role TENANT đơn lẻ.'),
        ('Người thuê','User TENANT gắn Tenant theo dữ liệu','Chỉ dữ liệu cổng thuê theo identity liên kết; không được coi có quyền sửa dữ liệu thuê của Tenant khác.'),
        ('Chủ trọ','User LANDLORD active','Dữ liệu theo landlordId. Quản lý tài sản/người thuê/tài chính/vận hành thuộc mình; không suy quyền ADMIN từ quyền sở hữu khu.'),
        ('Nhân viên','User STAFF, profile active, landlord active','Cần permission và phạm vi khu, đồng thời controller/action phải được interceptor cho phép. RequirePermissions nhiều mã áp ANY, không phải ALL.'),
        ('Quản trị viên','User ADMIN, AdminProfile/permissions và MFA theo guard','AdminPermissions yêu cầu ALL quyền được liệt kê; thiếu required metadata bị từ chối theo cơ chế admin-access. Không đồng nghĩa mọi ADMIN có toàn bộ quyền.'),
        ('Worker nội bộ','Không phải vai trò User thứ năm','Thực thi job/delivery/outbox theo module và cấu hình; không mô hình hóa worker thành quyền truy cập UI.'),
    ],[2.7,5.5,7.7])
    paragraph('Nguồn xác thực và quyền: ' + ref('jwt','rolesGuard','adminAccess','propertyInterceptor','userDb') + '. Ma trận này là mô tả bộ lọc quyền thực tế, không chỉ sao chép decorator ở controller.')
    heading('2.1 Giao của các bộ lọc quyền nhân viên',2)
    paragraph('Quyền hiệu lực STAFF = trạng thái danh tính hợp lệ ∩ role được cho phép ∩ permission phù hợp ∩ controller/action trong allowlist ∩ dữ liệu nằm trong khu được cấp. Không khẳng định quyền thực thi chỉ từ @Roles(STAFF). ' + ref('jwt','rolesGuard','propertyInterceptor'))
    table(['Phạm vi','Được xác nhận từ interceptor'],[
        ('Allowlist controller','PropertiesController, PropertyRoomsController, RoomsController, TenantsController, LeasesController, RoomLeasesController, TenantLeasesController, BillingController, ExpensesController, MaintenanceController, ReportsController, DashboardController, TenantLifecycleController.'),
        ('Ngoại lệ Auth và Staff','AuthController được đi qua. StaffController chỉ list và presets; cập nhật quyền, tạo invite không được mở cho STAFF chỉ vì decorator có staff.manage.'),
        ('Chặn action cụ thể','PropertiesController.create; MaintenanceController.escalate; BillingController.outboxEvents và retryOutbox.'),
        ('Controller ngoài allowlist','P1OperationsController, AnnouncementsController, NotificationsController, OperationsController, AuditController, TenantInvitesController và support controllers không được STAFF truy cập theo interceptor hiện có.'),
        ('Nhắc phí và dữ liệu Tenant','Reminder cần propertyId cụ thể thuộc scope. tenantScope yêu cầu có lease trong khu được cấp và không có lease/invoice ngoài khu; Tenant mới chưa lease có thể không còn hiện ở truy vấn scoped.'),
    ],[3.3,12.6])
    paragraph('Các UC ngoài nhóm SYS chưa có ma trận endpoint–permission hoàn chỉnh bằng hành vi UI; thông tin Roles/AdminPermissions/RequirePermissions thô của từng route được lưu trong Requirements_Traceability_Matrix.tsv, nhưng không thay thế kết luận hiệu lực ở mục này.')

def decomposition_report():
    heading('3 Phân rã chức năng và catalog Use Case')
    counts=Counter(c['group'] for c in cases())
    table(['Module','Mục tiêu nghiệp vụ','Số UC','Mức hoàn thành'],[
        (GROUPS[g], text, str(counts[g]), 'A–J: 9 UC' if g=='SYS' else 'Catalog; chưa đặc tả A–J')
        for g,text in [
            ('SYS','Đăng ký, đăng nhập, quản lý phiên và khôi phục truy cập'),
            ('DIS','Khám phá, đăng tin, lịch xem, đánh giá và kiểm duyệt cá nhân'),
            ('OPT','Khu trọ, phòng, tiện ích, giá và trạng thái tài sản'),
            ('TNT','Hồ sơ người thuê, hợp đồng, thanh lý và vòng đời thuê'),
            ('BIL','Hóa đơn, công nợ, chứng từ, thu tiền, phân bổ và báo cáo'),
            ('OPS','Bảo trì, điện nước, thông báo và vận hành khác'),
            ('TEN','Tra cứu và tương tác của người thuê theo danh tính'),
            ('ADM','Tài khoản quản trị, kiểm duyệt, registry, tài chính và governance'),
            ('SUP','Ticket, trao đổi, tệp, phân công và SLA hỗ trợ'),
            ('STF','Mời nhân viên, cấp scope và mô phỏng quyền'),
        ]
    ],[3.7,7.1,1.2,3.9])
    paragraph('Trong catalog: XN = đã xác nhận nhóm tài khoản qua các lớp; CB = có route/service wiring nhưng chưa đủ đối chiếu chi tiết ở đợt này; MP = một phần với giới hạn đã phát hiện (thanh toán demo). CB không được dùng làm bằng chứng rằng mọi bước của bản cũ là đúng. Mô tả ngắn chính là mục tiêu và giới hạn ở từng dòng; API thể hiện định danh controller.method để tra route chính xác trong ma trận R.')
    for group, title in GROUPS.items():
        heading('3.'+str(list(GROUPS).index(group)+1)+' '+title,2)
        rows=[]
        for c in cases():
            if c['group']!=group:continue
            api=[]
            for b in c['bindings']:
                if b.startswith('LOCAL.'):
                    api.append(b+' (Flutter, không API riêng)')
                else:
                    api.append(b+' ['+ROUTES[b]['ref']+']')
            status='XN' if group=='SYS' else ('MP' if c['code'] in ('TEN-05','TEN-09.2') else 'CB')
            c['status']=status
            rows.append((c['id']+'\n'+c['title'],c['actor']+'\n'+c['goal'], '\n'.join(api),status))
        table(['Mã và tên','Tác nhân và mục tiêu','API hoặc hàm liên quan','TT'],rows,[3.8,5.0,6.3,0.8])
        for c in cases():
            if c['group']==group and c['notes']:
                paragraph(c['id']+': '+c['notes'])
    heading('3.11 Quan hệ giữa các Use Case',2)
    paragraph('Không gán include/extend chỉ vì chung service/DTO: issueSession dùng chung là tái sử dụng kỹ thuật. UC-SYS-04 cũ chuyển thành SP-SYS-01 và SP-SYS-02, không mất chức năng phục hồi phiên. Chưa xác nhận generalization hoặc các mũi tên ở sơ đồ cũ; cần cập nhật sơ đồ theo catalog trước khi nghiệm thu.')

def auth_report():
    heading('4 Đặc tả chi tiết nhóm tài khoản')
    paragraph('Chín UC dưới đây đã được đối chiếu frontend, API, service, validation, dữ liệu và test khi có. Test scenarios tại mục J là kịch bản nghiệm thu suy ra từ AS-IS, không phải cam kết mọi kịch bản đều có test tự động hoặc đã chạy E2E. Mỗi số bước là cục bộ trong UC; mã BR dùng chung và truy vết ở mục 6.')
    for s in SPECS:
        pagebreak()
        c=next(c for c in cases() if c['code']==s['code'])
        heading(c['id']+' '+c['title'],2)
        heading('A Thông tin tổng quan',3)
        table(['Thuộc tính','Đặc tả'],[
            ('Mã và tên',c['id']+' — '+c['title']),
            ('Mô tả nghiệp vụ',s['description']),
            ('Phạm vi và cấp độ','Hệ thống Quản lý nhà trọ AS-IS; cấp mục tiêu người dùng, module Tài khoản và phiên làm việc.'),
            ('Tác nhân chính',s['actor']),
            ('Tác nhân phối hợp','Dịch vụ giao nhận email nếu được cấu hình; chỉ ở nhánh gửi của UC-SYS-06. Không coi email đã giao khi mới enqueue.' if s['code']=='SYS-06' else 'Không xác định tác nhân nghiệp vụ phối hợp độc lập trong luồng này; DB, API và secure storage là thành phần hệ thống.'),
            ('Mục tiêu',c['goal']),('Kích hoạt',s['trigger']),('Điều kiện trước',s['pre']),
            ('Hậu điều kiện thành công',s['success']),('Bảo đảm tối thiểu',s['minimum']),
        ],[4.0,11.9])
        heading('B Dữ liệu và ràng buộc',3)
        table(['Trường','Kiểu và bắt buộc','Điều kiện hợp lệ và giới hạn','Mặc định và quan hệ'],s['fields'],[3.0,2.8,6.6,3.5])
        heading('C Luồng thành công chính',3)
        table(['Bước','Tác nhân','Hành động','Phản hồi hoặc kết quả'],[(str(i),*step) for i,step in enumerate(s['flow'],1)],[0.9,2.4,6.1,6.5])
        heading('D Luồng thay thế',3)
        table(['Mã và bước','Điều kiện','Trình tự xử lý','Kết quả và điểm trở lại'],[(a+' / '+b,c,d,e) for a,b,c,d,e in s['alternatives']],[1.6,4.0,6.0,4.3])
        heading('E Luồng ngoại lệ',3)
        table(['Mã và bước','Điều kiện','Hệ thống xử lý','Trạng thái sau lỗi'],[(a+' / '+b,c,d,e) for a,b,c,d,e in s['errors']],[1.6,4.6,4.9,4.8])
        heading('F Quy tắc nghiệp vụ',3)
        table(['Mã','Quy tắc có thể kiểm thử','Nguồn'],[('BR-'+num,rule,ref(source)) for num,rule,source in s['rules']],[1.3,12.2,2.4])
        heading('G Phân quyền và bảo mật',3)
        paragraph(s['access'])
        heading('H Kết quả và dữ liệu sau thao tác',3)
        paragraph(s['effects'])
        heading('I Truy vết source code',3)
        layer=[]
        for key in s['sources']:
            e=SOURCES[key]
            layer.append((e['id'],e['file']+':'+str(e['line']),e['label']))
        table(['Nguồn','File và dòng','Hàm API hoặc bằng chứng'],layer,[1.2,9.1,5.6])
        heading('J Kịch bản nghiệm thu từ hành vi đã xác nhận',3)
        table(['Mã','Điều kiện hoặc thao tác','Kết quả phải kiểm chứng'],[(c['id']+'-'+a,b,d) for a,b,d in s['scenarios']],[3.1,5.5,7.3])
    heading('4.1 Checklist kiểm tra chéo nhóm tài khoản',2)
    table(['Tiêu chí','Kết quả rà soát và giới hạn'],[
        ('Đúng nghiệp vụ','Tách seeker/User TENANT khỏi hồ sơ Tenant; tách mời Tenant và STAFF; không có quyền tự chọn ADMIN.'),
        ('Đầy đủ','9 UC có A–J; phiên kỹ thuật được đặc tả riêng. Nhóm ngoài tài khoản chưa được đánh dấu hoàn tất.'),
        ('Rõ ràng','Đã ghi DTO riêng của từng endpoint, HTTP/status/code và kết quả UI; không dùng nhánh lỗi chung giả lập cho mọi UC.'),
        ('Nhất quán','BR-01–26 dùng chung; TTL cấu hình tách khỏi token mời 7 ngày và token khôi phục 30 phút.'),
        ('Có thể kiểm thử','Mỗi UC có success, invalid data và nhánh từ chối thực tế; endpoint công khai không tự thêm lỗi thiếu JWT.'),
        ('Có thể truy vết','Nguồn E có file, dòng và hàm, đối chiếu snapshot. Không tuyên bố tất cả acceptance scenarios đã chạy.'),
    ],[3.2,12.7])

def support_report():
    heading('5 Các tiến trình hỗ trợ phiên')
    heading('5.1 SP SYS 01 Phục hồi phiên ứng dụng',2)
    paragraph('Thay thế phần phục hồi danh tính của UC-SYS-04 cũ. Kích hoạt khi SessionController khởi tạo, không phải thao tác đăng nhập mới của người dùng. Nguồn: '+ref('authStorage','sessionController','jwt','authNavigation','sessionTests'))
    table(['Bước','Thực hiện','Kết quả và nhánh'],[
        ('1','Đọc secure storage','Không có phiên: trả null, ứng dụng ở trạng thái chưa đăng nhập.'),
        ('2','Gọi GET /api/v1/auth/me bằng JWT','Kiểm chứng active User/session/version và serialize quyền; nếu hợp lệ giữ token hiện hành, cập nhật user.'),
        ('3','Đọc lại storage trước ghi','Nếu đã logout: không phục hồi. Nếu user đã đổi: trả phiên mới, không ghi đè danh tính khác.'),
        ('4','Nếu /me nhận 401','Thử refresh bằng token hiện hành; trước/sau request kiểm tra lại user và refreshToken còn như cũ.'),
        ('5','Xử lý refresh','401 refresh: xóa đúng phiên matching; non-401: rethrow và giữ storage. Không coi mọi lỗi mạng là mất quyền vĩnh viễn.'),
    ],[1.0,5.7,9.2])
    paragraph('Dữ liệu sau thao tác: có thể cập nhật thông tin user và token, không tạo User hay Tenant. JWT sid có thể vắng ở phiên legacy; không mô tả sid là bắt buộc cho mọi token AS-IS. Kịch bản cần kiểm chứng: /me thành công, refresh hết hạn, lỗi 5xx, logout giữa request và đổi tài khoản giữa request; kết quả không được khôi phục phiên đã rời.')
    heading('5.2 SP SYS 02 Luân chuyển refresh token',2)
    paragraph('Kích hoạt khi khôi phục phiên hoặc request bảo vệ bị 401. API POST /api/v1/auth/refresh công khai, body refreshToken string tối thiểu 32 ký tự, throttle 20/60 giây; mặc định POST trả 201. Nguồn: '+ref('refreshDto','refreshService','tokenRefresh','network','sessionDb','issueSession'))
    table(['Bước','Thực hiện','Kết quả và kiểm soát'],[
        ('1','Client phối hợp refresh','TokenRefreshCoordinator gộp request đồng thời trong instance; API client chỉ authRetry một lần cho request lỗi 401.'),
        ('2','Server hash token, tìm candidate và khóa User','Kiểm token tồn tại, chưa revoked, chưa hết hạn, User active. Nếu có sid: AuthSession chưa revoke/hết hạn và userVersion trùng hiện hành.'),
        ('3','Tiêu thụ token có điều kiện trong transaction','Token cũ được revoke và trỏ replacedByTokenId; tạo replacement cùng sid; trả token mới.'),
        ('4','Client kiểm tra lại phiên trước ghi','Không ghi đè user mới hoặc token đã được thay; không phục sinh phiên đã logout.'),
        ('5','Từ chối và lỗi','Sai/hết hạn/dùng lại: 401 INVALID_REFRESH_TOKEN. Non-401 không tự xóa phiên. Không thấy revoke toàn bộ token family chỉ do replay.'),
    ],[1.0,5.7,9.2])
    paragraph('Cấp phiên mới dùng access TTL từ cấu hình (mặc định 15m) và refresh TTL mặc định 30 ngày theo cơ chế fallback, không phải chính sách bất biến. Rotation không gia hạn expiresAt của AuthSession: hạn token thay thế bị giới hạn bởi hạn phiên. Kiểm thử suy ra: token một lần, hai refresh cạnh tranh, storage đã đổi, lỗi 5xx và session revoked. Nguồn E2E xoay token/logout có tại '+ref('refreshE2e')+' nhưng chưa chạy. Không có bảo đảm request nghiệp vụ gốc thành công sau refresh nếu quyền dữ liệu đã thay đổi.')

def rules_report():
    heading('6 Danh mục quy tắc nghiệp vụ và phát hiện hệ thống')
    table(['Mã','Điều kiện và quy tắc','UC và bằng chứng'],[
        ('BR-'+num,rule,'UC-'+s['code']+' '+ref(source)) for s in SPECS for num,rule,source in s['rules']
    ],[1.3,10.2,4.4])
    paragraph('Các phát hiện ngoài SYS sau đây là ranh giới đã đọc trong service để hiệu chỉnh catalog; chưa thay thế đặc tả A–J. Nguồn là các service/phương thức được ghi từng dòng. Cần bổ sung trường dữ liệu, thứ tự UI và ma trận test khi đặc tả nhóm tương ứng.')
    findings=[
        ('Phòng và hợp đồng','Kết thúc lease không làm phòng VACANT ngay: chuyển MAINTENANCE và bắt đầu turnover. Tạo lease bị chặn bởi lease ACTIVE/turnover chưa xong và điều kiện phòng; deposit dương được ghi COLLECTED.', ['backend/src/leases/leases.service.ts'], ['OPT','TNT']),
        ('Thu hồi phòng','Turnover qua RETURNED, INSPECTION, REPAIR, CLEANING, READY; sửa chữa chưa xong chặn bước hoàn tất; chỉ khi sẵn sàng mới VACANT.', ['backend/src'], ['TNT']),
        ('Thanh lý và hoàn cọc','Settlement có preview/fingerprint và idempotency; không chứng minh thực hiện chuyển khoản ngân hàng. Ghi hoàn tiền cọc là luồng riêng; không tự nhập chung hóa đơn cũ vào settlement.', ['backend/src'], ['TNT','BIL']),
        ('Vòng đời hợp đồng','Request APPROVED chưa tự đồng nghĩa đã chuyển/checkout/renew. TRANSFER/CHECKOUT có điều kiện ended+settled và thực thi riêng.', ['backend/src'], ['TNT']),
        ('Tài chính','Proof PENDING không phải Payment. Approve tạo payment theo số nợ còn; cancel invoice bị chặn bởi lịch sử payment kể cả đã đảo về net zero. Payment được quản lý allocation không đảo trực tiếp.', ['backend/src'], ['BIL']),
        ('Thanh toán thẻ','DemoCardGateway chỉ bật khi NODE_ENV khác production và DEMO_PAYMENTS_ENABLED=true; không xác nhận cổng ngân hàng thật. QR/chuyển khoản thủ công không đồng nghĩa webhook xác nhận tiền tự động.', ['backend/src/online-payments'], ['TEN','BIL']),
        ('Báo cáo thu','Báo cáo tháng cộng net Payment, không mặc định toàn bộ tiền receipt. Xuất CSV tại UI qua clipboard không phải tính năng tải XLSX.', ['backend/src','lib/features'], ['BIL']),
        ('Tin công khai','Phải PUBLISHED, Room active VACANT, Property không archived và landlord active. Sửa nội dung có thể đưa tin về DRAFT, không đồng nghĩa sửa xong vẫn xuất bản.', ['backend/src'], ['DIS']),
        ('Lịch xem','Chuyển thành lease chỉ khi viewing COMPLETED; có transaction và version/capacity checks. Saved searches có giới hạn 10; không tìm thấy endpoint sửa toàn bộ bộ lọc đã lưu.', ['backend/src'], ['DIS']),
        ('Gói dịch vụ','Không có subscription row không mặc định bằng gói hạn mức 0. Hết hạn gói chặn tăng trưởng theo service; không đồng nghĩa xóa dữ liệu thuê đang tồn tại.', ['backend/src'], ['ADM']),
        ('Hỗ trợ và chatbot','Tệp hỗ trợ có quét malware riêng; không suy mọi upload được quét. Chatbot LANDLORD-only, mặc định tắt; không có bằng chứng truy vấn dữ liệu kinh doanh sống cho mọi câu hỏi.', ['backend/src'], ['SUP','OPS']),
    ]
    evidence_keys=[['leaseCreate','leaseEnd','turnover'],['turnoverAdvance','turnover'],
                   ['settleConfirm','settlePreview','settleRefund'],['lifecycleExecute'],
                   ['proofReview','invoiceCancel','paymentReverse'],['demoGateway'],
                   ['monthlyReport','reportCsv'],['listingVisible','listingUpdate'],
                   ['savedSearchCreate','viewingLease'],['entitlements'],['supportAttachment','chatbotConfig','chatbotRole']]
    for (name,text,_,groups),keys in zip(findings,evidence_keys):
        paragraph(name+': '+text+' '+ref(*keys))

def trace_report():
    heading('7 Ma trận truy vết yêu cầu')
    paragraph('Requirements_Traceability_Matrix.tsv là ma trận đầy đủ 405 endpoint: mã R, HTTP/path, controller.method, file/dòng, role/permission metadata, DTO và lời gọi service có thể phân giải, UC hoặc tiến trình hỗ trợ. Đây là bằng chứng cấu trúc; các service gọi tiếp, scope interceptor và UI vẫn cần đọc để xác nhận hành vi. Ký hiệu LOCAL không bị gán API giả.')
    paragraph('Số 405 chỉ đếm route khai báo bằng HTTP decorator trong controller. Handler middleware /uploads và Swagger /docs có điều kiện cấu hình trong app.bootstrap.ts không nằm trong số đếm này. Không suy 405 là toàn bộ bề mặt HTTP của mọi cấu hình triển khai. '+ref('bootstrap'))
    paragraph('Xuất PDF cục bộ: LOCAL.leasePdf '+ref('leasePdf')+'; LOCAL.invoicePdf '+ref('invoicePdf')+'. Hai hàm nằm phía Flutter; dữ liệu đầu vào phải lấy qua UC xem đối tượng đã được kiểm quyền, không tạo chữ ký số qua việc dựng PDF.')
    table(['Nguồn','File và dòng','Hàm hoặc thành phần'],[(s['id'],s['file']+':'+str(s['line']),s['label']) for s in SOURCES.values()],[1.1,9.4,5.4])
    heading('7.1 Độ phủ truy vết theo nhóm',2)
    table(['Nhóm','UC','Độ sâu đã xác nhận'],[(g+' '+GROUPS[g],str(sum(c['group']==g for c in cases())), 'Frontend → API → service → DTO → schema; test được ghi theo phạm vi.' if g=='SYS' else 'API → lời gọi service đã kiểm kê; chưa đủ đối chiếu A–J/UI/test cho từng UC.') for g in GROUPS],[4.7,1.0,10.2])
    paragraph('Không đặt trạng thái “xác nhận toàn bộ” cho 155 UC còn lại chỉ vì có endpoint. Việc kiểm kê đủ 405 route kiểm soát bỏ sót đầu vào kỹ thuật; không chứng minh không còn chức năng local-only ngoài hai xuất PDF đã ghi nhận.')
    heading('7.2 Đối chiếu mã Use Case cũ và mới',2)
    old=json.loads((ROOT/'docs/report_2026-10-28_v3/audit.json').read_text())['cases']
    newids={c['id'] for c in cases()}
    rows=[]
    for c in old:
        code=c['id']
        targets=CROSSWALK.get(code,[code] if code in newids else [])
        if not targets:raise ValueError('Old UC unmapped '+code)
        rows.append((code,c['title'],', '.join(targets),'Giữ mã; nội dung được rà soát lại, không bảo lưu kết luận cũ.' if targets==[code] else 'Tách mục tiêu hoặc phân loại lại tiến trình; không làm mất chức năng.'))
    table(['Mã cũ','Tên trong báo cáo cũ','Mã đối chiếu mới','Cách xử lý'],rows,[2.1,5.3,3.8,4.7])
    paragraph('UC mới đáng chú ý: UC-SYS-09 nhận lời mời STAFF. Các trường hợp split được ghi từng dòng thay vì đánh lại toàn bộ mã, nhằm giữ khả năng so sánh với báo cáo và sơ đồ cũ. 164 là số catalog mới, không phải số đặc tả A–J đã hoàn tất.')

def gaps_report():
    heading('8 Điểm chưa rõ khác biệt và kiểm thử')
    table(['Mã','Thực trạng hoặc điểm chưa xác định','Tác động và hướng xử lý'],[
        ('GAP-01','155 UC ngoài SYS chưa hoàn tất A–J; catalog mới chỉ có wiring và ranh giới đọc ở service.','Không nghiệm thu toàn hệ thống từ đợt 1. Đặc tả tiếp theo nhóm, bắt đầu tài sản/hợp đồng và tài chính.'),
        ('GAP-02','Không có bộ yêu cầu chuẩn hoặc chính sách nghiệp vụ được phê duyệt độc lập.','Chỉ kết luận khác biệt so với báo cáo cũ, không tuyên bố code vi phạm yêu cầu khách hàng chưa được cung cấp.'),
        ('GAP-03','Không đọc DB runtime, secrets hoặc xác nhận migrations production.','Không bịa volume, dữ liệu thật, trạng thái triển khai, CORS thực, provider credentials hoặc SLA vận hành.'),
        ('GAP-04','STAFF decorator và interceptor có giao khác nhau; một số quyền mang tên có nhưng controller không được phép.','Báo cáo cũ không được mô tả đầy đủ quyền STAFF chỉ theo annotation. Xác nhận kỳ vọng người sở hữu nghiệp vụ trước khi sửa code.'),
        ('GAP-05','Register tạo User trước issueSession; accept invite commit trước issueSession.','Không viết bảo đảm thất bại luôn giữ nguyên dữ liệu. Xác định quy trình xử lý tài khoản đã tạo nhưng client chưa nhận phiên.'),
        ('GAP-06','Đặt lại mật khẩu có thể đã commit rồi UI báo lỗi do logout; UI không phân biệt lỗi hậu commit.','Đây là khác biệt hiển thị/trạng thái, không được mô tả rằng mật khẩu chưa đổi mỗi khi UI báo lỗi.'),
        ('GAP-07','Checkbox ghi nhớ và đồng ý điều khoản chưa có bằng chứng điều khiển TTL hoặc lưu chấp thuận backend.','Không thêm chính sách thời hạn theo checkbox hay bằng chứng pháp lý đã đồng ý.'),
        ('GAP-08','Thanh toán thẻ là demo; kênh gửi mail/storage/worker cần cấu hình.','Không nói đã tích hợp ngân hàng hoặc đã gửi thư khi chỉ có job; cần kiểm tra môi trường và nhà cung cấp riêng.'),
        ('GAP-09','Báo cáo cũ dùng nhánh thay thế/ngoại lệ chung và API mapping theo gợi ý tên; chưa đủ chứng cứ từng bước.','Thay riêng nhóm SYS; catalog mới route AST chính xác. Không tái gắn nhãn verified cho các bảng cũ.'),
        ('GAP-10','Không thấy tự merge seeker vào Tenant khi accept email đã tồn tại.','Email trùng trả conflict; không viết luồng tự hợp nhất. Nếu cần merge, đó là TO-BE riêng.'),
        ('GAP-11','Danh sách phiên API mọi vai trò; UI quản lý phiên được xác nhận tại Admin.','Không dựng thao tác trên màn hình landlord/tenant/staff chưa có bằng chứng.'),
        ('GAP-12','RegisterDto fullName IsNotEmpty kiểm tra trước trim; email register không có max như forgot.','Ghi ràng buộc endpoint cụ thể; không áp đồng loạt nonblank/max254 từ biểu mẫu khác.'),
    ],[1.5,7.3,7.1])
    heading('8.1 Bằng chứng kiểm thử đã thực thi',2)
    table(['Lệnh và phạm vi','Kết quả','Giới hạn chứng minh'],[
        ('npm test -- --runInBand: auth.service, jwt.strategy, account-access.service, admin-mfa.service, roles.guard, property-scope, tenant-invites.service','7 suites; 31 tests pass','Unit/mock tests; tenant-invites suite không tự chứng minh accept E2E, account-access suite tập trung rate-limit gửi.'),
        ('flutter test --reporter expanded test/features/auth test/data/auth test/core/network/api_client_test.dart','48 tests pass','Có đăng ký hai loại tài khoản, validation, duplicate/rate-limit/network, recovery UI, refresh/session isolation. Không phải thiết bị thật hay backend thật.'),
        ('Hash vùng liên quan auth/common/tenants/staff và UI/data/network/tests','Trùng manifest tại thời điểm kiểm tra','Không suy các module ngoài vùng này đã được chạy với cùng độ phủ.'),
        ('backend/test/e2e/app-functional.e2e-spec.ts và các E2E khác','Có source; chưa chạy','Có kịch bản nhận lời mời Tenant/STAFF đồng thời và hết hạn. Không kết luận transaction/lock/concurrency đã được xác minh bằng DB thực từ lần chạy unit này.'),
    ],[7.1,2.5,6.3])
    paragraph('Log nguyên trạng: evidence/auth-backend-tests.log và evidence/auth-flutter-tests.log. Các số chạy toàn bộ hệ thống ở đợt trước không dùng làm bằng chứng cho snapshot hiện tại. Acceptance scenarios mục J phải được thực thi độc lập để có kết luận nghiệm thu; báo cáo này không thay thế biên bản test.')
    heading('8.2 Đề xuất cải tiến tách khỏi AS IS',2)
    paragraph('Các mục sau chỉ là đề xuất, chưa phải hành vi hiện có: làm rõ trạng thái tạo tài khoản thành công nhưng cấp phiên thất bại; thông báo UI phân biệt redeem thành công và logout lỗi; quyết định chính sách merge seeker–Tenant; thống nhất ý định cấp quyền STAFF với interceptor; xác định có cần lưu chấp thuận điều khoản và ý nghĩa ghi nhớ đăng nhập. Không sửa code ứng dụng trong đợt tài liệu này.')
    heading('8.3 Thứ tự hoàn thiện các đợt tiếp theo',2)
    table(['Ưu tiên','Nhóm','Đầu ra bắt buộc trước khi đánh dấu hoàn tất'],[
        ('1','OPT và TNT','Đối chiếu UI–API–service–schema; lease/deposit/settlement/turnover/lifecycle theo trạng thái và transaction; A–J từng UC.'),
        ('2','BIL và TEN','Hóa đơn, cash receipt/allocation/payment/proof/reversal/refund/demo; ma trận biến động số dư và lỗi hậu commit.'),
        ('3','DIS','Tin, lịch xem, review, moderation và appeal; version/capacity/scope; cập nhật quan hệ và sơ đồ UC.'),
        ('4','OPS, STF, ADM và SUP','Ma trận permission hiệu lực đến action, worker/config-dependent behavior; A–J, BR và test scenarios riêng từng mục tiêu.'),
    ],[1.3,3.5,11.1])

def build_content():
    register_sources()
    system_report(); actor_report(); decomposition_report(); auth_report()
    support_report(); rules_report(); trace_report(); gaps_report()
    return BLOCKS
