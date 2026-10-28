# Rà soát dự án trước khi phát triển tiếp

Ngày kiểm tra: **04/10/2026**, múi giờ Asia/Ho_Chi_Minh.

## 1. Kết luận

**Nền tảng đã đủ để phát triển tiếp sau một vòng ổn định, nhưng chưa nên coi là sẵn sàng production.**

Frontend phân tích tĩnh sạch, build iOS release không ký thành công; backend build và 59 unit test thành công. Tuy nhiên, có lỗi đã tái hiện trong khôi phục phiên, cache theo tài khoản, duyệt chứng từ, phục vụ file upload và entry point Docker. Bộ Flutter test hiện tại còn hai test lỗi.

Trong đợt kiểm tra này không sửa code ứng dụng, không commit, không reset database, không chạy migration ghi dữ liệu. File báo cáo này là tài liệu mới; các reproduction test nằm ngoài repository trong `/tmp/rental-room-project-audit/`.

## 2. Phạm vi và kiến trúc

| Thành phần | Vị trí | Cấu trúc hiện tại |
|---|---|---|
| Flutter client | `/Users/hoang/Rental_room_management` | 125 file trong `lib/`, 21 file test; Riverpod, GoRouter, Dio, secure storage |
| NestJS API | `backend` | Controllers/services theo domain; Prisma và PostgreSQL; JWT, role và staff permissions |
| Database migrations | `backend/prisma/migrations` | 21 migration; lịch sử migration của database local đang up to date |
| Nền tảng mobile | `/Users/hoang/Rental_room_management/ios` | iOS scaffold và build release không ký hoạt động |
| Web/Android | Frontend workspace | `web/` không có `index.html`; không thấy scaffold Android |

Các nhóm nghiệp vụ đã đối chiếu qua routes, providers, API/services, schema, test và tài liệu:

- Splash/onboarding; đăng ký, đăng nhập, refresh, restore, logout; routing cho admin/landlord/tenant/staff.
- Admin quản lý landlord/property; staff invitations và permission checks.
- Property/room lifecycle; tài sản phòng, kiểm tra phòng và phí dịch vụ.
- Tenant/account/invite; lease, kết thúc/gia hạn hợp đồng, tiền cọc và lịch sử thay đổi.
- Meter readings, hóa đơn, thanh toán, đảo thanh toán, chứng từ và billing automation.
- Tenant portal, maintenance, expenses, reports, dashboard, audit, notifications và operations.
- Upload, PDF/share, messaging simulator/ZNS, cấu hình chạy và Docker.

Đây là rà soát tĩnh kết hợp các kiểm tra có thể thực hiện an toàn tại local, không phải chứng nhận rằng mọi màn hình và luồng production đã được kiểm thử end-to-end.

## 3. Kết quả kiểm tra thực tế

