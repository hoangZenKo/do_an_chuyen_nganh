# Demo kiểm thử hệ thống trên iOS Simulator

File chạy chính: `system_demo.mjs`. Các kịch bản được chia bằng comment
`// PHẦN 01`, `// PHẦN 02`... bằng tiếng Việt. Không thay thế `lib/main.dart`.

## Chạy

Từ thư mục gốc dự án:

```sh
npm ci --prefix test/system_demo
npm --prefix test/system_demo run demo -- --delay=2500
```

Lệnh thứ hai tự tạo dữ liệu thử, khởi động API/Appium, build bản debug, mở
Simulator `Rental System Demo`, đổi tài khoản và thực hiện các kịch bản.
Mỗi thao tác nghỉ 2,5 giây; giữa các mục nghỉ 4 giây. Banner xanh trên app
hiển thị thao tác hiện tại. Không cần chạy server cổng 3000 trước.
Sau phần nhìn thấy trên Simulator, chương trình chạy các bộ test hiện có.
Không bấm tay vào Simulator khi bộ test đang thao tác.

Yêu cầu trên máy Mac:
- Node.js >= 24, npm; đã cài dependency backend (`npm ci --prefix backend`).
- Flutter, Xcode, CocoaPods và một iOS runtime đã cài trong Xcode.
- PostgreSQL local đang chạy; `psql` có trên PATH; user trong
  `backend/.env` có quyền CREATE DATABASE và DROP database do mình tạo.
- `DATABASE_URL` trong môi trường, hoặc `backend/.env`, chỉ được trỏ local.
- Internet cho lần đầu tải package, driver và build dependency.

Đặt `FLUTTER_BIN` nếu Flutter không ở PATH. Thiết lập riêng trong shell không
cần đưa vào Git:

```sh
export FLUTTER_BIN=/duong/dan/flutter/bin/flutter
```

## Chạy từng nhóm

Muốn copy lệnh riêng theo từng chức năng (đăng nhập, đăng ký, sửa chữa...):
mở `CHAY_TUNG_CHUC_NANG.md` cùng thư mục. Mỗi mục có một lệnh độc lập,
đã kèm nhóm tiên quyết cần thiết; không phải chạy lần lượt cả danh sách.

```sh
# Chỉ lập danh mục route/nút/test từ mã nguồn, không sửa dữ liệu.
npm --prefix test/system_demo run inventory

# Từ đăng nhập đến sửa chữa hai vai trò; nhanh hơn để kiểm tra script.
npm --prefix test/system_demo run demo -- --delay=700 --sections=login,contract,deposit,billing,maintenance

# Tạo khu trọ/phòng rồi tạo tin, gửi duyệt, admin duyệt.
npm --prefix test/system_demo run demo -- --sections=login,property,room,listing

# Mở các màn hình đã đăng ký (SCREEN SMOKE, không phải test mọi nút).
npm --prefix test/system_demo run smoke

# Chỉ chạy các Flutter/unit/API suites, không mở Simulator.
npm --prefix test/system_demo run demo -- --sections=regression

# Kiểm tra logic của chính bộ chạy.
npm --prefix test/system_demo test
```

`--sections` chọn chính xác nhóm, không tự chọn dependency. Luôn thêm `login`
khi chạy UI. `listing` và `room-services` cần thêm `room`; nếu thiếu hoặc ca
trước lỗi, ca phụ thuộc báo `blocked`, không báo đạt giả. Lần chạy nào cũng có
dữ liệu nền mới cho các ca độc lập. `--device=UDID` chỉ dùng khi cố ý chọn máy
ảo khác; mặc định không cài đè lên máy ảo demo cá nhân.

Nhấn Ctrl+C để dừng và dọn tài nguyên. `--keep-database` giữ lại DB thử phục
vụ điều tra; tên DB nằm trong log. Không có mật khẩu trong `fixtures.json`.
SIGKILL, máy mất điện hoặc Terminal bị cưỡng bức đóng không thể bảo đảm dọn DB.

## Các phần có trong file chạy

