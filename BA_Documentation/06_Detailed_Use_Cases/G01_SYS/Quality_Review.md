# Rà soát đặc tả G01/SYS

Ngày 29/10/2026. Phạm vi: 11/11 UC G01; source snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Đây là báo cáo riêng, không phải bảng đặc tả bổ sung cho từng UC.

## 1. Kết quả và danh sách hoàn thành

11 tệp đặc tả, mỗi tệp một bảng liên tục hai cột, đủ 20 thuộc tính. Không thêm/gộp/tách/loại bỏ/đổi mã/đổi tên UC; giữ 10 trạng thái Xác minh tĩnh và 1 Một phần. Xác minh tĩnh mô tả hành vi source, không khẳng định end-to-end đã nghiệm thu.

- UC-ADM-07.1 — Thiết lập MFA Admin.
- UC-SYS-01 — Đăng ký tài khoản chủ trọ.
- UC-SYS-02 — Đăng ký tài khoản tìm phòng.
- UC-SYS-03 — Đăng nhập.
- UC-SYS-05.1 — Đăng xuất phiên hiện tại.
- UC-SYS-05.2 — Xem và thu hồi các phiên của mình.
- UC-SYS-06 — Khôi phục mật khẩu bằng liên kết một lần.
- UC-SYS-07 — Đổi mật khẩu khi đang đăng nhập.
- UC-SYS-08 — Kích hoạt tài khoản người thuê từ lời mời.
- UC-SYS-09 — Kích hoạt tài khoản nhân viên từ lời mời.
- UC-SYS-10 — Thiết lập mật khẩu tài khoản được mời.

| Nhánh chức năng G01 | Số UC |
|---|---|
| Đăng ký và kích hoạt | 5 |
| Đăng nhập và quản lý phiên | 3 |
| Bảo vệ tài khoản (gồm MFA Admin) | 3 |
| Tổng G01 | 11 |

Tại thời điểm đợt G01 còn 151 UC/15 nhóm chưa đặc tả; lượt hoàn tất tiếp theo ngày 29/10/2026 đã bổ sung đủ G02–G16. Báo cáo toàn hệ thống nằm tại ../Quality_Review.md.

## 2. Nguồn và đối chiếu

Đọc nền AS-IS lịch sử trong docs/ba, FDD G01.1–G01.3, Actor Catalog/Matrix, Catalog JSON/Markdown và quality review Giai đoạn 2; đọc hai trang UML G01/diagram-manifest; đối chiếu controller/service/DTO/schema/UI/repository/state/router/guard/error filter/tests liên quan. Gói chuẩn `01_System_Analysis/` chưa có: dùng nền phân tích thực có, không khai báo một đầu vào đã xuất không tồn tại. Nội dung cũ không thay thế code hiện tại.

Nhãn trong từng UC là nguồn cục bộ riêng có đường dẫn/dòng; các claim validation, auth, lỗi, mutation/transaction và nhánh UI đều được dẫn đến các nguồn tương ứng. Trạng thái DB thực/migration/provider không thể kết luận từ schema hoặc unit mock.

## 3. Đối chiếu Actor và UML

| Phạm vi | Actor theo Catalog/UML | Kết luận đối chiếu code |
|---|---|---|
| UC-SYS-01/02/03/06/08/09/10 | A01 | Public controller; A01 là ngữ cảnh trước đăng nhập, không phải role Guest. Người nhận lời mời không phải admin tạo lời mời. |
| UC-SYS-05.1 | A02/A03/A04/A05 | Ngữ cảnh người đang rời phiên; API công khai dựa refresh token, không gán JWT guard giả. |
| UC-SYS-05.2/07 | A02/A03/A04/A05 | API JWT của chính mình; AuthController không capability riêng. STAFF được interceptor cho qua nhưng JWT vẫn kiểm profile/chủ trọ active. UI không đầy đủ cho mọi actor. |
| UC-ADM-07.1 | A05 | JWT + kiểm ADMIN/AdminProfile rõ trong controller; không @Roles không có nghĩa public. Không yêu cầu capability hay step-up giả. |
| UC-SYS-06 | E01 phối hợp có điều kiện | Worker gửi HTTPS webhook khi cấu hình/bật; chưa xác nhận email thật. |
| UC-SYS-10 | Không E01 | Redeem không gọi provider; gửi link ở UC mời trước đó ngoài phạm vi này. |

