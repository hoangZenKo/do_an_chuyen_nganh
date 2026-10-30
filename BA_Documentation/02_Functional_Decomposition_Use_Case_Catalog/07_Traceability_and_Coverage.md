# Truy vết triển khai và kiểm tra độ phủ

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Cách đọc bằng chứng

Bằng chứng hành vi là controller đã nối service và phần xử lý được đọc, hoặc logic Flutter thuần cục bộ. DTO/schema cho cấu trúc và ràng buộc, không tự chứng minh nghiệp vụ đầy đủ. UI/repository/test dưới đây là **nguồn liên quan đã đối chiếu**, không phải khẳng định từng màn hình/test bao phủ trọn UC. Không có kết quả chạy test mới trong đợt tài liệu này; E2E có reset DB nên không thực thi.

Từng handler ghi role, quyền STAFF/ADMIN và rào chắn interceptor. Hành vi chung còn cần điều kiện sở hữu/trạng thái trong service. Các nhóm DTO/model được dùng để định vị tiếp, không ngụ ý mọi trường của model đều được UC sửa. Số endpoint duy nhất: 405, trong đó 395 nối UC, 10 cơ chế kỹ thuật. Một endpoint có thể dùng cho nhiều mục tiêu có điều kiện, nên không cộng tổng route từng UC để suy tổng endpoint.

## 2. Truy vết từng UC

### UC-ADM-07.1 — Thiết lập MFA Admin

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạo và xác nhận cấu hình MFA với mã khôi phục
- Ranh giới: AdminSecurityController dùng JWT trực tiếp cho bước thiết lập MFA; không gán capability giả cho endpoint này. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/me/security | `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:25` (AdminSecurityController.status) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/admin/me/security/enroll | `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:30` (AdminSecurityController.enroll) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/admin/me/security/confirm | `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:32` (AdminSecurityController.confirm) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:29` (AdminMfaService.required); `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:52` (AdminMfaService.enroll); `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:66` (AdminMfaService.verify).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1902` (AdminStepUpGrant).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_security_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.spec.ts:1`.
- Mục khảo sát liên quan: F-142.

### UC-SYS-01 — Đăng ký tài khoản chủ trọ

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thiết lập tài khoản chủ trọ để bắt đầu quản lý nhà trọ; nhận phiên theo kết quả đăng ký.
- Ranh giới: Tạo User và cấp phiên là hai đơn vị ghi khác nhau; lỗi cấp phiên sau khi tạo có thể để lại User.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/register | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:18` (AuthController.register) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:37` (AuthService.register).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/dto/register.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-001.

### UC-SYS-02 — Đăng ký tài khoản tìm phòng

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thiết lập tài khoản tìm phòng để lưu nhu cầu và đặt lịch; chưa mặc nhiên có hồ sơ thuê hoặc hợp đồng.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/register-seeker | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:25` (AuthController.registerSeeker) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:41` (AuthService.registerSeeker).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/dto/register.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-002.

### UC-SYS-03 — Đăng nhập

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Nhận phiên đúng danh tính và điều hướng theo vai trò
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/login | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:32` (AuthController.login) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:71` (AuthService.login).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/dto/login.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-003.

### UC-SYS-05.1 — Đăng xuất phiên hiện tại

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thu hồi phiên gắn refresh token và rời phiên cục bộ
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/logout | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:44` (AuthController.logout) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:137` (AuthService.logout).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/dto/refresh.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-005.

### UC-SYS-05.2 — Xem và thu hồi các phiên của mình

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kiểm soát thiết bị đang truy cập tài khoản
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/auth/sessions | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:59` (AuthController.sessions) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/auth/sessions/:id/revoke | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:66` (AuthController.revokeSession) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/auth/sessions/revoke-all | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:73` (AuthController.revokeOtherSessions) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:212` (AuthService.sessions); `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:232` (AuthService.revokeSession); `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:244` (AuthService.revokeOtherSessions).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1902` (AdminStepUpGrant).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_sessions_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_security_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.spec.ts:1`.
- Mục khảo sát liên quan: F-144.

### UC-SYS-06 — Khôi phục mật khẩu bằng liên kết một lần

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Một phần.
- Mục tiêu: Đặt lại mật khẩu qua token giao nhận riêng
- Ranh giới: Đã có token, thu hồi phiên và job giao link; chưa kiểm chứng email/provider thật.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/account-access/forgot | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:19` (AccountAccessController.forgot) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/auth/account-access/redeem | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:20` (AccountAccessController.redeem) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:47` (AccountAccessService.forgot); `/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:54` (AccountAccessService.redeem).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:7`; `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:8`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/account_access_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-006.

### UC-SYS-07 — Đổi mật khẩu khi đang đăng nhập

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thay mật khẩu sau khi xác minh mật khẩu hiện tại
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/change-password | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:80` (AuthController.changePassword) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:159` (AuthService.changePassword).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/dto/change-password.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-005.

### UC-SYS-08 — Kích hoạt tài khoản người thuê từ lời mời

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Nhận quyền vào cổng người thuê, gắn đúng hồ sơ đã được chủ trọ mời.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenant-invites/accept | `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.controller.ts:45` (TenantInvitesController.accept) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.service.ts:97` (TenantInvitesService.accept).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/accept-tenant-invite.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-027.

### UC-SYS-09 — Kích hoạt tài khoản nhân viên từ lời mời

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Nhận tài khoản nhân viên với quyền và khu trọ đã được chủ trọ cấp qua lời mời.
- Ranh giới: Bổ sung vì bản V3 chưa tách mục tiêu kích hoạt STAFF.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/staff/invites/accept | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:96` (StaffController.accept) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:104` (StaffService.accept).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/staff/dto/accept-staff-invite.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:311` (StaffInvite); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:331` (StaffPropertyScope).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/staff/staff_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-008.

### UC-SYS-10 — Thiết lập mật khẩu tài khoản được mời

- Nhóm: G01 — Tài khoản và an toàn truy cập. Actor chính: Khách/chưa đăng nhập (A01). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đặt mật khẩu bằng liên kết mời một lần rồi đăng nhập; không tự chọn vai trò hoặc cấp quyền mới.
- Ranh giới: Dùng cùng cơ chế redeem với khôi phục mật khẩu nhưng mục tiêu kích hoạt tài khoản đã được quản trị tạo. Service không phân nhánh kiểm purpose tại redeem; không thêm bảo đảm purpose không có trong code.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/auth/account-access/redeem | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:20` (AccountAccessController.redeem) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:54` (AccountAccessService.redeem).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:8`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1771` (AccountAccessToken).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/auth/account_access_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/auth.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.spec.ts:1`; `/Users/hoang/Rental_room_management/test/features/auth/auth_navigation_test.dart:1`.
- Mục khảo sát liên quan: F-006.

### UC-DIS-01 — Tìm và lọc tin phòng công khai

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Khách/chưa đăng nhập (A01); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tìm tin công khai theo bộ lọc và cơ sở trường
- Ranh giới: Tin công khai cần PUBLISHED, phòng active và VACANT, khu không archived, chủ trọ active; lọc trường học là nhánh tìm kiếm.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/public/listings | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:43` (PublicListingsController.list) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/public/campuses | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:12` (PublicCampusesController.list) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:29` (ListingsService.publicList); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:182` (ListingsService.campuses).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:11`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-086, F-093, F-087.

