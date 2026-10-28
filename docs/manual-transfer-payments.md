# Chuyển khoản ngân hàng, chủ trọ xác nhận thủ công

Ngày cập nhật: 2026-10-29.

## Phạm vi và quyết định

Giữ trải nghiệm thanh toán đơn giản, không yêu cầu tích hợp payOS: người thuê chuyển tiền bằng ứng dụng ngân hàng, gửi chứng từ và chờ chủ trọ kiểm tra thực nhận. Tái sử dụng hóa đơn, chứng từ và sổ thu hiện có thay vì tạo sổ tiền thứ hai.

Đây là thu tiền hóa đơn thuê phòng cho chủ trọ, **không phải thanh toán gói Free/Pro/Premium hoặc doanh thu nền tảng**. App không tự trừ tiền, đọc số dư, xác minh giao dịch ngân hàng hay tự động đối soát qua webhook. Ảnh chứng từ và nút “Tôi đã chuyển tiền” không chứng minh ngân hàng đã chuyển tiền thành công.

Luồng thẻ giả lập cũ chỉ dành cho hóa đơn demo riêng, vẫn chịu `DEMO_PAYMENTS_ENABLED` và bị chặn ở production. Không dùng hóa đơn demo để thu tiền thật.

## Trước khi chạy trên database đang dùng

Migration mới: `backend/prisma/migrations/20261028140000_manual_transfer_account/migration.sql`. Migration chỉ thêm bảng `PropertyPaymentAccount`, không backfill hay thay đổi số tiền hóa đơn. Các phiên kiểm thử đã apply migration trên database tạm; **chưa apply vào database đang dùng**.

Không chạy `prisma migrate dev`, reset hoặc seed để vượt qua lỗi readiness. Dừng tiến trình API cũ trước khi triển khai; dùng cùng source/Prisma Client đã generate và cùng cấu hình môi trường cho toàn bộ release.

Theo quy trình [Database safety](production-safety-2026-10-25.md), tại thư mục `backend/`:

1. Kiểm tra đúng `DATABASE_URL`, có PostgreSQL client tools tương thích và `BACKUP_ENCRYPTION_KEY` hợp lệ; không log hay commit các giá trị này.
2. Chạy `npm run ops:backup`; giữ đường dẫn manifest trả về cùng archive mã hóa và key lưu riêng.
3. Rehearsal restore + migrate trên database tạm, không phải database đang dùng:

   ```bash
   ALLOW_RESTORE_CHECK=true \
   RESTORE_CHECK_DATABASE=rental_restore_check_manual_transfer \
   npm run ops:rehearse -- /secure/backups/manifest.json
   ```

4. Chạy `npm run ops:preflight`, kiểm tra migration thiếu/drift/failed; không tiếp tục nếu rehearsal hoặc kiểm tra an toàn thất bại.
5. Chỉ khi đã chọn đúng database và backup mới trong 24 giờ, chạy guarded migration với tên database thực tế:

   ```bash
   MIGRATION_CONFIRM_DATABASE=TEN_DATABASE_DA_XAC_NHAN \
   npm run ops:migrate -- /secure/backups/manifest.json
   ```

6. Chạy `npm run prisma:generate`, `npm run ops:readiness`, `npm run build`; chỉ khi readiness pass mới khởi động API và kiểm tra `GET /api/v1/health/ready`.

Không chỉ xóa bảng mới để rollback: sau khi có giao dịch thật phải giữ chứng từ, lịch sử và sổ thu. Nếu rollout lỗi, dừng nhận thao tác mới, giữ nguyên dữ liệu và áp dụng kế hoạch phục hồi đã rehearsal; không tự restore đè database.

## Chủ trọ cấu hình nhận tiền

1. Mở danh sách khu trọ → chỉnh sửa khu trọ đã lưu → **Tài khoản nhận tiền**.
2. Nhập ngân hàng, tên người nhận và số tài khoản. Số tài khoản hiện hỗ trợ 4–34 chữ số, giữ nguyên số 0 đầu; chưa hỗ trợ alias có chữ.
3. Có thể tải ảnh QR do ngân hàng cung cấp, hoặc bỏ QR để chuyển theo thông tin tài khoản. QR không được app tự tạo/giải mã/xác minh. Chủ trọ phải kiểm tra ảnh khớp đúng ngân hàng, số tài khoản và chủ tài khoản; nếu QR có số tiền/nội dung cố định phải kiểm tra lại trước mỗi lần dùng.
4. Bật nhận chuyển khoản và lưu. Nếu báo dữ liệu đã thay đổi hoặc lưu chưa rõ kết quả, tải lại trước khi lưu tiếp; không ghi đè bản cấu hình cũ.

Chỉ chủ trọ sở hữu khu trọ được sửa cấu hình; staff/Admin không được dùng API này. Tắt nhận chuyển khoản ẩn tài khoản khỏi hướng dẫn mới, nhưng không hủy chứng từ cũ hoặc xóa khoản thu.

## Người thuê thanh toán

