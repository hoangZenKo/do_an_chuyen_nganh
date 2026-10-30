# Implementation Map

> Muc tieu: moi flow co bang A-Z rieng, moi buoc co file source ro rang, khong gom cum qua tay.
>
> Cap nhat: 2026-08-19.

## Cach doc

Tat ca duong dan tinh tu repository nay; source NestJS nam trong `backend/`.

1. Chon flow ban muon lam.
2. Doc cot `Buoc` tu tren xuong duoi.
3. Moi buoc co file can mo ngay trong cot `File`.
4. Doc `Backend` va `DB` neu flow do cham server/du lieu.
5. Doc `Tests / gap` de biet con can verify gi truoc khi chot.

## Cach dung file nay de code mot chuc nang

File nay khong chi la ban do file. No la playbook de ban lam theo tung buoc.

Cach dung dung:

1. Chon feature can lam, vi du `Login`, `Billing`, `Tenant portal invoice detail`.
2. Doc `Muc tieu` de biet chuc nang do dung de lam gi.
3. Doc `Implementation flow` de biet phai code theo thu tu nao.
4. Doc cot `File` de mo dung file can sua.
5. Doc `DB` de biet bang nao bi doc/ghi.
6. Doc `Tests / gap` de biet can verify gi truoc khi chot.
7. Khi co loi, quay lai dung buoc dang bi fail, khong sua lung tung cac file khac truoc.

Format toi uu cho moi feature:

| Muc | Ban can biet gi |
|---|---|
| Muc tieu | Chuc nang nay de lam gi |
| User flow | Nguoi dung bam gi, nhap gi, thay gi |
| Implementation flow | FE -> API -> BE -> DB -> response |
| File map | Can mo/sua file nao |
| Data map | Du lieu chay qua model, dto, table nao |
| Permission map | Ai duoc dung chuc nang nay |
| Tests / gap | Can chay test nao de chot |
| Definition of done | Khi nao coi nhu xong that |

## Demo feature: Login

### Muc tieu

Cho phep nguoi dung dang nhap bang email/password, luu session, va tu dong di den dung home theo role (`admin`, `landlord`, `staff`, `tenant`).

### User flow

1. Nguoi dung mo app.
2. App kiem tra session cu.
3. Neu chua co session hop le, app hien login screen.
4. Nguoi dung nhap email va password.
5. Nguoi dung bam dang nhap.
6. FE validate input co ban.
7. FE goi API login.
8. BE kiem tra email/password.
9. Neu dung, BE tao access token va refresh token.
10. BE tra session ve FE.
11. FE luu session vao secure storage.
12. FE cap nhat auth state.
13. Router redirect ve home dung role.
14. Neu sai, hien loi ngay tren form.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Khai bao route login va redirect theo auth state | `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart` | App mo dung flow auth, user chua dang nhap bi day ve login |
| 2 | Hien thi man hinh login | `lib/features/auth/login_screen.dart` | Nguoi dung thay man hinh login ro rang |
| 3 | Xay form email/password | `lib/features/auth/auth_form.dart` | Co validate, loading, error, submit button |
| 4 | Xu ly state login | `lib/features/auth/auth_providers.dart` | Co provider/ notifier dieu khien submit va auth state |
| 5 | Goi API login | `lib/data/auth/auth_api.dart` | POST dung payload len backend |
| 6 | Luu session local | `lib/data/auth/secure_session_storage.dart` | Restart app van con dang nhap neu token con hop le |
| 7 | Gan token vao request | `lib/core/network/api_client.dart` | Request sau login co Authorization header |
| 8 | Backend nhan request login | `backend/src/auth/auth.controller.ts` | Co route `POST /auth/login` |
| 9 | Backend xu ly logic login | `backend/src/auth/auth.service.ts` | Check user/password, tao token, tra response |
| 10 | Validate input | `backend/src/auth/dto/login.dto.ts` | Chan input sai format/empty |
| 11 | Doc/ghi DB | `backend/prisma/schema.prisma` | Doc `User`, ghi `RefreshToken` |
| 12 | Redirect sau login | `lib/features/auth/auth_navigation.dart`, `lib/app/app.dart` | Dieu huong ve dung home theo role |
| 13 | Verify | `test/features/auth/auth_navigation_test.dart`, `backend/src/auth/*.spec.ts` | Login flow khong bi vong, khong sai role |

### Data flow

```text
LoginScreen
→ AuthForm
→ auth providers
→ AuthApi.login()
→ POST /auth/login
→ AuthController.login()
→ AuthService.login()
→ Prisma User + RefreshToken
→ FE secure storage
→ auth state update
→ GoRouter redirect
```

### File map

| File | Vai tro |
|---|---|
| `lib/app/app.dart` | Tao router va redirect theo auth state |
| `lib/features/auth/auth_navigation.dart` | Quyet dinh home path theo role va guard route |
| `lib/features/auth/login_screen.dart` | UI login |
| `lib/features/auth/auth_form.dart` | Form dung chung cho login/register |
| `lib/features/auth/auth_providers.dart` | State, submit, loading, error |
| `lib/data/auth/auth_api.dart` | HTTP client cho auth |
| `lib/data/auth/secure_session_storage.dart` | Luu/xoa session |
| `lib/core/network/api_client.dart` | Gan token va refresh token logic |
| `backend/src/auth/auth.controller.ts` | Backend route |
| `backend/src/auth/auth.service.ts` | Backend logic |
| `backend/src/auth/dto/login.dto.ts` | Validate request |
| `backend/prisma/schema.prisma` | User/RefreshToken |

### Khi nao coi nhu xong

1. Dang nhap dung thi vao dung home.
2. Dang nhap sai thi hien loi.
3. Restart app van restore session.
4. Logout xoa session.
5. Request sau login co token.
6. Test frontend va backend deu pass.

## Route inventory

| Nhom | Routes | File |
|---|---|---|
| Startup/auth | `/splash`, `/onboarding`, `/auth/login`, `/auth/register` | `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart` |
| Invite activation | `/tenant/activate?code=...`, `/staff/activate?code=...` | `lib/app/app.dart`, `lib/features/auth/tenant_invite_screen.dart`, `lib/features/auth/staff_invite_screen.dart` |
| Landlord shell | `/dashboard`, `/settings`, `/settings/password`, `/settings/fake-zalo` | `lib/app/app.dart`, `lib/features/dashboard/dashboard_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/features/tenant_portal/tenant_zalo_screen.dart` |
| Property/room | `/properties`, `/properties/form`, `/rooms/form`, `/rooms/:id` | `lib/app/app.dart`, `lib/features/properties/*`, `lib/features/rooms/*` |
| Tenant/lease | `/tenants`, `/tenants/form`, `/tenants/:id`, `/leases/form`, `/lease-expiry` | `lib/app/app.dart`, `lib/features/tenants/*` |
| Billing/ops | `/billing`, `/billing/bulk`, `/billing/form`, `/billing/:id`, `/expenses`, `/expenses/form`, `/maintenance`, `/maintenance/form`, `/reports`, `/audit`, `/notifications`, `/actions`, `/staff` | `lib/app/app.dart`, `lib/features/billing/*`, `lib/features/expenses/*`, `lib/features/maintenance/*`, `lib/features/reports/*`, `lib/features/audit/*`, `lib/features/notifications/*`, `lib/features/operations/*`, `lib/features/staff/*` |
| Tenant portal | `/tenant`, `/tenant/password`, `/tenant/zalo`, `/tenant/invoices`, `/tenant/invoices/:id`, `/tenant/maintenance` | `lib/app/app.dart`, `lib/features/tenant_portal/*` |
| Admin | `/admin`, `/admin/landlords`, `/admin/landlords/form`, `/admin/landlords/:id`, `/admin/properties`, `/admin/properties/form`, `/admin/properties/:id` | `lib/app/app.dart`, `lib/features/admin/*` |

