# Sơ đồ Use Case chi tiết theo nhóm

Bộ sơ đồ bổ sung cho đặc tả 67 UC trong năm nhóm SYS, ADM, OPT, BIL và TEN. Mã UC, tên UC và actor được lấy từ các bảng đặc tả; không thêm chức năng hoặc tự quyết định những chính sách còn cần xác nhận.

## Tệp để rà soát và chỉnh sửa

- Bản Word có đầy đủ đặc tả và hình vẽ: `../USE_CASE_SPECIFICATION_WITH_DIAGRAMS.docx`.
- Bản đặc tả Markdown có hình vẽ và liên kết tới từng UC: `../USE_CASE_SPECIFICATION.md`.
- Tệp sơ đồ chỉnh sửa được bằng diagrams.net: `USE_CASE_GROUP_DIAGRAMS.drawio`. Mỗi sơ đồ là một trang trong cùng tệp.
- Mỗi sơ đồ có bản SVG và PNG cùng tên. Bản PNG được chèn vào Word; bản SVG dùng để xem ở kích thước lớn.
- Bản Word `../USE_CASE_SPECIFICATION.docx` trước khi thêm sơ đồ được giữ nguyên.

## Danh mục sơ đồ

| Mã sơ đồ | Nhóm | Nội dung | Số UC chi tiết | Tên tệp SVG và PNG |
| --- | --- | --- | --- | --- |
| D-SYS-01 | SYS | Xác thực và phiên làm việc | 3 | `use-case-sys-01` |
| D-ADM-01 | ADM | Quản trị hệ thống | 8 | `use-case-adm-01` |
| D-OPT-01 | OPT | Tổng quan vận hành và quản lý khu trọ | 6 | `use-case-opt-01` |
| D-OPT-02 | OPT | Quản lý phòng | 9 | `use-case-opt-02` |
| D-OPT-03 | OPT | Quản lý hồ sơ người thuê | 6 | `use-case-opt-03` |
| D-OPT-04 | OPT | Quản lý hợp đồng thuê | 6 | `use-case-opt-04` |
| D-OPT-05 | OPT | Quản lý bảo trì | 4 | `use-case-opt-05` |
| D-BIL-01 | BIL | Chỉ số điện nước và hóa đơn | 8 | `use-case-bil-01` |
| D-BIL-02 | BIL | Thanh toán minh chứng và chi phí | 6 | `use-case-bil-02` |
| D-BIL-03 | BIL | Báo cáo và thông báo | 4 | `use-case-bil-03` |
| D-TEN-01 | TEN | Cổng thông tin Người thuê | 7 | `use-case-ten-01` |

## Quy ước trình bày

- Hình người thể hiện actor ở ngoài biên hệ thống. Hình elip thể hiện UC có mã và tên trùng với đặc tả.
- Đường liền nối actor với UC mà actor tham gia. Liên kết này không thể hiện thứ tự thực hiện các UC.
- Khung nét đứt chỉ gom UC chi tiết theo mã UC tổng quan; không phải một UC mới và không tự xác lập quan hệ bao gồm, mở rộng hoặc kế thừa.
- Khi một UC tổng quan được đặc tả trực tiếp, mã của nó được giữ nguyên trong hình elip. Không tạo thêm UC con chỉ để đồng nhất cách đánh mã.
- Actor cùng tên có thể được lặp lại trong một hình để giảm giao cắt. Các hình lặp lại vẫn đại diện cho cùng một vai trò.
- Nhóm OPT và BIL được chia thành nhiều hình để giữ kích thước chữ dễ đọc; toàn bộ 11 hình bao phủ đúng 67 UC, mỗi UC xuất hiện trong một hình.
- Admin hệ thống, Chủ trọ và Người thuê tham gia đăng nhập và đăng xuất. Chỉ Người thuê tham gia kích hoạt tài khoản từ lời mời.
- Dịch vụ Zalo ZNS chỉ là actor phụ tại nhánh gửi ra Zalo của UC-BIL-07.02; không coi thông báo nội bộ là gửi Zalo thành công.
- Các điểm chưa thống nhất vẫn được giữ tại Phụ lục A của đặc tả. Sơ đồ không thay thế việc xác nhận quy tắc nghiệp vụ hoặc nghiệm thu vận hành.
