# G07 — Vòng đời thuê và quyết toán

Ngày 29/10/2026. Hoàn thành 7/7 tệp đặc tả theo Catalog. Mỗi UC có một bảng hai cột/20 thuộc tính. Trạng thái ở bảng là mức triển khai/xác minh Catalog, không là nghiệm thu runtime.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Đặc tả |
|---|---|---|---|---|
| UC-TEN-07.1 | Đề nghị gia hạn thuê | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TEN-07.1.md:1` |
| UC-TEN-07.2 | Đề nghị chuyển phòng | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TEN-07.2.md:1` |
| UC-TEN-07.3 | Đề nghị trả phòng | A04 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TEN-07.3.md:1` |
| UC-TNT-08 | Xem trước và xác nhận quyết toán trả phòng | A02 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TNT-08.md:1` |
| UC-TNT-09 | Ghi nhận đã hoàn cọc theo quyết toán | A02 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TNT-09.md:1` |
| UC-TNT-10 | Xét duyệt yêu cầu vòng đời thuê | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TNT-10.md:1` |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã duyệt | A02, A03 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/UC-TNT-11.md:1` |

Gửi đề nghị, xét duyệt, thực thi có mục tiêu/trạng thái và actor khác; không gộp. Quyết toán không tự cấn nợ invoice cũ; hoàn cọc là ghi nhận, không chuyển ngân hàng.

Rà soát nhóm: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/Quality_Review.md:1`. Báo cáo toàn hệ thống: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