| Phần | Nhóm `--sections` | Thao tác / mức kiểm thử |
| --- | --- | --- |
| 01 | login | Đăng nhập thật người thuê, chủ trọ, nhân viên, admin |
| 02 | inventory | Đăng ký tài khoản tìm trọ mới, kiểm tra không tự tạo hợp đồng |
| 03 | property | Tạo/sửa khu trọ và đối chiếu DB |
| 04 | room | Chọn khu, tạo/sửa phòng, mở Info/Ảnh/Lịch/Hợp đồng |
| 05 | tenant | Tạo/tìm/sửa người thuê, mở hồ sơ từ phòng và quay lại |
| 06 | listing | Tạo bản nháp → gửi duyệt → admin duyệt nội dung |
| 07 | housing | Xem tin, lưu yêu thích, kiểm tra danh sách đã lưu |
| 07B | housing | Đặt/đổi/hủy lịch, đặt lại, xác nhận, đã xem sớm, tạo hợp đồng |
| 08 | contract | Chủ trọ lập bàn giao, người thuê xác nhận nhận phòng |
| 09 | deposit | Ghi thu cọc, đối chiếu sổ cọc ở tài khoản người thuê |
| 10 | billing | Upload chứng từ, chưa tự cộng tiền, chủ trọ duyệt, kiểm tra số dư |
| 10B | billing | Tạo hóa đơn qua form, người thuê xem kỳ mới, chủ trọ hủy có lý do |
| 11 | maintenance | Báo sự cố → xử lý → phản hồi → hoàn tất → người thuê xem |
| 12 | expense | Thêm chi phí, kiểm tra khoản lưu, mở báo cáo |
| 13 | renewal | Yêu cầu gia hạn → duyệt không tự thực hiện → thực hiện riêng |
| 14 | occupants | Thêm/xóa người ở cùng, đối chiếu hai vai trò |
| 15 | notifications | Mở thông báo, tài khoản, Zalo nội bộ, hỗ trợ (screen) |
| 15B | support | Chủ trọ tạo ticket, admin phản hồi, chủ trọ nhận nội dung |
| 15C | security | Đổi mật khẩu thật và đăng nhập lại hai vai trò |
| 15D | room-services | Tạo biểu phí dịch vụ của phòng |
| 16 | screens | Quét route theo quyền, kiểm tra lỗi tải/render và chụp ảnh |
| 17 | staff | Kiểm tra màn hình được cấp quyền và dữ liệu khu được cấp |
| 17B | staff | Tạo mã mời nhân viên, kiểm tra phạm vi và màn quản lý quyền |
| 18 | admin | Mở phân hệ tài khoản, tìm kiếm, kiểm duyệt, vận hành, bảo mật (screen) |
| 19 | checkout | Yêu cầu/duyệt trả phòng, xem trước, xác nhận quyết toán, ghi hoàn cọc |
| 20 | regression | Flutter tests, backend unit, Node safety tests và từng API E2E |

Các suite hiện có được phát hiện động; bao gồm kiểm tra phân quyền, nhiều
landlord, lỗi validation, billing/receipt/refund, chuyển phòng, tranh chấp,
thông báo, báo cáo, admin, vận hành, upload và bảo mật theo những assertion
thực tế của mỗi suite. Script không tự viết lại assertion để làm xanh test.
File `.local.` phụ thuộc môi trường QA cũ không tự chạy trên DB cá nhân.

## An toàn và các hook chỉ dành cho kiểm thử

- Mỗi lượt tạo `rental_ui_test_<timestamp>_<random>` riêng; mỗi API suite cũng
  có DB riêng theo đúng guard của suite. Không truncate DB gốc.
- Chạy backend cổng ngẫu nhiên, uploads nằm trong thư mục output của lượt đó.
  Không dùng tài khoản người dùng đã có. DB thử mặc định bị xóa khi kết thúc.
- Các worker gửi tin, provider thanh toán thật và chatbot thật không bật.
  Suite recovery dùng endpoint `.example.test` theo runner gốc, worker tắt.
- `appium_main.dart` từ chối release và API không local/cổng 3000. Secure
  storage có namespace riêng. Nó vẫn chạy widget và repository thật của app.
- Route hook chỉ đưa app tới route nội bộ; **không kiểm thử rằng nút/menu dẫn
  tới route đó đúng**. Các thao tác form/submit vẫn qua UI và backend thật.
- File picker được thay trong entrypoint kiểm thử bằng PNG mẫu ở temp. Upload,
  xác thực quyền và gửi chứng từ vẫn chạy thật; **native picker chưa được test**.
- Tắt frame synchronization để vòng chờ không kẹt trên loading animation;
  thay bằng chờ có timeout và assertion màn hình/DB. Không tắt bảo mật backend.
- Những lượt chạy nhanh vẫn chờ khi gần giới hạn đăng nhập thật của app.
- Chỉ dừng các tiến trình do bộ chạy tạo. Không dừng server cá nhân cổng 3000.

## Đọc kết quả

Mỗi lượt tạo thư mục `output/system-demo/<run-id>/`:

- `report.html`, `report.json`: từng ca `passed`, `failed`, `blocked`, mức test.
- `coverage-inventory.json`: route/nút có vị trí nguồn và danh sách suite.
- `coverage.json`: kết quả screen smoke theo route, nhãn nào đã gặp và phạm
  vi còn thiếu. Nhãn đã gặp **không đồng nghĩa** thao tác nguồn đó đã được test.
