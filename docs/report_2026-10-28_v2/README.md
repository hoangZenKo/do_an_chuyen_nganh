# Tai nguyen bao cao V2 ngay 28/10/2026

Ban giao chinh: ../Bao_cao_Quan_ly_Nha_tro_V2_2026-10-28.docx.

- Pham vi bao cao: Khach vang lai, Nguoi thue, Chu tro, Admin. Khong sua module nhan su trong ung dung.
- 131 dac ta UC chi tiet; 83 panel so do, gom 24 UC (co so do tong), 18 lop, 38 panel cho 19 luong tuan tu, 2 kien truc va 1 doi tuong.
- 28 anh giao dien dai dien bon tac nhan; A4, Times New Roman, bang trang vien den, bia theo reference, muc luc va danh muc hinh co lien ket.
- Khong in nguyen schema, danh muc FK hay toan bo endpoint. audit.json la inventory doi chieu noi bo, khong la phan bat buoc cua bao cao.
- uc-crosswalk.json doi chieu 67 UC cu. diagrams/ chua PNG/SVG; so do tong la UC-OVERVIEW.svg. report_data.py giu thong diep sequence.
- evidence/ giu snapshot controller/service va SHA-256; evidence-update-v2.json ghi cac source thay doi sau test cu.
- Log test cu: backend 672 dat, 7 bo qua; build dat. Flutter features/data 503 dat, 12 loi. Khong sua ung dung de lam dep ket qua.
- ui-capture-tests.log va ui/: 51 test capture Admin dat.
- ui-capture-v2.log, ui-tenant-capture-v2.log, ui-landlord-capture-v2.log: 11 + 27 + 5 = 43 test dat. capture-tests/ la harness doc-only, ui-v2/ la anh widget that voi fixture; khong phai E2E hoac du lieu nguoi dung that.
- verification.json ghi kiem tra cau truc, pham vi, so trang muc luc/hinh, bang va hash tai lieu goc. PDF/PNG QA chi luu trong /tmp, khong la ban giao.

## Gioi han

Khong reset DB, migrate, seed, giao dich tien that, gui provider hoac production deploy. Test cu khong duoc suy ra bao phu thay doi sau moc chay. Mot so thanh phan reports con do tuong phan thap trong theme hien tai, duoc giu trung thuc va ghi chu trong bao cao. Ho ten, MSSV, lop, giang vien va phan cong thuc te chua duoc cung cap.

## Dung lai

Scripts duoc cau hinh cho /Users/hoang/Rental_room_management va /tmp/rental-report-v2-20261028. Neu doi may, can sua ROOT/TMP, runtime va cac duong dan trong harness. Chuoi dung: diagrams.py; render_diagrams.cjs; build_report.py; render_docx.py vao thu muc moi; measure_pages.py; build lai va render lai; verify_report.py voi thu muc render cuoi. Khong chay audit.py de ghi de audit.json ma chua ra soat scope va evidence. Khong dung so trang cu sau khi doi noi dung.