## Route and role gates

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Dinh nghia route constants/path helper | `lib/features/auth/auth_navigation.dart` |
| 2 | Gan `GoRouter`, redirect va transition rieng cho Zalo screens | `lib/app/app.dart` |
| 3 | Chon home theo role `admin`, `tenant`, `staff`, `landlord` | `lib/features/auth/auth_navigation.dart` |
| 4 | Guard landlord/admin/tenant/settings route | `lib/features/auth/auth_navigation.dart` |
| 5 | Guard staff theo permissions | `lib/features/auth/auth_navigation.dart`, `lib/models/auth_models.dart` |
| 6 | Backend roles/permissions guard | `backend/src/common/*`, `backend/src/staff/staff-presets.ts` |
| 7 | Tests / gap | `test/features/auth/auth_navigation_test.dart`; can bo sung matrix cho tat ca staff permissions |

## Auth: login

### Muc tieu

Dang nhap nguoi dung bang email/password, tao session, luu token local, va dua nguoi dung ve dung man hinh theo role.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Kiem tra route login va redirect auth | `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart` | User chua dang nhap vao `/auth/login`; user da dang nhap khong bi quay lai login |
| 2 | Hien UI login | `lib/features/auth/login_screen.dart` | Man hinh login render dung title, form, loading/error |
| 3 | Validate form email/password | `lib/features/auth/auth_form.dart` | Khong submit khi email/password rong; hien loi de hieu |
| 4 | Xu ly submit trong state layer | `lib/features/auth/auth_providers.dart` | Khi bam login thi set loading, goi API, set success/error |
| 5 | Goi backend login | `lib/data/auth/auth_api.dart` | Gui `POST /auth/login` dung payload `{ email, password }` |
| 6 | Backend nhan request | `backend/src/auth/auth.controller.ts` | Route `/auth/login` nhan DTO va goi service |
| 7 | Backend validate body | `backend/src/auth/dto/*` | Body sai format bi chan truoc khi vao logic |
| 8 | Backend check user/password | `backend/src/auth/auth.service.ts` | Tim `User`, verify password hash, tao token neu hop le |
| 9 | DB doc/ghi session | `backend/prisma/schema.prisma` | Doc `User`, tao/cap nhat `RefreshToken` |
| 10 | FE parse va luu session | `lib/models/auth_models.dart`, `lib/data/auth/secure_session_storage.dart` | Access token, refresh token, user duoc luu local |
| 11 | Gan token cho request tiep theo | `lib/core/network/api_client.dart` | Request sau login co `Authorization: Bearer ...` |
| 12 | Dieu huong theo role | `lib/features/auth/auth_navigation.dart`, `lib/app/app.dart` | `admin -> /admin`, `tenant -> /tenant`, `landlord/staff -> /dashboard` |
| 13 | Xu ly 401/refresh token | `lib/core/network/api_client.dart`, `lib/data/auth/token_refresh_coordinator.dart`, `lib/data/auth/auth_api.dart` | Access token het han thi refresh 1 lan, retry request cu |
| 14 | Verify | `test/features/auth/auth_navigation_test.dart`, `test/core/network/api_client_test.dart`, `backend/src/auth/*.spec.ts` | Login, redirect, token attach/refresh duoc bao ve bang test |

### Data flow thanh cong

```text
LoginScreen
→ AuthForm submit(email, password)
→ auth_providers login handler
→ AuthApi.login()
→ POST /auth/login
→ AuthController
→ AuthService
→ Prisma User + RefreshToken
→ response AuthSession
→ SecureSessionStorage.save()
→ auth state = authenticated
→ GoRouter redirect theo role
```

### Failure flow hay gap

| Loi | Kiem tra file nao | Huong xu ly |
|---|---|---|
| Bam login khong co gi xay ra | `login_screen.dart`, `auth_form.dart`, `auth_providers.dart` | Kiem tra callback submit, loading state, form validation |
| API khong duoc goi | `auth_providers.dart`, `auth_api.dart` | Kiem tra provider co goi dung method API khong |
| Sai password nhung UI khong hien loi | `auth_api.dart`, `api_failure.dart`, `auth_providers.dart`, `auth_form.dart` | Kiem tra error mapping va error display |
| Login xong khong redirect | `auth_navigation.dart`, `app.dart` | Kiem tra role home path va router refresh/auth state |
| Request sau login bi 401 | `secure_session_storage.dart`, `api_client.dart` | Kiem tra token co luu va attach vao header khong |
| Staff login duoc nhung vao sai man | `auth_navigation.dart`, `models/auth_models.dart`, `backend/src/staff/staff-presets.ts` | Kiem tra permission map va route guard |

### DB / API contract

| Thanh phan | Noi dung |
|---|---|
| API | `POST /auth/login` |
| Request | `{ email, password }` |
| Response | `accessToken`, `refreshToken`, `user`, `role`, `permissions` |
| DB doc | `User` |
| DB ghi | `RefreshToken` |
| Permission | Login khong can permission; role/permission duoc dung sau khi login |

### Definition of done

1. Login dung tai khoan thi thanh cong.
2. Login sai password/email thi hien loi va khong luu session.
3. Session duoc luu local.
4. Restart app restore duoc session neu token hop le.
5. User duoc redirect dung theo role.
6. Request sau login co token.
7. Refresh token khong bi race khi nhieu request 401.
8. Logout xoa session va quay ve login.
9. Test FE/BE lien quan pass.

## Auth: register

### Muc tieu

Cho phep nguoi dung tao tai khoan moi, dat session ban dau neu flow co cho phep, va khong lam lo role/permission sai.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo register screen | `lib/features/auth/register_screen.dart` | Nguoi dung thay form dang ky ro rang |
| 2 | Dung form chung | `lib/features/auth/auth_form.dart` | Validation ten/email/password hien dung |
| 3 | Xu ly submit va loading | `lib/features/auth/auth_providers.dart` | Nut submit disabled khi dang xu ly |
| 4 | Goi API register | `lib/data/auth/auth_api.dart` | Gui payload dung len backend |
| 5 | Backend nhan request | `backend/src/auth/*` | Route register nhan body hop le |
| 6 | Backend validate | `backend/src/auth/dto/*` | Chan email sai format, password yeu |
| 7 | Backend tao user | `backend/src/auth/auth.service.ts` | Ghi `User` moi vao DB |
| 8 | Tao session neu cho phep | `backend/src/auth/auth.service.ts` | Tra token va user ve FE |
| 9 | Luu session local | `lib/data/auth/secure_session_storage.dart` | App mo lai van con trang thai hop le neu token con han |
| 10 | Redirect sau dang ky | `lib/features/auth/auth_navigation.dart`, `lib/app/app.dart` | Di ve dung home theo role |
| 11 | Verify | `test/features/auth/auth_navigation_test.dart`, `backend/src/auth/*.spec.ts` | Dang ky, redirect, validation duoc bao ve |

### Data flow thanh cong

```text
RegisterScreen
→ AuthForm submit
→ auth_providers register handler
→ AuthApi.register()
→ backend auth register route
→ AuthService.createUser()
→ Prisma User (+ RefreshToken neu co)
→ SecureSessionStorage.save()
→ auth state update
→ GoRouter redirect
```

### File map

| File | Vai tro |
|---|---|
| `lib/features/auth/register_screen.dart` | UI dang ky |
| `lib/features/auth/auth_form.dart` | Form va validation chung |
| `lib/features/auth/auth_providers.dart` | State submit/register |
| `lib/data/auth/auth_api.dart` | HTTP register call |
| `lib/data/auth/secure_session_storage.dart` | Luu session |
| `lib/features/auth/auth_navigation.dart` | Redirect |
| `backend/src/auth/auth.service.ts` | Tao user, hash mat khau |
| `backend/src/auth/dto/*` | Validate body |
| `backend/prisma/schema.prisma` | `User`, `RefreshToken` |

### Failure flow hay gap

| Loi | File can xem truoc | Cach phan biet |
|---|---|---|
| Bam dang ky khong co gi xay ra | `register_screen.dart`, `auth_form.dart`, `auth_providers.dart` | Kiem tra callback va loading |
| Email da ton tai | `auth_api.dart`, `auth.service.ts`, `api_failure.dart` | Mapping error `EMAIL_ALREADY_EXISTS` |
| Dang ky xong nhung khong vao app | `auth_navigation.dart`, `secure_session_storage.dart` | Kiem tra session va redirect |
| User moi co role sai | `auth.service.ts`, `auth_models.dart` | Kiem tra backend default role |

