# Các biểu đồ tuần tự của hệ thống quản lý nhà trọ

## 1 Mục đích và phạm vi

Bộ sơ đồ mô tả 10 kịch bản trọng tâm, liên quan 15 Use Case đã đặc tả, chia thành 22 hình để giữ chữ dễ đọc. Ba actor là Admin, Chủ trọ và Người thuê. Không phải bộ 67 sơ đồ tương ứng toàn bộ 67 Use Case.

Phiên bản 1.2, chuẩn hóa tên thành phần và văn phong ngày 7 tháng 10 năm 2026. Căn cứ đối chiếu mã nguồn ngày 6 tháng 10 năm 2026 được giữ nguyên. Nội dung phân tích không thay thế nghiệm thu.

## 2 Quy ước biểu diễn

- Nhãn trên hình sử dụng ngôn ngữ nghiệp vụ: hành động, dữ liệu trao đổi, kết quả và điều kiện. Đường dẫn API, tên hàm, mã lỗi, biến và trạng thái mã nguồn nằm ở cột chi tiết triển khai khi cần. Tên lớp Controller/Service được giữ trên lifeline; thao tác băm mật khẩu dùng đúng thuật ngữ, còn thuật toán nằm trong bảng.
- Lifeline dùng tên thành phần hoặc đối tượng: Controller/Service giữ đúng tên lớp hiện có; giao diện, actor và kho dữ liệu dùng danh từ tiếng Việt. Tệp định nghĩa thành phần được đối chiếu trong bảng, không tạo thêm lớp hoặc lifeline.
- Màu vàng nhạt #FFFFB9, viền đỏ nâu #800000, chữ Tahoma trên nền trắng; mô phỏng phong cách StarUML cổ điển, không phải dự án .mdj.
- Không có khung bao ngoài hoặc tab sd. Chỉ giữ các khung alt, opt, loop, break và ref; đây là ký hiệu UML, không phải tên hàm trong mã nguồn.
- alt chọn một nhánh; opt chạy khi điều kiện đúng; loop lặp theo dữ liệu; break kết thúc tương tác khi điều kiện lỗi đúng; ref dẫn tới đoạn được phân rã.
- Đường liền biểu diễn lời gọi, nét đứt biểu diễn phản hồi. Thanh vàng mảnh biểu diễn thời gian thực thi ở mức khái quát.
- Actor dùng hình người; boundary cho giao diện và Controller; control cho Service; cylinder cho kho dữ liệu. Không thêm Entity chỉ để đủ ký hiệu.
- Số thông điệp bắt đầu từ 1 trong mỗi hình. Các nhánh alt không chạy lần lượt trong cùng một yêu cầu.
- Hai hình nối bằng ref có thể là hai đoạn của cùng một lần ghi nhận. Các thao tác xác nhận hoặc hủy thay đổi biểu diễn tính thống nhất của dữ liệu, không phải câu lệnh SQL trên hình.

## 3 Điều kiện và ngoại lệ dùng chung

Hệ thống kiểm tra phiên đăng nhập, tình trạng sử dụng tài khoản, vai trò, quyền thao tác và dữ liệu đầu vào trước khi xử lý nghiệp vụ. Nếu biểu mẫu sai thì chưa gửi yêu cầu. Nếu không đủ quyền hoặc điều kiện thì không đi tiếp nhánh thành công.

Nếu chưa lưu thành công, lỗi xử lý hủy các thay đổi trong lần ghi nhận. Lỗi sau khi lưu hoặc mất phản hồi không chứng minh dữ liệu đã bị hủy; cần tra cứu trước khi gửi lại. Ghi nhật ký không làm hủy kết quả nghiệp vụ đã lưu thành công.

## 4 Danh mục sơ đồ

| Kịch bản | Nội dung | Use Case | Hình |
| --- | --- | --- | --- |
| SD-01 | Đăng nhập và điều hướng theo vai trò | UC-SYS-01 | SD-01A, SD-01B, SD-01C |
| SD-02 | Mời và kích hoạt tài khoản người thuê | UC-OPT-04.06, UC-SYS-01.01 | SD-02A, SD-02B |
| SD-03 | Admin tạo tài khoản chủ trọ | UC-ADM-02.02 | SD-03A |
| SD-04 | Tạo hợp đồng thuê phòng | UC-OPT-05.02 | SD-04A, SD-04B |
| SD-05 | Kết thúc hợp đồng và giải phóng phòng | UC-OPT-05.05 | SD-05A |
| SD-06 | Lập hóa đơn cho một hợp đồng | UC-BIL-02.01 | SD-06A, SD-06B |
| SD-07 | Ghi nhận thanh toán hóa đơn | UC-BIL-03.01 | SD-07A, SD-07B |
| SD-08 | Gửi và xét duyệt minh chứng thanh toán | UC-TEN-04, UC-BIL-04 | SD-08A, SD-08B, SD-08C, SD-08D |
| SD-09 | Gửi xử lý và hoàn tất bảo trì | UC-TEN-05.01, UC-OPT-06.03, UC-OPT-06.04 | SD-09A, SD-09B, SD-09C |
| SD-10 | Xem và xuất báo cáo tháng | UC-BIL-06.01, UC-BIL-06.02 | SD-10A, SD-10B |

## SD-01 Đăng nhập và điều hướng theo vai trò

**Điều kiện trước:** Chưa đăng nhập, hoặc ứng dụng đang kiểm tra phiên đã lưu.

**Dữ liệu đầu vào:** Email, mật khẩu; phiên lưu trên thiết bị nếu có.

**Điều kiện sau khi thành công:** Phiên hợp lệ được lưu an toàn; mở đúng khu vực Admin, Chủ trọ hoặc Người thuê.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Bộ sơ đồ tập trung vào ba vai trò Admin, Chủ trọ và Người thuê.
- Sự cố khi khôi phục không đồng nghĩa phiên đã bị thu hồi. Chỉ xóa phiên khi việc gia hạn bị từ chối do thông tin xác thực không còn hợp lệ.
- Các đoạn tham chiếu tránh lặp lại phần tạo phiên và điều hướng.

### SD-01A Kiểm tra thông tin đăng nhập

![SD-01A Kiểm tra thông tin đăng nhập](sequence-diagrams/full/sd-01a-credentials.png)