### UC-DIS-02 — Xem chi tiết tin và đánh giá công khai

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Khách/chưa đăng nhập (A01); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc nội dung tin còn hiển thị cùng đánh giá được duyệt
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/public/listings/:id | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:46` (PublicListingsController.detail) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/public/listings/:id/reviews | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:12` (PublicRoomReviewsController.list) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:60` (ListingsService.publicDetail); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:157` (ReviewsService.publicReviews).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:7`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:964` (RoomReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/listings/review_composer.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-086, F-109.

### UC-DIS-03 — Lưu và bỏ lưu phòng yêu thích

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì danh sách tin quan tâm của mình
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/favorites | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:43` (HousingController.favorites) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/housing/favorites/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:48` (HousingController.favorite) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/housing/favorites/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:53` (HousingController.save) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/housing/favorites/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:58` (HousingController.remove) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:31` (HousingService.favorites); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:48` (HousingService.favorite); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:54` (HousingService.saveFavorite); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:62` (HousingService.removeFavorite).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-097.

### UC-DIS-04 — Lưu bộ lọc và theo dõi tin khớp

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu tối đa 10 tìm kiếm và đọc cảnh báo kết quả mới
- Ranh giới: Không có endpoint sửa filters của tìm kiếm đã lưu; chỉ tạo bật tắt xóa và đọc cảnh báo.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/student/searches | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:12` (SavedSearchesController.list) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/student/searches | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:13` (SavedSearchesController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/student/searches/alerts | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:14` (SavedSearchesController.alerts) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/student/searches/alerts/:id/read | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:15` (SavedSearchesController.read) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/student/searches/:id | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:16` (SavedSearchesController.status) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/student/searches/:id | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:17` (SavedSearchesController.remove) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:22` (SavedSearchesService.list); `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:25` (SavedSearchesService.create); `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:54` (SavedSearchesService.alerts); `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:50` (SavedSearchesService.read); `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:37` (SavedSearchesService.status); `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:46` (SavedSearchesService.remove).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:166`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:173`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:684` (SavedSearch); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:698` (SavedSearchMatch).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/saved_searches_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-094, F-095.

### UC-DIS-16 — So sánh các phòng quan tâm

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Khách/chưa đăng nhập (A01); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: So sánh tối đa ba tin trong phiên giao diện để chọn phòng phù hợp.
- Ranh giới: Trạng thái so sánh trong Riverpod, tối đa 3 tin; không có bằng chứng lưu lâu dài ở backend.

Không có API riêng: mục tiêu được thực hiện cục bộ ở Flutter; không bịa Controller/Service/DB tương ứng.

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/lib/features/listings/listing_comparison_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/listings/listings_providers.dart:1`.
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/listing_comparison_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/listings/saved_searches_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-096.

### UC-DIS-17 — Ước tính chi phí thuê phòng

- Nhóm: G02 — Tìm và lựa chọn phòng. Actor chính: Khách/chưa đăng nhập (A01); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ước tính chi phí ở, chi phí mỗi người và chi phí vào ở từ giá niêm yết; không tạo hóa đơn.
- Ranh giới: Ước tính frontend từ tin: thuê, điện, nước, dịch vụ, gửi xe; chia người và tiền cọc vào ở. Không phải hóa đơn hay cam kết thu.

Không có API riêng: mục tiêu được thực hiện cục bộ ở Flutter; không bịa Controller/Service/DB tương ứng.

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/lib/features/listings/student_listing_widgets.dart:1`; `/Users/hoang/Rental_room_management/lib/models/student_discovery.dart:1`.
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: Không có bảng lưu riêng cho trạng thái cục bộ/ước tính.
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/student_listing_widgets.dart:1`; `/Users/hoang/Rental_room_management/lib/features/settings/settings_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/test/features/onboarding/onboarding_persistence_test.dart:1`.
- Mục khảo sát liên quan: F-176.

### UC-DIS-05 — Quản lý và gửi duyệt tin cho thuê

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chuẩn bị, cập nhật và gửi tin phòng thuộc mình để kiểm duyệt, duy trì thông tin còn phòng.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/listings | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:55` (LandlordListingsController.list) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/listings | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:60` (LandlordListingsController.create) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/listings/:id | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:65` (LandlordListingsController.update) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/listings/:id/submit | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:70` (LandlordListingsController.submit) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/listings/:id/confirm-availability | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:80` (LandlordListingsController.confirm) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:84` (ListingsService.create); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:104` (ListingsService.update); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:113` (ListingsService.submit); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:209` (ListingsService.confirmAvailability).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:59`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:116`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:126`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:121`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-088, F-089.

### UC-DIS-06.2 — Ẩn tin cho thuê của mình

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ngừng công khai tin mà không xóa lịch sử
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/listings/:id/hide | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:75` (LandlordListingsController.hide) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:124` (ListingsService.hide).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:121`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-089.

### UC-DIS-08 — Quản lý khung giờ xem phòng

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Mở hoặc gỡ khung giờ cho lịch xem tin của mình
- Ranh giới: Slot 15–120 phút, giới hạn số lịch sắp tới; TENANT chỉ đọc slot.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/listings/:id/slots | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:14` (HousingController.slots) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/housing/listings/:id/slots | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:17` (HousingController.addSlot) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/housing/slots/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:22` (HousingController.removeSlot) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:102` (HousingService.slots); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:120` (HousingService.addSlot); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:145` (HousingService.removeSlot).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:25`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-098.

### UC-DIS-09 — Đặt và quản lý lịch xem của mình

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chọn lịch hợp lệ, theo dõi, đổi hoặc hủy lịch xem do mình đặt trong các trạng thái được phép.
- Ranh giới: Đặt trước ít nhất 15 phút, không quá 90 ngày; kiểm tra trùng lịch của hai bên; reschedule là TENANT.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/housing/viewings | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:68` (HousingController.book) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/housing/viewings | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:63` (HousingController.viewings) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/housing/viewings/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:71` (HousingController.viewing) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/housing/viewings/:id/reschedule | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:25` (HousingController.reschedule) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/housing/viewings/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:74` (HousingController.update) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:83` (HousingService.book); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:67` (HousingService.viewings); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:77` (HousingService.viewing); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:158` (HousingService.reschedule); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:208` (HousingService.update).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:6`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:33`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:61`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-099, F-100.

### UC-DIS-10 — Tiếp nhận và hoàn tất lịch xem

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xác nhận, từ chối, hủy hoặc ghi hoàn tất lịch xem tại tin của mình.
- Ranh giới: LANDLORD xử lý lịch của tin mình; hoàn tất là điều kiện cho chuyển lịch thành hợp đồng.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/viewings | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:63` (HousingController.viewings) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/housing/viewings/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:71` (HousingController.viewing) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/housing/viewings/:id | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:74` (HousingController.update) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:67` (HousingService.viewings); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:77` (HousingService.viewing); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:208` (HousingService.update).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:6`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:61`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-099, F-100.

### UC-DIS-13.2 — Gửi phản hồi về thử nghiệm tìm phòng

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi PilotFeedback khi khu vực thử nghiệm được mở
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/pilot | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:92` (HousingController.pilot) | Roles(AuthRole.TENANT, AuthRole.LANDLORD, AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| POST /api/v1/housing/feedback | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:95` (HousingController.feedback) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:316` (HousingService.pilot); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:321` (HousingService.feedback).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:72`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-104.

### UC-TNT-12.2 — Lập biên bản bàn giao nhận phòng

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi nhận hiện trạng, chỉ số và hình ảnh để hai bên đối chiếu lúc nhận phòng.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/leases/:id/handover | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:30` (HousingController.handover) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/housing/leases/:id/handover | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:33` (HousingController.saveHandover) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:22` (HandoverService.get); `/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:34` (HandoverService.save).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:38`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-102.

### UC-TNT-12.3 — Xác nhận biên bản bàn giao nhận phòng

- Nhóm: G03 — Đăng tin, lịch xem và nhận phòng. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xác nhận đúng phiên bản biên bản nhận phòng của hợp đồng đã đến ngày hiệu lực.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/housing/leases/:id/handover/accept | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:38` (HousingController.acceptHandover) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:58` (HandoverService.accept).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:56`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-102.

### UC-OPT-02 — Tra cứu khu trọ

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc khu trọ theo bộ lọc lifecycle và phạm vi
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/properties | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:37` (PropertiesController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/properties/:id | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:60` (PropertiesController.getById) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:42` (PropertiesService.list); `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:56` (PropertiesService.getById).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/properties/dto/list-properties-query.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-011.

### UC-OPT-03.1 — Tạo khu trọ

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Bổ sung khu trọ mới vào danh mục kinh doanh trong hạn mức gói được áp dụng.
- Ranh giới: Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/properties | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:43` (PropertiesController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:61` (PropertiesService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/properties/dto/create-property.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-012.

### UC-OPT-03.2 — Cập nhật thông tin khu trọ

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Sửa tên và địa chỉ khu thuộc phạm vi
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/properties/:id | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:66` (PropertiesController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:76` (PropertiesService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/properties/dto/update-property.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-013.

### UC-OPT-04.1 — Lưu trữ hoặc khôi phục khu trọ

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạm ngừng hoặc đưa khu trọ trở lại vận hành, bảo toàn lịch sử và kiểm tra hợp đồng/hạn mức.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/properties/:id/status | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:87` (PropertiesController.updateStatus) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:89` (PropertiesService.updateStatus); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/properties/dto/update-property-status.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-014.

### UC-OPT-04.3 — Xóa khu trọ đủ điều kiện

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xóa vật lý khi các ràng buộc phụ thuộc cho phép
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| DELETE /api/v1/properties/:id | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:108` (PropertiesController.remove) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: property.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:116` (PropertiesService.remove); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-015.

### UC-OPT-05 — Tra cứu phòng và lịch sử liên quan

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu thông tin phòng và lịch sử liên quan trong khu trọ được phép quản lý.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/properties/:propertyId/rooms | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:44` (PropertyRoomsController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/rooms/:id | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:85` (RoomsController.getById) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:92` (RoomsService.listByProperty); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:110` (RoomsService.getById).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/list-rooms-query.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-016.

### UC-OPT-06.1 — Tạo phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Bổ sung phòng có thể vận hành trong khu đang hoạt động, trong hạn mức được áp dụng.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/properties/:propertyId/rooms | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:54` (PropertyRoomsController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:115` (RoomsService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/create-room.dto.ts:17`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-017.

### UC-OPT-06.2 — Cập nhật thông tin phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cập nhật thông tin phòng mà không tự ghi đè giá của hợp đồng đã lập.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/rooms/:id | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:91` (RoomsController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:141` (RoomsService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room.dto.ts:16`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-017.

### UC-OPT-07.1 — Đổi trạng thái sử dụng phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cập nhật trạng thái sử dụng phòng phù hợp hợp đồng và quy trình chuẩn bị lại phòng.
- Ranh giới: Không được mô tả chuyển trạng thái phòng tùy ý: lease ACTIVE, isActive và turnover ràng buộc trạng thái. Cùng PATCH với sửa phòng nhưng mục tiêu đổi trạng thái được giữ riêng; không có endpoint status nghiệp vụ riêng. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/rooms/:id | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:91` (RoomsController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:141` (RoomsService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room.dto.ts:16`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-017.

### UC-OPT-07.2 — Vô hiệu hóa hoặc khôi phục phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạm ngừng hoặc tái sử dụng phòng mà vẫn bảo toàn lịch sử nghiệp vụ.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/rooms/:id/status | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:112` (RoomsController.updateStatus) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:166` (RoomsService.updateStatus); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room-status.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-018.

### UC-OPT-07.3 — Xóa phòng đủ điều kiện

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xóa phòng sau kiểm tra hợp đồng chỉ số hóa đơn lịch xem turnover
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| DELETE /api/v1/rooms/:id | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:133` (RoomsController.remove) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:190` (RoomsService.remove); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-019.

### UC-OPT-08.1 — Quản lý tài sản phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì danh mục, số lượng và tình trạng tài sản gắn với phòng.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/rooms/:id/assets | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:152` (RoomsController.assets) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/rooms/:id/assets | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:158` (RoomsController.createAsset) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/rooms/:id/assets/:assetId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:179` (RoomsController.updateAsset) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/rooms/:id/assets/:assetId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:201` (RoomsController.removeAsset) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:203` (RoomsService.assets); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:212` (RoomsService.createAsset); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:233` (RoomsService.updateAsset); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:262` (RoomsService.removeAsset).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/create-room-asset.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room-asset.dto.ts:11`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-020.

### UC-OPT-08.2 — Theo dõi lịch kiểm tra phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lập kế hoạch, ghi kết quả và hoàn tất kiểm tra hiện trạng phòng.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/rooms/:id/inspections | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:222` (RoomsController.inspections) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/rooms/:id/inspections | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:228` (RoomsController.createInspection) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/rooms/:id/inspections/:inspectionId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:249` (RoomsController.updateInspection) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/rooms/:id/inspections/:inspectionId/complete | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:276` (RoomsController.completeInspection) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/rooms/:id/inspections/:inspectionId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:301` (RoomsController.removeInspection) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:268` (RoomsService.inspections); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:277` (RoomsService.createInspection); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:294` (RoomsService.updateInspection); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:316` (RoomsService.completeInspection); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:330` (RoomsService.removeInspection).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/create-room-inspection.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room-inspection.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-021.

### UC-OPT-09 — Quản lý phiên bản phí dịch vụ phòng

- Nhóm: G04 — Khu trọ và cơ sở vật chất. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thiết lập phí dịch vụ theo kỳ hiệu lực và tra cứu lịch sử phiên bản; nhân viên không được ghi phí.
- Ranh giới: Đọc service fees/tariff versions: STAFF room.view + scope. Tạo/sửa/xóa phí: chỉ LANDLORD. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/rooms/:id/service-fees | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:322` (RoomsController.serviceFees) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/rooms/:id/service-fees | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:328` (RoomsController.createServiceFee) | Roles(AuthRole.LANDLORD) | STAFF: room.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/rooms/:id/service-fees/:feeId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:350` (RoomsController.updateServiceFee) | Roles(AuthRole.LANDLORD) | STAFF: room.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/rooms/:id/service-fees/:feeId/versions | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:373` (RoomsController.tariffVersions) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/rooms/:id/service-fees/:feeId | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:379` (RoomsController.removeServiceFee) | Roles(AuthRole.LANDLORD) | STAFF: room.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:340` (RoomsService.serviceFees); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:350` (RoomsService.createServiceFee); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:373` (RoomsService.updateServiceFee); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:421` (RoomsService.serviceFeeVersions); `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:417` (RoomsService.removeServiceFee).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/rooms/dto/create-room-service-fee.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/rooms/dto/update-room-service-fee.dto.ts:13`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728` (RoomAsset); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745` (RoomInspection); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761` (RoomServiceFee); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/rooms/service-tariff.spec.ts:1`.
- Mục khảo sát liên quan: F-022.

### UC-STF-01 — Mời nhân viên và cấp phạm vi khu trọ

- Nhóm: G05 — Nhân sự và ủy quyền vận hành. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạo lời mời với tập quyền và propertyIds thuộc mình
- Ranh giới: LANDLORD tạo lời mời và nhận inviteCode/activationPath để chia sẻ; code không gửi email. STAFF chỉ list/presets, không được tạo invite. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/staff/presets | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:25` (StaffController.presets) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/staff | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:32` (StaffController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/staff/invites | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:39` (StaffController.createInvite) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:200` (StaffService.presets); `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:54` (StaffService.list); `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:64` (StaffService.createInvite); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/staff/dto/create-staff-invite.dto.ts:15`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:311` (StaffInvite); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:331` (StaffPropertyScope).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/staff/staff_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-007, F-008.

### UC-STF-02 — Cập nhật quyền trạng thái và phạm vi nhân viên

- Nhóm: G05 — Nhân sự và ủy quyền vận hành. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đổi quyền preset khu được cấp và trạng thái nhân viên
- Ranh giới: Dù decorator có STAFF và staff.manage, interceptor không cho STAFF tự cập nhật quyền. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/staff/:id | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:64` (StaffController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:161` (StaffService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/staff/dto/update-staff.dto.ts:15`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:311` (StaffInvite); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:331` (StaffPropertyScope).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/staff/staff_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-009.

### UC-STF-03 — Mô phỏng quyền nhân viên

- Nhóm: G05 — Nhân sự và ủy quyền vận hành. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kiểm tra quyền hiệu lực mà không đổi cấp quyền
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/staff/:id/simulate | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:90` (StaffController.simulate) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:211` (StaffService.simulate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/staff/dto/simulate-staff-permission.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:311` (StaffInvite); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:331` (StaffPropertyScope).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/staff/staff_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-010.

### UC-STF-04 — Tra cứu nhân viên và phạm vi được cấp

- Nhóm: G05 — Nhân sự và ủy quyền vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc danh sách nhân viên/preset trong phạm vi được cấp mà không tạo lời mời hoặc thay quyền.
- Ranh giới: STAFF được phép hai handler list/presets; service lọc nhân viên theo propertyScopes giao với khu được cấp. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/staff | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:32` (StaffController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/staff/presets | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:25` (StaffController.presets) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: staff.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:54` (StaffService.list); `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:200` (StaffService.presets).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:311` (StaffInvite); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:331` (StaffPropertyScope).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/staff/staff_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-007.

### UC-TEN-01 — Xem hồ sơ và tổng quan thuê của mình

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu hồ sơ và tổng quan quan hệ thuê gắn với tài khoản của mình.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/me | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:17` (TenantPortalController.me) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/dashboard | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:22` (TenantPortalController.dashboard) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:91` (TenantPortalService.me); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:96` (TenantPortalService.dashboard).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-074.

### UC-TEN-02 — Tra cứu hợp đồng và quyết toán của mình

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu hợp đồng, cọc và quyết toán thuộc mình mà không sửa điều khoản.
- Ranh giới: Chưa thấy UI cổng TENANT nối shareLeasePdf; chỉ xác minh đọc hợp đồng/quyết toán, không cấp quyền xuất hợp đồng PDF từ việc dùng chung model. TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/leases | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:32` (TenantPortalController.leases) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/leases/:leaseId/settlement | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:27` (TenantLifecyclePortalController.settlement) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:181` (TenantPortalService.leases); `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:44` (LeaseSettlementsService.getForTenant).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1051` (LeaseSettlement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1089` (LeaseSettlementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/lease_settlement_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1`; `/Users/hoang/Rental_room_management/lib/features/reports/reports_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-036, F-074, F-119.

### UC-TEN-08.1 — Xem người ở cùng hợp đồng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc occupants nhưng không tự thêm hoặc xóa
- Ranh giới: Người thuê chỉ xem người ở cùng; không tự thêm/xóa occupant. TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/occupants | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:30` (TenantLifecyclePortalController.occupants) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205` (TenantLifecycleService.occupants).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-041.

### UC-TNT-01 — Tra cứu hồ sơ người thuê và tổng quan

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu hồ sơ và tổng quan tài chính/lịch sử thuê của khách thuộc phạm vi quản lý.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenants | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:38` (TenantsController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenants/:id | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:61` (TenantsController.getById) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenants/:id/overview | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:67` (TenantsController.overview) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:116` (TenantsService.list); `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:136` (TenantsService.getById); `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:141` (TenantsService.overview).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/list-tenants-query.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-023, F-024.

### UC-TNT-02.1 — Tạo hồ sơ người thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lập hồ sơ khách thuê để quản lý quan hệ thuê, chưa tự cấp tài khoản đăng nhập.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenants | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:44` (TenantsController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:209` (TenantsService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/create-tenant.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-023.

### UC-TNT-02.2 — Cập nhật hồ sơ người thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cập nhật thông tin cá nhân và liên hệ của khách thuê thuộc phạm vi quản lý.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/tenants/:id | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:94` (TenantsController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:255` (TenantsService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/update-tenant.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-023.

### UC-TNT-02.3 — Vô hiệu hóa hoặc khôi phục người thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ngừng hoặc khôi phục hoạt động hồ sơ khách thuê theo ràng buộc hợp đồng hiện tại.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/tenants/:id/status | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:115` (TenantsController.updateStatus) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:279` (TenantsService.updateStatus); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/update-tenant-status.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-025.

### UC-TNT-02.4 — Xóa hồ sơ người thuê đủ điều kiện

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Loại hồ sơ khách thuê chỉ khi các ràng buộc dữ liệu cho phép xóa.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| DELETE /api/v1/tenants/:id | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:136` (TenantsController.remove) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:296` (TenantsService.remove); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-025.

### UC-TNT-03 — Tạo lời mời truy cập cổng người thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạo mã/liên kết kích hoạt một lần để khách thuê được vào cổng thông tin của hồ sơ đã có.
- Ranh giới: LANDLORD nhận inviteCode/activationPath để chia sẻ; không khẳng định email tự gửi. STAFF bị PropertyScopeInterceptor chặn TenantInvitesController. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenants/:id/invite | `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.controller.ts:23` (TenantInvitesController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.service.ts:54` (TenantInvitesService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/create-tenant-invite.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-027.

### UC-TNT-03.1 — Tạo trực tiếp tài khoản cho hồ sơ người thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cấp tài khoản đăng nhập liên kết trực tiếp hồ sơ người thuê đã có.
- Ranh giới: STAFF tenant.manage có thể tạo tài khoản trực tiếp vì TenantsController được whitelist; khác UC mời qua TenantInvitesController bị chặn. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenants/:id/account | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:73` (TenantsController.createAccount) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: tenant.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:222` (TenantsService.createAccount); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenants/dto/create-tenant-account.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-026.

### UC-TNT-04 — Tra cứu và xuất hợp đồng thuê

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc hợp đồng theo phòng người thuê và số ngày cảnh báo
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/leases/expiring | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:50` (LeasesController.expiring) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/rooms/:roomId/leases | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:184` (RoomLeasesController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenants/:tenantId/leases | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:197` (TenantLeasesController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:271` (LeasesService.expiring); `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:343` (LeasesService.listByRoom); `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:358` (LeasesService.listByTenant).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1`; `/Users/hoang/Rental_room_management/lib/features/reports/reports_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-029, F-032, F-119.

### UC-TNT-05 — Lập hợp đồng thuê phòng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thiết lập quan hệ thuê có hiệu lực và cập nhật tình trạng phòng; tiền cọc thỏa thuận được lưu, cọc đã thu chỉ tự ghi khi lập trực tiếp với số tiền dương; hỗ trợ nguồn lịch xem đủ điều kiện.
- Ranh giới: Tạo lease ACTIVE và chuyển phòng OCCUPIED trong transaction; một lease ACTIVE/phòng. Create DTO không nhận endDate; chỉnh hạn ở luồng sau. Biến thể từ lịch xem chỉ LANDLORD: lịch phải COMPLETED, chuyển LEASED và ẩn tin. STAFF chỉ luồng tạo trực tiếp, không dùng HousingController. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/leases | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:29` (LeasesController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/housing/viewings/:id/lease | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:79` (HousingController.lease) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:87` (LeasesService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:240` (HousingService.createLease).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/create-lease.dto.ts:10`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:86`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-028, F-101.

- Đính chính 29/10/2026: Nhánh lập từ lịch xem gọi createWithinTransaction với recordDeposit=false: lưu tiền cọc thỏa thuận nhưng không tự ghi COLLECTED. Nhánh lập trực tiếp mới tự ghi COLLECTED khi deposit dương.

### UC-TNT-06.1 — Cập nhật điều khoản hợp đồng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Điều chỉnh điều khoản hợp đồng và giữ lịch sử thay đổi để tra cứu.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/leases/:id | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:104` (LeasesController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:198` (LeasesService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/update-lease.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-030.

### UC-TNT-06.2 — Gia hạn hợp đồng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kéo dài thời hạn hợp đồng đang hoạt động khi đáp ứng điều kiện chưa quyết toán.
- Ranh giới: ACTIVE, endDate mới lớn hơn endDate hiện tại và chưa quyết toán; không tự thanh toán cọc/nợ. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/leases/:id/renew | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:125` (LeasesController.renew) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:224` (LeasesService.renew); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/renew-lease.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-030.

### UC-TNT-06.3 — Kết thúc hợp đồng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chấm dứt quan hệ thuê và mở quy trình chuẩn bị lại phòng, chưa tự quyết toán.
- Ranh giới: Kết thúc lease đặt ENDED, phòng MAINTENANCE và mở turnover; không tự quyết toán hay đưa phòng VACANT. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/leases/:id/end | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:59` (LeasesController.end) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:160` (LeasesService.end); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-031.

### UC-TNT-07 — Tra cứu và ghi giao dịch cọc

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Theo dõi và ghi các khoản thu, hoàn, khấu trừ hoặc điều chỉnh cọc trong giới hạn số dư.
- Ranh giới: Thu/hoàn/khấu trừ cọc theo ledger; không vượt số dư; đã quyết toán thì chặn đường biến động cọc cũ. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/leases/:id/deposits | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:146` (LeasesController.deposits) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/leases/:id/deposits | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:152` (LeasesController.createDeposit) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:262` (LeasesService.depositTransactions); `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:314` (LeasesService.createDepositTransaction); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/create-deposit-transaction.dto.ts:12`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1034` (LeaseChange).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/resource-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-033.

### UC-TNT-12.1 — Quản lý người ở cùng hợp đồng

- Nhóm: G06 — Hồ sơ thuê, hợp đồng và tiền cọc. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì danh sách người ở cùng hợp đồng trong giới hạn sức chứa phòng.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant-lifecycle/leases/:leaseId/occupants | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:54` (TenantLifecycleController.occupants) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant-lifecycle/leases/:leaseId/occupants | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:57` (TenantLifecycleController.addOccupant) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/tenant-lifecycle/leases/:leaseId/occupants/:id | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:60` (TenantLifecycleController.removeOccupant) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205` (TenantLifecycleService.occupants); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:215` (TenantLifecycleService.addOccupant); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:229` (TenantLifecycleService.removeOccupant).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:86`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-041.

### UC-TEN-07.1 — Đề nghị gia hạn thuê

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi, theo dõi hoặc hủy đề nghị gia hạn hợp đồng của mình; chưa tự thay đổi thời hạn.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:15` (TenantLifecyclePortalController.requests) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:18` (TenantLifecyclePortalController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:21` (TenantLifecyclePortalController.cancel) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` (TenantLifecycleService.requests); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:61` (TenantLifecycleService.createRequest); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:92` (TenantLifecycleService.cancelRequest).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:52`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:8`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:28`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-037.

### UC-TEN-07.2 — Đề nghị chuyển phòng

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu phòng đủ điều kiện, gửi/theo dõi hoặc hủy đề nghị chuyển phòng; chưa tạo hợp đồng mới.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:15` (TenantLifecyclePortalController.requests) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:18` (TenantLifecyclePortalController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:21` (TenantLifecyclePortalController.cancel) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/transfer-rooms | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:24` (TenantLifecyclePortalController.transferRooms) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` (TenantLifecycleService.requests); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:61` (TenantLifecycleService.createRequest); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:92` (TenantLifecycleService.cancelRequest); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:131` (TenantLifecycleService.transferRooms).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:52`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:8`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:28`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:72`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-037, F-040.

### UC-TEN-07.3 — Đề nghị trả phòng

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi, theo dõi hoặc hủy đề nghị trả phòng để được xét và thực hiện sau; chưa tự kết thúc/quyết toán hợp đồng.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:15` (TenantLifecyclePortalController.requests) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:18` (TenantLifecyclePortalController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/lifecycle-requests/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:21` (TenantLifecyclePortalController.cancel) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` (TenantLifecycleService.requests); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:61` (TenantLifecycleService.createRequest); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:92` (TenantLifecycleService.cancelRequest).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:52`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:8`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:28`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-037.

### UC-TNT-08 — Xem trước và xác nhận quyết toán trả phòng

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chốt snapshot chi phí cọc và nghĩa vụ còn lại không tự chuyển tiền
- Ranh giới: Chốt tiền thuê theo ngày gồm ngày checkout nếu kỳ chưa được lập; cọc chỉ bù khoản quyết toán. Nợ hóa đơn cũ được trình bày riêng, không tự tất toán; fingerprint/idempotency.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/leases/:id/settlement | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:76` (LeasesController.settlement) | Roles(AuthRole.LANDLORD) | STAFF: lease.view; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/leases/:id/settlement/preview | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:83` (LeasesController.previewSettlement) | Roles(AuthRole.LANDLORD) | STAFF: lease.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/leases/:id/settlement/confirm | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:90` (LeasesController.confirmSettlement) | Roles(AuthRole.LANDLORD) | STAFF: lease.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:39` (LeaseSettlementsService.get); `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:53` (LeaseSettlementsService.preview); `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:61` (LeaseSettlementsService.confirm).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/lease-settlement.dto.ts:35`; `/Users/hoang/Rental_room_management/backend/src/leases/dto/lease-settlement.dto.ts:75`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1051` (LeaseSettlement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1089` (LeaseSettlementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/lease_settlement_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.spec.ts:1`.
- Mục khảo sát liên quan: F-034, F-036.

### UC-TNT-09 — Ghi nhận đã hoàn cọc theo quyết toán

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi nhận khoản hoàn cọc theo quyết toán đã được thực trả, có lịch sử kiểm tra.
- Ranh giới: Chỉ ghi nhận hoàn cọc đã thực hiện, không chuyển tiền qua ngân hàng.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/leases/:id/settlement/refund | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:97` (LeasesController.recordSettlementRefund) | Roles(AuthRole.LANDLORD) | STAFF: lease.manage; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:101` (LeaseSettlementsService.recordRefund).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/leases/dto/lease-settlement.dto.ts:84`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1051` (LeaseSettlement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1089` (LeaseSettlementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/lease_settlement_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-settlement.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.spec.ts:1`.
- Mục khảo sát liên quan: F-035.

### UC-TNT-10 — Xét duyệt yêu cầu vòng đời thuê

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đặt APPROVED hoặc REJECTED chưa tự đổi hợp đồng
- Ranh giới: APPROVED không đồng nghĩa đã thực thi; chưa thay lease chỉ bằng quyết định. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant-lifecycle/requests | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:45` (TenantLifecycleController.requests) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant-lifecycle/requests/:id/review | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:48` (TenantLifecycleController.review) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:37` (TenantLifecycleService.requests); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:102` (TenantLifecycleService.decideRequest).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:52`; `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:36`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-037, F-038.

### UC-TNT-11 — Thực thi yêu cầu vòng đời đã duyệt

- Nhóm: G07 — Vòng đời thuê và quyết toán. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thực hiện đề nghị gia hạn, chuyển hoặc trả phòng đã được duyệt, bảo đảm không thực hiện trùng và đáp ứng điều kiện hợp đồng.
- Ranh giới: Thực thi một lần theo requestKey; chuyển/trả phòng cần lease kết thúc và quyết toán theo nhánh; chuyển phòng tạo lease mới và kiểm tra sức chứa. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenant-lifecycle/requests/:id/execute | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:51` (TenantLifecycleController.execute) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: lease.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148` (TenantLifecycleService.executeRequest).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:44`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-039.

### UC-BIL-01 — Ghi chỉ số điện nước theo kỳ

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu lượng tiêu thụ và số tiền của phòng loại tiện ích kỳ
- Ranh giới: Chỉ số mới không nhỏ hơn chỉ số cũ, đơn giá dương; số liệu theo phòng/kỳ/loại tiện ích. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/meter-readings | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:56` (BillingController.meterReadings) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/meter-readings | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:66` (BillingController.createMeterReading) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:269` (BillingService.listMeterReadings); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:227` (BillingService.createMeterReading); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/create-meter-reading.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-043, F-044.

### UC-BIL-02 — Xem trước và lập hóa đơn một hợp đồng

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Phát hành hóa đơn với các dòng giá chụp tại kỳ lập
- Ranh giới: Đóng băng line item/giá ở thời điểm lập; chống trùng theo leaseId, billingMonth, isDemo, revision sau các migration. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/active-leases | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:50` (BillingController.activeLeases) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/invoices/preview | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:413` (BillingController.previewInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/invoices | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:241` (BillingController.createInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:189` (BillingService.activeLeases); `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:100` (BillingTariffsService.preview); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:291` (BillingService.createInvoice); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-tariffs.dto.ts:32`; `/Users/hoang/Rental_room_management/backend/src/billing/dto/create-invoice.dto.ts:32`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1377` (BillingTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1405` (BillingPeriodLock); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/billing_tariffs_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.spec.ts:1`.
- Mục khảo sát liên quan: F-043, F-045, F-061.

### UC-BIL-03 — Lập hóa đơn hàng loạt

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kiểm tra trước và tạo kết quả cho từng hợp đồng đủ điều kiện
- Ranh giới: Preflight và kết quả từng hợp đồng là bước của lập hàng loạt, không tách thành UC kiểm tra trùng. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/bulk/preflight | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:135` (BillingController.bulkInvoicePreflight) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/invoices/bulk | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:144` (BillingController.createBulkInvoices) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:384` (BillingService.bulkInvoicePreflight); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:460` (BillingService.createBulkInvoices); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/create-bulk-invoices.dto.ts:13`; `/Users/hoang/Rental_room_management/backend/src/billing/dto/create-bulk-invoices.dto.ts:32`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-046.

### UC-BIL-04 — Tra cứu hóa đơn và công nợ

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc số còn phải thu và nhóm ngày quá hạn
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/invoices | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:90` (BillingController.invoices) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/billing/invoices/:id | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:264` (BillingController.invoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/billing/aging | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:315` (BillingController.aging) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/billing/reminders | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:110` (BillingController.reminders) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/billing/invoices/:id/payment-link | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:24` (LandlordOnlinePaymentsController.status) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/billing/invoices/:id/payment-events | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:25` (LandlordOnlinePaymentsController.events) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:794` (BillingService.listInvoices); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:907` (BillingService.getInvoice); `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:150` (BillingLedgerService.aging); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:830` (BillingService.reminders); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:66` (OnlinePaymentsService.status); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:134` (OnlinePaymentsService.events).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:61`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1656` (PaymentLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1688` (DemoCheckoutSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1704` (PaymentWebhookEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_online_payment_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/demo-card-payments.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/demo-card.gateway.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-048, F-060, F-066, F-067, F-119.

### UC-BIL-05 — Sửa hạn thanh toán hoặc ghi chú hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đổi hạn và ghi chú mà không ghi đè dòng tiền
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/billing/invoices/:id | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:270` (BillingController.updateInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:916` (BillingService.updateInvoice); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/update-invoice.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-049.

### UC-BIL-06 — Thay thế hóa đơn chưa có lịch sử thanh toán

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Hủy bản gốc và tạo revision mới có liên kết truy vết
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/:id/replacement | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:303` (BillingController.replaceInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.adjust; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:25` (BillingLedgerService.replace).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:29`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-054.

### UC-BIL-07 — Điều chỉnh tăng hoặc giảm hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thay đổi nghĩa vụ hóa đơn bằng điều chỉnh tăng/giảm theo số tiền hoặc tỷ lệ có truy vết.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/:id/adjustments | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:309` (BillingController.adjustInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.adjust; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:60` (BillingLedgerService.adjust).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:13`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-055.

### UC-BIL-08.1 — Hủy hóa đơn đủ điều kiện

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ngừng hiệu lực thu của hóa đơn sai hoặc không còn cần thu khi chưa có lịch sử thanh toán.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:291` (BillingController.cancelInvoice) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.cancel; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1245` (BillingService.cancelInvoice).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/cancel-invoice.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-053.

### UC-BIL-09 — Ghi nhận thanh toán trực tiếp

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi số tiền người thuê đã trả cho hóa đơn thật, không vượt nghĩa vụ còn lại.
- Ranh giới: Khoản trả dương, không vượt dư; chặn demo/hóa đơn hủy. Không đồng nghĩa thu tiền trực tiếp từ ngân hàng. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/:id/payments | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:419` (BillingController.recordPayment) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.record_payment; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:960` (BillingService.recordPayment); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/record-payment.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-050.

### UC-BIL-10 — Tạo khoản thu cho người thuê

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi số tiền đã nhận từ người thuê, theo dõi phần còn khả dụng chưa phân bổ.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/receipts | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:321` (BillingController.receipts) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/receipts | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:327` (BillingController.createReceipt) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.record_payment; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:145` (BillingLedgerService.receipts); `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:88` (BillingLedgerService.createReceipt).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:45`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-056.

### UC-BIL-11 — Phân bổ khoản thu cho hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Dùng phần tiền thu còn khả dụng để thanh toán các hóa đơn của cùng người thuê.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/receipts/:id/allocations | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:333` (BillingController.allocateReceipt) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.record_payment; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:101` (BillingLedgerService.allocate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:40`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-057.

### UC-BIL-12.1 — Giải phóng phân bổ khoản thu

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Hủy phân bổ tiền thu đã ghi sai và khôi phục phần tiền có thể dùng lại, giữ lịch sử đảo.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/receipts/:id/allocations/:allocationId/release | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:339` (BillingController.releaseAllocation) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.reverse_payment; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:111` (BillingLedgerService.release).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:8`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-058.

### UC-BIL-12.2 — Đảo thanh toán trực tiếp

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Hủy tác động khoản thanh toán ghi sai bằng giao dịch đảo có truy vết, không sửa xóa lịch sử.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/invoices/:invoiceId/payments/:paymentId/reverse | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:475` (BillingController.reversePayment) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.reverse_payment; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1185` (BillingService.reversePayment); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/reverse-payment.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-052.

### UC-BIL-13 — Ghi nhận hoàn tiền từ khoản thu

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi khoản đã hoàn từ tiền thu chưa phân bổ cho người thuê, có tham chiếu và không vượt số dư.
- Ranh giới: Chỉ hoàn từ tiền khả dụng chưa phân bổ; ghi ReceiptRefund, không lệnh chuyển tiền. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/receipts/:id/refunds | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:345` (BillingController.refundReceipt) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.refund; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:132` (BillingLedgerService.refund).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:55`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1247` (BillingCommand); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1259` (InvoiceAdjustment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1295` (PaymentAllocation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1310` (BillingRefund).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_receipts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-rules.spec.ts:1`.
- Mục khảo sát liên quan: F-059.

### UC-BIL-14 — Xét duyệt chứng từ thanh toán

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chấp thuận hoặc từ chối chứng từ do người thuê gửi; chỉ ghi đã trả khi chứng từ được chấp thuận.
- Ranh giới: Chấp thuận tạo receipt/payment/allocation; từ chối không tăng paidAmount. Cần billing.view để đọc và billing.approve_payment_proof để quyết. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/payment-proofs | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:440` (BillingController.paymentProofs) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/payment-proofs/:id/review | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:449` (BillingController.reviewPaymentProof) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.approve_payment_proof; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1038` (BillingService.listPaymentProofs); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1053` (BillingService.reviewPaymentProof); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/review-payment-proof.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-051.

### UC-BIL-15 — Đề xuất biểu phí theo kỳ hiệu lực

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đề nghị mức phí mới theo thời điểm hiệu lực để được chủ trọ xem xét.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/tariffs | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:381` (BillingController.tariffsList) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/tariffs/proposals | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:387` (BillingController.proposeTariff) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:19` (BillingTariffsService.list); `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:25` (BillingTariffsService.propose).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-tariffs.dto.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1377` (BillingTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1405` (BillingPeriodLock).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_tariffs_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.spec.ts:1`.
- Mục khảo sát liên quan: F-061.

### UC-BIL-16 — Phân tích tác động và duyệt biểu phí

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duyệt hoặc từ chối đề xuất sau kiểm tra kỳ đã phát hành hoặc khóa
- Ranh giới: STAFF billing.view chỉ xem tác động; reviewTariff chỉ LANDLORD dù danh sách permission có billing.tariff_approve. Controller reviewTariff là LANDLORD-only dù tồn tại tên permission billing.tariff_approve. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/tariffs/:id/impact | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:393` (BillingController.tariffImpact) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/tariffs/:id/review | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:399` (BillingController.reviewTariff) | Roles(AuthRole.LANDLORD) | STAFF: billing.tariff_approve; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:44` (BillingTariffsService.impact); `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:67` (BillingTariffsService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-tariffs.dto.ts:23`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1377` (BillingTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1405` (BillingPeriodLock).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_tariffs_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.spec.ts:1`.
- Mục khảo sát liên quan: F-061, F-062.

### UC-BIL-17.1 — Cấu hình lập hóa đơn định kỳ

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu lịch lập hóa đơn theo khu
- Ranh giới: STAFF: đọc billing.view; sửa billing.create, kèm propertyIds. Không dùng billing.policy để suy quyền. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/automation | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:168` (BillingController.billingAutomation) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/billing/automation | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:180` (BillingController.updateBillingAutomation) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:599` (BillingService.billingAutomation); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:615` (BillingService.updateBillingAutomation); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-automation.dto.ts:17`; `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-automation.dto.ts:22`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-047.

### UC-BIL-17.2 — Xem trước và chạy đợt lập hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lập hóa đơn theo đợt từ cấu hình đã lưu và theo dõi kết quả của kỳ được chọn.
- Ranh giới: STAFF preview/run cần billing.create; chạy đợt do người dùng và worker dùng chung nghiệp vụ, worker không là Actor ngoài hệ thống. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/automation/preview | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:208` (BillingController.billingAutomationPreview) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/automation/run | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:217` (BillingController.runBillingAutomation) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.create; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:642` (BillingService.billingAutomationPreview); `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:669` (BillingService.runBillingAutomation); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-automation.dto.ts:40`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:795` (InvoiceLineItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1139` (MeterReading); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1416` (BillingAutomation).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.spec.ts:1`.
- Mục khảo sát liên quan: F-047.

### UC-BIL-18.1 — Cấu hình chính sách nhắc nợ

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu chính sách mặc định hoặc ghi đè theo khu
- Ranh giới: STAFF cần billing.policy và propertyId trong phạm vi được giao cho cả đọc/cập nhật. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/reminder-policy | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:351` (BillingController.reminderPolicy) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.policy; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/billing/reminder-policy | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:357` (BillingController.updateReminderPolicy) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.policy; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:20` (BillingRemindersService.policy); `/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:31` (BillingRemindersService.save).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:68`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1112` (NotificationDelivery); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1323` (BillingReminderPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1341` (BillingOutboxEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1362` (BillingNotification).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/notifications/notifications_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-113.

### UC-BIL-18.2 — Gửi nhắc nợ theo chính sách

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Một phần.
- Mục tiêu: Chọn phạm vi/chính sách và xếp hàng nhắc nghĩa vụ hóa đơn; xem kết quả nội bộ, không đảm bảo provider đã giao.
- Ranh giới: STAFF chỉ đường BillingController với billing.policy + propertyId được giao; đường NotificationsController/ZNS bị chặn STAFF. APP, webhook nhắc nợ và ZNS không được đồng nhất. APP/outbox có triển khai; EMAIL/ZALO/webhook/ZNS phụ thuộc cấu hình và chưa xác nhận giao thực. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/reminders/run | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:124` (BillingController.runReminders) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.policy; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/reminders/enqueue | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:363` (BillingController.enqueueReminders) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.policy; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/notifications/zalo/invoice-reminders | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:39` (NotificationsController.sendInvoiceRemindersZalo) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:49` (BillingRemindersService.enqueue); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:83` (NotificationsService.sendInvoiceRemindersZalo).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1112` (NotificationDelivery); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1323` (BillingReminderPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1341` (BillingOutboxEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1362` (BillingNotification).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/notifications/notifications_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-111, F-113.

### UC-BIL-18.3 — Theo dõi và thử lại outbox hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc sự kiện và yêu cầu thử lại theo trạng thái được phép
- Ranh giới: Chỉ LANDLORD dùng outboxEvents/retryOutbox vì interceptor chặn STAFF dù decorator có quyền. Interceptor không cho STAFF dùng outboxEvents hoặc retryOutbox. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/billing/outbox | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:369` (BillingController.outboxEvents) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/billing/outbox/:id/retry | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:375` (BillingController.retryOutbox) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: billing.policy; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-outbox.service.ts:90` (BillingOutboxService.list); `/Users/hoang/Rental_room_management/backend/src/billing/billing-outbox.service.ts:99` (BillingOutboxService.retry).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-ledger.dto.ts:8`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1112` (NotificationDelivery); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1323` (BillingReminderPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1341` (BillingOutboxEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1362` (BillingNotification).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/notifications/notifications_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-114.

### UC-BIL-22 — Khóa kỳ thanh toán của khu

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đóng kỳ thanh toán của khu trọ để ngăn thay đổi ngoài quy tắc cho phép.
- Ranh giới: Chỉ LANDLORD khóa kỳ; không suy ra quyền STAFF từ permission enum.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/billing/period-locks | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:406` (BillingController.lockPeriod) | Roles(AuthRole.LANDLORD) | STAFF: billing.tariff_approve; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:91` (BillingTariffsService.lockPeriod).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/dto/billing-tariffs.dto.ts:27`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:777` (ServiceTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1377` (BillingTariffVersion); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1405` (BillingPeriodLock).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/billing/billing_tariffs_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/invoice-tariffs.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.spec.ts:1`.
- Mục khảo sát liên quan: F-063.

### UC-BIL-23 — Cấu hình tài khoản nhận chuyển khoản

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Thiết lập ngân hàng, tài khoản và QR nhận tiền để người thuê xem hướng dẫn chuyển khoản.
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/properties/:id/transfer-account | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.controller.ts:12` (TransferAccountController.account) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/properties/:id/transfer-account | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.controller.ts:14` (TransferAccountController.save) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:11` (ManualTransferService.account); `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:20` (ManualTransferService.save).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:398` (PropertyPaymentAccount); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_manual_payment_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.spec.ts:1`.
- Mục khảo sát liên quan: F-064.

### UC-TEN-03 — Tra cứu hóa đơn của mình

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tra cứu nghĩa vụ, trạng thái và chi tiết hóa đơn của mình; xuất PDF khi giao diện hỗ trợ.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/invoices | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:27` (TenantPortalController.invoices) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/invoices/:id | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:37` (TenantPortalController.invoice) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:157` (TenantPortalService.invoices); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:167` (TenantPortalService.invoice).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1`; `/Users/hoang/Rental_room_management/lib/features/reports/reports_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-074, F-119.

### UC-TEN-04 — Gửi chứng từ chuyển khoản hóa đơn

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lấy hướng dẫn chuyển khoản và gửi bằng chứng cho hóa đơn của mình để chờ xét duyệt; chưa tự ghi đã trả.
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenant/invoices/:id/payment-proofs | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:70` (TenantPortalController.submitPaymentProof) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/invoices/:id/transfer-instructions | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.controller.ts:22` (TransferInstructionsController.instructions) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:426` (TenantPortalService.submitPaymentProof); `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:46` (ManualTransferService.instructions).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/dto/create-payment-proof.dto.ts:15`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:398` (PropertyPaymentAccount); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_manual_payment_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/manual-transfers.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.spec.ts:1`.
- Mục khảo sát liên quan: F-065.

### UC-TEN-05 — Thanh toán bằng thẻ mô phỏng

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Đã triển khai — DEMO.
- Mục tiêu: Trải nghiệm trả một hóa đơn kiểm thử bằng trang thẻ mô phỏng nội bộ, hoàn toàn không thu tiền thật.
- Ranh giới: Chỉ bật ngoài production và DEMO_PAYMENTS_ENABLED=true; không có cổng thu thẻ tiền thật được xác nhận. Chỉ isDemo/DEMO_CARD, không có thu tiền ngân hàng thực. TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/tenant/invoices/:id/payment-link | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:15` (TenantOnlinePaymentsController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/invoices/:id/demo-invoice | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:16` (TenantOnlinePaymentsController.demoInvoice) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/invoices/:id/payment-link | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:17` (TenantOnlinePaymentsController.status) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/payments/demo/checkout/:token | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:41` (DemoCardPaymentController.checkout) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/payments/demo/checkout/:token/confirm | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:53` (DemoCardPaymentController.confirm) | Không khai báo @Roles; xem guard riêng | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:41` (OnlinePaymentsService.createLink); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:21` (OnlinePaymentsService.createDemoInvoice); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:66` (OnlinePaymentsService.status); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:99` (OnlinePaymentsService.checkout); `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:109` (OnlinePaymentsService.confirmDemo).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1656` (PaymentLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1688` (DemoCheckoutSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1704` (PaymentWebhookEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_online_payment_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/demo-card-payments.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/billing/demo-card.gateway.spec.ts:1`.
- Mục khảo sát liên quan: F-066, F-067.

### UC-TEN-08.2 — Chọn kênh nhận nhắc nợ

- Nhóm: G08 — Hóa đơn, thu tiền và công nợ. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đặt enabled và các kênh nhắc nợ được hỗ trợ
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/notification-preferences | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:33` (TenantLifecyclePortalController.preference) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PUT /api/v1/tenant/notification-preferences | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:36` (TenantLifecyclePortalController.savePreference) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:240` (TenantLifecycleService.preference); `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:245` (TenantLifecycleService.savePreference).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/dto/tenant-lifecycle.dto.ts:100`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:846` (TenantOccupant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:863` (TenantLifecycleRequest); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:889` (TenantLifecycleExecution); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:900` (TenantNotificationPreference).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_lifecycle_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-042.

### UC-BIL-19 — Quản lý khoản chi vận hành

- Nhóm: G09 — Bảo trì và chi phí vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu khoản Expense riêng với tiền thuê và tiền cọc
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/expenses | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:36` (ExpensesController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: expense.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/expenses | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:42` (ExpensesController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: expense.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/expenses/:id | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:59` (ExpensesController.getById) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: expense.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/expenses/:id | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:65` (ExpensesController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: expense.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/expenses/:id | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:86` (ExpensesController.remove) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: expense.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:34` (ExpensesService.list); `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:77` (ExpensesService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:72` (ExpensesService.getById); `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:99` (ExpensesService.update); `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:130` (ExpensesService.remove).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/expenses/dto/list-expenses-query.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/expenses/dto/create-expense.dto.ts:13`; `/Users/hoang/Rental_room_management/backend/src/expenses/dto/update-expense.dto.ts:13`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/expenses/expenses_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-069.

### UC-OPS-01 — Tiếp nhận và theo dõi phiếu bảo trì

- Nhóm: G09 — Bảo trì và chi phí vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì ticket nội dung bình luận và xóa theo điều kiện
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/maintenance | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:41` (MaintenanceController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/maintenance | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:47` (MaintenanceController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/maintenance/:id | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:73` (MaintenanceController.getById) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/maintenance/:id/comments | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:148` (MaintenanceController.addComment) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/maintenance/:id | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:173` (MaintenanceController.remove) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:60` (MaintenanceService.list); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:116` (MaintenanceService.create); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:111` (MaintenanceService.getById); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:272` (MaintenanceService.addComment); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:292` (MaintenanceService.remove).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/list-maintenance-query.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/create-maintenance-ticket.dto.ts:15`; `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/create-maintenance-comment.dto.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1498` (MaintenanceComment).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/maintenance/maintenance_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-070, F-072.

### UC-OPS-02 — Phân công và cập nhật bảo trì

- Nhóm: G09 — Bảo trì và chi phí vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gán nhân viên tiến độ hạn xử lý và chạy kiểm tra SLA
- Ranh giới: STAFF không gọi escalate; thao tác thủ công chỉ LANDLORD. Worker SLA là thành phần nội bộ. STAFF được một số thao tác bảo trì nhưng bị chặn escalate ở interceptor. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/maintenance/assignees | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:67` (MaintenanceController.assignees) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/maintenance/:id | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:85` (MaintenanceController.update) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/maintenance/:id/status | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:106` (MaintenanceController.updateStatus) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/maintenance/sla/escalate | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:79` (MaintenanceController.escalate) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:54` (MaintenanceService.assignees); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:142` (MaintenanceService.update); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:203` (MaintenanceService.updateStatus); `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance-sla.service.ts:24` (MaintenanceSlaService.escalate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/update-maintenance-ticket.dto.ts:15`; `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/update-maintenance-status.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1498` (MaintenanceComment).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/maintenance/maintenance_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-070, F-071, F-073.

### UC-OPS-03 — Hoàn tất bảo trì và liên kết khoản chi

- Nhóm: G09 — Bảo trì và chi phí vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chốt bảo trì đã hoàn tất và ghi khoản chi sửa chữa liên quan khi có, không tạo chi phí trùng.
- Ranh giới: Hoàn thành có thể tạo Expense REPAIR một lần; không đếm lại khoản chi thành UC mới. STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/maintenance/:id/complete | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:127` (MaintenanceController.complete) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: maintenance.complete; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:227` (MaintenanceService.complete); `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:89` (AuditService.recordSafe).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/complete-maintenance-ticket.dto.ts:12`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:291` (StaffProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1498` (MaintenanceComment).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/maintenance/maintenance_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/staff-lifecycle.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-072.

### UC-TEN-06 — Gửi và trao đổi yêu cầu bảo trì

- Nhóm: G09 — Bảo trì và chi phí vận hành. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạo ticket và bình luận cho phòng gắn hợp đồng của mình
- Ranh giới: TENANT cần hợp đồng ACTIVE để tạo yêu cầu đúng phòng; không cấp quyền maintenance.manage của chủ trọ. TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/maintenance | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:79` (TenantPortalController.maintenance) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/maintenance | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:84` (TenantPortalController.createMaintenance) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/maintenance/:id/comments | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:92` (TenantPortalController.addMaintenanceComment) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:371` (TenantPortalService.maintenance); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:384` (TenantPortalService.createMaintenance); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:407` (TenantPortalService.addMaintenanceComment).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/dto/create-tenant-maintenance.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/maintenance/dto/create-maintenance-comment.dto.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-075.

### UC-OPS-04 — Theo dõi việc cần xử lý

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc action items và đánh dấu đã xem theo tài khoản
- Ranh giới: OperationsController không nằm trong allowlist của PropertyScopeInterceptor; STAFF bị từ chối. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/operations/action-items | `/Users/hoang/Rental_room_management/backend/src/operations/operations.controller.ts:18` (OperationsController.actionItems) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/operations/action-items/:id/read | `/Users/hoang/Rental_room_management/backend/src/operations/operations.controller.ts:24` (OperationsController.markRead) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/operations/operations.service.ts:50` (OperationsService.actionItems); `/Users/hoang/Rental_room_management/backend/src/operations/operations.service.ts:32` (OperationsService.markRead).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/operations/action-items.dto.ts:7`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1574` (OperationTask).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/action_items_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-078, F-079.

### UC-OPS-05 — Chuẩn bị phòng sau trả phòng

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đưa phòng đã nhận lại qua kiểm tra, sửa chữa và dọn dẹp để đủ điều kiện cho thuê tiếp.
- Ranh giới: RETURNED → INSPECTION → REPAIR → CLEANING → READY; sửa chữa chưa xong chặn đi tiếp; chỉ đưa VACANT khi pipeline hoàn tất. P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/operations/turnovers | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:25` (P1OperationsController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.view ANY room.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/operations/turnovers | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:26` (P1OperationsController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/operations/turnovers/:id/advance | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:27` (P1OperationsController.advance) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/operations/turnovers.service.ts:13` (TurnoversService.list); `/Users/hoang/Rental_room_management/backend/src/operations/turnovers.service.ts:22` (TurnoversService.create); `/Users/hoang/Rental_room_management/backend/src/operations/turnovers.service.ts:35` (TurnoversService.advance).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:16`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:21`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1574` (OperationTask).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/p1_operations_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/operations/action_items_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-080.

### UC-OPS-06 — Thiết lập lịch công việc định kỳ

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tạo và bật/tắt quy tắc công việc lặp lại cho khu/phòng để phát sinh đầu việc.
- Ranh giới: P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/operations/recurring | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:28` (P1OperationsController.templates) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.view ANY operation.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/operations/recurring | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:29` (P1OperationsController.createRecurring) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/operations/recurring/:id | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:30` (P1OperationsController.toggle) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/operations/options | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:16` (P1OperationsController.options) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: room.manage ANY operation.manage ANY notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:41` (RecurringService.templates); `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:27` (RecurringService.create); `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:50` (RecurringService.toggle).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:27`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:38`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1574` (OperationTask).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/p1_operations_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/operations/action_items_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-080, F-081.

### UC-OPS-06.1 — Thực hiện checklist công việc định kỳ

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Theo dõi và xác nhận hoàn thành đầu việc được sinh từ lịch công việc.
- Ranh giới: P1OperationsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/operations/tasks | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:31` (P1OperationsController.tasks) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.view ANY operation.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/operations/tasks/:id/checklist | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:32` (P1OperationsController.check) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: operation.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:56` (RecurringService.tasks); `/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:65` (RecurringService.check).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:12`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:42`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1514` (RoomTurnover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1574` (OperationTask).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/p1_operations_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/operations/action_items_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-082.

### UC-OPS-07 — Soạn và phát thông báo người thuê

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu mẫu nhóm lịch thông báo và theo dõi lượt đọc
- Ranh giới: AnnouncementsController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/announcements | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:13` (AnnouncementsController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view ANY notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/announcements/templates | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:14` (AnnouncementsController.templates) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view ANY notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/announcements/groups | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:15` (AnnouncementsController.groups) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view ANY notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/announcements/templates | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:16` (AnnouncementsController.createTemplate) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/announcements/groups | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:17` (AnnouncementsController.createGroup) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/announcements | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:18` (AnnouncementsController.create) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/announcements/:id/receipts | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:19` (AnnouncementsController.receipts) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view ANY notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/announcements/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:20` (AnnouncementsController.cancel) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.manage; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:46` (AnnouncementsService.list); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:50` (AnnouncementsService.templates); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:51` (AnnouncementsService.groups); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:18` (AnnouncementsService.createTemplate); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:11` (AnnouncementsService.createGroup); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:22` (AnnouncementsService.create); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:69` (AnnouncementsService.receipts); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:74` (AnnouncementsService.cancel).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:53`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:48`; `/Users/hoang/Rental_room_management/backend/src/operations/p1.dto.ts:59`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1599` (TenantGroup); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1610` (AnnouncementTemplate); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1622` (Announcement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1645` (AnnouncementRecipient).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/p1_operations_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-083, F-084, F-085.

### UC-SUP-04 — Theo dõi thông báo cá nhân

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc, xác nhận đã đọc và chọn sở thích thông báo của mình qua các hộp thư được cấp; nguồn portal/vận hành/nền tảng vẫn tách biệt.
- Ranh giới: Gộp mục tiêu đọc thông báo, không đồng nhất Notification, HousingNotification và PlatformNotification. Theo đúng handler; STAFF bị chặn tất cả các nguồn thông báo này. Chỉ phần endpoint cho LANDLORD TENANT ADMIN được coi truy cập được; STAFF bị chặn bởi interceptor. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/notification-center | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:14` (NotificationCenterController.list) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| GET /api/v1/notification-center/preferences | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:15` (NotificationCenterController.preferences) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| PATCH /api/v1/notification-center/preferences | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:16` (NotificationCenterController.updatePreferences) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| POST /api/v1/notification-center/:id/read | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:17` (NotificationCenterController.markRead) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| POST /api/v1/notification-center/read-all | `/Users/hoang/Rental_room_management/backend/src/support/notification-center.controller.ts:18` (NotificationCenterController.markAllRead) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| GET /api/v1/support/notifications | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:25` (SupportController.listNotifications) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| POST /api/v1/support/notifications/:id/read | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:26` (SupportController.markNotification) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| POST /api/v1/support/notifications/read-all | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:27` (SupportController.markAllNotifications) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.notifications.view |
| GET /api/v1/housing/notifications | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:84` (HousingController.notifications) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/housing/notifications/:id/read | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:89` (HousingController.read) | Roles(AuthRole.TENANT, AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/tenant/notifications | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:42` (TenantPortalController.notifications) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/notifications/:id/read | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:47` (TenantPortalController.markNotificationRead) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/notifications | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:18` (NotificationsController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/notifications/:id/read | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:24` (NotificationsController.markRead) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` (PlatformNotificationService.list); `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:9` (PlatformNotificationService.preferences); `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:13` (PlatformNotificationService.updatePreferences); `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:30` (PlatformNotificationService.markRead); `/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:36` (PlatformNotificationService.markAllRead); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:279` (HousingService.notifications); `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:311` (HousingService.readNotification); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:188` (TenantPortalService.notifications); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:266` (TenantPortalService.markNotificationRead); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:40` (NotificationsService.list); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:58` (NotificationsService.markRead).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:28`; `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1112` (NotificationDelivery); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1323` (BillingReminderPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1341` (BillingOutboxEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1362` (BillingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1983` (PlatformNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2198` (PlatformNotificationPreference); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2206` (PlatformNotificationDelivery).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/notifications/notifications_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-operations-release.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-076, F-103, F-110, F-115, F-155.

### UC-SUP-06 — Hỏi trợ lý AI và đọc nguồn hướng dẫn

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02). Trạng thái: Một phần.
- Mục tiêu: Nhận hướng dẫn sử dụng có nguồn trong phạm vi tri thức được phép, hoặc thông báo chưa đủ bằng chứng.
- Ranh giới: Chỉ hướng dẫn có nguồn theo GLOBAL/LANDLORD/PROPERTY; tối đa 3 đoạn; không có dữ liệu thì fallback; không trả lời trực tiếp số dư sống hay tự thao tác nghiệp vụ. Retrieval, scope và fallback có code/test; chưa gọi model Ollama thật trong khảo sát.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/chatbot/ask | `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.controller.ts:19` (ChatbotController.ask) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/chatbot/sources/:id | `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.controller.ts:26` (ChatbotController.source) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.service.ts:24` (ChatbotService.ask); `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.service.ts:64` (ChatbotService.getSource).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/chatbot/dto/ask-chatbot.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/chatbot/dto/ask-chatbot.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:250` (KnowledgeDocument); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:272` (KnowledgeChunk).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/chatbot/chatbot_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/chatbot.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/chatbot/knowledge-retriever.spec.ts:1`.
- Mục khảo sát liên quan: F-121.

### UC-TEN-09.2 — Trao đổi tin nhắn Zalo mô phỏng

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04). Trạng thái: Đã triển khai — MÔ PHỎNG.
- Mục tiêu: Trao đổi và kiểm tra tin nhắn lưu nội bộ ứng dụng; không mô tả là kết nối Zalo OA thật.
- Ranh giới: Tin được lưu nội bộ, không mặc định gửi ra Zalo. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này. TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/zalo-messages | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:52` (TenantPortalController.zaloMessages) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/zalo-messages | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:57` (TenantPortalController.createZaloMessage) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/zalo-messages/:id/read | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:65` (TenantPortalController.markZaloMessageRead) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/notifications/zalo/test-message | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:53` (NotificationsController.createZaloTestMessage) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/notifications/zalo/manual-message | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:59` (NotificationsController.createZaloManualMessage) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/notifications/deliveries | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:30` (NotificationsController.deliveryLogs) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: notification.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:279` (TenantPortalService.zaloMessages); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:311` (TenantPortalService.createZaloMessage); `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:346` (TenantPortalService.markZaloMessageRead); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:196` (NotificationsService.createZaloTestMessage); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:275` (NotificationsService.createZaloManualMessage); `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:67` (NotificationsService.deliveryLogs).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/tenant-portal/dto/create-tenant-zalo-message.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:816` (Tenant); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1101` (NotificationRead); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1112` (NotificationDelivery); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1201` (PaymentProof); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1323` (BillingReminderPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1341` (BillingOutboxEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1362` (BillingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1460` (MaintenanceTicket).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_portal_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/notifications/notifications_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/app-functional.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/billing-production.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-077, F-110, F-112.

### UC-TEN-09.3 — Đọc và xác nhận thông báo chủ trọ

- Nhóm: G10 — Công việc, thông tin và hỗ trợ sử dụng. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi lượt đọc hoặc acknowledgement Announcement
- Ranh giới: TENANT cần Tenant liên kết/lease hoặc invoice thuộc mình; đăng ký tìm phòng chưa tự có các dữ liệu này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/tenant/announcements | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:27` (TenantAnnouncementsController.list) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/tenant/announcements/:id/read | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:28` (TenantAnnouncementsController.read) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:53` (AnnouncementsService.tenantAnnouncements); `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:59` (AnnouncementsService.markRead).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1599` (TenantGroup); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1610` (AnnouncementTemplate); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1622` (Announcement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1645` (AnnouncementRecipient).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/operations/p1_operations_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/p1-operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/tenant-portal-priority.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-085.

### UC-ADM-01 — Xem tổng quan nền tảng

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc overview analytics và công việc chờ theo quyền
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/overview | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:22` (AdminController.overview) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/analytics/overview | `/Users/hoang/Rental_room_management/backend/src/admin/admin-overview-analytics.controller.ts:14` (AdminOverviewAnalyticsController.overview) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/analytics/summary | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:68` (AdminConsoleController.analytics) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/workspace/summary | `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.controller.ts:14` (AdminWorkspaceController.summary) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/workspace/action-items | `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.controller.ts:16` (AdminWorkspaceController.actionItems) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:64` (AdminService.overview); `/Users/hoang/Rental_room_management/backend/src/admin/admin-overview-analytics.service.ts:33` (AdminOverviewAnalyticsService.overview); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:286` (AdminConsoleService.analytics); `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.service.ts:25` (AdminWorkspaceService.summary); `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.service.ts:81` (AdminWorkspaceService.actionItems).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-overview-analytics.service.ts:9`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:67`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_workspace_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_overview_page.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-131, F-132.

### UC-ADM-14 — Tra cứu và xuất nhật ký quản trị

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc audit và xuất dữ liệu trong phạm vi capability
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/audit-logs | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:47` (AdminConsoleController.audit) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.audit.view |
| GET /api/v1/admin/audit-logs/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:49` (AdminConsoleController.auditDetail) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.audit.view |
| POST /api/v1/admin/audit-logs/export | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:51` (AdminConsoleController.auditExport) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.audit.view AND admin.audit.export |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:202` (AdminConsoleService.audit); `/Users/hoang/Rental_room_management/backend/src/admin/admin-audit-query.service.ts:37` (AdminAuditQueryService.detail); `/Users/hoang/Rental_room_management/backend/src/admin/admin-audit-query.service.ts:48` (AdminAuditQueryService.export).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:37`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:45`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-174.

### UC-ADM-16 — Quản lý lịch và tải báo cáo Admin

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lập lịch theo timezone chạy và tải kết quả của mình
- Ranh giới: Lịch/run thuộc chủ sở hữu, tái kiểm quyền lúc chạy; kết quả TTL 7 ngày, feature flag; object storage tùy cấu hình. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/report-schedules | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:28` (GovernanceController.schedules) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| POST /api/v1/admin/report-schedules | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:29` (GovernanceController.createSchedule) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| PATCH /api/v1/admin/report-schedules/:id | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:30` (GovernanceController.updateSchedule) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| POST /api/v1/admin/report-schedules/:id/run | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:31` (GovernanceController.runSchedule) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| GET /api/v1/admin/report-schedules/:id/runs | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:32` (GovernanceController.runs) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| GET /api/v1/admin/report-runs/:id/download | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:35` (GovernanceController.download) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| POST /api/v1/admin/report-runs/:id/download-link | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:34` (GovernanceController.link) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |
| POST /api/v1/admin/report-runs/:id/retry | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:33` (GovernanceController.retry) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reports.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:92` (GovernanceService.schedules); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:93` (GovernanceService.createSchedule); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:94` (GovernanceService.updateSchedule); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:95` (GovernanceService.runSchedule); `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:45` (AdminReportWorkerService.runs); `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:72` (AdminReportWorkerService.verifyLink); `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:52` (AdminReportWorkerService.download); `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:62` (AdminReportWorkerService.downloadLink); `/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:80` (AdminReportWorkerService.retry).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:14`; `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:21`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2119` (AdminReportSchedule); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2139` (AdminReportRun).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_governance.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-168, F-169.

### UC-BIL-20 — Phân tích và xuất báo cáo vận hành

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đánh giá thu, chi, công nợ và công suất theo định nghĩa của báo cáo; xuất CSV khi có quyền tương ứng.
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/reports/monthly | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:18` (ReportsController.monthly) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: report.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/reports/analytics | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:38` (ReportsController.analytics) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: report.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |
| GET /api/v1/reports/monthly/export | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:28` (ReportsController.monthlyExport) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: report.export; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:18` (ReportsService.monthly); `/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:180` (ReportsService.analytics); `/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:141` (ReportsService.monthlyExport).
- DTO trực tiếp: Không có DTO class trực tiếp hoặc chức năng cục bộ; xem tham số handler, không dựng DTO giả.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/reports/reports_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-117, F-118.

### UC-OPS-09 — Tra cứu nhật ký vận hành

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc AuditLog thuộc chủ trọ theo bộ lọc
- Ranh giới: AuditController có decorator STAFF nhưng interceptor chặn toàn controller với STAFF. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/audit-logs | `/Users/hoang/Rental_room_management/backend/src/audit/audit.controller.ts:19` (AuditController.list) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: audit.view; bị interceptor chặn; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:26` (AuditService.list).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/audit/dto/list-audit-logs-query.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:346` (AuditLog).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/audit/audit_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/operations.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/authorization-ownership.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-120.

### UC-OPT-01 — Xem dashboard và bản đồ phòng

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Chủ trọ (A02); Nhân viên vận hành (A03). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Theo dõi chỉ số và mở phòng trong phạm vi được cấp
- Ranh giới: STAFF chỉ trong propertyIds được giao; permission chi tiết theo từng handler ở bảng truy vết.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/dashboard/metrics | `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.controller.ts:19` (DashboardController.metrics) | Roles(AuthRole.LANDLORD, AuthRole.STAFF) | STAFF: report.view; còn kiểm scope; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.ts:17` (DashboardService.metrics).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/dashboard/dto/dashboard-metrics-query.dto.ts:4`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1016` (DepositTransaction); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1159` (Invoice); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1435` (Expense).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/reports/reports_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/lease-billing-dashboard.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/reports/billing-analytics.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.spec.ts:1`.
- Mục khảo sát liên quan: F-116.

### UC-SUP-05.1 — Giám sát và xử lý sự cố vận hành

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc sự cố và thực hiện action đúng trạng thái
- Ranh giới: Quản trị nhận/giao/hoãn/xử lý sự cố; release summary có productionAccepted:false, không là xác nhận đạt production. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/operations/incidents | `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:29` (IncidentWorkflowController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| GET /api/v1/admin/operations/incidents/assignees | `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:30` (IncidentWorkflowController.assignees) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| GET /api/v1/admin/operations/incidents/:id | `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:31` (IncidentWorkflowController.detail) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| POST /api/v1/admin/operations/incidents/:id/actions | `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:32` (IncidentWorkflowController.action) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view AND admin.operations.manage |
| GET /api/v1/admin/operations/health | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:70` (AdminConsoleController.operationsHealth) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| POST /api/v1/admin/operations/incidents/:id/acknowledge | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:73` (AdminConsoleController.acknowledgeIncident) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.service.ts:18` (IncidentWorkflowService.list); `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.service.ts:14` (IncidentWorkflowService.assignees); `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.service.ts:36` (IncidentWorkflowService.detail); `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.service.ts:47` (IncidentWorkflowService.transition); `/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.ts:32` (OperationsHealthService.summary); `/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.ts:181` (OperationsHealthService.acknowledge).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:10`; `/Users/hoang/Rental_room_management/backend/src/health/incident-workflow.controller.ts:18`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:17`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1803` (DeliveryJob); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1824` (OperationsMetric); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1833` (WorkerHeartbeat); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1840` (OperationsIncident).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_workspace_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-operations-release.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.spec.ts:1`.
- Mục khảo sát liên quan: F-171, F-172.

### UC-SUP-05.2 — Theo dõi hàng đợi giao nhận

- Nhóm: G11 — Báo cáo và giám sát vận hành. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Đọc metadata job và thử lại notification đủ điều kiện
- Ranh giới: Theo dõi/retry job có code; chưa xác nhận dịch vụ giao nhận ngoài hệ thống. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/operations/delivery-jobs | `/Users/hoang/Rental_room_management/backend/src/health/operations-queue.controller.ts:18` (OperationsQueueController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| GET /api/v1/admin/operations/notification-delivery | `/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.controller.ts:14` (NotificationDeliveryController.queue) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view |
| POST /api/v1/admin/operations/notification-delivery/:id/retry | `/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.controller.ts:15` (NotificationDeliveryController.retry) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.operations.view AND admin.operations.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/health/operations-queue.service.ts:9` (OperationsQueueService.list); `/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.service.ts:83` (NotificationDeliveryService.queue); `/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.service.ts:89` (NotificationDeliveryService.retry).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/health/operations-queue.controller.ts:9`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1803` (DeliveryJob); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1824` (OperationsMetric); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1833` (WorkerHeartbeat); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1840` (OperationsIncident); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1983` (PlatformNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2198` (PlatformNotificationPreference); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2206` (PlatformNotificationDelivery).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_workspace_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-operations-release.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.spec.ts:1`.
- Mục khảo sát liên quan: F-156, F-173.

### UC-ADM-02 — Tra cứu tài khoản nền tảng

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc thông tin khách hàng được che theo projection
- Ranh giới: Console accounts cần accounts.view; endpoint /admin/landlords cũ cần accounts.manage. Không gộp thành quyền đọc mặc định cho cả hai. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/accounts | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:19` (AdminConsoleController.accounts) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.view |
| GET /api/v1/admin/accounts/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:22` (AdminConsoleController.account) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.view |
| GET /api/v1/admin/landlords | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:28` (AdminController.listLandlords) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.manage |
| GET /api/v1/admin/landlords/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:40` (AdminController.getLandlord) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` (AdminConsoleService.accounts); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:44` (AdminConsoleService.account); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:75` (AdminService.listLandlords); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:102` (AdminService.getLandlord).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/dto/list-landlords-query.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-124, F-133.

### UC-ADM-03.1 — Tạo hoặc mời tài khoản chủ trọ

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Tạo tài khoản LANDLORD hoặc công việc kích hoạt theo endpoint
- Ranh giới: Invite ADMIN/LANDLORD dùng cùng endpoint: mục tiêu này chỉ role=LANDLORD, cần dashboard.view + kiểm accounts.manage tại service; nhánh dev trực tiếp riêng. Nhánh mật khẩu trực tiếp giới hạn môi trường dev; nhánh lời mời phụ thuộc giao link ngoài. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/landlords | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:34` (AdminController.createLandlord) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.manage |
| POST /api/v1/admin/account-invites | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:37` (AdminConsoleController.invite) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:90` (AdminService.createLandlord); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:170` (AdminConsoleService.invite).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/dto/create-landlord.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:29`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-135, F-127.

### UC-ADM-03.2 — Cập nhật hồ sơ chủ trọ

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Sửa dữ liệu chủ trọ không thay quyền Admin
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| PATCH /api/v1/admin/landlords/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:46` (AdminController.updateLandlord) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:114` (AdminService.updateLandlord).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/dto/update-landlord.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-134.

### UC-ADM-04.1 — Đình chỉ hoặc khôi phục tài khoản

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ngừng/cho phép tài khoản tiếp tục hoạt động theo thẩm quyền, bảo toàn dữ liệu và hiệu lực thu hồi phiên.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/accounts/:id/suspend | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:25` (AdminConsoleController.suspend) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.suspend |
| PATCH /api/v1/admin/landlords/:id/status | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:52` (AdminController.updateLandlordStatus) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.suspend |
| POST /api/v1/admin/accounts/:id/restore | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:27` (AdminConsoleController.restore) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.suspend |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:56` (AdminConsoleService.status); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:125` (AdminService.updateLandlordStatus).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:17`; `/Users/hoang/Rental_room_management/backend/src/admin/dto/update-landlord-status.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-125.

### UC-ADM-04.3 — Thu hồi phiên của tài khoản khác

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Vô hiệu session và refresh token không xóa dữ liệu tài chính
- Ranh giới: Thu hồi khách hàng: sessions.revoke; thu hồi Admin khác: admins.manage và sessions.revoke cùng điều kiện service, không gán cùng quyền cho mọi loại tài khoản. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/accounts/:id/revoke-sessions | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:29` (AdminConsoleController.revoke) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.sessions.revoke |
| POST /api/v1/admin/admins/:id/revoke-sessions | `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.controller.ts:25` (AdminLifecycleController.revoke) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage AND admin.sessions.revoke |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:79` (AdminConsoleService.revoke); `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.service.ts:65` (AdminLifecycleService.revoke).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:17`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1902` (AdminStepUpGrant).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_security_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.spec.ts:1`.
- Mục khảo sát liên quan: F-125, F-145.

### UC-ADM-05.1 — Mở thông tin cá nhân được che

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xem dữ liệu cá nhân đang được che khi có lý do, quyền phù hợp và dấu vết kiểm tra.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/accounts/:id/reveal | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:31` (AdminConsoleController.reveal) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.pii.reveal |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:93` (AdminConsoleService.reveal).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-126.

### UC-ADM-05.2 — Yêu cầu khôi phục truy cập cho tài khoản

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Xếp hàng liên kết đặt mật khẩu không trả mật khẩu mới
- Ranh giới: Xếp hàng yêu cầu khôi phục; chưa xác nhận email thực. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/accounts/:id/reset-password | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:35` (AdminConsoleController.reset) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.accounts.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:192` (AdminConsoleService.reset).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-127.

### UC-ADM-06.1 — Cấp và quản lý quyền quản trị viên

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Cập nhật preset hoặc quyền trong tập được phép ủy quyền
- Ranh giới: Invite role=ADMIN cần dashboard.view, admins.manage, MFA và không vượt quyền người mời; preset mời chỉ support/moderator/analyst. Cập nhật tùy biến theo quyền super_admin; không tự đổi mình, giữ super_admin hoạt động cuối. Có cấp quyền/lời mời/gửi lại; giao nhận kích hoạt bên ngoài chưa được kiểm chứng. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/admins | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:39` (AdminConsoleController.admins) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| GET /api/v1/admin/admins/:id/access | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:41` (AdminConsoleController.adminAccess) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| PATCH /api/v1/admin/admins/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:44` (AdminConsoleController.profile) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| POST /api/v1/admin/account-invites | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:37` (AdminConsoleController.invite) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/admins/:id/lifecycle | `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.controller.ts:16` (AdminLifecycleController.detail) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| POST /api/v1/admin/admins/:id/resend-invite | `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.controller.ts:19` (AdminLifecycleController.resend) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` (AdminConsoleService.accounts); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:110` (AdminConsoleService.adminAccess); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:123` (AdminConsoleService.updateAdmin); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:170` (AdminConsoleService.invite); `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.service.ts:22` (AdminLifecycleService.detail); `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.service.ts:47` (AdminLifecycleService.resend).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:20`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:29`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:17`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1902` (AdminStepUpGrant).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_security_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.spec.ts:1`.
- Mục khảo sát liên quan: F-124, F-127, F-128, F-145.

### UC-ADM-06.2 — Rà soát quyền Admin định kỳ

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu kết quả rà soát và hạn rà soát tiếp theo cho người khác
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/permission-catalog | `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.controller.ts:17` (AdminAccessReviewController.catalog) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| GET /api/v1/admin/access-reviews | `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.controller.ts:18` (AdminAccessReviewController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| POST /api/v1/admin/access-reviews/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.controller.ts:20` (AdminAccessReviewController.review) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.service.ts:12` (AdminAccessReviewService.catalog); `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.service.ts:17` (AdminAccessReviewService.list); `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.service.ts:39` (AdminAccessReviewService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.controller.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1720` (RefreshToken); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1902` (AdminStepUpGrant).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_security_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/production-safety.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.spec.ts:1`.
- Mục khảo sát liên quan: F-145.

### UC-ADM-08 — Tra cứu khu và phòng toàn nền tảng

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc kho phòng và trạng thái tin tách biệt
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/properties | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:62` (AdminController.listProperties) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.view |
| GET /api/v1/admin/properties/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:75` (AdminController.getProperty) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.view |
| GET /api/v1/admin/rooms | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:82` (AdminController.rooms) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:133` (AdminService.listProperties); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:158` (AdminService.getProperty); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:162` (AdminService.rooms).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/dto/list-admin-properties-query.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/dto/list-admin-rooms-query.dto.ts:5`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-133.

### UC-ADM-09 — Tạo hoặc cập nhật khu thay chủ trọ

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Khai báo hoặc chỉnh thông tin khu trọ thay cho chủ trọ qua chức năng quản trị.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/properties | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:69` (AdminController.createProperty) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.manage |
| PATCH /api/v1/admin/properties/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:89` (AdminController.updateProperty) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:147` (AdminService.createProperty); `/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:189` (AdminService.updateProperty).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/dto/create-admin-property.dto.ts:3`; `/Users/hoang/Rental_room_management/backend/src/admin/dto/update-admin-property.dto.ts:3`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-134.

### UC-ADM-10 — Tìm kiếm và định vị tài nguyên

- Nhóm: G12 — Tài khoản và tài nguyên nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Trả kết quả từng loại được quyền đọc không vượt capability
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/search | `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.controller.ts:18` (AdminSearchController.searchAll) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/resources | `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.controller.ts:21` (AdminSearchController.resources) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/resources/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.controller.ts:24` (AdminSearchController.detail) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.service.ts:35` (AdminSearchService.search); `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.service.ts:119` (AdminSearchService.resources).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.dto.ts:21`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_search_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`.
- Mục khảo sát liên quan: F-136.

### UC-ADM-11 — Tiếp nhận và kiểm duyệt tin cho thuê

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Nhận/giao việc và quyết định công khai, từ chối hoặc ẩn tin; batch/preview là biến thể theo capability riêng.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/moderation/queue | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:62` (AdminConsoleController.queue) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| POST /api/v1/admin/moderation/work | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:64` (AdminConsoleController.work) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/moderation/items/:kind/:id | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:66` (AdminConsoleController.item) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/listings | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:100` (AdminListingsController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |
| POST /api/v1/admin/listings/:id/review | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:103` (AdminListingsController.review) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |
| POST /api/v1/admin/moderation-v2/bulk | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:31` (ModerationV2Controller.bulk) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.bulk |
| POST /api/v1/admin/moderation-v2/bulk/preview | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:32` (ModerationV2Controller.preview) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.bulk |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:238` (AdminConsoleService.queue); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:251` (AdminConsoleService.work); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:274` (AdminConsoleService.moderationItem); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:130` (ListingsService.review); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:124` (ModerationV2Service.bulk); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:145` (ModerationV2Service.preview).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:52`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:58`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:59`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:131`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:20`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1786` (ModerationWorkItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2024` (ModerationQualityReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2036` (ModerationPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2053` (ModerationAppeal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_moderation_v2.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-moderation-policy.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.spec.ts:1`.
- Mục khảo sát liên quan: F-088, F-090, F-130, F-159.

### UC-ADM-11.1 — Xác minh thông tin tin cho thuê

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Ghi trạng thái xác minh thông tin tin/chủ/phòng; tách với quyết định công khai và hồ sơ xác minh chủ trọ.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/listings | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:100` (AdminListingsController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |
| POST /api/v1/admin/listings/:id/verification | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:108` (AdminListingsController.verify) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:187` (ListingsService.verify).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:59`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:193`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-088, F-091.

### UC-ADM-12 — Kiểm duyệt đánh giá và phản hồi phòng

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chấp thuận/ẩn đánh giá và phản hồi của chủ trọ theo quyền kiểm duyệt đánh giá.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/room-reviews | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:52` (AdminRoomReviewsController.queue) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reviews.moderate |
| POST /api/v1/admin/room-reviews/:id/moderate | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:55` (AdminRoomReviewsController.moderate) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reviews.moderate |
| POST /api/v1/admin/room-reviews/:id/reply/moderate | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:60` (AdminRoomReviewsController.reply) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.reviews.moderate |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:140` (ReviewsService.queue); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:111` (ReviewsService.moderate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:15`; `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:55`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:964` (RoomReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/review_composer.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-108.

### UC-ADM-12.1 — Xử lý báo cáo vi phạm tin đăng

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kết luận báo cáo về tin đăng để xử lý nội dung bị phản ánh theo quyền kiểm duyệt tin.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/listings/reports | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:92` (AdminListingsController.reports) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |
| POST /api/v1/admin/listings/reports/:id/review | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:95` (AdminListingsController.reviewReport) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:230` (ListingsService.reports); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:239` (ListingsService.reviewReport).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:11`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:185`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-092.

### UC-ADM-13.1 — Quản lý chính sách kiểm duyệt

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Quản lý các phiên bản chính sách kiểm duyệt và xác định bản đang hiệu lực.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/moderation-policies | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:19` (ModerationPolicyController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |
| POST /api/v1/admin/moderation-policies | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:24` (ModerationPolicyController.create) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |
| POST /api/v1/admin/moderation-policies/:id/activate | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:25` (ModerationPolicyController.activate) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.admins.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:12` (ModerationPolicyService.list); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:16` (ModerationPolicyService.create); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:27` (ModerationPolicyService.activate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1786` (ModerationWorkItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2024` (ModerationQualityReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2036` (ModerationPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2053` (ModerationAppeal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_moderation_v2.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-moderation-policy.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.spec.ts:1`.
- Mục khảo sát liên quan: F-160.

### UC-ADM-13.2 — Xử lý kháng nghị kiểm duyệt

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Phân công và đưa ra kết luận độc lập về kháng nghị đối với quyết định kiểm duyệt.
- Ranh giới: Reviewer không là người ra quyết định gốc; cần quyền kháng nghị và quyền nội dung tương ứng theo service. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/moderation-v2/decisions | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:26` (ModerationV2Controller.decisions) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |
| GET /api/v1/admin/moderation-v2/history/:kind/:id | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:27` (ModerationV2Controller.history) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| GET /api/v1/admin/moderation-v2/appeals | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:28` (ModerationV2Controller.appeals) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.appeals |
| POST /api/v1/admin/moderation-v2/appeals/:id/assign | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:29` (ModerationV2Controller.assign) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.appeals |
| POST /api/v1/admin/moderation-v2/appeals/:id/resolve | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:30` (ModerationV2Controller.resolve) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.appeals |
| GET /api/v1/admin/moderation-v2/reports | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:33` (ModerationV2Controller.reports) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:27` (ModerationV2Service.decisions); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:38` (ModerationV2Service.history); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:59` (ModerationV2Service.appeals); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:73` (ModerationV2Service.assign); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:89` (ModerationV2Service.resolve); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:180` (ModerationV2Service.reports).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:6`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:13`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:10`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:67`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1786` (ModerationWorkItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2024` (ModerationQualityReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2036` (ModerationPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2053` (ModerationAppeal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_moderation_v2.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-moderation-policy.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.spec.ts:1`.
- Mục khảo sát liên quan: F-157, F-158.

### UC-ADM-13.3 — Đánh giá chất lượng kiểm duyệt

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lấy mẫu và đánh giá quyết định không tự đánh giá mình
- Ranh giới: Đánh giá độc lập với người ra quyết định; không tự áp chế tài. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/moderation-policies/quality | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:20` (ModerationPolicyController.quality) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |
| GET /api/v1/admin/moderation-policies/quality/samples | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:21` (ModerationPolicyController.samples) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |
| GET /api/v1/admin/moderation-policies/quality/samples/:id | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:22` (ModerationPolicyController.sample) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |
| POST /api/v1/admin/moderation-policies/quality/samples/:id/review | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:23` (ModerationPolicyController.review) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.moderation.reports |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:40` (ModerationPolicyService.quality); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.ts:20` (ModerationQualityService.samples); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.ts:42` (ModerationQualityService.detail); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.ts:60` (ModerationQualityService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.dto.ts:15`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.dto.ts:22`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1786` (ModerationWorkItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2024` (ModerationQualityReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2036` (ModerationPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2053` (ModerationAppeal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_moderation_v2.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-moderation-policy.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.spec.ts:1`.
- Mục khảo sát liên quan: F-161.

### UC-DIS-07 — Báo cáo tin phòng không phù hợp

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi ListingReport để admin xử lý
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/student/listings/:id/reports | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:33` (StudentListingsController.report) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:217` (ListingsService.report).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:178`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-092.

### UC-DIS-12 — Viết sửa và rút đánh giá phòng đã thuê

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi nội dung gắn hợp đồng đủ điều kiện để kiểm duyệt
- Ranh giới: Cần bàn giao đã chấp nhận hoặc nhánh lịch sử thuê đã kết thúc đủ điều kiện; sửa đưa lại chờ duyệt; rút không cho admin đăng lại tùy ý.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/reviews/leases/:id | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:20` (RoomReviewsController.context) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/reviews/leases/:id | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:23` (RoomReviewsController.create) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| PATCH /api/v1/reviews/:id | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:28` (RoomReviewsController.update) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| DELETE /api/v1/reviews/:id | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:33` (RoomReviewsController.withdraw) | Roles(AuthRole.TENANT) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:41` (ReviewsService.context); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:51` (ReviewsService.create); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:72` (ReviewsService.update); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:87` (ReviewsService.withdraw).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:23`; `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:45`; `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:40`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:964` (RoomReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/review_composer.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-105, F-106.

### UC-DIS-13.1 — Trả lời đánh giá phòng

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Chủ trọ (A02). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi phản hồi của chủ trọ qua kiểm duyệt riêng
- Ranh giới: Chỉ trong phạm vi dữ liệu và trạng thái service cho phép.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/reviews/landlord | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:38` (RoomReviewsController.landlord) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/reviews/:id/reply | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:41` (RoomReviewsController.reply) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:134` (ReviewsService.landlord); `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:99` (ReviewsService.reply).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:7`; `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.dto.ts:50`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:928` (Lease); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:964` (RoomReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/review_composer.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-107.

### UC-DIS-15 — Xem quyết định và gửi kháng nghị kiểm duyệt

- Nhóm: G13 — Kiểm duyệt và chất lượng nội dung. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đề nghị xem lại quyết định thuộc tài nguyên của mình
- Ranh giới: Chỉ quyết định bất lợi thuộc ownerId của mình, trong 14 ngày và chưa bị thay thế/kháng nghị trùng. ADMIN chỉ có đường đọc/gửi cho tài nguyên chính mình nếu có, không mặc định quyền của chủ trọ. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/moderation/decisions | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:16` (MyModerationController.decisions) | Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |
| GET /api/v1/moderation/appeals | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:17` (MyModerationController.appeals) | Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |
| POST /api/v1/moderation/appeals | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:18` (MyModerationController.appeal) | Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |
| GET /api/v1/moderation/features | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:19` (MyModerationController.features) | Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:27` (ModerationV2Service.decisions); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:59` (ModerationV2Service.appeals); `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:42` (ModerationV2Service.appeal); `/Users/hoang/Rental_room_management/backend/src/platform/feature-flags.service.ts:29` (FeatureFlagsService.effective).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:6`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.dto.ts:5`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1786` (ModerationWorkItem); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2000` (ModerationDecision); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2024` (ModerationQualityReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2036` (ModerationPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2053` (ModerationAppeal); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2085` (FeatureFlag); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2095` (AdminTeam); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2107` (AdminTeamMember).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_moderation_v2.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_governance.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-moderation-policy.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-157, F-158, F-164.

### UC-SUP-01 — Gửi và theo dõi yêu cầu hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Tạo hồ sơ hỗ trợ của mình, trao đổi với người xử lý và theo dõi kết quả; mở lại bằng phản hồi trong thời hạn cho phép.
- Ranh giới: Ticket của requester; nội dung internal không công khai; trả lời mở lại RESOLVED trong 7 ngày, CLOSED không trả lời. Có feature flag support.user_tickets. Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Luồng ticket có triển khai; biến thể tệp đính kèm fail-closed khi scanner chưa có, chưa xác nhận scanner thật. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/support/tickets | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:15` (SupportController.create) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |
| GET /api/v1/support/tickets | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:16` (SupportController.list) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| GET /api/v1/support/tickets/:id | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:19` (SupportController.detail) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| POST /api/v1/support/tickets/:id/replies | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:20` (SupportController.reply) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| POST /api/v1/support/tickets/:id/attachments | `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.controller.ts:16` (SupportAttachmentController.upload) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read AND admin.support.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:46` (SupportService.create); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:63` (SupportService.list); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:91` (SupportService.detail); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:104` (SupportService.reply); `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.service.ts:25` (SupportAttachmentService.upload).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:12`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:27`; `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:23`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-146, F-151.

### UC-SUP-01.1 — Tiếp nhận và xử lý hồ sơ hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Một phần.
- Mục tiêu: Nhận/giao hồ sơ, phản hồi công khai, ghi chú nội bộ và kết thúc xử lý theo quyền, phạm vi người xử lý.
- Ranh giới: Controller cho nhiều role nhưng service.manage đòi ADMIN support.read/manage; không phải mọi chủ trọ/TENANT đều ghi chú, giao việc hay đổi trạng thái. Tệp tối đa 8MB, tối đa 20/ticket; chỉ CLEAN/hash hợp lệ; scanner chưa có thì fail-closed. Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Quyền xử lý ticket có code; tệp kèm cần scanner/storage và chưa kiểm chứng runtime ngoài. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/support/tickets | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:16` (SupportController.list) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| GET /api/v1/support/tickets/assignees | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:17` (SupportController.assignees) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.manage |
| GET /api/v1/support/tickets/teams | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:18` (SupportController.teams) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.manage |
| GET /api/v1/support/tickets/:id | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:19` (SupportController.detail) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| POST /api/v1/support/tickets/:id/replies | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:20` (SupportController.reply) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| POST /api/v1/support/tickets/:id/notes | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:21` (SupportController.note) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| PATCH /api/v1/support/tickets/:id/assignment | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:22` (SupportController.assign) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| PATCH /api/v1/support/tickets/:id/status | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:23` (SupportController.status) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read |
| POST /api/v1/admin/support-context | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:59` (AdminConsoleController.context) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read |
| POST /api/v1/support/tickets/:id/attachments | `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.controller.ts:16` (SupportAttachmentController.upload) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.support.read AND admin.support.manage |
| POST /api/v1/admin/support-cases/:id/timeline | `/Users/hoang/Rental_room_management/backend/src/support/support-case.controller.ts:20` (SupportCaseController.timeline) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read |
| POST /api/v1/admin/support-cases/:id/links | `/Users/hoang/Rental_room_management/backend/src/support/support-case.controller.ts:22` (SupportCaseController.link) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| PATCH /api/v1/support/tickets/:id/labels | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:21` (SupportToolsController.labels) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:63` (SupportService.list); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:39` (SupportService.assignees); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:43` (SupportService.teams); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:91` (SupportService.detail); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:104` (SupportService.reply); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:142` (SupportService.note); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:125` (SupportService.assign); `/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:143` (SupportService.status); `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:210` (AdminConsoleService.context); `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.service.ts:25` (SupportAttachmentService.upload); `/Users/hoang/Rental_room_management/backend/src/support/support-case.service.ts:33` (SupportCaseService.timeline); `/Users/hoang/Rental_room_management/backend/src/support/support-case.service.ts:57` (SupportCaseService.link); `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:26` (SupportToolsService.labels).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:12`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:27`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:32`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:37`; `/Users/hoang/Rental_room_management/backend/src/support/support.dto.ts:45`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:48`; `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:23`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`; `/Users/hoang/Rental_room_management/backend/src/support/support-case.controller.ts:10`; `/Users/hoang/Rental_room_management/backend/src/support/support-tools.dto.ts:5`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:177` (User); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1738` (AuthSession); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1755` (AdminProfile); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_accounts_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-accounts.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-inventory.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-console.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-accounts.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-129, F-146, F-147, F-148, F-151, F-152.

### UC-SUP-02.1 — Cấu hình phân công tự động hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đặt skills và phân công theo khả dụng của người xử lý
- Ranh giới: skills/autoAssign cần đồng thời support.read, support.manage, admins.manage theo metadata; không tạo Actor Agent độc lập với ADMIN. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/support/skills | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:18` (SupportWorkflowController.skills) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage AND admin.admins.manage |
| PATCH /api/v1/support/skills/:id | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:19` (SupportWorkflowController.setSkills) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage AND admin.admins.manage |
| POST /api/v1/support/tickets/:id/auto-assign | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:20` (SupportWorkflowController.autoAssign) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage AND admin.admins.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:43` (SupportWorkflowService.skills); `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:47` (SupportWorkflowService.setSkills); `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:60` (SupportWorkflowService.autoAssign).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:12`; `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:18`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-150.

### UC-SUP-02.2 — Cấu hình và theo dõi SLA hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu lịch giờ làm và chính sách thời hạn hỗ trợ
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/support-sla-policy | `/Users/hoang/Rental_room_management/backend/src/support/support-sla.controller.ts:14` (SupportSlaController.policy) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage AND admin.admins.manage |
| PATCH /api/v1/admin/support-sla-policy | `/Users/hoang/Rental_room_management/backend/src/support/support-sla.controller.ts:15` (SupportSlaController.update) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage AND admin.admins.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-sla.service.ts:25` (SupportSlaService.policy); `/Users/hoang/Rental_room_management/backend/src/support/support-sla.service.ts:36` (SupportSlaService.update).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-sla.dto.ts:11`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1917` (SupportSlaPolicy); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1934` (SupportEscalation); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1983` (PlatformNotification).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_sla_policy_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-operations-release.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/support/business-calendar.spec.ts:1`.
- Mục khảo sát liên quan: F-153, F-154.

### UC-SUP-03.2 — Quản lý mẫu trả lời hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì bộ mẫu phản hồi phục vụ trả lời hỗ trợ nhất quán.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/support/templates | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:18` (SupportToolsController.templates) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| POST /api/v1/support/templates | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:19` (SupportToolsController.create) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| PATCH /api/v1/support/templates/:id | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:20` (SupportToolsController.update) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:71` (SupportToolsService.templates); `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:75` (SupportToolsService.saveTemplate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.dto.ts:23`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-148.

### UC-SUP-03.2.1 — Hợp nhất hồ sơ hỗ trợ trùng

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Liên kết hồ sơ trùng về hồ sơ chính có kiểm soát, tránh xử lý lặp và giữ lịch sử.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/support/tickets/:id/merge | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:22` (SupportToolsController.merge) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:50` (SupportToolsService.merge).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.dto.ts:17`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-148.

### UC-SUP-03.2.2 — Đánh giá kết quả hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Chủ trọ (A02); Người tìm phòng/người thuê (A04); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Gửi phản hồi một lần cho hồ sơ của mình đã được giải quyết/đóng.
- Ranh giới: Requester đúng ticket; một lần sau RESOLVED/CLOSED, không ticket đã merged. Có handler khai báo STAFF nhưng bị PropertyScopeInterceptor chặn; không cấp quyền chính từ decorator này. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/support/tickets/:id/feedback | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:23` (SupportToolsController.feedback) | Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT) | STAFF: không khai báo metadata permission; bị interceptor chặn; ADMIN: admin.dashboard.view |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:37` (SupportToolsService.feedback).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-tools.dto.ts:11`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-149.

### UC-SUP-03.3 — Lưu bộ lọc xử lý hỗ trợ

- Nhóm: G14 — Dịch vụ hỗ trợ khách hàng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Lưu bộ lọc riêng để quay lại tập hồ sơ hỗ trợ cần xử lý.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/support/views | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:14` (SupportWorkflowController.views) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| POST /api/v1/support/views | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:15` (SupportWorkflowController.createView) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| PATCH /api/v1/support/views/:id | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:16` (SupportWorkflowController.updateView) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |
| DELETE /api/v1/support/views/:id | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:17` (SupportWorkflowController.deleteView) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.support.read AND admin.support.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:14` (SupportWorkflowService.views); `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:18` (SupportWorkflowService.saveView); `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:37` (SupportWorkflowService.deleteView).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1862` (SupportTicket); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1946` (SupportCaseLink); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1958` (SupportMessage); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2163` (SupportAttachment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2177` (SupportSavedView); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2189` (SupportAgentSkill).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_support_center.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-support-tools.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-roadmap-inboxes.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-150.

### UC-ADM-18 — Xét duyệt hồ sơ xác minh chủ trọ

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Xét hồ sơ và chứng cứ của chủ trọ để ghi quyết định xác minh có kiểm soát thay đổi.
- Ranh giới: Hai vai trò dùng endpoint khác nhau; không gán quyền xét duyệt cho chủ trọ. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/landlord-verifications | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:21` (AdminRegistryController.verifications) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.verifications.view AND admin.support.read |
| POST /api/v1/admin/landlord-verifications/:id/review | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:27` (AdminRegistryController.reviewVerification) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.verifications.manage AND admin.support.read |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:22` (AdminVerificationService.list); `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:56` (AdminVerificationService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:22`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-137.

### UC-ADM-18.1 — Nộp hồ sơ xác minh chủ trọ

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Chủ trọ (A02); Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cung cấp hồ sơ và bằng chứng hỗ trợ để được xét xác minh chủ trọ.
- Ranh giới: Hai vai trò dùng endpoint khác nhau; không gán quyền xét duyệt cho chủ trọ. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/landlord-verification | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:62` (LandlordVerificationController.own) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/landlord-verification | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:64` (LandlordVerificationController.submit) | Roles(AuthRole.LANDLORD) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: không metadata ADMIN; xem guard/controller |
| POST /api/v1/admin/landlord-verifications | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:24` (AdminRegistryController.submitVerification) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.verifications.manage AND admin.support.read |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:15` (AdminVerificationService.own); `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:34` (AdminVerificationService.submit).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:17`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:11`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-137.

### UC-ADM-19 — Trình và xét duyệt hồ sơ khu trọ

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duyệt snapshot khu khi thông tin chưa thay đổi
- Ranh giới: Trình/xét khu ở đây do ADMIN có properties.manage; chưa có bằng chứng chủ trọ tự trình. Hồ sơ xét khu khác verified của tin. Endpoint trình hồ sơ khu hiện dành ADMIN; không ghi bước này do LANDLORD thực hiện. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/property-reviews | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:30` (AdminRegistryController.propertyReviews) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.view |
| POST /api/v1/admin/properties/:id/submit-review | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:33` (AdminRegistryController.submitProperty) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.manage |
| POST /api/v1/admin/property-reviews/:id/review | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:36` (AdminRegistryController.reviewProperty) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.properties.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-property-review.service.ts:16` (AdminPropertyReviewService.list); `/Users/hoang/Rental_room_management/backend/src/admin/admin-property-review.service.ts:29` (AdminPropertyReviewService.submit); `/Users/hoang/Rental_room_management/backend/src/admin/admin-property-review.service.ts:48` (AdminPropertyReviewService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:27`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:22`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-138.

### UC-ADM-20 — Quản lý danh mục gói dịch vụ

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Quản lý nội dung, phiên bản điều khoản và hạn mức của các gói dịch vụ.
- Ranh giới: Quản lý phiên bản điều khoản/hạn mức; đọc plans.view, ghi plans.manage. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/service-plans | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:39` (AdminRegistryController.servicePlans) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.view |
| POST /api/v1/admin/service-plans | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:42` (AdminRegistryController.savePlan) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:19` (AdminPlansService.plans); `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:29` (AdminPlansService.save).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:31`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-139.

### UC-ADM-21 — Gán gói và xem lịch sử đăng ký

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Cấp gói dịch vụ cho chủ trọ và tra cứu lịch sử quyền sử dụng đã ghi nhận.
- Ranh giới: Chỉ gán gói và lịch sử, không có UC thanh toán mua gói. Quota chỉ áp nếu đã có subscription; hết hạn chặn tăng inventory, không xóa dữ liệu. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/subscriptions | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:45` (AdminRegistryController.subscriptions) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.view |
| GET /api/v1/admin/subscriptions/:id/events | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:48` (AdminRegistryController.subscriptionEvents) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.view |
| POST /api/v1/admin/landlords/:id/subscription | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:51` (AdminRegistryController.assignSubscription) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:52` (AdminPlansService.subscriptions); `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:62` (AdminPlansService.history); `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:74` (AdminPlansService.assign).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:42`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-140.

### UC-ADM-22 — Hủy quyền sử dụng gói đang hiệu lực

- Nhóm: G15 — Hồ sơ xác minh và gói dịch vụ. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kết thúc hiệu lực không tự hoàn tiền hoặc xóa khu phòng
- Ranh giới: Chấm dứt quyền dùng gói không tự hoàn tiền, không xóa khu/phòng. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/subscriptions/:id/cancel | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:54` (AdminRegistryController.cancelSubscription) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.plans.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:109` (AdminPlansService.cancel).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.dto.ts:48`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`.
- Mục khảo sát liên quan: F-140.

### UC-ADM-15 — Chuẩn bị đối soát sao kê

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Nhập sao kê, tra cứu ứng viên và lập đề xuất ghép/bỏ ghép với chứng từ sẵn có.
- Ranh giới: Nhập sao kê và đề xuất ghép chứng từ đã có; không suy ra kết nối tài khoản ngân hàng trực tiếp. Đối soát tham chiếu khoản thu đã có; không đồng nghĩa tự nhận tiền ngân hàng hoặc tự ghi Payment. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/finance/statements | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:14` (FinanceReconciliationController.importStatement) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |
| GET /api/v1/admin/finance/statement-lines | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:15` (FinanceReconciliationController.lines) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read |
| POST /api/v1/admin/finance/statement-lines/:id/proposals | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:16` (FinanceReconciliationController.propose) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |
| GET /api/v1/admin/finance/statement-lines/:id/candidates | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:17` (FinanceReconciliationController.candidates) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |
| GET /api/v1/admin/finance/reconciliation-proposals | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:18` (FinanceReconciliationController.proposals) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:18` (FinanceReconciliationService.importStatement); `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:95` (FinanceReconciliationService.lines); `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:100` (FinanceReconciliationService.propose); `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:81` (FinanceReconciliationService.candidates); `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:126` (FinanceReconciliationService.proposals).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.dto.ts:12`; `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.dto.ts:31`; `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.dto.ts:20`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2224` (FinanceStatement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2237` (FinanceStatementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2259` (FinanceReconciliationProposal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_finance_workflow.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.spec.ts:1`.
- Mục khảo sát liên quan: F-166, F-167.

### UC-ADM-15.1 — Duyệt đề xuất đối soát sao kê

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Chấp thuận/từ chối đề xuất ghép hoặc bỏ ghép do người khác lập, không thực hiện chuyển tiền.
- Ranh giới: Checker phải khác maker dù cùng role/capability; chỉ ghi kết quả đối soát, không chuyển tiền. Đối soát tham chiếu khoản thu đã có; không đồng nghĩa tự nhận tiền ngân hàng hoặc tự ghi Payment. ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/finance/reconciliation-proposals | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:18` (FinanceReconciliationController.proposals) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |
| POST /api/v1/admin/finance/reconciliation-proposals/:id/approve | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:19` (FinanceReconciliationController.approve) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |
| POST /api/v1/admin/finance/reconciliation-proposals/:id/reject | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:20` (FinanceReconciliationController.reject) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read AND admin.finance.reconcile |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:126` (FinanceReconciliationService.proposals); `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:131` (FinanceReconciliationService.review).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.dto.ts:27`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2224` (FinanceStatement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2237` (FinanceStatementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2259` (FinanceReconciliationProposal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_finance_workflow.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.spec.ts:1`.
- Mục khảo sát liên quan: F-167.

### UC-ADM-17.1 — Cấu hình bật tắt tính năng nền tảng

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Kiểm soát bật/tắt và phạm vi triển khai tính năng theo người dùng/vai trò trong các khóa cho phép.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/feature-flags | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:24` (GovernanceController.flagsList) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.flags.manage |
| GET /api/v1/admin/feature-flags/effective | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:25` (GovernanceController.effective) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.dashboard.view |
| PATCH /api/v1/admin/feature-flags/:key | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:26` (GovernanceController.flagsUpdate) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.flags.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:70` (GovernanceService.flagsList); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:71` (GovernanceService.flagsEffective); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:72` (GovernanceService.flagsUpdate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/feature-flags.service.ts:10`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2085` (FeatureFlag); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2095` (AdminTeam); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2107` (AdminTeamMember).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_governance.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-164.

### UC-ADM-17.2 — Quản lý nhóm Admin

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì nhóm quản trị và thành viên để tổ chức xử lý công việc nền tảng.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/team | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:17` (GovernanceController.team) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |
| GET /api/v1/admin/teams | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:18` (GovernanceController.teams) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |
| POST /api/v1/admin/teams | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:19` (GovernanceController.createTeam) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |
| POST /api/v1/admin/teams/:id/members | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:20` (GovernanceController.addMember) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |
| PATCH /api/v1/admin/teams/:id | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:21` (GovernanceController.updateTeam) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |
| POST /api/v1/admin/teams/:id/members/:userId/remove | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:22` (GovernanceController.removeMember) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.teams.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:16` (GovernanceService.team); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:20` (GovernanceService.teams); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:24` (GovernanceService.createTeam); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:28` (GovernanceService.addMember); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:40` (GovernanceService.updateTeam); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:49` (GovernanceService.removeMember).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:5`; `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:6`; `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:7`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.dto.ts:14`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2085` (FeatureFlag); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2095` (AdminTeam); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2107` (AdminTeamMember).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_governance.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-162.

### UC-ADM-23 — Quản lý danh mục cơ sở trường

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Duy trì dữ liệu cơ sở trường phục vụ tìm phòng theo vị trí.
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/campuses | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:21` (AdminCampusesController.list) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.campuses.manage |
| POST /api/v1/admin/campuses | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:23` (AdminCampusesController.create) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.campuses.manage |
| PATCH /api/v1/admin/campuses/:id | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:25` (AdminCampusesController.update) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.campuses.manage |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:182` (ListingsService.campuses); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:196` (ListingsService.createCampus); `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:200` (ListingsService.updateCampus).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:144`; `/Users/hoang/Rental_room_management/backend/src/listings/listings.dto.ts:161`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:369` (Property); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:486` (Room); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:531` (RoomListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:657` (SchoolCampus); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:710` (ListingReport).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/explore_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/security-discovery.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/explore-preview-images.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-093.

### UC-ADM-24 — Tra cứu giao dịch tài chính nền tảng

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc dữ liệu giao dịch theo projection quản trị
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/admin/finance/transactions | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:18` (AdminRegistryController.transactionList) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read |
| GET /api/v1/admin/finance/reconciliation | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:27` (GovernanceController.finance) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.finance.read |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/admin/admin-transactions.service.ts:24` (AdminTransactionsService.list); `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:73` (GovernanceService.finance).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/admin/admin-transactions.service.ts:9`; `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:9`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:410` (LandlordVerification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:427` (PropertyApprovalReview); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:443` (ServicePlan); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:459` (LandlordSubscription); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:473` (SubscriptionEvent); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1226` (Payment); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1274` (BillingReceipt); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2224` (FinanceStatement); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2237` (FinanceStatementLine); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2259` (FinanceReconciliationProposal).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_registry_screen.dart:1`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_finance_workflow.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-registry.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.service.spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-completion.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.spec.ts:1`.
- Mục khảo sát liên quan: F-141, F-165.

### UC-ADM-26 — Mô phỏng quyền Admin

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Tính quyền được phép không thay hồ sơ cấp quyền
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| POST /api/v1/admin/permissions/simulate | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:23` (GovernanceController.simulate) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.permissions.simulate |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:62` (GovernanceService.simulate).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/platform/governance.dto.ts:8`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2085` (FeatureFlag); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2095` (AdminTeam); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:2107` (AdminTeamMember).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/admin/admin_governance.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/admin-sprints.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/admin-next-sprints.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-163.

### UC-ADM-27 — Đọc phản hồi thử nghiệm tìm phòng

- Nhóm: G16 — Quản trị chính sách và đối soát nền tảng. Actor chính: Quản trị viên nền tảng (A05). Trạng thái: Xác minh tĩnh.
- Mục tiêu: Đọc PilotFeedback và thống kê theo trang
- Ranh giới: ADMIN cần toàn bộ capability của handler và điều kiện service; không tự thừa hưởng nghiệp vụ LANDLORD.

| API | Controller/handler | Role khai báo | Quyền và hạn chế |
| --- | --- | --- | --- |
| GET /api/v1/housing/feedback | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:98` (HousingController.feedbackList) | Roles(AuthRole.ADMIN) | STAFF: không khai báo metadata permission; không role STAFF; ADMIN: admin.listings.moderate |

- Hành vi nghiệp vụ: `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:327` (HousingService.feedbackList).
- DTO trực tiếp: `/Users/hoang/Rental_room_management/backend/src/housing/housing.dto.ts:6`.
- Dữ liệu liên quan: `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:580` (SavedListing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:591` (RoomViewing); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:620` (ViewingSlot); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:632` (HousingNotification); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:644` (PilotFeedback); `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:1002` (LeaseHandover).
- UI liên quan: `/Users/hoang/Rental_room_management/lib/features/listings/housing_screen.dart:1`.
- Test liên quan (chỉ đọc, không chạy đợt này): `/Users/hoang/Rental_room_management/backend/test/e2e/housing.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/listings.e2e-spec.ts:1`; `/Users/hoang/Rental_room_management/backend/test/e2e/reviews.e2e-spec.ts:1`.
- Mục khảo sát liên quan: F-104.

## 3. Toàn bộ 180 mục khảo sát và nơi tiếp nhận

Mã F được cấp trong gói này để kiểm tra coverage khảo sát, không là UC cũ hay tuyên bố tài liệu Giai đoạn 1 đã được xuất. Một mục có thể phục vụ nhiều UC hoặc TECH; trạng thái cột này phản ánh phạm vi mục khảo sát, không thay trạng thái UC hiện tại.

| Mã khảo sát | Chức năng đã đọc | Trạng thái khảo sát | UC tiếp nhận | TECH/GAP | Bằng chứng |
| --- | --- | --- | --- | --- | --- |
| F-001 | Đăng ký chủ trọ | Đã triển khai | UC-SYS-01 | — | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:18` (AuthController.register)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:37` (AuthService.register) |
| F-002 | Đăng ký người tìm trọ | Đã triển khai | UC-SYS-02 | — | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:25` (AuthController.registerSeeker)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:41` (AuthService.registerSeeker) |
| F-003 | Đăng nhập và thông tin tài khoản | Đã triển khai | UC-SYS-03 | — | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:32` (AuthController.login)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:71` (AuthService.login) |
| F-004 | Làm mới phiên | Đã triển khai | Không thành UC độc lập | TECH-01 | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:38` (AuthController.refresh)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:91` (AuthService.refresh) |
| F-005 | Đăng xuất và đổi mật khẩu | Đã triển khai | UC-SYS-05.1, UC-SYS-07 | — | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:44` (AuthController.logout)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:137` (AuthService.logout) |
| F-006 | Yêu cầu khôi phục và kích hoạt tài khoản | Triển khai một phần | UC-SYS-06, UC-SYS-10 | — | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.controller.ts:19` (AccountAccessController.forgot)<br>`/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:47` (AccountAccessService.forgot) |
| F-007 | Danh sách nhân viên và preset | Đã triển khai | UC-STF-01, UC-STF-04 | — | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:25` (StaffController.presets)<br>`/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:54` (StaffService.list) |
| F-008 | Mời và nhận lời mời nhân viên | Đã triển khai | UC-SYS-09, UC-STF-01 | — | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:39` (StaffController.createInvite)<br>`/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:64` (StaffService.createInvite) |
| F-009 | Cập nhật quyền, scope và trạng thái nhân viên | Đã triển khai | UC-STF-02 | — | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:64` (StaffController.update)<br>`/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:161` (StaffService.update) |
| F-010 | Mô phỏng quyền nhân viên theo khu trọ | Đã triển khai | UC-STF-03 | — | `/Users/hoang/Rental_room_management/backend/src/staff/staff.controller.ts:90` (StaffController.simulate)<br>`/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:211` (StaffService.simulate) |
| F-011 | Tra cứu danh sách và chi tiết khu trọ | Đã triển khai | UC-OPT-02 | — | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:37` (PropertiesController.list)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:42` (PropertiesService.list) |
| F-012 | Tạo khu trọ | Đã triển khai | UC-OPT-03.1 | — | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:43` (PropertiesController.create)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:61` (PropertiesService.create) |
| F-013 | Cập nhật khu trọ | Đã triển khai | UC-OPT-03.2 | — | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:66` (PropertiesController.update)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:76` (PropertiesService.update) |
| F-014 | Lưu trữ và khôi phục khu trọ | Đã triển khai | UC-OPT-04.1 | — | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:87` (PropertiesController.updateStatus)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:89` (PropertiesService.updateStatus) |
| F-015 | Xóa khu trọ có điều kiện | Đã triển khai | UC-OPT-04.3 | — | `/Users/hoang/Rental_room_management/backend/src/properties/properties.controller.ts:108` (PropertiesController.remove)<br>`/Users/hoang/Rental_room_management/backend/src/properties/properties.service.ts:116` (PropertiesService.remove) |
| F-016 | Danh sách và chi tiết phòng | Đã triển khai | UC-OPT-05 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:44` (PropertyRoomsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:92` (RoomsService.listByProperty) |
| F-017 | Tạo và sửa phòng | Đã triển khai | UC-OPT-06.1, UC-OPT-06.2, UC-OPT-07.1 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:54` (PropertyRoomsController.create)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:115` (RoomsService.create) |
| F-018 | Thay đổi trạng thái và ngừng/khôi phục phòng | Đã triển khai | UC-OPT-07.2 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:112` (RoomsController.updateStatus)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:166` (RoomsService.updateStatus) |
| F-019 | Xóa phòng có điều kiện | Đã triển khai | UC-OPT-07.3 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:133` (RoomsController.remove)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:190` (RoomsService.remove) |
| F-020 | Quản lý tài sản phòng | Đã triển khai | UC-OPT-08.1 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:152` (RoomsController.assets)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:203` (RoomsService.assets) |
| F-021 | Lập và hoàn tất kiểm tra phòng | Đã triển khai | UC-OPT-08.2 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:222` (RoomsController.inspections)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:268` (RoomsService.inspections) |
| F-022 | Phí dịch vụ phòng và lịch sử phiên bản | Đã triển khai | UC-OPT-09 | — | `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:322` (RoomsController.serviceFees)<br>`/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:340` (RoomsService.serviceFees) |
| F-023 | Tra cứu, tạo và sửa hồ sơ người thuê | Đã triển khai | UC-TNT-01, UC-TNT-02.1, UC-TNT-02.2 | — | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:38` (TenantsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:116` (TenantsService.list) |
| F-024 | Tổng quan tài chính và lịch sử người thuê | Đã triển khai | UC-TNT-01 | — | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:67` (TenantsController.overview)<br>`/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:141` (TenantsService.overview) |
| F-025 | Ngừng hoạt động/khôi phục và xóa người thuê | Đã triển khai | UC-TNT-02.3, UC-TNT-02.4 | — | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:115` (TenantsController.updateStatus)<br>`/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:279` (TenantsService.updateStatus) |
| F-026 | Tạo trực tiếp tài khoản người thuê | Đã triển khai | UC-TNT-03.1 | — | `/Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:73` (TenantsController.createAccount)<br>`/Users/hoang/Rental_room_management/backend/src/tenants/tenants.service.ts:222` (TenantsService.createAccount) |
| F-027 | Mời người thuê kích hoạt tài khoản | Đã triển khai | UC-SYS-08, UC-TNT-03 | — | `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.controller.ts:23` (TenantInvitesController.create)<br>`/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.service.ts:54` (TenantInvitesService.create) |
| F-028 | Tạo hợp đồng thuê | Đã triển khai | UC-TNT-05 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:29` (LeasesController.create)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:87` (LeasesService.create) |
| F-029 | Xem hợp đồng theo phòng hoặc người thuê | Đã triển khai | UC-TNT-04 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:184` (RoomLeasesController.list)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:343` (LeasesService.listByRoom) |
| F-030 | Sửa và gia hạn hợp đồng | Đã triển khai | UC-TNT-06.1, UC-TNT-06.2 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:104` (LeasesController.update)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:198` (LeasesService.update) |
| F-031 | Kết thúc hợp đồng và mở pipeline trả phòng | Đã triển khai | UC-TNT-06.3 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:59` (LeasesController.end)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:160` (LeasesService.end) |
| F-032 | Tra cứu hợp đồng sắp hết hạn | Đã triển khai | UC-TNT-04 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:50` (LeasesController.expiring)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:271` (LeasesService.expiring) |
| F-033 | Thu, hoàn và khấu trừ tiền cọc | Đã triển khai | UC-TNT-07 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:146` (LeasesController.deposits)<br>`/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:262` (LeasesService.depositTransactions) |
| F-034 | Xem trước và xác nhận quyết toán | Đã triển khai | UC-TNT-08 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:83` (LeasesController.previewSettlement)<br>`/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:53` (LeaseSettlementsService.preview) |
| F-035 | Ghi nhận đã hoàn cọc sau quyết toán | Đã triển khai | UC-TNT-09 | — | `/Users/hoang/Rental_room_management/backend/src/leases/leases.controller.ts:97` (LeasesController.recordSettlementRefund)<br>`/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:101` (LeaseSettlementsService.recordRefund) |
| F-036 | Xem quyết toán đã lưu | Đã triển khai | UC-TEN-02, UC-TNT-08 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:27` (TenantLifecyclePortalController.settlement)<br>`/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:39` (LeaseSettlementsService.get) |
| F-037 | Gửi, xem và hủy yêu cầu gia hạn/chuyển/trả phòng | Đã triển khai | UC-TEN-07.1, UC-TEN-07.2, UC-TEN-07.3, UC-TNT-10 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:15` (TenantLifecyclePortalController.requests)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:61` (TenantLifecycleService.createRequest) |
| F-038 | Duyệt hoặc từ chối yêu cầu vòng đời | Đã triển khai | UC-TNT-10 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:48` (TenantLifecycleController.review)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:102` (TenantLifecycleService.decideRequest) |
| F-039 | Thực thi yêu cầu đã duyệt | Đã triển khai | UC-TNT-11 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:51` (TenantLifecycleController.execute)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148` (TenantLifecycleService.executeRequest) |
| F-040 | Tìm phòng đủ điều kiện chuyển | Đã triển khai | UC-TEN-07.2 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:24` (TenantLifecyclePortalController.transferRooms)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:131` (TenantLifecycleService.transferRooms) |
| F-041 | Xem và quản lý người ở cùng | Đã triển khai | UC-TEN-08.1, UC-TNT-12.1 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:30` (TenantLifecyclePortalController.occupants)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205` (TenantLifecycleService.occupants) |
| F-042 | Thiết lập kênh nhắc hóa đơn | Đã triển khai | UC-TEN-08.2 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:33` (TenantLifecyclePortalController.preference)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:240` (TenantLifecycleService.preference) |
| F-043 | Danh sách lease cần lập hóa đơn và chỉ số | Đã triển khai | UC-BIL-01, UC-BIL-02 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:50` (BillingController.activeLeases)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:189` (BillingService.activeLeases) |
| F-044 | Ghi chỉ số điện/nước | Đã triển khai | UC-BIL-01 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:66` (BillingController.createMeterReading)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:227` (BillingService.createMeterReading) |
| F-045 | Lập hóa đơn đơn lẻ | Đã triển khai | UC-BIL-02 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:241` (BillingController.createInvoice)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:291` (BillingService.createInvoice) |
| F-046 | Xem trước và lập hóa đơn hàng loạt | Đã triển khai | UC-BIL-03 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:135` (BillingController.bulkInvoicePreflight)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:384` (BillingService.bulkInvoicePreflight) |
| F-047 | Tự động lập hóa đơn theo khu trọ | Đã triển khai | UC-BIL-17.1, UC-BIL-17.2 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:168` (BillingController.billingAutomation)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:599` (BillingService.billingAutomation) |
| F-048 | Tra cứu hóa đơn, trạng thái và công nợ | Đã triển khai | UC-BIL-04 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:90` (BillingController.invoices)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:794` (BillingService.listInvoices) |
| F-049 | Sửa ghi chú/hạn hóa đơn chưa thu | Đã triển khai | UC-BIL-05 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:270` (BillingController.updateInvoice)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:916` (BillingService.updateInvoice) |
| F-050 | Ghi nhận thanh toán hóa đơn | Đã triển khai | UC-BIL-09 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:419` (BillingController.recordPayment)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:960` (BillingService.recordPayment) |
| F-051 | Duyệt hoặc từ chối chứng từ chuyển khoản | Đã triển khai | UC-BIL-14 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:440` (BillingController.paymentProofs)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1038` (BillingService.listPaymentProofs) |
| F-052 | Đảo thanh toán | Đã triển khai | UC-BIL-12.2 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:475` (BillingController.reversePayment)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1185` (BillingService.reversePayment) |
| F-053 | Hủy hóa đơn có điều kiện | Đã triển khai | UC-BIL-08.1 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:291` (BillingController.cancelInvoice)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1245` (BillingService.cancelInvoice) |
| F-054 | Thay thế hóa đơn | Đã triển khai | UC-BIL-06 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:303` (BillingController.replaceInvoice)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:25` (BillingLedgerService.replace) |
| F-055 | Điều chỉnh giảm/tăng, miễn giảm và phụ thu | Đã triển khai | UC-BIL-07 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:309` (BillingController.adjustInvoice)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:60` (BillingLedgerService.adjust) |
| F-056 | Tạo và tra cứu phiếu thu | Đã triển khai | UC-BIL-10 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:321` (BillingController.receipts)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:88` (BillingLedgerService.createReceipt) |
| F-057 | Phân bổ tiền thu vào hóa đơn | Đã triển khai | UC-BIL-11 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:333` (BillingController.allocateReceipt)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:101` (BillingLedgerService.allocate) |
| F-058 | Giải phân bổ phiếu thu | Đã triển khai | UC-BIL-12.1 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:339` (BillingController.releaseAllocation)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:111` (BillingLedgerService.release) |
| F-059 | Ghi nhận hoàn tiền phiếu thu | Đã triển khai | UC-BIL-13 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:345` (BillingController.refundReceipt)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:132` (BillingLedgerService.refund) |
| F-060 | Báo cáo tuổi nợ | Đã triển khai | UC-BIL-04 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:315` (BillingController.aging)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:150` (BillingLedgerService.aging) |
| F-061 | Đề xuất và xem tác động biểu phí | Đã triển khai | UC-BIL-02, UC-BIL-15, UC-BIL-16 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:381` (BillingController.tariffsList)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:19` (BillingTariffsService.list) |
| F-062 | Phê duyệt/từ chối biểu phí | Đã triển khai | UC-BIL-16 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:399` (BillingController.reviewTariff)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:67` (BillingTariffsService.review) |
| F-063 | Khóa kỳ hóa đơn | Đã triển khai | UC-BIL-22 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:406` (BillingController.lockPeriod)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:91` (BillingTariffsService.lockPeriod) |
| F-064 | Cấu hình tài khoản nhận chuyển khoản | Đã triển khai | UC-BIL-23 | — | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.controller.ts:12` (TransferAccountController.account)<br>`/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:11` (ManualTransferService.account) |
| F-065 | Xem hướng dẫn chuyển khoản và gửi bằng chứng | Đã triển khai | UC-TEN-04 | — | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.controller.ts:22` (TransferInstructionsController.instructions)<br>`/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:46` (ManualTransferService.instructions) |
| F-066 | Tạo hóa đơn kiểm thử và link thẻ demo | Đã triển khai | UC-BIL-04, UC-TEN-05 | — | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:15` (TenantOnlinePaymentsController.create)<br>`/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:21` (OnlinePaymentsService.createDemoInvoice) |
| F-067 | Xác nhận thanh toán demo và tra cứu sự kiện | Đã triển khai | UC-BIL-04, UC-TEN-05 | — | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:25` (LandlordOnlinePaymentsController.events)<br>`/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:99` (OnlinePaymentsService.checkout) |
| F-068 | Đối soát giao dịch ngân hàng qua cổng demo | Triển khai một phần | Không thành UC độc lập | TECH-09 | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:26` (LandlordOnlinePaymentsController.reconcile)<br>`/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:139` (OnlinePaymentsService.reconcile) |
| F-069 | Quản lý chi phí vận hành | Đã triển khai | UC-BIL-19 | — | `/Users/hoang/Rental_room_management/backend/src/expenses/expenses.controller.ts:36` (ExpensesController.list)<br>`/Users/hoang/Rental_room_management/backend/src/expenses/expenses.service.ts:34` (ExpensesService.list) |
| F-070 | Quản lý phiếu bảo trì | Đã triển khai | UC-OPS-01, UC-OPS-02 | — | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:41` (MaintenanceController.list)<br>`/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:60` (MaintenanceService.list) |
| F-071 | Phân công người xử lý và hạn bảo trì | Đã triển khai | UC-OPS-02 | — | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:67` (MaintenanceController.assignees)<br>`/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:54` (MaintenanceService.assignees) |
| F-072 | Trao đổi và hoàn thành bảo trì | Đã triển khai | UC-OPS-01, UC-OPS-03 | — | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:127` (MaintenanceController.complete)<br>`/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.service.ts:272` (MaintenanceService.addComment) |
| F-073 | Escalation bảo trì quá hạn | Đã triển khai | UC-OPS-02 | — | `/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance.controller.ts:79` (MaintenanceController.escalate)<br>`/Users/hoang/Rental_room_management/backend/src/maintenance/maintenance-sla.service.ts:24` (MaintenanceSlaService.escalate) |
| F-074 | Hồ sơ, dashboard, hợp đồng và hóa đơn của tôi | Đã triển khai | UC-TEN-01, UC-TEN-02, UC-TEN-03 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:17` (TenantPortalController.me)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:91` (TenantPortalService.me) |
| F-075 | Gửi và trao đổi yêu cầu bảo trì | Đã triển khai | UC-TEN-06 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:79` (TenantPortalController.maintenance)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:371` (TenantPortalService.maintenance) |
| F-076 | Thông báo và đánh dấu đã đọc | Đã triển khai | UC-SUP-04 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:42` (TenantPortalController.notifications)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:188` (TenantPortalService.notifications) |
| F-077 | Hộp thoại Zalo mô phỏng | Đã triển khai | UC-TEN-09.2 | — | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.controller.ts:52` (TenantPortalController.zaloMessages)<br>`/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:279` (TenantPortalService.zaloMessages) |
| F-078 | Danh sách việc cần xử lý và đánh dấu đã xem | Đã triển khai | UC-OPS-04 | — | `/Users/hoang/Rental_room_management/backend/src/operations/operations.controller.ts:18` (OperationsController.actionItems)<br>`/Users/hoang/Rental_room_management/backend/src/operations/operations.service.ts:50` (OperationsService.actionItems) |
| F-079 | Truy cập trung tâm việc cần xử lý bằng STAFF | Triển khai một phần | UC-OPS-04 | TECH-02 | `/Users/hoang/Rental_room_management/backend/src/operations/operations.controller.ts:18` (OperationsController.actionItems)<br>`/Users/hoang/Rental_room_management/backend/src/operations/operations.service.ts:50` (OperationsService.actionItems) |
| F-080 | Quy trình trả phòng và sẵn sàng cho thuê | Đã triển khai | UC-OPS-05, UC-OPS-06 | — | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:25` (P1OperationsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/operations/turnovers.service.ts:13` (TurnoversService.list) |
| F-081 | Tạo và tạm dừng lịch công việc định kỳ | Đã triển khai | UC-OPS-06 | — | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:28` (P1OperationsController.templates)<br>`/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:27` (RecurringService.create) |
| F-082 | Sinh và hoàn thành checklist công việc | Đã triển khai | UC-OPS-06.1 | — | `/Users/hoang/Rental_room_management/backend/src/operations/p1.controller.ts:31` (P1OperationsController.tasks)<br>`/Users/hoang/Rental_room_management/backend/src/operations/recurring.service.ts:79` (RecurringService.generateDue) |
| F-083 | Tạo nhóm người thuê và mẫu thông báo | Đã triển khai | UC-OPS-07 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:14` (AnnouncementsController.templates)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:11` (AnnouncementsService.createGroup) |
| F-084 | Soạn, lên lịch và hủy thông báo | Đã triển khai | UC-OPS-07 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:13` (AnnouncementsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:22` (AnnouncementsService.create) |
| F-085 | Phát hành và theo dõi đã đọc | Đã triển khai | UC-OPS-07, UC-TEN-09.3 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/announcements.controller.ts:19` (AnnouncementsController.receipts)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/announcements.service.ts:81` (AnnouncementsService.sendDue) |
| F-086 | Tìm kiếm và xem tin công khai | Đã triển khai | UC-DIS-01, UC-DIS-02 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:43` (PublicListingsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:29` (ListingsService.publicList) |
| F-087 | Lọc vị trí gần cơ sở trường | Đã triển khai | UC-DIS-01 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:261` (ListingsService.nearbyCampus) |
| F-088 | Tạo và sửa tin phòng | Đã triển khai | UC-DIS-05, UC-ADM-11, UC-ADM-11.1 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:55` (LandlordListingsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:69` (ListingsService.manageList) |
| F-089 | Gửi duyệt, ẩn và xác nhận phòng còn trống | Đã triển khai | UC-DIS-05, UC-DIS-06.2 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:70` (LandlordListingsController.submit)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:113` (ListingsService.submit) |
| F-090 | Phê duyệt, từ chối và ẩn tin | Đã triển khai | UC-ADM-11 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:103` (AdminListingsController.review)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:130` (ListingsService.review) |
| F-091 | Xác minh tin/chủ và kiểm tra phòng ở tin | Đã triển khai | UC-ADM-11.1 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:108` (AdminListingsController.verify)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:187` (ListingsService.verify) |
| F-092 | Báo cáo tin và xử lý báo cáo | Đã triển khai | UC-ADM-12.1, UC-DIS-07 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:33` (StudentListingsController.report)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:217` (ListingsService.report) |
| F-093 | Danh mục cơ sở trường | Đã triển khai | UC-DIS-01, UC-ADM-23 | — | `/Users/hoang/Rental_room_management/backend/src/listings/listings.controller.ts:12` (PublicCampusesController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/listings.service.ts:182` (ListingsService.campuses) |
| F-094 | Lưu, bật/tắt và xóa tìm kiếm | Đã triển khai | UC-DIS-04 | — | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:12` (SavedSearchesController.list)<br>`/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:22` (SavedSearchesService.list) |
| F-095 | Quét tin phù hợp và thông báo tìm kiếm đã lưu | Đã triển khai | UC-DIS-04 | — | `/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.controller.ts:14` (SavedSearchesController.alerts)<br>`/Users/hoang/Rental_room_management/backend/src/listings/saved-searches.service.ts:67` (SavedSearchesService.scanAll) |
| F-096 | So sánh tin trong phiên giao diện | Đã triển khai | UC-DIS-16 | — | `/Users/hoang/Rental_room_management/lib/features/listings/listing_comparison_screen.dart:1`<br>`/Users/hoang/Rental_room_management/lib/features/listings/listings_providers.dart:1` |
| F-097 | Lưu và bỏ lưu tin yêu thích | Đã triển khai | UC-DIS-03 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:43` (HousingController.favorites)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:31` (HousingService.favorites) |
| F-098 | Mở và xóa khung giờ xem phòng | Đã triển khai | UC-DIS-08 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:14` (HousingController.slots)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:102` (HousingService.slots) |
| F-099 | Đặt, đổi lịch và tra cứu lịch xem | Đã triển khai | UC-DIS-09, UC-DIS-10 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:25` (HousingController.reschedule)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:83` (HousingService.book) |
| F-100 | Xác nhận, từ chối, hủy hoặc hoàn thành lịch xem | Đã triển khai | UC-DIS-09, UC-DIS-10 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:74` (HousingController.update)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:208` (HousingService.update) |
| F-101 | Chuyển lịch đã xem thành hợp đồng | Đã triển khai | UC-TNT-05 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:79` (HousingController.lease)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:240` (HousingService.createLease) |
| F-102 | Biên bản bàn giao và xác nhận nhận phòng | Đã triển khai | UC-TNT-12.2, UC-TNT-12.3 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:30` (HousingController.handover)<br>`/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:22` (HandoverService.get) |
| F-103 | Nhắc lịch và hộp thông báo xem phòng | Đã triển khai | UC-SUP-04 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:84` (HousingController.notifications)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:279` (HousingService.notifications) |
| F-104 | Phản hồi pilot và số liệu pilot | Đã triển khai | UC-DIS-13.2, UC-ADM-27 | — | `/Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:92` (HousingController.pilot)<br>`/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:316` (HousingService.pilot) |
| F-105 | Kiểm tra đủ điều kiện và gửi đánh giá | Đã triển khai | UC-DIS-12 | — | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:20` (RoomReviewsController.context)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:18` (ReviewsService.verification) |
| F-106 | Sửa và rút đánh giá | Đã triển khai | UC-DIS-12 | — | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:28` (RoomReviewsController.update)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:72` (ReviewsService.update) |
| F-107 | Phản hồi đánh giá của chủ trọ | Đã triển khai | UC-DIS-13.1 | — | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:38` (RoomReviewsController.landlord)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:134` (ReviewsService.landlord) |
| F-108 | Kiểm duyệt đánh giá và phản hồi | Đã triển khai | UC-ADM-12 | — | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:52` (AdminRoomReviewsController.queue)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:140` (ReviewsService.queue) |
| F-109 | Xem đánh giá công khai và điểm tổng hợp | Đã triển khai | UC-DIS-02 | — | `/Users/hoang/Rental_room_management/backend/src/reviews/reviews.controller.ts:12` (PublicRoomReviewsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/reviews/reviews.service.ts:157` (ReviewsService.publicReviews) |
| F-110 | Thông báo công việc của chủ trọ | Đã triển khai | UC-SUP-04, UC-TEN-09.2 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:18` (NotificationsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:40` (NotificationsService.list) |
| F-111 | Nhắc nợ Zalo ZNS qua provider | Triển khai một phần | UC-BIL-18.2 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:39` (NotificationsController.sendInvoiceRemindersZalo)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:83` (NotificationsService.sendInvoiceRemindersZalo) |
| F-112 | Tạo tin Zalo test/thủ công mô phỏng | Đã triển khai | UC-TEN-09.2 | — | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:53` (NotificationsController.createZaloTestMessage)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:196` (NotificationsService.createZaloTestMessage) |
| F-113 | Chính sách nhắc nợ theo ngày/kênh và hàng đợi | Đã triển khai | UC-BIL-18.1, UC-BIL-18.2 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:124` (BillingController.runReminders)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:20` (BillingRemindersService.policy) |
| F-114 | Tra cứu và thử lại sự kiện billing outbox | Đã triển khai | UC-BIL-18.3 | — | `/Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:369` (BillingController.outboxEvents)<br>`/Users/hoang/Rental_room_management/backend/src/billing/billing-outbox.service.ts:90` (BillingOutboxService.list) |
| F-115 | Các quyền thông báo/vận hành trên STAFF hiện tại | Triển khai một phần | UC-SUP-04 | TECH-02 | `/Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:18` (NotificationsController.list)<br>`/Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:40` (NotificationsService.list) |
| F-116 | Dashboard chủ trọ theo khu và tháng | Đã triển khai | UC-OPT-01 | — | `/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.controller.ts:19` (DashboardController.metrics)<br>`/Users/hoang/Rental_room_management/backend/src/dashboard/dashboard.service.ts:17` (DashboardService.metrics) |
| F-117 | Báo cáo tài chính tháng và phân tích | Đã triển khai | UC-BIL-20 | — | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:18` (ReportsController.monthly)<br>`/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:18` (ReportsService.monthly) |
| F-118 | Xuất báo cáo CSV | Đã triển khai | UC-BIL-20 | — | `/Users/hoang/Rental_room_management/backend/src/reports/reports.controller.ts:28` (ReportsController.monthlyExport)<br>`/Users/hoang/Rental_room_management/backend/src/reports/reports.service.ts:141` (ReportsService.monthlyExport) |
| F-119 | Xuất/in PDF hóa đơn và hợp đồng tại frontend | Đã triển khai | UC-TEN-02, UC-TNT-04, UC-BIL-04, UC-TEN-03 | — | `/Users/hoang/Rental_room_management/lib/features/billing/invoice_pdf.dart:1`<br>`/Users/hoang/Rental_room_management/lib/features/tenants/lease_pdf.dart:1` |
| F-120 | Xem nhật ký theo chủ trọ | Đã triển khai | UC-OPS-09 | — | `/Users/hoang/Rental_room_management/backend/src/audit/audit.controller.ts:19` (AuditController.list)<br>`/Users/hoang/Rental_room_management/backend/src/audit/audit.service.ts:26` (AuditService.list) |
| F-121 | Hỏi đáp có nguồn và xem trích dẫn | Triển khai một phần | UC-SUP-06 | — | `/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.controller.ts:19` (ChatbotController.ask)<br>`/Users/hoang/Rental_room_management/backend/src/chatbot/chatbot.service.ts:24` (ChatbotService.ask) |
| F-122 | Nhập/thu hồi tài liệu tri thức đã duyệt | Đã triển khai | Không thành UC độc lập | TECH-06 | `/Users/hoang/Rental_room_management/backend/src/chatbot/knowledge.repository.ts:41` (KnowledgeRepository.replaceDocument) |
| F-123 | Tải ảnh/PDF và lấy URL truy cập được cấp quyền | Đã triển khai | Không thành UC độc lập | TECH-05 | `/Users/hoang/Rental_room_management/backend/src/uploads/uploads.controller.ts:13` (UploadsController.upload)<br>`/Users/hoang/Rental_room_management/backend/src/uploads/uploads.service.ts:23` (UploadsService.save) |
| F-124 | Danh sách, bộ lọc và chi tiết tài khoản | Đã triển khai | UC-ADM-02, UC-ADM-06.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:19` (AdminConsoleController.accounts)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:28` (AdminConsoleService.accounts) |
| F-125 | Tạm khóa/mở tài khoản và thu hồi phiên | Đã triển khai | UC-ADM-04.1, UC-ADM-04.3 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:25` (AdminConsoleController.suspend)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:56` (AdminConsoleService.status) |
| F-126 | Mở dữ liệu cá nhân với lý do | Đã triển khai | UC-ADM-05.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:31` (AdminConsoleController.reveal)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:93` (AdminConsoleService.reveal) |
| F-127 | Mời tài khoản và khôi phục truy cập từ admin | Triển khai một phần | UC-ADM-03.1, UC-ADM-05.2, UC-ADM-06.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:35` (AdminConsoleController.reset)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:170` (AdminConsoleService.invite) |
| F-128 | Quản lý quyền admin và bảo vệ super admin cuối | Đã triển khai | UC-ADM-06.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:41` (AdminConsoleController.adminAccess)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:110` (AdminConsoleService.adminAccess) |
| F-129 | Tra cứu ngữ cảnh hỗ trợ read-only | Đã triển khai | UC-SUP-01.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:59` (AdminConsoleController.context)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:210` (AdminConsoleService.context) |
| F-130 | Hàng đợi kiểm duyệt và nhận/giao việc | Đã triển khai | UC-ADM-11 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:62` (AdminConsoleController.queue)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:238` (AdminConsoleService.queue) |
| F-131 | Tổng quan, summary và danh sách việc admin | Đã triển khai | UC-ADM-01 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.controller.ts:14` (AdminWorkspaceController.summary)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-workspace.service.ts:25` (AdminWorkspaceService.summary) |
| F-132 | Phân tích overview nền tảng | Đã triển khai | UC-ADM-01 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-overview-analytics.controller.ts:14` (AdminOverviewAnalyticsController.overview)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-overview-analytics.service.ts:33` (AdminOverviewAnalyticsService.overview) |
| F-133 | Tra cứu chủ trọ, khu và phòng toàn hệ thống | Đã triển khai | UC-ADM-02, UC-ADM-08 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:28` (AdminController.listLandlords)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:75` (AdminService.listLandlords) |
| F-134 | Sửa chủ trọ, tạo/sửa khu từ admin | Đã triển khai | UC-ADM-03.2, UC-ADM-09 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:46` (AdminController.updateLandlord)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:114` (AdminService.updateLandlord) |
| F-135 | Tạo chủ trọ trực tiếp bằng mật khẩu ở môi trường dev | Đã triển khai | UC-ADM-03.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin.controller.ts:34` (AdminController.createLandlord)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin.service.ts:90` (AdminService.createLandlord) |
| F-136 | Tìm kiếm đa tài nguyên và trang read-only | Đã triển khai | UC-ADM-10 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-search.controller.ts:18` (AdminSearchController.searchAll)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-search.service.ts:35` (AdminSearchService.search) |
| F-137 | Nộp và xét hồ sơ xác minh chủ trọ | Đã triển khai | UC-ADM-18, UC-ADM-18.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:21` (AdminRegistryController.verifications)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:15` (AdminVerificationService.own) |
| F-138 | Gửi và xét duyệt khu trọ | Đã triển khai | UC-ADM-19 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:30` (AdminRegistryController.propertyReviews)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-property-review.service.ts:16` (AdminPropertyReviewService.list) |
| F-139 | Danh mục gói và phiên bản điều khoản | Đã triển khai | UC-ADM-20 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:39` (AdminRegistryController.servicePlans)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:19` (AdminPlansService.plans) |
| F-140 | Cấp, hủy và xem lịch sử gói cho chủ trọ | Đã triển khai | UC-ADM-21, UC-ADM-22 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:45` (AdminRegistryController.subscriptions)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-plans.service.ts:52` (AdminPlansService.subscriptions) |
| F-141 | Sổ giao dịch toàn nền tảng | Đã triển khai | UC-ADM-24 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-registry.controller.ts:18` (AdminRegistryController.transactionList)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-transactions.service.ts:24` (AdminTransactionsService.list) |
| F-142 | Đăng ký và xác nhận MFA admin | Đã triển khai | UC-ADM-07.1 | — | `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:25` (AdminSecurityController.status)<br>`/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:52` (AdminMfaService.enroll) |
| F-143 | Step-up cho thao tác admin nhạy cảm | Đã triển khai | Không thành UC độc lập | TECH-03 | `/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.controller.ts:23` (AdminStepUpController.issue)<br>`/Users/hoang/Rental_room_management/backend/src/auth/admin-step-up.service.ts:19` (AdminStepUpService.issue) |
| F-144 | Xem và thu hồi phiên bản thân | Đã triển khai | UC-SYS-05.2 | — | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:59` (AuthController.sessions)<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:212` (AuthService.sessions) |
| F-145 | Rà soát quyền định kỳ và vòng đời lời mời admin | Đã triển khai | UC-ADM-04.3, UC-ADM-06.1, UC-ADM-06.2 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.controller.ts:17` (AdminAccessReviewController.catalog)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-access-review.service.ts:12` (AdminAccessReviewService.catalog) |
| F-146 | Tạo, tra cứu và trao đổi ticket hỗ trợ | Đã triển khai | UC-SUP-01, UC-SUP-01.1 | — | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:15` (SupportController.create)<br>`/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:46` (SupportService.create) |
| F-147 | Nhận/giao ticket và chuyển trạng thái | Đã triển khai | UC-SUP-01.1 | — | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:17` (SupportController.assignees)<br>`/Users/hoang/Rental_room_management/backend/src/support/support.service.ts:125` (SupportService.assign) |
| F-148 | Nhãn, mẫu trả lời và gộp ticket | Đã triển khai | UC-SUP-01.1, UC-SUP-03.2, UC-SUP-03.2.1 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:18` (SupportToolsController.templates)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:26` (SupportToolsService.labels) |
| F-149 | Đánh giá hỗ trợ sau xử lý | Đã triển khai | UC-SUP-03.2.2 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-tools.controller.ts:23` (SupportToolsController.feedback)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-tools.service.ts:37` (SupportToolsService.feedback) |
| F-150 | Lưu bộ lọc và điều phối theo kỹ năng/công suất | Đã triển khai | UC-SUP-02.1, UC-SUP-03.3 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-workflow.controller.ts:14` (SupportWorkflowController.views)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-workflow.service.ts:14` (SupportWorkflowService.views) |
| F-151 | Tệp hỗ trợ có quét mã độc | Triển khai một phần | UC-SUP-01, UC-SUP-01.1 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-attachment.controller.ts:16` (SupportAttachmentController.upload)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-attachment.service.ts:25` (SupportAttachmentService.upload) |
| F-152 | Liên kết tài nguyên và timeline hồ sơ hỗ trợ | Đã triển khai | UC-SUP-01.1 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-case.controller.ts:20` (SupportCaseController.timeline)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-case.service.ts:33` (SupportCaseService.timeline) |
| F-153 | Cấu hình lịch làm việc và ngưỡng SLA | Đã triển khai | UC-SUP-02.2 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-sla.controller.ts:14` (SupportSlaController.policy)<br>`/Users/hoang/Rental_room_management/backend/src/support/support-sla.service.ts:25` (SupportSlaService.policy) |
| F-154 | Theo dõi SLA và escalation đa cấp | Đã triển khai | UC-SUP-02.2 | — | `/Users/hoang/Rental_room_management/backend/src/support/support-sla.service.ts:53` (SupportSlaService.run) |
| F-155 | Hộp thông báo nền tảng và tùy chọn nhận | Đã triển khai | UC-SUP-04 | — | `/Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:25` (SupportController.listNotifications)<br>`/Users/hoang/Rental_room_management/backend/src/support/platform-notification.service.ts:24` (PlatformNotificationService.list) |
| F-156 | Gửi thông báo ngoài app và thử lại dead-letter | Triển khai một phần | UC-SUP-05.2 | — | `/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.controller.ts:14` (NotificationDeliveryController.queue)<br>`/Users/hoang/Rental_room_management/backend/src/support/notification-delivery.service.ts:22` (NotificationDeliveryService.enqueue) |
| F-157 | Lịch sử quyết định và báo cáo kiểm duyệt | Đã triển khai | UC-ADM-13.2, UC-DIS-15 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:16` (MyModerationController.decisions)<br>`/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:27` (ModerationV2Service.decisions) |
| F-158 | Gửi và xử lý khiếu nại kiểm duyệt | Đã triển khai | UC-ADM-13.2, UC-DIS-15 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:17` (MyModerationController.appeals)<br>`/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:42` (ModerationV2Service.appeal) |
| F-159 | Xem trước và kiểm duyệt hàng loạt | Đã triển khai | UC-ADM-11 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:31` (ModerationV2Controller.bulk)<br>`/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:145` (ModerationV2Service.preview) |
| F-160 | Tạo và kích hoạt policy kiểm duyệt | Đã triển khai | UC-ADM-13.1 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:19` (ModerationPolicyController.list)<br>`/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.service.ts:12` (ModerationPolicyService.list) |
| F-161 | Lấy mẫu QA và đánh giá quyết định độc lập | Đã triển khai | UC-ADM-13.3 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-policy.controller.ts:20` (ModerationPolicyController.quality)<br>`/Users/hoang/Rental_room_management/backend/src/platform/moderation-quality.service.ts:20` (ModerationQualityService.samples) |
| F-162 | Quản lý nhóm admin và thành viên | Đã triển khai | UC-ADM-17.2 | — | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:17` (GovernanceController.team)<br>`/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:16` (GovernanceService.team) |
| F-163 | Mô phỏng quyền admin | Đã triển khai | UC-ADM-26 | — | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:23` (GovernanceController.simulate)<br>`/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:62` (GovernanceService.simulate) |
| F-164 | Cờ tính năng và rollout theo user/role | Đã triển khai | UC-DIS-15, UC-ADM-17.1 | — | `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.controller.ts:19` (MyModerationController.features)<br>`/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:70` (GovernanceService.flagsList) |
| F-165 | Đọc tổng quan đối soát nội bộ | Đã triển khai | UC-ADM-24 | — | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:27` (GovernanceController.finance)<br>`/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:73` (GovernanceService.finance) |
| F-166 | Nhập sao kê và gợi ý ghép giao dịch | Đã triển khai | UC-ADM-15 | — | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:14` (FinanceReconciliationController.importStatement)<br>`/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:18` (FinanceReconciliationService.importStatement) |
| F-167 | Đề xuất và phê duyệt ghép/bỏ ghép sao kê | Đã triển khai | UC-ADM-15, UC-ADM-15.1 | — | `/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.controller.ts:16` (FinanceReconciliationController.propose)<br>`/Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:100` (FinanceReconciliationService.propose) |
| F-168 | Tạo, sửa lịch và xếp hàng chạy báo cáo | Đã triển khai | UC-ADM-16 | — | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:28` (GovernanceController.schedules)<br>`/Users/hoang/Rental_room_management/backend/src/platform/governance.service.ts:92` (GovernanceService.schedules) |
| F-169 | Worker tạo báo cáo, tải và thử lại | Đã triển khai | UC-ADM-16 | — | `/Users/hoang/Rental_room_management/backend/src/platform/governance.controller.ts:32` (GovernanceController.runs)<br>`/Users/hoang/Rental_room_management/backend/src/platform/admin-report-worker.service.ts:107` (AdminReportWorkerService.enqueueDue) |
| F-170 | Health liveness/readiness và kiểm tra schema | Đã triển khai | Không thành UC độc lập | TECH-04 | `/Users/hoang/Rental_room_management/backend/src/health/health.controller.ts:24` (HealthController.ready)<br>`/Users/hoang/Rental_room_management/backend/src/health/schema-readiness.service.ts:38` (SchemaReadinessService.inspect) |
| F-171 | Metrics, heartbeat, backup telemetry và release gate | Đã triển khai | UC-SUP-05.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:70` (AdminConsoleController.operationsHealth)<br>`/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.ts:32` (OperationsHealthService.summary) |
| F-172 | Theo dõi, nhận, giao, tạm hoãn và xử lý sự cố | Đã triển khai | UC-SUP-05.1 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:73` (AdminConsoleController.acknowledgeIncident)<br>`/Users/hoang/Rental_room_management/backend/src/health/operations-health.service.ts:181` (OperationsHealthService.acknowledge) |
| F-173 | Xem hàng đợi delivery và worker gửi link/cảnh báo | Đã triển khai | UC-SUP-05.2 | — | `/Users/hoang/Rental_room_management/backend/src/health/operations-queue.controller.ts:18` (OperationsQueueController.list)<br>`/Users/hoang/Rental_room_management/backend/src/health/operations-queue.service.ts:9` (OperationsQueueService.list) |
| F-174 | Nhật ký admin: danh sách, chi tiết và xuất | Đã triển khai | UC-ADM-14 | — | `/Users/hoang/Rental_room_management/backend/src/admin/admin-console.controller.ts:47` (AdminConsoleController.audit)<br>`/Users/hoang/Rental_room_management/backend/src/admin/admin-console.service.ts:202` (AdminConsoleService.audit) |
| F-175 | Giới thiệu lần đầu và xem thông tin cá nhân | Đã triển khai | Không thành UC độc lập | TECH-07 | `/Users/hoang/Rental_room_management/lib/features/onboarding/onboarding_screen.dart:1`<br>`/Users/hoang/Rental_room_management/lib/data/onboarding/onboarding_preferences.dart:1` |
| F-176 | Ước tính chi phí ở và chi phí mỗi người | Đã triển khai | UC-DIS-17 | — | `/Users/hoang/Rental_room_management/lib/features/listings/student_listing_widgets.dart:1`<br>`/Users/hoang/Rental_room_management/lib/models/student_discovery.dart:1` |
| F-177 | Sao lưu, phục hồi thử và off-site backup | Triển khai một phần | Không thành UC độc lập | TECH-08 | `/Users/hoang/Rental_room_management/backend/scripts/database-safety.mjs:1`<br>`/Users/hoang/Rental_room_management/backend/scripts/offsite-backup.mjs:1` |
| F-178 | Thanh toán thẻ tiền thật qua ngân hàng | Chưa xác minh | Không thành UC độc lập | GAP-01 | `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_online_payment_screen.dart:1`<br>`/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:1` |
| F-179 | Ký số/xác nhận pháp lý hợp đồng điện tử | Chưa xác minh | Không thành UC độc lập | GAP-02 | `/Users/hoang/Rental_room_management/lib/features/tenants/lease_pdf.dart:1`<br>`/Users/hoang/Rental_room_management/backend/src/housing/handover.service.ts:1` |
| F-180 | Người dùng tự cập nhật hồ sơ cá nhân | Chưa xác minh | Không thành UC độc lập | GAP-03 | `/Users/hoang/Rental_room_management/lib/data/auth/auth_api.dart:1`<br>`/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:1` |

## 4. Phạm vi kiểm tra và điểm chưa được xác minh

Độ phủ trên là inventory/traceability tĩnh, không phải line coverage hoặc acceptance. Không chạy ứng dụng/DB/provider trong đợt này. Tệp unit/Flutter/E2E chỉ làm nguồn đối chiếu và phải chạy riêng trong môi trường phù hợp khi cần xác minh hành vi. Không tái dùng kết quả test lịch sử như lần chạy mới.

Migration/schema thể hiện thiết kế mã nguồn, không chứng minh DB runtime đã áp migration. Adapter/thông báo queued không chứng minh nhà cung cấp giao thành công. Không chụp hoặc suy giao diện đang chạy từ tên widget.