### Definition of done

1. Dang ky tao duoc user moi.
2. Validation loi hien dung.
3. Session duoc luu neu flow co login ngay.
4. Role/permission khoi tao dung.
5. Test FE/BE lien quan pass.

## Auth: session restore

### Muc tieu

Tu dong khoi phuc trang thai dang nhap tu session local khi mo lai app, neu token van con hop le.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | App boot gap splash/auth state | `lib/app/app.dart`, `lib/features/splash/splash_screen.dart` | App khong flash sai man hinh |
| 2 | Doc session local | `lib/data/auth/secure_session_storage.dart` | Lay access/refresh token va user |
| 3 | Khoi tao auth state | `lib/features/auth/auth_providers.dart` | Provider chuyen sang authenticated neu hop le |
| 4 | Kiem tra token hieu luc | `lib/core/network/api_client.dart` | Token het han se khong mat state ngay neu refresh duoc |
| 5 | Goi `/auth/me` neu can | `backend/src/auth/*` | Xac minh user/role tu backend |
| 6 | Redirect sau restore | `lib/features/auth/auth_navigation.dart` | Di den home dung role |
| 7 | Verify | `test/features/auth/auth_navigation_test.dart` | Restore khong bi loop |

### File map

| File | Vai tro |
|---|---|
| `lib/features/auth/auth_providers.dart` | Restore flow va auth state |
| `lib/data/auth/secure_session_storage.dart` | Nguon luu local |
| `lib/app/app.dart` | Entry point va router |
| `lib/features/splash/splash_screen.dart` | Man hinh cho khi restore |
| `backend/src/auth/*` | Backend session/me endpoint |
| `backend/prisma/schema.prisma` | `User`, `RefreshToken` |

### Khi nao co loi

| Loi | Noi can xem |
|---|---|
| Vao app bi quay ve login lien tuc | `secure_session_storage.dart`, `auth_providers.dart` |
| App mo len bi trang trung gian qua lau | `splash_screen.dart`, `app.dart` |
| Restore dung nhung role sai | `auth_navigation.dart`, backend `/auth/me` |

### Definition of done

1. Mo app len co the restore session neu token hop le.
2. Token het han thi co duong refresh.
3. Khong bi vong redirect.
4. UI khong flash man hinh sai.

## Auth: refresh token

### Muc tieu

Tu dong lay access token moi khi request bi 401, va chong race condition khi nhieu request cung refresh.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Bắt 401 tu request | `lib/core/network/api_client.dart` | Request loi co the duoc retry |
| 2 | Cho request khac dung chung 1 lan refresh | `lib/data/auth/token_refresh_coordinator.dart` | Khong refresh song song |
| 3 | Goi refresh API | `lib/data/auth/auth_api.dart` | Tra token moi |
| 4 | Cap nhat session local | `lib/data/auth/secure_session_storage.dart` | Token moi duoc luu |
| 5 | Retry request goc | `lib/core/network/api_client.dart` | API request tiep tuc chay |
| 6 | Backend verify refresh token | `backend/src/auth/*` | Token cu het han bi chan |
| 7 | DB | `User`, `RefreshToken` | Token rotation/co the revoke |
| 8 | Verify | `test/core/network/api_client_test.dart` | Race/refresh behavior duoc bao ve |

### File map

| File | Vai tro |
|---|---|
| `lib/core/network/api_client.dart` | Interceptor 401/retry |
| `lib/data/auth/token_refresh_coordinator.dart` | Chong refresh song song |
| `lib/data/auth/auth_api.dart` | Refresh request |
| `lib/data/auth/secure_session_storage.dart` | Luu token moi |
| `backend/src/auth/*` | Refresh endpoint |
| `backend/prisma/schema.prisma` | Refresh token storage |

### Failure flow hay gap

| Loi | File can xem truoc | Cach phan biet |
|---|---|---|
| Hết token ma request treo | `api_client.dart` | Kiem tra refresh promise |
| Nhieu request 401 refresh cung luc | `token_refresh_coordinator.dart` | Kiem tra lock/queue |
| Refresh xong van 401 | `secure_session_storage.dart`, backend auth | Kiem tra token moi da luu hay chua |

### Definition of done

1. 401 co duong refresh.
2. Khong double refresh.
3. Request goc retry thanh cong neu refresh thanh cong.
4. Het session thi ve login.

## Auth: logout

### Muc tieu

Xoa session local, huy refresh token neu backend co, va dua nguoi dung ve login.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | User bam logout | `lib/features/auth/auth_providers.dart` | State chuan bi clear |
| 2 | Goi logout API | `lib/data/auth/auth_api.dart` | Backend co the revoke token |
| 3 | Xoa session local | `lib/data/auth/secure_session_storage.dart` | Token mat khoi may |
| 4 | Reset auth state | `lib/features/auth/auth_providers.dart` | App khong coi la authenticated nua |
| 5 | Redirect ve login | `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart` | Vao dung login screen |
| 6 | Backend logout | `backend/src/auth/*` | Co the revoke refresh token |
| 7 | DB | `RefreshToken` | Token cu khong dung lai duoc |
| 8 | Verify | `test/features/auth/auth_navigation_test.dart` | Logout khong de route cu bi sticky |

### Definition of done

1. Logout xoa session local.
2. Khong con request nao attach token cu.
3. Router ve login.
4. Session cu khong dung lai duoc.

## Auth: tenant invite accept

### Muc tieu

Cho tenant chấp nhan loi moi va gan tai khoan voi tenant profile dung giang buoc.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo invite screen | `lib/features/auth/tenant_invite_screen.dart` | Nguoi dung thay form accept invite |
| 2 | Dung form chung | `lib/features/auth/auth_form.dart` | Co validation co ban |
| 3 | Submit invite code | `lib/features/auth/auth_providers.dart` | Goi API accept invite |
| 4 | Backend xac minh invite | `backend/src/tenants/tenant-invites.controller.ts`, `backend/src/tenants/tenant-invites.service.ts` | Invite hop le moi duoc accept |
| 5 | Gan user/tenant | `backend/src/tenants/*` | `Tenant.userId` duoc set |
| 6 | DB | `TenantInvite`, `Tenant`, `User` | Moi lien duoc luu |
| 7 | Redirect | `lib/features/auth/auth_navigation.dart` | Di den tenant home |
| 8 | Verify | `test/features/auth/auth_navigation_test.dart` | Invite flow khong sai role |

### Definition of done

1. Invite code hop le thi accept duoc.
2. Tenant duoc gan voi user.
3. Khong cho accept lai code da dung.
4. Role vao dung tenant portal.

## Auth: staff invite accept

### Muc tieu

Cho staff chấp nhan loi moi, tao profile staff va gan permission preset dung.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo staff invite screen | `lib/features/auth/staff_invite_screen.dart` | Form accept invite hien ra |
| 2 | Nhap thong tin va submit | `lib/features/auth/auth_form.dart`, `lib/features/auth/auth_providers.dart` | Submit goi API |
| 3 | Backend staff invite | `backend/src/staff/staff.controller.ts`, `backend/src/staff/staff.service.ts` | Invite duoc xac minh |
| 4 | Khoi tao staff profile | `backend/src/staff/*` | `StaffProfile` duoc tao |
| 5 | Gan role/permission | `backend/src/staff/staff-presets.ts` | Permission preset dung |
| 6 | DB | `StaffInvite`, `UserRole.STAFF`, `StaffProfile` | Du lieu staff day du |
| 7 | Redirect | `lib/features/auth/auth_navigation.dart` | Staff vao dung shell |
| 8 | Verify | `backend/src/staff/*.spec.ts` | Guard va preset khong bi sai |

### Definition of done

1. Invite staff accept duoc.
2. Role staff duoc set dung.
3. Permission preset khong sai.
4. Staff vao dung khu vuc app.

## Startup / onboarding

### Muc tieu

