# Sơ đồ kiến trúc tổng thể hệ thống quản lý nhà trọ

Bản xem trước ngày 17 tháng 10 năm 2026, phục vụ phần dẫn nhập mục 2.4. Chưa chèn vào báo cáo và không đổi mục lục. Đây là sơ đồ kiến trúc logic hiện có, không phải đề xuất thay đổi hệ thống hoặc sơ đồ triển khai vật lý.

## Tài nguyên

- architecture-overview.png: bản xem trước nền trắng, 3000 × 3000 px.
- architecture-overview.svg: vector dùng để đưa vào báo cáo.
- architecture-overview.drawio: các khối, chữ và đường nối chỉnh sửa riêng được; không nhúng ảnh.
- build.py: tái tạo SVG, PNG và draw.io; dùng Pillow, Tahoma và Sharp trong runtime hiện tại.

## Diễn giải dùng trong báo cáo

Hệ thống được tổ chức theo kiến trúc client–server. Admin, Chủ trọ và Người thuê sử dụng ứng dụng Flutter với giao diện và chức năng phù hợp với vai trò. Phía ứng dụng tách giao diện, quản lý trạng thái và truy cập dữ liệu. Yêu cầu được gửi đến backend NestJS thông qua REST API; các yêu cầu cần xác thực sử dụng JWT.

Backend được tổ chức theo mô hình nguyên khối mô-đun: các nhóm chức năng cùng thuộc một ứng dụng NestJS, không phải những dịch vụ triển khai độc lập. Lớp tiếp nhận API phối hợp với cơ chế xác thực, phân quyền và kiểm tra dữ liệu trước khi chuyển yêu cầu đến phần xử lý nghiệp vụ. Các mô-đun truy cập dữ liệu quan hệ qua Prisma và lưu trữ trong PostgreSQL. Ứng dụng Flutter không kết nối trực tiếp cơ sở dữ liệu.

Tệp tải lên được xử lý riêng và lưu trong thư mục uploads trên máy chủ. Khối kho tệp được tách khỏi PostgreSQL để phân biệt nội dung tệp với dữ liệu nghiệp vụ và đường dẫn tham chiếu. Kênh Zalo ZNS là tích hợp tùy chọn, chỉ sử dụng khi được bật và có cấu hình hợp lệ; hình không khẳng định kênh này đã hoạt động trong môi trường hiện tại.

## Quy ước và giới hạn

- Mũi tên chỉ hướng yêu cầu hoặc truy cập chính; phản hồi được lược bớt. Không biểu diễn thứ tự thời gian như sơ đồ tuần tự.
- Khung Flutter và NestJS là ranh giới thành phần, không phải khung trang hoặc khung sd.
- Khối API nhóm Controllers, Guards và Validation; không có nghĩa mọi bước xác thực được viết bên trong Controller.
- UploadsController được tách ra để minh họa đường lưu tệp; đây là thành phần thuộc API của cùng backend, không phải một tầng nằm dưới Services.
- Các ô nghiệp vụ là nhóm chức năng để đọc tổng thể; không biểu diễn toàn bộ phụ thuộc giữa các mô-đun. Auth, Admin và TenantPortal được ghi bổ sung; Staff, Operations, Health và các chi tiết kỹ thuật khác không được khai triển trong hình này.
- Ba actor theo phạm vi báo cáo. Không suy ra các vai trò có quyền như nhau hoặc dự án chỉ hỗ trợ ba vai trò.
- Đường nét đứt và khung nét đứt biểu diễn tích hợp Zalo ZNS tùy chọn. Không ngụ ý gửi email tự động, cổng thanh toán hay lưu trữ đám mây đã tồn tại.
- Đây không phải sơ đồ bảo mật đầy đủ: việc backend phục vụ tệp qua đường dẫn /uploads/ không được diễn giải thành mọi lượt đọc tệp đều đã qua kiểm tra quyền nghiệp vụ.
- Sơ đồ chưa thể hiện HTTPS, tên miền, reverse proxy hoặc máy chủ cloud vì chưa xác nhận cấu hình triển khai tương ứng.

## Căn cứ đối chiếu

Các đường dẫn frontend tính từ thư mục gốc repository; backend tính từ `backend/`. Đối chiếu chỉ đọc, không sửa mã ứng dụng.

| Thành phần | Căn cứ |
| --- | --- |
| Các mô-đun cùng ứng dụng NestJS | Backend src/app.module.ts và src/main.ts |
| Tiền tố API, kiểm tra dữ liệu, phục vụ tệp | Backend src/app.bootstrap.ts |
| Cơ chế phân quyền | Backend src/common/authorization.module.ts và src/common/roles.guard.ts |
| Tệp lưu trên đĩa | Backend src/uploads/uploads.controller.ts |
| Prisma truy cập cơ sở dữ liệu | Backend src/prisma/prisma.service.ts và prisma/schema.prisma |
| Zalo ZNS tùy chọn | Backend src/notifications/notifications.module.ts và src/notifications/zalo-zns.service.ts |
| API client và JWT | Frontend lib/core/network/api_client.dart |
| Repository | Frontend lib/data/billing/billing_repository.dart |
| Riverpod và giao diện | Frontend lib/features và lib/data; pubspec.yaml |

## Vị trí đề xuất

Đặt hình ở phần mở đầu mục 2.4 Mô hình hệ thống / Thiết kế giải pháp, trước 2.4.1. Chú thích đề xuất: “Kiến trúc tổng thể hệ thống quản lý nhà trọ”. Giữ nguyên số các mục hiện có. Chỉ tích hợp sau khi người dùng duyệt bản xem trước.

