# Giai đoạn 3 — UML Use Case AS-IS

Ngày: 29/10/2026 · Git: c565c29ee5742d38dfaea37aa8fa047f4b6793c0.

## Phạm vi

- 162 UC nguồn trong 16 nhóm G01–G16; giữ nguyên toàn bộ mã, tên, mục tiêu, Actor và trạng thái của Catalog Giai đoạn 2.
- 28 sơ đồ độc lập: 1 tổng thể (12 UC đại diện), 21 trang module và 6 góc nhìn STAFF. Module lớn phân trang để đọc, không tách/gộp hay chuyển nhóm UC.
- Mỗi UC xuất hiện đúng một lần trong bộ trang module; lặp có chủ đích ở tổng thể và góc nhìn A03 không là UC trùng Catalog.
- Giữ 151 UC xác minh tĩnh, 9 một phần, 1 DEMO và 1 mô phỏng; sơ đồ không xác nhận triển khai production.
- Không sửa ứng dụng; không viết đặc tả chi tiết, không tạo Actor hoặc quan hệ include/extend/generalization thiếu căn cứ.

## Tài liệu

- Diagram_Validation_Report.md: kết quả kiểm tra và các vấn đề cần xác minh.
- UC_Diagram_Traceability.md: 162 UC → sơ đồ sở hữu → bằng chứng code.
- Association_Traceability.md: nguồn và giới hạn từng đường tương tác, bao gồm V và provider.
- Actor_Coverage_Index.md: toàn bộ phạm vi theo Actor; đối chiếu Matrix Giai đoạn 2.
- data/diagram-manifest.json: danh mục sơ đồ, edge, điều kiện và nguồn dùng kiểm tra tự động.
- Validation_Result.json và Render_Result.json: log kiểm tra dữ liệu và render thực tế.

## Danh mục sơ đồ

| Sơ đồ | Loại | Nhóm | UC | SVG | PNG |
| --- | --- | --- | --- | --- | --- |
| [Overall_Use_Case](Overall_Use_Case.puml) | overall | tổng thể | 12 | [SVG](rendered/Overall_Use_Case.svg) | [PNG](rendered/Overall_Use_Case.png) |
| [UC_G01_01_SYS_Public](UC_G01_01_SYS_Public.puml) | module | G01 | 7 | [SVG](rendered/UC_G01_01_SYS_Public.svg) | [PNG](rendered/UC_G01_01_SYS_Public.png) |
| [UC_G01_02_SYS_Sessions](UC_G01_02_SYS_Sessions.puml) | module | G01 | 4 | [SVG](rendered/UC_G01_02_SYS_Sessions.svg) | [PNG](rendered/UC_G01_02_SYS_Sessions.png) |
| [UC_G02](UC_G02.puml) | module | G02 | 6 | [SVG](rendered/UC_G02.svg) | [PNG](rendered/UC_G02.png) |
| [UC_G03](UC_G03.puml) | module | G03 | 7 | [SVG](rendered/UC_G03.svg) | [PNG](rendered/UC_G03.png) |
| [UC_G04](UC_G04.puml) | module | G04 | 14 | [SVG](rendered/UC_G04.svg) | [PNG](rendered/UC_G04.png) |
| [UC_G05](UC_G05.puml) | module | G05 | 4 | [SVG](rendered/UC_G05.svg) | [PNG](rendered/UC_G05.png) |
| [UC_G06_01_Tenant_Records](UC_G06_01_Tenant_Records.puml) | module | G06 | 8 | [SVG](rendered/UC_G06_01_Tenant_Records.svg) | [PNG](rendered/UC_G06_01_Tenant_Records.png) |
| [UC_G06_02_Leases_Deposits](UC_G06_02_Leases_Deposits.puml) | module | G06 | 9 | [SVG](rendered/UC_G06_02_Leases_Deposits.svg) | [PNG](rendered/UC_G06_02_Leases_Deposits.png) |
| [UC_G07](UC_G07.puml) | module | G07 | 7 | [SVG](rendered/UC_G07.svg) | [PNG](rendered/UC_G07.png) |
| [UC_G08_01_Invoices](UC_G08_01_Invoices.puml) | module | G08 | 11 | [SVG](rendered/UC_G08_01_Invoices.svg) | [PNG](rendered/UC_G08_01_Invoices.png) |
| [UC_G08_02_Collections](UC_G08_02_Collections.puml) | module | G08 | 10 | [SVG](rendered/UC_G08_02_Collections.svg) | [PNG](rendered/UC_G08_02_Collections.png) |
| [UC_G08_03_Tariffs_Periods](UC_G08_03_Tariffs_Periods.puml) | module | G08 | 3 | [SVG](rendered/UC_G08_03_Tariffs_Periods.svg) | [PNG](rendered/UC_G08_03_Tariffs_Periods.png) |
| [UC_G08_04_Reminders](UC_G08_04_Reminders.puml) | module | G08 | 4 | [SVG](rendered/UC_G08_04_Reminders.svg) | [PNG](rendered/UC_G08_04_Reminders.png) |
| [UC_G09](UC_G09.puml) | module | G09 | 5 | [SVG](rendered/UC_G09.svg) | [PNG](rendered/UC_G09.png) |
| [UC_G10](UC_G10.puml) | module | G10 | 9 | [SVG](rendered/UC_G10.svg) | [PNG](rendered/UC_G10.png) |
| [UC_G11](UC_G11.puml) | module | G11 | 8 | [SVG](rendered/UC_G11.svg) | [PNG](rendered/UC_G11.png) |
| [UC_G12](UC_G12.puml) | module | G12 | 12 | [SVG](rendered/UC_G12.svg) | [PNG](rendered/UC_G12.png) |
| [UC_G13](UC_G13.puml) | module | G13 | 11 | [SVG](rendered/UC_G13.svg) | [PNG](rendered/UC_G13.png) |
| [UC_G14](UC_G14.puml) | module | G14 | 8 | [SVG](rendered/UC_G14.svg) | [PNG](rendered/UC_G14.png) |
| [UC_G15](UC_G15.puml) | module | G15 | 6 | [SVG](rendered/UC_G15.svg) | [PNG](rendered/UC_G15.png) |
| [UC_G16](UC_G16.puml) | module | G16 | 9 | [SVG](rendered/UC_G16.svg) | [PNG](rendered/UC_G16.png) |
| [Actor_A03_01](Actor_A03_01.puml) | actor | A03 | 5 | [SVG](rendered/Actor_A03_01.svg) | [PNG](rendered/Actor_A03_01.png) |
| [Actor_A03_02](Actor_A03_02.puml) | actor | A03 | 13 | [SVG](rendered/Actor_A03_02.svg) | [PNG](rendered/Actor_A03_02.png) |
| [Actor_A03_03](Actor_A03_03.puml) | actor | A03 | 13 | [SVG](rendered/Actor_A03_03.svg) | [PNG](rendered/Actor_A03_03.png) |
| [Actor_A03_04](Actor_A03_04.puml) | actor | A03 | 8 | [SVG](rendered/Actor_A03_04.svg) | [PNG](rendered/Actor_A03_04.png) |
| [Actor_A03_05](Actor_A03_05.puml) | actor | A03 | 16 | [SVG](rendered/Actor_A03_05.svg) | [PNG](rendered/Actor_A03_05.png) |
| [Actor_A03_06](Actor_A03_06.puml) | actor | A03 | 5 | [SVG](rendered/Actor_A03_06.svg) | [PNG](rendered/Actor_A03_06.png) |