| Kiểm tra | Kết quả | Ghi chú |
|---|---|---|
| `flutter analyze --no-pub` | PASS | Không có analyzer issues |
| `flutter test --no-pub --reporter expanded` | FAIL | 110 test qua, 2 test onboarding lỗi; kết quả lặp lại ở lần chạy thứ hai |
| `flutter build ios --release --no-codesign --no-pub` | PASS | Sinh `Runner.app`, khoảng 70.2 MB; chưa ký, chưa chạy thiết bị thật |
| `flutter build web --no-pub` | FAIL | `Missing index.html`; không xem đây là lỗi iOS vì product hiện ưu tiên iOS |
| `dart format --output=none --set-exit-if-changed lib test` | FAIL | 146 file được kiểm tra; 28 file cần format; chế độ này không ghi thay đổi |
| Backend `npm run build` | PASS | Artifact entry point nằm tại `dist/src/main.js` |
| Backend `npm test -- --runInBand` | PASS | 8 suite, 59 test |
| Backend ESLint, không dùng `--fix` | FAIL | Không tìm thấy ESLint configuration |
| `prisma validate` | PASS | Schema hợp lệ |
| `prisma migrate status` | PASS | Database local `rental_management`: 21 migration, up to date |
| Test tạm cho restore/cache/upload MIME | 2 FAIL, 1 PASS | Hai lỗi restore/cache tái hiện; MIME của PNG từ Flutter đúng, không có cơ sở kết luận lỗi MIME của client |
| Concurrent payment-proof review harness | FAIL theo invariant mong đợi | Cùng một proof tạo hai payment; dùng service build thật và Prisma transaction double, không ghi database |
| Standalone upload/static HTTP harness | Xác nhận vấn đề | File HTML khai báo MIME ảnh được nhận; GET không auth trả 200 và `text/html`; static response thiếu headers Helmet |
| Build với layout `COPY` của Docker, trong thư mục tạm | PASS build, FAIL entry-point check | `dist/src/main.js` tồn tại; `dist/main.js` không tồn tại |
| Backend E2E | CHƯA CHẠY | Suite reset database; môi trường xác minh hiện là database local đang dùng, không tự ý dùng làm test database |

Toolchain local đã kiểm tra: Flutter 3.29.2, Dart 3.7.2, Node 24.7.0, npm 11.5.1, iPhoneOS SDK 18.4. Đây là phiên bản đã cài trên máy, không phải khuyến nghị phiên bản mới nhất.

## 4. Các phát hiện ưu tiên cao — P1

### F01. Restore ghi đè token đã được rotate

Nguồn: `/Users/hoang/Rental_room_management/lib/data/auth/auth_repository.dart:39`; interceptor tại `/Users/hoang/Rental_room_management/lib/core/network/api_client.dart:44`.

- `restore()` đọc session cũ, sau đó gọi `/auth/me`.
- Khi access token hết hạn, interceptor refresh, lưu token mới và retry `/auth/me` thành công.
- Repository lại tạo session từ token đã đọc trước đó và ghi đè token mới.
- Reproduction mong đợi `new-refresh` nhưng nhận `old-refresh`.
- Hậu quả: request tiếp theo có thể dùng refresh token đã bị consume, dẫn tới phiên bị vô hiệu hóa và yêu cầu đăng nhập lại.
- Hướng sửa: thống nhất một nơi điều phối refresh/session; không ghi token từ snapshot trước request sau khi request có thể đã rotate token. Thêm regression test ở seam repository + interceptor.

### F02. Cache dữ liệu không được cô lập theo tài khoản

Nguồn: `/Users/hoang/Rental_room_management/lib/features/rooms/room_providers.dart:33`; `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_providers.dart:31`; `/Users/hoang/Rental_room_management/lib/features/auth/auth_providers.dart:111`.

- Một số `FutureProvider` không `autoDispose`, không phụ thuộc identity/session; logout chỉ đổi trạng thái session và xóa credentials.
- Cùng một `ProviderScope`, tài khoản A tải property, logout, tài khoản B login: `propertiesProvider` vẫn trả property của A.
- Reproduction mong đợi `property-account-b` nhưng nhận `property-account-a`.
- Hậu quả: lộ dữ liệu đã cache trên cùng thiết bị và selected-property cũ có thể gây lỗi tải dữ liệu của B. Đây là lỗi client cache, không đồng nghĩa đã bypass ownership API.
- Hướng sửa: key/cache lifecycle theo user identity; reset selected property và invalidate dữ liệu theo session boundary. Kiểm tra tenant/room detail và các cache tương tự, không chỉ property list.

### F03. Một chứng từ có thể được ghi nhận thanh toán hai lần

Nguồn: `backend/src/billing/billing.service.ts:1073`; kiểm tra pending tại dòng 1085; khóa invoice tại dòng 1095; cập nhật proof tại dòng 1148.

