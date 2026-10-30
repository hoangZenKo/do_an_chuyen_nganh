# Implementation Roadmap

> Baseline: 24/10/2026
>
> Mục tiêu là phát triển chức năng nghiệp vụ, không tiếp tục redesign giao diện. Đây là đề xuất backlog dựa trên source hiện tại của Flutter và backend sibling, không phải xác nhận các flow đã chạy thành công ở runtime.

## Hiện trạng dùng để lập plan

- Đã có source cho phòng/khu trọ, người thuê/hợp đồng, gia hạn, sổ cọc, hóa đơn/thanh toán/chứng từ, bảo trì/chi phí, nhân viên/phân quyền và audit log.
- Đã có tài sản phòng, kiểm tra phòng, phí dịch vụ cố định; maintenance completion có thể tạo expense. Không lập lại các chức năng này như module mới.
- Đã có báo cáo tháng và export CSV; tìm phòng, yêu thích, saved search, lịch xem, đánh giá và bàn giao nhận phòng cũng đã có source.
- Điểm mở rộng rõ nhất: trả phòng/quyết toán trọn luồng, dòng phí chi tiết và tính tiền lẻ ngày, người ở cùng/chuyển phòng, tenant gửi yêu cầu nghiệp vụ, staff scope theo khu trọ.
- `PROJECT_STATUS.md` còn ghi ngày 08/09/2026 và checklist có mục lỗi thời như audit log chưa có. Đối chiếu source và tài liệu ngày 23/10/2026 trước khi chọn ticket; không coi ô chưa đánh dấu là chức năng chắc chắn còn thiếu.

## 1. Thứ tự ưu tiên

| Ưu tiên | Nhóm chức năng | Kết quả cần đạt |
|---|---|---|
| P0 | Chốt baseline tối thiểu | Biết flow nào đã hoạt động và phần nào còn thiếu trước khi sửa |
| P1 | Vòng đời hợp đồng và trả phòng | Từ tạo hợp đồng đến gia hạn, trả phòng, chốt điện nước và xử lý cọc |
| P1/P2 | Người ở cùng và chuyển phòng | Quản lý thành viên thực ở, sức chứa và chuyển phòng không mất lịch sử |
| P2 | Bảo trì nâng cao | Giao việc, hạn xử lý, xác nhận kết quả và thông báo |
| P1 | Billing và công nợ | Hóa đơn có phí dịch vụ, điều chỉnh, đối soát và nhắc nợ đáng tin cậy |
| P1 | Tenant portal | Người thuê tự xem hợp đồng, thanh toán, báo hỏng và nhận thông báo |
| P2 | Nhân viên, phân quyền và admin | Vận hành nhiều nhân viên, kiểm soát scope và truy vết thao tác |
| P2 | Báo cáo và quản trị danh mục | Có báo cáo kinh doanh và quản lý dữ liệu trên toàn hệ thống |
| P3 | Marketplace tìm phòng | Kiểm chứng các flow đã có và hoàn thiện thông báo, dữ liệu tin còn phòng |
| P3 | Tích hợp và production | Zalo/ZNS thật, push notification, backup, monitoring và release pipeline |

## 2. Phase 0 — Chốt baseline trước khi mở rộng

### P0.1. Kiểm chứng source hiện tại

- Chạy `flutter analyze`, Flutter unit/widget tests, backend build/unit tests và backend E2E trên database test riêng.
- Kiểm tra migration status; chỉ áp dụng migration mới khi triển khai ticket cần thay đổi schema, không reset/seed database đang dùng.
- Manual verify login/refresh/logout, property-room, tenant-lease, tạo hóa đơn, thanh toán, payment proof và maintenance upload.
- Dùng fixture/seed trên database test riêng, không ghi đè dữ liệu local đang dùng.

### P0.2. Contract đi cùng từng ticket

- Chuẩn hóa DTO, error code, conflict và format thời gian cho API mới; tận dụng `ApiFailure` hiện có.
- Error envelope toàn hệ thống và Swagger là công việc hỗ trợ, không phải điều kiện chặn mọi chức năng nghiệp vụ.
- Cập nhật checklist theo bằng chứng source/test; tách rõ đã có source, đã test và đã verify trên thiết bị.

