# Rà soát chất lượng đặc tả toàn hệ thống

Ngày 29/10/2026. Snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng ngoài các bảng UC.

## 1. Kết quả phạm vi

**162/162 UC, 16/16 nhóm**. Giữ nguyên 11 G01, bổ sung 151 G02–G16. 151 Xác minh tĩnh, 9 Một phần, 1 DEMO, 1 MÔ PHỎNG. Đã đặc tả không đồng nghĩa đã triển khai hoàn chỉnh hoặc nghiệm thu runtime. Không thêm/gộp/tách/loại bỏ/đổi mã/đổi tên hoặc thay trạng thái UC trong Catalog/UML.

| Nhóm | Nghiệp vụ | UC | Xác minh tĩnh | Một phần | DEMO/Mô phỏng | Chỉ mục |
|---|---|---|---|---|---|---|
| G01 | Tài khoản và an toàn truy cập | 11 | 10 | 1 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/README.md:1` |
| G02 | Tìm và lựa chọn phòng | 6 | 6 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G02_DIS/README.md:1` |
| G03 | Đăng tin, lịch xem và nhận phòng | 7 | 7 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G03_HOUSING/README.md:1` |
| G04 | Khu trọ và cơ sở vật chất | 14 | 14 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/README.md:1` |
| G05 | Nhân sự và ủy quyền vận hành | 4 | 4 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G05_STAFF/README.md:1` |
| G06 | Hồ sơ thuê, hợp đồng và tiền cọc | 17 | 17 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/README.md:1` |
| G07 | Vòng đời thuê và quyết toán | 7 | 7 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/README.md:1` |
| G08 | Hóa đơn, thu tiền và công nợ | 28 | 26 | 1 | 1 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G08_BILLING/README.md:1` |
| G09 | Bảo trì và chi phí vận hành | 5 | 5 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G09_MAINTENANCE/README.md:1` |
| G10 | Công việc, thông tin và hỗ trợ sử dụng | 9 | 7 | 1 | 1 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G10_OPERATIONS/README.md:1` |
| G11 | Báo cáo và giám sát vận hành | 8 | 7 | 1 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G11_REPORTING/README.md:1` |
| G12 | Tài khoản và tài nguyên nền tảng | 12 | 9 | 3 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/README.md:1` |
| G13 | Kiểm duyệt và chất lượng nội dung | 11 | 11 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G13_MODERATION/README.md:1` |
| G14 | Dịch vụ hỗ trợ khách hàng | 8 | 6 | 2 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/README.md:1` |
| G15 | Hồ sơ xác minh và gói dịch vụ | 6 | 6 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G15_VERIFICATION_PLANS/README.md:1` |
| G16 | Quản trị chính sách và đối soát nền tảng | 9 | 9 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G16_GOVERNANCE/README.md:1` |

Các kết quả machine-check được đọc ở Validation_Result.json/Markdown_Parse_Result.json/Source_Integrity_Result.json sau khi chạy validator. Chúng kiểm cấu trúc/truy vết, không tự đánh giá đầy đủ ngữ nghĩa. Danh sách toàn bộ mã tại `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Coverage_Matrix.md:1`.

## 2. Đối chiếu Catalog và UML

162 mã/tên/mục tiêu/nhóm/actor chính/phối hợp/trạng thái giữ đúng Catalog. 21 trang UML module biểu diễn mỗi UC đúng một lần; bộ 28 sơ đồ còn có 1 overall và 6 Actor views, không đếm các view này thành UC mới. Không có include/extend/generalization ở manifest hiện hành; mọi bảng giữ nguyên quyết định đó.

Bổ sung UI trực tiếp thay gợi ý màn hình rộng ở truy vết cũ, ví dụ listing_detail_screen, manage_listings_screen, viewing_slots_screen, handover_screen, billing_form_screen, bulk_invoice_screen, lease_pdf và các Admin panel. Không sửa JSON truy vết Giai đoạn 2/3 được bảo vệ. Những phần chưa nối được client trực tiếp được ghi rõ trong bảng, không suy chỉ từ API thành thao tác UI.

## 3. Rà gộp/tách, trùng lặp và thao tác kỹ thuật

