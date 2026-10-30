# Phân rã chức năng theo nghiệp vụ

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

Đây là AS-IS theo mã nguồn, không phải yêu cầu tương lai hoặc xác nhận nghiệm thu production. Không viết đặc tả chi tiết, không vẽ UML Use Case Diagram.

## 1. Cách đọc

Nút gốc: **Hệ thống quản lý và tìm thuê nhà trọ**. Cấp 1: 16 nhóm; cấp 2: chức năng tổng hợp; cấp 3: mục tiêu UC. Mỗi UC xuất hiện đúng một nơi; không nhân bản chức năng dùng chung. FDD không thể hiện Actor, thứ tự, trạng thái hay include/extend. Cơ chế kỹ thuật và ứng viên thiếu bằng chứng có register riêng, không giả thành UC nghiệp vụ.

## 2. Cây chức năng

### G01 — Tài khoản và an toàn truy cập

- **G01.1 Đăng ký và kích hoạt**
  - Đăng ký tài khoản chủ trọ — UC-SYS-01
  - Đăng ký tài khoản tìm phòng — UC-SYS-02
  - Kích hoạt tài khoản người thuê từ lời mời — UC-SYS-08
  - Kích hoạt tài khoản nhân viên từ lời mời — UC-SYS-09
  - Thiết lập mật khẩu tài khoản được mời — UC-SYS-10
- **G01.2 Đăng nhập và quản lý phiên**
  - Đăng nhập — UC-SYS-03
  - Đăng xuất phiên hiện tại — UC-SYS-05.1
  - Xem và thu hồi các phiên của mình — UC-SYS-05.2
- **G01.3 Bảo vệ tài khoản**
  - Khôi phục mật khẩu bằng liên kết một lần — UC-SYS-06 [Một phần]
  - Đổi mật khẩu khi đang đăng nhập — UC-SYS-07
  - Thiết lập MFA Admin — UC-ADM-07.1

### G02 — Tìm và lựa chọn phòng

- **G02.1 Khám phá phòng**
  - Tìm và lọc tin phòng công khai — UC-DIS-01
  - Xem chi tiết tin và đánh giá công khai — UC-DIS-02
- **G02.2 Lưu nhu cầu và theo dõi tin**
  - Lưu và bỏ lưu phòng yêu thích — UC-DIS-03
  - Lưu bộ lọc và theo dõi tin khớp — UC-DIS-04
- **G02.3 Đánh giá lựa chọn**
  - So sánh các phòng quan tâm — UC-DIS-16
  - Ước tính chi phí thuê phòng — UC-DIS-17

### G03 — Đăng tin, lịch xem và nhận phòng

- **G03.1 Quảng bá phòng cho thuê**
  - Quản lý và gửi duyệt tin cho thuê — UC-DIS-05
  - Ẩn tin cho thuê của mình — UC-DIS-06.2
- **G03.2 Tổ chức xem phòng**
  - Quản lý khung giờ xem phòng — UC-DIS-08
  - Đặt và quản lý lịch xem của mình — UC-DIS-09
  - Tiếp nhận và hoàn tất lịch xem — UC-DIS-10
- **G03.3 Chốt thuê và bàn giao**
  - Lập biên bản bàn giao nhận phòng — UC-TNT-12.2
  - Xác nhận biên bản bàn giao nhận phòng — UC-TNT-12.3

### G04 — Khu trọ và cơ sở vật chất

- **G04.1 Danh mục và vòng đời khu trọ**
  - Tra cứu khu trọ — UC-OPT-02
  - Tạo khu trọ — UC-OPT-03.1
  - Cập nhật thông tin khu trọ — UC-OPT-03.2
  - Lưu trữ hoặc khôi phục khu trọ — UC-OPT-04.1
  - Xóa khu trọ đủ điều kiện — UC-OPT-04.3