[SVG vector](sequence-diagrams/full/sd-01a-credentials.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-01a-credentials.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Người dùng → Màn hình đăng nhập | Luồng chung | Nhập email và mật khẩu | Không cần bổ sung |
| 2 | Màn hình đăng nhập → Người dùng | alt Biểu mẫu thiếu hoặc sai định dạng | Yêu cầu sửa biểu mẫu; chưa gửi yêu cầu đăng nhập khi biểu mẫu chưa hợp lệ. | Không cần bổ sung |
| 3 | Màn hình đăng nhập → AuthController | alt Biểu mẫu hợp lệ | Gửi thông tin đăng nhập | POST /auth/login |
| 4 | AuthController → AuthService | alt Biểu mẫu hợp lệ | Yêu cầu xác thực đăng nhập | login(email, password). DTO hợp lệ được chuyển tới AuthService; login là endpoint công khai. |
| 5 | AuthService → Cơ sở dữ liệu | alt Biểu mẫu hợp lệ | Tra cứu tài khoản theo email | Tìm User theo email. Chuẩn hóa email bằng trim và lowercase; tìm đúng một tài khoản. |
| 6 | Cơ sở dữ liệu → AuthService | alt Biểu mẫu hợp lệ | Kết quả tra cứu tài khoản | User hoặc không tồn tại |
| 7 | AuthService → AuthController | alt Biểu mẫu hợp lệ / alt Không tồn tại hoặc bị khóa | Thông tin đăng nhập không hợp lệ | INVALID_CREDENTIALS |
| 8 | AuthController → Màn hình đăng nhập | alt Biểu mẫu hợp lệ / alt Không tồn tại hoặc bị khóa | Từ chối đăng nhập | Không cần bổ sung |
| 9 | Màn hình đăng nhập → Người dùng | alt Biểu mẫu hợp lệ / alt Không tồn tại hoặc bị khóa | Hiển thị lỗi | Không cần bổ sung |
| 10 | AuthService → AuthService | alt Biểu mẫu hợp lệ / alt Tài khoản hoạt động | Kiểm tra mật khẩu | argon2.verify(password) |
| 11 | AuthService → AuthController | alt Biểu mẫu hợp lệ / alt Tài khoản hoạt động / alt Mật khẩu không khớp | Thông tin đăng nhập không hợp lệ | INVALID_CREDENTIALS |
| 12 | AuthController → Màn hình đăng nhập | alt Biểu mẫu hợp lệ / alt Tài khoản hoạt động / alt Mật khẩu không khớp | Từ chối đăng nhập | Không cần bổ sung |
| 13 | Màn hình đăng nhập → Người dùng | alt Biểu mẫu hợp lệ / alt Tài khoản hoạt động / alt Mật khẩu không khớp | Hiển thị lỗi | Không cần bổ sung |

### SD-01B Khôi phục phiên trên thiết bị

![SD-01B Khôi phục phiên trên thiết bị](sequence-diagrams/full/sd-01b-restore-session.png)

[SVG vector](sequence-diagrams/full/sd-01b-restore-session.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-01b-restore-session.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Người dùng → Ứng dụng | Luồng chung | Mở ứng dụng | Không cần bổ sung |
| 2 | Ứng dụng → Ứng dụng | Luồng chung | Đọc phiên đã lưu trên thiết bị | Không cần bổ sung |
| 3 | Ứng dụng → Người dùng | alt Không có phiên lưu | Hiển thị đăng nhập | Không cần bổ sung |
| 4 | Ứng dụng → AuthController | alt Có phiên lưu | Yêu cầu kiểm tra phiên | GET /auth/me. Gửi access token từ phiên lưu; API xác thực tài khoản và trạng thái hoạt động. |
| 5 | AuthController → AuthService | alt Có phiên lưu | Xác minh tài khoản | Không cần bổ sung |
| 6 | AuthService → Cơ sở dữ liệu | alt Có phiên lưu | Tra cứu tài khoản hiện tại | Đọc User hiện tại |
| 7 | Cơ sở dữ liệu → AuthService | alt Có phiên lưu | Trạng thái tài khoản | Trạng thái User |
| 8 | AuthService → AuthController | alt Có phiên lưu | Kết quả xác minh tài khoản | User hoặc lỗi xác thực |
| 9 | AuthController → Ứng dụng | alt Có phiên lưu | Kết quả kiểm tra phiên | Kết quả /auth/me |
| 10 | Ứng dụng → Ứng dụng | alt Có phiên lưu / alt Phiên đăng nhập còn hợp lệ | Lưu thông tin tài khoản mới | Lưu User đã cập nhật Điều kiện triển khai: alt me thành công. |
| 11 | Ứng dụng → AuthController | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ | Yêu cầu gia hạn đăng nhập | POST /auth/refresh Điều kiện triển khai: alt me trả 401. |
| 12 | AuthController → Ứng dụng | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ | Kết quả gia hạn đăng nhập | Điều kiện triển khai: alt me trả 401. |
| 13 | Ứng dụng → Ứng dụng | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ / alt Gia hạn phiên thành công | Lưu phiên mới | Điều kiện triển khai: alt me trả 401. |
| 14 | Ứng dụng → Ứng dụng | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ / alt Yêu cầu gia hạn bị từ chối | Xóa phiên đã lưu | Điều kiện triển khai: alt me trả 401. |
| 15 | Ứng dụng → Người dùng | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ / alt Yêu cầu gia hạn bị từ chối | Yêu cầu đăng nhập lại | Điều kiện triển khai: alt me trả 401. |
| 16 | Ứng dụng → Người dùng | alt Có phiên lưu / alt Thông tin phiên không còn hợp lệ / alt Không hoàn tất gia hạn do lỗi khác | Hiển thị lỗi khôi phục | Hiển thị lỗi khôi phục. Giữ thông tin lưu; SessionController chuyển unauthenticated với failure. Điều kiện triển khai: alt me trả 401. |
| 17 | Ứng dụng → Người dùng | alt Có phiên lưu / alt Không xác minh được phiên do lỗi khác | Hiển thị lỗi khôi phục; không tự xóa phiên đã lưu vì lỗi mạng hoặc lỗi máy chủ. | Điều kiện triển khai: alt me lỗi khác 401. |

### SD-01C Tạo phiên đăng nhập và điều hướng theo vai trò

![SD-01C Tạo phiên đăng nhập và điều hướng theo vai trò](sequence-diagrams/full/sd-01c-session-routing.png)

[SVG vector](sequence-diagrams/full/sd-01c-session-routing.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-01c-session-routing.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | AuthService → AuthService | Luồng chung | Tạo phiên đăng nhập | issueSession(user). Tiếp nối nhánh mật khẩu đúng SD-01A; không dùng đoạn phát hành phiên cho /auth/me. |
| 2 | AuthService → AuthService | Luồng chung | Tạo thông tin gia hạn phiên | Sinh refresh token. Sinh ngẫu nhiên 48 byte và tính SHA-256 để lưu hash, không lưu token gốc. |
| 3 | AuthService → Cơ sở dữ liệu | Luồng chung | Lưu thông tin gia hạn phiên | Lưu RefreshToken |
| 4 | Cơ sở dữ liệu → AuthService | Luồng chung | Thông tin phiên và thời hạn | Bản ghi và expiresAt |
| 5 | AuthService → AuthService | Luồng chung | Tạo thông tin xác thực phiên | Ký access JWT |
| 6 | AuthService → AuthController | Luồng chung | Tài khoản và phiên đăng nhập | User và cặp token |
| 7 | AuthController → Ứng dụng | Luồng chung | Phiên đăng nhập | AuthSession |
| 8 | Ứng dụng → Ứng dụng | Luồng chung | Lưu phiên an toàn | Lưu phiên an toàn. AuthRepository lưu qua SecureSessionStorage; SessionController đánh dấu authenticated. |
| 9 | Ứng dụng → Ứng dụng | alt Người dùng là Admin | Điều hướng đến giao diện quản trị | Mở /admin Điều kiện triển khai: alt role = ADMIN. |
| 10 | Ứng dụng → Người dùng | alt Người dùng là Admin | Hiển thị giao diện quản trị | Điều kiện triển khai: alt role = ADMIN. |
| 11 | Ứng dụng → Ứng dụng | alt Người dùng là Chủ trọ | Điều hướng đến giao diện quản lý nhà trọ | Mở /dashboard Điều kiện triển khai: alt role = LANDLORD. |
| 12 | Ứng dụng → Người dùng | alt Người dùng là Chủ trọ | Hiển thị giao diện quản lý nhà trọ | Điều kiện triển khai: alt role = LANDLORD. |
| 13 | Ứng dụng → Ứng dụng | alt Người dùng là Người thuê | Điều hướng đến giao diện người thuê | Mở /tenant Điều kiện triển khai: alt role = TENANT. |
| 14 | Ứng dụng → Người dùng | alt Người dùng là Người thuê | Hiển thị giao diện người thuê | Điều kiện triển khai: alt role = TENANT. |

### Đối chiếu đặc tả Use Case

**UC-SYS-01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Người dùng: Mở chức năng đăng nhập.<br><br>**2.** Hệ thống: Hiển thị các trường email và mật khẩu.<br><br>**3.** Người dùng: Nhập email, mật khẩu và chọn đăng nhập.<br><br>**4.** Hệ thống: Kiểm tra thông tin đăng nhập, đối chiếu tài khoản và tình trạng hoạt động của tài khoản.<br><br>**5.** Hệ thống: Xác lập phiên đăng nhập và mở khu vực làm việc của Admin hệ thống, Chủ trọ hoặc Người thuê theo vai trò tài khoản. |
| **Luồng thay thế** | **A1 — Tại bước 1:** Thiết bị còn lưu thông tin đăng nhập. Hệ thống xác minh tài khoản; nếu còn hợp lệ thì mở khu vực làm việc theo vai trò mà không yêu cầu nhập lại. UC kết thúc thành công.<br><br>**A2 — Trong nhánh A1:** Thông tin phiên không còn hợp lệ. Hệ thống thử khôi phục trạng thái đăng nhập; nếu bị từ chối thì xóa thông tin phiên đã lưu và quay lại bước 2 để người dùng đăng nhập lại. |
| **Luồng ngoại lệ** | **E1 — Tại bước 3:** Thiếu email, mật khẩu hoặc email không hợp lệ. Yêu cầu điều chỉnh dữ liệu; chưa thực hiện đăng nhập và quay lại bước 3.<br><br>**E2 — Tại bước 4:** Tài khoản không tồn tại, bị khóa hoặc mật khẩu sai. Thông báo thông tin đăng nhập không hợp lệ; không tạo phiên mới. Người dùng kiểm tra lại thông tin và thực hiện lại từ bước 3.<br><br>**E3 — Trong nhánh A1:** Không xác minh được trạng thái đăng nhập do lỗi khác với thông tin phiên không hợp lệ. Hiển thị lỗi; chưa mở khu vực làm việc và không tự coi tài khoản bị khóa hoặc phiên đã bị xóa. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Lưu ý triển khai | Lỗi mạng khi khôi phục không đồng nghĩa token bị thu hồi; chỉ xóa phiên khi refresh bị từ chối 401. |
| Thành phần AuthController | src/auth/auth.controller.ts |
| Thành phần AuthService | src/auth/auth.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Kiểm tra và gia hạn phiên đăng nhập | AuthService.refresh Kiểm tra token lưu và luân chuyển phiên |
| Căn cứ kiểm chứng | Backend src/auth/auth.service.ts login tại dòng 60 |
| Căn cứ kiểm chứng | Backend src/auth/auth.service.ts issueSession tại dòng 134 |
| Căn cứ kiểm chứng | Flutter lib/data/auth/auth_repository.dart restore tại dòng 39 |
| Căn cứ kiểm chứng | Flutter lib/features/auth/auth_navigation.dart homeRouteForSession tại dòng 195 |

## SD-02 Mời và kích hoạt tài khoản người thuê

**Điều kiện trước:** Chủ trọ có hồ sơ người thuê; kích hoạt dùng mã lời mời chưa hết hạn và chưa sử dụng.

**Dữ liệu đầu vào:** Hồ sơ người thuê được chọn, email; mã lời mời và mật khẩu mới khi kích hoạt.

**Điều kiện sau khi thành công:** Tạo lời mời chưa tạo tài khoản đăng nhập. Kích hoạt thành công tạo tài khoản người thuê và liên kết với hồ sơ.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Lời mời có thời hạn 7 ngày. Chủ trọ cung cấp mã hoặc đường dẫn cho người thuê; luồng này không tự động gửi email.
- Tài khoản được lưu trước khi tạo phiên đăng nhập. Nếu lỗi phát sinh sau khi lưu, tài khoản có thể đã tồn tại; cần kiểm tra trước khi kích hoạt lại.
- PX-12 cần chốt việc gửi lại lời mời và xử lý phiên sau kích hoạt. Hiện trạng chưa kiểm tra lại tình trạng sử dụng hồ sơ tại bước kích hoạt.

### SD-02A Tạo lời mời kích hoạt tài khoản

![SD-02A Tạo lời mời kích hoạt tài khoản](sequence-diagrams/full/sd-02a-create-invite.png)

[SVG vector](sequence-diagrams/full/sd-02a-create-invite.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-02a-create-invite.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình hồ sơ người thuê | Luồng chung | Nhập email và xác nhận | Không cần bổ sung |
| 2 | Màn hình hồ sơ người thuê → TenantInvitesController | Luồng chung | Gửi yêu cầu tạo lời mời | POST /tenants/:id/invite |
| 3 | TenantInvitesController → TenantInvitesService | Luồng chung | Yêu cầu tạo lời mời | create(landlordId, id) |
| 4 | TenantInvitesService → Cơ sở dữ liệu | Luồng chung | Tra cứu hồ sơ đang sử dụng | Tìm Tenant đang dùng |
| 5 | Cơ sở dữ liệu → TenantInvitesService | Luồng chung | Hồ sơ và tài khoản liên kết | Tenant và userId |
| 6 | TenantInvitesService → TenantInvitesController | alt Hồ sơ ngoài phạm vi quản lý, đã ngừng sử dụng hoặc đã có tài khoản | Hồ sơ không đủ điều kiện | TENANT_* error |
| 7 | TenantInvitesController → Màn hình hồ sơ người thuê | alt Hồ sơ ngoài phạm vi quản lý, đã ngừng sử dụng hoặc đã có tài khoản | Không chấp nhận tạo lời mời | Không cần bổ sung |
| 8 | Màn hình hồ sơ người thuê → Chủ trọ | alt Hồ sơ ngoài phạm vi quản lý, đã ngừng sử dụng hoặc đã có tài khoản | Hiển thị lỗi | Không cần bổ sung |
| 9 | TenantInvitesService → Cơ sở dữ liệu | alt Hồ sơ hợp lệ | Tra cứu tài khoản theo email | Tìm User theo email |
| 10 | Cơ sở dữ liệu → TenantInvitesService | alt Hồ sơ hợp lệ | Kết quả kiểm tra email | Không cần bổ sung |
| 11 | TenantInvitesService → TenantInvitesController | alt Hồ sơ hợp lệ / alt Email đã đăng ký | Email đã được đăng ký | EMAIL_ALREADY_REGISTERED |
| 12 | TenantInvitesController → Màn hình hồ sơ người thuê | alt Hồ sơ hợp lệ / alt Email đã đăng ký | Không chấp nhận tạo lời mời | Không cần bổ sung |
| 13 | TenantInvitesService → TenantInvitesService | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Tạo mã kích hoạt | Sinh mã và hash |
| 14 | TenantInvitesService → Cơ sở dữ liệu | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Lưu lời mời kích hoạt | Tạo TenantInvite. Lưu email chuẩn hóa, tokenHash, tenantId, landlordId và expiresAt sau 7 ngày. |
| 15 | Cơ sở dữ liệu → TenantInvitesService | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Lời mời đã được lưu | TenantInvite đã lưu |
| 16 | TenantInvitesService → TenantInvitesController | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Mã và đường dẫn kích hoạt | Mã và activationPath |
| 17 | TenantInvitesController → Màn hình hồ sơ người thuê | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Lời mời đã tạo | Không cần bổ sung |
| 18 | Màn hình hồ sơ người thuê → Chủ trọ | alt Hồ sơ hợp lệ / alt Email chưa đăng ký | Hiển thị mã kích hoạt để Chủ trọ cung cấp mã hoặc đường dẫn cho Người thuê. Không tự động gửi email. | Không cần bổ sung |

### SD-02B Kích hoạt và liên kết tài khoản

![SD-02B Kích hoạt và liên kết tài khoản](sequence-diagrams/full/sd-02b-accept-invite.png)

[SVG vector](sequence-diagrams/full/sd-02b-accept-invite.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-02b-accept-invite.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Người thuê → Biểu mẫu kích hoạt | Luồng chung | Nhập mã và mật khẩu | Không cần bổ sung |
| 2 | Biểu mẫu kích hoạt → TenantInvitesController | Luồng chung | Gửi yêu cầu kích hoạt | POST /tenant-invites/accept |
| 3 | TenantInvitesController → TenantInvitesService | Luồng chung | Yêu cầu kiểm tra lời mời | accept(inviteCode) |
| 4 | TenantInvitesService → Cơ sở dữ liệu | Luồng chung | Tra cứu lời mời theo mã | BEGIN; tìm mã theo hash |
| 5 | Cơ sở dữ liệu → TenantInvitesService | Luồng chung | Lời mời và hồ sơ người thuê | Invite kèm Tenant |
| 6 | TenantInvitesService → Cơ sở dữ liệu | alt Mã mời sai, hết hạn, đã dùng hoặc hồ sơ đã có tài khoản | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Sai mã, hết hạn, đã dùng hoặc Tenant đã liên kết. |
| 7 | TenantInvitesService → TenantInvitesController | alt Mã mời sai, hết hạn, đã dùng hoặc hồ sơ đã có tài khoản | Lời mời không hợp lệ | INVALID_TENANT_INVITE Điều kiện triển khai: alt Sai mã, hết hạn, đã dùng hoặc Tenant đã liên kết. |
| 8 | TenantInvitesController → Biểu mẫu kích hoạt | alt Mã mời sai, hết hạn, đã dùng hoặc hồ sơ đã có tài khoản | Từ chối kích hoạt | Điều kiện triển khai: alt Sai mã, hết hạn, đã dùng hoặc Tenant đã liên kết. |
| 9 | TenantInvitesService → TenantInvitesService | alt Lời mời còn hiệu lực | Băm mật khẩu mới | Argon2 hash mật khẩu |
| 10 | TenantInvitesService → Cơ sở dữ liệu | alt Lời mời còn hiệu lực | Tạo tài khoản người thuê | Tạo User TENANT |
| 11 | Cơ sở dữ liệu → TenantInvitesService | alt Lời mời còn hiệu lực / alt Email đã được đăng ký | Dữ liệu trùng; hủy thay đổi | P2002; ROLLBACK Điều kiện triển khai: alt INSERT vi phạm email duy nhất. |
| 12 | TenantInvitesService → TenantInvitesController | alt Lời mời còn hiệu lực / alt Email đã được đăng ký | Email đã được đăng ký | EMAIL_ALREADY_REGISTERED Điều kiện triển khai: alt INSERT vi phạm email duy nhất. |
| 13 | TenantInvitesController → Biểu mẫu kích hoạt | alt Lời mời còn hiệu lực / alt Email đã được đăng ký | Không tạo tài khoản | Điều kiện triển khai: alt INSERT vi phạm email duy nhất. |
| 14 | TenantInvitesService → Cơ sở dữ liệu | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Liên kết tài khoản với hồ sơ | Liên kết Tenant.userId Điều kiện triển khai: alt INSERT thành công. |
| 15 | TenantInvitesService → Cơ sở dữ liệu | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Đánh dấu lời mời đã sử dụng | Đặt invite.acceptedAt Điều kiện triển khai: alt INSERT thành công. |
| 16 | TenantInvitesService → Cơ sở dữ liệu | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Xác nhận lưu toàn bộ dữ liệu | COMMIT Điều kiện triển khai: alt INSERT thành công. |
| 17 | TenantInvitesService → TenantInvitesController | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Phiên đăng nhập người thuê | Điều kiện triển khai: alt INSERT thành công. |
| 18 | TenantInvitesController → Biểu mẫu kích hoạt | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Phiên đăng nhập | AuthSession Điều kiện triển khai: alt INSERT thành công. |
| 19 | Biểu mẫu kích hoạt → Biểu mẫu kích hoạt | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Lưu phiên an toàn | Điều kiện triển khai: alt INSERT thành công. |
| 20 | Biểu mẫu kích hoạt → Người thuê | alt Lời mời còn hiệu lực / alt Tài khoản được tạo thành công | Hiển thị giao diện người thuê | Điều kiện triển khai: alt INSERT thành công. |

### Đối chiếu đặc tả Use Case

**UC-OPT-04.06**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn tạo lời mời kích hoạt tài khoản cho Người thuê.<br><br>**2.** Hệ thống: Hiển thị trường email của Người thuê được mời.<br><br>**3.** Chủ trọ: Nhập email và xác nhận tạo lời mời.<br><br>**4.** Hệ thống: Kiểm tra hồ sơ chưa có tài khoản và email chưa được đăng ký.<br><br>**5.** Hệ thống: Tạo mã mời có thời hạn 7 ngày và đường dẫn kích hoạt gắn với hồ sơ.<br><br>**6.** Chủ trọ: Sao chép mã hoặc đường dẫn để chuyển cho Người thuê. |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Hồ sơ không tồn tại/không hoạt động, đã có tài khoản hoặc email đã đăng ký. Từ chối tạo lời mời. UC kết thúc đối với yêu cầu bị từ chối. |

**UC-SYS-01.01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Người thuê: Mở chức năng kích hoạt tài khoản từ lời mời.<br><br>**2.** Hệ thống: Hiển thị các trường mã mời và mật khẩu mới.<br><br>**3.** Người thuê: Nhập mã mời, đặt mật khẩu và xác nhận kích hoạt.<br><br>**4.** Hệ thống: Kiểm tra lời mời còn hiệu lực, chưa sử dụng và hồ sơ Người thuê chưa liên kết với tài khoản.<br><br>**5.** Hệ thống: Tạo tài khoản Người thuê, liên kết với hồ sơ được mời và đánh dấu lời mời đã sử dụng.<br><br>**6.** Hệ thống: Đăng nhập cho tài khoản mới và mở cổng thông tin Người thuê khi việc xác lập phiên thành công. |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 3:** Mã để trống hoặc mật khẩu dưới 12 ký tự trên biểu mẫu. Không gửi yêu cầu; yêu cầu bổ sung dữ liệu. Sau khi điều chỉnh, thực hiện lại từ bước 3.<br><br>**E2 — Tại bước 4:** Mã sai, hết hạn, đã dùng hoặc hồ sơ đã liên kết tài khoản. Từ chối kích hoạt; hiển thị lỗi lời mời không hợp lệ. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E3 — Tại bước 4:** Mật khẩu không đáp ứng chính sách mật khẩu. Từ chối yêu cầu; Người thuê điều chỉnh mật khẩu. Sau khi điều chỉnh, thực hiện lại từ bước 3.<br><br>**E4 — Tại bước 5:** Email đã được đăng ký. Từ chối tạo tài khoản trùng. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | tenantId, email; inviteCode và mật khẩu mới khi kích hoạt. |
| Kết quả ghi nhận | Tạo lời mời chưa tạo User. Khi kích hoạt thành công, tạo User TENANT và liên kết hồ sơ. |
| Lưu ý triển khai | Phiên đăng nhập được phát hành sau commit tạo tài khoản. Nếu lỗi ở bước này, tài khoản có thể đã tồn tại; kiểm tra lại trước khi kích hoạt lại. |
| Lưu ý triển khai | PX-12 cần chốt gửi lại lời mời và xử lý phiên sau kích hoạt. accept không kiểm tra lại tenant.isActive. |
| Thành phần TenantInvitesController | src/tenants/tenant-invites.controller.ts |
| Thành phần TenantInvitesService | src/tenants/tenant-invites.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Kiểm tra mã mời và chính sách mật khẩu | Kiểm tra biểu mẫu và DTO Mật khẩu đạt chính sách |
| Tham chiếu Tạo phiên đăng nhập sau khi tài khoản đã được lưu | AuthService.issueSession thực hiện SAU commit |
| Căn cứ kiểm chứng | Backend src/tenants/tenant-invites.service.ts create tại dòng 52 |
| Căn cứ kiểm chứng | Backend src/tenants/tenant-invites.service.ts accept tại dòng 87 |
| Căn cứ kiểm chứng | Flutter lib/features/auth/tenant_invite_screen.dart _submit tại dòng 39 |
| Căn cứ kiểm chứng | Flutter lib/features/tenants/tenant_detail_screen.dart _showTenantInviteDialog tại dòng 1061 |

## SD-03 Admin tạo tài khoản chủ trọ

**Điều kiện trước:** Admin đã đăng nhập và có quyền quản trị.

**Dữ liệu đầu vào:** Họ tên, email, mật khẩu; điện thoại tùy chọn.

**Điều kiện sau khi thành công:** Tạo tài khoản chủ trọ được phép sử dụng; không đăng nhập thay tài khoản vừa tạo.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Mật khẩu dài từ 12 đến 128 ký tự và đáp ứng chính sách đã xác định.
- Không tạo tài khoản bằng email đã được đăng ký. Kiểm tra trùng được thực hiện khi lưu tài khoản.

### SD-03A Tạo tài khoản chủ trọ và kiểm tra email

![SD-03A Tạo tài khoản chủ trọ và kiểm tra email](sequence-diagrams/full/sd-03a-create-landlord.png)

[SVG vector](sequence-diagrams/full/sd-03a-create-landlord.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-03a-create-landlord.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Admin → Biểu mẫu chủ trọ | Luồng chung | Nhập tài khoản mới | Không cần bổ sung |
| 2 | Biểu mẫu chủ trọ → AdminController | Luồng chung | Gửi thông tin chủ trọ mới | POST /admin/landlords |
| 3 | AdminController → AdminService | Luồng chung | Yêu cầu tạo tài khoản chủ trọ | createLandlord(input) |
| 4 | AdminService → AdminService | Luồng chung | Kiểm tra và bảo vệ thông tin | Chuẩn hóa; hash mật khẩu |
| 5 | AdminService → Cơ sở dữ liệu | Luồng chung | Lưu tài khoản chủ trọ | INSERT User LANDLORD |
| 6 | Cơ sở dữ liệu → AdminService | alt Email đã được sử dụng | Email đã được sử dụng | P2002 |
| 7 | AdminService → AdminController | alt Email đã được sử dụng | Email đã đăng ký | Không cần bổ sung |
| 8 | AdminController → Biểu mẫu chủ trọ | alt Email đã được sử dụng | Từ chối tạo tài khoản | Không cần bổ sung |
| 9 | Biểu mẫu chủ trọ → Admin | alt Email đã được sử dụng | Yêu cầu sử dụng email khác | Không cần bổ sung |
| 10 | Cơ sở dữ liệu → AdminService | alt Tạo thành công | Tài khoản được phép sử dụng | User isActive = true |
| 11 | AdminService → AdminController | alt Tạo thành công | Thông tin Chủ trọ | Không cần bổ sung |
| 12 | AdminController → Biểu mẫu chủ trọ | alt Tạo thành công | Tài khoản đã tạo | Không cần bổ sung |
| 13 | Biểu mẫu chủ trọ → Admin | alt Tạo thành công | Hiển thị kết quả | Không cần bổ sung |

### Đối chiếu đặc tả Use Case

**UC-ADM-02.02**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Admin hệ thống: Chọn tạo tài khoản Chủ trọ.<br><br>**2.** Hệ thống: Hiển thị các trường họ tên, email, mật khẩu và số điện thoại.<br><br>**3.** Admin hệ thống: Nhập họ tên, email, mật khẩu; bổ sung số điện thoại nếu có và xác nhận tạo.<br><br>**4.** Hệ thống: Kiểm tra dữ liệu bắt buộc, định dạng email, chính sách mật khẩu và việc email đã được đăng ký.<br><br>**5.** Hệ thống: Tạo tài khoản có vai trò Chủ trọ, trạng thái đang hoạt động và hiển thị tài khoản mới. |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Email không hợp lệ hoặc mật khẩu không đạt chính sách. Từ chối yêu cầu; Admin hệ thống điều chỉnh biểu mẫu. Sau khi điều chỉnh, thực hiện lại từ bước 3.<br><br>**E2 — Tại bước 5:** Email đã được dùng. Không tạo tài khoản; thông báo email đã đăng ký. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Kết quả ghi nhận | Tạo User LANDLORD, isActive = true; không phát hành phiên cho tài khoản mới. |
| Lưu ý triển khai | Mật khẩu 12 đến 128 ký tự và có đủ nhóm ký tự theo DTO. |
| Lưu ý triển khai | Email trùng được phát hiện bởi ràng buộc duy nhất tại INSERT; service không truy vấn trước để kiểm tra trùng. |
| Tham chiếu Kiểm tra quyền quản trị và thông tin đăng ký | Guards ADMIN và DTO Kiểm tra email mật khẩu |
| Thành phần AdminController | src/admin/admin.controller.ts |
| Thành phần AdminService | src/admin/admin.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Căn cứ kiểm chứng | Backend src/admin/admin.service.ts createLandlord tại dòng 156 |
| Căn cứ kiểm chứng | Backend src/admin/dto/create-landlord.dto.ts CreateLandlordDto tại dòng 3 |
| Căn cứ kiểm chứng | Flutter lib/features/admin/admin_landlord_form_screen.dart Tệp giao diện liên quan đối chiếu ở mức tệp |

## SD-04 Tạo hợp đồng thuê phòng

**Điều kiện trước:** Chủ trọ đã chọn khu trọ và hồ sơ người thuê; xác nhận thông tin trên biểu mẫu.

**Dữ liệu đầu vào:** Phòng thuê, hồ sơ người thuê, giá thuê tháng, tiền cọc mặc định 0 và ngày bắt đầu tùy chọn.

**Điều kiện sau khi thành công:** Tạo hợp đồng có hiệu lực và chuyển phòng sang Đang thuê. Nếu tiền cọc lớn hơn 0, hiện trạng ghi nhận khoản thu cọc ban đầu.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- PX-01 đến PX-04 chưa chốt giá thuê 0, trạng thái phòng đủ điều kiện, cách thu cọc ban đầu và ngày kết thúc.
- SD-04A và SD-04B là hai đoạn của cùng một lần tạo hợp đồng. Các thay đổi được ghi nhận cùng nhau hoặc hủy nếu chưa lưu thành công.
- Điều kiện kiểm tra là phòng chưa có hợp đồng hiệu lực; không mặc định phòng phải ở trạng thái Trống. Hiện trạng chưa ngăn một người thuê có nhiều hợp đồng hiệu lực.
- Việc ghi nhận cùng nhau chưa đủ để khẳng định đã ngăn mọi trường hợp tạo hợp đồng đồng thời; cần kiểm chứng riêng.

### SD-04A Kiểm tra điều kiện lập hợp đồng

![SD-04A Kiểm tra điều kiện lập hợp đồng](sequence-diagrams/full/sd-04a-lease-validation.png)

[SVG vector](sequence-diagrams/full/sd-04a-lease-validation.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-04a-lease-validation.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Biểu mẫu hợp đồng | Luồng chung | Xác nhận tạo hợp đồng | Không cần bổ sung |
| 2 | Biểu mẫu hợp đồng → LeasesController | Luồng chung | Gửi thông tin hợp đồng | POST /leases |
| 3 | LeasesController → LeasesService | Luồng chung | Yêu cầu tạo hợp đồng | create(landlordId, input) |
| 4 | LeasesService → Cơ sở dữ liệu | Luồng chung | Tra cứu phòng thuộc quản lý | BEGIN; tìm Room sở hữu |
| 5 | Cơ sở dữ liệu → LeasesService | Luồng chung | Thông tin phòng và khu trọ | Room và khu trọ |
| 6 | LeasesService → Cơ sở dữ liệu | alt Không tìm thấy phòng, phòng đã ngừng sử dụng hoặc khu trọ đã lưu trữ | Hủy các thay đổi chưa lưu | ROLLBACK |
| 7 | LeasesService → LeasesController | alt Không tìm thấy phòng, phòng đã ngừng sử dụng hoặc khu trọ đã lưu trữ | Lỗi phòng hoặc khu trọ | Không cần bổ sung |
| 8 | LeasesController → Biểu mẫu hợp đồng | alt Không tìm thấy phòng, phòng đã ngừng sử dụng hoặc khu trọ đã lưu trữ | Từ chối tạo hợp đồng | Không cần bổ sung |
| 9 | LeasesService → Cơ sở dữ liệu | alt Phòng hợp lệ | Tra cứu hồ sơ thuộc quản lý | Tìm Tenant sở hữu |
| 10 | Cơ sở dữ liệu → LeasesService | alt Phòng hợp lệ | Hồ sơ và tình trạng sử dụng | Tenant và isActive |
| 11 | LeasesService → Cơ sở dữ liệu | alt Phòng hợp lệ / alt Không tìm thấy hồ sơ người thuê hoặc hồ sơ đã ngừng sử dụng | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Thiếu Tenant hoặc Tenant ngừng dùng. |
| 12 | LeasesService → LeasesController | alt Phòng hợp lệ / alt Không tìm thấy hồ sơ người thuê hoặc hồ sơ đã ngừng sử dụng | Lỗi hồ sơ Người thuê | Điều kiện triển khai: alt Thiếu Tenant hoặc Tenant ngừng dùng. |
| 13 | LeasesController → Biểu mẫu hợp đồng | alt Phòng hợp lệ / alt Không tìm thấy hồ sơ người thuê hoặc hồ sơ đã ngừng sử dụng | Từ chối tạo hợp đồng | Điều kiện triển khai: alt Thiếu Tenant hoặc Tenant ngừng dùng. |

### SD-04B Tạo hợp đồng và ghi nhận tiền cọc

![SD-04B Tạo hợp đồng và ghi nhận tiền cọc](sequence-diagrams/full/sd-04b-lease-persistence.png)

[SVG vector](sequence-diagrams/full/sd-04b-lease-persistence.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-04b-lease-persistence.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | LeasesService → Cơ sở dữ liệu | Luồng chung | Tra cứu hợp đồng có hiệu lực | Tìm ACTIVE lease của phòng |
| 2 | Cơ sở dữ liệu → LeasesService | Luồng chung | Kết quả kiểm tra hợp đồng | Không cần bổ sung |
| 3 | LeasesService → Cơ sở dữ liệu | alt Phòng đã có hợp đồng hiệu lực | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Phòng đã có ACTIVE lease. |
| 4 | LeasesService → LeasesController | alt Phòng đã có hợp đồng hiệu lực | Phòng đã có hợp đồng hiệu lực | ROOM_OCCUPIED Điều kiện triển khai: alt Phòng đã có ACTIVE lease. |
| 5 | LeasesController → Biểu mẫu hợp đồng | alt Phòng đã có hợp đồng hiệu lực | Yêu cầu chọn phòng khác | Điều kiện triển khai: alt Phòng đã có ACTIVE lease. |
| 6 | Biểu mẫu hợp đồng → Chủ trọ | alt Phòng đã có hợp đồng hiệu lực | Thông báo phòng đã được thuê | Điều kiện triển khai: alt Phòng đã có ACTIVE lease. |
| 7 | LeasesService → Cơ sở dữ liệu | alt Phòng chưa có hợp đồng hiệu lực | Lưu hợp đồng có hiệu lực | Tạo Lease ACTIVE Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 8 | Cơ sở dữ liệu → LeasesService | alt Phòng chưa có hợp đồng hiệu lực | Hợp đồng mới | Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 9 | LeasesService → Cơ sở dữ liệu | alt Phòng chưa có hợp đồng hiệu lực / opt Tiền cọc > 0 | Ghi nhận khoản thu cọc ban đầu | Tạo cọc COLLECTED. Không áp dụng khi deposit không nhập hoặc bằng 0; đây là hành vi hiện tại, chưa coi chính sách thu cọc đã chốt. Điều kiện triển khai: alt Chưa có ACTIVE lease / opt deposit > 0 theo hiện trạng PX-03. |
| 10 | LeasesService → Cơ sở dữ liệu | alt Phòng chưa có hợp đồng hiệu lực | Cập nhật phòng thành Đang thuê | Room = OCCUPIED. Cập nhật tenantName theo hồ sơ người thuê. Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 11 | LeasesService → Cơ sở dữ liệu | alt Phòng chưa có hợp đồng hiệu lực | Xác nhận lưu toàn bộ dữ liệu | COMMIT Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 12 | LeasesService → LeasesController | alt Phòng chưa có hợp đồng hiệu lực | Hợp đồng đã lưu | Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 13 | LeasesController → Biểu mẫu hợp đồng | alt Phòng chưa có hợp đồng hiệu lực | Tạo hợp đồng thành công | Điều kiện triển khai: alt Chưa có ACTIVE lease. |
| 14 | Biểu mẫu hợp đồng → Chủ trọ | alt Phòng chưa có hợp đồng hiệu lực | Hiển thị hợp đồng | Điều kiện triển khai: alt Chưa có ACTIVE lease. |

### Đối chiếu đặc tả Use Case

**UC-OPT-05.02**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Tại hồ sơ Người thuê, chọn Tạo hợp đồng thuê.<br><br>**2.** Hệ thống: Hiển thị danh sách phòng có thể chọn trên biểu mẫu và các trường giá thuê tháng, tiền cọc, ngày bắt đầu; điều kiện lựa chọn phòng cần đối chiếu [PX-02](#px-02).<br><br>**3.** Chủ trọ: Chọn phòng dự kiến cho thuê.<br><br>**4.** Hệ thống: Điền giá thuê theo giá phòng nếu trường giá thuê chưa có giá trị; hiển thị ngày bắt đầu mặc định là ngày hiện tại.<br><br>**5.** Chủ trọ: Kiểm tra hoặc điều chỉnh giá thuê, nhập tiền cọc nếu có, chọn ngày bắt đầu và xác nhận tạo hợp đồng.<br><br>**6.** Hệ thống: Kiểm tra phòng và Người thuê thuộc phạm vi quản lý, đang được sử dụng, khu trọ chưa lưu trữ và phòng chưa có hợp đồng hiệu lực; kiểm tra dữ liệu nhập theo chức năng hiện tại.<br><br>**7.** Hệ thống: Tạo hợp đồng Hiệu lực, lưu điều khoản và cập nhật phòng thành Đang thuê, gắn tên Người thuê; cách ghi nhận thu cọc khi nhập cọc dương được tách tại [PX-03](#px-03).<br><br>**8.** Hệ thống: Trở về hồ sơ Người thuê và cập nhật thông tin hợp đồng liên quan. |
| **Luồng thay thế** | **A1 — Tại bước 5:** Không nhập tiền cọc hoặc nhập 0. Ghi nhận tiền cọc hợp đồng bằng 0; tiếp tục bước 6 và tại bước 7 không tạo khoản thu cọc ban đầu.<br><br>**A2 — Trước khi xác nhận tại bước 5:** Chủ trọ quay lại hồ sơ Người thuê. Không thực hiện tạo hợp đồng; UC kết thúc. |
| **Luồng ngoại lệ** | **E1 — Tại bước 2:** Chưa chọn khu trọ. Thông báo cần chọn khu trọ; chưa hiển thị biểu mẫu lập hợp đồng. Chủ trọ chọn khu trọ rồi khởi tạo lại UC.<br><br>**E2 — Tại bước 2:** Không có phòng trong danh sách được phép chọn. Thông báo không có phòng để lập hợp đồng; UC kết thúc.<br><br>**E3 — Tại bước 5:** Chưa chọn phòng hoặc giá thuê không đạt điều kiện của biểu mẫu. Chưa thực hiện tạo hợp đồng. Nếu chưa chọn phòng, quay lại bước 3 rồi tiếp tục bước 4 và bước 5. Nếu giá thuê không đạt điều kiện của biểu mẫu, điều chỉnh giá thuê tại bước 5 rồi xác nhận lại. Chênh lệch giá thuê xem [PX-01](#px-01).<br><br>**E4 — Tại bước 6:** Phòng, Người thuê không tồn tại, ngoài phạm vi, đã ngừng sử dụng hoặc khu trọ đã lưu trữ. Từ chối tạo; UC kết thúc không có hợp đồng mới từ yêu cầu bị từ chối.<br><br>**E5 — Tại bước 6:** Phòng đã có hợp đồng hiệu lực. Từ chối tạo thêm; Chủ trọ quay lại bước 3 để chọn phòng khác, tiếp tục bước 4 và kiểm tra lại giá thuê trước khi xác nhận tại bước 5. Giá thuê chỉ được điền theo giá phòng khi trường này chưa có giá trị.<br><br>**E6 — Tại bước 7–8:** Không hoàn tất hoặc không nhận được kết quả. Hiển thị lỗi nếu có; kiểm tra lịch sử hợp đồng trước khi tạo lại vì chưa xác định được kết quả ghi nhận. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | roomId, tenantId, monthlyRent, deposit mặc định 0, startDate tùy chọn. |
| Kết quả ghi nhận | Tạo Lease ACTIVE và đặt Room OCCUPIED; cọc > 0 tạo DepositTransaction COLLECTED theo hiện trạng. |
| Lưu ý triển khai | Các kiểm tra và ghi dữ liệu đều trong một transaction; SD-04A và SD-04B là hai đoạn của cùng giao dịch. |
| Lưu ý triển khai | Chỉ kiểm tra không có ACTIVE lease, không mặc định yêu cầu room.status phải là VACANT; chưa có chặn nhiều hợp đồng của cùng Tenant. |
| Lưu ý triển khai | Không khẳng định khóa cạnh tranh đồng thời chỉ vì đã dùng transaction; cần nghiệm thu đồng thời riêng. |
| Tham chiếu SD-04B Tiếp tục ghi nhận cùng hợp đồng | SD-04B Tiếp tục cùng transaction |
| Thành phần LeasesController | src/leases/leases.controller.ts |
| Thành phần LeasesService | src/leases/leases.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Ghi nhật ký tạo hợp đồng sau khi lưu thành công | AuditService.recordSafe lease.create sau commit |
| Căn cứ kiểm chứng | Backend src/leases/leases.service.ts create tại dòng 85 |
| Căn cứ kiểm chứng | Backend src/leases/leases.controller.ts async create tại dòng 28 |
| Căn cứ kiểm chứng | Flutter lib/features/tenants/lease_form_screen.dart _submit tại dòng 59 |

## SD-05 Kết thúc hợp đồng và giải phóng phòng

**Điều kiện trước:** Chủ trọ chọn hợp đồng thuộc phạm vi và xác nhận kết thúc.

**Dữ liệu đầu vào:** Hợp đồng được chọn để kết thúc.

**Điều kiện sau khi thành công:** Hợp đồng chuyển sang Đã kết thúc; phòng chỉ chuyển sang Trống khi không còn hợp đồng hiệu lực khác.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Hiện trạng chưa từ chối việc kết thúc lại hợp đồng đã kết thúc; thao tác lại có thể thay đổi ngày kết thúc.
- Không tự hoàn cọc hoặc quyết toán hóa đơn; đây là các nghiệp vụ riêng.

### SD-05A Kết thúc hợp đồng và giải phóng phòng

![SD-05A Kết thúc hợp đồng và giải phóng phòng](sequence-diagrams/full/sd-05a-end-lease.png)

[SVG vector](sequence-diagrams/full/sd-05a-end-lease.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-05a-end-lease.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình chi tiết hợp đồng | Luồng chung | Xác nhận kết thúc hợp đồng | Không cần bổ sung |
| 2 | Màn hình chi tiết hợp đồng → LeasesController | Luồng chung | Gửi yêu cầu kết thúc hợp đồng | POST /leases/:id/end |
| 3 | LeasesController → LeasesService | Luồng chung | Yêu cầu kết thúc hợp đồng | end(landlordId, id) |
| 4 | LeasesService → Cơ sở dữ liệu | Luồng chung | Tra cứu hợp đồng thuộc quản lý | BEGIN; tìm Lease sở hữu |
| 5 | Cơ sở dữ liệu → LeasesService | Luồng chung | Kết quả tra cứu hợp đồng | Lease hoặc không có |
| 6 | LeasesService → Cơ sở dữ liệu | alt Không tìm thấy trong phạm vi | Hủy các thay đổi chưa lưu | ROLLBACK |
| 7 | LeasesService → LeasesController | alt Không tìm thấy trong phạm vi | Không tìm thấy hợp đồng | LEASE_NOT_FOUND |
| 8 | LeasesController → Màn hình chi tiết hợp đồng | alt Không tìm thấy trong phạm vi | Từ chối kết thúc | Không cần bổ sung |
| 9 | LeasesService → Cơ sở dữ liệu | alt Tìm thấy hợp đồng | Đánh dấu hợp đồng đã kết thúc | Lease = ENDED. Ghi endDate bằng thời điểm hiện tại. |
| 10 | LeasesService → Cơ sở dữ liệu | alt Tìm thấy hợp đồng | Tra cứu hợp đồng còn hiệu lực | Tìm ACTIVE lease còn lại |
| 11 | Cơ sở dữ liệu → LeasesService | alt Tìm thấy hợp đồng | Hợp đồng còn hiệu lực | Không cần bổ sung |
| 12 | LeasesService → Cơ sở dữ liệu | alt Tìm thấy hợp đồng / alt Không còn hợp đồng hiệu lực của phòng | Cập nhật phòng thành Trống | Room = VACANT. Đồng thời xóa tenantName của phòng. Điều kiện triển khai: alt Không còn ACTIVE lease. |
| 13 | LeasesService → LeasesService | alt Tìm thấy hợp đồng / alt Phòng còn hợp đồng hiệu lực khác | Giữ trạng thái phòng | Điều kiện triển khai: alt Còn ACTIVE lease khác. |
| 14 | LeasesService → Cơ sở dữ liệu | alt Tìm thấy hợp đồng | Xác nhận lưu toàn bộ dữ liệu | COMMIT |
| 15 | LeasesService → LeasesController | alt Tìm thấy hợp đồng | Hợp đồng đã kết thúc | Không cần bổ sung |
| 16 | LeasesController → Màn hình chi tiết hợp đồng | alt Tìm thấy hợp đồng | Kết quả kết thúc | Không cần bổ sung |
| 17 | Màn hình chi tiết hợp đồng → Chủ trọ | alt Tìm thấy hợp đồng | Hiển thị lịch sử thuê | Không cần bổ sung |

### Đối chiếu đặc tả Use Case

**UC-OPT-05.05**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn kết thúc hợp đồng.<br><br>**2.** Hệ thống: Hiển thị yêu cầu xác nhận kết thúc hợp đồng đã chọn.<br><br>**3.** Chủ trọ: Xác nhận kết thúc.<br><br>**4.** Hệ thống: Kiểm tra hợp đồng thuộc phạm vi quản lý của Chủ trọ.<br><br>**5.** Hệ thống: Đánh dấu hợp đồng Đã kết thúc, ghi ngày kết thúc hiện tại; nếu phòng không còn hợp đồng hiệu lực thì chuyển phòng thành Trống và bỏ tên Người thuê đang gắn.<br><br>**6.** Hệ thống: Cập nhật hợp đồng và tình trạng phòng để Chủ trọ kiểm tra. |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Hợp đồng không thuộc Chủ trọ hoặc không tồn tại. Từ chối thao tác. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | leaseId. |
| Kết quả ghi nhận | Lease chuyển ENDED; chỉ đặt Room VACANT khi không còn ACTIVE lease khác. |
| Lưu ý triển khai | Hiện trạng không từ chối hợp đồng đã ENDED; gọi lại có thể ghi lại endDate. |
| Tham chiếu Ghi nhật ký kết thúc hợp đồng | AuditService.recordSafe lease.end sau commit |
| Thành phần LeasesController | src/leases/leases.controller.ts |
| Thành phần LeasesService | src/leases/leases.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Căn cứ kiểm chứng | Backend src/leases/leases.service.ts end tại dòng 147 |
| Căn cứ kiểm chứng | Backend src/leases/leases.controller.ts async end tại dòng 58 |
| Căn cứ kiểm chứng | Flutter lib/features/tenants/tenant_providers.dart Tệp giao diện liên quan đối chiếu ở mức tệp |

## SD-06 Lập hóa đơn cho một hợp đồng

**Điều kiện trước:** Chủ trọ chọn hợp đồng có hiệu lực thuộc phạm vi quản lý.

**Dữ liệu đầu vào:** Hợp đồng, kỳ hóa đơn, hạn thanh toán, khoản thu khác, ghi chú; tối đa hai loại chỉ số điện nước.

**Điều kiện sau khi thành công:** Tạo hóa đơn Chưa thanh toán, gồm tiền thuê, điện, nước và phí. Chỉ số mới được lưu cùng hóa đơn.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Không gửi chỉ số mới thì dùng số đã ghi của cùng phòng và kỳ. Thành phần chưa có dữ liệu được tính bằng 0 theo hiện trạng; PX-16 cần xác nhận.
- Không tạo thêm hóa đơn hoặc chỉ số trùng với dữ liệu đã ghi trong cùng kỳ. Chi tiết phát hiện trùng nằm ở bảng triển khai.
- Phí dịch vụ đang áp dụng được cộng vào khoản thu khác và tóm tắt trong ghi chú. Hóa đơn tổng tiền 0 vẫn được ghi là Chưa thanh toán theo hiện trạng PX-17.

### SD-06A Kiểm tra hợp đồng kỳ và chỉ số điện nước

![SD-06A Kiểm tra hợp đồng kỳ và chỉ số điện nước](sequence-diagrams/full/sd-06a-invoice-validation.png)

[SVG vector](sequence-diagrams/full/sd-06a-invoice-validation.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-06a-invoice-validation.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Biểu mẫu hóa đơn | Luồng chung | Xác nhận lập hóa đơn | Không cần bổ sung |
| 2 | Biểu mẫu hóa đơn → BillingController | Luồng chung | Gửi thông tin lập hóa đơn | POST /billing/invoices |
| 3 | BillingController → BillingService | Luồng chung | Yêu cầu lập hóa đơn | createInvoice(input) |
| 4 | BillingService → Cơ sở dữ liệu | Luồng chung | Tra cứu hợp đồng thuộc quản lý | Tìm Lease sở hữu |
| 5 | Cơ sở dữ liệu → BillingService | Luồng chung | Hợp đồng và giá thuê | Lease và giá thuê |
| 6 | BillingService → BillingController | alt Không tìm thấy hợp đồng hoặc hợp đồng đã hết hiệu lực | Hợp đồng không đủ điều kiện | LEASE_NOT_FOUND / NOT_ACTIVE Điều kiện triển khai: alt Thiếu hợp đồng hoặc không ACTIVE. |
| 7 | BillingController → Biểu mẫu hóa đơn | alt Không tìm thấy hợp đồng hoặc hợp đồng đã hết hiệu lực | Không lập hóa đơn | Điều kiện triển khai: alt Thiếu hợp đồng hoặc không ACTIVE. |
| 8 | BillingService → BillingService | alt Hợp đồng có hiệu lực | Kiểm tra kỳ và chỉ số | Kiểm tra kỳ và chỉ số. billingMonth phải thuộc thời gian thuê; dueDate hợp lệ; không lặp utilityType; currentReading >= previousReading và unitPrice > 0. Điều kiện triển khai: alt Hợp đồng ACTIVE. |
| 9 | BillingService → BillingController | alt Hợp đồng có hiệu lực / alt Kỳ hoặc chỉ số không hợp lệ | Lỗi kỳ hoặc chỉ số | Điều kiện triển khai: alt Hợp đồng ACTIVE. |
| 10 | BillingController → Biểu mẫu hóa đơn | alt Hợp đồng có hiệu lực / alt Kỳ hoặc chỉ số không hợp lệ | Yêu cầu điều chỉnh dữ liệu | Điều kiện triển khai: alt Hợp đồng ACTIVE. |
| 11 | Biểu mẫu hóa đơn → Chủ trọ | alt Hợp đồng có hiệu lực / alt Kỳ hoặc chỉ số không hợp lệ | Hiển thị lỗi | Điều kiện triển khai: alt Hợp đồng ACTIVE. |

### SD-06B Tính tiền và lập hóa đơn

![SD-06B Tính tiền và lập hóa đơn](sequence-diagrams/full/sd-06b-invoice-persistence.png)

[SVG vector](sequence-diagrams/full/sd-06b-invoice-persistence.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-06b-invoice-persistence.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | BillingService → Cơ sở dữ liệu | Luồng chung | Bắt đầu ghi nhận nghiệp vụ | BEGIN transaction |
| 2 | BillingService → Cơ sở dữ liệu | loop Với mỗi loại chỉ số điện hoặc nước được gửi | Lưu chỉ số điện hoặc nước | Tạo MeterReading. usage = currentReading - previousReading; amount = usage × unitPrice. Danh sách rỗng bỏ qua vòng lặp. Điều kiện triển khai: loop Mỗi chỉ số mới trong meterReadings từ 0 đến 2 loại. |
| 3 | Cơ sở dữ liệu → BillingService | loop Với mỗi loại chỉ số điện hoặc nước được gửi / break Chỉ số của phòng và kỳ đã được ghi | Dữ liệu trùng; hủy thay đổi | P2002; ROLLBACK Điều kiện triển khai: loop Mỗi chỉ số mới trong meterReadings từ 0 đến 2 loại / break INSERT MeterReading vi phạm duy nhất. |
| 4 | BillingService → BillingController | loop Với mỗi loại chỉ số điện hoặc nước được gửi / break Chỉ số của phòng và kỳ đã được ghi | Chỉ số trong kỳ đã được ghi | METER_READING_EXISTS Điều kiện triển khai: loop Mỗi chỉ số mới trong meterReadings từ 0 đến 2 loại / break INSERT MeterReading vi phạm duy nhất. |
| 5 | BillingController → Biểu mẫu hóa đơn | loop Với mỗi loại chỉ số điện hoặc nước được gửi / break Chỉ số của phòng và kỳ đã được ghi | Từ chối chỉ số trùng | Điều kiện triển khai: loop Mỗi chỉ số mới trong meterReadings từ 0 đến 2 loại / break INSERT MeterReading vi phạm duy nhất. |
| 6 | BillingService → Cơ sở dữ liệu | Luồng chung | Đọc chỉ số phòng trong kỳ | Không cần bổ sung |
| 7 | Cơ sở dữ liệu → BillingService | Luồng chung | Các chỉ số điện nước trong kỳ | Không cần bổ sung |
| 8 | BillingService → Cơ sở dữ liệu | Luồng chung | Tra cứu phí dịch vụ áp dụng | Đọc phí dịch vụ active |
| 9 | Cơ sở dữ liệu → BillingService | Luồng chung | Danh sách phí cố định | Không cần bổ sung |
| 10 | BillingService → BillingService | Luồng chung | Tính tổng tiền và ghi chú | Tính tổng tiền và ghi chú. total = monthlyRent + electricity + water + input.otherAmount + tổng phí cố định; không đổi dữ liệu hợp đồng. |
| 11 | BillingService → Cơ sở dữ liệu | Luồng chung | Lưu hóa đơn chưa thanh toán | Tạo Invoice UNPAID |
| 12 | Cơ sở dữ liệu → BillingService | alt Hợp đồng đã có hóa đơn trong kỳ | Dữ liệu trùng; hủy thay đổi | P2002; ROLLBACK Điều kiện triển khai: alt INSERT Invoice vi phạm duy nhất. |
| 13 | BillingService → BillingController | alt Hợp đồng đã có hóa đơn trong kỳ | Hóa đơn trong kỳ đã tồn tại | INVOICE_EXISTS. METER_READING_EXISTS khi target là roomId, utilityType, billingMonth; trường hợp còn lại INVOICE_EXISTS. Điều kiện triển khai: alt INSERT Invoice vi phạm duy nhất. |
| 14 | BillingController → Biểu mẫu hóa đơn | alt Hợp đồng đã có hóa đơn trong kỳ | Không tạo dữ liệu trùng | Điều kiện triển khai: alt INSERT Invoice vi phạm duy nhất. |
| 15 | Biểu mẫu hóa đơn → Chủ trọ | alt Hợp đồng đã có hóa đơn trong kỳ | Thông báo dữ liệu đã tồn tại | Điều kiện triển khai: alt INSERT Invoice vi phạm duy nhất. |
| 16 | Cơ sở dữ liệu → BillingService | alt Ghi nhận dữ liệu thành công | Hóa đơn đã được lưu đầy đủ | COMMIT và Invoice |
| 17 | BillingService → BillingController | alt Ghi nhận dữ liệu thành công | Hóa đơn đã tạo | Không cần bổ sung |
| 18 | BillingController → Biểu mẫu hóa đơn | alt Ghi nhận dữ liệu thành công | Hóa đơn mới | Không cần bổ sung |
| 19 | Biểu mẫu hóa đơn → Chủ trọ | alt Ghi nhận dữ liệu thành công | Hiển thị số phải thu | Không cần bổ sung |

### Đối chiếu đặc tả Use Case

**UC-BIL-02.01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn lập hóa đơn cho một hợp đồng và xác định kỳ tính.<br><br>**2.** Hệ thống: Hiển thị hợp đồng, tiền thuê, kỳ tính và các trường chỉ số điện, nước, đơn giá, khoản khác, hạn thanh toán, ghi chú.<br><br>**3.** Chủ trọ: Kiểm tra thông tin; nhập các chỉ số và khoản bổ sung nếu có, xác định hạn thanh toán và xác nhận lập hóa đơn.<br><br>**4.** Hệ thống: Kiểm tra hợp đồng còn hiệu lực, kỳ tính thuộc thời gian thuê, chưa có hóa đơn cùng hợp đồng và kỳ, dữ liệu được nhập hợp lệ.<br><br>**5.** Hệ thống: Ghi các chỉ số được bổ sung; lấy chỉ số đã có trong kỳ và các phí dịch vụ đang áp dụng của phòng.<br><br>**6.** Hệ thống: Tính tiền thuê, điện, nước, phí dịch vụ và khoản khác; tạo hóa đơn và cung cấp kết quả. Trường hợp thiếu chỉ số hoặc tổng tiền bằng 0 xem [PX-16](#px-16), [PX-17](#px-17). |
| **Luồng thay thế** | **A1 — Tại bước 3:** Không gửi chỉ số mới. Dùng chỉ số đã có cùng phòng/kỳ; thành phần chưa có dữ liệu được tính theo xử lý hiện tại, không bắt buộc đủ cả hai loại. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Hợp đồng không hiệu lực, kỳ ngoài thời gian thuê hoặc dữ liệu sai. Từ chối lập. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E2 — Tại bước 5:** Chỉ số gửi mới trùng dữ liệu đã có. Từ chối do chỉ số trùng; không tạo hóa đơn từ giao dịch này. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E3 — Tại bước 6:** Đã có hóa đơn cùng hợp đồng/kỳ. Từ chối tạo trùng. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | leaseId, billingMonth, dueDate, otherAmount, note; tối đa hai bộ chỉ số điện nước. |
| Kết quả ghi nhận | Tạo Invoice UNPAID với tổng tiền thuê, điện, nước và phí; chỉ số mới được ghi trong cùng giao dịch. |
| Lưu ý triển khai | Không có chỉ số mới thì dùng bản ghi đã có cùng phòng và tháng. Thiếu loại nào thì amountFor cho loại đó bằng 0; PX-16 cần xác nhận. |
| Lưu ý triển khai | Không truy vấn trước để kiểm tra hóa đơn trùng; dựa vào ràng buộc UNIQUE của Invoice và MeterReading. |
| Lưu ý triển khai | Phí dịch vụ cố định đang active được cộng vào otherAmount và ghi tóm tắt vào note. Hóa đơn tổng 0 vẫn tạo UNPAID theo hiện trạng PX-17. |
| Tham chiếu Kiểm tra quyền quản lý và dữ liệu đầu vào | Guards và DTO Quyền Chủ trọ dữ liệu hợp lệ |
| Thành phần BillingController | src/billing/billing.controller.ts |
| Thành phần BillingService | src/billing/billing.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Ghi nhật ký lập hóa đơn | AuditService.recordSafe billing.invoice_create |
| Căn cứ kiểm chứng | Backend src/billing/billing.service.ts createInvoice tại dòng 279 |
| Căn cứ kiểm chứng | Backend src/billing/dto/create-invoice.dto.ts CreateInvoiceDto tại dòng 32 |
| Căn cứ kiểm chứng | Flutter lib/features/billing/billing_providers.dart Tệp giao diện liên quan đối chiếu ở mức tệp |

## SD-07 Ghi nhận thanh toán hóa đơn

**Điều kiện trước:** Chủ trọ chọn hóa đơn còn phải thu và xác nhận khoản thanh toán.

**Dữ liệu đầu vào:** Hóa đơn được chọn, số tiền thanh toán nguyên dương, phương thức, thời điểm thanh toán tùy chọn và ghi chú.

**Điều kiện sau khi thành công:** Ghi nhận khoản thanh toán, tăng số tiền đã thu và chuyển hóa đơn sang Thanh toán một phần hoặc Đã thanh toán.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Kiểm tra số còn phải thu trước khi ghi nhận khoản thanh toán; cơ chế phối hợp khi thao tác đồng thời được giải thích ở bảng triển khai.
- Phương thức thanh toán chỉ mô tả khoản thu đã được ghi nhận; luồng này không thực hiện chuyển tiền qua cổng thanh toán.
- Khoản thu vượt số còn phải thu bị từ chối; không tự ghi số dư âm hoặc tiền thừa.

### SD-07A Kiểm tra hóa đơn và khoản thanh toán

![SD-07A Kiểm tra hóa đơn và khoản thanh toán](sequence-diagrams/full/sd-07a-payment-checks.png)

[SVG vector](sequence-diagrams/full/sd-07a-payment-checks.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-07a-payment-checks.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình chi tiết hóa đơn | Luồng chung | Xác nhận khoản thu | Không cần bổ sung |
| 2 | Màn hình chi tiết hóa đơn → BillingController | Luồng chung | Gửi thông tin khoản thanh toán | POST …/:id/payments. Đường đầy đủ là /billing/invoices/:id/payments; amount phải >= 1 theo DTO. |
| 3 | BillingController → BillingService | Luồng chung | Yêu cầu ghi nhận thanh toán | recordPayment(input) |
| 4 | BillingService → BillingService | Luồng chung | Xác định thời điểm thanh toán | Chuẩn hóa paidAt |
| 5 | BillingService → Cơ sở dữ liệu | Luồng chung | Tra cứu hóa đơn và số dư | BEGIN; khóa Invoice. lockOwnedInvoice: SELECT đúng hóa đơn thuộc Chủ trọ FOR UPDATE OF i rồi đọc bản ghi. |
| 6 | Cơ sở dữ liệu → BillingService | Luồng chung | Hóa đơn thuộc phạm vi quản lý | Invoice thuộc quyền |
| 7 | BillingService → Cơ sở dữ liệu | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc khoản thu vượt số còn phải thu | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Thiếu hóa đơn, CANCELLED, đã đủ tiền hoặc amount > remaining. |
| 8 | BillingService → BillingController | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc khoản thu vượt số còn phải thu | Lỗi hóa đơn hoặc số dư | Lỗi hóa đơn hoặc số dư. INVOICE_NOT_FOUND, INVOICE_CANCELLED, INVOICE_ALREADY_PAID hoặc PAYMENT_EXCEEDS_REMAINING tùy điều kiện đầu tiên thất bại. Điều kiện triển khai: alt Thiếu hóa đơn, CANCELLED, đã đủ tiền hoặc amount > remaining. |
| 9 | BillingController → Màn hình chi tiết hóa đơn | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc khoản thu vượt số còn phải thu | Khoản thu bị từ chối | Điều kiện triển khai: alt Thiếu hóa đơn, CANCELLED, đã đủ tiền hoặc amount > remaining. |
| 10 | Màn hình chi tiết hóa đơn → Chủ trọ | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc khoản thu vượt số còn phải thu | Hiển thị lỗi | Điều kiện triển khai: alt Thiếu hóa đơn, CANCELLED, đã đủ tiền hoặc amount > remaining. |

### SD-07B Ghi nhận thanh toán và cập nhật số phải thu

![SD-07B Ghi nhận thanh toán và cập nhật số phải thu](sequence-diagrams/full/sd-07b-payment-status.png)

[SVG vector](sequence-diagrams/full/sd-07b-payment-status.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-07b-payment-status.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | BillingService → Cơ sở dữ liệu | Luồng chung | Ghi nhận khoản thanh toán | Tạo Payment PAYMENT |
| 2 | Cơ sở dữ liệu → BillingService | Luồng chung | Khoản thanh toán đã ghi nhận | Payment đã ghi |
| 3 | BillingService → BillingService | Luồng chung | Cập nhật tổng tiền đã thanh toán | Cộng paidAmount mới |
| 4 | BillingService → Cơ sở dữ liệu | alt Tổng tiền đã thanh toán < Tổng tiền hóa đơn | Ghi nhận thanh toán một phần | Invoice = PARTIAL. Cập nhật paidAmount mới; số còn phải thu = totalAmount - paidAmount mới. Điều kiện triển khai: alt paidAmount mới < totalAmount. |
| 5 | BillingService → Cơ sở dữ liệu | alt Tổng tiền đã thanh toán = Tổng tiền hóa đơn | Ghi nhận đã thanh toán đủ; số còn phải thu bằng 0. | Invoice = PAID. Ghi nhận đã thanh toán đủ; số còn phải thu bằng 0. Điều kiện triển khai: alt paidAmount mới = totalAmount. |
| 6 | BillingService → Cơ sở dữ liệu | Luồng chung | Xác nhận lưu toàn bộ dữ liệu | COMMIT |
| 7 | BillingService → BillingController | Luồng chung | Hóa đơn và khoản thanh toán | Invoice và Payment |
| 8 | BillingController → Màn hình chi tiết hóa đơn | Luồng chung | Kết quả thu tiền | Không cần bổ sung |
| 9 | Màn hình chi tiết hóa đơn → Chủ trọ | Luồng chung | Hiển thị số dư mới | Không cần bổ sung |

### Đối chiếu đặc tả Use Case

**UC-BIL-03.01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn ghi nhận khoản thanh toán trên hóa đơn.<br><br>**2.** Hệ thống: Hiển thị tổng tiền, tiền đã thu, số còn phải thu và các trường số tiền, phương thức, ngày thanh toán, ghi chú.<br><br>**3.** Chủ trọ: Nhập khoản tiền đã nhận, phương thức và ngày nhận; bổ sung ghi chú nếu có và xác nhận.<br><br>**4.** Hệ thống: Kiểm tra hóa đơn chưa hủy, còn phải thu; số tiền là số nguyên dương và không vượt số còn phải thu.<br><br>**5.** Hệ thống: Ghi khoản thanh toán, tăng tiền đã thu và tính lại trạng thái hóa đơn đồng bộ.<br><br>**6.** Hệ thống: Hiển thị khoản thanh toán mới cùng số dư và trạng thái hóa đơn. |
| **Luồng thay thế** | **A1 — Tại bước 3:** Chủ trọ nhập số tiền nhỏ hơn số còn phải thu. Tiếp tục bước 4 để kiểm tra hóa đơn và số tiền. Nếu hợp lệ, tại bước 5 hệ thống ghi khoản thanh toán và chuyển hóa đơn sang Thanh toán một phần; hiển thị khoản thu và số dư mới tại bước 6. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Hóa đơn đã hủy/đã thu đủ hoặc số tiền vượt số dư. Từ chối ghi thu. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E2 — Tại bước 4:** Số tiền không phải số nguyên dương. Từ chối dữ liệu. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | invoiceId, amount nguyên dương, method, paidAt tùy chọn, note. |
| Kết quả ghi nhận | Tạo Payment PAYMENT; paidAmount tăng đúng khoản thu và Invoice chuyển PARTIAL hoặc PAID. |
| Lưu ý triển khai | Khóa hàng Invoice bằng FOR UPDATE trong transaction để kiểm tra số dư trước khi ghi tiền. |
| Tham chiếu SD-07B Tiếp tục ghi nhận cùng khoản thanh toán | SD-07B Tiếp tục cùng transaction |
| Thành phần BillingController | src/billing/billing.controller.ts |
| Thành phần BillingService | src/billing/billing.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Ghi nhật ký ghi nhận thanh toán | AuditService.recordSafe billing.payment_record |
| Căn cứ kiểm chứng | Backend src/billing/billing.service.ts recordPayment tại dòng 967 |
| Căn cứ kiểm chứng | Backend src/billing/billing.service.ts lockOwnedInvoice tại dòng 1531 |
| Căn cứ kiểm chứng | Backend src/billing/billing.service.ts invoiceStatusForBalance tại dòng 1791 |
| Căn cứ kiểm chứng | Flutter lib/features/billing/invoice_detail_screen.dart Tệp giao diện liên quan đối chiếu ở mức tệp |

## SD-08 Gửi và xét duyệt minh chứng thanh toán

**Điều kiện trước:** Người thuê có hồ sơ đang sử dụng và hóa đơn của mình; Chủ trọ chỉ xét minh chứng Chờ duyệt thuộc phạm vi quản lý.

**Dữ liệu đầu vào:** Tệp minh chứng, số tiền, phương thức, ghi chú; minh chứng được chọn, quyết định chấp thuận hoặc từ chối và ghi chú xét duyệt.

**Điều kiện sau khi thành công:** Gửi minh chứng chỉ tạo trạng thái Chờ duyệt, chưa ghi nhận tiền đã thu. Chấp thuận tạo khoản thanh toán và cập nhật hóa đơn; từ chối không thay đổi khoản thu.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Biểu mẫu yêu cầu ít nhất một tệp, nhưng xử lý tiếp nhận hiện chưa bắt buộc tương ứng; PX-25 cần chốt thống nhất.
- Tải tệp là thao tác riêng. Khi gửi minh chứng, hệ thống tiếp nhận thông tin và đường dẫn đến các tệp đã tải.
- Minh chứng chờ duyệt làm giảm hạn mức được phép gửi thêm, nhưng chưa được tính vào số tiền đã thanh toán.
- PX-21: việc kiểm tra trạng thái Chờ duyệt chưa đủ để khẳng định đã chống mọi trường hợp duyệt đồng thời cùng một minh chứng.

### SD-08A Tải tệp và chuẩn bị minh chứng

![SD-08A Tải tệp và chuẩn bị minh chứng](sequence-diagrams/full/sd-08a-proof-upload.png)

[SVG vector](sequence-diagrams/full/sd-08a-proof-upload.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-08a-proof-upload.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Người thuê → Biểu mẫu minh chứng | Luồng chung | Chọn ảnh hoặc PDF | Không cần bổ sung |
| 2 | Biểu mẫu minh chứng → UploadsController | loop Mỗi tệp do người thuê chọn | Gửi tệp minh chứng | POST /uploads multipart |
| 3 | UploadsController → Biểu mẫu minh chứng | loop Mỗi tệp do người thuê chọn / alt Không có tệp, loại tệp không được hỗ trợ hoặc tệp vượt giới hạn dung lượng | Lỗi tải tệp | Lỗi tải tệp. API giới hạn 8 MiB; chấp nhận JPEG, PNG, WebP, HEIC, HEIF và PDF; không thêm URL tệp lỗi. |
| 4 | UploadsController → Kho tệp | loop Mỗi tệp do người thuê chọn / alt Tệp hợp lệ | Lưu tệp tên ngẫu nhiên | Không cần bổ sung |
| 5 | Kho tệp → UploadsController | loop Mỗi tệp do người thuê chọn / alt Tệp hợp lệ | Tệp đã lưu | Không cần bổ sung |
| 6 | UploadsController → Biểu mẫu minh chứng | loop Mỗi tệp do người thuê chọn / alt Tệp hợp lệ | Đường dẫn truy cập tệp | URL của tệp |
| 7 | Biểu mẫu minh chứng → Biểu mẫu minh chứng | loop Mỗi tệp do người thuê chọn / alt Tệp hợp lệ | Đính kèm đường dẫn tệp | Thêm URL vào biểu mẫu |
| 8 | Người thuê → Biểu mẫu minh chứng | Luồng chung | Nhập số tiền và gửi | Không cần bổ sung |
| 9 | Biểu mẫu minh chứng → Người thuê | alt Số tiền không hợp lệ hoặc chưa đính kèm tệp | Yêu cầu bổ sung | Điều kiện triển khai: alt amount <= 0 hoặc chưa có tệp trên UI. |

### SD-08B Gửi minh chứng chờ xét duyệt

![SD-08B Gửi minh chứng chờ xét duyệt](sequence-diagrams/full/sd-08b-submit-proof.png)

[SVG vector](sequence-diagrams/full/sd-08b-submit-proof.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-08b-submit-proof.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Biểu mẫu minh chứng → TenantPortalController | Luồng chung | Gửi thông tin minh chứng | POST …/payment-proofs. Đường đầy đủ /tenant/invoices/:id/payment-proofs; body gửi amount, method, note và proofImageUrls. |
| 2 | TenantPortalController → TenantPortalService | Luồng chung | Yêu cầu ghi nhận minh chứng | submitPaymentProof(input) |
| 3 | TenantPortalService → Cơ sở dữ liệu | Luồng chung | Tra cứu hồ sơ đang sử dụng | Đọc Tenant active. tenantProfile tìm theo userId; không có hồ sơ active thì TENANT_PROFILE_NOT_FOUND. |
| 4 | Cơ sở dữ liệu → TenantPortalService | Luồng chung | Hồ sơ Người thuê | Không cần bổ sung |
| 5 | TenantPortalService → TenantPortalController | break Không có hồ sơ Người thuê đang dùng | Không có hồ sơ người thuê | Không có hồ sơ Tenant. TENANT_PROFILE_NOT_FOUND |
| 6 | TenantPortalController → Biểu mẫu minh chứng | break Không có hồ sơ Người thuê đang dùng | Từ chối gửi minh chứng | Không cần bổ sung |
| 7 | TenantPortalService → Cơ sở dữ liệu | Luồng chung | Tra cứu hóa đơn và số dư | BEGIN; khóa Invoice. SELECT Invoice có tenantId đúng hồ sơ FOR UPDATE OF i; đọc lại trạng thái và số dư. |
| 8 | Cơ sở dữ liệu → TenantPortalService | Luồng chung | Hóa đơn và số còn phải thu | Invoice và remaining |
| 9 | TenantPortalService → Cơ sở dữ liệu | alt Hóa đơn không thuộc người thuê, đã hủy hoặc không còn số phải thu | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Không đúng hóa đơn, CANCELLED hoặc remaining <= 0. |
| 10 | TenantPortalService → TenantPortalController | alt Hóa đơn không thuộc người thuê, đã hủy hoặc không còn số phải thu | Lỗi hóa đơn | Điều kiện triển khai: alt Không đúng hóa đơn, CANCELLED hoặc remaining <= 0. |
| 11 | TenantPortalController → Biểu mẫu minh chứng | alt Hóa đơn không thuộc người thuê, đã hủy hoặc không còn số phải thu | Từ chối minh chứng | Điều kiện triển khai: alt Không đúng hóa đơn, CANCELLED hoặc remaining <= 0. |
| 12 | TenantPortalService → Cơ sở dữ liệu | alt Hóa đơn còn số phải thu | Tính tổng minh chứng chờ duyệt | Tổng amount PENDING |
| 13 | Cơ sở dữ liệu → TenantPortalService | alt Hóa đơn còn số phải thu | Tổng tiền minh chứng chờ duyệt | pendingAmount |
| 14 | TenantPortalService → Cơ sở dữ liệu | alt Hóa đơn còn số phải thu / alt Số tiền minh chứng vượt số còn phải thu sau khi trừ phần chờ duyệt | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt amount > remaining - pendingAmount. |
| 15 | TenantPortalService → TenantPortalController | alt Hóa đơn còn số phải thu / alt Số tiền minh chứng vượt số còn phải thu sau khi trừ phần chờ duyệt | Minh chứng vượt hạn mức gửi | PROOF_EXCEEDS_REMAINING. Mã đầy đủ PAYMENT_PROOF_EXCEEDS_REMAINING; chưa tạo thêm minh chứng. Điều kiện triển khai: alt amount > remaining - pendingAmount. |
| 16 | TenantPortalController → Biểu mẫu minh chứng | alt Hóa đơn còn số phải thu / alt Số tiền minh chứng vượt số còn phải thu sau khi trừ phần chờ duyệt | Vượt hạn mức gửi | Điều kiện triển khai: alt amount > remaining - pendingAmount. |
| 17 | TenantPortalService → Cơ sở dữ liệu | alt Hóa đơn còn số phải thu / alt Số tiền trong hạn mức | Lưu minh chứng chờ duyệt | Tạo PaymentProof PENDING |
| 18 | Cơ sở dữ liệu → TenantPortalService | alt Hóa đơn còn số phải thu / alt Số tiền trong hạn mức | Minh chứng đã được lưu | COMMIT và minh chứng |
| 19 | TenantPortalService → TenantPortalController | alt Hóa đơn còn số phải thu / alt Số tiền trong hạn mức | Minh chứng đã gửi | Không cần bổ sung |
| 20 | TenantPortalController → Biểu mẫu minh chứng | alt Hóa đơn còn số phải thu / alt Số tiền trong hạn mức | Đang chờ Chủ trọ duyệt | Không cần bổ sung |
| 21 | Biểu mẫu minh chứng → Người thuê | alt Hóa đơn còn số phải thu / alt Số tiền trong hạn mức | Hiển thị trạng thái chờ | Không cần bổ sung |

### SD-08C Chấp thuận hoặc từ chối minh chứng

![SD-08C Chấp thuận hoặc từ chối minh chứng](sequence-diagrams/full/sd-08c-review-proof.png)

[SVG vector](sequence-diagrams/full/sd-08c-review-proof.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-08c-review-proof.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình duyệt minh chứng | Luồng chung | Chọn duyệt hoặc từ chối | Không cần bổ sung |
| 2 | Màn hình duyệt minh chứng → BillingController | Luồng chung | Gửi quyết định xét duyệt | POST …/:id/review. Đường đầy đủ /billing/payment-proofs/:id/review; quyết định không được PENDING. |
| 3 | BillingController → BillingService | Luồng chung | Yêu cầu xét duyệt minh chứng | reviewPaymentProof() |
| 4 | BillingService → Cơ sở dữ liệu | Luồng chung | Tra cứu minh chứng thuộc quản lý | BEGIN; đọc Proof sở hữu |
| 5 | Cơ sở dữ liệu → BillingService | Luồng chung | Minh chứng và trạng thái duyệt | Proof và trạng thái |
| 6 | BillingService → Cơ sở dữ liệu | alt Không tìm thấy minh chứng hoặc minh chứng đã được xét duyệt | Hủy các thay đổi chưa lưu | ROLLBACK Điều kiện triển khai: alt Không có Proof hoặc đã xét duyệt. |
| 7 | BillingService → BillingController | alt Không tìm thấy minh chứng hoặc minh chứng đã được xét duyệt | Minh chứng không thể xét duyệt | NOT_FOUND / ALREADY_REVIEWED Điều kiện triển khai: alt Không có Proof hoặc đã xét duyệt. |
| 8 | BillingController → Màn hình duyệt minh chứng | alt Không tìm thấy minh chứng hoặc minh chứng đã được xét duyệt | Không xét duyệt lại | Điều kiện triển khai: alt Không có Proof hoặc đã xét duyệt. |
| 9 | BillingService → BillingService | alt Minh chứng đang chờ duyệt / alt Chủ trọ chọn từ chối | Không ghi nhận khoản thanh toán | Không tạo Payment. Không khóa kiểm tra số dư dành riêng cho nhánh approve; paidAmount giữ nguyên. Điều kiện triển khai: alt Proof còn PENDING / alt decision = REJECTED. |
| 10 | BillingService → Cơ sở dữ liệu | alt Minh chứng đang chờ duyệt | Lưu kết quả xét duyệt minh chứng | Cập nhật Proof quyết định. Ghi status, reviewedAt, reviewedById và reviewNote; chỉ tới bước này nếu SD-08D thành công hoặc đã chọn reject. Điều kiện triển khai: alt Proof còn PENDING. |
| 11 | Cơ sở dữ liệu → BillingService | alt Minh chứng đang chờ duyệt | Kết quả xét duyệt đã được lưu | COMMIT và Proof Điều kiện triển khai: alt Proof còn PENDING. |
| 12 | BillingService → BillingController | alt Minh chứng đang chờ duyệt | Kết quả xét duyệt | Điều kiện triển khai: alt Proof còn PENDING. |
| 13 | BillingController → Màn hình duyệt minh chứng | alt Minh chứng đang chờ duyệt | Minh chứng sau xét duyệt | Proof sau xét duyệt Điều kiện triển khai: alt Proof còn PENDING. |
| 14 | Màn hình duyệt minh chứng → Chủ trọ | alt Minh chứng đang chờ duyệt | Hiển thị quyết định | Điều kiện triển khai: alt Proof còn PENDING. |

### SD-08D Kiểm tra số dư khi chấp thuận minh chứng

![SD-08D Kiểm tra số dư khi chấp thuận minh chứng](sequence-diagrams/full/sd-08d-approve-proof.png)

[SVG vector](sequence-diagrams/full/sd-08d-approve-proof.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-08d-approve-proof.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | BillingService → Cơ sở dữ liệu | Luồng chung | Tra cứu hóa đơn thuộc quản lý | Khóa Invoice sở hữu. Tiếp nối APPROVED trong SD-08C; cùng transaction, không mở giao dịch thứ hai. |
| 2 | Cơ sở dữ liệu → BillingService | Luồng chung | Hóa đơn và số còn phải thu | Invoice và số dư |
| 3 | BillingService → Cơ sở dữ liệu | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu / break Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu | Hủy toàn bộ thay đổi chưa lưu | ROLLBACK toàn giao dịch Điều kiện triển khai: alt Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining / break Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining. |
| 4 | BillingService → BillingController | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu / break Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu | Lỗi hóa đơn hoặc số dư | Điều kiện triển khai: alt Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining / break Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining. |
| 5 | BillingController → Màn hình duyệt minh chứng | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu / break Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu | Duyệt bị từ chối | Điều kiện triển khai: alt Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining / break Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining. |
| 6 | Màn hình duyệt minh chứng → Chủ trọ | alt Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu / break Không tìm thấy hóa đơn, hóa đơn đã hủy, đã thanh toán đủ hoặc minh chứng vượt số còn phải thu | Hiển thị lỗi xét duyệt | Điều kiện triển khai: alt Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining / break Invoice thiếu CANCELLED đã đủ tiền hoặc proof.amount > remaining. |
| 7 | BillingService → Cơ sở dữ liệu | alt Hóa đơn cho phép thu | Ghi nhận thanh toán từ minh chứng | Tạo Payment từ Proof. type PAYMENT; amount và method lấy từ Proof; paidAt hiện tại; note ưu tiên ghi chú xét duyệt. |
| 8 | BillingService → BillingService | alt Hóa đơn cho phép thu | Tính tổng tiền đã thanh toán | Tính paidAmount mới |
| 9 | BillingService → Cơ sở dữ liệu | alt Hóa đơn cho phép thu / alt Tổng tiền đã thanh toán < Tổng tiền hóa đơn | Ghi nhận thanh toán một phần | Invoice = PARTIAL Điều kiện triển khai: alt Thu chưa đủ totalAmount. |
| 10 | BillingService → Cơ sở dữ liệu | alt Hóa đơn cho phép thu / alt Tổng tiền đã thanh toán = Tổng tiền hóa đơn | Ghi nhận đã thanh toán đủ | Invoice = PAID Điều kiện triển khai: alt Thu đủ totalAmount. |

### Đối chiếu đặc tả Use Case

**UC-TEN-04**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Người thuê: Mở hóa đơn còn phải thanh toán và chọn gửi minh chứng.<br><br>**2.** Hệ thống: Hiển thị các trường số tiền, phương thức, ghi chú và lựa chọn tải tệp minh chứng.<br><br>**3.** Người thuê: Nhập số tiền, phương thức; bổ sung ghi chú, tải tệp theo yêu cầu của biểu mẫu và xác nhận gửi. Chính sách bắt buộc tệp xem [PX-25](#px-25).<br><br>**4.** Hệ thống: Kiểm tra dữ liệu và xác nhận hóa đơn thuộc hồ sơ, chưa hủy, còn phải thu.<br><br>**5.** Hệ thống: Tính tổng tiền của các minh chứng Chờ duyệt; kiểm tra khoản gửi mới không vượt số còn phải thu sau khi trừ tổng đang chờ.<br><br>**6.** Hệ thống: Ghi minh chứng Chờ duyệt và hiển thị kết quả để Người thuê theo dõi; chưa ghi nhận tiền đã thu. |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 3:** Chưa tải tệp hoặc số tiền nhập không hợp lệ trên biểu mẫu. Không gửi yêu cầu; yêu cầu bổ sung. Sau khi điều chỉnh, thực hiện lại từ bước 3.<br><br>**E2 — Tại bước 4:** Hóa đơn không thuộc hồ sơ, đã hủy hoặc đã thu đủ. Từ chối gửi chứng từ. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E3 — Tại bước 5:** Số tiền vượt phần số dư chưa được các minh chứng Chờ duyệt giữ chỗ. Từ chối tạo chứng từ. UC kết thúc đối với yêu cầu bị từ chối. |

**UC-BIL-04**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Mở minh chứng thanh toán đang Chờ duyệt.<br><br>**2.** Hệ thống: Hiển thị số tiền, phương thức, tệp minh chứng và ghi chú của Người thuê.<br><br>**3.** Chủ trọ: Đối soát thông tin đã nhận, chọn duyệt và xác nhận quyết định.<br><br>**4.** Hệ thống: Kiểm tra minh chứng tồn tại trong phạm vi quản lý và còn Chờ duyệt. Với quyết định duyệt, kiểm tra thêm hóa đơn chưa hủy, còn phải thu và số tiền minh chứng không vượt số còn phải thu.<br><br>**5.** Hệ thống: Ghi khoản thanh toán từ minh chứng, cập nhật hóa đơn và đánh dấu minh chứng Đã duyệt đồng bộ.<br><br>**6.** Hệ thống: Hiển thị quyết định duyệt, khoản thanh toán và số còn phải thu mới. |
| **Luồng thay thế** | **A1 — Tại bước 3:** Chủ trọ chọn từ chối minh chứng, bổ sung ghi chú nếu có và xác nhận. Tại bước 4, hệ thống kiểm tra minh chứng thuộc phạm vi quản lý và còn Chờ duyệt; không áp dụng điều kiện số dư hóa đơn dành riêng cho nhánh duyệt. Nếu hợp lệ, tại bước 5 ghi kết quả Đã từ chối, người duyệt, thời điểm và ghi chú; không tạo khoản thanh toán và không thay đổi số tiền đã thu. Tại bước 6, hiển thị quyết định từ chối; UC kết thúc thành công ở nhánh từ chối. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Minh chứng không tồn tại hoặc đã có kết quả. Từ chối xử lý lại. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E2 — Tại bước 4:** Duyệt cho hóa đơn đã hủy/đã thu đủ hoặc số tiền vượt số dư. Từ chối duyệt; chưa tạo khoản thu từ yêu cầu này. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | Tệp minh chứng, amount, method, note; proofId, quyết định approve hoặc reject và ghi chú xét duyệt. |
| Kết quả ghi nhận | Gửi tạo PENDING và chưa thu tiền. Approve tạo Payment và cập nhật Invoice; reject không thay đổi khoản thu. |
| Lưu ý triển khai | UI bắt buộc ít nhất một tệp, nhưng DTO proofImageUrls vẫn optional; PX-25 cần chốt thống nhất. |
| Lưu ý triển khai | Upload là request riêng POST /uploads; endpoint payment-proofs chỉ nhận URL, không nhận tệp multipart. |
| Lưu ý triển khai | Minh chứng đang chờ giữ phần hạn mức gửi, không cộng vào paidAmount. Khả dụng = remaining - tổng amount PENDING. |
| Lưu ý triển khai | PX-21: review kiểm tra proof PENDING nhưng chưa khóa proof trước kiểm tra. Không tuyên bố đã chống mọi cuộc đua duyệt cùng minh chứng. |
| Tham chiếu SD-08B Gửi thông tin và đường dẫn tệp minh chứng | SD-08B Gửi danh sách URL cho API nghiệp vụ |
| Thành phần UploadsController | src/uploads/uploads.controller.ts |
| Thành phần TenantPortalController | src/tenant-portal/tenant-portal.controller.ts |
| Thành phần TenantPortalService | src/tenant-portal/tenant-portal.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Ghi nhật ký xét duyệt minh chứng | AuditService.recordSafe billing.payment_proof_review |
| Thành phần BillingController | src/billing/billing.controller.ts |
| Thành phần BillingService | src/billing/billing.service.ts |
| Tham chiếu Trở về SD-08C Lưu kết quả chấp thuận minh chứng | Trở về SD-08C Ghi Proof APPROVED rồi commit |
| Căn cứ kiểm chứng | Backend src/tenant-portal/tenant-portal.service.ts submitPaymentProof tại dòng 402 |
| Căn cứ kiểm chứng | Backend src/billing/billing.service.ts reviewPaymentProof tại dòng 1057 |
| Căn cứ kiểm chứng | Backend src/uploads/uploads.controller.ts upload tại dòng 62 |
| Căn cứ kiểm chứng | Flutter lib/features/tenant_portal/tenant_invoice_detail_screen.dart _pickAndUploadFile tại dòng 389 |

## SD-09 Gửi xử lý và hoàn tất bảo trì

**Điều kiện trước:** Người thuê có hồ sơ đang sử dụng và hợp đồng có hiệu lực; Chủ trọ chỉ xử lý yêu cầu thuộc phạm vi quản lý.

**Dữ liệu đầu vào:** Tiêu đề, mô tả, ảnh và mức ưu tiên; yêu cầu bảo trì, trạng thái; chi phí thực tế, ngày hoàn tất, lựa chọn ghi khoản chi và ghi chú.

**Điều kiện sau khi thành công:** Tạo yêu cầu bảo trì Chờ xử lý; cập nhật tiến độ và các mốc phù hợp. Hoàn tất chuyển sang Hoàn tất và có thể liên kết khoản chi sửa chữa.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Ảnh được tải theo luồng SD-08A, nhưng yêu cầu bảo trì có thể không kèm ảnh. Mức ưu tiên mặc định là Trung bình.
- Hiện trạng chọn hợp đồng có hiệu lực đầu tiên theo ngày bắt đầu giảm dần; chưa cho chọn phòng khi có nhiều hợp đồng. PX-27 cần xác nhận.
- PX-13: chưa có quy tắc hạn chế mọi chuyển trạng thái. Hủy không tự ghi ngày hoàn tất; chuyển sang Hoàn tất chỉ thêm mốc nếu chưa có.
- Chỉ tạo khoản chi khi đã chọn ghi khoản chi, chi phí lớn hơn 0 và chưa có khoản chi liên kết. Hoàn tất lại chưa tự bị từ chối; PX-14 cần chốt.

### SD-09A Người thuê gửi yêu cầu bảo trì

![SD-09A Người thuê gửi yêu cầu bảo trì](sequence-diagrams/full/sd-09a-request-maintenance.png)

[SVG vector](sequence-diagrams/full/sd-09a-request-maintenance.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-09a-request-maintenance.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Người thuê → Biểu mẫu báo sự cố | Luồng chung | Nhập yêu cầu bảo trì | Không cần bổ sung |
| 2 | Biểu mẫu báo sự cố → TenantPortalController | Luồng chung | Gửi yêu cầu bảo trì | POST /tenant/maintenance |
| 3 | TenantPortalController → TenantPortalService | Luồng chung | Yêu cầu ghi nhận sự cố | createMaintenance() |
| 4 | TenantPortalService → Cơ sở dữ liệu | Luồng chung | Tra cứu hồ sơ và hợp đồng | Đọc Tenant và Leases |
| 5 | Cơ sở dữ liệu → TenantPortalService | Luồng chung | Hồ sơ và lịch sử thuê | Tenant active và lịch sử |
| 6 | TenantPortalService → TenantPortalController | break Không có hồ sơ Người thuê đang dùng | Không có hồ sơ người thuê | Không có hồ sơ Tenant. TENANT_PROFILE_NOT_FOUND |
| 7 | TenantPortalController → Biểu mẫu báo sự cố | break Không có hồ sơ Người thuê đang dùng | Từ chối yêu cầu | Không cần bổ sung |
| 8 | TenantPortalService → TenantPortalService | Luồng chung | Xác định hợp đồng đang hiệu lực | Chọn ACTIVE lease đầu |
| 9 | TenantPortalService → TenantPortalController | alt Không có hợp đồng hiệu lực | Chưa có hợp đồng hiệu lực | PROFILE / LEASE_REQUIRED. ACTIVE_LEASE_REQUIRED; không tạo ticket khi hồ sơ chưa có hợp đồng ACTIVE. Điều kiện triển khai: alt Không có ACTIVE lease. |
| 10 | TenantPortalController → Biểu mẫu báo sự cố | alt Không có hợp đồng hiệu lực | Từ chối yêu cầu | Điều kiện triển khai: alt Không có ACTIVE lease. |
| 11 | Biểu mẫu báo sự cố → Người thuê | alt Không có hợp đồng hiệu lực | Hiển thị điều kiện thiếu | Điều kiện triển khai: alt Không có ACTIVE lease. |
| 12 | TenantPortalService → Cơ sở dữ liệu | alt Có hợp đồng hiệu lực | Lưu yêu cầu bảo trì mới | Tạo Ticket OPEN. Lấy landlordId, propertyId, roomId từ hồ sơ và hợp đồng; priority mặc định MEDIUM; lưu mô tả và URL ảnh. Điều kiện triển khai: alt Có hợp đồng ACTIVE. |
| 13 | Cơ sở dữ liệu → TenantPortalService | alt Có hợp đồng hiệu lực | Yêu cầu bảo trì đã được lưu | Ticket đã ghi Điều kiện triển khai: alt Có hợp đồng ACTIVE. |
| 14 | TenantPortalService → TenantPortalController | alt Có hợp đồng hiệu lực | Yêu cầu bảo trì mới | Điều kiện triển khai: alt Có hợp đồng ACTIVE. |
| 15 | TenantPortalController → Biểu mẫu báo sự cố | alt Có hợp đồng hiệu lực | Yêu cầu bảo trì chờ xử lý | Ticket OPEN Điều kiện triển khai: alt Có hợp đồng ACTIVE. |
| 16 | Biểu mẫu báo sự cố → Người thuê | alt Có hợp đồng hiệu lực | Hiển thị đã gửi | Điều kiện triển khai: alt Có hợp đồng ACTIVE. |

### SD-09B Chủ trọ cập nhật tiến độ bảo trì

![SD-09B Chủ trọ cập nhật tiến độ bảo trì](sequence-diagrams/full/sd-09b-process-maintenance.png)

[SVG vector](sequence-diagrams/full/sd-09b-process-maintenance.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-09b-process-maintenance.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình danh sách bảo trì | Luồng chung | Chọn trạng thái xử lý | Không cần bổ sung |
| 2 | Màn hình danh sách bảo trì → MaintenanceController | Luồng chung | Gửi trạng thái xử lý bảo trì | POST /maintenance/:id/status |
| 3 | MaintenanceController → MaintenanceService | Luồng chung | Yêu cầu cập nhật tiến độ | updateStatus(input) |
| 4 | MaintenanceService → Cơ sở dữ liệu | Luồng chung | Tra cứu yêu cầu thuộc quản lý | Tìm Ticket sở hữu |
| 5 | Cơ sở dữ liệu → MaintenanceService | Luồng chung | Kết quả tra cứu yêu cầu | Ticket hoặc không có |
| 6 | MaintenanceService → MaintenanceController | alt Yêu cầu ngoài phạm vi quản lý hoặc trạng thái không hợp lệ | Yêu cầu hoặc trạng thái sai | Lỗi Ticket hoặc status Điều kiện triển khai: alt Không thuộc phạm vi hoặc status không hợp lệ. |
| 7 | MaintenanceController → Màn hình danh sách bảo trì | alt Yêu cầu ngoài phạm vi quản lý hoặc trạng thái không hợp lệ | Từ chối cập nhật | Điều kiện triển khai: alt Không thuộc phạm vi hoặc status không hợp lệ. |
| 8 | MaintenanceService → MaintenanceService | alt Yêu cầu và trạng thái hợp lệ / alt Chuyển sang Đang xử lý và chưa ghi thời điểm bắt đầu | Ghi nhận thời điểm bắt đầu | startedAt = hiện tại Điều kiện triển khai: alt Ticket và status hợp lệ / alt IN_PROGRESS và chưa có startedAt. |
| 9 | MaintenanceService → MaintenanceService | alt Yêu cầu và trạng thái hợp lệ / alt Chuyển sang Hoàn tất và chưa ghi thời điểm hoàn tất | Ghi nhận thời điểm hoàn tất | completedAt = hiện tại Điều kiện triển khai: alt Ticket và status hợp lệ / alt DONE và chưa có completedAt. |
| 10 | MaintenanceService → MaintenanceService | alt Yêu cầu và trạng thái hợp lệ / alt Trạng thái hợp lệ khác hoặc đã có mốc | Giữ nguyên mốc cũ | Giữ nguyên mốc cũ. Bao gồm CANCELLED; hủy không tự đặt completedAt. Điều kiện triển khai: alt Ticket và status hợp lệ. |
| 11 | MaintenanceService → Cơ sở dữ liệu | alt Yêu cầu và trạng thái hợp lệ | Lưu trạng thái xử lý bảo trì | Cập nhật Ticket.status Điều kiện triển khai: alt Ticket và status hợp lệ. |
| 12 | Cơ sở dữ liệu → MaintenanceService | alt Yêu cầu và trạng thái hợp lệ | Yêu cầu sau cập nhật | Ticket sau cập nhật Điều kiện triển khai: alt Ticket và status hợp lệ. |
| 13 | MaintenanceService → MaintenanceController | alt Yêu cầu và trạng thái hợp lệ | Kết quả cập nhật | Điều kiện triển khai: alt Ticket và status hợp lệ. |
| 14 | MaintenanceController → Màn hình danh sách bảo trì | alt Yêu cầu và trạng thái hợp lệ | Tiến độ mới | Điều kiện triển khai: alt Ticket và status hợp lệ. |
| 15 | Màn hình danh sách bảo trì → Chủ trọ | alt Yêu cầu và trạng thái hợp lệ | Hiển thị trạng thái | Điều kiện triển khai: alt Ticket và status hợp lệ. |

### SD-09C Hoàn tất bảo trì và ghi nhận chi phí

![SD-09C Hoàn tất bảo trì và ghi nhận chi phí](sequence-diagrams/full/sd-09c-complete-maintenance.png)

[SVG vector](sequence-diagrams/full/sd-09c-complete-maintenance.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-09c-complete-maintenance.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Biểu mẫu hoàn tất | Luồng chung | Xác nhận hoàn tất | Không cần bổ sung |
| 2 | Biểu mẫu hoàn tất → MaintenanceController | Luồng chung | Gửi thông tin hoàn tất bảo trì | POST /maintenance/:id/complete |
| 3 | MaintenanceController → MaintenanceService | Luồng chung | Yêu cầu hoàn tất bảo trì | complete(input) |
| 4 | MaintenanceService → Cơ sở dữ liệu | Luồng chung | Tra cứu yêu cầu thuộc quản lý | Tìm Ticket sở hữu |
| 5 | Cơ sở dữ liệu → MaintenanceService | Luồng chung | Yêu cầu và khoản chi liên kết | Ticket và expenseId |
| 6 | MaintenanceService → MaintenanceController | alt Không tìm thấy yêu cầu hoặc chi phí hay ngày hoàn tất không hợp lệ | Yêu cầu hoặc dữ liệu không hợp lệ | Lỗi Ticket hoặc dữ liệu Điều kiện triển khai: alt Không có Ticket hoặc dữ liệu chi phí ngày không hợp lệ. |
| 7 | MaintenanceController → Biểu mẫu hoàn tất | alt Không tìm thấy yêu cầu hoặc chi phí hay ngày hoàn tất không hợp lệ | Từ chối hoàn tất | Điều kiện triển khai: alt Không có Ticket hoặc dữ liệu chi phí ngày không hợp lệ. |
| 8 | MaintenanceService → MaintenanceService | alt Dữ liệu hợp lệ | Xác định chi phí và ngày hoàn tất | Chọn cost và completedAt. actualCost ưu tiên input, rồi giá trị cũ, rồi 0; completedAt ưu tiên input, mặc định hiện tại. |
| 9 | MaintenanceService → Cơ sở dữ liệu | alt Dữ liệu hợp lệ | Bắt đầu ghi nhận nghiệp vụ | BEGIN transaction |
| 10 | MaintenanceService → Cơ sở dữ liệu | alt Dữ liệu hợp lệ / opt Chọn ghi khoản chi, chi phí > 0 và chưa có khoản chi liên kết | Ghi nhận khoản chi sửa chữa | Tạo Expense REPAIR. Cùng khu trọ, phòng, landlordId; amount = actualCost, expenseDate = completedAt; title từ Ticket. Điều kiện triển khai: opt createExpense = true và cost > 0 và expenseId chưa có. |
| 11 | Cơ sở dữ liệu → MaintenanceService | alt Dữ liệu hợp lệ / opt Chọn ghi khoản chi, chi phí > 0 và chưa có khoản chi liên kết | Khoản chi sửa chữa mới | Expense mới Điều kiện triển khai: opt createExpense = true và cost > 0 và expenseId chưa có. |
| 12 | MaintenanceService → Cơ sở dữ liệu | alt Dữ liệu hợp lệ | Lưu yêu cầu bảo trì đã hoàn tất | Ticket = DONE. Lưu completedAt, actualCost, note nếu cung cấp và expenseId nếu tạo khoản chi mới. |
| 13 | Cơ sở dữ liệu → MaintenanceService | alt Dữ liệu hợp lệ | Kết quả hoàn tất đã được lưu | COMMIT và Ticket |
| 14 | MaintenanceService → MaintenanceController | alt Dữ liệu hợp lệ | Hoàn tất bảo trì | Không cần bổ sung |
| 15 | MaintenanceController → Biểu mẫu hoàn tất | alt Dữ liệu hợp lệ | Yêu cầu bảo trì đã hoàn tất | Ticket DONE |
| 16 | Biểu mẫu hoàn tất → Chủ trọ | alt Dữ liệu hợp lệ | Hiển thị chi phí | Không cần bổ sung |

### Đối chiếu đặc tả Use Case

**UC-TEN-05.01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Người thuê: Chọn gửi yêu cầu bảo trì.<br><br>**2.** Hệ thống: Hiển thị các trường tiêu đề sự cố, mô tả, mức ưu tiên và ảnh.<br><br>**3.** Người thuê: Nhập tiêu đề, mô tả; chọn mức ưu tiên và bổ sung ảnh nếu có rồi xác nhận gửi.<br><br>**4.** Hệ thống: Xác định hồ sơ và hợp đồng hiệu lực để gắn yêu cầu với phòng, khu trọ và Chủ trọ.<br><br>**5.** Hệ thống: Ghi yêu cầu ở trạng thái Mới, dùng mức ưu tiên Trung bình nếu không được chỉ định.<br><br>**6.** Hệ thống: Hiển thị yêu cầu đã gửi trong danh sách để Người thuê theo dõi. |
| **Luồng thay thế** | **A1 — Tại bước 3:** Không gửi ảnh hoặc mức ưu tiên. Cho phép không có ảnh; mức ưu tiên dùng giá trị mặc định. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Không có hồ sơ đang sử dụng hoặc không có hợp đồng hiệu lực. Từ chối tạo yêu cầu. UC kết thúc đối với yêu cầu bị từ chối.<br><br>**E2 — Tại bước 3:** Tiêu đề/ưu tiên không hợp lệ. Yêu cầu điều chỉnh dữ liệu. Sau khi điều chỉnh, thực hiện lại từ bước 3. |

**UC-OPT-06.03**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn chỉnh sửa yêu cầu bảo trì.<br><br>**2.** Hệ thống: Hiển thị phòng/khu trọ, tiêu đề, mô tả, mức ưu tiên, trạng thái, ngày báo, chi phí dự kiến, chi phí thực tế và ghi chú hiện tại.<br><br>**3.** Chủ trọ: Thay đổi các thông tin cần sửa trên biểu mẫu và xác nhận lưu.<br><br>**4.** Hệ thống: Kiểm tra quyền quản lý yêu cầu, khu trọ, phòng và tính hợp lệ của dữ liệu.<br><br>**5.** Hệ thống: Lưu các thông tin được thay đổi. Không tự ghi ngày bắt đầu hoặc hoàn tất chỉ vì đổi trạng thái trong biểu mẫu sửa; khác biệt với thao tác nhanh xem [PX-13](#px-13).<br><br>**6.** Hệ thống: Hiển thị nội dung và tiến độ mới của yêu cầu. |
| **Luồng thay thế** | **A1 — Tại bước 1:** Chủ trọ chọn bắt đầu xử lý hoặc hủy yêu cầu ngay trên danh sách thay cho mở biểu mẫu sửa. Hệ thống tiếp nhận lựa chọn và tiếp tục bước 4 để kiểm tra yêu cầu thuộc phạm vi quản lý. Tại bước 5, hệ thống chuyển sang Đang xử lý hoặc Đã hủy; khi bắt đầu xử lý và chưa có ngày bắt đầu thì ghi thời điểm hiện tại. Nhánh hủy không tự ghi ngày hoàn tất. Hiển thị kết quả tại bước 6. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Yêu cầu/phòng/khu trọ không hợp lệ hoặc trạng thái/ngày sai. Từ chối cập nhật. UC kết thúc đối với yêu cầu bị từ chối. |

**UC-OPT-06.04**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn hoàn tất yêu cầu bảo trì.<br><br>**2.** Hệ thống: Hiển thị chi phí thực tế, ghi chú và lựa chọn ghi nhận khoản chi.<br><br>**3.** Chủ trọ: Nhập chi phí thực tế, ghi chú nếu có, chọn có ghi khoản chi hay không và xác nhận hoàn tất.<br><br>**4.** Hệ thống: Kiểm tra yêu cầu, chi phí và thời điểm hoàn tất.<br><br>**5.** Hệ thống: Đánh dấu yêu cầu Hoàn tất; nếu chọn ghi khoản chi, chi phí dương và chưa có khoản chi liên kết thì tạo khoản chi sửa chữa, liên kết với yêu cầu.<br><br>**6.** Hệ thống: Hiển thị kết quả hoàn tất và khoản chi liên quan nếu được tạo. |
| **Luồng thay thế** | **A1 — Tại bước 3:** Chủ trọ không chọn ghi khoản chi. Tiếp tục bước 4 để kiểm tra yêu cầu, chi phí và thời điểm hoàn tất. Nếu hợp lệ, tại bước 5 hệ thống đánh dấu yêu cầu Hoàn tất mà không tạo khoản chi mới; hiển thị kết quả tại bước 6. |
| **Luồng ngoại lệ** | **E1 — Tại bước 4:** Yêu cầu không tồn tại/ngoài phạm vi hoặc dữ liệu không hợp lệ. Từ chối hoàn tất. UC kết thúc đối với yêu cầu bị từ chối. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | Tiêu đề, mô tả, ảnh URL và ưu tiên; ticketId, status; actualCost, completedAt, createExpense, note. |
| Kết quả ghi nhận | Tạo ticket OPEN; xử lý ghi mốc phù hợp; hoàn tất đặt DONE và có thể liên kết Expense REPAIR. |
| Lưu ý triển khai | Ảnh tải bằng luồng POST /uploads giống SD-08A, nhưng yêu cầu bảo trì cho phép không ảnh; ưu tiên mặc định medium. |
| Lưu ý triển khai | Hệ thống chọn ACTIVE lease đầu tiên trong danh sách sắp startDate giảm dần; chưa có chọn phòng khi nhiều hợp đồng PX-27. |
| Lưu ý triển khai | PX-13: chưa có state machine hạn chế chuyển trạng thái. Hủy không tự ghi completedAt; đổi sang DONE chỉ thêm completedAt nếu chưa có. |
| Lưu ý triển khai | Tạo khoản chi chỉ khi createExpense = true, actualCost > 0 và chưa có expenseId. Gọi complete lại không tự bị từ chối PX-14. |
| Tham chiếu Tải tệp và nhận đường dẫn như SD-08A | POST /uploads và nhận URL như SD-08A |
| Thành phần TenantPortalController | src/tenant-portal/tenant-portal.controller.ts |
| Thành phần TenantPortalService | src/tenant-portal/tenant-portal.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Tham chiếu Ghi nhật ký cập nhật tiến độ bảo trì | AuditService.recordSafe maintenance.status_update |
| Thành phần MaintenanceController | src/maintenance/maintenance.controller.ts |
| Thành phần MaintenanceService | src/maintenance/maintenance.service.ts |
| Tham chiếu Ghi nhật ký hoàn tất bảo trì | AuditService.recordSafe maintenance.complete |
| Căn cứ kiểm chứng | Backend src/tenant-portal/tenant-portal.service.ts createMaintenance tại dòng 360 |
| Căn cứ kiểm chứng | Backend src/maintenance/maintenance.service.ts updateStatus tại dòng 177 |
| Căn cứ kiểm chứng | Backend src/maintenance/maintenance.service.ts complete tại dòng 201 |
| Căn cứ kiểm chứng | Flutter lib/features/maintenance/maintenance_screen.dart Tệp giao diện liên quan đối chiếu ở mức tệp |

## SD-10 Xem và xuất báo cáo tháng

**Điều kiện trước:** Chủ trọ đã đăng nhập; chọn tháng và tùy chọn khu trọ thuộc quyền chưa lưu trữ.

**Dữ liệu đầu vào:** Tháng báo cáo và khu trọ tùy chọn.

**Điều kiện sau khi thành công:** Hiển thị số liệu trong phạm vi đã chọn. Khi xuất, tạo nội dung báo cáo CSV và sao chép để người dùng sử dụng tiếp.

**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.

### Lưu ý nghiệp vụ

- Tiền phải thu theo kỳ hóa đơn; tiền đã thu theo thời điểm thanh toán, có tính các khoản hoàn tác; chi phí và giao dịch cọc theo thời điểm phát sinh.
- Số còn phải thu là số dư hiện tại của hóa đơn kỳ đã chọn. Số hợp đồng hiệu lực phản ánh hiện tại, không tái dựng thời điểm cuối tháng. PX-22 cần chốt ý nghĩa.
- Lợi nhuận ước tính bằng tiền đã thu trừ chi phí, không cộng cọc vào doanh thu. Chỉ số cọc trả hiện gồm cả hoàn cọc và khấu trừ.
- PX-23: xuất CSV hiện sao chép nội dung, không tải tệp và không xuất PDF. Dữ liệu được tổng hợp lại khi xuất, nên có thể khác thời điểm xem.
- Không có phát sinh vẫn là báo cáo hợp lệ; các tổng tiền bằng 0, số hợp đồng hiệu lực vẫn đếm tại thời điểm xem. Hiện trạng chưa có thông báo lỗi riêng cho thao tác xuất.

### SD-10A Xem báo cáo thu chi tháng

![SD-10A Xem báo cáo thu chi tháng](sequence-diagrams/full/sd-10a-monthly-report.png)

[SVG vector](sequence-diagrams/full/sd-10a-monthly-report.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-10a-monthly-report.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình báo cáo | Luồng chung | Chọn tháng và khu trọ | Không cần bổ sung |
| 2 | Màn hình báo cáo → ReportsController | Luồng chung | Gửi yêu cầu xem báo cáo tháng | GET /reports/monthly |
| 3 | ReportsController → ReportsService | Luồng chung | Yêu cầu tổng hợp báo cáo tháng | monthly(month, propertyId) |
| 4 | ReportsService → ReportsService | Luồng chung | Xác định khoảng tháng | Xác định khoảng tháng. Mặc định tháng hiện tại, monthStart UTC và nextMonth làm cận trên không bao gồm. |
| 5 | ReportsService → Cơ sở dữ liệu | opt Có chọn khu trọ riêng | Kiểm tra khu trọ thuộc quản lý | Điều kiện triển khai: opt Có propertyId. |
| 6 | Cơ sở dữ liệu → ReportsService | opt Có chọn khu trọ riêng | Khu chưa lưu trữ | Điều kiện triển khai: opt Có propertyId. |
| 7 | ReportsService → ReportsController | opt Có chọn khu trọ riêng / break Khu không thuộc quyền hoặc đã lưu trữ | Khu trọ không đủ điều kiện | PROPERTY_NOT_FOUND Điều kiện triển khai: opt Có propertyId. |
| 8 | ReportsController → Màn hình báo cáo | opt Có chọn khu trọ riêng / break Khu không thuộc quyền hoặc đã lưu trữ | Từ chối xem báo cáo | Điều kiện triển khai: opt Có propertyId. |
| 9 | ReportsService → Cơ sở dữ liệu | Luồng chung | Tra cứu số liệu báo cáo tháng | Đọc 5 nhóm dữ liệu. Trong prisma.$transaction: Invoice theo billingMonth không CANCELLED; Payment PAYMENT/REVERSAL theo paidAt; Expense theo expenseDate; DepositTransaction theo occurredAt; đếm Lease ACTIVE hiện tại. |
| 10 | Cơ sở dữ liệu → ReportsService | Luồng chung | Số liệu thu chi cọc và hợp đồng | Hóa đơn thu chi cọc Lease |
| 11 | ReportsService → ReportsService | Luồng chung | Tổng hợp và phân nhóm | Tổng hợp và phân nhóm. billed, received, expense, outstanding, estimatedProfit; thống kê trạng thái hóa đơn, loại chi và phương thức thu. |
| 12 | ReportsService → ReportsController | Luồng chung | Báo cáo tháng đã tổng hợp | MonthlyReport |
| 13 | ReportsController → Màn hình báo cáo | Luồng chung | Số liệu theo phạm vi | Không cần bổ sung |
| 14 | Màn hình báo cáo → Chủ trọ | alt Kỳ có dữ liệu tài chính | Hiển thị báo cáo tháng | Không cần bổ sung |
| 15 | Màn hình báo cáo → Chủ trọ | alt Không có phát sinh trong kỳ | Hiển thị số tiền bằng 0 | Hiển thị số tiền bằng 0. Không báo lỗi; số hợp đồng ACTIVE vẫn đếm tại thời điểm truy vấn. |

### SD-10B Xuất báo cáo và sao chép nội dung CSV

![SD-10B Xuất báo cáo và sao chép nội dung CSV](sequence-diagrams/full/sd-10b-export-csv.png)

[SVG vector](sequence-diagrams/full/sd-10b-export-csv.svg) · [Nguồn draw.io](sequence-diagrams/full/sd-10b-export-csv.drawio)

| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |
| --- | --- | --- | --- | --- |
| 1 | Chủ trọ → Màn hình báo cáo | Luồng chung | Chọn Xuất CSV | Không cần bổ sung |
| 2 | Màn hình báo cáo → ReportsController | Luồng chung | Gửi yêu cầu xuất báo cáo tháng | GET /reports/monthly/export |
| 3 | ReportsController → ReportsService | Luồng chung | Yêu cầu tạo báo cáo dạng CSV | monthlyExport() |
| 4 | ReportsService → ReportsController | alt Tổng hợp báo cáo thất bại | Lỗi báo cáo | Không cần bổ sung |
| 5 | ReportsController → Màn hình báo cáo | alt Tổng hợp báo cáo thất bại | Không có kết quả xuất báo cáo | API trả lỗi. _exportCsv chưa có try/catch riêng; không khẳng định snackbar lỗi đã được triển khai. |
| 6 | ReportsService → ReportsService | alt Tổng hợp thành công | Tạo các dòng CSV | Không cần bổ sung |
| 7 | ReportsService → ReportsService | alt Tổng hợp thành công / loop Với mỗi ô CSV cần định dạng ký tự đặc biệt | Định dạng dữ liệu CSV hợp lệ | Không cần bổ sung |
| 8 | ReportsService → ReportsController | alt Tổng hợp thành công | Tên tệp và nội dung báo cáo | filename mimeType content |
| 9 | ReportsController → Màn hình báo cáo | alt Tổng hợp thành công | Báo cáo sẵn sàng sao chép | ReportExport |
| 10 | Màn hình báo cáo → Màn hình báo cáo | alt Tổng hợp thành công | Sao chép nội dung báo cáo | Clipboard.setData(content) |
| 11 | Màn hình báo cáo → Chủ trọ | alt Tổng hợp thành công | Thông báo đã sao chép CSV | Thông báo Đã copy CSV. filename = monthly-report-YYYY-MM.csv. Không tải file xuống thiết bị. |

### Đối chiếu đặc tả Use Case

**UC-BIL-06.01**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Mở báo cáo và chọn tháng, khu trọ cần xem.<br><br>**2.** Hệ thống: Kiểm tra khu trọ được chọn thuộc phạm vi quản lý và chưa lưu trữ.<br><br>**3.** Hệ thống: Tổng hợp hóa đơn theo kỳ; khoản thu, khoản đảo, khoản chi và giao dịch cọc theo ngày phát sinh.<br><br>**4.** Hệ thống: Tính tiền lập hóa đơn, thực thu, công nợ hiện tại, chi phí và chênh lệch thu–chi; tổng hợp riêng thông tin cọc, xem [PX-22](#px-22).<br><br>**5.** Hệ thống: Hiển thị chỉ số tổng hợp, cơ cấu khoản chi, phương thức thu và danh sách hóa đơn để Chủ trọ đối chiếu. |
| **Luồng thay thế** | **A1 — Tại bước 1:** Không chọn tháng hoặc khu trọ riêng. Dùng tháng hiện tại và phạm vi Chủ trọ theo xử lý báo cáo. |
| **Luồng ngoại lệ** | **E1 — Tại bước 2:** Khu trọ ngoài phạm vi hoặc đã lưu trữ. Từ chối báo cáo theo khu trọ đó. UC kết thúc đối với yêu cầu bị từ chối. |

**UC-BIL-06.02**

| Thuộc tính | Đặc tả |
| --- | --- |
| **Luồng chính** | **1.** Chủ trọ: Chọn xuất CSV cho báo cáo tháng đang xem.<br><br>**2.** Hệ thống: Tổng hợp báo cáo theo tháng và phạm vi khu trọ đã chọn.<br><br>**3.** Hệ thống: Tạo nội dung CSV gồm các chỉ số tổng hợp và danh sách hóa đơn, kèm tên tệp tương ứng.<br><br>**4.** Hệ thống: Sao chép nội dung CSV vào bộ nhớ sao chép của thiết bị và hiển thị tên tệp; kết quả lưu thành tệp xem [PX-23](#px-23). |
| **Luồng thay thế** | Không có nhánh thay thế nghiệp vụ riêng trong phạm vi UC này. |
| **Luồng ngoại lệ** | **E1 — Tại bước 2:** Không lấy được báo cáo hoặc dữ liệu ngoài phạm vi. Không có CSV mới; hiển thị lỗi. |

### Liên hệ triển khai và căn cứ kiểm chứng

| Nội dung | Chi tiết |
| --- | --- |
| Dữ liệu đầu vào | month tùy chọn, propertyId tùy chọn. |
| Kết quả ghi nhận | Xem số liệu theo phạm vi; xuất trả filename, mimeType, content và Flutter sao chép content vào clipboard. |
| Lưu ý triển khai | Billed lọc billingMonth; received lọc paidAt và cộng số tiền có dấu PAYMENT/REVERSAL; expense lọc expenseDate; deposit lọc occurredAt. |
| Lưu ý triển khai | Outstanding là số dư hiện tại của hóa đơn kỳ đã chọn; activeLeases là số ACTIVE hiện tại, không phải tái dựng cuối tháng. PX-22 cần chốt ngữ nghĩa. |
| Lưu ý triển khai | Ước tính lợi nhuận = received - expense; không cộng cọc vào doanh thu. depositReturned hiện gồm REFUNDED và DEDUCTED. |
| Lưu ý triển khai | PX-23: nút Xuất CSV hiện sao chép nội dung, không tải file và không xuất PDF. monthlyExport gọi monthly lần nữa, dữ liệu có thể thay đổi giữa xem và xuất. |
| Lưu ý triển khai | Không có phát sinh vẫn là báo cáo hợp lệ; các tổng tiền bằng 0, activeLeases vẫn phản ánh hiện tại. Hàm _exportCsv chưa có catch hiển thị lỗi riêng. |
| Thành phần ReportsController | src/reports/reports.controller.ts |
| Thành phần ReportsService | src/reports/reports.service.ts |
| Thành phần Cơ sở dữ liệu | PostgreSQL |
| Căn cứ kiểm chứng | Backend src/reports/reports.service.ts monthly tại dòng 15 |
| Căn cứ kiểm chứng | Backend src/reports/reports.service.ts monthlyExport tại dòng 135 |
| Căn cứ kiểm chứng | Flutter lib/features/reports/reports_screen.dart _exportCsv tại dòng 66 |

## 5 Bàn giao và chỉnh sửa

- SEQUENCE_DIAGRAM_SPECIFICATION.docx là bản Word độc lập, có hình và bảng thông điệp chi tiết; không ghi đè báo cáo Word tổng.
- sequence-diagrams/full/SEQUENCE_DIAGRAMS.drawio có 22 trang chỉnh sửa được; các ký hiệu và chữ là đối tượng riêng, không phải ảnh PNG nhúng.
- model.json tách nhãn nghiệp vụ với thông tin triển khai. build.py tạo hình và Markdown; build_document.py tạo Word; manifest.json và validation.json ghi kết quả kiểm tra.
- Mục 2.4.4 của PROPOSAL_QUAN_LY_TRO.md dùng cùng hình và nội dung nghiệp vụ; chi tiết kỹ thuật tra cứu ở các bảng trong đặc tả độc lập.
- Trong bộ chính thức, SD-01 là đăng nhập và SD-04 là tạo hợp đồng. Bộ demo cũ ở thư mục cha chỉ là lịch sử duyệt form.