| Trường hợp | Nhận định theo source | Quyết định AS-IS |
|---|---|---|
| OPT-06.2 / OPT-07.1 | Cùng RoomsService.update/PATCH, nhưng sửa mô tả và đổi trạng thái có ràng buộc ACTIVE lease/turnover khác | Giữ 2 mục tiêu; không thêm endpoint status tưởng tượng. `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:141` |
| OPT-04.1 / OPT-07.2 / xóa | Archive khu, isActive phòng và delete có hậu quả/điều kiện riêng | Không gộp thành xóa dữ liệu; quy trình xóa có kiểm lịch sử. |
| TNT-03 / TNT-03.1 / SYS-08 | Mời nhận code, tạo User trực tiếp và kích hoạt là mục tiêu/cơ chế/quyền khác | Giữ. STAFF được trực tiếp nhưng không được TenantInvitesController. |
| TNT-06.3 / TNT-08 / OPS-05 | Kết thúc lease, quyết toán và chuẩn bị phòng không tự đồng thời hoàn thành | Giữ; không coi end lease tự hoàn cọc/VACANT. `/Users/hoang/Rental_room_management/backend/src/operations/turnover.workflow.ts:7` |
| TEN-07.* / TNT-10 / TNT-11 | Gửi đề nghị, quyết định và thực thi khác actor/trạng thái; APPROVED trả requiresLeaseAction | Giữ, không thêm include do tiền điều kiện. |
| BIL-06 / BIL-07 / BIL-08.1 | Replacement chỉ chưa payment history; adjustment giữ ledger; cancel không xóa | Không gộp vào sửa hóa đơn chung. |
| BIL-09 / BIL-10 / BIL-11 / BIL-12.* / BIL-13 | Payment trực tiếp khác receipt/credit/allocation; release khác reversal và refund | Giữ mục tiêu độc lập, không đếm Payment nội bộ tạo bởi proof là UC mới. |
| BIL-02 / BIL-03 / BIL-17.2 | Đơn lẻ, batch và chạy cấu hình có phạm vi/điều kiện riêng; preview/preflight chỉ là bước | Giữ Catalog, không tạo UC kiểm tra trùng/tính tiền riêng. |
| BIL-18.2 / TEN-09.2 / SUP-04 / TEN-09.3 | Nhắc nợ provider, Zalo mock, thông báo cá nhân và announcement không cùng nguồn/trạng thái | Không gộp; SENT mock ≠ giao ngoài. |
| ADM-11 / ADM-12 / ADM-12.1 / ADM-13.2 / ADM-13.3 | Tin/review/report/appeal/QA có điều kiện và kết quả khác; batch có partial success | Giữ. QA không áp chế tài; reopen không publish. `/Users/hoang/Rental_room_management/backend/src/platform/moderation-v2.service.ts:124` |
| ADM-18 / ADM-19 / ADM-11.1 | Xác minh chủ trọ, snapshot khu và dấu verified tin khác thực thể | Giữ; không gán quyền trình khu cho landlord khi endpoint ADMIN-only. |
| ADM-20…22 | Danh mục/gán/hủy entitlement không có mua gói/thu tiền thực | Không bổ sung UC thanh toán gói; không gọi price gói là doanh thu. |
| ADM-15 / ADM-15.1 | Import/đề xuất và duyệt có maker/checker riêng, không tạo Payment | Giữ mục tiêu, không coi mỗi dòng sao kê/API là UC. |
| SUP-01 / SUP-01.1 | Requester gửi/theo dõi khác Admin xử lý/internal/assignment | Giữ; Admin requester chỉ đánh giá ticket mình, không đánh giá hộ. |
| DIS-16 / DIS-17 | So sánh và tính ngân sách local là mục tiêu người tìm phòng; state/tính toán không là thao tác backend | Giữ, không tự tạo persistence hoặc hợp đồng/thu tiền. |

**Số điều chỉnh đã áp dụng Catalog/UML: 0 gộp, 0 tách, 0 loại bỏ, 0 thêm mới, 0 đổi mã/tên.** Các chỗ cùng service nhưng mục tiêu khác đã giới hạn rõ trong bảng thay vì tự thay danh mục. Các thao tác lock/query/retry nội bộ không được nâng thành UC mới.

## 4. Những UC còn giới hạn theo Catalog

