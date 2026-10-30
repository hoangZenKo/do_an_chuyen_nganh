# Bảo toàn mã Use Case và bảng chuyển hướng

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Quy tắc

Catalog gần nhất 164 mã là baseline ưu tiên, không có nghĩa đặc tả cũ đúng toàn bộ. Giữ 147 mã, bổ sung 15 mã, chuyển hướng/phân loại 17 mã cũ. Không dùng mã chuyển hướng cho mục tiêu mới. Prefix kế thừa lịch sử, không ép bằng nhóm nghiệp vụ mới. Hậu tố không là quan hệ UML.

## 2. Toàn bộ 164 mã catalog gần nhất

| Mã cũ | Tên cũ | Mã đích | Xử lý |
| --- | --- | --- | --- |
| UC-SYS-01 | Đăng ký tài khoản chủ trọ | UC-SYS-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-02 | Đăng ký tài khoản tìm phòng | UC-SYS-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-03 | Đăng nhập | UC-SYS-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | UC-SYS-05.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | UC-SYS-05.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-06 | Khôi phục mật khẩu bằng liên kết một lần | UC-SYS-06 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | UC-SYS-07 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-08 | Kích hoạt tài khoản người thuê từ lời mời | UC-SYS-08 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SYS-09 | Kích hoạt tài khoản nhân viên từ lời mời | UC-SYS-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | UC-DIS-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | UC-DIS-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-03 | Lưu và bỏ lưu phòng yêu thích | UC-DIS-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-04 | Lưu bộ lọc và theo dõi tin khớp | UC-DIS-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-05 | Soạn và sửa bản nháp tin cho thuê | UC-DIS-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-06.1 | Gửi tin cho thuê để kiểm duyệt | UC-DIS-05 | Gộp: Soạn/sửa và gửi kiểm duyệt cùng phục vụ đưa tin của mình ra công khai; gửi duyệt không tạo mục tiêu độc lập ở mức catalog. |
| UC-DIS-06.2 | Ẩn tin cho thuê của mình | UC-DIS-06.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-06.3 | Xác nhận lại tình trạng còn phòng | UC-DIS-05 | Gộp: Xác nhận còn phòng là nhánh duy trì tin cho thuê, không tạo UC chỉ cho một nút cập nhật thời điểm. |
| UC-DIS-07 | Báo cáo tin phòng không phù hợp | UC-DIS-07 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-08 | Quản lý khung giờ xem phòng | UC-DIS-08 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-09 | Đặt và theo dõi lịch xem phòng | UC-DIS-09, UC-DIS-10 | Tái phân ranh giới: Tách mục tiêu người đặt và chủ trọ; đổi/hủy là biến thể, không tạo UC riêng cho từng trạng thái. |
| UC-DIS-10 | Đổi lịch hủy và xử lý lịch xem | UC-DIS-09, UC-DIS-10 | Tái phân ranh giới: Tách mục tiêu người đặt và chủ trọ; đổi/hủy là biến thể, không tạo UC riêng cho từng trạng thái. |
| UC-DIS-11 | Tạo hợp đồng từ lịch xem đã hoàn thành | UC-TNT-05 | Tạo hợp đồng trực tiếp hoặc từ lịch xem cùng đích thiết lập quan hệ thuê. Giữ biến thể lịch COMPLETED → LEASED/ẩn tin, chỉ LANDLORD; không tạo UC hợp đồng trùng ở nhóm tìm phòng. |
| UC-DIS-12 | Viết sửa và rút đánh giá phòng đã thuê | UC-DIS-12 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-13.1 | Trả lời đánh giá phòng | UC-DIS-13.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-13.2 | Gửi phản hồi về thử nghiệm tìm phòng | UC-DIS-13.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-DIS-14 | Xem thông báo hành trình tìm thuê | UC-SUP-04 | Gộp: Đọc/đánh dấu thông báo cá nhân là cùng mục tiêu; giữ nguồn dữ liệu và phạm vi endpoint thành các biến thể, không gộp bảng dữ liệu. |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | UC-DIS-15 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-01 | Xem dashboard và bản đồ phòng | UC-OPT-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-02 | Tra cứu và chọn khu trọ | UC-OPT-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-03.1 | Tạo khu trọ | UC-OPT-03.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | UC-OPT-03.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-04.1 | Lưu trữ khu trọ | UC-OPT-04.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-04.2 | Khôi phục khu trọ đã lưu trữ | UC-OPT-04.1 | Gộp: Lưu trữ/khôi phục là hai chiều của mục tiêu quản lý vòng đời khu, cùng quyền; vẫn giữ hai nhánh kiểm tra điều kiện. |
| UC-OPT-04.3 | Xóa khu trọ chưa có phòng và lịch sử xét duyệt | UC-OPT-04.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | UC-OPT-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-06.1 | Tạo phòng | UC-OPT-06.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-06.2 | Cập nhật thông tin phòng | UC-OPT-06.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-07.1 | Đổi trạng thái sử dụng phòng | UC-OPT-07.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | UC-OPT-07.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-07.3 | Xóa phòng chưa có lịch sử nghiệp vụ | UC-OPT-07.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-08.1 | Quản lý tài sản phòng | UC-OPT-08.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | UC-OPT-08.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ phòng | UC-OPT-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | UC-TNT-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | UC-TNT-02.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | UC-TNT-02.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục người thuê | UC-TNT-02.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-02.4 | Xóa hồ sơ người thuê chưa có lịch sử | UC-TNT-02.4 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-03 | Tạo lời mời truy cập cổng người thuê | UC-TNT-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-03.1 | Tạo trực tiếp tài khoản cho hồ sơ người thuê | UC-TNT-03.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-04 | Tra cứu hợp đồng và cảnh báo hết hạn | UC-TNT-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-05 | Tạo hợp đồng và ghi nhận cọc ban đầu | UC-TNT-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | UC-TNT-06.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-06.2 | Gia hạn hợp đồng | UC-TNT-06.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-06.3 | Kết thúc hợp đồng | UC-TNT-06.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-07 | Tra cứu và ghi giao dịch cọc | UC-TNT-07 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-08 | Xem trước và xác nhận quyết toán trả phòng | UC-TNT-08 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-09 | Ghi nhận đã hoàn cọc theo quyết toán | UC-TNT-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-10 | Xét duyệt yêu cầu vòng đời thuê | UC-TNT-10 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã duyệt | UC-TNT-11 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | UC-TNT-12.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-12.2 | Lập biên bản bàn giao nhận phòng | UC-TNT-12.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-12.3 | Xác nhận biên bản bàn giao nhận phòng | UC-TNT-12.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TNT-13 | Xuất hoặc chia sẻ hợp đồng PDF | UC-TNT-04 | PDF là đầu ra của tra cứu hợp đồng ở tenant_detail_screen cho chủ trọ/nhân viên; chưa thấy cổng TENANT nối shareLeasePdf. Không tạo UC xuất/ký số độc lập. |
| UC-BIL-01 | Ghi chỉ số điện nước theo kỳ | UC-BIL-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-02 | Xem trước và lập hóa đơn một hợp đồng | UC-BIL-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-03 | Lập hóa đơn hàng loạt | UC-BIL-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-04 | Tra cứu hóa đơn và tuổi nợ | UC-BIL-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-05 | Sửa hạn thanh toán hoặc ghi chú hóa đơn | UC-BIL-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-06 | Thay thế hóa đơn chưa có lịch sử thanh toán | UC-BIL-06 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-07 | Phát hành credit note hoặc debit note | UC-BIL-07 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-08.1 | Hủy hóa đơn đủ điều kiện | UC-BIL-08.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-08.2 | Xuất hoặc chia sẻ hóa đơn PDF | UC-BIL-04, UC-TEN-03 | Gộp: Xuất/chia sẻ PDF là lựa chọn đầu ra sau khi được đọc hóa đơn, không phải nghĩa vụ thanh toán mới. |
| UC-BIL-09 | Ghi nhận thanh toán trực tiếp | UC-BIL-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-10 | Tạo khoản thu cho người thuê | UC-BIL-10 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-11 | Phân bổ khoản thu cho hóa đơn | UC-BIL-11 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-12.1 | Giải phóng phân bổ khoản thu | UC-BIL-12.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-12.2 | Đảo thanh toán trực tiếp | UC-BIL-12.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-13 | Ghi nhận hoàn tiền từ khoản thu | UC-BIL-13 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-14 | Xét duyệt chứng từ thanh toán | UC-BIL-14 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-15 | Đề xuất biểu phí theo kỳ hiệu lực | UC-BIL-15 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-16 | Phân tích tác động và duyệt biểu phí | UC-BIL-16 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-17.1 | Cấu hình lập hóa đơn định kỳ | UC-BIL-17.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-17.2 | Xem trước và chạy đợt lập hóa đơn | UC-BIL-17.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-18.1 | Cấu hình chính sách nhắc nợ | UC-BIL-18.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-18.2 | Xếp hàng nhắc nợ theo chính sách | UC-BIL-18.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-18.3 | Theo dõi và thử lại outbox hóa đơn | UC-BIL-18.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-19 | Quản lý khoản chi vận hành | UC-BIL-19 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-20 | Xem báo cáo tháng và chỉ số phân tích | UC-BIL-20 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-21 | Xuất nội dung báo cáo tháng CSV | UC-BIL-20 | Gộp: CSV là đầu ra của mục tiêu xem báo cáo tháng; giữ quyền report.export riêng cho biến thể xuất. |
| UC-BIL-22 | Khóa kỳ thanh toán của khu | UC-BIL-22 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-BIL-23 | Cấu hình tài khoản nhận chuyển khoản | UC-BIL-23 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-01 | Tiếp nhận và theo dõi phiếu bảo trì | UC-OPS-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-02 | Phân công và cập nhật bảo trì | UC-OPS-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-03 | Hoàn tất bảo trì và liên kết khoản chi | UC-OPS-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-04 | Theo dõi việc cần xử lý | UC-OPS-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-05 | Chuẩn bị phòng sau trả phòng | UC-OPS-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-06 | Quản lý việc định kỳ và checklist | UC-OPS-06, UC-OPS-06.1 | Tách: Thiết lập lịch và thực hiện công việc có kết quả bền vững khác nhau; tác vụ sinh tự động không thành Actor hệ thống. |
| UC-OPS-07 | Soạn và phát thông báo người thuê | UC-OPS-07 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-OPS-08 | Theo dõi lượt gửi và gửi nhắc Zalo | UC-SUP-04, UC-BIL-18.2, UC-TEN-09.2 | Phân bổ lại: UC cũ trộn hộp thông báo, nhắc nợ provider và tin test mô phỏng; chuyển về đúng mục tiêu, không mất hành vi. |
| UC-OPS-09 | Tra cứu nhật ký vận hành | UC-OPS-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-01 | Xem hồ sơ và tổng quan thuê của mình | UC-TEN-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-02 | Xem hợp đồng cọc và quyết toán của mình | UC-TEN-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-03 | Xem hóa đơn và PDF của mình | UC-TEN-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-04 | Gửi chứng từ thanh toán | UC-TEN-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-05 | Thanh toán bằng thẻ mô phỏng | UC-TEN-05 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-06 | Gửi và trao đổi yêu cầu bảo trì | UC-TEN-06 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-07 | Gửi hủy và theo dõi yêu cầu vòng đời thuê | UC-TEN-07.1, UC-TEN-07.2, UC-TEN-07.3 | Tách: Gia hạn, chuyển phòng và trả phòng là ba đích nghiệp vụ độc lập, chung hạ tầng request nhưng khác dữ liệu, điều kiện và kết quả. |
| UC-TEN-08.1 | Xem người ở cùng hợp đồng | UC-TEN-08.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-08.2 | Thiết lập sở thích nhắc nợ | UC-TEN-08.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-09.1 | Đọc thông báo cổng người thuê | UC-SUP-04 | Gộp: Đọc/đánh dấu thông báo cá nhân là cùng mục tiêu; giữ nguồn dữ liệu và phạm vi endpoint thành các biến thể, không gộp bảng dữ liệu. |
| UC-TEN-09.2 | Trao đổi tin nhắn mô phỏng Zalo trong portal | UC-TEN-09.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-09.3 | Đọc và xác nhận thông báo chủ trọ | UC-TEN-09.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-TEN-10 | Xem hướng dẫn chuyển khoản của hóa đơn | UC-TEN-04 | Gộp: Xem tài khoản/QR là bước chuẩn bị gửi chứng từ chuyển khoản của cùng hóa đơn; không phải thanh toán tự động. |
| UC-ADM-01 | Xem tổng quan và phân tích nền tảng | UC-ADM-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-02 | Tra cứu tài khoản nền tảng | UC-ADM-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | UC-ADM-03.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-03.2 | Cập nhật hồ sơ chủ trọ | UC-ADM-03.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-04.1 | Đình chỉ tài khoản và vô hiệu phiên | UC-ADM-04.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-04.2 | Khôi phục tài khoản bị đình chỉ | UC-ADM-04.1 | Gộp: Đình chỉ/khôi phục là hai chiều của quản lý quyền hoạt động tài khoản với cùng capability; không phục hồi token đã bị thu hồi. |
| UC-ADM-04.3 | Thu hồi phiên của tài khoản khách hàng | UC-ADM-04.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-05.1 | Mở thông tin cá nhân được che | UC-ADM-05.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | UC-ADM-05.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-06.1 | Quản lý hồ sơ và quyền Admin | UC-ADM-06.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-06.2 | Rà soát quyền Admin định kỳ | UC-ADM-06.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-07.1 | Thiết lập MFA Admin | UC-ADM-07.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-07.2 | Xác minh tăng cường cho thao tác nhạy cảm | TECH-03 | Phân loại lại: Cấp token step-up chỉ hỗ trợ thao tác nhạy cảm; không là mục tiêu nghiệp vụ độc lập. MFA thiết lập vẫn giữ UC. |
| UC-ADM-08 | Tra cứu khu và phòng toàn nền tảng | UC-ADM-08 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-09 | Tạo hoặc cập nhật khu thay chủ trọ | UC-ADM-09 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-10 | Tìm kiếm và định vị tài nguyên | UC-ADM-10 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-11 | Nhận việc và kiểm duyệt tin đăng | UC-ADM-11, UC-ADM-11.1 | Tách: Xác minh thông tin và quyết định công khai là hai mục tiêu khác nhau; verified badge không tự thay thế xét duyệt đăng tin. |
| UC-ADM-12 | Kiểm duyệt đánh giá và báo cáo vi phạm | UC-ADM-12, UC-ADM-12.1 | Tách: Báo cáo tin và review/reply là đối tượng, quyết định và permission độc lập; không cấp quyền reviews cho người chỉ có listings. |
| UC-ADM-13.1 | Quản lý chính sách kiểm duyệt | UC-ADM-13.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-13.2 | Xử lý kháng nghị kiểm duyệt | UC-ADM-13.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-13.3 | Đánh giá chất lượng kiểm duyệt | UC-ADM-13.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-14 | Tra cứu và xuất nhật ký quản trị | UC-ADM-14 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-15 | Đối soát sao kê theo maker checker | UC-ADM-15, UC-ADM-15.1 | Tách: Maker lập và checker duyệt tạo hai kết quả/điều kiện độc lập; cùng role ADMIN nhưng không được tự duyệt đề xuất. |
| UC-ADM-16 | Quản lý lịch và tải báo cáo Admin | UC-ADM-16 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-17.1 | Quản lý feature flags nghiệp vụ | UC-ADM-17.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-17.2 | Quản lý nhóm Admin | UC-ADM-17.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-18 | Nộp và xét duyệt xác minh chủ trọ | UC-ADM-18.1, UC-ADM-18 | Tách: Chủ trọ tự nộp không có quyền xét; bên xét là quản trị có capability. Tách theo mục tiêu và thẩm quyền thực tế. |
| UC-ADM-19 | Trình và xét duyệt hồ sơ khu trọ | UC-ADM-19 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-20 | Quản lý danh mục gói dịch vụ | UC-ADM-20 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-21 | Gán gói và xem lịch sử đăng ký | UC-ADM-21 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-22 | Hủy quyền sử dụng gói đang hiệu lực | UC-ADM-22 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-23 | Quản lý danh mục cơ sở trường | UC-ADM-23 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-24 | Tra cứu giao dịch tài chính nền tảng | UC-ADM-24 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-25 | Theo dõi kích hoạt và thu hồi phiên Admin | UC-ADM-06.1, UC-ADM-04.3 | Phân bổ lại: Tra cứu/gửi lại lời mời thuộc cấp tài khoản Admin; thu hồi phiên thuộc mục tiêu kiểm soát truy cập, không tạo UC lifecycle tổng hợp. |
| UC-ADM-26 | Mô phỏng quyền Admin | UC-ADM-26 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-ADM-27 | Đọc phản hồi thử nghiệm tìm phòng | UC-ADM-27 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-01 | Tạo và trao đổi hồ sơ hỗ trợ | UC-SUP-01, UC-SUP-01.1 | Tách: Người yêu cầu chỉ trao đổi ticket của mình; nhân sự hỗ trợ là ADMIN có capability, quyền nội bộ và mục tiêu xử lý riêng. |
| UC-SUP-02.1 | Cấu hình phân công tự động hỗ trợ | UC-SUP-02.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-02.2 | Cấu hình và theo dõi SLA hỗ trợ | UC-SUP-02.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-03.1 | Đính kèm tệp vào ticket hỗ trợ | UC-SUP-01, UC-SUP-01.1 | Gộp: Tệp quét sạch là chứng cứ kèm trao đổi ticket; không tạo UC cho thao tác tải lên; điều kiện scanner giữ nguyên. |
| UC-SUP-03.2 | Quản lý mẫu nhãn và hợp nhất ticket | UC-SUP-03.2, UC-SUP-03.2.1, UC-SUP-03.2.2, UC-SUP-01.1 | Tách: Mẫu trả lời, hợp nhất hồ sơ và đánh giá sau hỗ trợ có mục tiêu/Actor khác nhau; gán nhãn là nhánh xử lý hồ sơ. |
| UC-SUP-03.3 | Lưu bộ lọc xử lý ticket | UC-SUP-03.3 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-03.4 | Liên kết và xem dòng thời gian hồ sơ hỗ trợ | UC-SUP-01.1 | Gộp: Liên kết tài nguyên/timeline giúp xử lý cùng hồ sơ, không có mục tiêu nghiệp vụ độc lập với hồ sơ hỗ trợ. |
| UC-SUP-04 | Quản lý trung tâm thông báo cá nhân | UC-SUP-04 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-05.1 | Giám sát và xử lý sự cố vận hành | UC-SUP-05.1 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-05.2 | Theo dõi hàng đợi giao nhận | UC-SUP-05.2 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-SUP-06 | Hỏi trợ lý AI và đọc nguồn hướng dẫn | UC-SUP-06 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-STF-01 | Mời nhân viên và cấp phạm vi khu trọ | UC-STF-01 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-STF-02 | Cập nhật quyền trạng thái và phạm vi nhân viên | UC-STF-02 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |
| UC-STF-03 | Mô phỏng quyền nhân viên | UC-STF-03 | Giữ mã; rà lại mục tiêu, quyền và bằng chứng, không bảo lưu nội dung đặc tả cũ. |

