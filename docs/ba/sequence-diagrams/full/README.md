# Bộ biểu đồ tuần tự chính thức

Ngày đối chiếu 6 tháng 10 năm 2026. Bộ này mô tả 10 kịch bản trọng tâm, liên quan 15 UC, chia thành 22 hình. Không phải bộ 67 sơ đồ cho toàn bộ 67 UC.

## Tài nguyên

- `../../SEQUENCE_DIAGRAM_SPECIFICATION.docx`: Word chi tiết, gồm điều kiện trước, đầu vào, điều kiện sau, giới hạn, các hình và bảng diễn giải từng thông điệp.
- `../../SEQUENCE_DIAGRAM_SPECIFICATION.md`: đặc tả Markdown, bổ sung đối chiếu luồng chính, thay thế và ngoại lệ từ tài liệu Use Case.
- `SEQUENCE_DIAGRAMS.drawio`: 22 trang nguồn chỉnh sửa được, không chứa ảnh PNG nhúng. Các ký hiệu, lifeline, activation, mũi tên, khung nhánh và nhãn là đối tượng riêng.
- `sd-*.png`: ảnh RGB nền trắng, kích thước gấp đôi SVG để đưa vào Word.
- `sd-*.svg`: vector có chữ SVG thật; không có foreignObject hoặc bitmap chữ nhúng.
- `sd-*.drawio`: nguồn riêng cho từng hình.
- `model.json`: nội dung chuẩn, nhánh tương tác, UC và truy vết nguồn.
- `manifest.json`: kích thước, số thông điệp, loại fragment và hash từng tệp.

## Form và quy ước

Vàng nhạt #FFFFB9, đỏ nâu #800000, Tahoma với Arial dự phòng; không có khung bao ngoài và tab sd. Chỉ giữ khung nhánh UML alt, opt, loop, break và ref. Đây là form mô phỏng StarUML cổ điển, không phải tệp xuất StarUML hoặc dự án mdj.

SD-01 chính thức là đăng nhập; SD-04 là tạo hợp đồng. Bộ demo tạo hợp đồng SD-01 cũ được giữ tại thư mục cha làm lịch sử duyệt form. Không dùng mã demo để đối chiếu với danh mục chính thức.

## Phạm vi kịch bản

- SD-01 Đăng nhập và điều hướng theo vai trò — SD-01A, SD-01B, SD-01C
- SD-02 Mời và kích hoạt tài khoản người thuê — SD-02A, SD-02B
- SD-03 Admin tạo tài khoản chủ trọ — SD-03A
- SD-04 Tạo hợp đồng thuê phòng — SD-04A, SD-04B
- SD-05 Kết thúc hợp đồng và giải phóng phòng — SD-05A
- SD-06 Lập hóa đơn cho một hợp đồng — SD-06A, SD-06B
- SD-07 Ghi nhận thanh toán hóa đơn — SD-07A, SD-07B
- SD-08 Gửi và xét duyệt minh chứng thanh toán — SD-08A, SD-08B, SD-08C, SD-08D
- SD-09 Gửi xử lý và hoàn tất bảo trì — SD-09A, SD-09B, SD-09C
- SD-10 Xem và xuất báo cáo tháng — SD-10A, SD-10B

## Tái tạo và kiểm tra

Tại thư mục này chạy `python3 build.py`, rồi `python3 build_document.py`, sau cùng `python3 validate.py`. Cần Pillow, python-docx, Tahoma trên macOS và Node Sharp. Script dùng Node và Sharp của runtime Codex đã cấu hình trên máy hiện tại. Không cần Java, PlantUML hoặc cài StarUML.

Nếu thay nội dung, sửa model.json trước rồi tái tạo. build.py cập nhật hình, manifest và đặc tả Markdown; build_document.py cập nhật Word độc lập. Mục 2.4.4 của báo cáo tổng cần được đồng bộ riêng sau khi duyệt thay đổi, không tự ghi đè toàn bộ báo cáo.

Word dùng A3 cho hình nhiều nhánh và A4 cho phần diễn giải. Có thể đưa SVG riêng vào báo cáo theo khổ giấy mong muốn; tránh thu nhỏ đến mức khó đọc. Các điểm PX vẫn là vấn đề cần xác nhận, không được coi là chính sách đã chốt.

## Văn phong báo cáo

Phiên bản 1.2 chuẩn hóa ngày 7 tháng 10 năm 2026; giữ căn cứ đối chiếu nguồn ngày 6 tháng 10 năm 2026. Nhãn trên hình dùng hành động, kết quả và điều kiện nghiệp vụ. Tên hàm, đường dẫn API, mã lỗi, biến và trạng thái mã nguồn được giữ trong các bảng chi tiết triển khai, không đặt trên hình. Lifeline dùng tên thành phần hoặc đối tượng: Controller/Service giữ tên lớp thực tế; giao diện và kho dữ liệu dùng danh từ tiếng Việt. Bảng truy vết ghi tệp định nghĩa thành phần. Luồng và các nhánh không thay đổi.

`model.json` giữ nhãn nghiệp vụ riêng với dữ liệu triển khai. Bảng thông điệp Word và Markdown tách diễn giải nghiệp vụ khỏi chi tiết triển khai; mục 2.4.4 trong báo cáo tổng chỉ giữ phần diễn giải nghiệp vụ.

Tên lifeline đã thống nhất với các Controller/Service thực tế. Thông điệp điều hướng và hiển thị giao diện được phân biệt; thao tác mật khẩu dùng nhãn “Băm mật khẩu mới”, thuật toán nằm trong bảng diễn giải. Các nhánh và thứ tự tương tác không đổi.
