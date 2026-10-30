# Tài liệu phân tích và thiết kế

## Bản hiện hành

- `USE_CASE_SPECIFICATION_WITH_DIAGRAMS.docx`: đặc tả phiên bản 1.2, 67 UC theo mẫu 13 thuộc tính, 11 sơ đồ nhóm và Phụ lục C nhật ký hiệu chỉnh. Dùng bản này để rà soát trong Word hoặc nhập vào Google Docs.
- `USE_CASE_SPECIFICATION.md`: bản Markdown đồng bộ nội dung đặc tả và nhật ký.
- `USE_CASE_AUDIT.md`: báo cáo rà soát, từng thay đổi trước–sau, căn cứ đối chiếu, ma trận 67 UC, kết quả kiểm thử và các thiếu sót chưa xử lý.
- `diagrams/USE_CASE_GROUP_DIAGRAMS.drawio`: sơ đồ nhóm có thể chỉnh sửa; lần rà soát phiên bản 1.2 giữ nguyên 11 sơ đồ.

## Bản nền

`USE_CASE_SPECIFICATION.docx` là bản nền trước khi bổ sung sơ đồ, không phải phiên bản 1.2. Không dùng bản nền này thay cho bản Word hiện hành khi đối chiếu các hiệu chỉnh.

## Giới hạn

Đặc tả chưa thay thế nghiệm thu. Các điểm PX trong Phụ lục A vẫn cần xác nhận; việc hiệu chỉnh tài liệu không có nghĩa các thiếu sót mã nguồn đã được sửa. Xem báo cáo rà soát để phân biệt từng loại vấn đề.

## Mô hình lớp và đối tượng

- `CLASS_DIAGRAM_REPORT_SECTION.docx`: bản Word dành cho báo cáo, gồm sáu tiểu mục 2.4.3.1 đến 2.4.3.6; nội dung chính trình bày phạm vi, tổng quan, nhóm lớp, mô tả lớp, quan hệ và ví dụ đối tượng. Sơ đồ nhóm, ma trận đầy đủ và căn cứ đối chiếu được tách vào phụ lục. Dùng bản này khi đưa mục 2.4.3 vào báo cáo.
- `CLASS_DIAGRAM_SPECIFICATION.docx`: bản phân tích chi tiết để tra cứu, gồm mô hình lớp, đối tượng minh họa, ma trận quan hệ và nhật ký hiệu chỉnh. Có thể nhập vào Google Docs để rà soát.
- `CLASS_DIAGRAM_SPECIFICATION.md`: bản Markdown đồng bộ nội dung; mục 2.4.3 trong `../PROPOSAL_QUAN_LY_TRO.md` cũng được cập nhật.
- `class-diagrams/CLASS_DIAGRAMS.drawio`: 11 trang sơ đồ có thể chỉnh sửa, gồm một tổng quan, tám sơ đồ lớp chi tiết và hai góc nhìn đối tượng.
- `class-diagrams/README.md`: phạm vi, quy ước và danh mục tài nguyên PNG, SVG, PlantUML.
- `CLASS_DIAGRAM_AUDIT.md`: audit năm phần ngày 7 tháng 10 năm 2026, source of truth, ma trận đủ 39 association và 3 IDRef, changelog, 11 nguồn PlantUML và checklist. CD-05 đã bố trí Expense dưới MaintenanceTicket; CD-06 không còn connector IDRef.

Phạm vi mô hình lớp là 23 lớp và 39 quan hệ cấu trúc, không bao gồm StaffProfile và StaffInvite. Những điểm PX chưa chốt được giữ riêng. Bản Word này không ghi đè bản Word báo cáo tổng hoặc các đặc tả Use Case hiện có.

Kết luận audit là NOT READY TO SUBMIT: phải chốt các chính sách được liệt kê trong checklist và ghép mục 2.4.3 mới vào Word/PDF tổng. Bội số MaintenanceTicket–Expense là cấu trúc cho phép bởi schema, không phải xác nhận nghiệp vụ chia sẻ chi phí. Chỉ hình và tài liệu được hiệu chỉnh; mã nguồn và schema không thay đổi.

## Bản demo biểu đồ tuần tự

- `SEQUENCE_DIAGRAM_DEMO.docx`: bản Word độc lập của SD-01, tạo hợp đồng thuê phòng theo UC-OPT-05.02.
- `SEQUENCE_DIAGRAM_DEMO.md`: diễn giải luồng thành công, ánh xạ thành phần và các ngoại lệ ngoài phạm vi hình.
- `sequence-diagrams/`: nguồn draw.io chỉnh sửa được, vector SVG và ảnh PNG.

Bản demo dùng tiền cọc bằng 0 và chưa thay thế mục 2.4.4 của báo cáo tổng.


## Bộ biểu đồ tuần tự chính thức

- `SEQUENCE_DIAGRAM_SPECIFICATION.docx`: tài liệu chi tiết của 10 kịch bản, 15 UC và 22 hình, kèm bảng diễn giải từng thông điệp và giới hạn nghiệp vụ.
- `SEQUENCE_DIAGRAM_SPECIFICATION.md`: bản Markdown cùng nội dung hình, có đối chiếu các luồng Use Case và căn cứ mã nguồn.
- `sequence-diagrams/full/SEQUENCE_DIAGRAMS.drawio`: 22 trang nguồn chỉnh sửa được.
- `sequence-diagrams/full/README.md`: danh mục PNG, SVG, nguồn riêng, mô hình và cách tái tạo.

Bộ chính thức giữ form vàng nhạt đã duyệt, không có khung ngoài, và bổ sung alt, opt, loop, break theo từng luồng. SD-01 là đăng nhập; SD-04 là tạo hợp đồng, khác mã SD-01 của demo cũ. Mục 2.4.4 của báo cáo Markdown đã được thay bằng bộ này; không ghi đè báo cáo Word và PDF tổng.

Bộ chính thức đã chuẩn hóa văn phong ngày 7 tháng 10 năm 2026: nhãn hình và diễn giải báo cáo ưu tiên ngôn ngữ nghiệp vụ; tên hàm, đường dẫn API, mã lỗi và trạng thái mã nguồn được chuyển sang bảng chi tiết triển khai trong đặc tả độc lập. Không thay đổi luồng, các nhánh hoặc bộ demo cũ.

Tên lifeline đã thống nhất với các Controller/Service thực tế. Thông điệp điều hướng và hiển thị giao diện được phân biệt; thao tác mật khẩu dùng nhãn “Băm mật khẩu mới”, thuật toán nằm trong bảng diễn giải. Các nhánh và thứ tự tương tác không đổi.