## Cách đọc đúng

Ellipse là UC thật, Actor nằm ngoài biên “Hệ thống quản lý nhà trọ”. Nhãn nhóm chỉ ở tiêu đề, không phải UC. Association là đường liền không hướng, không diễn tả thứ tự. Đường xanh có nhãn là V hạn chế. Khách chưa đăng nhập dùng A01; A04 không được chuyên biệt hóa thành hai security role. Provider E01–E05 là bên ngoài biên triển khai, kể cả khi được đặt trên máy nội bộ; chưa chứng minh được kết nối runtime.

Điều kiện ownership, trạng thái dữ liệu, permission, feature flag, MFA/step-up vẫn áp dụng dù không ghi dài trên mỗi đường. Không nối mọi UC vào Đăng nhập; đó là tiền điều kiện, không phải include. Không nối đề nghị→duyệt→thực thi bằng include/extend chỉ vì có thứ tự.

## Tái tạo và kiểm tra

```sh
node BA_Documentation/05_Use_Case_Diagrams/tools/generate.cjs
node BA_Documentation/05_Use_Case_Diagrams/tools/validate.cjs
JAVA_BIN=/opt/homebrew/opt/openjdk@17/bin/java PLANTUML_JAR=/tmp/ba-stage3-tooling/plantuml-1.2026.9.jar GRAPHVIZ_DOT=/Users/hoang/Rental_room_management/BA_Documentation/05_Use_Case_Diagrams/tools/graphviz-dot.cjs VIZJS_MODULE=/tmp/ba-stage3-tooling/graphviz/node_modules/@viz-js/viz node BA_Documentation/05_Use_Case_Diagrams/tools/render.cjs
```

Nếu chưa có Graphviz native, cài bộ WASM ngoài dự án: npm install --prefix /tmp/ba-stage3-tooling/graphviz --no-audit --no-fund @viz-js/viz@3.17.0. Chạy validator sau khi render; visualInspection được đánh dấu bởi người kiểm tra sau khi xem ảnh, không tự xác nhận bằng script render.

Các script chỉ ghi trong thư mục tài liệu này. generate.cjs tái sinh .puml, manifest và bảng truy vết từ Catalog, không sửa Catalog. Render dùng PlantUML 1.2026.9 + Graphviz 13.1.2 qua @viz-js/viz 3.17.0 cục bộ, Java 17. Có thể thay bằng Graphviz dot native; không gửi sơ đồ lên dịch vụ công khai. Bản Smetana thử ban đầu có lệch điểm nối tại UC gắn stereotype nên không dùng cho bản bàn giao. JAR/runtime không đóng gói vào repository. Xem Render_Result.json để biết hash JAR, exit code và kích thước từng ảnh.
