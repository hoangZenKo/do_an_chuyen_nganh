# Sơ đồ lớp và đối tượng

## Phạm vi

23 lớp dữ liệu trong phạm vi báo cáo; 39 quan hệ cấu trúc được bao phủ bởi tám sơ đồ chi tiết. Không bao gồm StaffProfile và StaffInvite. Sơ đồ tổng quan chọn 13 lớp và 14 quan hệ, không thay thế sơ đồ chi tiết.

Mô hình đối tượng là dữ liệu giả định tại ngày 6 tháng 10 năm 2026, dùng mã rút gọn và thuộc tính chọn lọc. Không dùng làm dữ liệu vận hành, seed hoặc yêu cầu API.

## Tài nguyên

- `CLASS_DIAGRAMS.drawio`: 11 trang với hộp lớp, thuộc tính, đường nối và nhãn có thể chỉnh sửa trực tiếp.
- Mỗi hình có `.png` để chèn tài liệu, `.svg` để phóng to và `.puml` để chỉnh sửa bằng PlantUML. Nếu dựng lại bằng PlantUML, vị trí có thể khác ảnh PNG nhưng nội dung lớp và quan hệ phải giữ nguyên.
- `class-model.json`: tên lớp, thuộc tính, kiểu, quan hệ, bội số, enum và đối tượng minh họa.
- `diagram-manifest.json`: danh sách hình, kích thước, hộp, đường nối và nhãn của bản dựng hiện hành.

## Danh mục hình

| Mã | Nội dung | Tệp |
| --- | --- | --- |
| CD-00 | Tổng quan các lớp nghiệp vụ | `cd-00.png` |
| CD-01 | Tài khoản và hồ sơ Người thuê | `cd-01.png` |
| CD-02 | Khu trọ và phòng | `cd-02.png` |
| CD-03 | Hợp đồng và tiền cọc | `cd-03.png` |
| CD-04A | Chỉ số và hóa đơn | `cd-04a.png` |
| CD-04B | Thanh toán và minh chứng | `cd-04b.png` |
| CD-04C | Lập hóa đơn định kỳ | `cd-04c.png` |
| CD-05 | Bảo trì và chi phí | `cd-05.png` |
| CD-06 | Thông báo và nhật ký | `cd-06.png` |
| OD-01 | Đối tượng tài khoản và hợp đồng | `od-01.png` |
| OD-02 | Đối tượng hóa đơn và thanh toán | `od-02.png` |

## Quy ước

Đường liền là quan hệ cấu trúc. CD-06 ghi ba mã NotificationDelivery bằng thuộc tính và chú thích <<IDRef>>, không có connector hoặc bội số: tham chiếu bằng mã định danh trong dữ liệu, không phải structural association UML. Nhãn bội số đặt tại lớp mà số lượng được mô tả. Hộp màu xám là lớp hoặc đối tượng được nhắc lại; không tạo bản sao mô hình. Tên đối tượng được gạch chân. Không suy ra hợp thành, kết tập hoặc phương thức của thực thể từ xử lý bên ngoài.

Trong draw.io, nhãn bội số và tên vai trò là các đối tượng văn bản gắn với connector. Khi đổi vị trí hộp lớp hoặc tuyến đường nối, cần kiểm tra vị trí nhãn và đồng bộ diagram-manifest.json trước khi dựng lại. PlantUML ghi vai trò tại cả hai đầu association; ảnh hiển thị vai trò từ lớp nguồn, riêng Payment tự liên kết hiển thị cả hai vai trò.

Các liên kết Tenant.landlord và Tenant.user, AuditLog.actor và AuditLog.landlord phải được đọc theo vai trò khác nhau. NotificationRead.notificationId có thể được dùng với mã lượt gửi trong một luồng, nhưng không có quan hệ cấu trúc đến NotificationDelivery. Không tự thêm Invoice — MeterReading hoặc PaymentProof — Payment.

Nội dung giải thích nằm trong `../CLASS_DIAGRAM_SPECIFICATION.md`. Audit năm phần, ma trận 39 quan hệ và 3 IDRef, changelog, 11 nguồn PlantUML và checklist nằm trong `../CLASS_DIAGRAM_AUDIT.md`. Những chính sách chưa chốt giữ nhãn CẦN XÁC NHẬN NGHIỆP VỤ.

## Dựng và kiểm chứng

Dùng Python có Pillow, python-docx và Node có Sharp. Chạy `build.py` để dựng Draw.io, SVG, PNG và PlantUML; `update_documents.py` để đồng bộ hai Word phần lớp; `validate.py` để đối chiếu schema độc lập và kiểm tra các bản xuất. build.py dùng đường dẫn runtime trong cấu hình đầu tệp; điều chỉnh nếu chuyển máy. Không dùng dịch vụ render công khai để tải mô hình dự án lên mạng. Kiểm tra trực quan Word sau mỗi lần xuất; bộ kiểm tra tĩnh không thay thế kiểm tra trang in.