**Hoàn thành khi:** lỗi backend được Flutter hiển thị đúng ngữ cảnh; test và E2E chạy lặp lại được trên database sạch.

## 3. Phase 1 — Vòng đời thuê và vận hành cốt lõi

### P1.1. Trả phòng và quyết toán

- Thêm wizard trả phòng: ngày trả, điện/nước cuối, tiền thuê lẻ ngày, phí hư hỏng và lý do.
- Có bản xem trước quyết toán: công nợ còn lại, cọc thực giữ, khoản khấu trừ, số cần thu thêm hoặc hoàn lại.
- Tạo biên bản trả phòng riêng, tái sử dụng tài sản/kiểm tra phòng; không ghi đè biên bản nhận phòng đã xác nhận.
- Chốt quyết toán có version/idempotency; chống bấm hai lần làm trùng hóa đơn hoặc giao dịch cọc.
- Ghi nhận thực thu/thực hoàn bằng giao dịch riêng, không coi xác nhận quyết toán là tiền đã chuyển.
- Cho phép kết thúc thời gian ở nhưng vẫn theo dõi nợ chưa thu; chính sách buộc thanh toán trước khi đóng quyết toán cần được chốt trước khi code.
- Phòng sau khi trả là `VACANT` hoặc `MAINTENANCE` theo kết quả kiểm tra; tenant vẫn giữ tài khoản và lịch sử.

**Tận dụng source:** `Lease`, `DepositTransaction`, `LeaseChange`, `LeaseHandover` và flow handover hiện có; cần hoàn thiện API, Flutter UI, transaction test và device verification.

**Hoàn thành khi:** từ một lease đang thuê tạo được quyết toán có số liệu truy nguyên; retry không ghi tiền hai lần; nợ còn lại không biến mất khi kết thúc lease.

**Phụ thuộc:** cơ chế tính tiền theo ngày và dòng phí ở P1.4. Xây billing calculation/preview trước, rồi nối wizard trả phòng; có thể đặt các ticket trong cùng đợt triển khai.

### P1.2. Người ở cùng và chuyển phòng

- Thêm danh sách thành viên của hợp đồng: người đại diện, người ở cùng, ngày vào/ra và trạng thái thực ở.
- Kiểm tra sức chứa phòng; không yêu cầu mọi người ở cùng đều có tài khoản đăng nhập.
- Tính phí theo người dựa trên lịch sử cư trú và chính sách hiệu lực, không lấy số người hiện tại để tính ngược hóa đơn cũ.
- Chuyển phòng: chọn phòng đích còn trống, ngày hiệu lực, bàn giao hai phòng, xử lý chênh lệch thuê/cọc và giữ liên kết lịch sử hợp đồng.
- Không sửa trực tiếp `roomId` khiến invoice/lịch sử cũ mang thông tin phòng mới.

**Hoàn thành khi:** thay đổi người ở không làm sai phí các kỳ đã chốt; chuyển phòng không có hai lease active tranh phòng hoặc mất lịch sử.

**Phụ thuộc:** bảng thành viên trước phí theo người; quyết toán trước chuyển phòng. Chuyển phòng có thể để P2 nếu cần thu hẹp bản phát hành đầu.

### P2.1. Maintenance nâng cao

- Tận dụng CRUD, comment, trạng thái và completion tạo expense đã có; chỉ bổ sung phần thiếu.
- Giao ticket cho staff cụ thể, hạn xử lý, danh sách công việc của tôi và lọc quá hạn.
- Tenant xác nhận kết quả hoặc yêu cầu mở lại trong thời hạn cấu hình; giữ lịch sử thay vì xóa trạng thái cũ.
- Thông báo giao việc, phản hồi và quá hạn; tách lịch sử xử lý khỏi trạng thái hiện tại.
- Kiểm chứng completion/retry không tạo expense trùng và staff không xử lý ticket ngoài scope.

