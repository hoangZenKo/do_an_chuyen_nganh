# Actor Catalog và phân quyền AS-IS

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Biên hệ thống

Biên gồm Flutter, NestJS, Prisma/PostgreSQL và worker/CLI trong repository. Database, scheduler, outbox, audit logger và hệ thống không là Actor ngoài. Provider/model/scanner/storage là tác nhân phối hợp có điều kiện, chưa xác nhận production.

## 2. Actor chính

| Mã | Actor | Ánh xạ | Mục tiêu và phạm vi | Bằng chứng |
| --- | --- | --- | --- | --- |
| A01 | Khách/chưa đăng nhập | Không có UserRole Guest | Tìm tin công khai; đăng ký/đăng nhập; kích hoạt/reset bằng token. Người nhận lời mời là ngữ cảnh của A01. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:1` |
| A02 | Chủ trọ | LANDLORD | Quản lý dữ liệu thuộc mình; cấp quyền giới hạn cho STAFF; không có quyền quản trị nền tảng. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/current-user.decorator.ts:1` |
| A03 | Nhân viên vận hành | STAFF + StaffProfile | Permission, propertyIds, whitelist controller và service phải cùng cho phép. | `/Users/hoang/Rental_room_management/backend/src/auth/jwt.strategy.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| A04 | Người tìm phòng/người thuê | Cùng role TENANT | Tìm phòng có thể chưa có Tenant/Lease. Cổng thuê cần dữ liệu liên kết. Occupant không mặc định có tài khoản. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:1`; `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:1` |
| A05 | Quản trị viên nền tảng | ADMIN + AdminProfile | Capability theo thao tác, MFA/step-up và điều kiện người thực hiện; không thừa hưởng API LANDLORD. | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:1` |

### 2.1. Ngữ cảnh và nhiều trách nhiệm

- Một User có một trường role; không thấy cơ chế một tài khoản đồng thời nhiều UserRole hay tự đổi role. Một người có thể nhiều trách nhiệm nhưng không suy quyền union giữa các role.
- C-TIM: A04 tìm phòng; C-O: A04 có hồ sơ/lease để dùng cổng thuê. Đây là ngữ cảnh dữ liệu, không role mới hoặc quan hệ kế thừa quyền.
- Nhân sự hỗ trợ, kiểm duyệt, maker/checker là trách nhiệm của A05, không tạo role SUPPORT/MODERATOR. Tách người quyết định khi code cấm tự duyệt.
- Admin preset super_admin, support, moderator, analyst và Staff preset operator, accountant, maintenance, viewer, custom là gói permission, không Actor/role đăng nhập mới. Nguồn: `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1`; `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:1`.
- Người đăng ký TENANT không tự có Tenant/Lease. Tenant record/occupant không tự có User; cấp tài khoản trực tiếp và lời mời có luồng riêng.

### 2.2. Chuỗi xác định quyền

1. JWT, session, user còn hiệu lực; STAFF profile/chủ trọ liên quan hoạt động.
2. Role được handler cho phép, hoặc kiểm role riêng trong controller.
3. STAFF: ANY (some) của permission yêu cầu; ADMIN: ALL capability khai báo và metadata không rỗng. Metadata handler override class.
4. STAFF qua interceptor whitelist controller và propertyIds.
5. Service kiểm sở hữu, Tenant/Lease, trạng thái, version, quota/feature flag và độc lập người xét. Nhạy cảm quản trị có thể cần step-up một lần trong 5 phút gắn session/method/path/body.

Nguồn: `/Users/hoang/Rental_room_management/backend/src/auth/jwt.strategy.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36`; `/Users/hoang/Rental_room_management/backend/src/common/admin-access.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.service.ts:1`.

## 3. Tác nhân phối hợp

| Mã | Tác nhân | UC phối hợp | Xác nhận | Bằng chứng |
| --- | --- | --- | --- | --- |
| E01 | Dịch vụ giao liên kết/thông báo bên ngoài | UC-SYS-06, UC-BIL-18.2, UC-SUP-05.2, UC-ADM-03.1, UC-ADM-05.2, UC-ADM-06.1 | Có điều kiện; adapter/code có thật, chưa xác nhận provider runtime | `/Users/hoang/Rental_room_management/backend/src/delivery/delivery.service.ts:1`<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:1`<br>`/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.service.ts:1` |
| E02 | Nhà cung cấp Zalo ZNS | UC-BIL-18.2 | Có điều kiện; adapter/code có thật, chưa xác nhận provider runtime | `/Users/hoang/Rental_room_management/backend/src/notifications/zalo-zns.service.ts:1` |
| E03 | Dịch vụ quét tệp hỗ trợ | UC-SUP-01, UC-SUP-01.1 | Có điều kiện; adapter/code có thật, chưa xác nhận provider runtime | `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.service.ts:1`<br>`/Users/hoang/Rental_room_management/backend/src/uploads/malware-scanner.service.ts:1` |
| E04 | Dịch vụ mô hình AI | UC-SUP-06 | Có điều kiện; adapter/code có thật, chưa xác nhận provider runtime | `/Users/hoang/Rental_room_management/backend/src/chatbot/ollama.client.ts:1` |
| E05 | Kho lưu kết quả báo cáo ngoài hệ thống | UC-ADM-16 | Tùy cấu hình; adapter/code có thật, chưa xác nhận provider runtime | `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:1` |

