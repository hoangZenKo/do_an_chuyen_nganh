# Chỉ mục đầy đủ theo Actor

Mục đích: tra mọi UC Actor có thể khởi xướng và các ngoại lệ, không tạo thêm Actor hoặc UC. A04 dùng cùng role TENANT ở ngữ cảnh tìm phòng và đã thuê. Một User có một role, không có kế thừa ADMIN→LANDLORD hay STAFF→LANDLORD.

A03 có sáu sơ đồ chuyên biệt vì dễ nhầm quyền read-only và quyền bị interceptor chặn. A01/A02/A04 không thêm sơ đồ lặp; A05 đã có các trang quản trị tập trung theo G11–G16/G01. Bảng dưới cùng Actor–UC Matrix Giai đoạn 2 cung cấp phạm vi đầy đủ, không suy quyền từ sơ đồ tổng thể.

## A01 — Khách/chưa đăng nhập

Role: không đăng nhập, không có role GUEST. Actor chính trong **11 UC**.

| UC | Mục tiêu | Mức tham gia | Trang module |
| --- | --- | --- | --- |
| UC-SYS-01 | Đăng ký tài khoản chủ trọ | P — đủ dữ liệu/token theo UC | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-02 | Đăng ký tài khoản tìm phòng | P — đủ dữ liệu/token theo UC | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-03 | Đăng nhập | P — chủ tài khoản chưa đăng nhập | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-06 | Khôi phục mật khẩu bằng liên kết một lần | P — chủ tài khoản chưa đăng nhập | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-08 | Kích hoạt tài khoản người thuê từ lời mời | P — đủ dữ liệu/token theo UC | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-09 | Kích hoạt tài khoản nhân viên từ lời mời | P — đủ dữ liệu/token theo UC | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-SYS-10 | Thiết lập mật khẩu tài khoản được mời | P — đủ dữ liệu/token theo UC | [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | P — công khai | [UC_G02](UC_G02.puml) |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | P — công khai | [UC_G02](UC_G02.puml) |
| UC-DIS-16 | So sánh các phòng quan tâm | P — công khai | [UC_G02](UC_G02.puml) |
| UC-DIS-17 | Ước tính chi phí thuê phòng | P — công khai | [UC_G02](UC_G02.puml) |
| UC-TEN-05 | Thanh toán bằng thẻ mô phỏng | V — chỉ checkout có token demo hợp lệ | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |

## A02 — Chủ trọ

Role: LANDLORD. Actor chính trong **89 UC**.

| UC | Mục tiêu | Mức tham gia | Trang module |
| --- | --- | --- | --- |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-16 | So sánh các phòng quan tâm | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-17 | Ước tính chi phí thuê phòng | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-05 | Quản lý và gửi duyệt tin cho thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G03](UC_G03.puml) |
| UC-DIS-06.2 | Ẩn tin cho thuê của mình | P* — dữ liệu thuộc mình; điều kiện service | [UC_G03](UC_G03.puml) |
| UC-DIS-08 | Quản lý khung giờ xem phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G03](UC_G03.puml) |
| UC-DIS-09 | Đặt và quản lý lịch xem của mình | V — xem/phản hồi tại UC-DIS-10 | [UC_G03](UC_G03.puml) |
| UC-DIS-10 | Tiếp nhận và hoàn tất lịch xem | P* — dữ liệu thuộc mình; điều kiện service | [UC_G03](UC_G03.puml) |
| UC-DIS-13.2 | Gửi phản hồi về thử nghiệm tìm phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G16](UC_G16.puml) |
| UC-TNT-12.2 | Lập biên bản bàn giao nhận phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G03](UC_G03.puml) |
| UC-OPT-02 | Tra cứu khu trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-03.1 | Tạo khu trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-04.1 | Lưu trữ hoặc khôi phục khu trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-04.3 | Xóa khu trọ đủ điều kiện | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-06.1 | Tạo phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-06.2 | Cập nhật thông tin phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-07.1 | Đổi trạng thái sử dụng phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-07.3 | Xóa phòng đủ điều kiện | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-08.1 | Quản lý tài sản phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G04](UC_G04.puml) |
| UC-STF-01 | Mời nhân viên và cấp phạm vi khu trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G05](UC_G05.puml) |
| UC-STF-02 | Cập nhật quyền trạng thái và phạm vi nhân viên | P* — dữ liệu thuộc mình; điều kiện service | [UC_G05](UC_G05.puml) |
| UC-STF-03 | Mô phỏng quyền nhân viên | P* — dữ liệu thuộc mình; điều kiện service | [UC_G05](UC_G05.puml) |
| UC-STF-04 | Tra cứu nhân viên và phạm vi được cấp | P* — dữ liệu thuộc mình; điều kiện service | [UC_G05](UC_G05.puml) |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.4 | Xóa hồ sơ người thuê đủ điều kiện | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-03 | Tạo lời mời truy cập cổng người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-03.1 | Tạo trực tiếp tài khoản cho hồ sơ người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-04 | Tra cứu và xuất hợp đồng thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-05 | Lập hợp đồng thuê phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.2 | Gia hạn hợp đồng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.3 | Kết thúc hợp đồng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-07 | Tra cứu và ghi giao dịch cọc | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-08 | Xem trước và xác nhận quyết toán trả phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G07](UC_G07.puml) |
| UC-TNT-09 | Ghi nhận đã hoàn cọc theo quyết toán | P* — dữ liệu thuộc mình; điều kiện service | [UC_G07](UC_G07.puml) |
| UC-TNT-10 | Xét duyệt yêu cầu vòng đời thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G07](UC_G07.puml) |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã duyệt | P* — dữ liệu thuộc mình; điều kiện service | [UC_G07](UC_G07.puml) |
| UC-BIL-01 | Ghi chỉ số điện nước theo kỳ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-02 | Xem trước và lập hóa đơn một hợp đồng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-03 | Lập hóa đơn hàng loạt | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-04 | Tra cứu hóa đơn và công nợ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-05 | Sửa hạn thanh toán hoặc ghi chú hóa đơn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-06 | Thay thế hóa đơn chưa có lịch sử thanh toán | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-07 | Điều chỉnh tăng hoặc giảm hóa đơn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-08.1 | Hủy hóa đơn đủ điều kiện | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-09 | Ghi nhận thanh toán trực tiếp | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-10 | Tạo khoản thu cho người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-11 | Phân bổ khoản thu cho hóa đơn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-12.1 | Giải phóng phân bổ khoản thu | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-12.2 | Đảo thanh toán trực tiếp | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-13 | Ghi nhận hoàn tiền từ khoản thu | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-14 | Xét duyệt chứng từ thanh toán | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-15 | Đề xuất biểu phí theo kỳ hiệu lực | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) |
| UC-BIL-16 | Phân tích tác động và duyệt biểu phí | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) |
| UC-BIL-17.1 | Cấu hình lập hóa đơn định kỳ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-17.2 | Xem trước và chạy đợt lập hóa đơn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-18.1 | Cấu hình chính sách nhắc nợ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-18.2 | Gửi nhắc nợ theo chính sách | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-18.3 | Theo dõi và thử lại outbox hóa đơn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-22 | Khóa kỳ thanh toán của khu | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) |
| UC-BIL-23 | Cấu hình tài khoản nhận chuyển khoản | P* — dữ liệu thuộc mình; điều kiện service | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-TEN-05 | Thanh toán bằng thẻ mô phỏng | V — chỉ tra trạng thái/sự kiện demo ở UC-BIL-04 | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-19 | Quản lý khoản chi vận hành | P* — dữ liệu thuộc mình; điều kiện service | [UC_G09](UC_G09.puml) |
| UC-OPS-01 | Tiếp nhận và theo dõi phiếu bảo trì | P* — dữ liệu thuộc mình; điều kiện service | [UC_G09](UC_G09.puml) |
| UC-OPS-02 | Phân công và cập nhật bảo trì | P* — dữ liệu thuộc mình; điều kiện service | [UC_G09](UC_G09.puml) |
| UC-OPS-03 | Hoàn tất bảo trì và liên kết khoản chi | P* — dữ liệu thuộc mình; điều kiện service | [UC_G09](UC_G09.puml) |
| UC-OPS-04 | Theo dõi việc cần xử lý | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-OPS-05 | Chuẩn bị phòng sau trả phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-OPS-06 | Thiết lập lịch công việc định kỳ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-OPS-06.1 | Thực hiện checklist công việc định kỳ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-OPS-07 | Soạn và phát thông báo người thuê | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-SUP-04 | Theo dõi thông báo cá nhân | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-SUP-06 | Hỏi trợ lý AI và đọc nguồn hướng dẫn | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-TEN-09.2 | Trao đổi tin nhắn Zalo mô phỏng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G10](UC_G10.puml) |
| UC-BIL-20 | Phân tích và xuất báo cáo vận hành | P* — dữ liệu thuộc mình; điều kiện service | [UC_G11](UC_G11.puml) |
| UC-OPS-09 | Tra cứu nhật ký vận hành | P* — dữ liệu thuộc mình; điều kiện service | [UC_G11](UC_G11.puml) |
| UC-OPT-01 | Xem dashboard và bản đồ phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G11](UC_G11.puml) |
| UC-DIS-13.1 | Trả lời đánh giá phòng | P* — dữ liệu thuộc mình; điều kiện service | [UC_G13](UC_G13.puml) |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | P* — dữ liệu thuộc mình; điều kiện service | [UC_G13](UC_G13.puml) |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G14](UC_G14.puml) |
| UC-ADM-18.1 | Nộp hồ sơ xác minh chủ trọ | P* — dữ liệu thuộc mình; điều kiện service | [UC_G15](UC_G15.puml) |

