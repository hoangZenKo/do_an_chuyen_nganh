# Sơ đồ tuần tự BA - bộ vẽ lại

## Phạm vi và cách đọc

- Giữ 19 mã SD-01 đến SD-19 tương ứng 19 kịch bản trong phần 2.4.4 của báo cáo V4. Không thay đổi tệp Word gốc.
- Đây là sơ đồ tuần tự mức phân tích với ký hiệu tác nhân, giao diện, điều phối nghiệp vụ và hồ sơ nghiệp vụ. Không phải sơ đồ lời gọi giữa các lớp phần mềm.
- Màu vàng nhạt #FFFFB9, nét đỏ nâu #800000, nền trắng, đường sống xám nét đứt và thanh thực thi được giữ theo mẫu báo cáo.
- Đối tượng hồ sơ dùng ký hiệu entity trong mô hình phân tích; không đặt tên hệ quản trị dữ liệu và không diễn tả câu lệnh lưu trữ.
- Các lifeline hồ sơ gom các dữ kiện cùng mục tiêu nghiệp vụ, không khẳng định chúng là một bảng hoặc một lớp trong code. Nhãn “đối chiếu / lưu khi hợp lệ” tóm tắt trách nhiệm nghiệp vụ, không mô tả vị trí thực thi từng kiểm tra trong phần mềm.
- Các bước trước khi mở màn hình, đăng nhập của các nghiệp vụ đã xác thực và chi tiết lưu tệp minh chứng không được mở rộng thành luồng riêng trong hình.
- Tên hình được chuyển sang ngôn ngữ BA; mã SD là khóa đối chiếu với báo cáo. Các kịch bản báo cáo vốn có nhiều hành động liên quan được giữ dưới cùng mã SD, không tuyên bố mỗi kịch bản là một Use Case độc lập mới.
- Quyền của tác nhân phải được cấp cho hành động tương ứng; các nhãn chủ trọ thể hiện tác nhân chính, không phủ nhận quyền của nhân viên được phân quyền ở các chức năng code có hỗ trợ.
- Trong SD-16, hai người cùng thuộc vai trò Quản trị viên. Không tạo thêm vai trò hệ thống “người lập” hay “người kiểm tra”. Kiểm tra độc lập không được do cùng tài khoản lập đề nghị thực hiện.
- `alt` chọn nhánh theo điều kiện; các nhánh thành công được hiểu là đã qua điều kiện từ chối chung. `opt` là hành động có lựa chọn/điều kiện; các phần xử lý ở những thời điểm khác nhau không phải thao tác tự động nối tiếp. `loop` chỉ dùng cho gửi lại đăng nhập và trao đổi bảo trì có lặp thực tế.

## Những điểm nghiệp vụ đã đối chiếu lại

