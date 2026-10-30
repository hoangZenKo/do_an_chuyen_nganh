# Báo cáo kiểm chứng UML Use Case — Giai đoạn 3

Ngày thực hiện: **29/10/2026**, múi giờ Asia/Ho_Chi_Minh. Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Kết luận trong phạm vi AS-IS tĩnh

**Hoàn thành bộ sơ đồ Giai đoạn 3 theo Catalog nguồn hiện có.** Có 28 source PlantUML độc lập; cả 28 đã kiểm cú pháp và render thành công thành 28 SVG + 28 PNG bằng PlantUML thực tế, không dùng ảnh AI hay dịch vụ render công khai.

- Biểu diễn đủ **162/162 UC** của 16 nhóm nghiệp vụ G01–G16. Mỗi UC có đúng một trang module sở hữu.
- **Không thiếu UC, không trùng UC trong bộ module, không tạo UC/Actor mới, không đổi mã/tên/nhóm UC.**
- Tổng thể chỉ chọn 12 mục tiêu thật từ Catalog và có cả năm Actor chính; không thay module thành ellipse giả.
- 21 trang module; G01 và G06 mỗi nhóm hai trang, G08 bốn trang, các nhóm khác một trang. Đây là phân trang góc nhìn, không phải tách/gộp UC.
- Sáu góc nhìn A03 bao phủ toàn bộ 57 UC có STAFF là Actor chính và ba biến thể chỉ đọc. Không vẽ thêm các góc nhìn Actor chỉ lặp ma trận.
- **577 kiểm tra tự động đạt**, gồm đối chiếu dữ liệu, source .puml, hash render, nội dung và hình học SVG; đã xem contact sheet của toàn bộ 28 sơ đồ và ảnh đầy đủ của các trang phức tạp.
- Hash **846 tệp nguồn/test/schema/migration** không đổi so với Giai đoạn 2. Không sửa source ứng dụng, không chạy lại test nghiệp vụ hay xác nhận tích hợp production, không viết đặc tả UC chi tiết.

Kết luận này xác nhận chất lượng và tính truy vết của **tài liệu AS-IS theo code**, không thay thế nghiệm thu end-to-end, kiểm thử bảo mật, hay phê duyệt nghiệp vụ của chủ hệ thống.

## 2. Đầu vào và truy vết

| Đầu vào | Sử dụng |
| --- | --- |
| Catalog chuẩn hóa | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/05_Use_Case_Catalog.md:1 |
| Catalog máy đọc | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json:1 |
| Actor và quy tắc phân quyền | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/03_Actor_Catalog.md:1 |
| Actor–UC Matrix | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/04_Actor_Use_Case_Matrix.md:1 |
| Bằng chứng triển khai | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/07_Traceability_and_Coverage.md:1 |
| Handler/Service/DTO/DB/UI/test | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/traceability.json:1 |
| Phần chưa xác minh/kỹ thuật | /Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/09_Technical_and_Gap_Register.md:1 |

Fingerprint của Catalog và traceability được lưu trong data/diagram-manifest.json. Mọi UC có đường dẫn code trong UC_Diagram_Traceability.md; từng association có bằng chứng và điều kiện trong Association_Traceability.md cùng manifest. Bằng chứng chỉ ra handler/service được triển khai, không suy diễn mục tiêu chỉ từ tên endpoint.

## 3. Bao phủ theo nhóm nghiệp vụ

