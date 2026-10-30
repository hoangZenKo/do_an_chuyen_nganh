# G04 — Khu trọ và cơ sở vật chất

Ngày 29/10/2026. Hoàn thành 14/14 tệp đặc tả theo Catalog. Mỗi UC có một bảng hai cột/20 thuộc tính. Trạng thái ở bảng là mức triển khai/xác minh Catalog, không là nghiệm thu runtime.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Đặc tả |
|---|---|---|---|---|
| UC-OPT-02 | Tra cứu khu trọ | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-02.md:1` |
| UC-OPT-03.1 | Tạo khu trọ | A02 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-03.1.md:1` |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-03.2.md:1` |
| UC-OPT-04.1 | Lưu trữ hoặc khôi phục khu trọ | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-04.1.md:1` |
| UC-OPT-04.3 | Xóa khu trọ đủ điều kiện | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-04.3.md:1` |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-05.md:1` |
| UC-OPT-06.1 | Tạo phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-06.1.md:1` |
| UC-OPT-06.2 | Cập nhật thông tin phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-06.2.md:1` |
| UC-OPT-07.1 | Đổi trạng thái sử dụng phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-07.1.md:1` |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-07.2.md:1` |
| UC-OPT-07.3 | Xóa phòng đủ điều kiện | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-07.3.md:1` |
| UC-OPT-08.1 | Quản lý tài sản phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-08.1.md:1` |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-08.2.md:1` |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ phòng | A02 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/UC-OPT-09.md:1` |

UC-OPT-06.2 và UC-OPT-07.1 dùng cùng PATCH nhưng dữ liệu mô tả phòng và chuyển status có quy tắc khác. Tắt isActive khác status; delete có kiểm lịch sử. Chưa cần đổi mã/gộp.

Rà soát nhóm: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/Quality_Review.md:1`. Báo cáo toàn hệ thống: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
