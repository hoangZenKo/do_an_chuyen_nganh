# G06 — Hồ sơ thuê, hợp đồng và tiền cọc

Ngày 29/10/2026. Hoàn thành 17/17 tệp đặc tả theo Catalog. Mỗi UC có một bảng hai cột/20 thuộc tính. Trạng thái ở bảng là mức triển khai/xác minh Catalog, không là nghiệm thu runtime.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Đặc tả |
|---|---|---|---|---|
| UC-TEN-01 | Xem hồ sơ và tổng quan thuê của mình | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TEN-01.md:1` |
| UC-TEN-02 | Tra cứu hợp đồng và quyết toán của mình | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TEN-02.md:1` |
| UC-TEN-08.1 | Xem người ở cùng hợp đồng | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TEN-08.1.md:1` |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-01.md:1` |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-02.1.md:1` |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-02.2.md:1` |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục người thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-02.3.md:1` |
| UC-TNT-02.4 | Xóa hồ sơ người thuê đủ điều kiện | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-02.4.md:1` |
| UC-TNT-03 | Tạo lời mời truy cập cổng người thuê | A02 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-03.md:1` |
| UC-TNT-03.1 | Tạo trực tiếp tài khoản cho hồ sơ người thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-03.1.md:1` |
| UC-TNT-04 | Tra cứu và xuất hợp đồng thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-04.md:1` |
| UC-TNT-05 | Lập hợp đồng thuê phòng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-05.md:1` |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-06.1.md:1` |
| UC-TNT-06.2 | Gia hạn hợp đồng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-06.2.md:1` |
| UC-TNT-06.3 | Kết thúc hợp đồng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-06.3.md:1` |
| UC-TNT-07 | Tra cứu và ghi giao dịch cọc | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-07.md:1` |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/UC-TNT-12.1.md:1` |

Tạo User trực tiếp và mời qua invite là hai cơ chế khác, quyền STAFF khác. TENANT đọc lease không có bằng chứng UI shareLeasePdf; xuất thuộc vận hành. Kết thúc lease không tự quyết toán.

Rà soát nhóm: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/Quality_Review.md:1`. Báo cáo toàn hệ thống: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