| Nhóm | Tên nhóm theo Catalog | UC nguồn | UC đã biểu diễn | Trang module | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| G01 | Tài khoản và an toàn truy cập | 11 | 11 | 2 | Đủ, giữ nguyên nhóm |
| G02 | Tìm và lựa chọn phòng | 6 | 6 | 1 | Đủ, giữ nguyên nhóm |
| G03 | Đăng tin, lịch xem và nhận phòng | 7 | 7 | 1 | Đủ, giữ nguyên nhóm |
| G04 | Khu trọ và cơ sở vật chất | 14 | 14 | 1 | Đủ, giữ nguyên nhóm |
| G05 | Nhân sự và ủy quyền vận hành | 4 | 4 | 1 | Đủ, giữ nguyên nhóm |
| G06 | Hồ sơ thuê, hợp đồng và tiền cọc | 17 | 17 | 2 | Đủ, giữ nguyên nhóm |
| G07 | Vòng đời thuê và quyết toán | 7 | 7 | 1 | Đủ, giữ nguyên nhóm |
| G08 | Hóa đơn, thu tiền và công nợ | 28 | 28 | 4 | Đủ, giữ nguyên nhóm |
| G09 | Bảo trì và chi phí vận hành | 5 | 5 | 1 | Đủ, giữ nguyên nhóm |
| G10 | Công việc, thông tin và hỗ trợ sử dụng | 9 | 9 | 1 | Đủ, giữ nguyên nhóm |
| G11 | Báo cáo và giám sát vận hành | 8 | 8 | 1 | Đủ, giữ nguyên nhóm |
| G12 | Tài khoản và tài nguyên nền tảng | 12 | 12 | 1 | Đủ, giữ nguyên nhóm |
| G13 | Kiểm duyệt và chất lượng nội dung | 11 | 11 | 1 | Đủ, giữ nguyên nhóm |
| G14 | Dịch vụ hỗ trợ khách hàng | 8 | 8 | 1 | Đủ, giữ nguyên nhóm |
| G15 | Hồ sơ xác minh và gói dịch vụ | 6 | 6 | 1 | Đủ, giữ nguyên nhóm |
| G16 | Quản trị chính sách và đối soát nền tảng | 9 | 9 | 1 | Đủ, giữ nguyên nhóm |
| **Tổng** | **16 nhóm** | **162** | **162** | **21** | **Không thiếu/trùng** |

Có 234 lượt xuất hiện ellipse trong cả 28 sơ đồ: 162 lượt module + 12 lượt tổng thể + 60 lượt góc nhìn STAFF. Chỉ có **162 UC duy nhất**; việc lặp có chủ đích giữa các góc nhìn không tạo thêm UC.

## 4. Actor và Association

| Actor | Role/ngữ cảnh | Số UC là Actor chính | Quy tắc biểu diễn |
| --- | --- | --- | --- |
| A01 — Khách/chưa đăng nhập | Chưa đăng nhập; không có role GUEST | 11 | Ownership, token và điều kiện dữ liệu theo UC. |
| A02 — Chủ trọ | LANDLORD | 89 | Ownership, token và điều kiện dữ liệu theo UC. |
| A03 — Nhân viên vận hành | STAFF | 57 | Permission + whitelist + property scope; không có kế thừa Chủ trọ. |
| A04 — Người tìm phòng/người thuê | TENANT | 31 | Một role TENANT; ngữ cảnh tìm phòng/đã thuê không tạo hai security role. |
| A05 — Quản trị viên nền tảng | ADMIN | 51 | Capability theo handler + MFA/step-up nếu áp dụng; không toàn quyền nghiệp vụ Chủ trọ. |

Số UC theo Actor không cộng thành 162 vì một UC có thể có nhiều Actor chính. Trong bộ module có **257 associations**: 239 Actor chính, bảy biến thể tham gia hạn chế (V), 11 phối hợp ngoài. Toàn bộ 28 sơ đồ có 333 associations kể cả các lần lặp của góc nhìn.

### 4.1. Bảy biến thể V được vẽ có giới hạn

| UC | Actor | Phạm vi được thể hiện |
| --- | --- | --- |
| UC-DIS-08 | A04 | Chỉ xem khung giờ, không quản lý khung giờ của Chủ trọ. |
| UC-TNT-12.2 | A04 | Chỉ xem biên bản; chấp nhận là UC-TNT-12.3 riêng. |
| UC-OPT-09 | A03 | Chỉ đọc phí/phiên bản với room.view và scope, không ghi phí. |
| UC-STF-01 | A03 | Chỉ đọc nhân viên/preset, không tạo lời mời hoặc cấp quyền. |
| UC-BIL-16 | A03 | Chỉ đọc phân tích tác động với billing.view, không duyệt biểu phí. |
| UC-TEN-05 | A01 | Checkout khi có token DEMO hợp lệ; không tự tạo payment link người khác. |
| UC-DIS-15 | A05 | Chỉ ngữ cảnh ownerId/requesterId của mình và capability tương ứng; không suy quyền xử lý kháng nghị toàn nền tảng. |