11/11 mã/tên giữ nguyên, 7 UC ở trang Public và 4 UC ở trang Sessions; association chính/phối hợp khớp manifest. Cả hai trang không có include/extend/generalization; đặc tả chỉ giải thích lời gọi tái sử dụng/cùng service hoặc thứ tự nghiệp vụ, không chuyển chúng thành UML include. Không chỉnh sửa .puml/rendered/Catalog.

Nguồn UML: `/Users/hoang/Rental_room_management/BA_Documentation/05_Use_Case_Diagrams/UC_G01_01_SYS_Public.puml:1`; `/Users/hoang/Rental_room_management/BA_Documentation/05_Use_Case_Diagrams/UC_G01_02_SYS_Sessions.puml:1`.

## 4. Chưa xác minh và khoảng trống có căn cứ

| Mã | UC | Giới hạn/chênh lệch AS-IS | Bằng chứng và tác động |
|---|---|---|---|
| GAP-SYS-01 | SYS-06 | Chưa xác minh provider gửi email tới hộp thư thật. SENT chỉ là webhook HTTP ok, không phải email delivered. | `/Users/hoang/Rental_room_management/backend/src/delivery/delivery.service.ts:79`; giữ Một phần, không nâng trạng thái vì có worker. |
| GAP-SYS-02 | SYS-05.2 | Backend cho 4 role, chỉ tìm thấy UI chuyên dụng /admin/sessions cho A05. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:59`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_sessions_screen.dart:19`; không tự mô tả UI cho A02/A03/A04. |
| GAP-SYS-03 | SYS-05.2 | Dialog khẳng định giữ phiên hiện tại; UI ẩn nút, nhưng single-revoke backend chấp nhận chính sid hiện tại. Chỉ bulk bảo vệ current. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:232`; `/Users/hoang/Rental_room_management/lib/features/admin/admin_sessions_screen.dart:31`; đặc tả A5 nêu API-only, không dùng label UI làm luật server. |
| GAP-SYS-04 | SYS-07 | Chưa tìm điểm truy cập UI Admin riêng; API không cấm ADMIN. UI mật khẩu mới chỉ min12, backend policy đủ 12–128/4 nhóm. | `/Users/hoang/Rental_room_management/lib/features/tenant_portal/tenant_change_password_screen.dart:31`; `/Users/hoang/Rental_room_management/backend/src/auth/dto/change-password.dto.ts:4`; giữ actor API A05 và ghi giới hạn UI. |
| GAP-SYS-05 | SYS-07 | changePassword không consume AccountAccessToken đang chờ, khác redeem; không bảo đảm link cũ vô hiệu sau đổi password bằng mật khẩu cũ. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:159`; `/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:67`; là chênh lệch triển khai cần chủ hệ thống xem xét, không tự sửa. |
| GAP-SYS-06 | SYS-06/10 | redeem không kiểm purpose, nhận token INVITE/PASSWORD_RESET bằng cùng cơ chế; route/form không phân mục đích. | `/Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:54`; ghi rõ giới hạn, không tự thêm điều kiện purpose. |
| GAP-SYS-07 | SYS-08/09 | UI chỉ min12 password và code không rỗng; backend mạnh hơn. Chưa xác minh test trực tiếp staff accept; suite tenant invite unit chỉ kiểm create. | `/Users/hoang/Rental_room_management/lib/features/auth/staff_invite_screen.dart:75`; `/Users/hoang/Rental_room_management/backend/src/staff/dto/accept-staff-invite.dto.ts:3`; không gán test lifecycle cho handler không được gọi. |
| GAP-SYS-08 | SYS-03 | Login chỉ kiểm User.isActive/password; STAFF profile/chủ trọ active kiểm tại JwtStrategy, nên có thể nhận session login nhưng request tiếp bị 401. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:71`; `/Users/hoang/Rental_room_management/backend/src/auth/jwt.strategy.ts:71`; không ghi login đã kiểm tất cả scope. |
| GAP-SYS-09 | SYS-03 | Remember me không được _submit gửi/tác động TTL; chưa có chính sách phiên theo checkbox. | `/Users/hoang/Rental_room_management/lib/features/auth/login_screen.dart:25`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:293`; không mô tả thời hạn khác theo UI. |
| GAP-SYS-10 | SYS-01/02/08/09/03 | Tạo User/kích hoạt và cấp phiên/ký/lưu client không cùng transaction toàn UC; failure sau commit có thể để account/acceptedAt/session đã tồn tại. MFA counter/recovery consume trước cấp login session. | `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:45`; `/Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.service.ts:139`; `/Users/hoang/Rental_room_management/backend/src/staff/staff.service.ts:149`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:66`; đặc tả bảo đảm tối thiểu không rollback giả. |
| GAP-SYS-11 | ADM-07.1 | Mất response confirm sau commit có thể mất mã recovery đã cấp một lần; chưa có regenerate/disable/re-display trong controller này. Chưa thử bằng authenticator thật. | `/Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:25`; `/Users/hoang/Rental_room_management/backend/src/auth/admin-mfa.service.ts:79`; không tạo chức năng khôi phục không có code. |
| GAP-SYS-12 | SYS-05.1 | Offline logout xóa client/cập nhật state, không chứng minh revoke server; token legacy thiếu sid chỉ revoke refresh. | `/Users/hoang/Rental_room_management/lib/data/auth/auth_api.dart:111`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:137`; không kết luận access token nào cũng vô hiệu ngay khi offline logout. |
| GAP-SYS-13 | SYS-10 | ADMIN invitation lifecycle coi ACTIVATED dựa bất kỳ audit auth.access_token_redeemed của user, không phân purpose nguồn. | `/Users/hoang/Rental_room_management/backend/src/admin/admin-lifecycle.service.ts:13`; không dùng nhãn lifecycle để khẳng định chỉ token INVITE đã dùng. |
| GAP-SYS-14 | SYS-01/02 | FullName whitespace-only bị UI chặn; DTO backend IsNotEmpty trước trim không chặn tên rỗng sau trim. Terms/confirm chỉ UI, không field API. | `/Users/hoang/Rental_room_management/backend/src/auth/dto/register.dto.ts:4`; `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:47`; không mô tả consent server chưa triển khai. |