- Hai transaction có thể cùng đọc proof là `PENDING` trước khi transaction nào khóa invoice.
- Invoice được khóa nên số dư được cập nhật tuần tự, nhưng trạng thái proof không được kiểm tra lại/claim atomically sau lock.
- Nếu proof chỉ thanh toán một phần và invoice vẫn đủ số dư, cả hai request approve đều tạo payment cho cùng proof.
- Harness tái hiện: `acceptedReviews=2`, `paymentsCreated=2`, `paidAmount=200` với proof `amount=100`.
- Hướng sửa: khóa/claim proof atomically cho cả approve và reject, xác định thứ tự lock thống nhất, và cân nhắc ràng buộc unique giữa payment và proof.
- Giới hạn bằng chứng: đã tái hiện bằng service thật với transaction double mô phỏng tuần tự hóa invoice; chưa chạy concurrent test trên PostgreSQL riêng.

### F04. Upload nhạy cảm được phục vụ public; kiểm tra loại file có thể bị giả mạo

Nguồn: `backend/src/app.bootstrap.ts:9`; `backend/src/uploads/uploads.controller.ts:39` và dòng 45.

- POST upload có JWT/role guard thông qua decorator `Roles`; không kết luận endpoint POST mở cho anonymous.
- GET `/uploads/...` lại là static middleware không kiểm tra session/ownership. Ai có URL đều có thể tải chứng từ/attachment; tên UUID khó đoán không thay thế authorization.
- File filter chỉ tin MIME do client khai báo; phần mở rộng giữ nguyên từ tên file.
- HTTP harness tải lên HTML vô hại dưới tên `.html`, MIME `image/png`: POST trả 201; GET không auth trả 200, `text/html; charset=UTF-8`.
- Static middleware đứng trước Helmet; response harness không có CSP hoặc `X-Content-Type-Options`.
- Hướng sửa: phân biệt ảnh public và attachment private; có upload metadata/ownership hoặc signed URLs; xác minh nội dung file và phần mở rộng tương ứng; không phục vụ nội dung chủ động trực tiếp cùng origin; áp security headers trước middleware phục vụ file.
- Giới hạn bằng chứng: harness upload bypass guard để giả lập uploader đã được phép; không dùng dữ liệu người dùng thật, không chứng minh bypass JWT.

### F05. Docker runtime gọi entry point không tồn tại

Nguồn: `backend/Dockerfile:21`; so sánh `backend/package.json:8`.

- Docker chạy `node dist/main.js`, trong khi build sinh `dist/src/main.js`.
- Đã dựng đúng layout các source được `COPY` vào build stage trong thư mục tạm: build exit 0 nhưng `dist/main.js` không tồn tại.
- Hướng sửa: thống nhất artifact layout và entry point giữa script production và Docker; bổ sung container startup smoke test.
- Cần kiểm tra tiếp: quyền ghi và persistence của `uploads` khi chạy `USER node`; runtime image hiện không có bước tạo/chown thư mục upload và compose không mount upload volume. Chưa chạy container thật để xác minh phần quyền này.

### F06. Guard E2E có thể cho phép reset nhầm database không phải test

Nguồn: `backend/test/e2e/e2e-fixtures.ts:8` và dòng 18.

- Guard dùng `/test/i` trên toàn bộ connection URL, không kiểm tra chính xác tên database.
- URL giả có username `test_user`, nhưng database `rental_management`, vẫn qua guard. Đã gọi riêng guard để kiểm chứng; không gọi reset hay database query.
- `resetDatabase()` sau đó xóa dữ liệu nhiều bảng nên nhầm cấu hình có thể gây mất dữ liệu local hoặc môi trường khác.
- Hướng sửa: parse URL và whitelist tên database test; yêu cầu env riêng cho destructive tests và test role chỉ có quyền trên database đó. Không dùng chuỗi username/password/hostname làm bằng chứng database an toàn.

## 5. Chất lượng và khả năng phát triển — P2/P3