- **G04.2 Danh mục và vòng đời phòng**
  - Tra cứu phòng và lịch sử liên quan — UC-OPT-05
  - Tạo phòng — UC-OPT-06.1
  - Cập nhật thông tin phòng — UC-OPT-06.2
  - Đổi trạng thái sử dụng phòng — UC-OPT-07.1
  - Vô hiệu hóa hoặc khôi phục phòng — UC-OPT-07.2
  - Xóa phòng đủ điều kiện — UC-OPT-07.3
- **G04.3 Tài sản, kiểm tra và phí phòng**
  - Quản lý tài sản phòng — UC-OPT-08.1
  - Theo dõi lịch kiểm tra phòng — UC-OPT-08.2
  - Quản lý phiên bản phí dịch vụ phòng — UC-OPT-09

### G05 — Nhân sự và ủy quyền vận hành

- **G05.1 Nhân sự và phạm vi làm việc**
  - Mời nhân viên và cấp phạm vi khu trọ — UC-STF-01
  - Cập nhật quyền trạng thái và phạm vi nhân viên — UC-STF-02
  - Tra cứu nhân viên và phạm vi được cấp — UC-STF-04
- **G05.2 Kiểm tra ủy quyền**
  - Mô phỏng quyền nhân viên — UC-STF-03

### G06 — Hồ sơ thuê, hợp đồng và tiền cọc

- **G06.1 Hồ sơ và tài khoản người thuê**
  - Tra cứu hồ sơ người thuê và tổng quan — UC-TNT-01
  - Tạo hồ sơ người thuê — UC-TNT-02.1
  - Cập nhật hồ sơ người thuê — UC-TNT-02.2
  - Vô hiệu hóa hoặc khôi phục người thuê — UC-TNT-02.3
  - Xóa hồ sơ người thuê đủ điều kiện — UC-TNT-02.4
  - Tạo lời mời truy cập cổng người thuê — UC-TNT-03
  - Tạo trực tiếp tài khoản cho hồ sơ người thuê — UC-TNT-03.1
  - Xem hồ sơ và tổng quan thuê của mình — UC-TEN-01
- **G06.2 Điều khoản và trạng thái hợp đồng**
  - Tra cứu và xuất hợp đồng thuê — UC-TNT-04
  - Lập hợp đồng thuê phòng — UC-TNT-05
  - Cập nhật điều khoản hợp đồng — UC-TNT-06.1
  - Gia hạn hợp đồng — UC-TNT-06.2
  - Kết thúc hợp đồng — UC-TNT-06.3
  - Tra cứu hợp đồng và quyết toán của mình — UC-TEN-02
- **G06.3 Tiền cọc và người ở cùng**
  - Tra cứu và ghi giao dịch cọc — UC-TNT-07
  - Quản lý người ở cùng hợp đồng — UC-TNT-12.1
  - Xem người ở cùng hợp đồng — UC-TEN-08.1

### G07 — Vòng đời thuê và quyết toán

- **G07.1 Đề nghị thay đổi quan hệ thuê**
  - Đề nghị gia hạn thuê — UC-TEN-07.1
  - Đề nghị chuyển phòng — UC-TEN-07.2
  - Đề nghị trả phòng — UC-TEN-07.3
- **G07.2 Xét và thực hiện thay đổi**
  - Xét duyệt yêu cầu vòng đời thuê — UC-TNT-10
  - Thực thi yêu cầu vòng đời đã duyệt — UC-TNT-11
- **G07.3 Quyết toán và hoàn cọc**
  - Xem trước và xác nhận quyết toán trả phòng — UC-TNT-08
  - Ghi nhận đã hoàn cọc theo quyết toán — UC-TNT-09

### G08 — Hóa đơn, thu tiền và công nợ

