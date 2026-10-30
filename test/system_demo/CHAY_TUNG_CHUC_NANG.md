# Copy và chạy riêng từng chức năng

Mở Terminal tại thư mục `/Users/hoang/Rental_room_management`.
Mỗi khối lệnh dưới đây chạy độc lập; không cần chạy khối trước.
Chọn đúng khối muốn xem rồi copy vào Terminal.

Mã thao tác thật nằm trong `system_demo.mjs`, từ comment `// PHẦN 01` trở đi.
Không copy riêng `await ui...` vào Terminal: đó là JavaScript cần Appium,
trình điều khiển, dữ liệu nền và API được runner chuẩn bị trước.
Các lệnh dưới giữ nguyên phần chuẩn bị đó và chỉ chọn nhóm cần kiểm thử.
`login` là điều kiện chung; vì vậy trước mỗi nhóm vẫn kiểm tra đăng nhập bốn vai.
Mỗi lần chạy tạo DB thử mới; không nối tiếp dữ liệu của lần trước.
Đây là từng **nhóm** chức năng, không phải mỗi nút là một test độc lập.

## 01. Test đăng nhập bốn vai trò

Mã thao tác tương ứng trong file chính:

```js
// PHẦN 01: Đăng nhập lần lượt người thuê, chủ trọ, nhân viên và admin.
await scenario('login', 'login', async () => {
  for (const role of ['tenant', 'landlord', 'staff', 'admin']) await ui.login(role);
}, []);
```

Copy lệnh này vào Terminal để chạy riêng:

```sh
# Test đăng nhập
npm --prefix test/system_demo run demo -- --sections=login --delay=2500
```

## 02. Test đăng ký tài khoản tìm trọ

```sh
# Test đăng ký; inventory là tên nhóm đăng ký trong runner hiện tại
npm --prefix test/system_demo run demo -- --sections=login,inventory --delay=2500
```

## 03. Test tạo và sửa khu trọ

```sh
# Test khu trọ
npm --prefix test/system_demo run demo -- --sections=login,property --delay=2500
```

## 04. Test tạo, sửa phòng và các tab chi tiết

```sh
# Test phòng
npm --prefix test/system_demo run demo -- --sections=login,room --delay=2500
```

## 05. Test thêm, tìm kiếm, sửa người thuê và quay lại hồ sơ

```sh
# Test người thuê
npm --prefix test/system_demo run demo -- --sections=login,tenant --delay=2500
```

## 06. Test tạo tin, gửi duyệt và admin duyệt

```sh
# Test tin đăng; cần tạo phòng trống bằng nhóm room trước
npm --prefix test/system_demo run demo -- --sections=login,room,listing --delay=2500
```

## 07. Test yêu thích và toàn bộ lịch xem phòng

Nhóm này gồm lưu yêu thích, đặt/đổi/hủy/đặt lại lịch, chủ trọ xác nhận,
đánh dấu đã xem sớm và tạo hợp đồng từ lịch xem.

```sh
# Test tìm trọ và lịch xem phòng
npm --prefix test/system_demo run demo -- --sections=login,housing --delay=2500
```

## 08. Test bàn giao và xác nhận nhận phòng

```sh
# Test bàn giao hợp đồng
npm --prefix test/system_demo run demo -- --sections=login,contract --delay=2500
```

## 09. Test thu và đối chiếu cọc

```sh
# Test tiền cọc
npm --prefix test/system_demo run demo -- --sections=login,deposit --delay=2500
```

## 10. Test hóa đơn và thanh toán hai vai trò

Gồm gửi/duyệt chứng từ, đối chiếu số dư, tạo/xem/hủy hóa đơn.
Hiện có lỗi runtime khi hủy hóa đơn; kết quả không bị sửa thành đạt.

```sh
# Test hóa đơn và thanh toán
npm --prefix test/system_demo run demo -- --sections=login,billing --delay=2500
```

## 11. Test sửa chữa hai vai trò

Mã tại `// PHẦN 11` dùng UI người thuê gửi yêu cầu, đổi sang chủ trọ nhận xử lý,
phản hồi và hoàn tất, sau đó đổi lại người thuê kiểm tra trạng thái.

```sh
# Test sửa chữa
npm --prefix test/system_demo run demo -- --sections=login,maintenance --delay=2500
```

## 12. Test khoản chi và mở báo cáo

```sh
# Test chi phí và báo cáo
npm --prefix test/system_demo run demo -- --sections=login,expense --delay=2500
```

## 13. Test yêu cầu, duyệt và thực hiện gia hạn

```sh
# Test gia hạn
npm --prefix test/system_demo run demo -- --sections=login,renewal --delay=2500
```

## 14. Test thêm, xóa và xem người ở cùng

```sh
# Test người ở cùng
npm --prefix test/system_demo run demo -- --sections=login,occupants --delay=2500
```

## 15. Test mở thông báo, tài khoản, Zalo nội bộ và hỗ trợ

Chỉ kiểm tra mở màn hình, không xác nhận mọi thao tác bên trong.

```sh
# Screen smoke: thông báo và tài khoản
npm --prefix test/system_demo run demo -- --sections=login,notifications --delay=2500
```

## 15B. Test ticket hỗ trợ và admin phản hồi

```sh
# Test gửi ticket và nhận phản hồi; còn lỗi layout đã ghi trong README
npm --prefix test/system_demo run demo -- --sections=login,support --delay=2500
```

## 15C. Test đổi mật khẩu và đăng nhập lại

```sh
# Test mật khẩu tài khoản thử, không phải tài khoản cá nhân
npm --prefix test/system_demo run demo -- --sections=login,security --delay=2500
```

## 15D. Test thêm phí dịch vụ riêng cho phòng

```sh
# Test phí dịch vụ; cần nhóm room tạo phòng trước
npm --prefix test/system_demo run demo -- --sections=login,room,room-services --delay=2500
```

## 16. Test mở các route đã đăng ký

```sh
# Screen smoke toàn bộ danh sách route phù hợp; không phải mọi nút
npm --prefix test/system_demo run demo -- --sections=login,screens --delay=2500
```

## 17. Test phạm vi nhân viên và mời nhân viên

```sh
# Test nhân viên; chưa kiểm thử kích hoạt lời mời qua email thật
npm --prefix test/system_demo run demo -- --sections=login,staff --delay=2500
```

## 18. Test mở các phân hệ admin

```sh
# Screen smoke admin; không phải toàn bộ thao tác quản trị
npm --prefix test/system_demo run demo -- --sections=login,admin --delay=2500
```

## 19. Test trả phòng, quyết toán và ghi nhận hoàn cọc

```sh
# Thu cọc trước để quan sát luồng hoàn cọc có số tiền
npm --prefix test/system_demo run demo -- --sections=login,deposit,checkout --delay=2500
```

## 20. Test hồi quy tự động, không mở máy ảo

```sh
# Chạy các suite Flutter, backend unit, script safety và API E2E hiện có
npm --prefix test/system_demo run demo -- --sections=regression
```

Mỗi lượt in đường dẫn `report.html` riêng. Lỗi/bị chặn trả exit code 1.
Nhấn Ctrl+C để dừng và dọn tài nguyên. Điều kiện cài đặt, giới hạn coverage và
các lỗi đã phát hiện được ghi trong `README.md` cùng thư mục.
