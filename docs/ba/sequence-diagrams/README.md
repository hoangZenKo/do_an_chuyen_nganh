# Bản demo biểu đồ tuần tự

## Bộ chính thức đã triển khai

`full/` chứa 10 kịch bản, 15 UC và 22 hình tuần tự theo form vàng nhạt không có khung ngoài, với nhánh alt, opt, loop và break. Dùng `full/SEQUENCE_DIAGRAMS.drawio` để chỉnh sửa toàn bộ; đặc tả Word và Markdown nằm ở thư mục ba. SD-01 chính thức là đăng nhập, SD-04 là tạo hợp đồng. Những tệp bên dưới là lịch sử demo duyệt form, không phải bộ chính thức.

## SD-01 Tạo hợp đồng thuê phòng

Use Case UC-OPT-05.02. Phạm vi hình là luồng thành công; Chủ trọ đã đăng nhập, tiền cọc bằng 0. Luồng được đối chiếu với đặc tả và backend, không tự bổ sung lớp Entity hoặc phương thức chưa được định nghĩa.

## Tài nguyên

- `sd-01-create-lease.drawio`: nguồn chỉnh sửa được trong draw.io, sử dụng actor, boundary, control, database, đường sống, thanh kích hoạt và thông điệp riêng biệt.
- `sd-01-create-lease.svg`: vector xuất từ draw.io, có nhúng bản nguồn.
- `sd-01-create-lease.png`: ảnh 2800 px, nền trắng.
- `../SEQUENCE_DIAGRAM_DEMO.md`: diễn giải, phạm vi, ánh xạ thành phần và ngoại lệ ngoài hình.
- `../SEQUENCE_DIAGRAM_DEMO.docx`: bản Word độc lập để rà soát và đưa vào báo cáo.

Các nhãn được giữ ngắn; thao tác SQL, tải dữ liệu ban đầu, kiểm tra đầu vào, xác thực và nhật ký được giải thích ở tài liệu thay vì thêm nhiều lifeline. Không ép sơ đồ có Entity nếu không có tương tác tương ứng. Hình này không mô tả toàn bộ nhánh của Use Case.

## Phiên bản mô phỏng phong cách StarUML

- `sd-01-create-lease-staruml-style.png`: bản xem trước gọn với khung sd, ký hiệu xám nhẹ và nhãn thành phần gạch chân.
- `sd-01-create-lease-staruml-style.svg`: vector với chữ SVG, không phụ thuộc ảnh chữ nhúng.
- `sd-01-create-lease-staruml-style.drawio`: bản chỉnh sửa được của phiên bản này.

Đây là bản mô phỏng phong cách, không phải ảnh xuất từ StarUML hoặc dự án `.mdj`. Nội dung nghiệp vụ và phạm vi luồng thành công giữ nguyên. Bản Word hiện có vẫn sử dụng phiên bản trước để so sánh trước khi chốt hình thức.

## Demo StarUML cổ điển màu vàng nhạt

- `sd-01-create-lease-staruml-yellow.png`: bản xem trước 2200 px, nền trắng, ký hiệu và thanh kích hoạt màu vàng nhạt; không có khung ngoài hoặc ô tiêu đề sd.
- `sd-01-create-lease-staruml-yellow.svg`: vector với chữ SVG và bảng màu vàng nhạt #FFFFB9, viền đỏ nâu #800000.
- `sd-01-create-lease-staruml-yellow.drawio`: nguồn chỉnh sửa được của bản demo vàng.

Bản này dùng font Tahoma với Arial làm phương án thay thế nếu thiếu font. Nhãn tự gọi được đặt tránh che thanh kích hoạt. Đây là bản mô phỏng, không phải tệp xuất từ StarUML hay dự án `.mdj`; không ghi đè bản Word hoặc các phiên bản màu trước. Phạm vi nghiệp vụ vẫn là luồng thành công của UC-OPT-05.02 với tiền cọc bằng 0.

Bộ chính thức đã chuẩn hóa văn phong ngày 7 tháng 10 năm 2026: nhãn hình và diễn giải báo cáo ưu tiên ngôn ngữ nghiệp vụ; tên hàm, đường dẫn API, mã lỗi và trạng thái mã nguồn được chuyển sang bảng chi tiết triển khai trong đặc tả độc lập. Không thay đổi luồng, các nhánh hoặc bộ demo cũ.

Tên lifeline đã thống nhất với các Controller/Service thực tế. Thông điệp điều hướng và hiển thị giao diện được phân biệt; thao tác mật khẩu dùng nhãn “Băm mật khẩu mới”, thuật toán nằm trong bảng diễn giải. Các nhánh và thứ tự tương tác không đổi.
