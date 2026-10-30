# Đối chiếu nghiệp vụ của 19 sơ đồ tuần tự

Các mã SD tương ứng mục 2.4.4 của báo cáo V4. Cột cuối trong mỗi hình là cơ sở dữ liệu; các điều kiện và phép tính thuộc cột xử lý nghiệp vụ. Bảng này nêu các điểm cần đọc cùng hình khi kiểm tra, không thay thế toàn bộ đặc tả Use Case. Căn cứ source được liệt kê riêng trong `TRUY_VET.md`.

| Mã | Kịch bản | Kết quả và giới hạn cần kiểm tra |
| --- | --- | --- |
| SD-01 | Đăng nhập và duy trì phiên sử dụng | Kiểm tra tài khoản và mật khẩu trước khi tạo phiên; quản trị viên bật xác thực hai lớp phải bổ sung mã. Duy trì phiên do ứng dụng yêu cầu; phiên không hợp lệ yêu cầu đăng nhập lại. |
| SD-02 | Đặt lịch xem phòng và lập hợp đồng từ lịch xem | Lịch được xác nhận khi còn trong tương lai, hoàn tất khi đã đến giờ. Chỉ lập hợp đồng từ lịch hoàn tất; cập nhật phòng, tin và lịch liên quan cùng nhau. Không tự ghi thu cọc trong bước lập từ lịch. |
| SD-03 | Lập hợp đồng thuê phòng và ghi nhận cọc ban đầu | Kiểm tra quyền, phòng, người thuê và hợp đồng hiệu lực. Lưu hợp đồng, tình trạng phòng và cọc cùng lần xử lý; chỉ ghi cọc đã thu khi số tiền đầu vào lớn hơn 0. |
| SD-04 | Đề xuất và xét duyệt biểu phí | Đề xuất chưa có hiệu lực áp giá. Duyệt phải kiểm tra quyền riêng, tháng hiệu lực, kỳ khóa và hóa đơn; giữ lịch sử khi chấp thuận hoặc từ chối. |
| SD-05 | Xem trước và phát hành hóa đơn tháng | Phần xử lý tính tiền từ dữ liệu hợp đồng và chỉ số. Không tạo trùng hóa đơn; tạo hàng loạt bỏ qua hóa đơn đã có, và có lỗi thì không lưu phần hóa đơn mới của đợt. |
| SD-06 | Ghi nhận khoản thu và phân bổ thanh toán | Tiền phân bổ không vượt tiền còn dư hoặc dư nợ, cùng người thuê. Khoản thu và phân bổ được ghi đồng bộ. Tiền chưa phân bổ chưa giảm nợ; gửi lại đúng yêu cầu không ghi tiền lần nữa. |
| SD-07 | Gỡ phân bổ và ghi nhận hoàn tiền khoản thu | Gỡ phân bổ giữ khoản gốc và lưu bút toán đảo. Chỉ ghi hoàn trong phần tiền còn dư; ghi nhận khoản đã hoàn không phải thực hiện chuyển tiền. |
| SD-08 | Gửi và xét duyệt chứng từ thanh toán | Chứng từ chờ duyệt chưa giảm nợ. Chấp thuận kiểm tra dư nợ hiện hành và ghi khoản thu/phân bổ một lần; từ chối có lý do. |
| SD-09 | Thay thế hoặc điều chỉnh hóa đơn | Có lịch sử thanh toán thì không thay thế. Điều chỉnh giảm không làm tổng tiền thấp hơn số đã thanh toán; phí chậm trả cần dư nợ quá hạn. |
| SD-10 | Quyết toán trả phòng và ghi nhận hoàn cọc | Xác nhận phải khớp dữ liệu xem trước. Kết thúc thuê, ghi quyết toán và khấu trừ cọc không tự xóa nợ hóa đơn, cũng không tự chuyển khoản hoàn. Ghi nhận hoàn cọc là thao tác riêng. |
| SD-11 | Gửi, xét duyệt và thực hiện yêu cầu thay đổi thuê | Xét duyệt và thực hiện là hai thao tác riêng. Trả/chuyển phòng cần hợp đồng cũ đã kết thúc và quyết toán; chuyển phòng còn kiểm tra ngày chuyển, phòng đến, sức chứa và giá thuê. |
| SD-12 | Tiếp nhận và hoàn tất yêu cầu bảo trì | Kiểm tra người gửi và phòng đang thuê, quyền phân công và trao đổi. Chỉ lập khoản chi nếu đã chọn ghi chi, tiền lớn hơn 0 và chưa có khoản chi liên kết; không hoàn tất phiếu đã hủy. |
| SD-13 | Xem báo cáo tháng và sao chép dữ liệu CSV | Phần xử lý tổng hợp thanh toán sau bút toán đảo, không lấy tổng khoản thu làm doanh thu. Xuất CSV là sao chép nội dung vào bộ nhớ tạm, không mô tả tải tệp tự động. |
| SD-14 | Đình chỉ và khôi phục tài khoản khách hàng | Không dùng thao tác này cho tài khoản quản trị. Đình chỉ thu hồi phiên, gồm phiên nhân viên của chủ trọ khi có; giữ dữ liệu tài chính. Khôi phục không làm phiên cũ có hiệu lực trở lại. |
| SD-15 | Tra cứu phòng và xử lý kiểm duyệt tin đăng | Tra cứu phòng chỉ đọc. Kiểm duyệt đúng hồ sơ tin, kiểm tra quyền, phân công và dữ liệu hiện hành. Nhận việc là lựa chọn, không phải điều kiện bắt buộc cho mọi trường hợp. |
| SD-16 | Nhập sao kê và xét duyệt đề nghị đối soát | Nhập sao kê có thể tự ghép nếu tìm được khoản phù hợp duy nhất; không phải mọi dòng đều cần lập đề nghị. Với đề nghị thủ công, người lập và người kiểm tra phải là hai tài khoản khác nhau cùng vai trò quản trị viên. Đề nghị chưa làm thay đổi kết quả ghép; khi chấp thuận kiểm tra lại số tiền và tình trạng ghép. Gửi lại đúng lần nhập không lưu trùng. |
| SD-17 | Hỏi hướng dẫn sử dụng và đọc nguồn được phép | Tra cứu kho tài liệu hướng dẫn trong cơ sở dữ liệu, không lấy số liệu vận hành để trả lời. Phần xử lý chọn căn cứ và kiểm tra câu trả lời; mở nguồn kiểm tra lại quyền và hiệu lực. Mô hình tạo câu trả lời được tóm tắt trong trách nhiệm xử lý, không khẳng định không có tích hợp bên ngoài. |
| SD-18 | Xét duyệt hồ sơ xác minh chủ trọ | Không tự duyệt hồ sơ; kiểm tra trạng thái hiện hành. Chấp thuận cần tài khoản hoạt động, phiếu đúng chủ trọ và chứng cứ đã kiểm tra an toàn, không phải chứng cứ chỉ dùng nội bộ. |
| SD-19 | Gán và kết thúc quyền sử dụng gói | Gán cần tài khoản/gói hoạt động, hạn đúng và số khu/phòng trong hạn mức. Gán gói không thu tiền; kết thúc không hoàn tiền và không xóa dữ liệu để ép theo hạn mức. |

Giới hạn: bảng và hình được đối chiếu source tĩnh. Những phần liên quan nhiều thời điểm vẫn giữ chung mã SD theo báo cáo, không được hiểu là toàn bộ diễn ra trong một lần nhấn nút hoặc một giao dịch lưu trữ duy nhất.