E05 chỉ khi dùng object storage; local filesystem không là Actor ngoài. Không tạo Actor ngân hàng thật từ DEMO_CARD hay enum legacy. Demo checkout là phần trong biên, người giữ token là ngữ cảnh người dùng của biến thể. Tạo lời mời tenant/staff trả link theo cơ chế hiện có; không tự gán kênh email ngoài khi chưa có đường gọi.

## 4. Staff Permission Catalog

Permission tồn tại không tự chứng minh sử dụng được. Danh sách UC là nơi có handler được phép; quyền áp theo thao tác, không AND tất cả quyền trong UC.

| Permission | UC/điều kiện | Bằng chứng |
| --- | --- | --- |
| property.view | UC-OPT-02 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| property.manage | UC-OPT-03.2, UC-OPT-04.1, UC-OPT-04.3 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| room.view | UC-OPT-05, UC-OPT-08.1, UC-OPT-08.2, UC-OPT-09 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| room.manage | UC-OPT-06.1, UC-OPT-06.2, UC-OPT-07.1, UC-OPT-07.2, UC-OPT-07.3, UC-OPT-08.1, UC-OPT-08.2 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| tenant.view | UC-TNT-01 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| tenant.manage | UC-TNT-02.1, UC-TNT-02.2, UC-TNT-02.3, UC-TNT-02.4, UC-TNT-03.1 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| lease.view | UC-TNT-04, UC-TNT-07, UC-TNT-12.1, UC-TNT-10 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| lease.manage | UC-TNT-05, UC-TNT-06.1, UC-TNT-06.2, UC-TNT-06.3, UC-TNT-07, UC-TNT-12.1, UC-TNT-10, UC-TNT-11 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.view | UC-BIL-01, UC-BIL-02, UC-BIL-04, UC-BIL-10, UC-BIL-14, UC-BIL-15, UC-BIL-16, UC-BIL-17.1 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.create | UC-BIL-01, UC-BIL-02, UC-BIL-03, UC-BIL-05, UC-BIL-15, UC-BIL-17.1, UC-BIL-17.2 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.record_payment | UC-BIL-09, UC-BIL-10, UC-BIL-11 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.cancel | UC-BIL-08.1 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.reverse_payment | UC-BIL-12.1, UC-BIL-12.2 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.approve_payment_proof | UC-BIL-14 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.adjust | UC-BIL-06, UC-BIL-07 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.refund | UC-BIL-13 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.policy | UC-BIL-18.1, UC-BIL-18.2 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| billing.tariff_approve | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| expense.view | UC-BIL-19 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| expense.manage | UC-BIL-19 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| maintenance.view | UC-OPS-01 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| maintenance.manage | UC-OPS-01, UC-OPS-02 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| maintenance.complete | UC-OPS-03 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| report.view | UC-BIL-20, UC-OPT-01 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| report.export | UC-BIL-20 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| staff.view | UC-STF-01, UC-STF-04 | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| staff.manage | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| audit.view | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| notification.view | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| notification.manage | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| operation.view | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |
| operation.manage | Không có đường STAFF thực thi được xác minh; không cấp từ enum. | `/Users/hoang/Rental_room_management/backend/src/common/permissions.constants.ts:1`; `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36` |

## 5. Admin Permission Catalog

Áp theo handler và service; ví dụ xử lý ticket còn cần support.manage, invite còn kiểm role đích/MFA. Không coi tổng quyền một hàng UC là bộ bắt buộc cho mọi thao tác.