**Hoàn thành khi:** tenant tạo ticket, staff nhận việc, xử lý, ghi chi phí và tenant xác nhận hoàn tất trên một timeline.

## 4. Phase 2 — Billing, công nợ và báo cáo

### P1.4. Billing production-ready

- Thêm dòng phí chi tiết cho invoice: loại phí, số lượng, đơn giá, khoảng thời gian và số tiền; hiện model có các khoản tổng hợp và `otherAmount`.
- Snapshot đơn giá/công thức/dịch vụ; thay cấu hình không làm đổi hóa đơn cũ. Bổ sung biểu phí có ngày hiệu lực nếu cần.
- Tạo calculation/preview dùng chung cho kỳ thường, vào ở giữa kỳ và trả phòng; chốt quy tắc làm tròn trước khi code.
- Nhập điện/nước theo bảng nhiều phòng, lưu bản nháp và cảnh báo chỉ số bất thường; preview trước khi phát hành bulk invoice.
- Thêm điều chỉnh tăng/giảm có lý do và lịch sử; không âm thầm sửa giao dịch đã ghi nhận.
- Tận dụng payment proof, review và reversal hiện có; bổ sung mã tham chiếu, idempotency và kiểm tra thao tác đồng thời.
- Giữ các trạng thái hiện có `UNPAID/PARTIAL/PAID/CANCELLED`; overdue suy ra từ hạn thanh toán và số dư, không tự thêm enum nếu không cần.
- Kiểm chứng bulk/worker/reminder đã có, ưu tiên chống trùng và thông báo lỗi từng phòng thay vì viết lại.

**Hoàn thành khi:** chạy lại worker hoặc gửi lại request không tạo invoice/payment trùng; dashboard khớp danh sách invoice và payment.

### P2.2. Báo cáo mở rộng

- Tận dụng báo cáo tháng và export CSV đã có, không dựng lại từ đầu.
- Thêm công nợ theo tuổi nợ, sổ giao dịch từng người thuê và danh sách cọc đang giữ.
- So sánh nhiều kỳ/nhiều khu trọ, drill-down từ KPI tới giao dịch gốc.
- Tách tiền thuê thực thu, khoản phải thu, chi phí và cọc; không coi tiền cọc đang giữ là doanh thu.

## 5. Phase 3 — Tenant portal và thông báo

### P1.5. Tenant self-service

- Thêm yêu cầu gia hạn/trả phòng có ngày mong muốn, lý do và trạng thái chờ duyệt/chấp thuận/từ chối/hủy.
- Landlord/staff duyệt yêu cầu, nêu điều kiện hoặc lý do từ chối; không tự sửa hợp đồng khi tenant gửi yêu cầu.
- Hiển thị quyết toán và biên bản trả phòng; tận dụng trang lease, sổ cọc, hóa đơn, maintenance và bàn giao đang có.
- Thống nhất trải nghiệm thông báo thuê/phòng/lịch xem: unread, đánh dấu đọc, deep link và làm mới.
- Thêm khôi phục mật khẩu với token một lần, hết hạn và giới hạn tần suất; đổi mật khẩu đã có, không triển khai lại.
- Push và provider Zalo/ZNS thật để P3, không chặn các luồng thông báo trong app.

**Hoàn thành khi:** tenant xử lý được nhu cầu thường ngày mà không cần truy cập màn quản trị; thao tác nhạy cảm vẫn cần landlord/staff duyệt.

## 6. Phase 4 — Nhân viên, quyền và admin

### P2.3. Staff scope theo khu trọ

- Tận dụng invite/activation, permission presets và audit đã có.
- Thêm phân công staff theo property; quyền hành động và phạm vi dữ liệu là hai kiểm tra riêng.
- Áp scope cho list/detail, báo cáo, upload và các mutation liên quan; không chỉ ẩn màn Flutter.
- Kiểm chứng thu hồi quyền có hiệu lực ở request tiếp theo; test staff gọi ID của khu trọ ngoài phạm vi.
- Mở rộng audit cho thay đổi phân công và các flow quyết toán/chuyển phòng mới.

