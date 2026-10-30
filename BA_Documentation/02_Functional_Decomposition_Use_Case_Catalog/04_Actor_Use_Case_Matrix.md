# Actor–Use Case Matrix

Ngày khảo sát: 29/10/2026 (Asia/Ho_Chi_Minh). Snapshot Git: `c565c29ee5742d38dfaea37aa8fa047f4b6793c0`.

## 1. Chú giải

- P: Actor chính của mục tiêu. P*: chỉ khi đúng quyền, sở hữu, trạng thái/feature flag; không phải toàn quyền trên mọi hành vi của UC.
- V: biến thể chỉ xem/tham gia có điều kiện, không phải Actor chính của toàn mục tiêu. B: controller/decorator có dấu vết STAFF nhưng interceptor chặn AS-IS. —: không gán quyền trong phạm vi mục tiêu này; không khẳng định mọi HTTP request của role đều bị cấm.
- Permission trong một ô là **tập xuất hiện theo handler**, không phải AND/OR toàn ô. STAFF với một handler: ANY trong metadata handler; ADMIN với một handler: ALL metadata, cộng điều kiện service/MFA/step-up.
- A01 khách/chưa đăng nhập; A02 chủ trọ; A03 nhân viên; A04 cùng role TENANT ở ngữ cảnh tìm thuê hoặc ở thuê; A05 ADMIN theo capability. E01…E05 là bên phối hợp ngoài, không có quyền đăng nhập.
- UC chỉ có nguồn UI frontend (so sánh/ước tính) không ngụ ý các role khác được mở menu. Các API công khai không cấm người đang đăng nhập; ô V thể hiện đọc công khai mà không gán họ làm Actor nghiệp vụ tìm thuê.

## G01 — Tài khoản và an toàn truy cập

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-ADM-07.1 | Thiết lập MFA Admin | — | — | — | — | P* — MFA: phiên ADMIN + profile; kiểm role trong controller | Không xác định Actor ngoài |
| UC-SYS-01 | Đăng ký tài khoản chủ trọ | P — đủ dữ liệu/token theo UC | — | — | — | — | Không xác định Actor ngoài |
| UC-SYS-02 | Đăng ký tài khoản tìm phòng | P — đủ dữ liệu/token theo UC | — | — | — | — | Không xác định Actor ngoài |
| UC-SYS-03 | Đăng nhập | P — chủ tài khoản chưa đăng nhập | — | — | — | — | Không xác định Actor ngoài |
| UC-SYS-05.1 | Đăng xuất phiên hiện tại | — | P — tài khoản/phiên của mình | P — phiên/tài khoản của mình | P — tài khoản/phiên của mình | P — tài khoản/phiên của mình | Không xác định Actor ngoài |
| UC-SYS-05.2 | Xem và thu hồi các phiên của mình | — | P — tài khoản/phiên của mình | P — phiên/tài khoản của mình | P — tài khoản/phiên của mình | P — tài khoản/phiên của mình | Không xác định Actor ngoài |
| UC-SYS-06 | Khôi phục mật khẩu bằng liên kết một lần | P — chủ tài khoản chưa đăng nhập | — | — | — | — | E01 |
| UC-SYS-07 | Đổi mật khẩu khi đang đăng nhập | — | P — tài khoản/phiên của mình | P — phiên/tài khoản của mình | P — tài khoản/phiên của mình | P — tài khoản/phiên của mình | Không xác định Actor ngoài |
| UC-SYS-08 | Kích hoạt tài khoản người thuê từ lời mời | P — đủ dữ liệu/token theo UC | — | — | — | — | Không xác định Actor ngoài |
| UC-SYS-09 | Kích hoạt tài khoản nhân viên từ lời mời | P — đủ dữ liệu/token theo UC | — | — | — | — | Không xác định Actor ngoài |
| UC-SYS-10 | Thiết lập mật khẩu tài khoản được mời | P — đủ dữ liệu/token theo UC | — | — | — | — | Không xác định Actor ngoài |