Mã GAP dùng hậu tố UC rút gọn để gọn bảng; SYS-x tương ứng UC-SYS-x, ADM-07.1 tương ứng UC-ADM-07.1. Đây là giới hạn/điểm cần xem xét, không là tính năng đề xuất được gắn vào luồng AS-IS.

## 5. Rà gộp/tách và độ hạt

| Trường hợp | Nhận định | Quyết định đợt này |
|---|---|---|
| SYS-06 và SYS-10 | Dùng chung RedeemDto/redeem/UI nhưng quên mật khẩu cần yêu cầu gửi link; mời tài khoản có sẵn bắt đầu từ link INVITE và User do admin tạo. | Giữ hai mục tiêu/mã; không sao chép gửi provider vào SYS-10. Ghi chung mechanism trong quan hệ; chưa cần sửa UML/Catalog. |
| SYS-08, SYS-09, SYS-10 | Cùng tên kích hoạt/thiết lập nhưng khác model/token, tạo User mới so với đổi password User sẵn có, linked Tenant so với Staff scope, trả session so với signInAgain. | Không gộp ba UC; 7 ngày cho Tenant/Staff invite khác token account-access 30 phút. |
| SYS-01 và SYS-02 | Một form/service chung nhưng tạo LANDLORD so với TENANT, mục tiêu quản lý so với tìm phòng. | Giữ hai UC; không tách Validate email/Chuẩn hóa phone/Tạo JWT thành UC kỹ thuật. |
| SYS-05.1 và SYS-05.2 | Rời client hiện tại khác kiểm soát danh sách thiết bị; bulk/single là hai lựa chọn trong một mục tiêu quản lý phiên. | Giữ hai UC hiện tại; không tách từng endpoint GET/revoke/bulk thành ba UC. |
| SYS-03 và ADM-07.1 | Dùng mã đã cấu hình khác thiết lập phương thức và nhận recovery codes. | Không gộp; không biến nhập MFA/TOTP/step-up nội bộ thành UC mới. |
| SYS-07 và SYS-06 | Có biết current password/JWT so với khôi phục bằng token khi quên. | Không gộp; không đổi actor A01 của reset thành actor đã xác thực. |

**Số điều chỉnh Catalog/UML đã thực hiện: 0 gộp, 0 tách, 0 loại bỏ, 0 đổi mã/tên/actor.** Các chênh lệch UI/API được bổ sung vào đặc tả thay vì tùy tiện thu hẹp quyền Catalog. Không còn UC kỹ thuật mới/trùng mã phát sinh trong gói này.

