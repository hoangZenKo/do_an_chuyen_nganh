# Kết quả đối chiếu Use Case với mã nguồn

Ngày chốt: 30/10/2026, giờ Việt Nam. Lượt kiểm tra bắt đầu ngày 29/10/2026.

## Kết luận

Bản V4 có những phát biểu nghiệp vụ chưa khớp hiện trạng. Đợt này phát hiện 7 điểm sai hoặc dễ gây hiểu sai trong 5 UC, cùng 1 đường dẫn tham chiếu lịch sử bị đứt. Đã đính chính các điểm này trong tài liệu, không sửa ứng dụng để làm cho tài liệu trở thành đúng.

Bản bàn giao: `/Users/hoang/Desktop/ĐỒ ÁN/Bao_cao_Quan_ly_Nha_tro_V5_2026-10-30_Doi_chieu_Code.docx`. V3 và V4 được giữ nguyên. V5 giữ 162 UC, 16 nhóm, thay 30 hình Use Case bằng bộ trắng đen, nét nối riêng. Không tự thêm, bỏ hoặc đổi mã UC, Actor hay quan hệ bao hàm/mở rộng.

**Chưa đủ cơ sở chứng nhận “đúng 100%” hoặc nghiệm thu toàn bộ hệ thống.** Kiểm tra đầu mối, quyền và test đạt không chứng minh mọi câu trong 162 đặc tả hoặc mọi tình huống thực tế đều đúng. Phạm vi và giới hạn dưới đây là một phần của kết quả kiểm tra, không được bỏ khi sử dụng tài liệu.

## 1. Sai lệch đã đính chính

| Mã | Mức ảnh hưởng | UC | Vấn đề cũ | Hiện trạng và cách đính chính |
|---|---|---|---|---|
| DC-01 | Cao — tiền cọc | UC-TNT-05 | Mục tiêu và hậu điều kiện có thể hiểu mọi nhánh đều tự ghi cọc đã thu khi số tiền dương. | Nhánh trực tiếp tự ghi cọc đã thu; nhánh từ lịch xem chỉ lưu cọc thỏa thuận, không tự ghi thu cọc. Đã tách rõ hai nhánh trong mục tiêu, luồng và kết quả. |
| DC-02 | Trung bình — đầu vào | UC-TNT-05 | Báo cáo cho nhập cả ngày kết thúc khi lập mới. | Phần nhận dữ liệu lập mới không cho endDate. Đã bỏ ngày kết thúc khỏi đầu vào lập mới; giữ ở cập nhật/gia hạn. |
| DC-03 | Trung bình — quy tắc chưa có | UC-TNT-05 | Khẳng định có kiểm tra sức chứa khi lập trực tiếp. | Hàm lập trực tiếp không kiểm capacity. Đã bỏ quy tắc này khỏi bước lập hợp đồng; thêm người ở cùng và chuyển phòng có kiểm tra riêng. |
| DC-04 | Trung bình — thao tác chưa có | UC-TNT-12.1 | “Thêm, sửa hoặc gỡ thành viên”. | Chỉ có xem, thêm, gỡ; chưa có sửa trực tiếp. Đã bỏ sửa và tách đúng điều kiện thêm/gỡ. |
| DC-05 | Cao — bảo toàn thông tin | UC-OPT-07.3 | Nêu kiểm tra tài sản, dễ hiểu tài sản và mọi thông tin phụ thuộc đều ngăn xóa phòng. | Điều kiện chặn là hợp đồng, chỉ số, hóa đơn, lịch xem và hồ sơ chuẩn bị phòng. Tài sản, lịch kiểm tra, phí dịch vụ phòng bị xóa cùng phòng theo schema/migration nguồn. Đã nêu rõ; chưa xác nhận DB triển khai đã áp các migration đó. |
| DC-06 | Cao — thẩm quyền | UC-ADM-18.1 | Quản trị viên hỗ trợ nộp vẫn phải đáp ứng “xét duyệt độc lập”. | Code chỉ chặn người xét có tài khoản trùng chủ trọ được xác minh; không chặn cùng Admin hỗ trợ nộp rồi xét. Đã bỏ khẳng định bắt buộc hai Admin độc lập. Nếu cần quy tắc này, phải lập yêu cầu thay đổi riêng, không mô tả thành AS-IS. |
| DC-07 | Trung bình — điều kiện truy cập | UC-SYS-05.1 | Tiền điều kiện chung yêu cầu tài khoản/phiên còn hiệu lực; phần quản trị dễ hiểu phải xác minh thêm để đăng xuất. | Đăng xuất không kiểm access JWT/mật khẩu; xử lý theo refresh token. Thiết bị vẫn dọn phiên khi không liên lạc được với hệ thống. Đã ghi điều kiện riêng, không buộc đăng nhập lại để thoát. |
| DC-08 | Thấp — truy vết | Tham chiếu 63 UC lịch sử | BA_USE_CASES.md ở thư mục gốc không còn tồn tại. | Sửa sang docs/BA_USE_CASES.md. Chạy lại kiểm tra Catalog: 45/45 mục đạt. |

