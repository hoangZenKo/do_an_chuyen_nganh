# Giai đoạn 4 — Đặc tả Use Case AS-IS

Ngày cập nhật: 29/10/2026. Snapshot source: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## Phạm vi hoàn thành

**162/162 UC, 16/16 nhóm** theo Catalog Giai đoạn 2. Giữ 11 đặc tả G01 đã có; bổ sung 151 đặc tả G02–G16 trong lượt hoàn tất này theo yêu cầu người dùng. Không thêm/đổi mã, đổi tên, đổi Actor hoặc nâng trạng thái xác minh.

- 151 UC **Xác minh tĩnh**; 9 **Một phần**; 1 **DEMO**; 1 **MÔ PHỎNG**.
- Mỗi UC là một tệp Markdown: một tiêu đề và đúng **một bảng liên tục hai cột, 20 thuộc tính**, không có bảng phụ.
- Hoàn thành **phạm vi tài liệu**, không có nghĩa nghiệm thu production, DB hay provider ngoài.

| Nhóm | Nghiệp vụ | UC | Xác minh tĩnh | Một phần | DEMO/Mô phỏng | Chỉ mục |
|---|---|---|---|---|---|---|
| G01 | Tài khoản và an toàn truy cập | 11 | 10 | 1 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G01_SYS/README.md:1` |
| G02 | Tìm và lựa chọn phòng | 6 | 6 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G02_DIS/README.md:1` |
| G03 | Đăng tin, lịch xem và nhận phòng | 7 | 7 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G03_HOUSING/README.md:1` |
| G04 | Khu trọ và cơ sở vật chất | 14 | 14 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G04_PROPERTY/README.md:1` |
| G05 | Nhân sự và ủy quyền vận hành | 4 | 4 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G05_STAFF/README.md:1` |
| G06 | Hồ sơ thuê, hợp đồng và tiền cọc | 17 | 17 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G06_TENANCY/README.md:1` |
| G07 | Vòng đời thuê và quyết toán | 7 | 7 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G07_LIFECYCLE/README.md:1` |
| G08 | Hóa đơn, thu tiền và công nợ | 28 | 26 | 1 | 1 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G08_BILLING/README.md:1` |
| G09 | Bảo trì và chi phí vận hành | 5 | 5 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G09_MAINTENANCE/README.md:1` |
| G10 | Công việc, thông tin và hỗ trợ sử dụng | 9 | 7 | 1 | 1 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G10_OPERATIONS/README.md:1` |
| G11 | Báo cáo và giám sát vận hành | 8 | 7 | 1 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G11_REPORTING/README.md:1` |
| G12 | Tài khoản và tài nguyên nền tảng | 12 | 9 | 3 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G12_ADMIN_ACCOUNTS/README.md:1` |
| G13 | Kiểm duyệt và chất lượng nội dung | 11 | 11 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G13_MODERATION/README.md:1` |
| G14 | Dịch vụ hỗ trợ khách hàng | 8 | 6 | 2 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G14_SUPPORT/README.md:1` |
| G15 | Hồ sơ xác minh và gói dịch vụ | 6 | 6 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G15_VERIFICATION_PLANS/README.md:1` |
| G16 | Quản trị chính sách và đối soát nền tảng | 9 | 9 | 0 | 0 | `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/G16_GOVERNANCE/README.md:1` |

## Đọc nhanh

- Toàn bộ mã/tên/actor/trạng thái/đường dẫn: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Coverage_Matrix.md:1`.
- Rà soát gộp/tách, quyền, khoảng trống và điểm cần người dùng xem xét: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Quality_Review.md:1`.
- Quy tắc đọc nguồn, validation và kiểm chứng: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Verification_Method.md:1`.
- Manifest: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/data/spec-manifest.json:1`; ghi chú nghiệp vụ cấu trúc: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/data/behavioral-analysis.json:1`.
- Kết quả kiểm định: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Validation_Result.json:1`, `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Markdown_Parse_Result.json:1`, `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Source_Integrity_Result.json:1`.
- Test thực thi lượt này: `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` — **71 suite / 736 test passed**. Bản 6 suite/24 test của đợt G01 giữ tại `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_G01_Previous.json:1`.

## Nguồn và giới hạn

Nền phân tích lịch sử: `/Users/hoang/Rental_room_management/docs/ba/uc-revision-2026-10-29/BA_AS_IS_Dot_1.md:1`. Chưa có gói xuất chuẩn `01_System_Analysis/`; không tuyên bố đã xuất Giai đoạn 1 chỉ vì có nền phân tích.

FDD, Actor–UC Matrix, Catalog và truy vết Giai đoạn 2 được dùng làm hợp đồng mã/actor; logic phải đối chiếu lại source. 21 trang UML module biểu diễn đủ 162 UC (28 trang tổng cộng khi tính thêm các trang tổng quan/Actor); giữ nguyên associations và không tự thêm include/extend/generalization. Nguồn chi tiết tại `/Users/hoang/Rental_room_management/BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/README.md:1` và `/Users/hoang/Rental_room_management/BA_Documentation/05_Use_Case_Diagrams/README.md:1`.

Không sửa source ứng dụng, Catalog hoặc UML. Chỉ bổ sung/cập nhật Giai đoạn 4 và chỉ mục BA. 846 source và toàn bộ gói Giai đoạn 2/3 được kiểm hash; 11 đặc tả G01 giữ nguyên nội dung. Tệp khóa Word bị xóa từ trước đã được người dùng xác nhận giữ nguyên; không khôi phục và không commit.

## Tự kiểm tra

```sh
python3 BA_Documentation/06_Detailed_Use_Cases/tools/validate-markdown.py
node BA_Documentation/06_Detailed_Use_Cases/tools/validate.cjs
```

Parser Markdown AST kiểm hình dạng bảng thật. Validator kiểm coverage/mã/actor/trạng thái/nhánh/truy vết/UML/hash và test record; **không thay thế** rà soát ngữ nghĩa hoặc thử runtime. Không xuất Word/PDF trong lượt này.

Kết quả kiểm định cuối: **162/162 bảng hợp lệ; 9.512/9.512 kiểm tra đạt; 457 tệp bằng chứng; bảo toàn source/Catalog/UML và 11 bảng G01**. Bộ backend unit/mock chạy lại đạt 71 suite/736 test. Giữ nguyên mọi giới hạn và trạng thái xác minh đã nêu, không xem số kiểm định tài liệu là số test nghiệp vụ.
