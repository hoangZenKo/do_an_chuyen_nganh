# Tai nguyen bao cao V3 ngay 28/10/2026

Ban giao: ../Bao_cao_Quan_ly_Nha_tro_V3_2026-10-28.docx.

- Do an ca nhan, mot sinh vien thuc hien. Chua duoc cung cap ho ten, MSSV, lop, giang vien; khong tu dien.
- Bon tac nhan: Khach vang lai, Nguoi thue, Chu tro, Admin. Khong sua hay xoa module ngoai pham vi trong ung dung.
- 131 UC, moi UC dung mot bang Word that, day du metadata, luong chinh tung buoc, thay the, ngoai le, hau dieu kien, quy tac va truy vet. Bang duoc phep tiep tuc sang trang voi header lap; khong ep mot UC vao mot trang bang cach cat noi dung.
- 64 so do: 24 UC (co tong quan), 18 lop, 19 sequence lien mach, 2 kien truc, 1 doi tuong. Sequence khong chia panel, co alt/opt/loop/break, call/return khai bao tuong minh, activation, guard va source anchor. sequence_model.py va sequence_renderer.py la nguon.
- 28 man hinh UI; tat ca 8 nhom anh Admin trong Word duoc chup lai theo source hien hanh va AdminOverviewTheme.light. Hai anh dai duoc cat tiep noi de doc chu, khong lien quan viec tach so do tuan tu.
- ui-admin-v3.log: 51 test goc dat. ui-admin-capture-v3.log: 51 ca harness dat. ui-admin-native-v3-final.log: chay cung harness khong dung test-font Ahem, All tests passed; runner dem ca setup/teardown. Khong cong cac dot nay thanh ca nghiep vu doc lap.
- capture-admin-manifest.json giu hash anh moi/anh cu; sequence-audit.json giu source/method/line/hash cho 19 sequence. evidence-update-v3.json ghi snapshot Admin va source.
- UC-BIL-16: LANDLORD co billing.tariff_approve; khong phai Admin. Chatbot la RAG tai lieu, khong co tool lay du lieu song. SD-19 bao gom huy goi UC-ADM-22.
- Log backend va bo Flutter rong tu ban truoc duoc giu nhu bang chung snapshot, khong khang dinh da chay lai tren moi thay doi. Chi cac bo Admin/capture tren duoc chay moi trong V3.
- Giu nguyen V2 va hai file goc, khong sua code ung dung, khong seed/reset DB, giao dich tien that hay deploy.

## Dung lai

Runtime Python/Node tu Codex workspace dependencies. Scripts dung /tmp/rental-report-v3-20261028 va ROOT /Users/hoang/Rental_room_management. Thu tu: diagrams.py; render_diagrams.cjs; build_report.py; render_docx.py; measure_pages.py; build lai va render vao thu muc QA moi den khi map trang on dinh; verify_report.py voi thu muc render cuoi. Khong dung so trang cu khi doi noi dung. QA PDF/PNG luu trong /tmp, khong la ban giao Word.