## G02 — Tìm và lựa chọn phòng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-DIS-01 | Tìm và lọc tin phòng công khai | P — công khai | V — truy cập công khai, không suy quyền menu | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — truy cập công khai, không suy quyền menu | Không xác định Actor ngoài |
| UC-DIS-02 | Xem chi tiết tin và đánh giá công khai | P — công khai | V — truy cập công khai, không suy quyền menu | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — truy cập công khai, không suy quyền menu | Không xác định Actor ngoài |
| UC-DIS-03 | Lưu và bỏ lưu phòng yêu thích | — | — | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | — | Không xác định Actor ngoài |
| UC-DIS-04 | Lưu bộ lọc và theo dõi tin khớp | — | — | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | — | Không xác định Actor ngoài |
| UC-DIS-16 | So sánh các phòng quan tâm | P — công khai | V — truy cập công khai, không suy quyền menu | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — truy cập công khai, không suy quyền menu | Không xác định Actor ngoài |
| UC-DIS-17 | Ước tính chi phí thuê phòng | P — công khai | V — truy cập công khai, không suy quyền menu | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — truy cập công khai, không suy quyền menu | Không xác định Actor ngoài |

## G03 — Đăng tin, lịch xem và nhận phòng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-DIS-05 | Quản lý và gửi duyệt tin cho thuê | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-DIS-06.2 | Ẩn tin cho thuê của mình | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-DIS-08 | Quản lý khung giờ xem phòng | — | P* — dữ liệu thuộc mình; điều kiện service | — | V — chỉ xem dữ liệu liên quan | — | Không xác định Actor ngoài |
| UC-DIS-09 | Đặt và quản lý lịch xem của mình | — | V — xem/phản hồi tại UC-DIS-10 | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | — | Không xác định Actor ngoài |
| UC-DIS-10 | Tiếp nhận và hoàn tất lịch xem | — | P* — dữ liệu thuộc mình; điều kiện service | — | V — đổi/hủy của mình tại UC-DIS-09 | — | Không xác định Actor ngoài |
| UC-TNT-12.2 | Lập biên bản bàn giao nhận phòng | — | P* — dữ liệu thuộc mình; điều kiện service | — | V — chỉ xem dữ liệu liên quan | — | Không xác định Actor ngoài |
| UC-TNT-12.3 | Xác nhận biên bản bàn giao nhận phòng | — | — | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | — | Không xác định Actor ngoài |

## G04 — Khu trọ và cơ sở vật chất

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-OPT-02 | Tra cứu khu trọ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — property.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-03.1 | Tạo khu trọ | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPT-03.2 | Cập nhật thông tin khu trọ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — property.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-04.1 | Lưu trữ hoặc khôi phục khu trọ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — property.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-04.3 | Xóa khu trọ đủ điều kiện | — | P* — dữ liệu thuộc mình; điều kiện service | P* — property.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-05 | Tra cứu phòng và lịch sử liên quan | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-06.1 | Tạo phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-06.2 | Cập nhật thông tin phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-07.1 | Đổi trạng thái sử dụng phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-07.2 | Vô hiệu hóa hoặc khôi phục phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-07.3 | Xóa phòng đủ điều kiện | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-08.1 | Quản lý tài sản phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.view, room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-08.2 | Theo dõi lịch kiểm tra phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — room.view, room.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPT-09 | Quản lý phiên bản phí dịch vụ phòng | — | P* — dữ liệu thuộc mình; điều kiện service | V — chỉ đọc: room.view + scope | — | — | Không xác định Actor ngoài |

## G05 — Nhân sự và ủy quyền vận hành

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-STF-01 | Mời nhân viên và cấp phạm vi khu trọ | — | P* — dữ liệu thuộc mình; điều kiện service | V — chỉ đọc: staff.view + scope | — | — | Không xác định Actor ngoài |
| UC-STF-02 | Cập nhật quyền trạng thái và phạm vi nhân viên | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-STF-03 | Mô phỏng quyền nhân viên | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-STF-04 | Tra cứu nhân viên và phạm vi được cấp | — | P* — dữ liệu thuộc mình; điều kiện service | P* — staff.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |

## G06 — Hồ sơ thuê, hợp đồng và tiền cọc

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-TEN-01 | Xem hồ sơ và tổng quan thuê của mình | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-02 | Tra cứu hợp đồng và quyết toán của mình | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-08.1 | Xem người ở cùng hợp đồng | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TNT-01 | Tra cứu hồ sơ người thuê và tổng quan | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-02.1 | Tạo hồ sơ người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-02.2 | Cập nhật hồ sơ người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-02.3 | Vô hiệu hóa hoặc khôi phục người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-02.4 | Xóa hồ sơ người thuê đủ điều kiện | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-03 | Tạo lời mời truy cập cổng người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-TNT-03.1 | Tạo trực tiếp tài khoản cho hồ sơ người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — tenant.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-04 | Tra cứu và xuất hợp đồng thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-05 | Lập hợp đồng thuê phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.manage; theo hành vi + scope; không tạo từ lịch xem | — | — | Không xác định Actor ngoài |
| UC-TNT-06.1 | Cập nhật điều khoản hợp đồng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-06.2 | Gia hạn hợp đồng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-06.3 | Kết thúc hợp đồng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-07 | Tra cứu và ghi giao dịch cọc | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.view, lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-12.1 | Quản lý người ở cùng hợp đồng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.view, lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |

## G07 — Vòng đời thuê và quyết toán

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-TEN-07.1 | Đề nghị gia hạn thuê | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-07.2 | Đề nghị chuyển phòng | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-07.3 | Đề nghị trả phòng | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TNT-08 | Xem trước và xác nhận quyết toán trả phòng | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-TNT-09 | Ghi nhận đã hoàn cọc theo quyết toán | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-TNT-10 | Xét duyệt yêu cầu vòng đời thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.view, lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TNT-11 | Thực thi yêu cầu vòng đời đã duyệt | — | P* — dữ liệu thuộc mình; điều kiện service | P* — lease.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |

## G08 — Hóa đơn, thu tiền và công nợ

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-BIL-01 | Ghi chỉ số điện nước theo kỳ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-02 | Xem trước và lập hóa đơn một hợp đồng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-03 | Lập hóa đơn hàng loạt | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-04 | Tra cứu hóa đơn và công nợ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-05 | Sửa hạn thanh toán hoặc ghi chú hóa đơn | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-06 | Thay thế hóa đơn chưa có lịch sử thanh toán | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.adjust; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-07 | Điều chỉnh tăng hoặc giảm hóa đơn | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.adjust; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-08.1 | Hủy hóa đơn đủ điều kiện | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.cancel; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-09 | Ghi nhận thanh toán trực tiếp | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.record_payment; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-10 | Tạo khoản thu cho người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.record_payment; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-11 | Phân bổ khoản thu cho hóa đơn | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.record_payment; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-12.1 | Giải phóng phân bổ khoản thu | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.reverse_payment; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-12.2 | Đảo thanh toán trực tiếp | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.reverse_payment; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-13 | Ghi nhận hoàn tiền từ khoản thu | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.refund; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-14 | Xét duyệt chứng từ thanh toán | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.approve_payment_proof; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-15 | Đề xuất biểu phí theo kỳ hiệu lực | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-16 | Phân tích tác động và duyệt biểu phí | — | P* — dữ liệu thuộc mình; điều kiện service | V — chỉ đọc: billing.view + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-17.1 | Cấu hình lập hóa đơn định kỳ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.view, billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-17.2 | Xem trước và chạy đợt lập hóa đơn | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.create; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-BIL-18.1 | Cấu hình chính sách nhắc nợ | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.policy; theo hành vi + scope; propertyId bắt buộc | — | — | Không xác định Actor ngoài |
| UC-BIL-18.2 | Gửi nhắc nợ theo chính sách | — | P* — dữ liệu thuộc mình; điều kiện service | P* — billing.policy; theo hành vi + scope; propertyId bắt buộc | — | — | E01, E02 |
| UC-BIL-18.3 | Theo dõi và thử lại outbox hóa đơn | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-BIL-22 | Khóa kỳ thanh toán của khu | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-BIL-23 | Cấu hình tài khoản nhận chuyển khoản | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-TEN-03 | Tra cứu hóa đơn của mình | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-04 | Gửi chứng từ chuyển khoản hóa đơn | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-05 | Thanh toán bằng thẻ mô phỏng | V — chỉ checkout có token demo hợp lệ | V — chỉ tra trạng thái/sự kiện demo ở UC-BIL-04 | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-08.2 | Chọn kênh nhận nhắc nợ | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |

## G09 — Bảo trì và chi phí vận hành

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-BIL-19 | Quản lý khoản chi vận hành | — | P* — dữ liệu thuộc mình; điều kiện service | P* — expense.view, expense.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPS-01 | Tiếp nhận và theo dõi phiếu bảo trì | — | P* — dữ liệu thuộc mình; điều kiện service | P* — maintenance.view, maintenance.manage; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPS-02 | Phân công và cập nhật bảo trì | — | P* — dữ liệu thuộc mình; điều kiện service | P* — maintenance.manage; theo hành vi + scope; không escalate | — | — | Không xác định Actor ngoài |
| UC-OPS-03 | Hoàn tất bảo trì và liên kết khoản chi | — | P* — dữ liệu thuộc mình; điều kiện service | P* — maintenance.complete; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-TEN-06 | Gửi và trao đổi yêu cầu bảo trì | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |

## G10 — Công việc, thông tin và hỗ trợ sử dụng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-OPS-04 | Theo dõi việc cần xử lý | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPS-05 | Chuẩn bị phòng sau trả phòng | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPS-06 | Thiết lập lịch công việc định kỳ | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPS-06.1 | Thực hiện checklist công việc định kỳ | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPS-07 | Soạn và phát thông báo người thuê | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-SUP-04 | Theo dõi thông báo cá nhân | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | P* — admin.notifications.view; theo handler | Không xác định Actor ngoài |
| UC-SUP-06 | Hỏi trợ lý AI và đọc nguồn hướng dẫn | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | E04 |
| UC-TEN-09.2 | Trao đổi tin nhắn Zalo mô phỏng | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |
| UC-TEN-09.3 | Đọc và xác nhận thông báo chủ trọ | — | — | — | P* — Tenant/lease/invoice của mình | — | Không xác định Actor ngoài |

## G11 — Báo cáo và giám sát vận hành

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-ADM-01 | Xem tổng quan nền tảng | — | — | — | — | P* — admin.dashboard.view; theo handler | Không xác định Actor ngoài |
| UC-ADM-14 | Tra cứu và xuất nhật ký quản trị | — | — | — | — | P* — admin.audit.view, admin.audit.export; theo handler | Không xác định Actor ngoài |
| UC-ADM-16 | Quản lý lịch và tải báo cáo Admin | — | — | — | — | P* — admin.reports.manage; theo handler | E05 |
| UC-BIL-20 | Phân tích và xuất báo cáo vận hành | — | P* — dữ liệu thuộc mình; điều kiện service | P* — report.view, report.export; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-OPS-09 | Tra cứu nhật ký vận hành | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | — | — | Không xác định Actor ngoài |
| UC-OPT-01 | Xem dashboard và bản đồ phòng | — | P* — dữ liệu thuộc mình; điều kiện service | P* — report.view; theo hành vi + scope | — | — | Không xác định Actor ngoài |
| UC-SUP-05.1 | Giám sát và xử lý sự cố vận hành | — | — | — | — | P* — admin.operations.view, admin.operations.manage; theo handler | Không xác định Actor ngoài |
| UC-SUP-05.2 | Theo dõi hàng đợi giao nhận | — | — | — | — | P* — admin.operations.view, admin.operations.manage; theo handler | E01 |

## G12 — Tài khoản và tài nguyên nền tảng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-ADM-02 | Tra cứu tài khoản nền tảng | — | — | — | — | P* — admin.accounts.view, admin.accounts.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-03.1 | Tạo hoặc mời tài khoản chủ trọ | — | — | — | — | P* — admin.accounts.manage, admin.dashboard.view; theo handler | E01 |
| UC-ADM-03.2 | Cập nhật hồ sơ chủ trọ | — | — | — | — | P* — admin.accounts.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-04.1 | Đình chỉ hoặc khôi phục tài khoản | — | — | — | — | P* — admin.accounts.suspend; theo handler | Không xác định Actor ngoài |
| UC-ADM-04.3 | Thu hồi phiên của tài khoản khác | — | — | — | — | P* — admin.sessions.revoke, admin.admins.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-05.1 | Mở thông tin cá nhân được che | — | — | — | — | P* — admin.pii.reveal; theo handler | Không xác định Actor ngoài |
| UC-ADM-05.2 | Yêu cầu khôi phục truy cập cho tài khoản | — | — | — | — | P* — admin.accounts.manage; theo handler | E01 |
| UC-ADM-06.1 | Cấp và quản lý quyền quản trị viên | — | — | — | — | P* — admin.admins.manage, admin.dashboard.view; theo handler | E01 |
| UC-ADM-06.2 | Rà soát quyền Admin định kỳ | — | — | — | — | P* — admin.admins.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-08 | Tra cứu khu và phòng toàn nền tảng | — | — | — | — | P* — admin.properties.view; theo handler | Không xác định Actor ngoài |
| UC-ADM-09 | Tạo hoặc cập nhật khu thay chủ trọ | — | — | — | — | P* — admin.properties.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-10 | Tìm kiếm và định vị tài nguyên | — | — | — | — | P* — admin.dashboard.view; theo handler | Không xác định Actor ngoài |