## 3. Toàn bộ 63 mã lịch sử trong BA_USE_CASES.md

Đây là crosswalk ngữ nghĩa cho tài liệu cũ hơn, không làm cho Actor/quy tắc hoặc mức ưu tiên trong tài liệu đó trở thành bằng chứng triển khai. Các UC kiểm quyền/chống trùng/log tự động không tiếp tục là mục tiêu nghiệp vụ độc lập.

| Mã lịch sử | Tên lịch sử | Mã đích chuẩn hóa | Lưu ý |
| --- | --- | --- | --- |
| UC-01 | Đăng nhập hệ thống | UC-SYS-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-02 | Đăng xuất hệ thống | UC-SYS-05.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-03 | Khôi phục phiên đăng nhập | TECH-01 | Cơ chế hỗ trợ/quy tắc bên trong UC; không giữ mã này như UC độc lập. |
| UC-04 | Kiểm soát quyền truy cập | TECH-02 | Cơ chế hỗ trợ/quy tắc bên trong UC; không giữ mã này như UC độc lập. |
| UC-05 | Xem danh sách khu trọ | UC-OPT-02 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-06 | Tạo khu trọ mới | UC-OPT-03.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-07 | Cập nhật thông tin khu trọ | UC-OPT-03.2 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-08 | Lưu trữ / khôi phục khu trọ | UC-OPT-04.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-09 | Chọn khu trọ đang quản lý | UC-OPT-02 | Chọn khu là bộ lọc/ngữ cảnh tra cứu, không là UC riêng. |
| UC-10 | Xem danh sách phòng | UC-OPT-05 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-11 | Xem chi tiết phòng | UC-OPT-05 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-12 | Tạo phòng mới | UC-OPT-06.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-13 | Cập nhật thông tin phòng | UC-OPT-06.2 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-14 | Cập nhật trạng thái phòng | UC-OPT-07.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-15 | Vô hiệu hóa / khôi phục phòng | UC-OPT-07.2 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-16 | Xóa phòng | UC-OPT-07.3 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-17 | Xem danh sách người thuê | UC-TNT-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-18 | Tạo hồ sơ người thuê | UC-TNT-02.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-19 | Cập nhật thông tin người thuê | UC-TNT-02.2 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-20 | Xem chi tiết người thuê | UC-TNT-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-21 | Vô hiệu hóa / khôi phục người thuê | UC-TNT-02.3 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-22 | Mời người thuê kích hoạt tài khoản | UC-TNT-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-23 | Tạo hợp đồng thuê phòng | UC-TNT-05 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-24 | Xem chi tiết hợp đồng | UC-TNT-04, UC-TEN-02 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-25 | Xem lịch sử hợp đồng | UC-TNT-04, UC-TEN-02 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-26 | Kết thúc hợp đồng | UC-TNT-06.3 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-27 | Theo dõi trạng thái hợp đồng | UC-TNT-04, UC-TEN-02 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-28 | Ghi chỉ số điện nước | UC-BIL-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-29 | Lập hóa đơn hàng tháng | UC-BIL-02, UC-BIL-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-30 | Kiểm tra trùng hóa đơn | UC-BIL-02, UC-BIL-03 | Cơ chế hỗ trợ/quy tắc bên trong UC; không giữ mã này như UC độc lập. |
| UC-31 | Xem danh sách hóa đơn | UC-BIL-04 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-32 | Xem chi tiết hóa đơn | UC-BIL-04, UC-TEN-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-33 | Ghi nhận thanh toán | UC-BIL-09 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-34 | Theo dõi công nợ | UC-BIL-04 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-35 | Theo dõi hóa đơn quá hạn | UC-BIL-14 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-36 | Hủy hóa đơn | UC-BIL-08.1 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-37 | Xuất / chia sẻ hóa đơn | UC-BIL-04, UC-TEN-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-38 | Tạo yêu cầu bảo trì | UC-OPS-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-39 | Người thuê gửi yêu cầu bảo trì | UC-TEN-06 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-40 | Xem danh sách yêu cầu bảo trì | UC-OPS-01, UC-TEN-06 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-41 | Cập nhật trạng thái bảo trì | UC-OPS-02, UC-OPS-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-42 | Ghi nhận chi phí bảo trì | UC-OPS-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-43 | Tạo khoản chi phí | UC-BIL-19 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-44 | Xem danh sách chi phí | UC-BIL-19 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-45 | Cập nhật chi phí | UC-BIL-19 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-46 | Phân loại chi phí | UC-BIL-19 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-47 | Thống kê chi phí theo danh mục | UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-48 | Gửi thông báo cho người thuê | UC-OPS-07, UC-BIL-18.2 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-49 | Xem danh sách thông báo | UC-SUP-04 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-50 | Người thuê xem thông báo | UC-SUP-04, UC-TEN-09.3 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-51 | Người thuê xem thông tin cá nhân | UC-TEN-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-52 | Người thuê xem hợp đồng hiện tại | UC-TEN-02 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-53 | Người thuê xem hóa đơn | UC-TEN-03 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-54 | Người thuê gửi minh chứng thanh toán | UC-TEN-04 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-55 | Người thuê đổi mật khẩu | UC-SYS-07 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-56 | Xem dashboard tổng quan | UC-OPT-01 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-57 | Xem báo cáo doanh thu | UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-58 | Xem báo cáo công nợ | UC-BIL-04, UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-59 | Xem báo cáo tỷ lệ lấp đầy | UC-OPT-01, UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-60 | Xem báo cáo chi phí | UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-61 | Xem báo cáo lợi nhuận | UC-BIL-20 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |
| UC-62 | Ghi nhận lịch sử hoạt động | TECH-02 | Cơ chế hỗ trợ/quy tắc bên trong UC; không giữ mã này như UC độc lập. |
| UC-63 | Xem lịch sử hoạt động | UC-OPS-09, UC-ADM-14 | Ánh xạ ngữ nghĩa; không xác nhận lại Actor, mô tả hay test của tài liệu lịch sử. |