| Capability | UC có handler sử dụng | Bằng chứng |
| --- | --- | --- |
| admin.dashboard.view | UC-DIS-13.2, UC-ADM-01, UC-ADM-03.1, UC-ADM-06.1, UC-ADM-10, UC-ADM-11, UC-ADM-13.2, UC-DIS-15, UC-SUP-01, UC-SUP-03.2.2, UC-ADM-17.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.accounts.view | UC-ADM-02 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.accounts.manage | UC-ADM-02, UC-ADM-03.1, UC-ADM-03.2, UC-ADM-05.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.accounts.suspend | UC-ADM-04.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.sessions.revoke | UC-ADM-04.3 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.properties.view | UC-ADM-08, UC-ADM-19 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.properties.manage | UC-ADM-09, UC-ADM-19 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.support.read | UC-SUP-01, UC-SUP-01.1, UC-SUP-02.1, UC-SUP-02.2, UC-SUP-03.2, UC-SUP-03.2.1, UC-SUP-03.3, UC-ADM-18, UC-ADM-18.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.pii.reveal | UC-ADM-05.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.listings.moderate | UC-ADM-11, UC-ADM-11.1, UC-ADM-12.1, UC-ADM-27 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.reviews.moderate | UC-ADM-12 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.audit.view | UC-ADM-14 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.campuses.manage | UC-ADM-23 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.admins.manage | UC-ADM-04.3, UC-ADM-06.1, UC-ADM-06.2, UC-ADM-13.1, UC-SUP-02.1, UC-SUP-02.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.operations.view | UC-SUP-05.1, UC-SUP-05.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.operations.manage | UC-SUP-05.1, UC-SUP-05.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.audit.export | UC-ADM-14 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.support.manage | UC-SUP-01, UC-SUP-01.1, UC-SUP-02.1, UC-SUP-02.2, UC-SUP-03.2, UC-SUP-03.2.1, UC-SUP-03.3 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.notifications.view | UC-SUP-04 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.moderation.appeals | UC-ADM-13.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.moderation.bulk | UC-ADM-11 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.moderation.reports | UC-ADM-13.1, UC-ADM-13.2, UC-ADM-13.3 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.flags.manage | UC-ADM-17.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.teams.manage | UC-ADM-17.2 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.permissions.simulate | UC-ADM-26 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.finance.read | UC-ADM-15, UC-ADM-15.1, UC-ADM-24 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.finance.reconcile | UC-ADM-15, UC-ADM-15.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.reports.manage | UC-ADM-16 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.verifications.view | UC-ADM-18 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.verifications.manage | UC-ADM-18, UC-ADM-18.1 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.plans.view | UC-ADM-20, UC-ADM-21 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |
| admin.plans.manage | UC-ADM-20, UC-ADM-21, UC-ADM-22 | `/Users/hoang/Rental_room_management/backend/src/common/admin-permissions.ts:1` |

## 6. Hạn chế quyền phải bảo toàn

| Trường hợp | Kết luận AS-IS |
| --- | --- |
| staff.manage | STAFF chỉ list/presets, không mời/sửa vì interceptor. |
| Cấp tài khoản tenant / mời tenant | STAFF tenant.manage được tạo trực tiếp qua TenantsController; lời mời TenantInvitesController bị chặn. |
| Phí phòng / biểu phí / khóa kỳ | STAFF đọc room.view/billing.view; ghi phí, duyệt biểu phí và khóa kỳ chỉ LANDLORD. |
| Dashboard | STAFF cần report.view; room.view không đủ. |
| Automation / reminder | Automation đọc billing.view, ghi/preview/run billing.create. Reminder billing.policy và propertyId được giao. |
| Ngoài whitelist | Operations, notifications, audit, support, uploads… chặn STAFF dù decorator có role/quyền; escalate bảo trì và billing outbox/retry cũng chặn riêng. |
| Tenant qua nhiều khu | Scope yêu cầu mọi lease/invoice trong phạm vi, không chỉ một lease khớp. |
| Accounts / legacy landlords | Console đọc accounts.view; /admin/landlords cũ cần accounts.manage. |
| Admin / landlord | super_admin không bỏ qua giới hạn role của API nghiệp vụ chủ trọ. |
| MFA controller | Thiếu @Roles không có nghĩa công khai: JWT và role/profile được kiểm trong AdminSecurityController. |

Nguồn cho các kết luận: `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36`; `/Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:1`.