## G13 — Kiểm duyệt và chất lượng nội dung

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-ADM-11 | Tiếp nhận và kiểm duyệt tin cho thuê | — | — | — | — | P* — admin.dashboard.view, admin.listings.moderate, admin.moderation.bulk; theo handler | Không xác định Actor ngoài |
| UC-ADM-11.1 | Xác minh thông tin tin cho thuê | — | — | — | — | P* — admin.listings.moderate; theo handler | Không xác định Actor ngoài |
| UC-ADM-12 | Kiểm duyệt đánh giá và phản hồi phòng | — | — | — | — | P* — admin.reviews.moderate; theo handler | Không xác định Actor ngoài |
| UC-ADM-12.1 | Xử lý báo cáo vi phạm tin đăng | — | — | — | — | P* — admin.listings.moderate; theo handler | Không xác định Actor ngoài |
| UC-ADM-13.1 | Quản lý chính sách kiểm duyệt | — | — | — | — | P* — admin.moderation.reports, admin.admins.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-13.2 | Xử lý kháng nghị kiểm duyệt | — | — | — | — | P* — admin.moderation.reports, admin.dashboard.view, admin.moderation.appeals; theo handler | Không xác định Actor ngoài |
| UC-ADM-13.3 | Đánh giá chất lượng kiểm duyệt | — | — | — | — | P* — admin.moderation.reports; theo handler | Không xác định Actor ngoài |
| UC-DIS-07 | Báo cáo tin phòng không phù hợp | — | — | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | — | Không xác định Actor ngoài |
| UC-DIS-12 | Viết sửa và rút đánh giá phòng đã thuê | — | — | — | P* — lease đủ điều kiện đánh giá | — | Không xác định Actor ngoài |
| UC-DIS-13.1 | Trả lời đánh giá phòng | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | — | Không xác định Actor ngoài |
| UC-DIS-15 | Xem quyết định và gửi kháng nghị kiểm duyệt | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — dashboard.view + ownerId của quyết định | Không xác định Actor ngoài |

## G14 — Dịch vụ hỗ trợ khách hàng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-SUP-01 | Gửi và theo dõi yêu cầu hỗ trợ | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | P* — ticket do mình yêu cầu | P* — admin.dashboard.view, admin.support.read, admin.support.manage; theo handler | E03 |
| UC-SUP-01.1 | Tiếp nhận và xử lý hồ sơ hỗ trợ | — | — | B — interceptor chặn | — | P* — admin.support.read, admin.support.manage; theo handler | E03 |
| UC-SUP-02.1 | Cấu hình phân công tự động hỗ trợ | — | — | — | — | P* — admin.support.read, admin.support.manage, admin.admins.manage; theo handler | Không xác định Actor ngoài |
| UC-SUP-02.2 | Cấu hình và theo dõi SLA hỗ trợ | — | — | — | — | P* — admin.support.read, admin.support.manage, admin.admins.manage; theo handler | Không xác định Actor ngoài |
| UC-SUP-03.2 | Quản lý mẫu trả lời hỗ trợ | — | — | — | — | P* — admin.support.read, admin.support.manage; theo handler | Không xác định Actor ngoài |
| UC-SUP-03.2.1 | Hợp nhất hồ sơ hỗ trợ trùng | — | — | — | — | P* — admin.support.read, admin.support.manage; theo handler | Không xác định Actor ngoài |
| UC-SUP-03.2.2 | Đánh giá kết quả hỗ trợ | — | P* — dữ liệu thuộc mình; điều kiện service | B — interceptor chặn | P* — ticket do mình yêu cầu | P* — admin.dashboard.view; theo handler | Không xác định Actor ngoài |
| UC-SUP-03.3 | Lưu bộ lọc xử lý hỗ trợ | — | — | — | — | P* — admin.support.read, admin.support.manage; theo handler | Không xác định Actor ngoài |

## G15 — Hồ sơ xác minh và gói dịch vụ

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-ADM-18 | Xét duyệt hồ sơ xác minh chủ trọ | — | — | — | — | P* — admin.verifications.view, admin.support.read, admin.verifications.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-18.1 | Nộp hồ sơ xác minh chủ trọ | — | P* — dữ liệu thuộc mình; điều kiện service | — | — | P* — admin.verifications.manage, admin.support.read; theo handler | Không xác định Actor ngoài |
| UC-ADM-19 | Trình và xét duyệt hồ sơ khu trọ | — | — | — | — | P* — admin.properties.view, admin.properties.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-20 | Quản lý danh mục gói dịch vụ | — | — | — | — | P* — admin.plans.view, admin.plans.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-21 | Gán gói và xem lịch sử đăng ký | — | — | — | — | P* — admin.plans.view, admin.plans.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-22 | Hủy quyền sử dụng gói đang hiệu lực | — | — | — | — | P* — admin.plans.manage; theo handler | Không xác định Actor ngoài |

