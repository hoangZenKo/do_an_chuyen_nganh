# G14 — Dịch vụ hỗ trợ khách hàng

Ngày 29/10/2026. Hoàn thành 8/8 tệp đặc tả theo Catalog. Mỗi UC có một bảng hai cột/20 thuộc tính. Trạng thái ở bảng là mức triển khai/xác minh Catalog, không là nghiệm thu runtime.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Đặc tả |
|---|---|---|---|---|
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | A02, A04, A05 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-01.md:1` |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | A05 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-01.1.md:1` |
| UC-SUP-02.1 | Cấu hình phân công tự động hỗ trợ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-02.1.md:1` |
| UC-SUP-02.2 | Cấu hình và theo dõi SLA hỗ trợ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-02.2.md:1` |
| UC-SUP-03.2 | Quản lý mẫu trả lời hỗ trợ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-03.2.md:1` |
| UC-SUP-03.2.1 | Hợp nhất hồ sơ hỗ trợ trùng | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-03.2.1.md:1` |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | A02, A04, A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-03.2.2.md:1` |
| UC-SUP-03.3 | Lưu bộ lọc xử lý hỗ trợ | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/UC-SUP-03.3.md:1` |

Requester ticket và Admin xử lý là hai mục tiêu. Internal không lộ requester. Scanner thiếu phải fail-closed; không đồng nhất có endpoint upload với tích hợp vận hành đã sẵn sàng.

Rà soát nhóm: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/Quality_Review.md:1`. Báo cáo toàn hệ thống: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
