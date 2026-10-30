# Sơ đồ tuần tự cho báo cáo quản lý nhà trọ

Bộ hình ngày 30/10/2026 giữ 19 kịch bản SD-01 đến SD-19 của mục 2.4.4 trong báo cáo V4, diễn đạt lại theo ngôn ngữ nghiệp vụ và thể hiện rõ tương tác với cơ sở dữ liệu. Tệp báo cáo Word gốc và bộ ảnh trước không bị thay đổi.

## Cấu trúc hình

- Tác nhân: người thực hiện thao tác trong nghiệp vụ.
- Giao diện: tiếp nhận thao tác và trình bày kết quả cho người dùng, dùng ký hiệu boundary như mẫu gốc.
- Xử lý nghiệp vụ: kiểm tra quyền, điều kiện, đối chiếu dữ liệu và tính toán, dùng ký hiệu control như mẫu gốc. Mũi tên quay về chính cột này biểu diễn xử lý nội bộ.
- Cơ sở dữ liệu: hình trụ màu vàng, nhận yêu cầu tra cứu hoặc lưu và trả dữ liệu hoặc kết quả lưu. Cột này đại diện cho cơ sở dữ liệu PostgreSQL được cấu hình trong dự án; hình không ghi tên hệ quản trị, bảng, câu lệnh truy vấn hoặc tên hàm.

Đây là sơ đồ tuần tự mức phân tích nghiệp vụ có thể hiện lưu trữ, không phải sơ đồ chỉ có tác nhân và một hệ thống hộp đen, cũng không phải sơ đồ chi tiết từng lời gọi lớp. Các cột xử lý gom trách nhiệm nghiệp vụ, không khẳng định chỉ có một lớp thực thi. Các lần đọc/ghi cùng mục tiêu có thể được tóm tắt thành một cặp thông điệp.

Màu vàng nhạt `#FFFFB9`, nét đỏ nâu `#800000`, đường sống xám nét đứt và phông Times New Roman giữ theo mẫu của báo cáo. Số thông điệp chạy xuyên suốt từng hình.

## Cách kiểm tra

1. Mở từng ảnh theo mã SD tương ứng hình trong báo cáo; không đối chiếu theo số thông điệp cũ vì số được đánh lại.
2. Đọc điều kiện của nhánh trước khi đọc thông điệp trong nhánh. `alt` là các lựa chọn loại trừ; `opt` chỉ xảy ra khi điều kiện được nêu đáp ứng; `loop` là thao tác có thể lặp; `break` dừng kịch bản khi gặp điều kiện lỗi. `group` gom các thay đổi có cùng yêu cầu lưu đồng bộ.
3. Các phần có thao tác mới của chủ trọ, người thuê hoặc quản trị viên có thể diễn ra tại các thời điểm khác nhau. Vị trí nối tiếp trong hình không có nghĩa hệ thống tự thực hiện các thao tác đó.
4. Với các chức năng đã xác thực, đăng nhập và bước điều hướng mở màn hình được coi là điều kiện trước. Các vai trò phải có quyền tương ứng; nhãn chủ trọ không loại trừ nhân viên được phân quyền ở các chức năng có hỗ trợ.
5. Đọc `DOI_CHIEU_KIEM_TRA.md` để xem kết quả và giới hạn cần kiểm tra theo từng kịch bản. Đọc `TRUY_VET.md` để tìm các thao tác trong source dùng làm căn cứ.

## Điểm thay đổi so với bộ ảnh trước

- Khôi phục cột hình trụ cơ sở dữ liệu, không dùng đối tượng entity thay cho database.
- Tách tra cứu, kiểm tra nghiệp vụ và ghi nhận kết quả; không đặt trách nhiệm quyết định hoặc tính toán ở cột cơ sở dữ liệu.
- Những đoạn trước gộp kiểm tra với ghi dữ liệu được tách nhánh thành công và không đủ điều kiện trước khi lưu.
- Giữ các giới hạn nghiệp vụ từ code: chứng từ chờ chưa giảm nợ; chấp thuận yêu cầu thay đổi thuê chưa thực hiện hợp đồng; ghi hoàn tiền không tự chuyển tiền; báo cáo CSV được sao chép vào bộ nhớ tạm.
- Bổ sung rõ nhánh tự ghép khi nhập sao kê có khoản phù hợp duy nhất. Nguyên tắc hai người áp dụng cho đề nghị đối soát thủ công, không mô tả mọi dòng sao kê đều phải chờ người duyệt.
- Không sao chép nguyên tên hàm, mã lỗi kỹ thuật, thông tin token hoặc chi tiết khóa dữ liệu của hình gốc sang hình BA.

## Tệp bàn giao

- `PNG/`: 19 ảnh PNG, một ảnh liền mạch cho mỗi kịch bản, metadata 300 DPI.
- `source/`: nguồn PlantUML, SVG và chương trình dựng lại hình.
- `source/verification.json`: mã băm source đối chiếu, báo cáo gốc và ảnh xuất; kích thước ảnh và vị trí phương thức trong code.
- `TRUY_VET.md`: danh sách source theo từng mã SD.
- `DOI_CHIEU_KIEM_TRA.md`: bảng nghiệp vụ để người dùng kiểm tra bộ hình.

Việc đối chiếu là đọc và phân tích source tĩnh, không phải kiểm thử đầu cuối ứng dụng. Kiểm tra dựng hình xác nhận cú pháp, thứ tự thông điệp, vùng chứa chữ, tính toàn vẹn PNG/ZIP và source không đổi trong quá trình xuất. Không dùng các kiểm tra này để tuyên bố toàn bộ chức năng đã chạy kiểm thử thành công. Khi chèn hình dài vào Word, cần giữ tỷ lệ và kiểm tra cỡ chữ ở kích thước in thực tế; thông số DPI không tự bảo đảm chữ đủ lớn trên trang.