### P3.1. Admin hỗ trợ vận hành

- Giữ landlord/property management hiện có; ưu tiên hàng đợi xử lý báo cáo tin, phản hồi và dữ liệu bất thường.
- Chỉ thêm quyền đọc chẩn đoán hoặc mutation có lý do nghiệp vụ được duyệt; không mặc định cho admin sửa/xóa mọi invoice/payment.
- Có audit và kiểm soát thông tin cá nhân khi hỗ trợ tenant/landlord.

## 7. Phase 5 — Marketplace tìm phòng

Đây là mở rộng/kiểm chứng các chức năng đang có, không phải viết mới toàn bộ marketplace:

- Kiểm chứng tin hết phòng/ngừng hoạt động được phản ánh đúng ở tìm kiếm, yêu thích và saved search.
- Bổ sung quản lý tùy chọn/tần suất nhận thông báo phù hợp nếu còn thiếu; kiểm tra chống gửi trùng.
- Kiểm thử thực tế toàn luồng `tìm -> đặt lịch -> xem -> tạo lease -> nhận phòng` và thu phản hồi người dùng.
- Chỉ mở rộng discovery sau khi đã đo được vấn đề từ thử nghiệm; chưa ưu tiên thêm AI/chatbot.

## 8. Thứ tự ticket nên triển khai

1. `P0`: rà baseline và chọn dữ liệu test, không thay đổi database đang dùng.
2. `P1`: invoice line items + calculation/preview theo ngày + idempotency.
3. `P1`: wizard trả phòng + quyết toán cọc/công nợ + biên bản trả phòng.
4. `P1`: yêu cầu gia hạn/trả phòng từ tenant + chủ trọ duyệt.
5. `P1/P2`: thành viên cư trú -> phí theo người -> chuyển phòng.
6. `P2`: staff property scope -> maintenance giao việc/SLA -> báo cáo mở rộng.
7. `P3`: khôi phục tài khoản, push/ZNS thật, admin hỗ trợ và thử nghiệm marketplace.

**Bản phát hành chức năng đầu tiên:** ticket 2-4, kèm baseline và kiểm thử liên quan. Không cần chờ toàn bộ P2/P3 hoặc Swagger xong mới giao được giá trị nghiệp vụ.

## Các quyết định cần chốt trước khi code

- Cách tính tiền thuê lẻ ngày: số ngày thực của tháng hay quy ước cố định, tính ngày vào/ra và làm tròn.
- Có cho bù trừ cọc vào công nợ không; ai được duyệt khấu trừ và hoàn cọc.
- Khi trả phòng còn nợ: ghi nhận khoản phải thu tiếp hay chặn đóng quyết toán; không xóa nợ theo lease.
- Một hợp đồng nhiều người: ai đại diện, ai thấy hóa đơn/cọc và ai được gửi yêu cầu kết thúc.

Đây là các lựa chọn nghiệp vụ chưa được người dùng xác nhận, không phải chính sách đã áp dụng trong code.

## 9. Definition of Done

- Có API DTO, authorization/ownership check và migration nếu cần.
- Có repository/provider/screen Flutter với loading, empty, retry, validation và conflict state.
- Có unit test cho service/repository và E2E cho permission, ownership, transaction và idempotency.
- Có audit event cho thao tác thay đổi dữ liệu quan trọng.
- Có manual flow trên simulator/device với backend thật nếu liên quan upload, notification hoặc PDF.
- Cập nhật `IMPLEMENTATION_CHECKLIST.md`, `PROJECT_STATUS.md` và `UPDATE_LOG.md` sau khi verify; không đánh dấu hoàn thành chỉ vì source compile.

## 10. Ngoài phạm vi trước mắt

- Không ưu tiên thêm chatbot/RAG feature mới trước khi flow thuê, billing và maintenance đạt Definition of Done.
- Không làm e-signature pháp lý hoặc tự động ghi nhận tiền cọc nếu chưa có quy trình xác nhận rõ ràng.
- Không bật Zalo/ZNS production bằng mock provider; phải tách test provider và provider thật.