## G16 — Quản trị chính sách và đối soát nền tảng

| Mã UC | Tên UC | A01 | A02 | A03 | A04 | A05 | Tác nhân phối hợp |
| --- | --- | --- | --- | --- | --- | --- | --- |
| UC-DIS-13.2 | Gửi phản hồi về thử nghiệm tìm phòng | — | P* — dữ liệu thuộc mình; điều kiện service | — | P* — TENANT; đúng chủ sở hữu/điều kiện dữ liệu | V — chỉ đọc cấu hình pilot; không gửi phản hồi | Không xác định Actor ngoài |
| UC-ADM-15 | Chuẩn bị đối soát sao kê | — | — | — | — | P* — admin.finance.read, admin.finance.reconcile; theo handler | Không xác định Actor ngoài |
| UC-ADM-15.1 | Duyệt đề xuất đối soát sao kê | — | — | — | — | P* — admin.finance.read, admin.finance.reconcile; theo handler | Không xác định Actor ngoài |
| UC-ADM-17.1 | Cấu hình bật tắt tính năng nền tảng | — | — | — | — | P* — admin.flags.manage, admin.dashboard.view; theo handler | Không xác định Actor ngoài |
| UC-ADM-17.2 | Quản lý nhóm Admin | — | — | — | — | P* — admin.teams.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-23 | Quản lý danh mục cơ sở trường | — | — | — | — | P* — admin.campuses.manage; theo handler | Không xác định Actor ngoài |
| UC-ADM-24 | Tra cứu giao dịch tài chính nền tảng | — | — | — | — | P* — admin.finance.read; theo handler | Không xác định Actor ngoài |
| UC-ADM-26 | Mô phỏng quyền Admin | — | — | — | — | P* — admin.permissions.simulate; theo handler | Không xác định Actor ngoài |
| UC-ADM-27 | Đọc phản hồi thử nghiệm tìm phòng | — | — | — | — | P* — admin.listings.moderate; theo handler | Không xác định Actor ngoài |

## 2. Những điều kiện service không được bỏ qua

