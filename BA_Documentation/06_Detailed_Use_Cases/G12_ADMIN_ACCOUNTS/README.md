# G12 — Tài khoản và tài nguyên nền tảng

Ngày 29/10/2026. Hoàn thành 12/12 tệp đặc tả theo Catalog. Mỗi UC có một bảng hai cột/20 thuộc tính. Trạng thái ở bảng là mức triển khai/xác minh Catalog, không là nghiệm thu runtime.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Đặc tả |
|---|---|---|---|---|
| UC-ADM-02 | Tra cứu tài khoản nền tảng | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-02.md:1` |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | A05 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-03.1.md:1` |
| UC-ADM-03.2 | Cập nhật hồ sơ chủ trọ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-03.2.md:1` |
| UC-ADM-04.1 | Đình chỉ hoặc khôi phục tài khoản | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-04.1.md:1` |
| UC-ADM-04.3 | Thu hồi phiên của tài khoản khác | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-04.3.md:1` |
| UC-ADM-05.1 | Mở thông tin cá nhân được che | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-05.1.md:1` |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | A05 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-05.2.md:1` |
| UC-ADM-06.1 | Cấp và quản lý quyền quản trị viên | A05 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-06.1.md:1` |
| UC-ADM-06.2 | Rà soát quyền Admin định kỳ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-06.2.md:1` |
| UC-ADM-08 | Tra cứu khu và phòng toàn nền tảng | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-08.md:1` |
| UC-ADM-09 | Tạo hoặc cập nhật khu thay chủ trọ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-09.md:1` |
| UC-ADM-10 | Tìm kiếm và định vị tài nguyên | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/UC-ADM-10.md:1` |

Admin là một Actor; preset/capability không tạo loại Actor mới. Quyền đọc accounts.view khác đường landlords cũ accounts.manage; không grant vì chung service.

Rà soát nhóm: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/Quality_Review.md:1`. Báo cáo toàn hệ thống: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
