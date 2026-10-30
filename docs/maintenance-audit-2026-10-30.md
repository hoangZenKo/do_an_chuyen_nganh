# Rà soát luồng sửa chữa - 30/10/2026

## Phạm vi và môi trường

- Rà soát màn danh sách/chi tiết, báo sự cố, phản hồi, đổi trạng thái, hoàn tất, chi phí, file đính kèm và quyền truy cập của tenant/chủ trọ/nhân viên.
- "Admin" quản lý sửa chữa ở đây là chủ trọ. ADMIN nền tảng vẫn bị từ chối ở API nghiệp vụ chủ trọ; không mở rộng quyền này.
- Test iOS chạy trên máy mới `Repairs Audit 20261030 - Codex`, iOS 18.4, UUID `31243B5D-738C-43AB-B157-E2285F616D57`. Không điều khiển máy tenant hay máy chủ trọ đang dùng.
- API và tài khoản QA dùng PostgreSQL riêng, dữ liệu tổng hợp; không dùng tài khoản Hoang Pham hay thay đổi database ứng dụng. Không sửa `.env`, không thêm migration, không commit.

## Những lỗi đã sửa

| Khu vực | Lỗi / rủi ro | Cách sửa |
| --- | --- | --- |
| Tenant - báo sự cố / phản hồi | Controller bị dispose trước khi sheet đóng hết; thao tác với ô đang focus có thể gây assertion màn đỏ. | Đưa form vào widget có lifecycle riêng, dispose theo widget thay vì ngay khi Future của sheet kết thúc. |
| Tenant - file đính kèm | Xóa chip file nhưng URL còn nằm trong ô nhập ẩn/nguồn dữ liệu phụ nên file vẫn được gửi. | Upload chỉ cập nhật danh sách file; xóa chip loại file khỏi payload; loại URL trùng. |
| Tenant - upload | Có thể gửi yêu cầu/phản hồi khi file chưa upload xong, khiến mất file khỏi yêu cầu. | Khóa gửi và chỉnh sửa trong thời gian upload; kiểm tra mounted trước cập nhật giao diện. |
| Tenant - đổi tài khoản | Sheet cũ giữ dữ liệu người thuê trước sau khi chuyển tài khoản. | Vô hiệu hóa và hủy form theo danh tính phiên; chuyển về tài khoản cũ cũng không làm form cũ xuất hiện lại. |
| Tenant / chủ trọ - callback chậm | Kết quả gửi thành công đến muộn có thể đóng nhầm màn mới mở. | Chỉ đóng route còn mounted và đang là route hiện hành. |
| Chủ trọ - hoàn tất / phản hồi | Lifecycle dialog có thể gây lỗi khi đóng lúc đang focus; hoàn tất lỗi API làm mất dữ liệu nhập. | Dialog tự quản lý controller; giữ dữ liệu/lỗi để thử lại, chặn gửi lặp trong lúc lưu. |
| Chủ trọ - menu | Phiếu đã hủy vẫn hiện thao tác Hoàn tất dù backend từ chối. | Ẩn Hoàn tất cho trạng thái đã hủy. |
| Chủ trọ - file | Không hiển thị đầy đủ file trong phiếu và phản hồi của tenant. | Thêm nút mở file qua API cấp URL có kiểm tra quyền; báo lỗi nếu không mở được. |
| Chủ trọ - chọn khu trọ | Tạo mới mặc định khu đầu danh sách thay vì khu đang chọn. | Ưu tiên `selectedPropertyProvider`, chỉ dùng khu đầu khi lựa chọn không còn hợp lệ. |
| Chủ trọ - dữ liệu nhập | Ngày như `2026-02-30` được Dart chuẩn hóa thay vì bị từ chối; số tiền vượt PostgreSQL Int lọt qua form. | Kiểm tra ngày bằng định dạng và round-trip; giới hạn chi phí 0..2147483647 ở form/hoàn tất. |
| Chủ trọ - chỉnh sửa | Xóa mô tả/ghi chú thành rỗng không được gửi nên dữ liệu cũ quay lại. | Gửi chuỗi rỗng nếu người dùng chủ động xóa; vẫn bỏ trường khi không cung cấp. |
| API - validation | Tiêu đề/phản hồi toàn dấu cách được chấp nhận; PATCH chứa null có thể vượt validation rồi gây HTTP 500. | Trim trước validation; từ chối null ở trường không hỗ trợ null. Giữ khả năng xóa assignee/dueAt bằng null. |
| API - thời gian xử lý | Đổi trạng thái qua màn sửa/PATCH không tự ghi `startedAt` hoặc `completedAt`, khác endpoint đổi trạng thái. | Tự ghi mốc còn thiếu khi chuyển sang đang xử lý/hoàn tất; không ghi đè mốc có sẵn hoặc thời gian chỉ định rõ. |
| Bảo mật - tenant | Danh sách, dashboard, thông báo và phản hồi dựa vào mọi hợp đồng của phòng nên có thể lộ phiếu khác kỳ thuê. | Dùng chung phạm vi chủ trọ + hợp đồng ACTIVE + phiếu tạo từ ngày bắt đầu kỳ thuê. Áp dụng cùng quy tắc khi đọc file. |
| Bảo mật - ghi chú | API tenant trả `note` vốn là ghi chú nội bộ chủ trọ. | Loại trường này khỏi dữ liệu phiếu trả về tenant. |
| Bảo mật - nhân viên | Có thể bỏ qua quyền `maintenance.complete` bằng PATCH hoặc endpoint status; tác giả phản hồi nhân viên bị ghi là chủ trọ. | Kiểm tra quyền hoàn tất ở cả hai đường cập nhật; lưu đúng vai trò STAFF. |
| Nhân viên - file | Bộ chặn property từ chối cấp URL file hợp lệ; URL ký cũng thiếu propertyScopes khi kiểm tra lại quyền. | Cho handler cấp URL đi vào kiểm tra quyền file; chỉ cho đọc file sửa chữa thuộc khu được giao và có `maintenance.view`; nạp lại scope khi đọc URL ký. |
| Theo dõi source | `uploads/` trong `.gitignore` backend vô tình bỏ qua cả `src/uploads/`. | Đổi thành `/uploads/` để chỉ bỏ qua thư mục file upload runtime. Source upload hiện xuất hiện là untracked và cần được đưa vào commit khi tích hợp. |