- **G08.1 Chỉ số và phát hành hóa đơn**
  - Ghi chỉ số điện nước theo kỳ — UC-BIL-01
  - Xem trước và lập hóa đơn một hợp đồng — UC-BIL-02
  - Lập hóa đơn hàng loạt — UC-BIL-03
  - Cấu hình lập hóa đơn định kỳ — UC-BIL-17.1
  - Xem trước và chạy đợt lập hóa đơn — UC-BIL-17.2
- **G08.2 Công nợ và điều chỉnh nghĩa vụ**
  - Tra cứu hóa đơn và công nợ — UC-BIL-04
  - Sửa hạn thanh toán hoặc ghi chú hóa đơn — UC-BIL-05
  - Thay thế hóa đơn chưa có lịch sử thanh toán — UC-BIL-06
  - Điều chỉnh tăng hoặc giảm hóa đơn — UC-BIL-07
  - Hủy hóa đơn đủ điều kiện — UC-BIL-08.1
  - Tra cứu hóa đơn của mình — UC-TEN-03
- **G08.3 Ghi nhận, phân bổ và hoàn thu**
  - Ghi nhận thanh toán trực tiếp — UC-BIL-09
  - Tạo khoản thu cho người thuê — UC-BIL-10
  - Phân bổ khoản thu cho hóa đơn — UC-BIL-11
  - Giải phóng phân bổ khoản thu — UC-BIL-12.1
  - Đảo thanh toán trực tiếp — UC-BIL-12.2
  - Ghi nhận hoàn tiền từ khoản thu — UC-BIL-13
- **G08.4 Chứng từ và kênh thanh toán**
  - Xét duyệt chứng từ thanh toán — UC-BIL-14
  - Cấu hình tài khoản nhận chuyển khoản — UC-BIL-23
  - Gửi chứng từ chuyển khoản hóa đơn — UC-TEN-04
  - Thanh toán bằng thẻ mô phỏng — UC-TEN-05 [Đã triển khai — DEMO]
- **G08.5 Biểu phí và kiểm soát kỳ**
  - Đề xuất biểu phí theo kỳ hiệu lực — UC-BIL-15
  - Phân tích tác động và duyệt biểu phí — UC-BIL-16
  - Khóa kỳ thanh toán của khu — UC-BIL-22
- **G08.6 Nhắc nợ và theo dõi gửi**
  - Cấu hình chính sách nhắc nợ — UC-BIL-18.1
  - Gửi nhắc nợ theo chính sách — UC-BIL-18.2 [Một phần]
  - Theo dõi và thử lại outbox hóa đơn — UC-BIL-18.3
  - Chọn kênh nhận nhắc nợ — UC-TEN-08.2

### G09 — Bảo trì và chi phí vận hành

- **G09.1 Yêu cầu và điều phối bảo trì**
  - Gửi và trao đổi yêu cầu bảo trì — UC-TEN-06
  - Tiếp nhận và theo dõi phiếu bảo trì — UC-OPS-01
  - Phân công và cập nhật bảo trì — UC-OPS-02
- **G09.2 Hoàn thành và ghi chi phí**
  - Hoàn tất bảo trì và liên kết khoản chi — UC-OPS-03
  - Quản lý khoản chi vận hành — UC-BIL-19

### G10 — Công việc, thông tin và hỗ trợ sử dụng

- **G10.1 Việc cần làm và chuẩn bị phòng**
  - Theo dõi việc cần xử lý — UC-OPS-04
  - Chuẩn bị phòng sau trả phòng — UC-OPS-05
- **G10.2 Vận hành lặp lại**
  - Thiết lập lịch công việc định kỳ — UC-OPS-06
  - Thực hiện checklist công việc định kỳ — UC-OPS-06.1
- **G10.3 Trao đổi và thông báo**
  - Soạn và phát thông báo người thuê — UC-OPS-07
  - Theo dõi thông báo cá nhân — UC-SUP-04
  - Trao đổi tin nhắn Zalo mô phỏng — UC-TEN-09.2 [Đã triển khai — MÔ PHỎNG]
  - Đọc và xác nhận thông báo chủ trọ — UC-TEN-09.3
