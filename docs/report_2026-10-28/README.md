# Tai nguyen bao cao ngay 28/10/2026

Ban giao chinh: ../Bao_cao_Quan_ly_Nha_tro_hoan_chinh_2026-10-28.docx.

- Bao cao theo template V1; khong ghi de hai tai lieu goc va khong sua code ung dung.
- 132 dac ta UC, 64 so do; bang trang, vien den. Khong in nguyen schema, danh muc FK hay toan bo endpoint API.
- uc-crosswalk.json doi chieu tung UC trong 67 UC cua ban do sang dac ta moi.
- diagram-manifest.json va diagrams/ chua PNG/SVG va DOT; sequence lay thong diep tu report_data.py.
- audit.json la inventory noi bo de doi chieu, khong phai mot phan bat buoc cua bao cao.
- evidence/ giu ban chup doc-only cua service/controller duoc dung trong dot doi chieu; manifest.json ghi SHA-256. Repository dang phat trien nen file lam viec co the tiep tuc thay doi; ban chup nay giup khong nham cac moc.
- backend-tests-latest.log: 672 test dat, 7 bo qua; 65 suite dat, 1 bo qua. backend-build-latest.log: exit 0.
- flutter-tests-latest.log: 503 dat, 12 loi; 11 dashboard navigation va 1 legacy admin status finder. Khong sua ung dung de lam dep ket qua.
- ui-capture-tests.log va ui/: 51 test capture dat, du lieu fixture, khong phai nghiem thu thiet bi/provider.
- verification.json ghi ket qua kiem tra Word va muc luc theo PDF render; PDF/PNG QA luu trong /tmp/rental-report-20261028/, khong phai ban giao.

## Pham vi va gioi han

Khong chay E2E reset database, migrate, seed, provider that, thanh toan that hoac production deploy. Ket qua test thuoc snapshot cua tung lan chay (backend khoang 05:04, Flutter khoang 05:07 UTC+7); thay doi sau do chi duoc doi chieu tinh, khong tu coi da dat test. Thong tin hanh chinh va phan cong thuc te can chu nhom cung cap.

## Dung lai

Script dung bao cao hien duoc cau hinh cho workspace /Users/hoang/Rental_room_management va thu muc lam viec /tmp/rental-report-20261028. Khong chay blind tren may khac. Neu can dung lai, sua ROOT/TMP, runtime Node/Python va cac duong dan tai nguyen trong cac script; tao thu muc QA moi, render lai toan bo va do lai muc luc sau moi thay doi phan trang. Khong dung muc luc cu khi noi dung thay doi.