### F07. Hai test onboarding không còn khớp UI hiện tại — P2

Nguồn: `/Users/hoang/Rental_room_management/test/features/onboarding/onboarding_persistence_test.dart:222` và dòng 259; `/Users/hoang/Rental_room_management/lib/features/onboarding/onboarding_screen.dart:402`.

Test vẫn tap `Next` tại bước mà UI hiện hiển thị `Get started`, nên không tìm thấy widget. Cần đối chiếu lại cả luồng CTA create-account/login, không chỉ đổi một text finder; chưa có cơ sở kết luận lỗi persistence runtime từ hai test này.

### F08. Backend lint script có nhưng thiếu cấu hình — P2

Nguồn: `backend/package.json:9`.

ESLint 8.57.1 không tìm thấy config khi kiểm tra source/test. Cần cấu hình TypeScript-aware lint và tách command check khỏi auto-fix. Đợt audit không gọi script có `--fix` để tránh thay đổi code.

### F09. Baseline phát triển chưa ổn định và chưa dễ tái lập — P2

- Frontend có 67 file tracked đã sửa và nhiều file mới chưa track từ trước audit; cần lưu trạng thái hiện tại có chủ đích trước refactor, không tự động gom toàn bộ artefact/worktree vào commit.
- `/Users/hoang/Rental_room_management/.gitignore:7` bỏ qua `pubspec.lock`; `git ls-files pubspec.lock` không trả file. Với app này nên cố định dependency resolution trong baseline release/CI.
- Backend sibling không nằm trong một Git repository tại thời điểm kiểm tra (`git ls-files` báo không phải repository). Cần đảm bảo source backend được quản lý version hoặc xác định repository thực sự trước khi thay đổi lớn.
- Không tìm thấy pipeline `.github` trong hai project; có thể CI nằm ngoài workspace, chưa xác minh. Cần một gate build/analyze/test/lint và E2E với database riêng.

### F10. Tài liệu trạng thái đang mâu thuẫn với code — P2

Nguồn: `/Users/hoang/Rental_room_management/PROJECT_STATUS.md:246`; `/Users/hoang/Rental_room_management/IMPLEMENTATION_CHECKLIST.md:112`; đối chiếu `backend/prisma/schema.prisma:168` và `src/audit/`.

Tài liệu ghi chưa có AuditLog/schema/API nhưng source đã có model, migration và audit module; frontend cũng có audit screen/providers. Cần cập nhật status theo mức source/test/runtime verified để tránh lên kế hoạch triển khai lại tính năng đã tồn tại.

### Các hạng mục cần xác minh/hardening, chưa coi là lỗi đã tái hiện

- PDF invoice/lease tải Noto Sans qua `PdfGoogleFonts` và fallback `ThemeData.base()` khi lỗi. Cần test xuất PDF tiếng Việt khi offline/cold cache và cân nhắc font bundled; chưa render/kiểm chứng lỗi ký tự trong audit này.
- Release API mặc định vẫn là `http://localhost:3000/api/v1`; phải có cấu hình endpoint HTTPS theo môi trường trước khi phân phối. Không tự ý đổi URL đang phục vụ phát triển local.
- Bundle identifier hiện `com.example.rentalRoomManagement`; build không ký chưa chứng minh signing/distribution sẵn sàng.
- Phân biệt messaging simulator `zalo-demo` với ZNS thật; chưa gửi thông báo hay verify delivery với dịch vụ bên ngoài.
- Quyết định chính sách revoke session khi đổi mật khẩu/deactivate landlord; cần test staff/tenant phụ thuộc landlord, không mặc định rằng policy chưa được nêu là đã vi phạm.
- Nhiều list API tải toàn bộ kết quả; cần pagination và dữ liệu lớn trước khi đánh giá scalability.
- Các screen lớn như settings/billing form/tenant portal dài khoảng 2.400–2.700 dòng; nên tách phần có trách nhiệm độc lập khi chạm tính năng tương ứng, không refactor hàng loạt ngay trong vòng sửa lỗi.
- 28 file cần format là vấn đề P3; không để formatting toàn dự án trộn lẫn patch sửa lỗi nghiệp vụ.

