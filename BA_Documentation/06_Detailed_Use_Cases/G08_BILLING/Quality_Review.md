# Rà soát G08 — Hóa đơn, thu tiền và công nợ

Ngày 29/10/2026; snapshot `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`. Báo cáo riêng, không phải bảng đặc tả bổ sung của UC.

## Kết quả

Hoàn thành 28/28 UC đúng mã/tên/actor/trạng thái, không thêm/gộp/tách/loại bỏ UC trong lượt này. Mọi UC giữ một association module theo UML; không thêm include/extend/generalization.

Không gộp Payment trực tiếp với Receipt/Allocation. Release khác reversal; thay invoice khác credit/debit note. Hai luồng nhắc APP/outbox và ZNS độc lập. DEMO_CARD không có tiền thật.

## Điểm kiểm soát từng UC

| UC | Điều kiện/kết quả cần kiểm thử | Mức xác minh | Bằng chứng logic chính |
|---|---|---|---|
| UC-BIL-01 | Chỉ số theo phòng/kỳ/tiện ích, không tự lập hóa đơn khi ghi. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:269` |
| UC-BIL-02 | Đóng băng line item tại thời điểm phát hành; không dùng ước tính tin đăng làm hóa đơn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:189` |
| UC-BIL-03 | Preflight không giữ chỗ DB và không bảo đảm batch sau không đổi; phải kiểm lại lúc lập. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:384` |
| UC-BIL-04 | STAFF chỉ các handler được interceptor cho phép; status/events link không tự mở theo quyền billing.view. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:794` |
| UC-BIL-05 | Không dùng đường này để sửa số tiền/line item. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:916` |
| UC-BIL-06 | Có lịch sử payment dù đã đảo về 0 vẫn phải dùng credit/debit note. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:25` |
| UC-BIL-07 | DISCOUNT/TENANT_WAIVER chỉ CREDIT; LATE_FEE/SURCHARGE chỉ DEBIT. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:60` |
| UC-BIL-08.1 | Không xóa hóa đơn vật lý; không đảo thanh toán ngầm để hủy. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1245` |
| UC-BIL-09 | Đây là ghi nhận đã thu, không tích hợp lệnh ngân hàng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:960` |
| UC-BIL-10 | Tạo receipt không tự thanh toán hóa đơn khi chưa phân bổ. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:145` |
| UC-BIL-11 | Các invoice phải thuộc cùng Tenant với receipt; không chuyển tín dụng người này cho người khác. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:101` |
| UC-BIL-12.1 | Giải phóng không phải hoàn tiền ra ngoài; tiền trở lại khả dụng. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:111` |
| UC-BIL-12.2 | Giữ payment gốc; không xóa chứng từ thu. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1185` |
| UC-BIL-13 | Ghi BillingRefund không thực thi ngân hàng và không tự đảo allocation. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-ledger.service.ts:132` |
| UC-BIL-14 | STAFF đọc cần billing.view; quyết định cần billing.approve_payment_proof và scope. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:1038` |
| UC-BIL-15 | Đề xuất chưa có hiệu lực như APPROVED; không sửa hóa đơn đã phát hành. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:19` |
| UC-BIL-16 | STAFF billing.view chỉ xem impact, không reviewTariff dù có tên permission billing.tariff_approve. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:44` |
| UC-BIL-17.1 | STAFF đọc billing.view, sửa billing.create, phải có scope; không suy quyền billing.policy. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:599` |
| UC-BIL-17.2 | Worker là thành phần nội bộ, không tạo Actor mới; STAFF run/preview cần billing.create. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing.service.ts:642` |
| UC-BIL-18.1 | STAFF cả đọc/ghi cần billing.policy và propertyId được giao. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:20` |
| UC-BIL-18.2 | Enqueue thành công không chứng minh EMAIL/ZALO/webhook đã giao thực. | Một phần | `/Users/hoang/Rental_room_management/backend/src/billing/billing-reminders.service.ts:49` |
| UC-BIL-18.3 | Retry không xác nhận giao thành công và không làm mới invoice/payment. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-outbox.service.ts:90` |
| UC-BIL-22 | Chỉ LANDLORD; chưa có bằng chứng mở khóa trong UC này. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/billing-tariffs.service.ts:91` |
| UC-BIL-23 | Thông tin nhận chuyển khoản thủ công không phải kết nối ngân hàng trực tiếp. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/billing/manual-transfer.service.ts:11` |
| UC-TEN-03 | Quyền xem không gồm sửa/hủy hóa đơn. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:157` |
| UC-TEN-04 | Gửi ảnh không đồng nghĩa chủ trọ đã nhận/duyệt tiền. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-portal/tenant-portal.service.ts:426` |
| UC-TEN-05 | Không có gateway thu thẻ tiền thật; cardLast4=4242 là dữ liệu mô phỏng. | Đã triển khai — DEMO | `/Users/hoang/Rental_room_management/backend/src/billing/online-payments.service.ts:41` |
| UC-TEN-08.2 | Lựa chọn kênh chỉ được worker dùng làm điều kiện; không chứng minh provider đã cấu hình/giao thành công. | Xác minh tĩnh | `/Users/hoang/Rental_room_management/backend/src/tenant-lifecycle/tenant-lifecycle.service.ts:240` |

## Giao diện, API và test

Phân biệt thao tác Actor ở mức mục tiêu với nút bấm: các nguồn UI/CLIENT được dẫn riêng trong bảng; trường hợp chưa có client khớp tất cả endpoint được ghi rõ. Không dùng gợi ý file màn hình chung ở Catalog làm bằng chứng mọi biến thể đều có UI. Endpoint, service/helper, lớp DTO kế thừa/lồng và model/guard đều được truy vết trong từng UC.

Test liên quan ghi ngay trong ô truy vết: chỉ file xuất hiện trong `/Users/hoang/Rental_room_management/BA_Documentation/06_Detailed_Use_Cases/Test_Execution_Result.json:1` mới được đánh đã chạy trong lượt này; file E2E/Flutter chỉ là chứng cứ tĩnh nếu không có record thực thi. 71 suite/736 test toàn lượt không chứng minh 28 UC đều được phủ đủ.

## Khoảng chưa xác minh

- UC-BIL-18.2 — Một phần:  APP/outbox có triển khai; EMAIL/ZALO/webhook/ZNS phụ thuộc cấu hình và chưa xác nhận giao thực.
- UC-TEN-05 — Đã triển khai — DEMO: Chỉ bật ngoài production và DEMO_PAYMENTS_ENABLED=true; không có cổng thu thẻ tiền thật được xác nhận. Chỉ isDemo/DEMO_CARD, không có thu tiền ngân hàng thực.
- Chưa xác minh DB/migrations đang chạy, giao diện thực tế nhiều tài khoản và concurrency trên database thật.
- Quyền từ backend không tự chứng minh có màn hình riêng cho từng Actor; dùng đúng ghi chú UI trong bảng.

## Gộp/tách và quyết định

Giữ nguyên Catalog và UML. Không gộp Payment trực tiếp với Receipt/Allocation. Release khác reversal; thay invoice khác credit/debit note. Hai luồng nhắc APP/outbox và ZNS độc lập. DEMO_CARD không có tiền thật. Những thiếu kiểm chứng triển khai không được biến thành UC mới hoặc âm thầm loại UC có bằng chứng. Danh sách cần người dùng xem xét nằm trong báo cáo chất lượng toàn hệ thống.