## Hành vi cần biết

- Tenant chỉ xem/trao đổi phiếu trong kỳ thuê ACTIVE hiện tại. Sau khi hợp đồng kết thúc, phiếu vẫn còn ở chủ trọ nhưng không còn xuất hiện ở tenant. Đây là thay đổi giới hạn truy cập có chủ đích để tránh lộ dữ liệu người thuê trước/sau.
- Ghi chú nội bộ không phải phản hồi cho tenant. Muốn tenant nhận nội dung thì dùng Phản hồi.
- Không thay đổi cơ chế tạo chi phí có sẵn: test xác nhận hoàn tất đồng thời không tạo hai chi phí, và không cho đổi tiền thực tế lệch với chi phí đã liên kết.

## Kết quả kiểm chứng

| Kiểm tra | Kết quả cuối |
| --- | --- |
| Flutter: maintenance, tenant maintenance, màu sắc, repository/API liên quan | 55/55 test qua |
| Flutter analyze trên source và test liên quan | Không có issue |
| API E2E: maintenance-audit, authorization-ownership, staff-lifecycle, tenant-portal-priority, lease-billing-dashboard | 22/22 test qua, 5 suite |
| Backend unit: uploads và recurring operations | 8/8 test qua, 3 suite |
| Backend `npm run build` | Qua |
| iOS integration, widget thật + API thật + database QA riêng | 1/1 luồng qua |
| `git diff --check` | Qua |

Luồng iOS đã chạy: tenant mở báo sự cố, thử gửi thiếu tiêu đề, tạo phiếu không ảnh, gửi phản hồi; chủ trọ thấy phiếu, chuyển Đang xử lý, đọc và trả lời; mở Hoàn tất, focus nhập tiền rồi hủy; mở lại hoàn tất với 125000; tenant xem phản hồi chủ trọ và không thấy ghi chú nội bộ. Test kiểm tra không phát sinh exception Flutter tại các mốc này.