| UC | Điều kiện bổ sung |
| --- | --- |
| UC-DIS-01 | Tin công khai cần PUBLISHED, phòng active và VACANT, khu không archived, chủ trọ active; lọc trường học là nhánh tìm kiếm. |
| UC-DIS-16 | Trạng thái so sánh trong Riverpod, tối đa 3 tin; không có bằng chứng lưu lâu dài ở backend. |
| UC-DIS-17 | Ước tính frontend từ tin: thuê, điện, nước, dịch vụ, gửi xe; chia người và tiền cọc vào ở. Không phải hóa đơn hay cam kết thu. |
| UC-DIS-08 | Slot 15–120 phút, giới hạn số lịch sắp tới; TENANT chỉ đọc slot. |
| UC-DIS-09 | Đặt trước ít nhất 15 phút, không quá 90 ngày; kiểm tra trùng lịch của hai bên; reschedule là TENANT. |
| UC-DIS-10 | LANDLORD xử lý lịch của tin mình; hoàn tất là điều kiện cho chuyển lịch thành hợp đồng. |
| UC-OPT-07.1 | Không được mô tả chuyển trạng thái phòng tùy ý: lease ACTIVE, isActive và turnover ràng buộc trạng thái. |
| UC-OPT-09 | Đọc service fees/tariff versions: STAFF room.view + scope. Tạo/sửa/xóa phí: chỉ LANDLORD. |
| UC-TEN-08.1 | Người thuê chỉ xem người ở cùng; không tự thêm/xóa occupant. |
| UC-TNT-03.1 | STAFF tenant.manage có thể tạo tài khoản trực tiếp vì TenantsController được whitelist; khác UC mời qua TenantInvitesController bị chặn. |
| UC-TNT-05 | Tạo lease ACTIVE và chuyển phòng OCCUPIED trong transaction; một lease ACTIVE/phòng. Create DTO không nhận endDate; chỉnh hạn ở luồng sau. Biến thể từ lịch xem chỉ LANDLORD: lịch phải COMPLETED, chuyển LEASED và ẩn tin. STAFF chỉ luồng tạo trực tiếp, không dùng HousingController. |
| UC-TNT-06.2 | ACTIVE, endDate mới lớn hơn endDate hiện tại và chưa quyết toán; không tự thanh toán cọc/nợ. |
| UC-TNT-06.3 | Kết thúc lease đặt ENDED, phòng MAINTENANCE và mở turnover; không tự quyết toán hay đưa phòng VACANT. |
| UC-TNT-07 | Thu/hoàn/khấu trừ cọc theo ledger; không vượt số dư; đã quyết toán thì chặn đường biến động cọc cũ. |
| UC-TNT-08 | Chốt tiền thuê theo ngày gồm ngày checkout nếu kỳ chưa được lập; cọc chỉ bù khoản quyết toán. Nợ hóa đơn cũ được trình bày riêng, không tự tất toán; fingerprint/idempotency. |
| UC-TNT-09 | Chỉ ghi nhận hoàn cọc đã thực hiện, không chuyển tiền qua ngân hàng. |
| UC-TNT-10 | APPROVED không đồng nghĩa đã thực thi; chưa thay lease chỉ bằng quyết định. |
| UC-TNT-11 | Thực thi một lần theo requestKey; chuyển/trả phòng cần lease kết thúc và quyết toán theo nhánh; chuyển phòng tạo lease mới và kiểm tra sức chứa. |
| UC-BIL-01 | Chỉ số mới không nhỏ hơn chỉ số cũ, đơn giá dương; số liệu theo phòng/kỳ/loại tiện ích. |
| UC-BIL-02 | Đóng băng line item/giá ở thời điểm lập; chống trùng theo leaseId, billingMonth, isDemo, revision sau các migration. |
| UC-BIL-03 | Preflight và kết quả từng hợp đồng là bước của lập hàng loạt, không tách thành UC kiểm tra trùng. |
| UC-BIL-09 | Khoản trả dương, không vượt dư; chặn demo/hóa đơn hủy. Không đồng nghĩa thu tiền trực tiếp từ ngân hàng. |
| UC-BIL-13 | Chỉ hoàn từ tiền khả dụng chưa phân bổ; ghi ReceiptRefund, không lệnh chuyển tiền. |
| UC-BIL-14 | Chấp thuận tạo receipt/payment/allocation; từ chối không tăng paidAmount. Cần billing.view để đọc và billing.approve_payment_proof để quyết. |
| UC-BIL-16 | STAFF billing.view chỉ xem tác động; reviewTariff chỉ LANDLORD dù danh sách permission có billing.tariff_approve. |
| UC-BIL-17.1 | STAFF: đọc billing.view; sửa billing.create, kèm propertyIds. Không dùng billing.policy để suy quyền. |
| UC-BIL-17.2 | STAFF preview/run cần billing.create; chạy đợt do người dùng và worker dùng chung nghiệp vụ, worker không là Actor ngoài hệ thống. |
| UC-BIL-18.1 | STAFF cần billing.policy và propertyId trong phạm vi được giao cho cả đọc/cập nhật. |
| UC-BIL-18.2 | STAFF chỉ đường BillingController với billing.policy + propertyId được giao; đường NotificationsController/ZNS bị chặn STAFF. APP, webhook nhắc nợ và ZNS không được đồng nhất. |
| UC-BIL-18.3 | Chỉ LANDLORD dùng outboxEvents/retryOutbox vì interceptor chặn STAFF dù decorator có quyền. |
| UC-BIL-22 | Chỉ LANDLORD khóa kỳ; không suy ra quyền STAFF từ permission enum. |
| UC-OPS-02 | STAFF không gọi escalate; thao tác thủ công chỉ LANDLORD. Worker SLA là thành phần nội bộ. |
| UC-OPS-03 | Hoàn thành có thể tạo Expense REPAIR một lần; không đếm lại khoản chi thành UC mới. |
| UC-TEN-06 | TENANT cần hợp đồng ACTIVE để tạo yêu cầu đúng phòng; không cấp quyền maintenance.manage của chủ trọ. |
| UC-OPS-05 | RETURNED → INSPECTION → REPAIR → CLEANING → READY; sửa chữa chưa xong chặn đi tiếp; chỉ đưa VACANT khi pipeline hoàn tất. |
| UC-SUP-04 | Gộp mục tiêu đọc thông báo, không đồng nhất Notification, HousingNotification và PlatformNotification. Theo đúng handler; STAFF bị chặn tất cả các nguồn thông báo này. |
| UC-SUP-06 | Chỉ hướng dẫn có nguồn theo GLOBAL/LANDLORD/PROPERTY; tối đa 3 đoạn; không có dữ liệu thì fallback; không trả lời trực tiếp số dư sống hay tự thao tác nghiệp vụ. |
| UC-ADM-16 | Lịch/run thuộc chủ sở hữu, tái kiểm quyền lúc chạy; kết quả TTL 7 ngày, feature flag; object storage tùy cấu hình. |
| UC-SUP-05.1 | Quản trị nhận/giao/hoãn/xử lý sự cố; release summary có productionAccepted:false, không là xác nhận đạt production. |
| UC-ADM-02 | Console accounts cần accounts.view; endpoint /admin/landlords cũ cần accounts.manage. Không gộp thành quyền đọc mặc định cho cả hai. |
| UC-ADM-03.1 | Invite ADMIN/LANDLORD dùng cùng endpoint: mục tiêu này chỉ role=LANDLORD, cần dashboard.view + kiểm accounts.manage tại service; nhánh dev trực tiếp riêng. |
| UC-ADM-04.3 | Thu hồi khách hàng: sessions.revoke; thu hồi Admin khác: admins.manage và sessions.revoke cùng điều kiện service, không gán cùng quyền cho mọi loại tài khoản. |
| UC-ADM-06.1 | Invite role=ADMIN cần dashboard.view, admins.manage, MFA và không vượt quyền người mời; preset mời chỉ support/moderator/analyst. Cập nhật tùy biến theo quyền super_admin; không tự đổi mình, giữ super_admin hoạt động cuối. |
| UC-ADM-13.2 | Reviewer không là người ra quyết định gốc; cần quyền kháng nghị và quyền nội dung tương ứng theo service. |
| UC-ADM-13.3 | Đánh giá độc lập với người ra quyết định; không tự áp chế tài. |
| UC-DIS-12 | Cần bàn giao đã chấp nhận hoặc nhánh lịch sử thuê đã kết thúc đủ điều kiện; sửa đưa lại chờ duyệt; rút không cho admin đăng lại tùy ý. |
| UC-DIS-15 | Chỉ quyết định bất lợi thuộc ownerId của mình, trong 14 ngày và chưa bị thay thế/kháng nghị trùng. ADMIN chỉ có đường đọc/gửi cho tài nguyên chính mình nếu có, không mặc định quyền của chủ trọ. |
| UC-SUP-01 | Ticket của requester; nội dung internal không công khai; trả lời mở lại RESOLVED trong 7 ngày, CLOSED không trả lời. Có feature flag support.user_tickets. |
| UC-SUP-01.1 | Controller cho nhiều role nhưng service.manage đòi ADMIN support.read/manage; không phải mọi chủ trọ/TENANT đều ghi chú, giao việc hay đổi trạng thái. Tệp tối đa 8MB, tối đa 20/ticket; chỉ CLEAN/hash hợp lệ; scanner chưa có thì fail-closed. |
| UC-SUP-02.1 | skills/autoAssign cần đồng thời support.read, support.manage, admins.manage theo metadata; không tạo Actor Agent độc lập với ADMIN. |
| UC-SUP-03.2.2 | Requester đúng ticket; một lần sau RESOLVED/CLOSED, không ticket đã merged. |
| UC-ADM-19 | Trình/xét khu ở đây do ADMIN có properties.manage; chưa có bằng chứng chủ trọ tự trình. Hồ sơ xét khu khác verified của tin. |
| UC-ADM-20 | Quản lý phiên bản điều khoản/hạn mức; đọc plans.view, ghi plans.manage. |
| UC-ADM-21 | Chỉ gán gói và lịch sử, không có UC thanh toán mua gói. Quota chỉ áp nếu đã có subscription; hết hạn chặn tăng inventory, không xóa dữ liệu. |
| UC-ADM-22 | Chấm dứt quyền dùng gói không tự hoàn tiền, không xóa khu/phòng. |
| UC-ADM-15 | Nhập sao kê và đề xuất ghép chứng từ đã có; không suy ra kết nối tài khoản ngân hàng trực tiếp. |
| UC-ADM-15.1 | Checker phải khác maker dù cùng role/capability; chỉ ghi kết quả đối soát, không chuyển tiền. |

Mọi dòng UC nối tới handler/nguồn ở tài liệu 07 và data/traceability.json. Không dùng ma trận này làm bảng cấp quyền production khi chưa đọc điều kiện theo handler.
