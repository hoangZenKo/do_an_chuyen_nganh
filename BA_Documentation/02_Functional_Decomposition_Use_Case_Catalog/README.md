# Giai đoạn 2 — Phân rã chức năng và chuẩn hóa Use Case Catalog

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

Đây là AS-IS theo mã nguồn, không phải yêu cầu tương lai hoặc xác nhận nghiệm thu production. Không viết đặc tả chi tiết, không vẽ UML Use Case Diagram.

## 1. Phạm vi và nguồn chuẩn

- Đối chiếu khảo sát nguồn với catalog 164 UC ở `/Users/hoang/Rental_room_management/docs/ba/uc-revision-2026-10-29/Use_Case_Catalog.json:1` và 63 mã lịch sử ở `/Users/hoang/Rental_room_management/docs/BA_USE_CASES.md:1`. Giữ nguyên tài liệu cũ; đặc tả/sơ đồ cũ không tự là bằng chứng hành vi.
- Kiểm tra lại 846 tệp source/test/schema/migration trùng cache nội dung đã khảo sát. Không sửa ứng dụng, không chạy DB E2E hoặc gọi provider/giao dịch thật.
- Kiểm kê 405 endpoint của 70 controller có route, gồm backend/src/uploads bị gitignore che khỏi tìm kiếm mặc định. 395 endpoint liên kết UC, 10 endpoint thuộc cơ chế kỹ thuật; đây không phải 405 UC hay độ phủ kiểm thử.
- 180 mục khảo sát mang mã F-001…F-180 trong gói này để kiểm tra không mất phạm vi. Đây là mã kiểm kê phân tích nội bộ, không phải UC hay tuyên bố đã xuất bộ Giai đoạn 1 trước đó. Mỗi mục chuyển vào UC, cơ chế kỹ thuật hoặc register thiếu bằng chứng.
- Dùng một thư mục Giai đoạn 2 dưới BA_Documentation, không di chuyển/ghi đè docs/ba.

## 2. Kết quả chính

**162 UC, 16 nhóm; giữ 147/164 mã, thêm 15 mã, chuyển hướng/phân loại lại 17 mã cũ. Không xóa chức năng ứng dụng.**

| Nhóm | Nghiệp vụ | Số UC |
| --- | --- | --- |
| G01 | Tài khoản và an toàn truy cập | 11 |
| G02 | Tìm và lựa chọn phòng | 6 |
| G03 | Đăng tin, lịch xem và nhận phòng | 7 |
| G04 | Khu trọ và cơ sở vật chất | 14 |
| G05 | Nhân sự và ủy quyền vận hành | 4 |
| G06 | Hồ sơ thuê, hợp đồng và tiền cọc | 17 |
| G07 | Vòng đời thuê và quyết toán | 7 |
| G08 | Hóa đơn, thu tiền và công nợ | 28 |
| G09 | Bảo trì và chi phí vận hành | 5 |
| G10 | Công việc, thông tin và hỗ trợ sử dụng | 9 |
| G11 | Báo cáo và giám sát vận hành | 8 |
| G12 | Tài khoản và tài nguyên nền tảng | 12 |
| G13 | Kiểm duyệt và chất lượng nội dung | 11 |
| G14 | Dịch vụ hỗ trợ khách hàng | 8 |
| G15 | Hồ sơ xác minh và gói dịch vụ | 6 |
| G16 | Quản trị chính sách và đối soát nền tảng | 9 |

| Trạng thái | Số UC | Cách hiểu |
| --- | --- | --- |
| Xác minh tĩnh | 151 | Đã đọc hành vi/controller/service hoặc logic Flutter và có nguồn; chưa xác nhận tích hợp chạy thật. |
| Một phần | 9 | Có code nhưng biến thể phụ thuộc dịch vụ ngoài/cấu hình chưa xác minh. |
| Đã triển khai — DEMO | 1 | Thanh toán thẻ kiểm thử, không tiền thật. |
| Đã triển khai — MÔ PHỎNG | 1 | Tin Zalo lưu nội bộ, không Zalo OA thật. |
| Chưa đủ bằng chứng — ngoài catalog | 3 | Thanh toán thật, ký số pháp lý, tự sửa hồ sơ. |

