# Implementation Map

> Muc tieu: moi flow co bang A-Z rieng, moi buoc co file source ro rang, khong gom cum qua tay.
>
> Cap nhat: 2026-08-12.

## Cach doc

1. Chon flow ban muon lam.
2. Doc cot `Buoc` tu tren xuong duoi.
3. Moi buoc co file can mo ngay trong cot `File`.
4. Doc `Backend` va `DB` neu flow do cham server/du lieu.
5. Doc `Tests / gap` de biet con can verify gi truoc khi chot.

## Auth: login

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo login screen | `lib/features/auth/login_screen.dart` |
| 2 | Dung auth form chung | `lib/features/auth/auth_form.dart` |
| 3 | Xu ly submit va loading/error | `lib/features/auth/auth_providers.dart` |
| 4 | Goi API login | `lib/data/auth/auth_api.dart` |
| 5 | Luu session | `lib/data/auth/secure_session_storage.dart` |
| 6 | Gan token vao request va redirect sau login | `lib/core/network/api_client.dart`, `lib/app/app.dart` |
| 7 | Backend login | `api:src/auth/*` |
| 8 | DB | `User`, `RefreshToken` |
| 9 | Tests / gap | Login source co san; forgot password chua co |

## Auth: register

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo register screen | `lib/features/auth/register_screen.dart` |
| 2 | Dung auth form chung | `lib/features/auth/auth_form.dart` |
| 3 | Xu ly submit va loading/error | `lib/features/auth/auth_providers.dart` |
| 4 | Goi API register | `lib/data/auth/auth_api.dart` |
| 5 | Luu session sau dang ky | `lib/data/auth/secure_session_storage.dart` |
| 6 | Redirect ve home | `lib/features/auth/auth_navigation.dart`, `lib/app/app.dart` |
| 7 | Backend register | `api:src/auth/*` |
| 8 | DB | `User`, `RefreshToken` |
| 9 | Tests / gap | Register source co san; client khong duoc set role tu dong |

## Auth: session restore

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Restore session khi mo app | `lib/features/auth/auth_providers.dart` |
| 2 | Doc session da luu | `lib/data/auth/secure_session_storage.dart` |
| 3 | Kiem tra app shell va splash redirect | `lib/app/app.dart` |
| 4 | Backend `/auth/me` | `api:src/auth/*` |
| 5 | DB | `User`, `RefreshToken` |
| 6 | Tests / gap | Restore source co san; device restart chua verify |

## Auth: refresh token

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Phat hien request bi `401` | `lib/core/network/api_client.dart` |
| 2 | Khong cho refresh chung tai 1 luc | `lib/data/auth/token_refresh_coordinator.dart` |
| 3 | Goi refresh API | `lib/data/auth/auth_api.dart` |
| 4 | Cap nhat session moi | `lib/data/auth/secure_session_storage.dart` |
| 5 | Retry request cu | `lib/core/network/api_client.dart` |
| 6 | Backend refresh | `api:src/auth/*` |
| 7 | DB | `User`, `RefreshToken` |
| 8 | Tests / gap | Refresh source co san; expiry/replay flow can verify them |

## Auth: logout

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Nhan logout tu UI/provider | `lib/features/auth/auth_providers.dart` |
| 2 | Goi logout API | `lib/data/auth/auth_api.dart` |
| 3 | Xoa session local | `lib/data/auth/secure_session_storage.dart` |
| 4 | Cap nhat route/home state | `lib/app/app.dart`, `lib/features/auth/auth_navigation.dart` |
| 5 | Backend logout | `api:src/auth/*` |
| 6 | DB | `RefreshToken` |
| 7 | Tests / gap | Logout source co san; local cleanup still can verify |

