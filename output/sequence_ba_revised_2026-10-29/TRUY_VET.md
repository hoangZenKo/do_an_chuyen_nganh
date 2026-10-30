# Truy vết nội dung sơ đồ

Các đường dẫn tính từ thư mục gốc dự án. Số dòng trỏ tới khai báo thao tác được dùng làm căn cứ.
Nội dung trong hình là diễn giải nghiệp vụ, không phải tên thao tác triển khai.

## SD-01. Đăng nhập và duy trì phiên sử dụng

- `backend/src/auth/auth.service.ts:71` - `login`
- `backend/src/auth/auth.service.ts:91` - `refresh`
- `backend/src/auth/auth.service.ts:179` - `issueSession`
- `lib/features/auth/login_screen.dart:37` - `_submit`
- `lib/features/auth/auth_navigation.dart:264` - `homeRouteForSession`
- `lib/data/auth/auth_repository.dart:43` - `restore`

## SD-02. Đặt lịch xem phòng và lập hợp đồng từ lịch xem

- `backend/src/housing/housing.service.ts:83` - `book`
- `backend/src/housing/housing.service.ts:208` - `update`
- `backend/src/housing/housing.service.ts:240` - `createLease`
- `backend/src/leases/leases.service.ts:93` - `createWithinTransaction`
- `lib/features/listings/housing_screen.dart:67` - `_viewingAction`
- `lib/features/listings/housing_dialog.dart`

## SD-03. Lập hợp đồng thuê phòng và ghi nhận cọc ban đầu

- `backend/src/leases/leases.service.ts:87` - `create`
- `backend/src/leases/leases.service.ts:93` - `createWithinTransaction`
- `lib/features/tenants/lease_form_screen.dart`

## SD-04. Đề xuất và xét duyệt biểu phí

- `backend/src/billing/billing-tariffs.service.ts:25` - `propose`
- `backend/src/billing/billing-tariffs.service.ts:44` - `impact`
- `backend/src/billing/billing-tariffs.service.ts:67` - `review`
- `lib/features/billing/billing_tariffs_screen.dart`

## SD-05. Xem trước và phát hành hóa đơn tháng

- `backend/src/billing/billing.service.ts:291` - `createInvoice`
- `backend/src/billing/billing.service.ts:384` - `bulkInvoicePreflight`
- `backend/src/billing/billing.service.ts:460` - `createBulkInvoices`
- `backend/src/billing/billing-tariffs.service.ts:100` - `preview`
- `lib/features/billing/bulk_invoice_screen.dart:304` - `_submit`

## SD-06. Ghi nhận khoản thu và phân bổ thanh toán

- `backend/src/billing/billing-ledger.service.ts:88` - `createReceipt`
- `backend/src/billing/billing-ledger.service.ts:101` - `allocate`
- `backend/src/billing/billing-ledger.service.ts:175` - `allocateLines`
- `backend/src/billing/billing-commands.service.ts:13` - `execute`
- `lib/features/billing/billing_receipts_screen.dart`

## SD-07. Gỡ phân bổ và ghi nhận hoàn tiền khoản thu

- `backend/src/billing/billing-ledger.service.ts:111` - `release`
- `backend/src/billing/billing-ledger.service.ts:132` - `refund`
- `backend/src/billing/billing-commands.service.ts:13` - `execute`
- `lib/features/billing/billing_receipts_screen.dart`

## SD-08. Gửi và xét duyệt chứng từ thanh toán

- `backend/src/tenant-portal/tenant-portal.service.ts:426` - `submitPaymentProof`
- `backend/src/billing/billing.service.ts:1053` - `reviewPaymentProof`
- `lib/features/billing/payment_proof_review_dialog.dart`
- `lib/features/tenant_portal/tenant_payment_proof_dialog.dart`

## SD-09. Thay thế hoặc điều chỉnh hóa đơn

- `backend/src/billing/billing-ledger.service.ts:25` - `replace`
- `backend/src/billing/billing-ledger.service.ts:60` - `adjust`
- `lib/features/billing/invoice_replacement_screen.dart`
- `lib/features/billing/invoice_adjustment_dialog.dart`