- **G10.4 Hướng dẫn sử dụng theo tri thức**
  - Hỏi trợ lý AI và đọc nguồn hướng dẫn — UC-SUP-06 [Một phần]

### G11 — Báo cáo và giám sát vận hành

- **G11.1 Theo dõi kinh doanh**
  - Xem dashboard và bản đồ phòng — UC-OPT-01
  - Phân tích và xuất báo cáo vận hành — UC-BIL-20
  - Xem tổng quan nền tảng — UC-ADM-01
- **G11.2 Nhật ký kiểm tra**
  - Tra cứu nhật ký vận hành — UC-OPS-09
  - Tra cứu và xuất nhật ký quản trị — UC-ADM-14
- **G11.3 Báo cáo định kỳ nền tảng**
  - Quản lý lịch và tải báo cáo Admin — UC-ADM-16
- **G11.4 Sự cố và chất lượng giao nhận**
  - Giám sát và xử lý sự cố vận hành — UC-SUP-05.1
  - Theo dõi hàng đợi giao nhận — UC-SUP-05.2 [Một phần]

### G12 — Tài khoản và tài nguyên nền tảng

- **G12.1 Tài khoản khách hàng**
  - Tra cứu tài khoản nền tảng — UC-ADM-02
  - Tạo hoặc mời tài khoản chủ trọ — UC-ADM-03.1 [Một phần]
  - Cập nhật hồ sơ chủ trọ — UC-ADM-03.2
  - Đình chỉ hoặc khôi phục tài khoản — UC-ADM-04.1
  - Thu hồi phiên của tài khoản khác — UC-ADM-04.3
  - Mở thông tin cá nhân được che — UC-ADM-05.1
  - Yêu cầu khôi phục truy cập cho tài khoản — UC-ADM-05.2 [Một phần]
- **G12.2 Nhân sự quản trị và rà soát quyền**
  - Cấp và quản lý quyền quản trị viên — UC-ADM-06.1 [Một phần]
  - Rà soát quyền Admin định kỳ — UC-ADM-06.2
- **G12.3 Tài nguyên và ngữ cảnh toàn nền tảng**
  - Tra cứu khu và phòng toàn nền tảng — UC-ADM-08
  - Tạo hoặc cập nhật khu thay chủ trọ — UC-ADM-09
  - Tìm kiếm và định vị tài nguyên — UC-ADM-10

### G13 — Kiểm duyệt và chất lượng nội dung

- **G13.1 Đánh giá và phản ánh nội dung**
  - Báo cáo tin phòng không phù hợp — UC-DIS-07
  - Viết sửa và rút đánh giá phòng đã thuê — UC-DIS-12
  - Trả lời đánh giá phòng — UC-DIS-13.1
- **G13.2 Quyết định nội dung và xác minh tin**
  - Tiếp nhận và kiểm duyệt tin cho thuê — UC-ADM-11
  - Xác minh thông tin tin cho thuê — UC-ADM-11.1
  - Kiểm duyệt đánh giá và phản hồi phòng — UC-ADM-12
  - Xử lý báo cáo vi phạm tin đăng — UC-ADM-12.1
- **G13.3 Kháng nghị, chính sách và chất lượng**
  - Xem quyết định và gửi kháng nghị kiểm duyệt — UC-DIS-15
  - Quản lý chính sách kiểm duyệt — UC-ADM-13.1
  - Xử lý kháng nghị kiểm duyệt — UC-ADM-13.2
  - Đánh giá chất lượng kiểm duyệt — UC-ADM-13.3

### G14 — Dịch vụ hỗ trợ khách hàng