- SD-01: yêu cầu bổ sung mã chỉ áp dụng khi quản trị viên đã bật xác thực hai lớp. Gửi mã là gửi lại yêu cầu đăng nhập; duy trì phiên là tương tác tự động của ứng dụng, không phải chức năng do người dùng bấm “gia hạn”.
- SD-02/03: lập hợp đồng từ lịch xem không tự ghi thu cọc. Lập hợp đồng trực tiếp có tiền cọc ban đầu lớn hơn 0 mới ghi khoản đã thu. Lịch xem phải được xác nhận và đến giờ mới ghi hoàn tất.
- SD-04: duyệt biểu phí kiểm tra lại kỳ đã có hóa đơn, kỳ đã khóa, thứ tự tháng hiệu lực và tháng trong quá khứ. Đề xuất chưa duyệt không có hiệu lực áp giá.
- SD-05: tạo hàng loạt bỏ qua hợp đồng đã có hóa đơn. Nếu phần tạo mới gặp lỗi thì không lưu hóa đơn mới nào của đợt; không mô tả thành công/thất bại độc lập cho từng phòng.
- SD-06/07: phân bổ không vượt tiền còn dư hoặc nợ hóa đơn; không phân bổ sang người thuê khác. Tiền chưa phân bổ không tự làm giảm nợ. Gỡ phân bổ ghi bút toán đảo và giữ khoản gốc. Hoàn tiền là ghi nhận, không thực hiện chuyển tiền. Gửi lại cùng yêu cầu trả kết quả đã có; không lặp tiền.
- SD-08: chứng từ chờ duyệt giữ phần dư nợ còn được gửi chứng từ khác nhưng chưa ghi giảm nợ. Chấp thuận phải kiểm tra lại số nợ, trạng thái và quyền, sau đó ghi thu/phân bổ một lần. Hóa đơn dùng thử không nhận chứng từ tiền thật.
- SD-09: hóa đơn có lịch sử thanh toán không được thay thế. Khoản giảm không được làm tổng tiền thấp hơn tiền đã thanh toán; phí chậm trả cần dư nợ quá hạn.
- SD-10: xác nhận phải khớp bản xem trước. Quyết toán không tự tất toán hóa đơn còn nợ và không đồng nghĩa đã chuyển cọc. Ghi nhận hoàn cọc là bước riêng; kiểm tra lại số dư và tránh lặp.
- SD-11: chấp thuận và thực hiện là hai hành động riêng. Trả/chuyển phòng phải có hợp đồng cũ đã kết thúc và quyết toán; chuyển phòng còn kiểm tra ngày, sức chứa, giá thuê và phòng đích. Gia hạn có điều kiện riêng.
- SD-12: chỉ tạo khoản chi khi đã chọn ghi chi, chi phí lớn hơn 0 và chưa có khoản chi liên kết. Không đổi chi phí đã gắn khoản chi và không hoàn tất phiếu đã hủy.
- SD-13: thu báo cáo dựa trên thanh toán và bút toán đảo, không dùng tổng khoản thu chưa phân bổ. Xuất CSV hiện tại sao chép nội dung vào bộ nhớ tạm, không tải tệp tự động.
- SD-14: không đình chỉ tài khoản quản trị bằng thao tác tài khoản khách hàng. Đình chỉ chủ trọ thu hồi cả phiên nhân viên; không xóa dữ liệu tài chính. Khôi phục không làm phiên cũ có hiệu lực trở lại.
- SD-15: tra cứu phòng chỉ đọc; kiểm duyệt dùng đúng hồ sơ tin và quyền riêng. Nhận việc là lựa chọn; không đặt ra quy tắc bắt buộc nhận việc khi code không yêu cầu. Không được xử lý công việc đã phân cho người khác nếu không có quyền quản lý tương ứng.
- SD-16: đề nghị chưa làm thay đổi kết quả đối soát. Người duyệt phải khác người lập; chấp thuận kiểm tra lại khoản thu, số tiền và tình trạng ghép hiện hành. Khoản thu được đối soát một lần, không đếm theo số phân bổ.
- SD-17: trợ lý hướng dẫn không lấy số liệu hoạt động trực tiếp. Chỉ trả câu trả lời có căn cứ; nguồn bị thay đổi/thu hồi không được dùng tiếp. Mở nguồn kiểm tra lại quyền, không dựa riêng vào quyền lúc hỏi.
- SD-18: không tự xét duyệt, chỉ xử lý hồ sơ còn chờ và chưa đổi. Chấp thuận cần chủ trọ hoạt động, phiếu hỗ trợ đúng chủ trọ chưa gộp, tệp chứng cứ không nội bộ thuộc loại đã kiểm tra an toàn. Chi tiết triển khai là `SUPPORT_CLEAN`, không đưa mã này vào hình.
- SD-19: gán gói không thu tiền, kết thúc gói không hoàn tiền; không xóa khu/phòng để cưỡng chế hạn mức.

## Tệp bàn giao và kiểm tra

- `PNG/`: 19 ảnh hoàn chỉnh, metadata 300 DPI, nền trắng, không có watermark.
- `source/SD-xx.puml` và `source/SD-xx.svg`: nguồn UML và bản vector để chỉnh sửa khi cần.
- `TRUY_VET.md`: nguồn code đối chiếu cho từng kịch bản.
- `source/verification.json`: kích thước, mã băm ảnh, nguồn đối chiếu và báo cáo gốc để kiểm tra tính toàn vẹn.
- Kiểm tra tĩnh nội dung từ code; không coi đây là kết quả chạy kiểm thử các chức năng của ứng dụng.
- Cú pháp UML, số thứ tự thông điệp, vùng chứa chữ, màu ký hiệu, tệp PNG và ZIP được kiểm tra tự động. Ảnh sau render được mở để kiểm tra trực quan.
- Khi chèn hình dài vào Word, dùng một trang riêng, giữ tỷ lệ ảnh và kiểm tra cỡ chữ tại kích thước in thực tế; DPI không thay thế việc đặt kích thước phù hợp trong tài liệu.