## SD-10. Quyết toán trả phòng và ghi nhận hoàn cọc

- `backend/src/leases/settlements.service.ts:53` - `preview`
- `backend/src/leases/settlements.service.ts:61` - `confirm`
- `backend/src/leases/settlements.service.ts:101` - `recordRefund`
- `backend/src/leases/settlements.service.ts:138` - `calculate`
- `lib/features/tenants/lease_settlement_screen.dart`

## SD-11. Gửi, xét duyệt và thực hiện yêu cầu thay đổi thuê

- `backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:61` - `createRequest`
- `backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:102` - `decideRequest`
- `backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148` - `executeRequest`
- `lib/features/tenants/tenant_lifecycle_screen.dart:141` - `_review`
- `lib/features/tenants/tenant_lifecycle_screen.dart:170` - `_execute`

## SD-12. Tiếp nhận và hoàn tất yêu cầu bảo trì

- `backend/src/tenant-portal/tenant-portal.service.ts:384` - `createMaintenance`
- `backend/src/tenant-portal/tenant-portal.service.ts:407` - `addMaintenanceComment`
- `backend/src/maintenance/maintenance.service.ts:142` - `update`
- `backend/src/maintenance/maintenance.service.ts:203` - `updateStatus`
- `backend/src/maintenance/maintenance.service.ts:272` - `addComment`
- `backend/src/maintenance/maintenance.service.ts:227` - `complete`
- `lib/features/maintenance/maintenance_screen.dart`

## SD-13. Xem báo cáo tháng và sao chép dữ liệu CSV

- `backend/src/reports/reports.service.ts:18` - `monthly`
- `backend/src/reports/reports.service.ts:141` - `monthlyExport`
- `lib/features/reports/reports_screen.dart:89` - `_exportCsv`

## SD-14. Đình chỉ và khôi phục tài khoản khách hàng

- `backend/src/admin/admin-console.service.ts:56` - `status`
- `lib/features/admin/admin_accounts_screen.dart`

## SD-15. Tra cứu phòng và xử lý kiểm duyệt tin đăng

- `backend/src/admin/admin.service.ts:162` - `rooms`
- `backend/src/admin/admin-console.service.ts:251` - `work`
- `backend/src/admin/admin-console.service.ts:274` - `moderationItem`
- `backend/src/listings/listings.service.ts:130` - `review`
- `backend/src/listings/listings.service.ts:158` - `mutate`
- `lib/features/admin/admin_inventory_widgets.dart`

## SD-16. Đối soát khoản thu theo nguyên tắc hai người

- `backend/src/platform/finance-reconciliation.service.ts:18` - `importStatement`
- `backend/src/platform/finance-reconciliation.service.ts:100` - `propose`
- `backend/src/platform/finance-reconciliation.service.ts:131` - `review`
- `backend/src/platform/finance-reconciliation.service.ts:75` - `validateReceipt`
- `lib/features/admin/admin_finance_workflow.dart`

## SD-17. Hỏi hướng dẫn sử dụng và đọc nguồn được phép

- `backend/src/chatbot/chatbot.service.ts:24` - `ask`
- `backend/src/chatbot/chatbot.service.ts:69` - `answer`
- `backend/src/chatbot/chatbot.service.ts:64` - `getSource`
- `backend/src/chatbot/chatbot.service.ts:117` - `validateAnswer`
- `backend/src/chatbot/knowledge.repository.ts`
- `lib/features/chatbot/chatbot_screen.dart:26` - `_send`
- `lib/features/chatbot/widgets/chat_source_sheet.dart`

## SD-18. Xét duyệt hồ sơ xác minh chủ trọ

- `backend/src/admin/admin-verification.service.ts:22` - `list`
- `backend/src/admin/admin-verification.service.ts:56` - `review`
- `lib/features/admin/admin_production_panels.dart`

## SD-19. Gán và kết thúc quyền sử dụng gói

- `backend/src/admin/admin-plans.service.ts:74` - `assign`
- `backend/src/admin/admin-plans.service.ts:109` - `cancel`
- `lib/features/admin/admin_production_panels.dart`