## A03 — Nhân viên vận hành

Role: STAFF. Actor chính trong **57 UC**.

| UC | Mục tiêu | Mức tham gia | Trang module |
| --- | --- | --- | --- |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | P — phiên/tài khoản của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | P — phiên/tài khoản của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | P — phiên/tài khoản của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-OPT-02 | Tra cứu khu trọ | P* — property.view; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-03.1 | Tạo khu trọ | B — interceptor chặn | [UC_G04](UC_G04.puml) |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | P* — property.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-04.1 | Lưu trữ hoặc khôi phục khu trọ | P* — property.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-04.3 | Xóa khu trọ đủ điều kiện | P* — property.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | P* — room.view; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-06.1 | Tạo phòng | P* — room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-06.2 | Cập nhật thông tin phòng | P* — room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-07.1 | Đổi trạng thái sử dụng phòng | P* — room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | P* — room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-07.3 | Xóa phòng đủ điều kiện | P* — room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-08.1 | Quản lý tài sản phòng | P* — room.view, room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | P* — room.view, room.manage; theo hành vi + scope | [UC_G04](UC_G04.puml) |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ phòng | V — chỉ đọc: room.view + scope | [UC_G04](UC_G04.puml) |
| UC-STF-01 | Mời nhân viên và cấp phạm vi khu trọ | V — chỉ đọc: staff.view + scope | [UC_G05](UC_G05.puml) |
| UC-STF-02 | Cập nhật quyền trạng thái và phạm vi nhân viên | B — interceptor chặn | [UC_G05](UC_G05.puml) |
| UC-STF-04 | Tra cứu nhân viên và phạm vi được cấp | P* — staff.view; theo hành vi + scope | [UC_G05](UC_G05.puml) |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | P* — tenant.view; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | P* — tenant.manage; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | P* — tenant.manage; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục người thuê | P* — tenant.manage; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-02.4 | Xóa hồ sơ người thuê đủ điều kiện | P* — tenant.manage; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-03 | Tạo lời mời truy cập cổng người thuê | B — interceptor chặn | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-03.1 | Tạo trực tiếp tài khoản cho hồ sơ người thuê | P* — tenant.manage; theo hành vi + scope | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TNT-04 | Tra cứu và xuất hợp đồng thuê | P* — lease.view; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-05 | Lập hợp đồng thuê phòng | P* — lease.manage; theo hành vi + scope; không tạo từ lịch xem | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | P* — lease.manage; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.2 | Gia hạn hợp đồng | P* — lease.manage; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-06.3 | Kết thúc hợp đồng | P* — lease.manage; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-07 | Tra cứu và ghi giao dịch cọc | P* — lease.view, lease.manage; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | P* — lease.view, lease.manage; theo hành vi + scope | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TNT-10 | Xét duyệt yêu cầu vòng đời thuê | P* — lease.view, lease.manage; theo hành vi + scope | [UC_G07](UC_G07.puml) |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã duyệt | P* — lease.manage; theo hành vi + scope | [UC_G07](UC_G07.puml) |
| UC-BIL-01 | Ghi chỉ số điện nước theo kỳ | P* — billing.view, billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-02 | Xem trước và lập hóa đơn một hợp đồng | P* — billing.view, billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-03 | Lập hóa đơn hàng loạt | P* — billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-04 | Tra cứu hóa đơn và công nợ | P* — billing.view; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-05 | Sửa hạn thanh toán hoặc ghi chú hóa đơn | P* — billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-06 | Thay thế hóa đơn chưa có lịch sử thanh toán | P* — billing.adjust; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-07 | Điều chỉnh tăng hoặc giảm hóa đơn | P* — billing.adjust; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-08.1 | Hủy hóa đơn đủ điều kiện | P* — billing.cancel; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-09 | Ghi nhận thanh toán trực tiếp | P* — billing.record_payment; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-10 | Tạo khoản thu cho người thuê | P* — billing.view, billing.record_payment; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-11 | Phân bổ khoản thu cho hóa đơn | P* — billing.record_payment; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-12.1 | Giải phóng phân bổ khoản thu | P* — billing.reverse_payment; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-12.2 | Đảo thanh toán trực tiếp | P* — billing.reverse_payment; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-13 | Ghi nhận hoàn tiền từ khoản thu | P* — billing.refund; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-14 | Xét duyệt chứng từ thanh toán | P* — billing.view, billing.approve_payment_proof; theo hành vi + scope | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-BIL-15 | Đề xuất biểu phí theo kỳ hiệu lực | P* — billing.view, billing.create; theo hành vi + scope | [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) |
| UC-BIL-16 | Phân tích tác động và duyệt biểu phí | V — chỉ đọc: billing.view + scope | [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) |
| UC-BIL-17.1 | Cấu hình lập hóa đơn định kỳ | P* — billing.view, billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-17.2 | Xem trước và chạy đợt lập hóa đơn | P* — billing.create; theo hành vi + scope | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-BIL-18.1 | Cấu hình chính sách nhắc nợ | P* — billing.policy; theo hành vi + scope; propertyId bắt buộc | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-18.2 | Gửi nhắc nợ theo chính sách | P* — billing.policy; theo hành vi + scope; propertyId bắt buộc | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-18.3 | Theo dõi và thử lại outbox hóa đơn | B — interceptor chặn | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-BIL-19 | Quản lý khoản chi vận hành | P* — expense.view, expense.manage; theo hành vi + scope | [UC_G09](UC_G09.puml) |
| UC-OPS-01 | Tiếp nhận và theo dõi phiếu bảo trì | P* — maintenance.view, maintenance.manage; theo hành vi + scope | [UC_G09](UC_G09.puml) |
| UC-OPS-02 | Phân công và cập nhật bảo trì | P* — maintenance.manage; theo hành vi + scope; không escalate | [UC_G09](UC_G09.puml) |
| UC-OPS-03 | Hoàn tất bảo trì và liên kết khoản chi | P* — maintenance.complete; theo hành vi + scope | [UC_G09](UC_G09.puml) |
| UC-OPS-04 | Theo dõi việc cần xử lý | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-OPS-05 | Chuẩn bị phòng sau trả phòng | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-OPS-06 | Thiết lập lịch công việc định kỳ | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-OPS-06.1 | Thực hiện checklist công việc định kỳ | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-OPS-07 | Soạn và phát thông báo người thuê | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-SUP-04 | Theo dõi thông báo cá nhân | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-TEN-09.2 | Trao đổi tin nhắn Zalo mô phỏng | B — interceptor chặn | [UC_G10](UC_G10.puml) |
| UC-BIL-20 | Phân tích và xuất báo cáo vận hành | P* — report.view, report.export; theo hành vi + scope | [UC_G11](UC_G11.puml) |
| UC-OPS-09 | Tra cứu nhật ký vận hành | B — interceptor chặn | [UC_G11](UC_G11.puml) |
| UC-OPT-01 | Xem dashboard và bản đồ phòng | P* — report.view; theo hành vi + scope | [UC_G11](UC_G11.puml) |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | B — interceptor chặn | [UC_G13](UC_G13.puml) |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | B — interceptor chặn | [UC_G14](UC_G14.puml) |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | B — interceptor chặn | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | B — interceptor chặn | [UC_G14](UC_G14.puml) |

