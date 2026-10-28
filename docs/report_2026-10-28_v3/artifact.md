# Hợp đồng dựng báo cáo từ mẫu V1

## Nguồn bất biến
Mẫu: /Users/hoang/Rental_room_management/docs/CSE703014_Report_Template_VI_V1.docx; SHA-256 a0afe993c3d04a4c90ad810b9eadccf48b31d5be60a0ef5c998eeb6237436604.
Bản dở: /Users/hoang/Rental_room_management/docs/Bao_cao_da_chinh_form.docx; SHA-256 1b84f983810ab5a794c23d871f602aa4b0f7b9ad412da6ab654d361e772923c1.
Mẫu có 6 trang sau render, 2 section; ảnh render tại /tmp/rental-report-20261028/template.
Bản dở có 200 trang render, 67 bảng UC; không dùng các số trang/mục lục cũ làm dữ liệu cuối.

## Hình thức giữ từ mẫu
Section bìa: Legal 8.5 × 14 inch, dọc, lề 1 inch, khoảng header/footer 0.5 inch.
Section nội dung: Letter 8.5 × 11 inch, dọc, lề 1 inch, header/footer 0.5 inch.
Times New Roman; nội dung 13 pt, đen, căn đều; heading 1/2/3 đậm đen theo vai trò mẫu.
Logo khoa từ media của mẫu; bìa trường/khoa/tên đồ án/các thông tin quản lý; ngày 28/10/2026.
Bảng viền đen, nền trắng hoàn toàn theo yêu cầu người dùng; font bảng 11.5 pt, line 1.0 để bảng UC đầy đủ không phải thu nhỏ hình.
Heading phân cấp 1–5 theo mẫu; use case chi tiết cấp 4 không phá số chương; giữ nhóm UC trong 2.4.1.
Các sơ đồ đặt trong 2.4.2–2.4.4, giao diện 2.4.5; không dán nguyên các tài liệu cũ làm chương riêng.
Footer đánh số trang cập nhật theo nội dung; không giữ giá trị PAGE cũ. Mục lục theo bookmark, lấy số trang từ PDF kiểm tra.

## Slot được thay
word/document.xml body: thay toàn bộ placeholder/nội dung mẫu bằng nội dung dự án; giữ style/theme/numbering definitions trong package gốc.
word/styles.xml: chuẩn hóa đen và cỡ chữ có kiểm soát; bỏ đánh số tự động trùng số heading đã viết.
word/document.xml sectPr: giữ đúng kích thước và lề; xóa trang trắng và các break thừa trong mẫu để mục lục không phát sinh trang rỗng.
word/header*.xml, footer*.xml: thay field số trang và liên kết phù hợp section mới; không giữ số trang cached từ mẫu.
Ảnh: giữ logo mẫu; thay sơ đồ cũ bằng sơ đồ mới; UI từ ảnh widget của source hiện tại, ghi rõ fixture.
customXml, metadata và quan hệ phần không sửa: giữ trong cơ chế mở từ template; thêm core title/date, không gán tác giả sinh viên không xác minh.
Toàn bộ package inventory ghi trong CSE703014_Report_Template_VI_V1-parts.json; nguồn gốc không bị ghi đè.

## Cổng kiểm tra
131 UC có mã duy nhất; luồng chính/thay thế/ngoại lệ/đầu vào/quy tắc/truy vết.
Schema đọc trực tiếp: 109 model; 399 route khai báo. Sơ đồ phân rã, không vẽ một hình quá dày.
Không hư cấu tên/MSSV/giảng viên, phân công hoặc lịch sử họp. Phần chưa có dữ liệu hành chính được đánh dấu công khai.
Không đồng nhất code có sẵn với nghiệm thu. Test backend/Flutter ghi theo log chạy mới, không lấy số cũ.
Render toàn bộ DOCX; kiểm tra PNG, text tràn, heading mồ côi, bảng/hình, phần tham khảo và mục lục; chỉ giao DOCX cuối.

## Điều chỉnh cuối theo yêu cầu người dùng
Không in danh mục toàn bộ schema/model/FK hoặc endpoint; chỉ giữ sơ đồ lớp theo miền và truy vết UC. 131 UC, 83 panel sơ đồ; có đối chiếu 67 UC cũ. Bảng trắng/viền đen. Snapshot source đối chiếu được lưu riêng ở evidence/, không ghi đè code; số liệu test gắn với từng log, không đồng nhất với mọi sửa đổi tiếp theo.

## V2 theo 8 phan hoi ngay 28/10/2026

Bia tham chieu double border; khong sao chep danh tinh/ten de tai cua anh mau. Bon tac nhan con nguoi, khong trinh bay module nhan su. So do tong dung form tap trung cu, tac nhan stick figure; 19 sequence duoc chia 38 panel voi boundary/control/entity vang va return net dut. Tat ca 131 UC co metadata, luong actor/system va bang ngoai le/hau dieu kien/quy tac/truy vet. Them 28 anh UI dai dien, danh muc 112 hinh co bookmark. A4 dong nhat, le trai 3cm, phai 2cm; bang trang vien den va header lap lai. Khong ghi de ban giao cu.

## V3 theo bon phan hoi moi

Moi UC mot table OOXML; 19 sequence lien mach theo model su kien co nhanh, source anchor; Admin chup moi voi theme sang va font native; phan cong ca nhan mot nguoi. Giu V2; khong doi application code. Danh muc hinh va muc luc do lai tu PDF.