### Bằng chứng trực tiếp

- DC-01: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:93` và `/Users/hoang/Rental_room_management/backend/src/housing/housing.service.ts:240`. Đã chạy nhánh lập trực tiếp và nhánh lịch xem qua lớp xử lý thật với lưu trữ giả lập; nhánh thứ hai không tạo giao dịch cọc.
- DC-02: `/Users/hoang/Rental_room_management/backend/src/leases/dto/create-lease.dto.ts:10`, `/Users/hoang/Rental_room_management/backend/src/app.bootstrap.ts:52`. Đã thử đầu vào có endDate: bị từ chối vì không phải trường được phép.
- DC-03: `/Users/hoang/Rental_room_management/backend/src/leases/leases.service.ts:93`; đối chiếu `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:148` và `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:215`.
- DC-04: `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.controller.ts:71`, `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:205`, `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:215`, `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:229`.
- DC-05: `/Users/hoang/Rental_room_management/backend/src/rooms/rooms.service.ts:190`; `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:728`, `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:745`, `/Users/hoang/Rental_room_management/backend/prisma/schema.prisma:761`; `/Users/hoang/Rental_room_management/backend/prisma/migrations/20260811110000_room_assets_inspections/migration.sql:45`, `/Users/hoang/Rental_room_management/backend/prisma/migrations/20260811120000_room_service_fees/migration.sql:22`.
- DC-06: `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:33` và `/Users/hoang/Rental_room_management/backend/src/admin/admin-verification.service.ts:56`. Đã gọi submit và review cùng một Admin, không thay hoặc bỏ qua hai hàm xử lý; với dữ liệu giả lập hợp lệ, kết quả chấp thuận được ghi nhận.
- DC-07: `/Users/hoang/Rental_room_management/backend/src/auth/auth.controller.ts:44`, `/Users/hoang/Rental_room_management/backend/src/auth/auth.service.ts:137`, `/Users/hoang/Rental_room_management/lib/data/auth/auth_repository.dart:93`, `/Users/hoang/Rental_room_management/lib/features/auth/auth_providers.dart:116`.
- DC-08: `/Users/hoang/Rental_room_management/docs/BA_USE_CASES.md:1`.

## 2. Phạm vi đã kiểm tra

### Trên toàn danh mục

- Đọc độc lập cây cú pháp TypeScript để lấy lớp/hàm, vai trò, quyền và lời gọi xử lý, không chỉ dùng kết quả phân tích cũ.
- Đối chiếu 162 UC, 405 điểm tiếp nhận yêu cầu; 160 UC có xử lý phía hệ thống, 2 UC chỉ so sánh/ước tính trên ứng dụng.
- Kiểm tra 857 dẫn chiếu hàm: 415 Controller, 442 Service (có lặp giữa UC). Không thiếu ký hiệu, không nhầm tệp; dòng dẫn nằm trong khai báo tương ứng.
- Theo dấu lời gọi từ Controller đến toàn bộ 442 dẫn chiếu Service: đều tìm được đường gọi. Đây là truy vết tĩnh, không chứng minh mọi nhánh đã chạy được.
- Chạy chính RolesGuard và PropertyScopeInterceptor với yêu cầu giả lập: vai trò đúng giá trị ứng dụng, có/thiếu quyền, có/không chỉ định khu cho hành động liên quan. Quyền STAFF ghi trong bảng truy vết không có sai khác với hai lớp đã thử.
- Phép thử quyền không chạy JWT, kiểm tra đầu vào, điều kiện Service, xác minh tăng cường, DB hoặc nhà cung cấp. Đường không có khai báo vai trò phải đọc bảo vệ riêng, không được tự coi là công khai.
- Kiểm tra 272 liên kết tác nhân trên 30 ảnh so với sơ đồ nguồn; giữ 7 liên kết giới hạn. Sơ đồ tổng chỉ có 12 mục tiêu đại diện; 29 sơ đồ nhóm mới bao phủ đủ 162 UC.
- Kiểm tra SHA-256 của 846 tệp source/test/schema/migration: không thay đổi.

### Rà soát quy tắc ưu tiên

Đã đối chiếu trực tiếp các quy tắc nêu trong sổ kiểm tra về: giới hạn STAFF; xác thực và thu hồi phiên; khôi phục mật khẩu; lập hợp đồng; cọc/quyết toán/hoàn; chuyển phòng; người ở cùng; lưu trữ và xóa khu/phòng; thay thế/điều chỉnh hóa đơn; phân bổ/giải phóng/hoàn khoản thu; bàn giao; nhắc nợ; thanh toán mô phỏng; xác minh chủ trọ; hạn mức gói; đề xuất/duyệt đối soát; so sánh và ước tính tại giao diện.

**Không tuyên bố đã rà soát thủ công mọi câu của 162 bảng trong đợt này.** Sổ 02_Use_Case_Audit_Ledger.md phân biệt kiểm tra đầu mối/chuỗi gọi/quyền diện rộng với quy tắc được đọc sâu. Không tự nâng UC chưa rà hết phát biểu thành “đã nghiệm thu”.

## 3. Kiểm thử đã chạy

| Phạm vi | Kết quả | Bằng chứng | Giới hạn |
|---|---|---|---|
| Backend Jest, loại test/e2e | 71 suite đạt, 1 bỏ qua; 736 test đạt, 7 bỏ qua; mã thoát 0 | data/unit-tests-result.json; data/unit-tests.log | Unit/mock; không tương đương 736 kịch bản nghiệp vụ khác nhau. |
| Flutter toàn bộ test hiện có, --no-pub | 678 test đạt, không thất bại/bỏ qua; 55 tệp; mã thoát 0 | data/flutter-summary.json; data/flutter-tests.log | Không thay thế thao tác người dùng trên dữ liệu thật. |
| Tái hiện sai lệch nghi ngờ | 6/6 phép thử đạt | data/semantic-probes.json | Lớp xử lý thật, lưu trữ giả lập, không giao dịch thật. |
| Kiểm tra Catalog | 45/45 mục đạt | ../02_Functional_Decomposition_Use_Case_Catalog/Validation_Result.json | Nhất quán/truy vết, không phải toàn bộ ngữ nghĩa. |
| Cú pháp đặc tả Markdown | 162/162 bảng hợp lệ | ../06_Detailed_Use_Cases/Markdown_Parse_Result.json | Mỗi bảng 20 thuộc tính; không kiểm nghĩa nghiệp vụ. |
| Nội dung Word | 162 bảng khớp dữ liệu; 23 trường ở 5 UC thay đổi so với V4; thay 30 ảnh | data/word-corrections.json | Phần ngoài phạm vi UC được giữ, không chứng nhận lại sơ đồ lớp/tương tác cũ. |

7 test bỏ qua đều thuộc knowledge.repository.spec.ts và cần PostgreSQL riêng: lưu vector, hủy khi nhập lỗi, phạm vi chủ trọ/khu, lọc nội dung, thu hồi nguồn, dữ liệu vector không hợp lệ và khác mô hình embedding. Không tính là đạt.

Trong bảng liên kết test cũ, 81 UC dẫn đến ít nhất một tệp backend test đã chạy và có test đạt. Đây là liên kết tệp liên quan, không phải độ bao phủ nghiệp vụ 81/162. Các UC còn lại có thể có test Flutter hoặc E2E chưa chạy; không suy ra “không có test”.

## 4. Chưa thể xác nhận

1. Chưa nghiệm thu đầu-cuối trên DB riêng đã áp migration với đủ dữ liệu và vai trò; không tác động DB đang dùng hay gửi thông báo thật.
2. Chưa xác nhận giao thư, Zalo ZNS, quét tệp, AI hoặc kho báo cáo ngoài đã chạy thành công với cấu hình triển khai.
3. Thanh toán thẻ chỉ DEMO; trao đổi Zalo hai chiều ở UC tương ứng chỉ mô phỏng. Không thêm thanh toán tiền thật hoặc ký số pháp lý khi chưa có bằng chứng.
4. Chưa chứng minh đồng thời, dữ liệu biên và khôi phục lỗi của mọi UC bằng kiểm thử tích hợp/đầu-cuối.
5. Kết quả kiểm tra/hash trước đợt này là lịch sử. Các tài liệu đã đính chính được ghi công khai trong data/documentation-changes.json; không giả vờ chúng còn nguyên hash cũ.

## 5. Tài nguyên kiểm tra

- 02_Use_Case_Audit_Ledger.md: 162 UC với bằng chứng, mức kiểm tra và giới hạn.
- data/independent-code-audit.json: hàm thực tế, đường gọi Service và phép thử quyền.
- data/semantic-probes.json: kết quả tái hiện, công cụ tại tools/probe-semantic-claims.cjs.
- data/diagram-code-audit.json: từng liên kết trên ảnh và cơ sở kiểm tra.
- data/word-corrections.json: 23 trường sửa, 30 ảnh thay và hash Word cũ/mới.
- data/audit-validation.json: các kiểm tra cuối cùng của lượt này.

Kết quả là tài liệu đã được đính chính theo các bằng chứng trên, không phải chứng nhận “khớp 100%”.

