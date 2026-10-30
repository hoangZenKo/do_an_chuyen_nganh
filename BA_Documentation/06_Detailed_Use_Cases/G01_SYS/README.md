# G01 — Tài khoản và an toàn truy cập (SYS)

Ngày 29/10/2026. **11 UC**, gồm 10 Xác minh tĩnh và 1 Một phần theo Catalog. Mỗi liên kết dưới là một tệp đặc tả riêng, một bảng hai cột duy nhất.

| Mã UC | Tên UC | Actor chính | Trạng thái Catalog | Tệp |
|---|---|---|---|---|
| UC-ADM-07.1 | Thiết lập MFA Admin | A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-ADM-07.1.md:1` |
| UC-SYS-01 | Đăng ký tài khoản chủ trọ | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-01.md:1` |
| UC-SYS-02 | Đăng ký tài khoản tìm phòng | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-02.md:1` |
| UC-SYS-03 | Đăng nhập | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-03.md:1` |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | A02, A03, A04, A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-05.1.md:1` |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | A02, A03, A04, A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-05.2.md:1` |
| UC-SYS-06 | Khôi phục mật khẩu bằng liên kết một lần | A01 | Một phần | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-06.md:1` |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | A02, A03, A04, A05 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-07.md:1` |
| UC-SYS-08 | Kích hoạt tài khoản người thuê từ lời mời | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-08.md:1` |
| UC-SYS-09 | Kích hoạt tài khoản nhân viên từ lời mời | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-09.md:1` |
| UC-SYS-10 | Thiết lập mật khẩu tài khoản được mời | A01 | Xác minh tĩnh | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/UC-SYS-10.md:1` |

A01: Khách/chưa đăng nhập; A02: Chủ trọ; A03: Nhân viên vận hành; A04: Người tìm phòng/người thuê; A05: Quản trị viên nền tảng. Tác nhân phối hợp E01 chỉ gắn UC-SYS-06 có điều kiện giao nhận; không thêm E01 cho UC-SYS-10 chỉ đổi token có sẵn.

## Coverage nghiệp vụ

| Nhánh FDD G01 | UC | Số lượng |
|---|---|---|
| G01.1 Đăng ký và kích hoạt | UC-SYS-01, 02, 08, 09, 10 | 5 |
| G01.2 Đăng nhập và quản lý phiên | UC-SYS-03, 05.1, 05.2 | 3 |
| G01.3 Bảo vệ tài khoản | UC-SYS-06, 07; UC-ADM-07.1 | 3 |

## Cách đọc

- Quyền API khác khả năng thao tác qua UI: quản lý phiên có API cho A02–A05 nhưng UI chuyên dụng đã truy được chỉ A05; đổi password có API A02–A05 nhưng chưa xác minh điểm truy cập Admin riêng.
- SYS-06 và SYS-10 cùng redeem nhưng khác mục tiêu. SYS-08/SYS-09 là mã mời 7 ngày tạo User mới; account-access là token 30 phút cho User đã tồn tại.
- Đổi password và bật MFA làm version cũ mất hiệu lực, không đồng nghĩa tất cả AuthSession có revokedAt. Đăng xuất offline chỉ bảo đảm theo code việc cố clear client/đặt unauthenticated, không chứng minh server đã revoke.
- Test_Execution_G01_Previous.json lưu 6 suite/24 test của đợt đầu; Test_Execution_Result.json cập nhật toàn lượt với 71 suite/736 test backend. Các test Flutter/E2E được trích trong bảng chỉ là bằng chứng tĩnh trừ khi kết quả thực thi ghi khác.

Rà soát ngữ nghĩa, phần chưa rõ và đối chiếu UML: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/Quality_Review.md:1`.