## Auth: tenant invite accept

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo tenant invite screen | `lib/features/auth/tenant_invite_screen.dart` |
| 2 | Dung auth form chung | `lib/features/auth/auth_form.dart` |
| 3 | Xu ly submit | `lib/features/auth/auth_providers.dart` |
| 4 | Goi API accept invite | `lib/data/auth/auth_api.dart` |
| 5 | Backend tenant invite | `api:src/tenants/tenant-invites.controller.ts`, `api:src/tenants/tenant-invites.service.ts` |
| 6 | DB | `TenantInvite`, `Tenant.userId` |
| 7 | Tests / gap | Invite source co san; manual activation chua verify |

## Auth: staff invite accept

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo staff invite screen | `lib/features/auth/staff_invite_screen.dart` |
| 2 | Dung auth form chung | `lib/features/auth/auth_form.dart` |
| 3 | Xu ly submit | `lib/features/auth/auth_providers.dart` |
| 4 | Goi API accept invite | `lib/data/auth/auth_api.dart` |
| 5 | Backend staff invite | `api:src/staff/staff.controller.ts`, `api:src/staff/staff.service.ts` |
| 6 | DB | `StaffInvite`, `UserRole.STAFF`, `StaffProfile` |
| 7 | Tests / gap | Invite source co san; manual activation chua verify |

## Startup / onboarding

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo splash screen | `lib/features/splash/splash_screen.dart` |
| 2 | Mo onboarding screens | `lib/features/onboarding/onboarding_screen.dart` |
| 3 | Doc onboarding state | `lib/features/onboarding/onboarding_providers.dart` |
| 4 | Noi vao app shell | `lib/app/app.dart` |
| 5 | Tests / gap | Widget + persistence tests co san; device restart chua verify |

## Dashboard landlord

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo dashboard screen | `lib/features/dashboard/dashboard_screen.dart` |
| 2 | Doc dashboard providers | `lib/features/dashboard/dashboard_providers.dart` |
| 3 | Mo notifications screen | `lib/features/notifications/notifications_screen.dart` |
| 4 | Mo notifications providers | `lib/features/notifications/notifications_providers.dart` |
| 5 | Mo action items screen | `lib/features/operations/action_items_screen.dart` |
| 6 | Mo operations providers | `lib/features/operations/operations_providers.dart` |
| 7 | Backend dashboard/notifications/operations | `api:src/dashboard/*`, `api:src/notifications/*`, `api:src/operations/*` |
| 8 | DB | `Property`, `Room`, `Lease`, `Invoice`, `Payment` |
| 9 | Tests / gap | Dashboard API + Flutter tests co san; manual data-heavy verify con can |

## Property

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo property list | `lib/features/properties/properties_list_screen.dart` |
| 2 | Mo property form | `lib/features/properties/property_form_screen.dart` |
| 3 | Doc room/property repo/api | `lib/data/rooms/property_api.dart`, `lib/data/rooms/room_repository.dart` |
| 4 | Backend property | `api:src/properties/*` |
| 5 | DB | `Property` |
| 6 | Tests / gap | Lifecycle source co san; manual CRUD chua verify day du |

## Room list / detail / form

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo rooms list | `lib/features/rooms/rooms_list_screen.dart` |
| 2 | Mo room detail | `lib/features/rooms/room_detail_screen.dart` |
| 3 | Mo room form | `lib/features/rooms/room_form_screen.dart` |
| 4 | Doc room providers | `lib/features/rooms/room_providers.dart` |
| 5 | Doc room/property repo/api | `lib/data/rooms/room_api.dart`, `lib/data/rooms/room_repository.dart` |
| 6 | Doc property selection | `lib/features/rooms/property_selection_provider.dart` |
| 7 | Backend rooms | `api:src/rooms/*` |
| 8 | DB | `Room`, lifecycle flags |
| 9 | Tests / gap | Lifecycle source co san; manual CRUD chua verify day du |