- PNG, `*-state.json`: ảnh và trạng thái UI khi lỗi; `steps.json`: thứ tự thao tác.
- `flutter-run.log`, `backend.log`, `appium.log`, các `*.e2e-spec.ts.log`:
  chẩn đoán hạ tầng và từng bộ test. `progress.json` cập nhật sau từng mục UI.

Exit code 0 chỉ có nghĩa **các ca đã chọn đạt**. Exit code 1 là có lỗi/bị chặn.
Nhóm không chọn không tính là đạt. `allFunctionsVerified` luôn là `false`:
chưa có ánh xạ assertion cho mọi nút, mọi trạng thái và mọi tổ hợp dữ liệu.

**Không hứa “100% toàn bộ chức năng đã được kiểm chứng”.** Đây là demo UI
liên vai trò, screen sweep và toàn bộ suite tự động hiện có, không phải bằng
chứng mọi chức năng trong ứng dụng đã có UI test đầy đủ.

Còn cần kiểm chứng riêng: mọi thao tác quản trị nâng cao/chỉnh quyền, toàn bộ
biến thể biểu phí và bulk invoice, chuyển phòng đầy đủ qua UI, activation qua
email/link thật, OTP/MFA enrollment, upload qua picker hệ điều hành, PDF/in/chia
sẻ, ứng dụng Zalo/ngân hàng bên ngoài, provider thực và accessibility trên
thiết bị thật. Ca backend đạt không thay thế việc bấm thử các phần này.

## Kết quả kiểm chứng ngày 30/10/2026

Đã chạy thực tế trên iOS Simulator `Rental System Demo`, không chỉ viết mã.
Các con số sau thuộc **những lượt chạy khác nhau**; không cộng chúng thành
một lượt chạy toàn hệ thống thành công:

- Danh mục nguồn: 89 route, 592 nhãn thao tác ứng viên, 103 file Flutter test,
  36 API E2E suites và 5 file test an toàn cho script. Nhãn không phải coverage.
- Screen sweep: 82/82 route được chọn mở được. Không chứng minh mọi nút đúng.
- Backend unit: 746 đạt, 7 bỏ qua; API E2E: 263 đạt, 6 lỗi trong 5 suites.
- Flutter: 782 đạt, 1 lỗi tương phản ở màn hình tìm kiếm người thuê.
- Test an toàn của backend scripts: 19/19 đạt; helper của bộ demo: 11/11 đạt.
- Dart analyze không có lỗi; Dart format không phát sinh thay đổi.
- Lượt tập trung cuối đã đi qua tạo/tìm/sửa người thuê, thu cọc, chứng từ và
  quyết toán/ghi nhận hoàn cọc. Tạo/xem/hủy hóa đơn và hỗ trợ vẫn báo lỗi runtime.

Lỗi còn được giữ nguyên trong báo cáo, **chưa sửa mã ứng dụng**:

- Hủy hóa đơn: `TextEditingController was used after being disposed`, kèm lỗi
  layout/widget tree; không coi là đạt dù DB đã ghi nhận thao tác.
- Hỗ trợ: overflow 12 px; lượt sau lỗi hóa đơn còn gặp Duplicate GlobalKeys,
  nên cần tái hiện độc lập để phân biệt lỗi gốc với lỗi dây chuyền.
- API: `billing-production`, `lease-settlement`, `operations`,
  `production-safety`, `security-discovery` có ca không đạt; xem log từng suite,
  không kết luận tất cả đều là lỗi sản phẩm trước khi điều tra.

Báo cáo nằm trong các thư mục sau, tính từ gốc dự án:

- Regression: `output/system-demo/1793322006840_76544ca7504d/report.html`.
- Screen sweep: `output/system-demo/1793322512819_952c81458554/report.html`.
- UI tập trung: `output/system-demo/1793323037123_2a4912164082/report.html`.
- Smoke cuối: `output/system-demo/1793323365007_7239cfd3b206/report.html`.

Hai lượt screen/UI trước gặp `kill EPERM` khi dọn tiến trình; báo cáo được
khôi phục từ `progress.json`, có ghi lỗi hạ tầng, DB thử được dọn thủ công.
Runner hiện có fallback dừng tiến trình và test cho trường hợp này. Smoke cuối
dùng bản mới: đăng nhập đủ bốn vai trò đạt, xuất báo cáo bình thường, exit 0,
đã xác nhận DB thử không còn và không còn API/Appium do runner đó khởi tạo.
Smoke cuối **chỉ kiểm tra đăng nhập/hạ tầng**, không xác nhận lại mọi ca UI.

## Tài liệu công cụ

- Appium Flutter Driver: https://github.com/appium/appium-flutter-driver
- Flutter integration testing: https://docs.flutter.dev/testing/integration-tests