1. Mở hóa đơn thật còn dư nợ → chuyển khoản ngân hàng.
2. Kiểm tra người nhận trong ứng dụng ngân hàng, nhập số tiền và nội dung `HD <invoice UUID>` hiển thị trong app. Đây là nội dung tham chiếu thủ công, không phải mã thanh toán được ngân hàng xác minh. Nếu ứng dụng ngân hàng giới hạn nội dung, ghi chú lại trong chứng từ để chủ trọ đối chiếu.
3. Chuyển tiền ngoài app. Với QR, luôn kiểm tra lại người nhận/số tiền/nội dung trước khi xác nhận trong ngân hàng.
4. Chọn **Tôi đã chuyển tiền — gửi chứng từ**, nhập số đã chuyển và tải ảnh/file chứng từ.
5. Hóa đơn chuyển sang chờ kiểm tra; **dư nợ chưa giảm**. Số tiền đã có chứng từ chờ duyệt được giữ chỗ để hạn chế gửi trùng; không chuyển lần nữa chỉ vì chưa thấy cập nhật.
6. Dùng **Kiểm tra trạng thái xác nhận** để tải lại. Nếu bị từ chối, xem lý do và liên hệ chủ trọ; chỉ gửi lại chứng từ đúng, không mặc định phải chuyển thêm tiền.

Hóa đơn đã hủy/đã trả đủ/demo, khu trọ lưu trữ hoặc chưa bật tài khoản không cung cấp thông tin nhận chuyển khoản khả dụng. Không chuyển theo tài khoản từ ảnh hoặc tin nhắn không được chủ trọ xác nhận.

## Duyệt và ghi nhận thu

Trong **Thu tiền** hoặc **Chi tiết hóa đơn**, mở chứng từ chờ duyệt:

- Xem chứng từ và đối chiếu khoản tiền thực nhận trong ngân hàng hoặc tiền mặt; checkbox xác nhận chỉ là bước nhắc người vận hành, không phải xác thực từ ngân hàng.
- Chỉ bật **Duyệt** sau khi người duyệt xác nhận đã kiểm tra tiền. Backend ghi khoản thu, phân bổ, thanh toán và cập nhật dư nợ trong cùng transaction.
- Thu một phần giữ hóa đơn ở trạng thái thu một phần. Bấm duyệt đồng thời không tạo hai khoản thu; lần sau nhận conflict và phải tải lại.
- **Từ chối** yêu cầu lý do, không ghi thu và giải phóng số tiền đang chờ duyệt.
- Chứng từ cho hóa đơn đã hủy hoặc có số tiền vượt dư nợ tại thời điểm duyệt sẽ bị từ chối ghi nhận.

Đổi tài khoản đăng nhập làm vô hiệu các form đang mở; đóng rồi mở lại từ phiên hiện tại. Không dùng công cụ quản trị hay sửa DB trực tiếp để đánh dấu đã trả.

## API và bảo mật

Tất cả endpoint dùng prefix `/api/v1` và Bearer session hiện có:

| Endpoint | Quyền / ý nghĩa |
| --- | --- |
| `GET /properties/:id/transfer-account` | Chủ trọ sở hữu khu trọ; chưa cấu hình trả `version: 0`, `enabled: false` |
| `PUT /properties/:id/transfer-account` | Chủ trọ sở hữu khu trọ đang hoạt động; `version`, `enabled`, `bankName`, `accountName`, `accountNumber`, `qrImagePath` tùy chọn |
| `GET /tenant/invoices/:id/transfer-instructions` | Người thuê sở hữu hóa đơn; trả `remainingAmount`, `pendingAmount`, `availableAmount`, `canSubmit`, `reference`, `account` |
| `POST /tenant/invoices/:id/payment-proofs` | API gửi chứng từ hiện có, có request key chống gửi lặp; không tự ghi đã thu |
| `POST /billing/payment-proofs/:id/review` | API duyệt/từ chối hiện có, kiểm tra scope và quyền thu tiền |

Đọc cấu hình/hướng dẫn dùng `private, no-store`. Cập nhật tài khoản khóa theo khu trọ, kiểm tra version và ghi audit không chứa toàn bộ số tài khoản. QR chỉ nhận upload ảnh private thuộc chủ trọ, không nhận URL ngoài hay ảnh của người khác. Người thuê chỉ được xin URL ảnh QR khi có hóa đơn thật chưa trả hết tại khu trọ tương ứng và tài khoản đang bật.

URL ảnh ký sẵn có hạn 5 phút theo cơ chế upload hiện có; tắt tài khoản không thu hồi ngay URL đã cấp. Không chia sẻ URL hoặc log token truy cập ảnh.

## Kiểm thử và nghiệm thu

Các lệnh hồi quy:

```bash
# Repository root
flutter test

# backend/
npm test -- --runInBand
npm run build
npm run test:manual-transfers:e2e
```

Runner E2E tự tạo database tên ngẫu nhiên có allowlist, apply migration, kiểm thử chuyển khoản thủ công + thẻ demo rồi xóa database do nó tạo. Không trỏ Jest E2E trực tiếp vào database đang dùng.

Nghiệm thu còn phải thực hiện sau migration: dùng tài khoản chủ trọ/người thuê thật trên thiết bị, cấu hình người nhận thật, kiểm tra quyền staff, gửi/duyệt/từ chối/thu một phần và kiểm tra báo cáo thu. Chưa có tiền được chuyển hoặc ngân hàng được xác minh trong các phiên kiểm thử tự động. Kết quả kiểm thử code không thay thế nghiệm thu staging hoặc giao dịch ngân hàng thực tế.