## 3. Bộ tài liệu

| Tệp | Nội dung |
| --- | --- |
| 01_Functional_Decomposition.md | Cây hệ thống → nhóm → chức năng → mục tiêu có mã UC. |
| 02_FDD.puml; 02_FDD.svg; diagrams/ | WBS PlantUML và sơ đồ phân cấp SVG đầy đủ/của 16 nhóm, không phải UML UC. |
| 03_Actor_Catalog.md | Actor, ngữ cảnh TENANT, preset, bên phối hợp, quyền và hạn chế. |
| 04_Actor_Use_Case_Matrix.md | 162 dòng Actor × UC, quyền chính/chỉ xem/bị chặn. |
| 05_Use_Case_Catalog.md | Catalog 7 cột theo yêu cầu. |
| 06_Use_Case_Quality_Review.md | Quyết định gộp/tách, kiểm tra chất lượng và điểm cần duyệt. |
| 07_Traceability_and_Coverage.md | Truy vết từng UC qua các lớp và disposition 180 mục khảo sát. |
| 08_UC_ID_Crosswalk.md | Ánh xạ toàn bộ 164 mã gần nhất và 63 mã lịch sử. |
| 09_Technical_and_Gap_Register.md | 9 nhóm kỹ thuật, 3 GAP và hạn chế triển khai/tích hợp. |
| data/catalog.json; data/traceability.json | Dữ liệu cấu trúc dùng cho giai đoạn tiếp theo. |
| tools/validate.cjs; Validation_Result.json | Kiểm tra IDs, coverage, bằng chứng, Actor, FDD và source không đổi. |

## 4. Quy ước

- Giữ mã cũ dù prefix khác nhóm nghiệp vụ mới (chi phí UC-BIL-19 nằm G09). Hậu tố kế thừa mã cha không hàm ý quan hệ UML. Mã đã chuyển hướng không tái sử dụng cho mục tiêu khác.
- Không đếm endpoint/nút bấm thành UC. Nhiều API có thể phục vụ một mục tiêu; ba loại lifecycle cùng API nhưng đích nghiệp vụ riêng. Preview, PDF/CSV, chọn khu, đánh dấu đọc và validation nằm trong mục tiêu tương ứng.
- Actor chính không được làm mọi biến thể. Matrix ghi điều kiện; data/traceability.json chứa ACL theo handler. Không AND/OR toàn bộ permission của một UC.
- Từng UC có bằng chứng hành vi; UI/test liệt kê là nguồn liên quan, không tự chứng minh chạy đủ luồng hoặc pass. Không công bố kết quả test cũ như lần chạy mới.
- Đường dẫn tuyệt đối kèm dòng là vị trí snapshot; nếu nguồn đổi, cần chạy kiểm tra và tái phân tích.

## 5. Kiểm tra sơ đồ

17 SVG đã render thành công; kiểm tra trực quan nhóm G02 và G08. PlantUML WBS được kiểm cấu trúc/mã, chưa biên dịch native vì máy không có Java runtime. Kết quả ở Diagram_Validation.json; SVG đọc được không phụ thuộc PlantUML.

## 6. Điều kiện chuyển Giai đoạn 3

Đây là baseline chuẩn hóa tĩnh để người dùng duyệt. Sau khi duyệt các điểm ở báo cáo chất lượng, có thể dựng UML và đặc tả chi tiết. Giữ nhãn Một phần/DEMO/MÔ PHỎNG, không đưa 3 GAP vào AS-IS xác nhận, không suy quyền STAFF từ menu. Chưa khẳng định hệ thống hoạt động end-to-end/production.