## 6. Điểm tốt cần giữ

- Đã có phân lớp core/data/models/features và các API/repository seams để test.
- Role decorator thực sự gắn JWT + RolesGuard; staff permissions lấy từ database trong JwtStrategy, không chỉ tin UI.
- Refresh token hash và rotating transaction đã có; giữ single-flight coordinator nhưng sửa repository restore và session boundaries.
- Có unique index partial `Lease_one_active_per_room` trong migration lifecycle; không kết luận sai rằng hai ACTIVE lease có thể tồn tại chỉ vì Prisma schema không biểu diễn index này.
- Billing có khóa row invoice, unique invoice theo lease/month, unique meter reading theo room/type/month và cơ chế reversal; lỗi payment proof cần được sửa đúng chỗ chứ không bỏ các bảo đảm đã có.
- CORS production yêu cầu cấu hình origins, global validation bật whitelist/forbidNonWhitelisted, và test source đã bao phủ các phần auth/roles/ownership quan trọng.
- CRUD/lifecycle, tenant portal, bảo trì, thu chi, audit và automation đã có nhiều hơn mô tả chưa hoàn thành trong một số tài liệu.

## 7. Thứ tự xử lý trước khi code thêm tính năng

1. **Khóa baseline:** xác định version control của cả frontend/backend, giữ các thay đổi hiện có và tách artefact thử nghiệm khỏi source cần đưa vào baseline.
2. **Ổn định phiên và dữ liệu:** sửa F01/F02; thêm regression tests mở app với token hết hạn và đổi tài khoản trên cùng thiết bị.
3. **Bảo vệ thanh toán/file:** sửa F03/F04; thêm concurrent approve/reject test, private-download authorization test và file-content validation test.
4. **Làm gate kiểm tra chạy được:** sửa F06/F07/F08; cố định dependencies; chạy lại unit/widget/analyzer/build và E2E trên database riêng.
5. **Xác minh deployment:** sửa F05; container startup/upload persistence smoke test, release API/signing, backup/restore và secret management.
6. **Đồng bộ tài liệu rồi phát triển:** cập nhật status và API contracts theo code đã xác minh; chọn tính năng tiếp theo theo khoảng trống nghiệp vụ thực, không theo checklist cũ.

Điều kiện để bắt đầu mở rộng an toàn: các lỗi phiên/cache/thanh toán đã có test chống tái phát; suite hiện tại xanh; phạm vi feature và API contract rõ. Điều kiện phát hành production còn đòi hỏi runtime/device/container, upload privacy, vận hành và backup được kiểm chứng.

## 8. Giới hạn của lần kiểm tra

- Không reset database, không chạy backend E2E destructive, không deploy migration mới.
- Không chạy app trên thiết bị thật/simulator hoặc tương tác toàn bộ UI, không tạo signed IPA.
- Không build/run image Docker thật; đã kiểm chứng artifact layout bằng build cô lập tương ứng source COPY.
- Không gửi ZNS, không test upload storage production, không thử backup/restore và không đo performance dưới tải.
- Không thực hiện dependency CVE audit hoặc penetration test toàn diện.
- Backend tests qua không thay thế integration tests Flutter/API; migration status up to date không phải chứng minh schema không có drift thủ công.

Logs local: `/tmp/rental-room-flutter-audit-tests.log`, `/tmp/rental-room-audit-format.log`, `/tmp/rental-room-project-audit/reproduction.log`, `/tmp/rental-room-project-audit/ios-release-build.log`. Các file trong `/tmp` có thể bị hệ thống dọn; báo cáo này lưu lại kết luận và bằng chứng chính.