Dung splash/onboarding de dan nguoi dung moi vao app dung luong va khong lam lenh xenh auth state.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Hien splash luc app mo | `lib/features/splash/splash_screen.dart` | Co trang cho trong luc check state |
| 2 | Chay onboarding neu can | `lib/features/onboarding/onboarding_screen.dart` | Nguoi dung moi thay huong dan |
| 3 | Doc onboarding state | `lib/features/onboarding/onboarding_providers.dart` | Biet da xem hay chua |
| 4 | Noi vao app shell | `lib/app/app.dart` | Di tiep login/home dung luong |
| 5 | Verify | `test/widget_test.dart` va test onboarding lien quan | Khong co flash route sai |

### Definition of done

1. Splash khong treo.
2. Onboarding co the qua bo qua.
3. App di dung auth flow tiep theo.

## Settings / account tools

### Muc tieu

Quan ly mat khau va cong cu tai khoan lien quan Zalo/messaging trong mot noi.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo settings | `lib/features/settings/settings_screen.dart` | Co entry point cho account tools |
| 2 | Doi mat khau tenant | `lib/features/tenant_portal/tenant_change_password_screen.dart`, `lib/data/auth/auth_api.dart` | Password duoc cap nhat an toan |
| 3 | Mo fake Zalo simulator | `lib/features/tenant_portal/tenant_zalo_screen.dart` | Co cong cu test thong diep |
| 4 | Launch messaging deep link | `lib/core/messaging/messaging_launcher.dart` | Mo app nhan tin / Zalo link |
| 5 | Backend password/Zalo endpoints | `backend/src/auth/*`, `backend/src/notifications/*` | Route backend phu hop |
| 6 | DB | `User`, `NotificationDelivery`, `NotificationRead` | Doi mat khau va read state co data |
| 7 | Verify | `test/features/tenant_portal/*`, `test/features/settings/*` neu co | Manual + widget coverage |

### Definition of done

1. Doi mat khau chay duoc.
2. Zalo/messaging tool khong gay crash.
3. Settings khong lam rot auth state.

## Dashboard landlord

### Muc tieu

Tong hop so lieu quan trong cho chu tro: phong, hop dong, hoa don, thanh toan, thong bao va action items.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo dashboard screen | `lib/features/dashboard/dashboard_screen.dart` | Thay chart/cards/summary |
| 2 | Lay metrics tu providers | `lib/features/dashboard/dashboard_providers.dart` | So lieu tai len dung |
| 3 | Mo notifications | `lib/features/notifications/notifications_screen.dart` | Thay thong bao moi |
| 4 | Mo operations/action items | `lib/features/operations/action_items_screen.dart` | Co danh sach viec can lam |
| 5 | Backend dashboard | `backend/src/dashboard/*` | Metrics dung role/scope |
| 6 | DB | `Property`, `Room`, `Lease`, `Invoice`, `Payment` | Metrics co nguon du lieu |
| 7 | Verify | `test/dashboard_test.dart`, `test/data/dashboard/dashboard_api_test.dart` | KPI va scope khong sai |

### Definition of done

1. Dashboard load duoc so lieu dung scope.
2. Khong lay lan du lieu property khac.
3. Summary cards khong sai so.

## Property

### Muc tieu

Quan ly property, tao/sua/xem danh sach property, va lam nen cho room/lease/billing.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo property list | `lib/features/properties/properties_list_screen.dart` | Co danh sach property |
| 2 | Mo property form | `lib/features/properties/property_form_screen.dart` | Tao/sua property duoc |
| 3 | Doc API repo | `lib/data/rooms/property_api.dart`, `lib/data/rooms/room_repository.dart` | CRUD goi dung backend |
| 4 | Backend property | `backend/src/properties/*` | Route dung va co guard |
| 5 | DB | `Property` | Du lieu property luu dung |
| 6 | Verify | test CRUD lien quan | UI/route/permission khong sai |

### Definition of done

1. Property CRUD duoc.
2. Property la root scope cho room/lease/billing.
3. UI cap nhat sau save/delete.

## Room list / detail / form

### Muc tieu

Quan ly phong, trang thai vacant/occupied, chi tiet phong va sub-resource lien quan.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo rooms list | `lib/features/rooms/rooms_list_screen.dart` | Thay danh sach phong |
| 2 | Mo room detail | `lib/features/rooms/room_detail_screen.dart` | Xem tenant, lease, asset, service fee |
| 3 | Mo room form | `lib/features/rooms/room_form_screen.dart` | Tao/sua room duoc |
| 4 | Doc providers | `lib/features/rooms/room_providers.dart` | State refresh dung |
| 5 | Doc repo/api | `lib/data/rooms/room_api.dart`, `lib/data/rooms/room_repository.dart` | CRUD va subresource calls |
| 6 | Doc selection helpers | `lib/features/rooms/property_selection_provider.dart` | Chon property dung scope |
| 7 | Backend rooms | `backend/src/rooms/*` | Route va guard dung |
| 8 | DB | `Room`, `RoomAsset`, `RoomInspection`, `RoomServiceFee` | Room subresources co data |
| 9 | Verify | `test/rooms_test.dart`, `test/features/rooms/room_detail_screen_test.dart`, `test/data/rooms_lifecycle_api_test.dart` | CRUD va lifecycle pass |

### Definition of done

1. Room CRUD xong.
2. Room status doi dung sau lease/end.
3. Detail screen khong missing subresource.

## Tenant list / detail / form

### Muc tieu

Quan ly tenant, link voi lease, co profile, account va invite flow.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo tenants list | `lib/features/tenants/tenants_list_screen.dart` | Danh sach tenant hien ra |
| 2 | Mo tenant detail | `lib/features/tenants/tenant_detail_screen.dart` | Xem lease, account, timeline |
| 3 | Mo tenant form | `lib/features/tenants/tenant_form_screen.dart` | Tao/sua tenant |
| 4 | Doc providers | `lib/features/tenants/tenant_providers.dart` | State dung |
| 5 | Doc repo/api | `lib/data/tenants/tenant_api.dart`, `lib/data/tenants/tenant_repository.dart` | CRUD va action calls |
| 6 | Doc model | `lib/models/tenant.dart` | Field map dung |
| 7 | Doc invite/account actions | `lib/features/tenants/tenant_detail_screen.dart`, `lib/data/tenants/tenant_api.dart` | Active account/invite behavior |
| 8 | Backend tenants | `backend/src/tenants/*` | Route hop le |
| 9 | DB | `Tenant`, `TenantInvite`, `User`, active lease refs | Quan he tenant/day du |
| 10 | Verify | `test/data/tenants_lifecycle_api_test.dart` | Lifecycle co bao ve |

### Definition of done

1. Tenant CRUD duoc.
2. Detail screen co du lieu lease/account.
3. Invite/account action khong sai scope.

## Lease create / renew / end / expiry / deposit / pdf

### Muc tieu

Quan ly vong doi hop dong thue: tao, gia han, ket thuc, theo doi han, deposit va PDF.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo lease form | `lib/features/tenants/lease_form_screen.dart` | Tao hop dong moi |
| 2 | Mo tenant detail lease actions | `lib/features/tenants/tenant_detail_screen.dart` | Co nut renew/end/deposit |
| 3 | Mo lease expiry screen | `lib/features/tenants/lease_expiry_screen.dart` | Danh sach sắp het han |
| 4 | Mo lease PDF | `lib/features/tenants/lease_pdf.dart` | Xuat hop dong PDF |
| 5 | Doc API | `lib/data/tenants/lease_api.dart` | CRUD/renew/end goi dung |
| 6 | Doc tenant repo + providers | `lib/data/tenants/tenant_repository.dart`, `lib/features/tenants/tenant_providers.dart` | Lease actions lien ket tenant |
| 7 | Doc model | `lib/models/lease.dart` | Status and deposit fields dung |
| 8 | Backend leases | `backend/src/leases/*` | Route va business rules |
| 9 | DB | `Lease`, `LeaseChange`, `DepositTransaction` | Luu lich su hop dong |
| 10 | Verify | test lease related hien co | Renew/deposit widget tests can bo sung |

### Definition of done

1. Tao/renew/end lease chay dung.
2. Expiry screen lay du lieu dung.
3. PDF xuat duoc.
4. Deposit transaction khong sai state.