## 6. Test đã thực thi và giới hạn

Chạy unit bằng Jest ở backend; kết quả 6 suite, 24 test đạt, không snapshot, không chạy DB E2E. Lệnh/từng test/status/thời điểm ở `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1`.

| Suite | Số test | Bằng chứng đạt thực tế | Không chứng minh |
|---|---|---|---|
| auth.service.spec.ts | 4 | đăng ký LANDLORD normalize; duplicate conflict; inactive login; đổi password/version/revoke refresh | toàn bộ HTTP DTO, phiên thực, STAFF/TENANT login, MFA login |
| jwt.strategy.spec.ts | 4 | map LANDLORD/ADMIN; từ chối non-access/missing user | tích hợp session revoked/version/profile STAFF trên DB thực |
| account-access.service.spec.ts | 1 | non-admin send rate limit | forgot response, redeem concurrent, email/provider |
| tenant-invites.service.spec.ts | 4 | tạo hashed invite và 3 nhánh lỗi create | accept Tenant, STAFF accept, commit PostgreSQL |
| admin-mfa.service.spec.ts | 7 | 6 vector TOTP SHA1 RFC và base32 | enroll/confirm/recovery lifecycle tích hợp hoặc authenticator thật |
| api-error.filter.spec.ts | 4 | contract lỗi, validation details và masking | mọi lỗi UI/backend trên runtime thật |

Không chạy Flutter tests trong đợt này; có đọc các test registration/navigation/account-access/admin sessions để định vị assertion, không báo chúng vừa đạt. Không chạy auth E2E vì harness có resetDatabase; không đụng dữ liệu nghiệp vụ thật, không gọi webhook/email/provider. Test source tồn tại không đồng nghĩa assertion phủ hết luồng.

Kiểm tài liệu riêng: markdown-it-py parse 11 tệp thành đúng 11 bảng, mỗi bảng có 2 header cells và 20 hàng dữ liệu; validator Node kiểm Catalog/Actor/UML, nguồn/dòng, nhãn truy vết và hash bảo toàn. Kết quả tại `Markdown_Parse_Result.json`, `Validation_Result.json`, `Source_Integrity_Result.json` trong thư mục Giai đoạn 4; không suy các kiểm tra này thành test runtime ứng dụng.

## 7. Kết luận cần người dùng xem xét

1. Ghi nhận chênh lệch API/UI SYS-05.2 và điểm truy cập Admin SYS-07; chọn để nguyên AS-IS hay lập yêu cầu phát triển sau (không tự bổ sung trong tài liệu hiện tại).
2. Xem xét chính sách vô hiệu AccountAccessToken sau đổi mật khẩu bằng current password; AS-IS hiện chưa có.
3. Xem xét bảo đảm giữ current session trong single revoke: label UI và backend khác nhau; không làm thay đổi quyền đã xác minh.
4. Cần môi trường test an toàn để nghiệm thu email/webhook, redeem đồng thời, MFA enrollment/login/recovery và transaction thật; kết quả unit chưa thay phần này.
5. Giữ phân tách SYS-06/SYS-10 và 3 cơ chế kích hoạt hiện tại cho truy vết; chưa có căn cứ bắt buộc gộp/đổi UML.

Không có câu hỏi nào buộc phải đoán nghiệp vụ để điền bảng. Mọi khoảng trống được ghi rõ; gói G01 đủ dùng làm nền đặc tả AS-IS có giới hạn xác minh, chưa phải biên bản nghiệm thu production. Ghi nhận lịch sử đợt G01: nhóm tiếp theo là G02 (6 UC). Lượt hoàn tất sau đó đã bổ sung đủ G02–G16; 11 bảng G01 được bảo toàn.


## Cập nhật lượt hoàn tất toàn hệ thống

Các số đo 6 suite/24 test và parser 11 bảng trong phần đợt đầu là lịch sử G01, không phải toàn bộ kết quả hiện tại. Bản test đợt đầu giữ ở `../Test_Execution_G01_Previous.json`. Lượt hoàn tất chạy 71 suite/736 test; validator/parser hiện kiểm toàn bộ 162 bảng. Không thay nội dung 11 bảng G01.
