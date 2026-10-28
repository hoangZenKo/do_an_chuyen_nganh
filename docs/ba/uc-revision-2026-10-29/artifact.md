# Hồ sơ chỉnh sửa tài liệu

- Tệp nguồn là báo cáo V3 của người dùng; SHA-256 giữ nguyên: 198de27e5e6f96734a12125d2c8e3dc1e9c653e82cab2f30dabe8b402cdb3c31.
- Đầu ra là bản UC độc lập đợt 1 thay phần kịch bản UC; không phải bản thay toàn bộ báo cáo hoặc bản đặc tả 164 UC hoàn tất.
- Kế thừa ngôn ngữ học thuật của mẫu: A4, Times New Roman, đen trắng, lề trái 3 cm/phải 2 cm, bảng có lưới. Không sao chép logo, tên tác giả hay số trang cũ.
- Nội dung chỉnh sửa: báo cáo AS-IS, tác nhân/quyền, phân rã, catalog, 9 UC A–J, 2 SP, BR, truy vết và điểm chưa rõ. Các mục còn thiếu được ghi rõ.
- Vùng biên tập tái tạo: tools/auth_specs.py và tools/report_content.py; build_revision.py tạo DOCX và Markdown cùng nguồn dữ liệu.
- Ma trận API đầy đủ ở Requirements_Traceability_Matrix.tsv; đoạn nguồn định vị ở evidence/source-excerpts.md.
- Nguồn và test snapshot không bao gồm secrets hoặc dữ liệu DB; không sửa source ứng dụng.