Đường xanh vẫn là association UML không hướng, không phải include/extend. Các ô V chỉ có truy cập public gián tiếp hoặc hành vi đã biểu diễn ở UC riêng không nối thêm để tránh hiểu nhầm là Actor chính. Các ô B của STAFF không có association. Danh sách đầy đủ và lý do không vẽ V nằm trong Association_Traceability.md.

### 4.2. Tác nhân phối hợp ngoài

| Actor | Phạm vi UC trong bộ module | Giới hạn |
| --- | --- | --- |
| E01 — Giao liên kết/thông báo | UC-SYS-06; UC-BIL-18.2; UC-SUP-05.2; UC-ADM-03.1; UC-ADM-05.2; UC-ADM-06.1 | Có adapter/queue/webhook; chỉ tương tác nếu nhánh cấu hình khả dụng; chưa xác nhận giao thực. |
| E02 — Nhà cung cấp Zalo ZNS | UC-BIL-18.2 | Chỉ nhánh NotificationsController mà Chủ trọ thực thi; STAFF bị chặn nhánh này. |
| E03 — Quét tệp hỗ trợ | UC-SUP-01; UC-SUP-01.1 | Chỉ nhánh đính kèm; fail-closed khi scanner không cấu hình/không khả dụng. |
| E04 — Dịch vụ mô hình AI | UC-SUP-06 | Ranh giới dịch vụ mô hình ngoài ứng dụng, kể cả đặt local; chưa gọi model thật trong khảo sát. |
| E05 — Kho báo cáo ngoài | UC-ADM-16 | Nhánh object storage; ReportObjectStorageService yêu cầu cấu hình storage ở production. |

Ở góc nhìn STAFF, không vẽ E02 vì STAFF không được gọi nhánh ZNS trực tiếp. UC-SYS-10 chỉ redeem token, không gắn E01. Chat Zalo mô phỏng không gắn E02. Database, worker, scheduler, outbox, logger là nội bộ biên, không tạo Actor. Các provider là tác nhân phối hợp có điều kiện từ Catalog, không phải xác nhận hệ thống production đã kết nối.

## 5. Kiểm tra quyền trực tiếp trên source

| Tình huống nhạy cảm | Quyết định giữ trên sơ đồ | Bằng chứng |
| --- | --- | --- |
| STAFF khai báo trong decorator nhưng controller không whitelist | Không tạo association cho mục tiêu bị chặn. | /Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36 |
| STAFF permission ANY theo handler | Nhãn quyền là các khả năng tùy handler, không yêu cầu tất cả permission của toàn UC cùng lúc. | /Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:56 |
| ADMIN permission ALL, handler override class | Association không bỏ qua capability, MFA hay step-up. | /Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:24; /Users/hoang/Rental_room_management/backend/src/common/admin-access.ts:1 |
| Tạo trực tiếp tenant account khác mời tenant | A03 chính tại UC-TNT-03.1; không tham gia UC-TNT-03. | /Users/hoang/Rental_room_management/backend/src/tenants/tenants.controller.ts:75; /Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.controller.ts:23; /Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36 |
| Phí dịch vụ và biểu phí | STAFF chỉ V ở UC-OPT-09 và UC-BIL-16; khóa kỳ UC-BIL-22 chỉ A02. | /Users/hoang/Rental_room_management/backend/src/rooms/rooms.controller.ts:322; /Users/hoang/Rental_room_management/backend/src/billing/billing.controller.ts:393 |
| Gửi nhắc nợ | A03 chỉ BillingController với billing.policy + propertyId được giao; nhánh ZNS chỉ A02. | /Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:60; /Users/hoang/Rental_room_management/backend/src/notifications/notifications.controller.ts:39; /Users/hoang/Rental_room_management/backend/src/notifications/notifications.service.ts:146 |
| MFA không có Roles decorator trực tiếp | Không coi là public; chỉ A05. | /Users/hoang/Rental_room_management/backend/src/auth/admin-security.controller.ts:19 |
| Gửi pilot feedback | A02/A04 gửi; không nối A05 vào mục tiêu gửi, dù Admin đọc pilot config. | /Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:95 |
| Support requester khác support manager | A02/A04/A05 theo ngữ cảnh requester tại UC-SUP-01; xử lý UC-SUP-01.1 chỉ A05 và điều kiện service. STAFF bị chặn. | /Users/hoang/Rental_room_management/backend/src/support/support.controller.ts:1; /Users/hoang/Rental_room_management/backend/src/support/support.service.ts:1; /Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36 |