| UC | Trạng thái | Phần có bằng chứng và phần chưa nghiệm thu |
|---|---|---|
| UC-SYS-06 | Một phần |  Đã có token, thu hồi phiên và job giao link; chưa kiểm chứng email/provider thật. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-BIL-18.2 | Một phần |  APP/outbox có triển khai; EMAIL/ZALO/webhook/ZNS phụ thuộc cấu hình và chưa xác nhận giao thực. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-TEN-05 | Đã triển khai — DEMO | Chỉ bật ngoài production và DEMO_PAYMENTS_ENABLED=true; không có cổng thu thẻ tiền thật được xác nhận. Chỉ isDemo/DEMO_CARD, không có thu tiền ngân hàng thực. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-SUP-06 | Một phần |  Retrieval, scope và fallback có code/test; chưa gọi model Ollama thật trong khảo sát. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-TEN-09.2 | Đã triển khai — MÔ PHỎNG |  Tin được lưu nội bộ, không mặc định gửi ra Zalo. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-SUP-05.2 | Một phần |  Theo dõi/retry job có code; chưa xác nhận dịch vụ giao nhận ngoài hệ thống. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-ADM-03.1 | Một phần |  Nhánh mật khẩu trực tiếp giới hạn môi trường dev; nhánh lời mời phụ thuộc giao link ngoài. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-ADM-05.2 | Một phần |  Xếp hàng yêu cầu khôi phục; chưa xác nhận email thực. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-ADM-06.1 | Một phần |  Có cấp quyền/lời mời/gửi lại; giao nhận kích hoạt bên ngoài chưa được kiểm chứng. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-SUP-01 | Một phần | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Luồng ticket có triển khai; biến thể tệp đính kèm fail-closed khi scanner chưa có, chưa xác nhận scanner thật. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |
| UC-SUP-01.1 | Một phần | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Quyền xử lý ticket có code; tệp kèm cần scanner/storage và chưa kiểm chứng runtime ngoài. Xem bảng đặc tả để phân biệt nhánh có điều kiện. |

Không nâng trạng thái Một phần chỉ vì unit/mock test đạt. DEMO_CARD chỉ ngoài production với cờ bật và dữ liệu isDemo; Zalo trao đổi mock lưu NotificationDelivery nội bộ. Phân biệt hai trường hợp này với cấu hình ZNS thật có điều kiện.

## 5. Quyền và giao diện cần xem xét

1. **Allowlist STAFF khác decorator:** chặn create khu, TenantInvitesController, Operations/P1/Announcements/Audit/Support/Housing và outbox/escalate theo chính sách. Chỉ handler được chấp nhận + permission + scope + service mới là quyền thực. `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:44`.
2. **TenantScope chặt:** yêu cầu ít nhất một lease và mọi lease/invoice đều trong scope. Tạo Tenant có handler cho STAFF không có nghĩa hồ sơ mới chưa lease sẽ hiện lại trong mọi danh sách; đây là hành vi source cần kiểm DB/UI theo kịch bản, không tự sửa. `/Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:25`.
3. **Actor TENANT hai bối cảnh:** đăng ký tìm phòng không có sẵn Tenant/lease; cổng thuê và review cần bằng chứng lịch sử riêng. Không thêm role Sinh viên thành role DB mới.
4. **Admin capabilities theo từng endpoint:** accounts.view khác landlords cũ accounts.manage, invite Admin còn kiểm MFA/grant-authority. Tác nhân Admin không tự có quyền vận hành chủ trọ. Preset không tạo Actor riêng.
5. **SYS-05.2 / SYS-07 và TEN-02:** G01 đã ghi API/UI chưa đồng đều; cổng TENANT đọc lease/settlement không có bằng chứng nối shareLeasePdf như màn hình vận hành. Không gán quyền export qua việc dùng chung model. `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:998`.
6. **Quyền mô phỏng không toàn diện:** STF-03 thêm additionalActionChecksApply; ADM-26 nhắc MFA/trạng thái/scope vẫn áp khi gọi thật. Không coi allowed=true là có thể gọi bất cứ endpoint.

## 6. Transaction, tiền và lỗi cần xem xét

