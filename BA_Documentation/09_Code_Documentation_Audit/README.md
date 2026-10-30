# Đối chiếu tài liệu Use Case với mã nguồn

Chốt ngày 30/10/2026; bắt đầu kiểm tra ngày 29/10/2026. Chỉ sửa tài liệu và ảnh trong báo cáo, không sửa source ứng dụng.

## Đọc kết quả

- `01_Findings_and_Corrections.md`: 7 điểm cần đính chính ở 5 UC, 1 đường dẫn lịch sử bị đứt, bằng chứng và giới hạn.
- `02_Use_Case_Audit_Ledger.md`: đủ 162 UC, phân biệt kiểm tra truy vết diện rộng với 43 UC được rà soát các quy tắc ưu tiên. Không phải chứng nhận đã rà soát mọi câu.
- `data/audit-validation.json`: kết quả kiểm tra cuối cùng.
- `data/diagram-code-audit.json`: 272 liên kết trên 30 ảnh, gồm 7 liên kết giới hạn.
- `data/word-corrections.json`: 23 trường đính chính ở 5 UC; giữ V4, xuất V5 và thay 30 ảnh trắng đen.

## Báo cáo sử dụng tiếp

`/Users/hoang/Desktop/ĐỒ ÁN/Bao_cao_Quan_ly_Nha_tro_V5_2026-10-30_Doi_chieu_Code.docx`

V5 cập nhật các điểm đã có bằng chứng sai và mục lục. Các phần ngoài phạm vi Use Case được giữ theo báo cáo cũ; không xem đó là đã kiểm chứng lại toàn bộ sơ đồ lớp, tương tác, giao diện hoặc kết quả lịch sử. Ảnh tổng có 12 mục tiêu đại diện; 29 ảnh nhóm bao phủ đủ 162 UC.

## Giới hạn bắt buộc giữ

Đây là đối chiếu source, phép thử quyền và unit/widget/mock, chưa là nghiệm thu đầu-cuối trên DB và dịch vụ bên ngoài. Không gọi kết quả này “khớp 100%”. Các bản validation/hash cũ mô tả thời điểm trước đính chính; bản gốc được bảo toàn tại `data/baselines/`. Không xóa dấu vết để làm cho hash cũ trông như chưa đổi.