Các vị trí handler chi tiết theo từng UC/association nằm trong hai bảng truy vết và manifest; dòng 1 ở bảng này chỉ là file nguồn tổng hợp, không thay thế truy vết cụ thể.

## 6. Quyết định ngữ nghĩa UML

**Include: 0; Extend: 0; Generalization: 0.** Không có quan hệ UC–UC được chứng minh cần vẽ trong baseline này. Không dùng quan hệ chỉ để làm sơ đồ “đầy đủ”. Đây là quyết định bảo thủ theo bằng chứng, không khẳng định UML không bao giờ có các quan hệ này.

| Ứng viên dễ vẽ sai | Kết luận | Căn cứ |
| --- | --- | --- |
| Mọi UC include Đăng nhập | Không vẽ. Phiên hợp lệ là tiền điều kiện, không phải mỗi lần đều thực thi UC-SYS-03. | /Users/hoang/Rental_room_management/backend/src/auth/jwt.strategy.ts:1 |
| Tạo lời mời include kích hoạt | Không vẽ. Hai mục tiêu của người gửi/người nhận, khác thời điểm; tạo invite chưa buộc người nhận redeem. | /Users/hoang/Rental_room_management/backend/src/tenants/tenant-invites.controller.ts:23; /Users/hoang/Rental_room_management/backend/src/auth/account-access.service.ts:54 |
| Duyệt vòng đời include thực thi | Không vẽ. UC-TNT-10 có thể duyệt/từ chối; UC-TNT-11 là lệnh độc lập cho yêu cầu APPROVED. | /Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:127; /Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:163 |
| Kết thúc thuê include quyết toán include hoàn cọc | Không vẽ. Có ràng buộc trạng thái nhưng không chứng minh mọi lần kết thúc bắt buộc gọi toàn chuỗi UC; hoàn cọc chỉ khi có khoản phải hoàn. | /Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:61; /Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:101 |
| Hoàn cọc mở rộng chuyển khoản ngân hàng | Không vẽ Actor/nghiệp vụ ngân hàng không có Catalog. UC-TNT-09 ghi giao dịch và tham chiếu khoản đã hoàn, không chuyển tiền. | /Users/hoang/Rental_room_management/backend/src/leases/settlements.service.ts:113 |
| Lập hợp đồng từ lịch xem là UC riêng | Không phục hồi UC-DIS-11 đã được chuẩn hóa. Nhánh trực tiếp/từ lịch COMPLETED cùng mục tiêu UC-TNT-05. | /Users/hoang/Rental_room_management/backend/src/housing/housing.controller.ts:79; Catalog UC-TNT-05 |
| PDF/CSV là UC extend | Không vẽ thêm. Đây là biến thể đầu ra đã nằm trong UC tra cứu/báo cáo nguồn. | Catalog UC-TNT-04, UC-BIL-20, UC-ADM-14 |
| Maker và Checker là hai security Actor mới | Không tạo. Cùng A05 nhưng phải là hai User khác nhau; điều kiện service không tạo kế thừa Actor. | /Users/hoang/Rental_room_management/backend/src/platform/finance-reconciliation.service.ts:137 |
| ADMIN kế thừa LANDLORD; STAFF kế thừa LANDLORD | Không vẽ. Code kiểm role cụ thể, permission và scope, không có quan hệ thay thế toàn bộ chức năng. | /Users/hoang/Rental_room_management/backend/src/common/roles.guard.ts:34; /Users/hoang/Rental_room_management/backend/src/common/property-scope.ts:36 |
| Phần mô phỏng kế thừa payment/Zalo thật | Không vẽ. Không có UC payment thật được xác nhận; chat giả lập chỉ lưu nội bộ. | /Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:44; /Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:311 |