## A04 — Người tìm phòng/người thuê

Role: TENANT. Actor chính trong **31 UC**.

| UC | Mục tiêu | Mức tham gia | Trang module |
| --- | --- | --- | --- |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-03 | Lưu và bỏ lưu phòng yêu thích | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-04 | Lưu bộ lọc và theo dõi tin khớp | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-16 | So sánh các phòng quan tâm | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-17 | Ước tính chi phí thuê phòng | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G02](UC_G02.puml) |
| UC-DIS-08 | Quản lý khung giờ xem phòng | V — chỉ xem dữ liệu liên quan | [UC_G03](UC_G03.puml) |
| UC-DIS-09 | Đặt và quản lý lịch xem của mình | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G03](UC_G03.puml) |
| UC-DIS-10 | Tiếp nhận và hoàn tất lịch xem | V — đổi/hủy của mình tại UC-DIS-09 | [UC_G03](UC_G03.puml) |
| UC-DIS-13.2 | Gửi phản hồi về thử nghiệm tìm phòng | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G16](UC_G16.puml) |
| UC-TNT-12.2 | Lập biên bản bàn giao nhận phòng | V — chỉ xem dữ liệu liên quan | [UC_G03](UC_G03.puml) |
| UC-TNT-12.3 | Xác nhận biên bản bàn giao nhận phòng | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G03](UC_G03.puml) |
| UC-TEN-01 | Xem hồ sơ và tổng quan thuê của mình | P* — Tenant/lease/invoice của mình | [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) |
| UC-TEN-02 | Tra cứu hợp đồng và quyết toán của mình | P* — Tenant/lease/invoice của mình | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TEN-08.1 | Xem người ở cùng hợp đồng | P* — Tenant/lease/invoice của mình | [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) |
| UC-TEN-07.1 | Đề nghị gia hạn thuê | P* — Tenant/lease/invoice của mình | [UC_G07](UC_G07.puml) |
| UC-TEN-07.2 | Đề nghị chuyển phòng | P* — Tenant/lease/invoice của mình | [UC_G07](UC_G07.puml) |
| UC-TEN-07.3 | Đề nghị trả phòng | P* — Tenant/lease/invoice của mình | [UC_G07](UC_G07.puml) |
| UC-TEN-03 | Tra cứu hóa đơn của mình | P* — Tenant/lease/invoice của mình | [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) |
| UC-TEN-04 | Gửi chứng từ chuyển khoản hóa đơn | P* — Tenant/lease/invoice của mình | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-TEN-05 | Thanh toán bằng thẻ mô phỏng | P* — Tenant/lease/invoice của mình | [UC_G08_02_Collections](UC_G08_02_Collections.puml) |
| UC-TEN-08.2 | Chọn kênh nhận nhắc nợ | P* — Tenant/lease/invoice của mình | [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) |
| UC-TEN-06 | Gửi và trao đổi yêu cầu bảo trì | P* — Tenant/lease/invoice của mình | [UC_G09](UC_G09.puml) |
| UC-SUP-04 | Theo dõi thông báo cá nhân | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G10](UC_G10.puml) |
| UC-TEN-09.2 | Trao đổi tin nhắn Zalo mô phỏng | P* — Tenant/lease/invoice của mình | [UC_G10](UC_G10.puml) |
| UC-TEN-09.3 | Đọc và xác nhận thông báo chủ trọ | P* — Tenant/lease/invoice của mình | [UC_G10](UC_G10.puml) |
| UC-DIS-07 | Báo cáo tin phòng không phù hợp | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G13](UC_G13.puml) |
| UC-DIS-12 | Viết sửa và rút đánh giá phòng đã thuê | P* — lease đủ điều kiện đánh giá | [UC_G13](UC_G13.puml) |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | [UC_G13](UC_G13.puml) |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | P* — ticket do mình yêu cầu | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | P* — ticket do mình yêu cầu | [UC_G14](UC_G14.puml) |