- Quyết toán dùng fingerprint/idempotency; cọc bù khoản quyết toán, nợ invoice cũ trình bày riêng. Chốt không tự ghi Payment/invoice, hoàn cọc chỉ ghi nhận. `/Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:61`.
- Ghi Payment, receipt refund, hoàn cọc và đối soát là sổ nội bộ/tham chiếu; không có bằng chứng API lệnh chuyển tiền ngân hàng thật.
- BillingCommands chống requestKey dùng lại khác nội dung; batch kiểm duyệt trả lỗi từng mục, không bảo đảm all-or-nothing. Không mặc định mọi UC rollback toàn bộ khi lỗi/mất response.
- Hóa đơn chưa được sửa hạn/note sau paid>0 hoặc status khác UNPAID; đây là AS-IS, không mở rộng theo kỳ vọng nghiệp vụ. `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:916`.
- Tệp hỗ trợ/scanned evidence fail-closed khi scanner thiếu, không đưa tệp chưa sạch thành bằng chứng hợp lệ. `/Users/hoang/Rental_room_management/backend/src/uploads/malware-scanner.service.ts:10`.
- Chính sách token sau đổi mật khẩu và single-session revoke đã ghi trong báo cáo G01; giữ lịch sử ghi nhận, không âm thầm vá ứng dụng trong giai đoạn BA.

## 7. Kiểm chứng đã chạy và chưa chạy

- Đã chạy **71 suite/736 test** backend unit/mock/HTTP mock nội bộ; 0 thất bại. Bỏ test knowledge.repository dùng DB, không chạy E2E có resetDatabase, không sửa/lint ứng dụng.
- Parser thật markdown-it-py kiểm 162 bảng, mỗi bảng 2 header/20 hàng/40 ô dữ liệu. Node đạt **9.512/9.512 kiểm tra**, 0 lỗi, dẫn chiếu **457 tệp bằng chứng**; kiểm source path/line/nhãn, ID/mục tiêu/actor/trạng thái, nhánh, UML và hash. Đây là kiểm định tài liệu, không phải 9.512 test nghiệp vụ.
- Chưa chạy Flutter/browser acceptance, transaction/concurrency DB thật, migrations của deployment hoặc provider email/ZNS/scanner/Ollama/object storage thật.
- Bảo toàn 846 source, Catalog và UML theo baseline; 11 bảng G01 có hash riêng. File khóa Word đã được cho phép xóa được giữ nguyên. Không commit/branch.

### Rà soát ngữ nghĩa vòng cuối

- Đối chiếu lại quyền STAFF theo RolesGuard/PropertyScopeInterceptor; settlement chỉ LANDLORD theo decorator handler, không suy quyền từ permission STAFF được liệt kê.
- Đối chiếu quyết toán, phân bổ khoản thu, checkout DEMO, maker–checker đối soát và hợp nhất ticket với service/helper. Đây là các điểm rà soát tập trung bổ sung, không thay thế giới hạn runtime đã công bố.
- UC-TEN-05 được bổ sung validation thủ công cardNumber/expiry/cvc, điều kiện khóa ký/URL, form HTML, nhánh token public, Origin, lỗi và khả năng đã lưu link trước lỗi tạo URL. Không nâng DEMO thành thanh toán thẻ thật. Nguồn: `/Users/hoang/Rental_room_management/backend/src/billing/demo-card.gateway.ts:41`, `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.controller.ts:53` và `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:41`.
- UC-BIL-11 chỉnh điểm phát sinh nhánh idempotency về trước callback ghi sổ, theo `/Users/hoang/Rental_room_management/backend/src/billing/billing-commands.service.ts:13`; không đổi mã, mục tiêu hoặc Actor.
- Validator phân biệt hậu tố test E2E với trạng thái đã chạy; literal regex trong inline code không bị nhận nhầm là nhãn source. Mọi nhãn dẫn chiếu nghiệp vụ vẫn phải được khai báo trong cùng bảng.

## 8. Kết luận sử dụng

Bộ đặc tả **đủ phạm vi 162 UC để rà soát BA/Dev/QA theo source AS-IS**, không là biên bản nghiệm thu sản phẩm. Không còn module chưa viết trong Giai đoạn 4. Các điểm hạn chế đã ghi trực tiếp, không đòi đoán chức năng để lấp bảng. Khi chuyển sang test/acceptance cần môi trường DB an toàn và provider được cấu hình; chưa có gói xuất chuẩn 01_System_Analysis, nên không báo toàn bộ bốn giai đoạn đều đã xuất chỉ từ việc hoàn tất đặc tả.