## 7. Đối chiếu Catalog và các điều chỉnh

Không phát hiện sai khác đủ căn cứ phải thay đổi Catalog Giai đoạn 2. **Không gộp, tách, loại bỏ, đổi mã, đổi Actor chính hoặc chuyển nhóm UC.** Các ngoại lệ authorization đã có trong Matrix được bảo toàn, kể cả khi tên role ở decorator rộng hơn quyền thực thi.

Điều chỉnh trong lúc xây dựng, không phải sửa Catalog:

1. Phân trang G01/G06/G08 để tránh dồn UC vào sơ đồ quá lớn; bảng sở hữu vẫn một UC/một trang module.
2. Chỉ thêm đường V khi có handler cụ thể và nhãn giới hạn; không nâng V thành P.
3. Góc nhìn A03 không mang theo nhánh E02/ZNS của A02. Đây là phép chiếu đúng phạm vi Actor, không thay UC-BIL-18.2.
4. Chuyển STAFF sang phía đối diện Chủ trọ trong các trang module dùng chung để giảm giao cắt; association không hướng nên đổi thứ tự hai đầu trong cú pháp không đổi ngữ nghĩa.
5. Thử Smetana tích hợp ban đầu cho thấy đường nối không chạm đúng oval ở một số UC có stereotype. Bản bàn giao chuyển sang Graphviz WASM cục bộ; đã render và đo lại điểm nối. Không bàn giao ảnh Smetana thử nghiệm trong rendered/.
6. SVG/PNG PlantUML chênh tối đa một pixel do làm tròn kích thước canvas; validator kiểm dung sai một pixel, không chỉnh ảnh sau render.

## 8. Vấn đề còn phải xác minh

### 8.1. Chín UC một phần — vẫn biểu diễn, không nâng trạng thái

| UC | Tên | Phần chưa xác minh |
| --- | --- | --- |
| UC-SYS-06 | Khôi phục mật khẩu bằng liên kết một lần | Đã có token, thu hồi phiên và job giao link; chưa kiểm chứng email/provider thật. |
| UC-BIL-18.2 | Gửi nhắc nợ theo chính sách | APP/outbox có triển khai; EMAIL/ZALO/webhook/ZNS phụ thuộc cấu hình và chưa xác nhận giao thực. |
| UC-SUP-06 | Hỏi trợ lý AI và đọc nguồn hướng dẫn | Retrieval, scope và fallback có code/test; chưa gọi model Ollama thật trong khảo sát. |
| UC-SUP-05.2 | Theo dõi hàng đợi giao nhận | Theo dõi/retry job có code; chưa xác nhận dịch vụ giao nhận ngoài hệ thống. |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | Nhánh mật khẩu trực tiếp giới hạn môi trường dev; nhánh lời mời phụ thuộc giao link ngoài. |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | Xếp hàng yêu cầu khôi phục; chưa xác nhận email thực. |
| UC-ADM-06.1 | Cấp và quản lý quyền quản trị viên | Có cấp quyền/lời mời/gửi lại; giao nhận kích hoạt bên ngoài chưa được kiểm chứng. |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Luồng ticket có triển khai; biến thể tệp đính kèm fail-closed khi scanner chưa có, chưa xác nhận scanner thật. |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | Decorator nhận STAFF nhưng interceptor chặn SupportController; không suy quyền thực thi từ decorator. Quyền xử lý ticket có code; tệp kèm cần scanner/storage và chưa kiểm chứng runtime ngoài. |

### 8.2. UC giới hạn môi trường

- **UC-TEN-05 — DEMO:** chỉ dữ liệu isDemo/DEMO_CARD và cờ môi trường; không có Actor ngân hàng/cổng thẻ tiền thật. A01 chỉ có nhánh checkout token demo hợp lệ.
- **UC-TEN-09.2 — MÔ PHỎNG:** tin lưu trong hệ thống, không coi là gửi Zalo thật; không nối E02.
- **UC-ADM-16:** có object-storage adapter, nhưng chưa xác nhận kết nối runtime, cấu hình/quyền tải file production.

### 8.3. Ba ứng viên ngoài Catalog — không được vẽ