## Tenant list / detail / form

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo tenants list | `lib/features/tenants/tenants_list_screen.dart` |
| 2 | Mo tenant detail | `lib/features/tenants/tenant_detail_screen.dart` |
| 3 | Mo tenant form | `lib/features/tenants/tenant_form_screen.dart` |
| 4 | Doc tenant providers | `lib/features/tenants/tenant_providers.dart` |
| 5 | Doc tenant repo/api | `lib/data/tenants/tenant_api.dart`, `lib/data/tenants/tenant_repository.dart` |
| 6 | Doc tenant model | `lib/models/tenant.dart` |
| 7 | Backend tenants | `api:src/tenants/*` |
| 8 | DB | `Tenant` |
| 9 | Tests / gap | Tenant source co san; overview/timeline widgets con it |

## Lease create / end / expiry / pdf

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo lease form | `lib/features/tenants/lease_form_screen.dart` |
| 2 | Mo tenant detail lease actions | `lib/features/tenants/tenant_detail_screen.dart` |
| 3 | Mo lease expiry screen | `lib/features/tenants/lease_expiry_screen.dart` |
| 4 | Mo lease PDF | `lib/features/tenants/lease_pdf.dart` |
| 5 | Doc lease API | `lib/data/tenants/lease_api.dart` |
| 6 | Doc tenant repo + providers | `lib/data/tenants/tenant_repository.dart`, `lib/features/tenants/tenant_providers.dart` |
| 7 | Backend leases | `api:src/leases/*` |
| 8 | DB | `Lease`, `LeaseChange`, `DepositTransaction` |
| 9 | Tests / gap | Lease source co san; renew/deposit widget tests thieu |