## A05 — Quản trị viên nền tảng

Role: ADMIN. Actor chính trong **51 UC**.

| UC | Mục tiêu | Mức tham gia | Trang module |
| --- | --- | --- | --- |
| UC-ADM-07.1 | Thiết lập MFA Admin | P* — MFA: phiên ADMIN + profile; kiểm role trong controller | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | P — tài khoản/phiên của mình | [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-16 | So sánh các phòng quan tâm | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-17 | Ước tính chi phí thuê phòng | V — truy cập công khai, không suy quyền menu | [UC_G02](UC_G02.puml) |
| UC-DIS-13.2 | Gửi phản hồi về thử nghiệm tìm phòng | V — chỉ đọc cấu hình pilot; không gửi phản hồi | [UC_G16](UC_G16.puml) |
| UC-SUP-04 | Theo dõi thông báo cá nhân | P* — admin.notifications.view; theo handler | [UC_G10](UC_G10.puml) |
| UC-ADM-01 | Xem tổng quan nền tảng | P* — admin.dashboard.view; theo handler | [UC_G11](UC_G11.puml) |
| UC-ADM-14 | Tra cứu và xuất nhật ký quản trị | P* — admin.audit.view, admin.audit.export; theo handler | [UC_G11](UC_G11.puml) |
| UC-ADM-16 | Quản lý lịch và tải báo cáo Admin | P* — admin.reports.manage; theo handler | [UC_G11](UC_G11.puml) |
| UC-SUP-05.1 | Giám sát và xử lý sự cố vận hành | P* — admin.operations.view, admin.operations.manage; theo handler | [UC_G11](UC_G11.puml) |
| UC-SUP-05.2 | Theo dõi hàng đợi giao nhận | P* — admin.operations.view, admin.operations.manage; theo handler | [UC_G11](UC_G11.puml) |
| UC-ADM-02 | Tra cứu tài khoản nền tảng | P* — admin.accounts.view, admin.accounts.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | P* — admin.accounts.manage, admin.dashboard.view; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-03.2 | Cập nhật hồ sơ chủ trọ | P* — admin.accounts.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-04.1 | Đình chỉ hoặc khôi phục tài khoản | P* — admin.accounts.suspend; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-04.3 | Thu hồi phiên của tài khoản khác | P* — admin.sessions.revoke, admin.admins.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-05.1 | Mở thông tin cá nhân được che | P* — admin.pii.reveal; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | P* — admin.accounts.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-06.1 | Cấp và quản lý quyền quản trị viên | P* — admin.admins.manage, admin.dashboard.view; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-06.2 | Rà soát quyền Admin định kỳ | P* — admin.admins.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-08 | Tra cứu khu và phòng toàn nền tảng | P* — admin.properties.view; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-09 | Tạo hoặc cập nhật khu thay chủ trọ | P* — admin.properties.manage; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-10 | Tìm kiếm và định vị tài nguyên | P* — admin.dashboard.view; theo handler | [UC_G12](UC_G12.puml) |
| UC-ADM-11 | Tiếp nhận và kiểm duyệt tin cho thuê | P* — admin.dashboard.view, admin.listings.moderate, admin.moderation.bulk; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-11.1 | Xác minh thông tin tin cho thuê | P* — admin.listings.moderate; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-12 | Kiểm duyệt đánh giá và phản hồi phòng | P* — admin.reviews.moderate; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-12.1 | Xử lý báo cáo vi phạm tin đăng | P* — admin.listings.moderate; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-13.1 | Quản lý chính sách kiểm duyệt | P* — admin.moderation.reports, admin.admins.manage; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-13.2 | Xử lý kháng nghị kiểm duyệt | P* — admin.moderation.reports, admin.dashboard.view, admin.moderation.appeals; theo handler | [UC_G13](UC_G13.puml) |
| UC-ADM-13.3 | Đánh giá chất lượng kiểm duyệt | P* — admin.moderation.reports; theo handler | [UC_G13](UC_G13.puml) |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | V — dashboard.view + ownerId của quyết định | [UC_G13](UC_G13.puml) |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | P* — admin.dashboard.view, admin.support.read, admin.support.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | P* — admin.support.read, admin.support.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-02.1 | Cấu hình phân công tự động hỗ trợ | P* — admin.support.read, admin.support.manage, admin.admins.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-02.2 | Cấu hình và theo dõi SLA hỗ trợ | P* — admin.support.read, admin.support.manage, admin.admins.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2 | Quản lý mẫu trả lời hỗ trợ | P* — admin.support.read, admin.support.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2.1 | Hợp nhất hồ sơ hỗ trợ trùng | P* — admin.support.read, admin.support.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | P* — admin.dashboard.view; theo handler | [UC_G14](UC_G14.puml) |
| UC-SUP-03.3 | Lưu bộ lọc xử lý hỗ trợ | P* — admin.support.read, admin.support.manage; theo handler | [UC_G14](UC_G14.puml) |
| UC-ADM-18 | Xét duyệt hồ sơ xác minh chủ trọ | P* — admin.verifications.view, admin.support.read, admin.verifications.manage; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-18.1 | Nộp hồ sơ xác minh chủ trọ | P* — admin.verifications.manage, admin.support.read; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-19 | Trình và xét duyệt hồ sơ khu trọ | P* — admin.properties.view, admin.properties.manage; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-20 | Quản lý danh mục gói dịch vụ | P* — admin.plans.view, admin.plans.manage; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-21 | Gán gói và xem lịch sử đăng ký | P* — admin.plans.view, admin.plans.manage; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-22 | Hủy quyền sử dụng gói đang hiệu lực | P* — admin.plans.manage; theo handler | [UC_G15](UC_G15.puml) |
| UC-ADM-15 | Chuẩn bị đối soát sao kê | P* — admin.finance.read, admin.finance.reconcile; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-15.1 | Duyệt đề xuất đối soát sao kê | P* — admin.finance.read, admin.finance.reconcile; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-17.1 | Cấu hình bật tắt tính năng nền tảng | P* — admin.flags.manage, admin.dashboard.view; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-17.2 | Quản lý nhóm Admin | P* — admin.teams.manage; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-23 | Quản lý danh mục cơ sở trường | P* — admin.campuses.manage; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-24 | Tra cứu giao dịch tài chính nền tảng | P* — admin.finance.read; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-26 | Mô phỏng quyền Admin | P* — admin.permissions.simulate; theo handler | [UC_G16](UC_G16.puml) |
| UC-ADM-27 | Đọc phản hồi thử nghiệm tìm phòng | P* — admin.listings.moderate; theo handler | [UC_G16](UC_G16.puml) |