| Gap | Mục tiêu chưa đủ bằng chứng | Xử lý |
| --- | --- | --- |
| GAP-01 | Thanh toán thẻ/ngân hàng tiền thật | Chỉ tìm thấy DEMO_CARD/isDemo và enum legacy; không có bằng chứng luồng cổng thật. Không đưa vào catalog chính. |
| GAP-02 | Ký số hợp đồng có giá trị pháp lý | PDF và chấp nhận biên bản không chứng minh chữ ký số/nhà cung cấp ký số. Không đưa vào catalog chính. |
| GAP-03 | Người dùng tự cập nhật hồ sơ cá nhân | Chỉ thấy xem thông tin phiên/hồ sơ và quản lý hồ sơ Tenant bởi chủ trọ; không thấy bằng chứng đủ cho tự cập nhật. Không đưa vào catalog chính. |

Không có “UC chưa xác minh” ngoài danh sách 162 bị đưa thành ellipse. Chín UC một phần đã có code lõi nên giữ đúng trạng thái; không coi chúng là chức năng hoàn chỉnh. Trước khi nâng trạng thái cần kiểm thử runtime bằng cấu hình, dữ liệu và dịch vụ thật được phép; không suy diễn đã triển khai chỉ vì adapter tồn tại.

## 9. Kiểm chứng thực tế

| Lớp kiểm tra | Kết quả và giới hạn |
| --- | --- |
| Baseline Giai đoạn 2 | Chạy lại tools/validate.cjs: 45 kiểm tra đạt; log Validation_Result.json của Giai đoạn 2 được làm mới. |
| Dữ liệu và .puml Giai đoạn 3 | 577 kiểm tra đạt trong Validation_Result.json, không thiếu hoặc trùng UC module. |
| Cú pháp PlantUML | 28/28 lệnh -checkonly exit 0; mỗi .puml độc lập, không dùng !include ngoài. |
| Render thật | PlantUML 1.2026.9 + OpenJDK 17.0.15 + Graphviz 13.1.2 qua @viz-js/viz 3.17.0; 28 SVG và 28 PNG, mọi lệnh exit 0. |
| Kiểm tra SVG | Đối chiếu đủ entity và edge đã render; UC là ellipse trong biên; Actor ngoài biên; ellipse không chồng nhau; đầu association bám oval. |
| Hiển thị | Đã xem cả 28 trang qua bảy contact sheet, thêm ảnh đầy đủ của Overall, G01 Sessions, G04, G08 Reminders và Actor_A03_06. Không thấy chữ cắt/mất dấu; một số giao cắt ở nhiều Actor dùng chung vẫn tồn tại, không cam kết tối ưu layout tuyệt đối. |
| Tính toàn vẹn | 846 hash nguồn không đổi; Catalog và traceability không đổi; Git HEAD không đổi. |
| Test ứng dụng và provider | Không chạy test ứng dụng, server, database hoặc gọi provider thật ở Giai đoạn 3; không có kết luận runtime mới. |

Bằng chứng máy đọc: Validation_Result.json, Render_Result.json, Source_Integrity_Result.json. Render_Result.json lưu phiên bản, hash JAR, mã thoát, hash từng .puml/ảnh và kích thước canvas. Validator kiểm giới hạn dòng/file của bằng chứng không tự chứng minh ngữ nghĩa nghiệp vụ; các quyết định nhạy cảm ở mục 5–6 được đọc code thủ công.

Công cụ cài thêm nằm trong /tmp/ba-stage3-tooling; không sửa dependency ứng dụng, không dùng mạng để render sơ đồ. Có thể dùng Graphviz native thay WASM khi tái tạo. Source JAR/runtime không được đưa vào repository. Xem README.md để chạy lại.

## 10. Điều kiện chuyển giai đoạn

Danh sách và sơ đồ ổn định theo snapshot hiện tại để chủ hệ thống duyệt và dùng cho đặc tả tiếp theo. Trước khi coi tài liệu là nghiệp vụ vận hành thực tế, cần xác nhận cấu hình production và các UC một phần/DEMO/mô phỏng nêu ở mục 8. Chưa bắt đầu viết đặc tả chi tiết hoặc tự động chuyển sang giai đoạn sau.