## Tenant portal overview

### Muc tieu

Cua so cho tenant xem hoa don, thong bao, maintenance, thanh toan va tuong tac portal.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo portal screen | `lib/features/tenant_portal/tenant_portal_screen.dart` | Trang portal tong hop hien ra |
| 2 | Doc providers | `lib/features/tenant_portal/tenant_portal_providers.dart` | State portal load dung |
| 3 | Doc repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` | API tenant portal chay |
| 4 | Doc model | `lib/models/tenant_portal.dart` | Map data dung |
| 5 | Backend portal | `backend/src/tenant-portal/*` | Route portal co guard |
| 6 | DB | `Tenant`, `Lease`, `Invoice`, `PaymentProof`, `MaintenanceTicket`, `NotificationRead` | Portal tong hop du lieu dung |
| 7 | Verify | portal flow da wire | Device QA can bo sung |

### Definition of done

1. Tenant nhin thay tong hop dung scope.
2. Portal khong lo du lieu landlord khac.
3. Navigation trong portal on dinh.

## Tenant portal: invoice detail

### Muc tieu

Cho tenant xem chi tiet hoa don, trang thai thanh toan, va submit chung tu khi can.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo invoice detail | `lib/features/tenant_portal/tenant_invoice_detail_screen.dart` | Xem chi tiet invoice |
| 2 | Doc providers | `lib/features/tenant_portal/tenant_portal_providers.dart` | State invoice/portal update |
| 3 | Doc repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` | Lay chi tiet va submit proof |
| 4 | Doc model | `lib/models/billing.dart`, `lib/models/tenant_portal.dart` | Status/amount/proof map dung |
| 5 | Backend tenant invoice detail | `backend/src/tenant-portal/*`, `backend/src/billing/*` | Route co guard tenant |
| 6 | DB | `Invoice`, `Payment`, `PaymentProof` | Lich su thanh toan/co chung tu |
| 7 | Verify | invoice detail + proof submit source co san | Runtime proof upload/review can test |

### Definition of done

1. Tenant xem duoc chi tiet hoa don cua minh.
2. Co the submit chung tu neu quy trinh cho phep.
3. Khong doc duoc invoice khac scope.

## Tenant portal: maintenance request

### Muc tieu

Tenant tao ticket bao tri, them comment va theo doi trang thai.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo maintenance list | `lib/features/tenant_portal/tenant_maintenance_screen.dart` | Tenant thay danh sach bao tri day du |
| 2 | Doc portal providers | `lib/features/tenant_portal/tenant_portal_providers.dart` | State ticket/comment dung |
| 3 | Tao ticket/comment | `lib/data/tenant_portal/tenant_portal_api.dart`, `lib/data/tenant_portal/tenant_portal_repository.dart` | Submit/refresh chay dung |
| 4 | Doc model | `lib/models/maintenance.dart` | Ticket/comment fields dung |
| 5 | Backend maintenance | `backend/src/tenant-portal/*`, `backend/src/maintenance/*` | Guard tenant + staff follow-up |
| 6 | DB | `MaintenanceTicket`, `MaintenanceComment`, `Tenant`, `Room` | Lich su bao tri day du |
| 7 | Dashboard shortcut | `lib/features/tenant_portal/tenant_portal_screen.dart`, `lib/features/auth/auth_navigation.dart`, `lib/app/app.dart` | Shortcut va route `/tenant/maintenance` chay |
| 8 | Verify | `test/data/tenant_portal/tenant_portal_api_test.dart`, `test/features/auth/auth_navigation_test.dart` | API/route regression pass; upload runtime can QA |

### Definition of done

1. Tenant tao ticket duoc.
2. Tenant loc/xem chi tiet ticket duoc.
3. Comment update duoc.
4. Staff/landlord xem duoc ticket tuong ung.

## Tenant portal: change password

### Muc tieu

Tenant doi mat khau tu portal ma khong can logout sai cach.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo change password screen | `lib/features/tenant_portal/tenant_change_password_screen.dart` | Form doi mat khau hien ra |
| 2 | Doc auth/session | `lib/features/auth/auth_providers.dart`, `lib/data/auth/secure_session_storage.dart` | Dung user hien tai |
| 3 | Goi backend | `backend/src/auth/*` | Doi mat khau hop le |
| 4 | DB | `User` | Password hash duoc cap nhat |
| 5 | Verify | password change source co san | Device/manual verify can |

### Definition of done

1. Password doi duoc.
2. Session van on dinh hoac dang xuat an toan neu backend yeu cau.
3. Khong lam lo password cu.

## Tenant portal: Zalo inbox/chat

### Muc tieu

Hien thi doi thoai/nhan thong bao Zalo giua tenant va chu tro, bao gom read state va delivery state.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo Zalo screen | `lib/features/tenant_portal/tenant_zalo_screen.dart` | Tenant thay inbox/chat |
| 2 | Doc chat state | `lib/features/tenant_portal/tenant_portal_providers.dart` | Message list load dung |
| 3 | Doc message model | `lib/models/notification_delivery.dart` | Delivery metadata hien dung |
| 4 | Doc repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` | Send/read behavior chay dung |
| 5 | Backend Zalo message | `backend/src/tenant-portal/*` | Route tra/ghi nhan dung |
| 6 | Backend read state | `backend/src/tenant-portal/*`, `backend/prisma/schema.prisma` | `NotificationRead` duoc luu |
| 7 | DB | `NotificationDelivery`, `NotificationRead` | Lich su message/read day du |
| 8 | Verify | Zalo two-way flow da wire | Manual verify can |

### Definition of done

1. Tenant nhan thay message dung scope.
2. Read state duoc ghi nhan.
3. Delivery log co the truy vet.

## Billing list / form / detail

### Muc tieu

Cho chu tro va staff co quyen xem danh sach hoa don, tao hoa don le, cap nhat hoa don, ghi nhan thanh toan, huy hoa don, dao thanh toan, xem/duyet chung tu thanh toan, in/xuat PDF va gui nhac no.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo billing shell va load danh sach invoice | `lib/features/billing/billing_screen.dart` | Thay list hoa don, summary, filter, pending proof, reminder card |
| 2 | Lay du lieu billing qua provider | `lib/features/billing/billing_providers.dart` | `invoicesProvider`, `pendingPaymentProofsProvider`, `billingRemindersProvider` cap nhat dung |
| 3 | Goi repository/api de lay invoice | `lib/data/billing/billing_repository.dart`, `lib/data/billing/billing_api.dart` | API `/billing/invoices`, `/billing/payment-proofs`, `/billing/reminders` chay dung |
| 4 | Mo billing form de lap hoa don le | `lib/features/billing/billing_form_screen.dart` | User chon room, nhap chi so, phi phu, due date, preview |
| 5 | Tinh truoc chi so va khoa du lieu can | `lib/features/billing/widgets/meter_reading_fields.dart` | Chi so dien nuoc hop le, khong duoc current < previous |
| 6 | Submit tao hoa don | `lib/features/billing/billing_form_screen.dart`, `lib/features/billing/billing_providers.dart` | Form submit thanh cong va refresh list/summary |
| 7 | Backend nhan tao hoa don | `backend/src/billing/billing.controller.ts` | Route `/billing/invoices` nhan request tao hoa don |
| 8 | Backend xu ly business logic | `backend/src/billing/billing.service.ts` | Tinh tien, tao `Invoice`, tao `MeterReading`, verify lease/month |
| 9 | Validate input | `backend/src/billing/dto/create-invoice.dto.ts`, `backend/src/billing/dto/create-meter-reading.dto.ts` | Chan payload sai, duplicate utility reading, invalid date |
| 10 | Doc/ghi DB | `backend/prisma/schema.prisma` | Doc `Lease`, ghi `Invoice`, `MeterReading`, `Payment`, `PaymentProof` |
| 11 | Mo invoice detail | `lib/features/billing/invoice_detail_screen.dart` | Xem chi tiet, timeline, action buttons |
| 12 | Ghi nhan thanh toan | `lib/features/billing/invoice_detail_screen.dart`, `lib/features/billing/billing_providers.dart`, `lib/data/billing/billing_api.dart` | Submit payment va cap nhat status/remaining |
| 13 | Huy hoa don / dao thanh toan | `lib/features/billing/invoice_detail_screen.dart`, `lib/data/billing/billing_repository.dart` | Co dialog, note, va refresh detail/list |
| 14 | Duyet chung tu thanh toan | `lib/features/billing/invoice_detail_screen.dart`, `lib/features/billing/billing_providers.dart` | Approve/reject proof, cap nhat invoice/payment state |
| 15 | Xuat PDF / share | `lib/features/billing/invoice_pdf.dart`, `lib/features/billing/invoice_detail_screen.dart` | Tao PDF va share/print duoc |
| 16 | Nhac no / Zalo reminder | `lib/features/billing/billing_screen.dart`, `lib/data/reports/reports_api.dart` | Copy reminder, gui Zalo, refresh reminder list |
| 17 | Backend payment/proof/cancel/reverse | `backend/src/billing/billing.controller.ts`, `backend/src/billing/billing.service.ts` | Route payments, cancel, reverse, review proof chay dung |
| 18 | Verify | `test/data/billing/billing_api_test.dart`, `test/features/billing/meter_reading_fields_test.dart`, `test/features/billing/invoice_timeline_test.dart`, `backend/src/billing/billing.service.spec.ts` | Tao hoa don, thanh toan, cancel, reverse, proof review deu co test bao ve |

### Data flow thanh cong

```text
BillingScreen / BillingFormScreen / InvoiceDetailScreen
→ billing providers
→ BillingRepository
→ BillingApi
→ POST/GET/PATCH /billing/...
→ BillingController
→ BillingService
→ Prisma Invoice + MeterReading + Payment + PaymentProof
→ response ve FE model Invoice / PaymentProof
→ UI refresh list/detail/summary
```

### Flow tao hoa don le

| Buoc | File | Viec can lam |
|---|---|---|
| 1 | `billing_form_screen.dart` | Chon room, nhap ky hoa don, chi so, phi phu |
| 2 | `meter_reading_fields.dart` | Kiem tra chi so hop le |
| 3 | `billing_providers.dart` | Goi submit controller |
| 4 | `billing_repository.dart` | Goi `createInvoice()` |
| 5 | `billing_api.dart` | Gui request len backend |
| 6 | `billing.controller.ts` | Nhan request va chuyen sang service |
| 7 | `billing.service.ts` | Tinh tong tien va tao invoice |
| 8 | `schema.prisma` | Ghi `Invoice` va `MeterReading` |
| 9 | `billing_providers.dart` | Invalidates invoices/summary |
| 10 | `billing_screen.dart` | Update UI sau khi tao xong |

### Flow ghi nhan thanh toan

| Buoc | File | Viec can lam |
|---|---|---|
| 1 | `invoice_detail_screen.dart` | Mo dialog ghi nhan thanh toan |
| 2 | `billing_providers.dart` | Goi payment controller |
| 3 | `billing_repository.dart` | Goi `recordPayment()` |
| 4 | `billing_api.dart` | POST `/billing/invoices/:id/payments` |
| 5 | `billing.controller.ts` | Nhan request |
| 6 | `billing.service.ts` | Kiem tra paid amount, cap nhat status |
| 7 | `schema.prisma` | Ghi `Payment`, update `Invoice.paidAmount` |
| 8 | `invoice_detail_screen.dart` | Refresh timeline, status, remaining amount |

### Flow huy hoa don / dao thanh toan / duyet chung tu

| Flow | File chinh | Viec can lam |
|---|---|---|
| Huy hoa don | `invoice_detail_screen.dart`, `billing_repository.dart`, `billing.service.ts` | Chi huy khi chua co payment, co note, cap nhat status cancelled |
| Dao thanh toan | `invoice_detail_screen.dart`, `billing_repository.dart`, `billing.service.ts` | Tao reversal payment, tru paidAmount, cap nhat status |
| Duyet chung tu | `invoice_detail_screen.dart`, `billing_repository.dart`, `billing.service.ts` | Approve/reject proof, neu approve thi co the tao payment |

### File map

| File | Vai tro |
|---|---|
| `lib/features/billing/billing_screen.dart` | Billing list, summary, reminders, pending proofs |
| `lib/features/billing/billing_form_screen.dart` | Tao hoa don le |
| `lib/features/billing/bulk_invoice_screen.dart` | Tao hoa don hang loat |
| `lib/features/billing/invoice_detail_screen.dart` | Chi tiet invoice, payment/cancel/reverse/proof/PDF |
| `lib/features/billing/billing_providers.dart` | Riverpod state cho billing |
| `lib/features/billing/widgets/meter_reading_fields.dart` | Validate chi so dien nuoc |
| `lib/features/billing/invoice_pdf.dart` | Tao PDF |
| `lib/data/billing/billing_repository.dart` | Business API layer cua FE |
| `lib/data/billing/billing_api.dart` | HTTP endpoints |
| `lib/data/reports/reports_api.dart` | Reminders va Zalo send |
| `backend/src/billing/billing.controller.ts` | Backend routes |
| `backend/src/billing/billing.service.ts` | Business logic |
| `backend/src/billing/dto/*` | Validate request |
| `backend/prisma/schema.prisma` | DB models |

### Loi hay gap can canh chung

| Loi | File can xem truoc | Cach phan biet |
|---|---|---|
| Hoa don tao xong nhung list khong refresh | `billing_providers.dart`, `billing_screen.dart` | Kiem tra invalidate provider |
| Tong tien sai | `billing.service.ts`, `billing_form_screen.dart` | Kiem tra cong thuc rent + utility + other |
| Duplicate invoice | `billing.service.ts`, `create-invoice.dto.ts` | Kiem tra leaseId + billingMonth |
| Chi so dien nuoc khong hop le | `meter_reading_fields.dart`, `billing.service.ts` | Kiem tra current >= previous |
| Thanh toan vuot qua con lai | `billing.service.ts` | Kiem tra remainingAmount truoc khi ghi payment |
| Huy hoa don khi da co payment | `billing.service.ts` | Chi cancel invoice chua co payment |
| Dao thanh toan 2 lan | `billing.service.ts` | Kiem tra payment da reversed chua |
| Duyet chung tu nhung invoice da paid/cancelled | `billing.service.ts` | Kiem tra status truoc khi approve |

### Definition of done

1. Tao hoa don le va hoa don hang loat deu hoat dong.
2. Invoice detail xem duoc timeline, payment, proof, PDF.
3. Ghi nhan thanh toan, huy hoa don, dao thanh toan, duyet chung tu deu chay.
4. Reminder/Zalo flow hoat dong.
5. UI refresh dung sau moi action.
6. FE va BE tests quan trong deu pass.
7. Khong con payload/response mismatch giua FE va BE.

### Tests / gap

| Loai test | File |
|---|---|
| Billing API contract | `test/data/billing/billing_api_test.dart` |
| Meter reading validation | `test/features/billing/meter_reading_fields_test.dart` |
| Invoice timeline | `test/features/billing/invoice_timeline_test.dart` |
| Backend billing logic | `backend/src/billing/billing.service.spec.ts` |
| E2E billing flow | `test/e2e/lease-billing-dashboard.e2e-spec.ts` |

## Billing bulk invoice

### Muc tieu

Lap hoa don hang loat cho property theo ky billing, voi preflight de biet lease nao da co invoice va lease nao san sang.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo bulk invoice screen | `lib/features/billing/bulk_invoice_screen.dart` | Co UI chon property/ky |
| 2 | Doc provider | `lib/features/billing/billing_providers.dart` | Co preflight/run state |
| 3 | Goi preflight | `lib/data/billing/billing_repository.dart`, `lib/data/billing/billing_api.dart` | Biet room nao ready/existing |
| 4 | Cho user chinh readings | `lib/features/billing/bulk_invoice_screen.dart`, `lib/features/billing/widgets/meter_reading_fields.dart` | Input so lieu dung |
| 5 | Goi tao hang loat | `lib/data/billing/billing_repository.dart`, `lib/data/billing/billing_api.dart` | POST bulk invoice chay |
| 6 | Backend preflight/run | `backend/src/billing/billing.controller.ts`, `backend/src/billing/billing.service.ts` | Tao hoac bao existing dung |
| 7 | DB | `Invoice`, `MeterReading`, `BillingAutomation` | Batch data luu dung |
| 8 | Verify | `backend/src/billing/billing.service.spec.ts`, `test/data/billing/billing_api_test.dart` | Summary/ready/existing pass |

### File map

| File | Vai tro |
|---|---|
| `lib/features/billing/bulk_invoice_screen.dart` | UI bulk generation |
| `lib/features/billing/billing_providers.dart` | Preflight/run state |
| `lib/data/billing/billing_repository.dart` | Wrapper for bulk calls |
| `lib/data/billing/billing_api.dart` | HTTP bulk endpoints |
| `backend/src/billing/billing.controller.ts` | `/billing/invoices/bulk/*` |
| `backend/src/billing/billing.service.ts` | Batch business logic |
| `backend/prisma/schema.prisma` | Invoice/readings relation |

### Definition of done

1. Preflight cho dung danh sach ready/existing.
2. Tao hang loat khong duplicate hoa don.
3. UI update sau batch.
4. Bulk test pass.

## Billing automation

### Muc tieu

Quan ly cau hinh tu dong lap hoa don theo property, bao gom bat/tat, ngay lap, ngay den han, preview va run.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo automation controls | `lib/features/billing/billing_screen.dart`, `lib/features/billing/bulk_invoice_screen.dart` | Co khu vuc automation |
| 2 | Doc state/provider | `lib/features/billing/billing_providers.dart` | Automation config va preview state load dung |
| 3 | Goi API preview/update/run | `lib/data/billing/billing_api.dart`, `lib/data/billing/billing_repository.dart` | API auto config chay |
| 4 | Doc models | `lib/models/billing.dart` | `BillingAutomation`, `BillingAutomationPreview`, `BillingAutomationRunResult` dung |
| 5 | Backend automation | `backend/src/billing/billing.controller.ts`, `backend/src/billing/billing.service.ts` | Config, preview, run hoat dong |
| 6 | DB | `BillingAutomation`, `Property`, `Invoice`, `MeterReading` | Luu cau hinh va ket qua |
| 7 | Verify | `backend/src/billing/billing.service.spec.ts`, `test/data/billing/billing_api_test.dart` | Preview/run/update khong sai |

### File map

| File | Vai tro |
|---|---|
| `lib/features/billing/billing_screen.dart` | Entry point automation |
| `lib/features/billing/bulk_invoice_screen.dart` | Panel chạy automation |
| `lib/features/billing/billing_providers.dart` | Automation controllers |
| `lib/data/billing/billing_repository.dart` | repo wrappers |
| `lib/data/billing/billing_api.dart` | API calls |
| `lib/models/billing.dart` | automation models |
| `backend/src/billing/billing.controller.ts` | automation routes |
| `backend/src/billing/billing.service.ts` | automation logic |
| `backend/prisma/schema.prisma` | automation table |

### Definition of done

1. Co the xem/doi cau hinh automation.
2. Preview ra ket qua dung.
3. Run automation tao invoice dung scope.
4. Khong tao duplicate invoice.

## Billing PDF

### Muc tieu

Xuat invoice PDF de in, share hoac gui cho tenant, dung du lieu tu invoice detail.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo PDF generator | `lib/features/billing/invoice_pdf.dart` | Tao file PDF tu invoice |
| 2 | Doc billing model | `lib/models/billing.dart` | Thong tin party, amount, payment co du |
| 3 | Doc share flow | `lib/features/billing/invoice_detail_screen.dart` | Nut print/share dung |
| 4 | Backend data source | `backend/src/billing/*` | Invoice details chinh xac |
| 5 | DB | `Invoice`, `Payment` | PDF co payment history |
| 6 | Verify | manual share/print, plus widget/PDF-related test if co | File xuat dung format |

### File map

| File | Vai tro |
|---|---|
| `lib/features/billing/invoice_pdf.dart` | Build PDF |
| `lib/features/billing/invoice_detail_screen.dart` | Trigger share/print |
| `lib/models/billing.dart` | Data source |
| `backend/src/billing/*` | backend invoice data |

### Definition of done

1. PDF tao duoc tu invoice detail.
2. Data in tren PDF trung khop DB.
3. Share/print khong loi.

## Maintenance list / form

### Muc tieu

Quan ly ticket bao tri tu tao moi den dong ticket, comment va lien ket expense neu can.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo maintenance list | `lib/features/maintenance/maintenance_screen.dart` | Thay ticket list |
| 2 | Mo maintenance form | `lib/features/maintenance/maintenance_form_screen.dart` | Tao ticket moi |
| 3 | Doc providers | `lib/features/maintenance/maintenance_providers.dart` | State load/update dung |
| 4 | Doc repo/api | `lib/data/maintenance/maintenance_repository.dart`, `lib/data/maintenance/maintenance_api.dart` | CRUD/comment API chay |
| 5 | Doc model | `lib/models/maintenance.dart` | Status, assignee, comments, images |
| 6 | Xu ly status/comment/delete | `lib/features/maintenance/maintenance_screen.dart`, `lib/features/maintenance/maintenance_form_screen.dart` | Update luong ticket |
| 7 | Backend maintenance | `backend/src/maintenance/*` | Route va permission dung |
| 8 | DB | `MaintenanceTicket`, `MaintenanceComment`, optional `Expense` | Ticket/comment co data |
| 9 | Verify | source co san; tenant comment/status/expense link flow can test | Manual QA con can |

### Definition of done

1. Ticket tao/sua/comment/dong duoc.
2. Staff va tenant thay dung scope.
3. Expense link khong sai.

## Reports

### Muc tieu

Tong hop bao cao tai chinh, hoa don, thanh toan, deposit, expense va reminder.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo reports screen | `lib/features/reports/reports_screen.dart` | Co dashboard bao cao |
| 2 | Doc providers | `lib/features/reports/reports_providers.dart` | Report/reminder state dung |
| 3 | Doc reports API | `lib/data/reports/reports_api.dart` | Monthly reports, reminders, Zalo send |
| 4 | Doc report models | `lib/models/reports.dart` | Summary/series/reminder models dung |
| 5 | Backend reports | `backend/src/reports/*`, `backend/src/notifications/*` | Report endpoints co data |
| 6 | DB | `Invoice`, `Payment`, `Expense`, `DepositTransaction`, `NotificationDelivery` | Nguon bao cao day du |
| 7 | Verify | report/reminder source co san | Export/reconciliation manual verify |

### Definition of done

1. Bao cao ra dung scope va thoi gian.
2. Reminder co the gui/lay lai.
3. Khong doc lan data khac landlord.

## Staff

### Muc tieu

Quan ly staff list, profile, invite, va permission preset cho cac vai tro trong he thong.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo staff screen | `lib/features/staff/staff_screen.dart` | Danh sach staff hien ra |
| 2 | Doc providers | `lib/features/staff/staff_providers.dart` | State load/update dung |
| 3 | Doc repo/api | `lib/data/staff/staff_repository.dart`, `lib/data/staff/staff_api.dart` | CRUD/invite calls chay |
| 4 | Doc model | `lib/models/staff.dart`, `lib/models/auth_models.dart` | Permission, role map dung |
| 5 | Doc permission presets | `backend/src/staff/staff-presets.ts`, `lib/features/auth/auth_navigation.dart` | UI/backend guard khop nhau |
| 6 | Backend staff | `backend/src/staff/*` | Routes va guards dung |
| 7 | DB | `UserRole.STAFF`, `StaffProfile`, `StaffInvite` | Staff state luu dung |
| 8 | Verify | backend guard coverage co san | UI coverage con partial |

### Definition of done

1. Staff CRUD/invite duoc.
2. Permission preset khong sai.
3. Route guard match backend.

## Audit

### Muc tieu

Xem lich su hanh dong quan trong cua landlord/staff de truy vet thay doi.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo audit screen | `lib/features/audit/audit_screen.dart` | Lich su hien ra |
| 2 | Doc providers | `lib/features/audit/audit_providers.dart` | Filter/page state dung |
| 3 | Doc repo/api | `lib/data/audit/audit_repository.dart`, `lib/data/audit/audit_api.dart` | Lay audit logs |
| 4 | Doc model | `lib/models/audit_log.dart` | Actor/resource/action map dung |
| 5 | Backend audit | `backend/src/audit/*` | Log routes hoat dong |
| 6 | DB | `AuditLog` | Lich su duoc luu |
| 7 | Verify | source co san | UI verify con can |

### Definition of done

1. Audit log xem duoc theo scope.
2. Lich su thay doi co the truy vet.
3. Khong lo data che khac scope.

## Notifications

### Muc tieu

Quan ly thong bao noi app va ZNS/Zalo delivery, bao gom read state va log send.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo notifications screen | `lib/features/notifications/notifications_screen.dart` | Inbox/thong bao hien ra |
| 2 | Doc providers | `lib/features/notifications/notifications_providers.dart` | State read/unread dung |
| 3 | Doc notifications API | `lib/data/notifications/notifications_api.dart` | Mark read, delivery, manual send |
| 4 | Doc models | `lib/models/landlord_notification.dart`, `lib/models/notification_delivery.dart` | Data map dung |
| 5 | Xu ly mark read / delivery logs / manual Zalo | `lib/data/notifications/notifications_api.dart` | Action dung scope |
| 6 | Backend notifications/ZNS | `backend/src/notifications/*` | Send/log routes hoat dong |
| 7 | DB | `NotificationRead`, `NotificationDelivery` | Read/delivery state luu dung |
| 8 | Verify | source co san | UI read-state/Zalo delivery can verify |

### Definition of done

1. Notifications list hien dung.
2. Mark read cap nhat state.
3. Delivery log/tracking khong sai.

## Operations

### Muc tieu

Tao danh sach viec can lam tu cac nghiep vu nhu billing, maintenance, notifications de staff/landlord xu ly.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo action items screen | `lib/features/operations/action_items_screen.dart` | Co danh sach viec can lam |
| 2 | Doc providers | `lib/features/operations/operations_providers.dart` | Filter/sort state dung |
| 3 | Doc API | `lib/data/operations/operations_api.dart` | Load action items |
| 4 | Backend operations | `backend/src/operations/*` | Route co data |
| 5 | DB | Derived from notifications / billing data | Item sinh tu du lieu nguon |
| 6 | Verify | source co san | QA action-item can verify |

### Definition of done

1. Action items lay dung tu nguon data.
2. Nguoi dung co the xu ly viec can lam.
3. Khong lap items sai scope.

## Expenses

### Muc tieu

Quan ly chi phi nha tro, lien ket bao tri/bao cao va bao gom vao reports.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo expense list/form | `lib/features/expenses/expenses_screen.dart`, `lib/features/expenses/expense_form_screen.dart` | Tao/xem chi phi |
| 2 | Doc providers | `lib/features/expenses/expense_providers.dart` | State update dung |
| 3 | Doc repo/api | `lib/data/expenses/expense_repository.dart`, `lib/data/expenses/expense_api.dart` | CRUD goi dung |
| 4 | Doc model | `lib/models/expense.dart` | Category/date/amount map dung |
| 5 | Backend expenses | `backend/src/expenses/*` | CRUD route hoat dong |
| 6 | DB | `Expense`, optional `Property`, `Room`, `MaintenanceTicket` | Expense co lien ket |
| 7 | Verify | source co san | Report inclusion can verify |

### Definition of done

1. Expense CRUD xong.
2. Expense co the nap vao reports.
3. Optional links khong lam loi save.

## Admin

### Muc tieu

Cho admin quan ly landlord, property, va du lieu cap he thong.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo admin dashboard | `lib/features/admin/admin_dashboard_screen.dart` | Co entry point admin |
| 2 | Mo landlord screens | `lib/features/admin/admin_landlords_screen.dart`, `lib/features/admin/admin_landlord_detail_screen.dart`, `lib/features/admin/admin_landlord_form_screen.dart` | CRUD landlord |
| 3 | Mo property screens | `lib/features/admin/admin_properties_screen.dart`, `lib/features/admin/admin_property_detail_screen.dart`, `lib/features/admin/admin_property_form_screen.dart` | CRUD property |
| 4 | Doc providers | `lib/features/admin/admin_providers.dart` | State load/update dung |
| 5 | Doc repo/api | `lib/data/admin/admin_repository.dart`, `lib/data/admin/admin_api.dart` | Admin HTTP layer |
| 6 | Backend admin | `backend/src/admin/*` | Route va permission dung |
| 7 | DB | `User`, `Property`, `Room`, `Tenant` | Admin scope luu dung |
| 8 | Verify | source co san | UI/flow can inspect truoc khi sua |

### Definition of done

1. Admin CRUD duoc landlord/property.
2. Scope admin rieng biet voi landlord.
3. Guard/permission khong lo.

## Uploads

### Muc tieu

Xu ly tai len file cho payment proof, maintenance attachments va cac attachment khac.

### Implementation flow

| Buoc | Lam gi | File | Ket qua mong muon |
|---|---|---|---|
| 1 | Mo upload helper | `lib/data/uploads/upload_api.dart` | Co helper gui file |
| 2 | Noi vao proof/maintenance/attachment | `lib/data/tenant_portal/tenant_portal_api.dart`, `lib/features/maintenance/maintenance_form_screen.dart` | Upload dung noi can dung |
| 3 | Backend file endpoints | `backend/src/uploads/*` | File receive/return URL |
| 4 | DB | Stores returned URLs on related records | Attachment URL luu dung |
| 5 | Verify | storage cleanup, file limits va runtime upload con follow-up | Can manual test |

### Definition of done

1. Upload tra duoc URL.
2. URL luu vao record lien quan.
3. File limit/cleanup duoc kiem tra ro.

## Cross-cutting

### Muc tieu

Ghi ro cac file dung chung phai hieu khi sua bat ky feature nao, vi day la nen tang de project van hanh on dinh.

### File map

| File | Vai tro |
|---|---|
| `lib/app/app.dart` | Router, shell, redirect, app bootstrap |
| `lib/core/theme/app_theme.dart` | Theme chung |
| `lib/core/config/api_config.dart` | Api base url/config |
| `lib/core/network/api_client.dart` | Dio client, auth header, refresh/retry |
| `lib/core/network/api_failure.dart` | Normalize loi backend/HTTP |
| `lib/core/utils/format.dart` | Format tien, ngay, so |
| `lib/core/messaging/messaging_launcher.dart` | Mo deep link/messaging app |
| `backend/src/common/*` | Auth roles, permissions, current user helpers |
| `backend/prisma/schema.prisma` | Source of truth cho schema |

### Definition of done

1. Neu sua API/auth/permission thi phai doc file chung nay truoc.
2. Khong hardcode route hay status lan trong feature file.
3. Schema thay doi phai keo theo FE model va test.

## Verification snapshot

### Muc tieu

Ghi ro nhung gi da co san va nhung gi van phai verify tay de tranh nham lan giua “file da co” va “flow da xong”.

| Muc | Noi dung |
|---|---|
| Flutter tests hien co | `test/core/network/api_client_test.dart`, `test/data/*`, `test/features/*`, `test/dashboard_test.dart`, `test/properties_test.dart`, `test/rooms_test.dart`, `test/widget_test.dart` |
| Backend tests hien co | `backend/test/e2e/*`, `backend/src/auth/*.spec.ts`, `backend/src/billing/*.spec.ts`, `backend/src/dashboard/*.spec.ts`, `backend/src/common/*.spec.ts`, `backend/src/tenants/*.spec.ts` |
| Lan cap nhat map nay | Chi cap nhat tai lieu; chua chay lai analyzer/test/build trong session nay |
| Manual gap | Tenant portal, Zalo 2 chieu, upload files va mot so CRUD/sub-resource flow van can verify tay |
| Environment note | Flutter local SDK tren may ban can chay tay tren macOS; backend e2e can canh binary/Prisma runtime phu hop |