## 4. Mã mới không có trong baseline 164

| Mã | Tên | Nguồn tạo mã |
| --- | --- | --- |
| UC-SYS-10 | Thiết lập mật khẩu tài khoản được mời | Bổ sung từ code: Làm rõ hai mục tiêu đã có triển khai nhưng catalog cũ gộp vào reset hoặc mời: người nhận lời mời đặt mật khẩu; STAFF chỉ tra cứu nhân sự bằng staff.view. |
| UC-DIS-16 | So sánh các phòng quan tâm | Bổ sung từ code: Catalog 164 chưa bao quát mục tiêu so sánh tối đa 3 tin và bộ ước tính chi phí có logic Flutter; không phải chức năng mới của ứng dụng. |
| UC-DIS-17 | Ước tính chi phí thuê phòng | Bổ sung từ code: Catalog 164 chưa bao quát mục tiêu so sánh tối đa 3 tin và bộ ước tính chi phí có logic Flutter; không phải chức năng mới của ứng dụng. |
| UC-STF-04 | Tra cứu nhân viên và phạm vi được cấp | Bổ sung từ code: Làm rõ hai mục tiêu đã có triển khai nhưng catalog cũ gộp vào reset hoặc mời: người nhận lời mời đặt mật khẩu; STAFF chỉ tra cứu nhân sự bằng staff.view. |
| UC-TEN-07.1 | Đề nghị gia hạn thuê | Tách: Gia hạn, chuyển phòng và trả phòng là ba đích nghiệp vụ độc lập, chung hạ tầng request nhưng khác dữ liệu, điều kiện và kết quả. |
| UC-TEN-07.2 | Đề nghị chuyển phòng | Tách: Gia hạn, chuyển phòng và trả phòng là ba đích nghiệp vụ độc lập, chung hạ tầng request nhưng khác dữ liệu, điều kiện và kết quả. |
| UC-TEN-07.3 | Đề nghị trả phòng | Tách: Gia hạn, chuyển phòng và trả phòng là ba đích nghiệp vụ độc lập, chung hạ tầng request nhưng khác dữ liệu, điều kiện và kết quả. |
| UC-OPS-06.1 | Thực hiện checklist công việc định kỳ | Tách: Thiết lập lịch và thực hiện công việc có kết quả bền vững khác nhau; tác vụ sinh tự động không thành Actor hệ thống. |
| UC-ADM-11.1 | Xác minh thông tin tin cho thuê | Tách: Xác minh thông tin và quyết định công khai là hai mục tiêu khác nhau; verified badge không tự thay thế xét duyệt đăng tin. |
| UC-ADM-12.1 | Xử lý báo cáo vi phạm tin đăng | Tách: Báo cáo tin và review/reply là đối tượng, quyết định và permission độc lập; không cấp quyền reviews cho người chỉ có listings. |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | Tách: Người yêu cầu chỉ trao đổi ticket của mình; nhân sự hỗ trợ là ADMIN có capability, quyền nội bộ và mục tiêu xử lý riêng. Gộp: Tệp quét sạch là chứng cứ kèm trao đổi ticket; không tạo UC cho thao tác tải lên; điều kiện scanner giữ nguyên. Gộp: Liên kết tài nguyên/timeline giúp xử lý cùng hồ sơ, không có mục tiêu nghiệp vụ độc lập với hồ sơ hỗ trợ. Tách: Mẫu trả lời, hợp nhất hồ sơ và đánh giá sau hỗ trợ có mục tiêu/Actor khác nhau; gán nhãn là nhánh xử lý hồ sơ. |
| UC-SUP-03.2.1 | Hợp nhất hồ sơ hỗ trợ trùng | Tách: Mẫu trả lời, hợp nhất hồ sơ và đánh giá sau hỗ trợ có mục tiêu/Actor khác nhau; gán nhãn là nhánh xử lý hồ sơ. |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | Tách: Mẫu trả lời, hợp nhất hồ sơ và đánh giá sau hỗ trợ có mục tiêu/Actor khác nhau; gán nhãn là nhánh xử lý hồ sơ. |
| UC-ADM-18.1 | Nộp hồ sơ xác minh chủ trọ | Tách: Chủ trọ tự nộp không có quyền xét; bên xét là quản trị có capability. Tách theo mục tiêu và thẩm quyền thực tế. |
| UC-ADM-15.1 | Duyệt đề xuất đối soát sao kê | Tách: Maker lập và checker duyệt tạo hai kết quả/điều kiện độc lập; cùng role ADMIN nhưng không được tự duyệt đề xuất. |

Đối với 131 mã của báo cáo .docx được catalog gần nhất viện dẫn: dùng crosswalk đã có trong `/Users/hoang/Rental_room_management/docs/ba/uc-revision-2026-10-29/BA_AS_IS_Dot_1.md:1` rồi chuyển tiếp qua bảng 164 mã ở mục 2. Đợt này không tuyên bố đọc lại/hiệu chỉnh toàn bộ .docx đó.