## Tenant portal overview

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo portal screen | `lib/features/tenant_portal/tenant_portal_screen.dart` |
| 2 | Doc portal providers | `lib/features/tenant_portal/tenant_portal_providers.dart` |
| 3 | Doc portal repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` |
| 4 | Doc portal model | `lib/models/tenant_portal.dart` |
| 5 | Backend tenant portal | `api:src/tenant-portal/*` |
| 6 | DB | tenant portal related relations in `api:prisma/schema.prisma` |
| 7 | Tests / gap | Portal flow da wire; device QA con can |

## Tenant portal: invoice detail

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo invoice detail screen | `lib/features/tenant_portal/tenant_invoice_detail_screen.dart` |
| 2 | Doc portal providers | `lib/features/tenant_portal/tenant_portal_providers.dart` |
| 3 | Doc portal repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` |
| 4 | Doc billing/portal model | `lib/models/billing.dart`, `lib/models/tenant_portal.dart` |
| 5 | Backend tenant invoice detail | `api:src/tenant-portal/*`, `api:src/billing/*` |
| 6 | DB | `Invoice`, `Payment`, `PaymentProof` |
| 7 | Tests / gap | Invoice detail source co san; proof review chua co full UI verify |

## Tenant portal: change password

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo change password screen | `lib/features/tenant_portal/tenant_change_password_screen.dart` |
| 2 | Doc auth/session state | `lib/features/auth/auth_providers.dart`, `lib/data/auth/secure_session_storage.dart` |
| 3 | Goi backend password change | `api:src/auth/*` |
| 4 | DB | `User` |
| 5 | Tests / gap | Password change source co san; device/manual verify can |

## Tenant portal: Zalo inbox/chat

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo Zalo screen | `lib/features/tenant_portal/tenant_zalo_screen.dart` |
| 2 | Doc chat state/controllers | `lib/features/tenant_portal/tenant_portal_providers.dart` |
| 3 | Doc message model | `lib/models/notification_delivery.dart` |
| 4 | Doc portal repo/api | `lib/data/tenant_portal/tenant_portal_repository.dart`, `lib/data/tenant_portal/tenant_portal_api.dart` |
| 5 | Backend Zalo message | `api:src/tenant-portal/*` |
| 6 | Backend read state | `api:src/tenant-portal/*`, `api:prisma/schema.prisma` |
| 7 | DB | `NotificationDelivery`, `NotificationRead` |
| 8 | Tests / gap | Zalo 2 chieu da wire; manual verify con can |

## Billing list / form / detail

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo billing screen | `lib/features/billing/billing_screen.dart` |
| 2 | Mo billing form | `lib/features/billing/billing_form_screen.dart` |
| 3 | Mo invoice detail | `lib/features/billing/invoice_detail_screen.dart` |
| 4 | Doc billing providers | `lib/features/billing/billing_providers.dart` |
| 5 | Doc billing repo/api | `lib/data/billing/billing_repository.dart`, `lib/data/billing/billing_api.dart` |
| 6 | Doc meter fields | `lib/features/billing/widgets/meter_reading_fields.dart` |
| 7 | Backend billing | `api:src/billing/*` |
| 8 | DB | `MeterReading`, `Invoice`, `Payment`, `PaymentProof` |
| 9 | Tests / gap | Billing backend coverage tot; UI tests con yeu |

## Billing bulk invoice

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo bulk invoice screen | `lib/features/billing/bulk_invoice_screen.dart` |
| 2 | Doc billing providers | `lib/features/billing/billing_providers.dart` |
| 3 | Doc billing repo/api | `lib/data/billing/billing_repository.dart`, `lib/data/billing/billing_api.dart` |
| 4 | Backend bulk invoice | `api:src/billing/*` |
| 5 | DB | `Invoice`, `MeterReading`, `BillingAutomation` |
| 6 | Tests / gap | Bulk client tests con thieu |

## Billing PDF

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo PDF generator | `lib/features/billing/invoice_pdf.dart` |
| 2 | Doc billing model | `lib/models/billing.dart` |
| 3 | Doc billing detail/share flow | `lib/features/billing/invoice_detail_screen.dart` |
| 4 | Backend billing data | `api:src/billing/*` |
| 5 | DB | `Invoice`, `Payment` |
| 6 | Tests / gap | PDF sharing source co san; runtime share verify can |

## Maintenance list / form

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo maintenance screen | `lib/features/maintenance/maintenance_screen.dart` |
| 2 | Mo maintenance form | `lib/features/maintenance/maintenance_form_screen.dart` |
| 3 | Doc maintenance providers | `lib/features/maintenance/maintenance_providers.dart` |
| 4 | Doc maintenance repo/api | `lib/data/maintenance/maintenance_repository.dart`, `lib/data/maintenance/maintenance_api.dart` |
| 5 | Doc maintenance model | `lib/models/maintenance.dart` |
| 6 | Backend maintenance | `api:src/maintenance/*` |
| 7 | DB | `MaintenanceTicket`, `MaintenanceComment` |
| 8 | Tests / gap | Source co san; tenant comment/status flow can verify |

## Reports

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo reports screen | `lib/features/reports/reports_screen.dart` |
| 2 | Doc reports providers | `lib/features/reports/reports_providers.dart` |
| 3 | Doc reports API | `lib/data/reports/reports_api.dart` |
| 4 | Doc reports model | `lib/models/reports.dart` |
| 5 | Backend reports | `api:src/reports/*` |
| 6 | DB | `Invoice`, `Payment`, `Expense`, `DepositTransaction` |
| 7 | Tests / gap | Monthly report source co san; reconciliation verify con manual |

## Staff

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo staff screen | `lib/features/staff/staff_screen.dart` |
| 2 | Doc staff providers | `lib/features/staff/staff_providers.dart` |
| 3 | Doc staff repo/api | `lib/data/staff/staff_repository.dart`, `lib/data/staff/staff_api.dart` |
| 4 | Doc staff model | `lib/models/staff.dart`, `lib/models/auth_models.dart` |
| 5 | Backend staff | `api:src/staff/*` |
| 6 | DB | `UserRole.STAFF`, `StaffProfile`, `StaffInvite` |
| 7 | Tests / gap | Backend guard coverage co san; UI coverage con partial |

## Audit

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo audit screen | `lib/features/audit/audit_screen.dart` |
| 2 | Doc audit providers | `lib/features/audit/audit_providers.dart` |
| 3 | Doc audit repo/api | `lib/data/audit/audit_repository.dart`, `lib/data/audit/audit_api.dart` |
| 4 | Doc audit model | `lib/models/audit_log.dart` |
| 5 | Backend audit | `api:src/audit/*` |
| 6 | DB | `AuditLog` |
| 7 | Tests / gap | Source co san; audit UI verify con can |

## Notifications

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo notifications screen | `lib/features/notifications/notifications_screen.dart` |
| 2 | Doc notifications providers | `lib/features/notifications/notifications_providers.dart` |
| 3 | Doc notifications API | `lib/data/notifications/notifications_api.dart` |
| 4 | Doc notification model | `lib/models/landlord_notification.dart` |
| 5 | Backend notifications | `api:src/notifications/*` |
| 6 | DB | `NotificationRead` |
| 7 | Tests / gap | Source co san; read-state UI still can verify |

## Operations

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo action items screen | `lib/features/operations/action_items_screen.dart` |
| 2 | Doc operations providers | `lib/features/operations/operations_providers.dart` |
| 3 | Doc operations API | `lib/data/operations/operations_api.dart` |
| 4 | Backend operations | `api:src/operations/*` |
| 5 | DB | Derived from notifications / billing data |
| 6 | Tests / gap | Source co san; action-item QA con can |

## Expenses

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo expense list/form | `lib/features/expenses/expenses_screen.dart`, `lib/features/expenses/expense_form_screen.dart` |
| 2 | Doc expense providers | `lib/features/expenses/expense_providers.dart` |
| 3 | Doc expense repo/api | `lib/data/expenses/expense_repository.dart`, `lib/data/expenses/expense_api.dart` |
| 4 | Doc expense model | `lib/models/expense.dart` |
| 5 | Backend expenses | `api:src/expenses/*` |
| 6 | DB | `Expense` |
| 7 | Tests / gap | Source co san; report inclusion can verify |

## Admin

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo admin dashboard | `lib/features/admin/admin_dashboard_screen.dart` |
| 2 | Mo landlord screens | `lib/features/admin/admin_landlords_screen.dart`, `lib/features/admin/admin_landlord_detail_screen.dart`, `lib/features/admin/admin_landlord_form_screen.dart` |
| 3 | Mo property screens | `lib/features/admin/admin_properties_screen.dart`, `lib/features/admin/admin_property_detail_screen.dart`, `lib/features/admin/admin_property_form_screen.dart` |
| 4 | Doc admin providers | `lib/features/admin/admin_providers.dart` |
| 5 | Doc admin repo/api | `lib/data/admin/admin_repository.dart`, `lib/data/admin/admin_api.dart` |
| 6 | Backend admin | `api:src/admin/*` |
| 7 | DB | `User`, `Property`, `Room`, `Tenant` |
| 8 | Tests / gap | Admin API co san; UI va flows can inspect truoc khi sua |

## Uploads

| Buoc | Lam gi | File |
|---|---|---|
| 1 | Mo upload helper | `lib/data/uploads/upload_api.dart` |
| 2 | Noi vao billing/pdf flow | `lib/features/billing/invoice_pdf.dart` |
| 3 | Backend file endpoints | `api:src/uploads/*`, `api:src/files/*` |
| 4 | DB | None directly |
| 5 | Tests / gap | Storage cleanup va runtime sharing con follow-up |

## Cross-cutting

| Muc | Noi dung |
|---|---|
| App shell | `lib/app/app.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| API client | `lib/core/network/api_client.dart` |
| Common auth/roles | `api:src/common/*` |
| Prisma schema | `api:prisma/schema.prisma` |

## Verification snapshot

| Muc | Noi dung |
|---|---|
| Flutter | `flutter analyze` da pass o vong cap nhat gan nhat |
| Backend | `npm run build`, Prisma validate/generate/deploy va test auth/billing/dashboard target da pass o vong cap nhat gan nhat |
| Manual gap | Tenant portal, Zalo 2 chieu va mot so CRUD flow van can verify tay |