- **G14.1 Đề nghị và xử lý hỗ trợ**
  - Gửi và theo dõi yêu cầu hỗ trợ — UC-SUP-01 [Một phần]
  - Tiếp nhận và xử lý hồ sơ hỗ trợ — UC-SUP-01.1 [Một phần]
  - Hợp nhất hồ sơ hỗ trợ trùng — UC-SUP-03.2.1
  - Đánh giá kết quả hỗ trợ — UC-SUP-03.2.2
- **G14.2 Năng lực xử lý và SLA**
  - Cấu hình phân công tự động hỗ trợ — UC-SUP-02.1
  - Cấu hình và theo dõi SLA hỗ trợ — UC-SUP-02.2
- **G14.3 Công cụ làm việc của bộ phận hỗ trợ**
  - Quản lý mẫu trả lời hỗ trợ — UC-SUP-03.2
  - Lưu bộ lọc xử lý hỗ trợ — UC-SUP-03.3

### G15 — Hồ sơ xác minh và gói dịch vụ

- **G15.1 Hồ sơ xác minh và xét duyệt khu**
  - Nộp hồ sơ xác minh chủ trọ — UC-ADM-18.1
  - Xét duyệt hồ sơ xác minh chủ trọ — UC-ADM-18
  - Trình và xét duyệt hồ sơ khu trọ — UC-ADM-19
- **G15.2 Gói và quyền sử dụng dịch vụ**
  - Quản lý danh mục gói dịch vụ — UC-ADM-20
  - Gán gói và xem lịch sử đăng ký — UC-ADM-21
  - Hủy quyền sử dụng gói đang hiệu lực — UC-ADM-22

### G16 — Quản trị chính sách và đối soát nền tảng

- **G16.1 Đối soát và kiểm soát tài chính**
  - Chuẩn bị đối soát sao kê — UC-ADM-15
  - Duyệt đề xuất đối soát sao kê — UC-ADM-15.1
  - Tra cứu giao dịch tài chính nền tảng — UC-ADM-24
- **G16.2 Tổ chức và chính sách quyền**
  - Cấu hình bật tắt tính năng nền tảng — UC-ADM-17.1
  - Quản lý nhóm Admin — UC-ADM-17.2
  - Mô phỏng quyền Admin — UC-ADM-26
- **G16.3 Danh mục và phản hồi thử nghiệm**
  - Quản lý danh mục cơ sở trường — UC-ADM-23
  - Gửi phản hồi về thử nghiệm tìm phòng — UC-DIS-13.2
  - Đọc phản hồi thử nghiệm tìm phòng — UC-ADM-27

## 3. Các ranh giới quan trọng

| Ranh giới | Cách thể hiện |
| --- | --- |
| Lịch xem → hợp đồng | G03 xử lý lịch; lập hợp đồng ở UC-TNT-05 G06 với biến thể lịch COMPLETED, không có UC hợp đồng trùng. |
| Đề nghị → duyệt → thực hiện | G07 giữ ba mục tiêu đề nghị, quyết định xét và thực hiện theo trạng thái; không coi APPROVED là đã thay lease. |
| Kết thúc → quyết toán → chuẩn bị phòng | Kết thúc ở G06; nghĩa vụ/cọc ở G07; sẵn sàng cho thuê ở G10. |
| Phí phòng → biểu phí hóa đơn | Thông tin phí phòng G04 và đề xuất/duyệt theo kỳ G08 có kết quả/quyền riêng. |
| Thông báo cá nhân → Announcement | Hộp thư UC-SUP-04 khác đọc/xác nhận thông báo chủ trọ có receipt UC-TEN-09.3. |
| User TENANT → Tenant/Lease | Đăng ký tìm phòng không tự có hồ sơ thuê/hợp đồng hoặc quyền cổng thuê. |
| Xác minh registry → xác minh tin | Hồ sơ chủ trọ/khu G15 khác flag xác minh tin và kiểm duyệt nội dung G13. |
| Báo cáo → đối soát | G11 theo dõi/xuất; G16 ghép sao kê maker/checker, không chuyển tiền. |