Các regression test mới đã được chạy ở trạng thái lỗi trước khi sửa, bao gồm file đã xóa vẫn gửi, đổi tài khoản giữ form, lifecycle hoàn tất, validation ngày/chi phí và thiếu timestamp PATCH.

### Giới hạn / lỗi ngoài phạm vi

- Chưa thao tác chọn ảnh qua trình chọn file iOS thật. Phần upload được kiểm tra bằng widget test giả lập file picker, E2E tenant upload và kiểm tra quyền file/URL ký. Không coi đây là xác nhận toàn bộ đường chọn ảnh native.
- CUA không điều khiển được lúc Mac đang khóa; luồng iOS nêu trên chạy bằng Flutter integration test trên simulator riêng, không phải thao tác chuột thủ công.
- Khi chạy thêm `operations.e2e-spec.ts`, còn 2 test quyền nhân viên nhận 403 thay vì 200. Bộ `PropertyScopeInterceptor` có sẵn không cho OperationsController; bộ staff-lifecycle hiện tại cũng kỳ vọng chặn operations/options. Chưa tự đổi chính sách Operations ngoài phạm vi sửa chữa. Log: `/tmp/repairs-api-suite.log`.
- Bộ staff-lifecycle ban đầu bị chặn vì tên database test không đúng quy ước riêng của suite. Đã tạo database dùng một lần đúng quy ước, migrate và chạy lại: 22/22 qua. Đây là lỗi thiết lập lần chạy đầu, không phải lỗi ứng dụng.
- Chưa xác nhận toàn bộ test của cả repository; kết luận chỉ áp dụng cho phạm vi và bộ test được liệt kê.

## Chạy lại

Tại thư mục dự án:

```sh
flutter test test/features/maintenance \
  test/features/tenant_portal/tenant_maintenance_screen_test.dart \
  test/features/tenant_portal/tenant_maintenance_colors_test.dart \
  test/data/maintenance_repository_test.dart \
  test/data/tenant_portal/tenant_portal_api_test.dart --reporter expanded

flutter analyze lib/features/maintenance \
  lib/features/tenant_portal/tenant_maintenance_screen.dart lib/data/maintenance \
  test/features/maintenance \
  test/features/tenant_portal/tenant_maintenance_screen_test.dart \
  test/features/tenant_portal/tenant_maintenance_colors_test.dart \
  test/data/maintenance_repository_test.dart

npm --prefix backend test -- --runInBand src/uploads src/operations/recurring.service.spec.ts
npm --prefix backend run build
```

E2E sẽ xóa dữ liệu trong database được chỉ định. Chỉ dùng database QA riêng đã migrate, không dùng `.env` ứng dụng. Để chạy cả 5 suite, tên database cần khớp `rental_billing_test_<digits>_<hex>` theo guard của staff-lifecycle. Đặt `NODE_ENV=test`, `DATABASE_URL` của database này và tắt các worker như môi trường QA. Sau đó chạy:

```sh
npm --prefix backend run test:e2e -- --runTestsByPath \
  test/e2e/maintenance-audit.e2e-spec.ts \
  test/e2e/authorization-ownership.e2e-spec.ts \
  test/e2e/staff-lifecycle.e2e-spec.ts \
  test/e2e/tenant-portal-priority.e2e-spec.ts \
  test/e2e/lease-billing-dashboard.e2e-spec.ts
```

Harness iOS dùng một lần nằm ở `/tmp/repairs-audit-qa`, import package từ source dự án, không sao chép màn sửa chữa. API QA tạm đã dừng và file test giữ server tạm đã được xóa khỏi repository, để không ảnh hưởng lần chạy E2E bình thường. Các session QA trong thư mục tạm không phải tài khoản ứng dụng và không được commit. Log iOS: `/tmp/repairs-ios-integration.log`; API: `/tmp/repairs-api-expanded-final.log`; Flutter: `/tmp/repairs-all-flutter.log`.

Để dùng bản sửa trên hai máy đang chạy: khởi động lại backend nếu không bật watch, rồi hot restart cả hai ứng dụng Flutter. Không chỉ hot reload khi kiểm tra lỗi lifecycle/controller.
