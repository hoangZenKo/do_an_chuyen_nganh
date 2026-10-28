# Báo cáo rà soát logic đặc tả Use Case

Phiên bản đặc tả sau rà soát: **1.2**. Báo cáo dành cho người kiểm tra nghiệp vụ và nhóm phát triển, tách nội dung đã sửa trong tài liệu khỏi thiếu sót mã nguồn và chính sách chưa được xác nhận.

## 1 Kết luận và phạm vi

- Ví dụ được phản ánh là đúng: **UC-OPT-05.02 E5 phải quay lại bước 3**, không phải bước 5. Sau khi chọn phòng khác, đi qua bước 4, kiểm tra lại giá thuê và xác nhận tại bước 5. Không cam kết giá thuê tự đổi khi trường giá thuê đã có giá trị.
- Hiệu chỉnh **22 điểm trong 20 UC**, tương ứng **28 ô thuộc tính**, đồng bộ Markdown và Word có sơ đồ. Giữ nguyên **67 UC, 24 UC tổng quan, 13 thuộc tính mỗi bảng, 11 sơ đồ nhóm**.
- Bổ sung **Phụ lục C** trong Word và Markdown để đọc nhanh nhật ký. Báo cáo này ghi đầy đủ trước–sau và căn cứ kiểm tra; không đưa thuật ngữ kỹ thuật trở lại bảng UC chính.
- Tách riêng một thiếu sót kiểm tra khi cập nhật khoản chi và hai kiểm thử onboarding đang thất bại. **Chưa sửa mã nguồn ứng dụng** trong lần rà soát này.
- Giữ các quyết định chưa chốt tại Phụ lục A: giá thuê 0, điều kiện phòng Bảo trì, tiền cọc, chuyển trạng thái bảo trì, vận hành lịch tự động và các điểm khác. Làm rõ PX-13, PX-19; thêm PX-32. Tài liệu hiện có 32 điểm cần xác nhận, không phải 32 lỗi đã được khắc phục.

### Tài liệu sử dụng

- Đặc tả Markdown: `/Users/hoang/Rental_room_management/docs/ba/USE_CASE_SPECIFICATION.md`.
- Word hiện hành có sơ đồ: `/Users/hoang/Rental_room_management/docs/ba/USE_CASE_SPECIFICATION_WITH_DIAGRAMS.docx`.
- Bản `/Users/hoang/Rental_room_management/docs/ba/USE_CASE_SPECIFICATION.docx` là bản nền trước khi bổ sung sơ đồ, không phải bản 1.2 được giao để rà soát.
- Mã nguồn ứng dụng: `/Users/hoang/Rental_room_management` và phần xử lý nghiệp vụ tại `backend`. Thư mục API không có thông tin Git để ghi nhận commit; không suy diễn phiên bản từ commit ứng dụng.
- Commit HEAD ứng dụng khi kiểm tra: `2d1ec6444ff8a84fb1de4487f4cc7514354076cc`. Checkout đã có nhiều thay đổi chưa commit; rà soát trên nội dung hiện có, không chỉ commit HEAD và không hoàn tác thay đổi sẵn có.

### Cách kiểm tra và giới hạn

Đọc 67 bảng đặc tả, đối chiếu luồng và trạng thái với phần xử lý liên quan; kiểm tra vị trí rẽ nhánh, bước tiếp nối, điều kiện trước và sau, dữ liệu đầu vào và quy tắc nghiệp vụ. Kiểm tra thêm biểu mẫu khi cần xác định lựa chọn, xác nhận và dữ liệu thực sự được gửi. Tham chiếu trong ma trận ở mục 5 là phần xử lý nghiệp vụ chính, không phải danh sách toàn bộ tệp đã đọc.

Kiểm tra tự động xác nhận tính đồng bộ tài liệu, số bảng, mã UC, thuộc tính, liên kết, sơ đồ và phạm vi bước. Các kiểm tra hồi quy ngữ nghĩa tập trung vào những nhánh đã sửa. Chúng **không chứng minh tất cả quy tắc nghiệp vụ đều đúng** và không thay thế kiểm thử end-to-end.

Không chạy nghiệm thu với cơ sở dữ liệu thực, dịch vụ Zalo thực hoặc môi trường triển khai. Không xác nhận giao dịch đồng thời, lịch chạy thật, múi giờ vận hành, gửi tin thật hoặc mọi tình huống mất kết nối. Nội dung ở đây không phải kết luận dự án không còn lỗi.

## 2 Nhật ký sửa chi tiết

Mỗi mã HC tương ứng một điểm hiệu chỉnh, không nhất thiết là một UC riêng. Một UC có thể có hai lỗi độc lập. Mục Trước và Sau dưới đây ghi lại các thuộc tính bị thay đổi; khi có hai lần sửa cùng một ô, Trước là nội dung ngay trước lần sửa tương ứng.

### HC-01 UC-OPT-05.02 E5 quay sai bước chọn phòng

**Lý do:** Phòng được chọn tại bước 3; bước 5 chỉ kiểm tra điều khoản và xác nhận. Chọn lại phòng phải đi qua bước 3, bước 4 và xác nhận lại.

**Thuộc tính:** Luồng ngoại lệ.

**Trước:**

E1 — Tại bước 2: Chưa chọn khu trọ. Thông báo cần chọn khu trọ; chưa hiển thị biểu mẫu lập hợp đồng. Chủ trọ chọn khu trọ rồi khởi tạo lại UC.

E2 — Tại bước 2: Không có phòng trong danh sách được phép chọn. Thông báo không có phòng để lập hợp đồng; UC kết thúc.

E3 — Tại bước 5: Chưa chọn phòng hoặc giá thuê không đạt điều kiện của biểu mẫu. Yêu cầu điều chỉnh; chưa thực hiện tạo hợp đồng và quay lại bước 5. Chênh lệch giá thuê xem PX-01.

E4 — Tại bước 6: Phòng, Người thuê không tồn tại, ngoài phạm vi, đã ngừng sử dụng hoặc khu trọ đã lưu trữ. Từ chối tạo; UC kết thúc không có hợp đồng mới từ yêu cầu bị từ chối.

E5 — Tại bước 6: Phòng đã có hợp đồng hiệu lực. Từ chối tạo thêm; Chủ trọ chọn phòng khác và thực hiện lại từ bước 5.

E6 — Tại bước 7–8: Không hoàn tất hoặc không nhận được kết quả. Hiển thị lỗi nếu có; kiểm tra lịch sử hợp đồng trước khi tạo lại vì chưa xác định được kết quả ghi nhận.

**Sau:**

E1 — Tại bước 2: Chưa chọn khu trọ. Thông báo cần chọn khu trọ; chưa hiển thị biểu mẫu lập hợp đồng. Chủ trọ chọn khu trọ rồi khởi tạo lại UC.

E2 — Tại bước 2: Không có phòng trong danh sách được phép chọn. Thông báo không có phòng để lập hợp đồng; UC kết thúc.

E3 — Tại bước 5: Chưa chọn phòng hoặc giá thuê không đạt điều kiện của biểu mẫu. Yêu cầu điều chỉnh; chưa thực hiện tạo hợp đồng và quay lại bước 5. Chênh lệch giá thuê xem PX-01.

E4 — Tại bước 6: Phòng, Người thuê không tồn tại, ngoài phạm vi, đã ngừng sử dụng hoặc khu trọ đã lưu trữ. Từ chối tạo; UC kết thúc không có hợp đồng mới từ yêu cầu bị từ chối.

E5 — Tại bước 6: Phòng đã có hợp đồng hiệu lực. Từ chối tạo thêm; Chủ trọ quay lại bước 3 để chọn phòng khác, tiếp tục bước 4 và kiểm tra lại giá thuê trước khi xác nhận tại bước 5. Giá thuê chỉ được điền theo giá phòng khi trường này chưa có giá trị.

E6 — Tại bước 7–8: Không hoàn tất hoặc không nhận được kết quả. Hiển thị lỗi nếu có; kiểm tra lịch sử hợp đồng trước khi tạo lại vì chưa xác định được kết quả ghi nhận.

**Căn cứ đối chiếu:**

- `backend/src/leases/leases.service.ts:85`.
- `/Users/hoang/Rental_room_management/lib/features/tenants/lease_form_screen.dart:59`.

### HC-02 UC-OPT-05.02 E3 gộp hai lỗi có vị trí khắc phục khác nhau

**Lý do:** Thiếu phòng cần chọn phòng tại bước 3; lỗi giá thuê cần sửa điều khoản tại bước 5. Không suy ra chính sách giá thuê 0 từ kiểm tra riêng của biểu mẫu.

**Thuộc tính:** Luồng ngoại lệ.

**Trước:**

E1 — Tại bước 2: Chưa chọn khu trọ. Thông báo cần chọn khu trọ; chưa hiển thị biểu mẫu lập hợp đồng. Chủ trọ chọn khu trọ rồi khởi tạo lại UC.

E2 — Tại bước 2: Không có phòng trong danh sách được phép chọn. Thông báo không có phòng để lập hợp đồng; UC kết thúc.

E3 — Tại bước 5: Chưa chọn phòng hoặc giá thuê không đạt điều kiện của biểu mẫu. Yêu cầu điều chỉnh; chưa thực hiện tạo hợp đồng và quay lại bước 5. Chênh lệch giá thuê xem PX-01.

E4 — Tại bước 6: Phòng, Người thuê không tồn tại, ngoài phạm vi, đã ngừng sử dụng hoặc khu trọ đã lưu trữ. Từ chối tạo; UC kết thúc không có hợp đồng mới từ yêu cầu bị từ chối.

E5 — Tại bước 6: Phòng đã có hợp đồng hiệu lực. Từ chối tạo thêm; Chủ trọ quay lại bước 3 để chọn phòng khác, tiếp tục bước 4 và kiểm tra lại giá thuê trước khi xác nhận tại bước 5. Giá thuê chỉ được điền theo giá phòng khi trường này chưa có giá trị.

E6 — Tại bước 7–8: Không hoàn tất hoặc không nhận được kết quả. Hiển thị lỗi nếu có; kiểm tra lịch sử hợp đồng trước khi tạo lại vì chưa xác định được kết quả ghi nhận.

**Sau:**

E1 — Tại bước 2: Chưa chọn khu trọ. Thông báo cần chọn khu trọ; chưa hiển thị biểu mẫu lập hợp đồng. Chủ trọ chọn khu trọ rồi khởi tạo lại UC.

E2 — Tại bước 2: Không có phòng trong danh sách được phép chọn. Thông báo không có phòng để lập hợp đồng; UC kết thúc.

E3 — Tại bước 5: Chưa chọn phòng hoặc giá thuê không đạt điều kiện của biểu mẫu. Chưa thực hiện tạo hợp đồng. Nếu chưa chọn phòng, quay lại bước 3 rồi tiếp tục bước 4 và bước 5. Nếu giá thuê không đạt điều kiện của biểu mẫu, điều chỉnh giá thuê tại bước 5 rồi xác nhận lại. Chênh lệch giá thuê xem PX-01.

E4 — Tại bước 6: Phòng, Người thuê không tồn tại, ngoài phạm vi, đã ngừng sử dụng hoặc khu trọ đã lưu trữ. Từ chối tạo; UC kết thúc không có hợp đồng mới từ yêu cầu bị từ chối.

E5 — Tại bước 6: Phòng đã có hợp đồng hiệu lực. Từ chối tạo thêm; Chủ trọ quay lại bước 3 để chọn phòng khác, tiếp tục bước 4 và kiểm tra lại giá thuê trước khi xác nhận tại bước 5. Giá thuê chỉ được điền theo giá phòng khi trường này chưa có giá trị.

E6 — Tại bước 7–8: Không hoàn tất hoặc không nhận được kết quả. Hiển thị lỗi nếu có; kiểm tra lịch sử hợp đồng trước khi tạo lại vì chưa xác định được kết quả ghi nhận.

**Căn cứ đối chiếu:**

- `backend/src/leases/leases.service.ts:85`.
- `/Users/hoang/Rental_room_management/lib/features/tenants/lease_form_screen.dart:59`.

### HC-03 UC-ADM-02.04 Xác nhận và nhánh mở khóa chưa thống nhất

**Lý do:** Phải chọn khóa hoặc mở khóa trước khi hiển thị yêu cầu xác nhận; xác nhận không chỉ dành cho thao tác khóa.

**Thuộc tính:** Luồng chính.

**Trước:**

1. Admin hệ thống: Chọn tài khoản Chủ trọ cần khóa hoặc mở khóa.

2. Hệ thống: Hiển thị trạng thái hiện tại và yêu cầu xác nhận thay đổi.

3. Admin hệ thống: Xác nhận khóa tài khoản.

4. Hệ thống: Kiểm tra tài khoản đích và cập nhật trạng thái khóa hoặc mở khóa theo lựa chọn đã xác nhận.

5. Hệ thống: Hiển thị trạng thái mới của tài khoản.

**Sau:**

1. Admin hệ thống: Chọn tài khoản Chủ trọ cần khóa hoặc mở khóa.

2. Hệ thống: Hiển thị trạng thái hiện tại và yêu cầu xác nhận thay đổi.

3. Admin hệ thống: Xác nhận thao tác khóa hoặc mở khóa đã chọn.

4. Hệ thống: Kiểm tra tài khoản đích và cập nhật trạng thái khóa hoặc mở khóa theo lựa chọn đã xác nhận.

5. Hệ thống: Hiển thị trạng thái mới của tài khoản.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Tài khoản đang bị khóa và Admin hệ thống chọn mở khóa. Gửi trạng thái hoạt động; xử lý tại bước 4.

**Sau:**

A1 — Tại bước 1: Tài khoản đang bị khóa và Admin hệ thống chọn mở khóa. Tại bước 2, hệ thống yêu cầu xác nhận mở khóa; tại bước 3, Admin hệ thống xác nhận. Tiếp tục bước 4 để kiểm tra tài khoản và cập nhật về đang hoạt động, sau đó hiển thị kết quả tại bước 5.

**Căn cứ đối chiếu:**

- `backend/src/admin/admin.service.ts:224`.
- `/Users/hoang/Rental_room_management/lib/features/admin/admin_landlord_detail_screen.dart:65`.

### HC-04 UC-OPT-02.04 Nhánh khôi phục xuất hiện sau xác nhận thao tác ngược lại

**Lý do:** Lựa chọn khôi phục phải diễn ra tại bước 1 trước hộp thoại xác nhận ở bước 2; sau xác nhận mới kiểm tra quyền và lưu thay đổi.

**Thuộc tính:** Kích hoạt.

**Trước:**

Chọn lưu trữ khu trọ đang sử dụng.

**Sau:**

Chọn lưu trữ khu trọ đang sử dụng hoặc khôi phục khu trọ đã lưu trữ.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chủ trọ chọn khôi phục khu trọ đã lưu trữ. Tiếp tục bước 4 để kiểm tra quyền quản lý, không áp dụng điều kiện không còn hợp đồng của nhánh lưu trữ; tại bước 5 đặt khu trọ về đang sử dụng, không tự khôi phục từng phòng.

**Sau:**

A1 — Tại bước 1: Chủ trọ chọn khôi phục khu trọ đã lưu trữ thay cho lưu trữ. Tại bước 2, hệ thống yêu cầu xác nhận khôi phục; tại bước 3, Chủ trọ xác nhận. Tiếp tục bước 4 để kiểm tra quyền quản lý, không áp dụng điều kiện không còn hợp đồng của nhánh lưu trữ; tại bước 5 đặt khu trọ về đang sử dụng, không tự khôi phục từng phòng; hiển thị kết quả tại bước 6.

**Căn cứ đối chiếu:**

- `backend/src/properties/properties.service.ts:84`.
- `/Users/hoang/Rental_room_management/lib/features/properties/properties_list_screen.dart:112`.

### HC-05 UC-OPT-03.05 Nhánh khôi phục xuất hiện sau xác nhận thao tác ngược lại

**Lý do:** Lựa chọn khôi phục phải diễn ra tại bước 1 trước hộp thoại xác nhận ở bước 2; sau xác nhận mới kiểm tra quyền và lưu thay đổi.

**Thuộc tính:** Kích hoạt.

**Trước:**

Chọn ngừng sử dụng phòng.

**Sau:**

Chọn ngừng sử dụng phòng đang sử dụng hoặc khôi phục phòng đã ngừng sử dụng.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chủ trọ chọn khôi phục phòng ngừng sử dụng. Tiếp tục bước 4 để kiểm tra quyền quản lý; tại bước 5 đặt phòng về đang sử dụng. Điều kiện khi khu trọ đã lưu trữ xem PX-10.

**Sau:**

A1 — Tại bước 1: Chủ trọ chọn khôi phục phòng đã ngừng sử dụng. Tại bước 2, hệ thống yêu cầu xác nhận khôi phục; tại bước 3, Chủ trọ xác nhận. Tiếp tục bước 4 để kiểm tra quyền quản lý, không áp dụng điều kiện không còn hợp đồng của nhánh ngừng sử dụng; tại bước 5 đặt phòng về đang sử dụng và hiển thị kết quả tại bước 6. Điều kiện khi khu trọ đã lưu trữ xem PX-10.

**Căn cứ đối chiếu:**

- `backend/src/rooms/rooms.service.ts:159`.
- `/Users/hoang/Rental_room_management/lib/features/rooms/room_detail_screen.dart:59`.

### HC-06 UC-OPT-04.04 Nhánh khôi phục xuất hiện sau xác nhận thao tác ngược lại

**Lý do:** Lựa chọn khôi phục phải diễn ra tại bước 1 trước hộp thoại xác nhận ở bước 2; sau xác nhận mới kiểm tra quyền và lưu thay đổi.

**Thuộc tính:** Kích hoạt.

**Trước:**

Chọn ngừng sử dụng hồ sơ Người thuê.

**Sau:**

Chọn ngừng sử dụng hồ sơ Người thuê hoặc khôi phục hồ sơ đã ngừng sử dụng.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chủ trọ chọn khôi phục hồ sơ. Tiếp tục bước 4 để kiểm tra quyền quản lý; tại bước 5 đặt hồ sơ về đang sử dụng, không tự thay đổi tài khoản đăng nhập.

**Sau:**

A1 — Tại bước 1: Chủ trọ chọn khôi phục hồ sơ đã ngừng sử dụng. Tại bước 2, hệ thống yêu cầu xác nhận khôi phục hồ sơ; tại bước 3, Chủ trọ xác nhận. Tiếp tục bước 4 để kiểm tra quyền quản lý, không áp dụng điều kiện không còn hợp đồng của nhánh ngừng sử dụng; tại bước 5 đặt hồ sơ về đang sử dụng, không tự thay đổi tài khoản đăng nhập; hiển thị kết quả tại bước 6.

**Căn cứ đối chiếu:**

- `backend/src/tenants/tenants.service.ts:277`.
- `/Users/hoang/Rental_room_management/lib/features/tenants/tenant_detail_screen.dart:51`.

### HC-07 UC-OPT-02.01 Số phòng bị mô tả nhầm là chỉ phòng đang sử dụng

**Lý do:** Tổng số phòng được tính từ toàn bộ phòng của khu trọ, không lọc riêng tình trạng đang sử dụng.

**Thuộc tính:** Luồng chính.

**Trước:**

1. Chủ trọ: Mở danh sách khu trọ và chọn bộ lọc đang sử dụng, đã lưu trữ hoặc tất cả.

2. Hệ thống: Lấy các khu trọ thuộc Chủ trọ theo bộ lọc cùng số phòng đang sử dụng.

3. Hệ thống: Hiển thị danh sách khu trọ và thông tin tóm tắt của từng khu.

4. Chủ trọ: Chọn khu trọ làm phạm vi vận hành cho các chức năng tiếp theo.

**Sau:**

1. Chủ trọ: Mở danh sách khu trọ và chọn bộ lọc đang sử dụng, đã lưu trữ hoặc tất cả.

2. Hệ thống: Lấy các khu trọ thuộc Chủ trọ theo bộ lọc cùng tổng số phòng của từng khu trọ, bao gồm cả phòng đã ngừng sử dụng.

3. Hệ thống: Hiển thị danh sách khu trọ và thông tin tóm tắt của từng khu.

4. Chủ trọ: Chọn khu trọ làm phạm vi vận hành cho các chức năng tiếp theo.

**Căn cứ đối chiếu:**

- `backend/src/properties/properties.service.ts:40`.
- `backend/src/properties/properties.service.ts:132`.

### HC-08 UC-OPT-03.07 Nhánh xóa tài sản chưa chỉ rõ bước kiểm tra và kết quả

**Lý do:** Nhánh xóa thay cho thêm phải kiểm tra phòng và tài sản, không chạy kiểm tra dữ liệu của tài sản mới rồi kết thúc không rõ bước.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chọn xóa tài sản hiện có. Kiểm tra tài sản thuộc phòng rồi xóa; tải lại danh sách.

**Sau:**

A1 — Tại bước 3: Chủ trọ chọn xóa tài sản hiện có thay cho thêm tài sản. Tại bước 4, hệ thống kiểm tra quyền quản lý phòng và xác nhận tài sản thuộc phòng rồi xóa tài sản đã chọn. Tại bước 5, hiển thị danh sách sau khi xóa; không tạo tài sản mới.

**Căn cứ đối chiếu:**

- `backend/src/rooms/rooms.service.ts:246`.

### HC-09 UC-OPT-03.08 Nhánh bật tắt hoặc xóa phí thiếu trình tự kiểm tra

**Lý do:** Mọi thay đổi đều phải kiểm tra phòng và phí đích trước khi lưu; kết quả quay về danh sách thay vì đi tiếp nhánh tạo phí mới.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Bật/tắt phí hiện có. Cập nhật tình trạng áp dụng của phí thuộc phòng; tải lại danh sách.

A2 — Tại bước 3: Xóa phí hiện có. Kiểm tra phí thuộc phòng rồi xóa.

**Sau:**

A1 — Tại bước 3: Chủ trọ chọn bật hoặc tắt phí hiện có. Tại bước 4, hệ thống kiểm tra quyền quản lý phòng và phí thuộc phòng rồi cập nhật tình trạng áp dụng. Tại bước 5, hiển thị danh sách sau cập nhật; không tạo phí mới.

A2 — Tại bước 3: Chủ trọ chọn xóa phí hiện có. Tại bước 4, hệ thống kiểm tra quyền quản lý phòng và phí thuộc phòng rồi xóa phí đã chọn. Tại bước 5, hiển thị danh sách sau khi xóa; không tạo phí mới.

**Căn cứ đối chiếu:**

- `backend/src/rooms/rooms.service.ts:350`.
- `backend/src/rooms/rooms.service.ts:370`.

### HC-10 UC-OPT-03.09 Nhánh hoàn tất lịch kiểm tra thiếu điểm tiếp nối

**Lý do:** Hoàn tất mục hiện có phải kiểm tra mục đích và ghi thời điểm hoàn tất, không tiếp tục tạo một mục kiểm tra mới.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Đánh dấu mục hiện có đã hoàn tất. Kiểm tra mục thuộc phòng; lưu thời điểm hoàn tất hiện tại và tải lại danh sách.

**Sau:**

A1 — Tại bước 3: Chủ trọ chọn đánh dấu mục kiểm tra hiện có đã hoàn tất. Tại bước 4, hệ thống kiểm tra quyền quản lý phòng và mục kiểm tra thuộc phòng rồi ghi thời điểm hoàn tất hiện tại. Tại bước 5, hiển thị lịch kiểm tra sau cập nhật; không tạo mục mới.

**Căn cứ đối chiếu:**

- `backend/src/rooms/rooms.service.ts:300`.

### HC-11 UC-OPT-06.03 Gộp chỉnh sửa thông tin với chuyển trạng thái nhanh và cam kết sai ngày xử lý

**Lý do:** Biểu mẫu sửa gửi ngày báo, không gửi ngày bắt đầu hoặc hoàn tất. Chỉ thao tác chuyển trạng thái riêng tự ghi các mốc tương ứng khi chưa có; không thể cam kết mọi lần sửa đều tự ghi ngày xử lý.

**Thuộc tính:** Dữ liệu đầu vào.

**Trước:**

Nội dung, phòng/khu trọ, ưu tiên, trạng thái, các ngày, chi phí và ghi chú theo thao tác.

**Sau:**

Nội dung, phòng/khu trọ, ưu tiên, trạng thái, ngày báo, chi phí dự kiến, chi phí thực tế và ghi chú theo biểu mẫu sửa. Nhánh thao tác nhanh sử dụng yêu cầu đã chọn và trạng thái cần chuyển; cách ghi ngày bắt đầu, hoàn tất xem PX-13.

**Thuộc tính:** Luồng chính.

**Trước:**

1. Chủ trọ: Chọn sửa nội dung hoặc cập nhật tiến độ của yêu cầu bảo trì.

2. Hệ thống: Hiển thị nội dung, mức ưu tiên, trạng thái, ngày xử lý và chi phí hiện tại.

3. Chủ trọ: Thay đổi nội dung hoặc trạng thái, bổ sung ngày và chi phí theo thao tác; xác nhận lưu.

4. Hệ thống: Kiểm tra quyền quản lý yêu cầu, khu trọ, phòng và tính hợp lệ của dữ liệu.

5. Hệ thống: Lưu thay đổi; ghi ngày bắt đầu hoặc hoàn tất khi chuyển trạng thái tương ứng và ngày đó chưa được ghi nhận.

6. Hệ thống: Hiển thị nội dung và tiến độ mới của yêu cầu.

**Sau:**

1. Chủ trọ: Chọn chỉnh sửa yêu cầu bảo trì.

2. Hệ thống: Hiển thị phòng/khu trọ, tiêu đề, mô tả, mức ưu tiên, trạng thái, ngày báo, chi phí dự kiến, chi phí thực tế và ghi chú hiện tại.

3. Chủ trọ: Thay đổi các thông tin cần sửa trên biểu mẫu và xác nhận lưu.

4. Hệ thống: Kiểm tra quyền quản lý yêu cầu, khu trọ, phòng và tính hợp lệ của dữ liệu.

5. Hệ thống: Lưu các thông tin được thay đổi. Không tự ghi ngày bắt đầu hoặc hoàn tất chỉ vì đổi trạng thái trong biểu mẫu sửa; khác biệt với thao tác nhanh xem PX-13.

6. Hệ thống: Hiển thị nội dung và tiến độ mới của yêu cầu.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chủ trọ bắt đầu xử lý hoặc hủy yêu cầu trên danh sách. Gửi trạng thái tương ứng và thực hiện bước 4.

**Sau:**

A1 — Tại bước 1: Chủ trọ chọn bắt đầu xử lý hoặc hủy yêu cầu ngay trên danh sách thay cho mở biểu mẫu sửa. Hệ thống tiếp nhận lựa chọn và tiếp tục bước 4 để kiểm tra yêu cầu thuộc phạm vi quản lý. Tại bước 5, hệ thống chuyển sang Đang xử lý hoặc Đã hủy; khi bắt đầu xử lý và chưa có ngày bắt đầu thì ghi thời điểm hiện tại. Nhánh hủy không tự ghi ngày hoàn tất. Hiển thị kết quả tại bước 6.

**Căn cứ đối chiếu:**

- `backend/src/maintenance/maintenance.service.ts:128`.
- `backend/src/maintenance/maintenance.service.ts:177`.
- `/Users/hoang/Rental_room_management/lib/features/maintenance/maintenance_form_screen.dart:277`.
- `/Users/hoang/Rental_room_management/lib/features/maintenance/maintenance_screen.dart:662`.

### HC-12 UC-OPT-06.04 Nhánh không ghi khoản chi hoàn tất trước kiểm tra

**Lý do:** Lựa chọn không ghi khoản chi là đầu vào tại bước 3, không phải thời điểm thay đổi trạng thái yêu cầu.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Không chọn ghi khoản chi. Chỉ cập nhật yêu cầu Hoàn tất; tiếp tục bước 4.

**Sau:**

A1 — Tại bước 3: Chủ trọ không chọn ghi khoản chi. Tiếp tục bước 4 để kiểm tra yêu cầu, chi phí và thời điểm hoàn tất. Nếu hợp lệ, tại bước 5 hệ thống đánh dấu yêu cầu Hoàn tất mà không tạo khoản chi mới; hiển thị kết quả tại bước 6.

**Căn cứ đối chiếu:**

- `backend/src/maintenance/maintenance.service.ts:201`.

### HC-13 UC-BIL-02.02 Hóa đơn đã tồn tại bị coi là kết thúc hoặc từ chối cả yêu cầu hàng loạt

**Lý do:** Một hóa đơn đã có cùng kỳ là kết quả đã tồn tại của từng hợp đồng; xử lý tiếp các hợp đồng còn lại trong cùng yêu cầu.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 5: Một hợp đồng đã có hóa đơn cùng kỳ. Trả hóa đơn hiện có với nhãn đã tồn tại, không tạo lại. UC kết thúc đối với yêu cầu bị từ chối.

A2 — Tại bước 5: Chỉ số loại dịch vụ đã có trong kỳ. Bỏ qua chỉ số gửi bổ sung cho loại đó; dùng giá trị đã lưu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

**Sau:**

A1 — Tại bước 5: Một hợp đồng đã có hóa đơn cùng kỳ. Trả hóa đơn hiện có với nhãn đã tồn tại, không tạo lại. Tiếp tục xử lý các hợp đồng còn lại tại bước 5, sau đó đưa hóa đơn hiện có vào kết quả tổng hợp tại bước 6.

A2 — Tại bước 5: Chỉ số loại dịch vụ đã có trong kỳ. Bỏ qua chỉ số gửi bổ sung cho loại đó; dùng giá trị đã lưu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

**Căn cứ đối chiếu:**

- `backend/src/billing/billing.service.ts:451`.

### HC-14 UC-BIL-02.02 Chỉ số có sẵn bị yêu cầu nhập lại dù được tái sử dụng

**Lý do:** Xử lý hàng loạt bỏ qua chỉ số bổ sung cho loại đã có và dùng giá trị đã lưu; không quay lại nhập bước 3.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 5: Một hợp đồng đã có hóa đơn cùng kỳ. Trả hóa đơn hiện có với nhãn đã tồn tại, không tạo lại. Tiếp tục xử lý các hợp đồng còn lại tại bước 5, sau đó đưa hóa đơn hiện có vào kết quả tổng hợp tại bước 6.

A2 — Tại bước 5: Chỉ số loại dịch vụ đã có trong kỳ. Bỏ qua chỉ số gửi bổ sung cho loại đó; dùng giá trị đã lưu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

**Sau:**

A1 — Tại bước 5: Một hợp đồng đã có hóa đơn cùng kỳ. Trả hóa đơn hiện có với nhãn đã tồn tại, không tạo lại. Tiếp tục xử lý các hợp đồng còn lại tại bước 5, sau đó đưa hóa đơn hiện có vào kết quả tổng hợp tại bước 6.

A2 — Tại bước 5: Chỉ số loại dịch vụ đã có trong kỳ. Bỏ qua chỉ số gửi bổ sung cho loại đó; dùng giá trị đã lưu. Tiếp tục tính và lập hóa đơn tại bước 5, xử lý các hợp đồng còn lại rồi hiển thị kết quả tổng hợp tại bước 6; không yêu cầu nhập lại chỉ vì đã có chỉ số.

**Căn cứ đối chiếu:**

- `backend/src/billing/billing.service.ts:451`.

### HC-15 UC-BIL-02.06 Sao chép thành công bị ghi là yêu cầu bị từ chối

**Lý do:** Sao chép nội dung là một kết quả thành công không tạo PDF, không phải lỗi hoặc từ chối nghiệp vụ.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 1: Chọn sao chép nội dung. Ứng dụng ghi nội dung hóa đơn vào bộ nhớ sao chép; không tạo PDF. UC kết thúc đối với yêu cầu bị từ chối.

**Sau:**

A1 — Tại bước 1: Chọn sao chép nội dung. Ứng dụng ghi nội dung hóa đơn vào bộ nhớ sao chép; không tạo PDF. UC kết thúc thành công sau khi sao chép; dữ liệu hóa đơn không thay đổi.

**Căn cứ đối chiếu:**

- `/Users/hoang/Rental_room_management/lib/features/billing/invoice_detail_screen.dart:1182`.

### HC-16 UC-BIL-02.07 Gộp điều kiện xem trước với chạy ngay và đặt lịch chạy trong bước lưu cấu hình

**Lý do:** Xem trước không yêu cầu bật cấu hình; chạy ngay có yêu cầu bật. Cả hai dùng cấu hình đã lưu hoặc mặc định, không tự dùng các giá trị đang sửa chưa lưu. Đến lịch là sự kiện riêng sau cấu hình, không phải nhánh tại bước lưu.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Xem trước hoặc chạy ngay khi cấu hình đang bật. Xem danh sách dự kiến; chạy thủ công dùng quy trình lập hàng loạt và cập nhật thông tin lần chạy.

A2 — Tại bước 5: Đến lịch chạy tự động. Bộ lập lịch kiểm tra khu trọ hoạt động, kỳ chưa chạy và chỉ số; thiếu chỉ số điện/nước cho hóa đơn cần lập thì bỏ qua kỳ chạy và trả lý do.

**Sau:**

A1 — Tại bước 3: Chủ trọ chọn xem trước thay cho lưu cấu hình. Hệ thống kiểm tra khu trọ, sử dụng cấu hình đã lưu hoặc cấu hình mặc định nếu chưa có để hiển thị danh sách hợp đồng, chỉ số và hạn thanh toán dự kiến. Cho phép xem trước khi cấu hình đang tắt; không lưu các thay đổi chưa xác nhận và không tạo hóa đơn. UC kết thúc nhánh xem trước sau khi hiển thị kết quả.

A2 — Tại bước 3: Chủ trọ chọn chạy ngay thay cho lưu cấu hình. Hệ thống kiểm tra khu trọ và cấu hình đã lưu đang bật, sau đó thực hiện lập hóa đơn hàng loạt theo UC-BIL-02.02 bằng cấu hình đã lưu. Khi xử lý thành công, cập nhật kỳ và thời điểm lần chạy rồi hiển thị kết quả; không tự lưu các giá trị đang sửa chưa xác nhận. Việc chạy khi đến lịch là sự kiện độc lập, được mô tả tại PX-19, không diễn ra trong bước 5 của luồng lưu cấu hình.

**Căn cứ đối chiếu:**

- `backend/src/billing/billing.service.ts:650`.
- `backend/src/billing/billing.service.ts:677`.
- `backend/src/billing/billing-automation.scheduler.ts:53`.
- `/Users/hoang/Rental_room_management/lib/features/billing/bulk_invoice_screen.dart:191`.

### HC-17 UC-BIL-03.01 Nhánh thu một phần ghi tiền trước kiểm tra

**Lý do:** Số tiền được nhập tại bước 3; kiểm tra điều kiện và giới hạn ở bước 4 rồi mới ghi khoản thanh toán ở bước 5.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Số tiền nhỏ hơn số dư. Ghi thu một phần; hóa đơn chuyển Thanh toán một phần.

**Sau:**

A1 — Tại bước 3: Chủ trọ nhập số tiền nhỏ hơn số còn phải thu. Tiếp tục bước 4 để kiểm tra hóa đơn và số tiền. Nếu hợp lệ, tại bước 5 hệ thống ghi khoản thanh toán và chuyển hóa đơn sang Thanh toán một phần; hiển thị khoản thu và số dư mới tại bước 6.

**Căn cứ đối chiếu:**

- `backend/src/billing/billing.service.ts:967`.

### HC-18 UC-BIL-04 Nhánh từ chối minh chứng bỏ qua kiểm tra và nhầm với thất bại của UC

**Lý do:** Từ chối minh chứng là quyết định xử lý thành công, nhưng vẫn phải kiểm tra quyền quản lý và trạng thái Chờ duyệt. Kiểm tra số dư hóa đơn chỉ áp dụng nhánh duyệt.

**Thuộc tính:** Luồng chính.

**Trước:**

1. Chủ trọ: Mở minh chứng thanh toán đang Chờ duyệt.

2. Hệ thống: Hiển thị số tiền, phương thức, tệp minh chứng và ghi chú của Người thuê.

3. Chủ trọ: Đối soát thông tin đã nhận, chọn duyệt và xác nhận quyết định.

4. Hệ thống: Kiểm tra minh chứng còn Chờ duyệt, hóa đơn chưa hủy, còn phải thu và số tiền minh chứng không vượt số còn phải thu.

5. Hệ thống: Ghi khoản thanh toán từ minh chứng, cập nhật hóa đơn và đánh dấu minh chứng Đã duyệt đồng bộ.

6. Hệ thống: Hiển thị quyết định duyệt, khoản thanh toán và số còn phải thu mới.

**Sau:**

1. Chủ trọ: Mở minh chứng thanh toán đang Chờ duyệt.

2. Hệ thống: Hiển thị số tiền, phương thức, tệp minh chứng và ghi chú của Người thuê.

3. Chủ trọ: Đối soát thông tin đã nhận, chọn duyệt và xác nhận quyết định.

4. Hệ thống: Kiểm tra minh chứng tồn tại trong phạm vi quản lý và còn Chờ duyệt. Với quyết định duyệt, kiểm tra thêm hóa đơn chưa hủy, còn phải thu và số tiền minh chứng không vượt số còn phải thu.

5. Hệ thống: Ghi khoản thanh toán từ minh chứng, cập nhật hóa đơn và đánh dấu minh chứng Đã duyệt đồng bộ.

6. Hệ thống: Hiển thị quyết định duyệt, khoản thanh toán và số còn phải thu mới.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Chọn từ chối. Đánh dấu chứng từ Đã từ chối, ghi người/thời điểm/ghi chú duyệt; không tạo khoản thu. UC kết thúc đối với yêu cầu bị từ chối.

**Sau:**

A1 — Tại bước 3: Chủ trọ chọn từ chối minh chứng, bổ sung ghi chú nếu có và xác nhận. Tại bước 4, hệ thống kiểm tra minh chứng thuộc phạm vi quản lý và còn Chờ duyệt; không áp dụng điều kiện số dư hóa đơn dành riêng cho nhánh duyệt. Nếu hợp lệ, tại bước 5 ghi kết quả Đã từ chối, người duyệt, thời điểm và ghi chú; không tạo khoản thanh toán và không thay đổi số tiền đã thu. Tại bước 6, hiển thị quyết định từ chối; UC kết thúc thành công ở nhánh từ chối.

**Căn cứ đối chiếu:**

- `backend/src/billing/billing.service.ts:1057`.

### HC-19 UC-BIL-05.02 Nhánh khoản chi cấp khu trọ ghi nhận trước kiểm tra

**Lý do:** Không chọn phòng chỉ thay đổi phạm vi khoản chi. Vẫn phải kiểm tra khu trọ và dữ liệu ở bước 4 trước khi ghi tại bước 5.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Không chọn phòng. Ghi khoản chi ở cấp khu trọ; tiếp tục bước 4.

**Sau:**

A1 — Tại bước 3: Chủ trọ không chọn phòng, xác định khoản chi ở cấp khu trọ. Tiếp tục bước 4 để kiểm tra khu trọ và dữ liệu khoản chi. Nếu hợp lệ, tại bước 5 hệ thống ghi khoản chi không gắn phòng và hiển thị kết quả.

**Căn cứ đối chiếu:**

- `backend/src/expenses/expenses.service.ts:75`.

### HC-20 UC-BIL-05.03 Đặc tả cam kết kiểm tra phòng của khu trọ trong trường hợp chưa được bảo đảm

**Lý do:** Khi đổi khu trọ nhưng không gửi lại phòng, xử lý hiện tại giữ phòng cũ và không kiểm tra lại sự phù hợp. Đây là thiếu sót mã nguồn cần tách riêng, không ghi thành bảo đảm đã thực hiện.

**Thuộc tính:** Luồng chính.

**Trước:**

1. Chủ trọ: Chọn chỉnh sửa khoản chi.

2. Hệ thống: Hiển thị khu trọ, phòng, nhóm, số tiền, ngày, tiêu đề, ghi chú và chứng từ hiện tại.

3. Chủ trọ: Thay đổi thông tin cần sửa và xác nhận lưu.

4. Hệ thống: Kiểm tra khoản chi thuộc phạm vi quản lý, dữ liệu hợp lệ và phòng thuộc khu trọ được cập nhật nếu có.

5. Hệ thống: Lưu các thông tin thay đổi và hiển thị khoản chi sau cập nhật.

**Sau:**

1. Chủ trọ: Chọn chỉnh sửa khoản chi.

2. Hệ thống: Hiển thị khu trọ, phòng, nhóm, số tiền, ngày, tiêu đề, ghi chú và chứng từ hiện tại.

3. Chủ trọ: Thay đổi thông tin cần sửa và xác nhận lưu.

4. Hệ thống: Kiểm tra khoản chi và khu trọ thuộc phạm vi quản lý, dữ liệu hợp lệ; khi có lựa chọn phòng mới, kiểm tra phòng thuộc khu trọ áp dụng. Trường hợp đổi khu trọ mà không chọn lại phòng cần xác nhận tại PX-32.

5. Hệ thống: Lưu các thông tin thay đổi và hiển thị khoản chi sau cập nhật.

**Thuộc tính:** Quy tắc nghiệp vụ.

**Trước:**

BR1. Số tiền sau sửa vẫn phải là số nguyên dương.

BR2. Phòng được chọn phải thuộc khu trọ của khoản chi.

**Sau:**

BR1. Số tiền sau sửa vẫn phải là số nguyên dương.

BR2. Khi chọn phòng trong lần cập nhật, phòng được chọn phải thuộc khu trọ của khoản chi. Việc giữ phòng cũ khi đổi khu trọ chưa được bảo đảm, xem PX-32.

**Căn cứ đối chiếu:**

- `backend/src/expenses/expenses.service.ts:97`.
- `/Users/hoang/Rental_room_management/lib/features/expenses/expense_form_screen.dart:123`.

### HC-21 UC-TEN-01 Hồ sơ chưa có hợp đồng bị coi là yêu cầu bị từ chối

**Lý do:** Hồ sơ đang được sử dụng vẫn có thể truy cập cổng thông tin khi chưa có hợp đồng. Phần phòng/hợp đồng là rỗng, không phải lỗi thiếu hồ sơ.

**Thuộc tính:** Luồng thay thế.

**Trước:**

A1 — Tại bước 3: Hồ sơ chưa có hợp đồng. Thông tin hồ sơ vẫn được trả về; không tạo giả một phòng đang thuê. UC kết thúc đối với yêu cầu bị từ chối.

**Sau:**

A1 — Tại bước 3: Hồ sơ chưa có hợp đồng. Hệ thống vẫn tổng hợp thông tin hồ sơ và dữ liệu liên quan hiện có; không hiển thị một phòng đang thuê khi chưa có căn cứ. Tiếp tục bước 4 để hiển thị thông tin tổng quan với phần hợp đồng/phòng thuê rỗng. Người thuê vẫn có thể xem các mục được phép tại bước 5; đây không phải yêu cầu bị từ chối.

**Căn cứ đối chiếu:**

- `backend/src/tenant-portal/tenant-portal.service.ts:93`.

### HC-22 UC-SYS-01.01 Thuật ngữ triển khai còn nằm trong bảng nghiệp vụ

**Lý do:** Đặc tả cần diễn đạt chính sách mật khẩu bằng ngôn ngữ nghiệp vụ, không đưa vị trí kiểm tra kỹ thuật vào câu mô tả.

**Thuộc tính:** Luồng ngoại lệ.

**Trước:**

E1 — Tại bước 3: Mã để trống hoặc mật khẩu dưới 12 ký tự trên biểu mẫu. Không gửi yêu cầu; yêu cầu bổ sung dữ liệu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

E2 — Tại bước 4: Mã sai, hết hạn, đã dùng hoặc hồ sơ đã liên kết tài khoản. Từ chối kích hoạt; hiển thị lỗi lời mời không hợp lệ. UC kết thúc đối với yêu cầu bị từ chối.

E3 — Tại bước 4: Mật khẩu không đáp ứng chính sách phía máy chủ. Từ chối yêu cầu; Người thuê điều chỉnh mật khẩu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

E4 — Tại bước 5: Email đã được đăng ký. Từ chối tạo tài khoản trùng. UC kết thúc đối với yêu cầu bị từ chối.

**Sau:**

E1 — Tại bước 3: Mã để trống hoặc mật khẩu dưới 12 ký tự trên biểu mẫu. Không gửi yêu cầu; yêu cầu bổ sung dữ liệu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

E2 — Tại bước 4: Mã sai, hết hạn, đã dùng hoặc hồ sơ đã liên kết tài khoản. Từ chối kích hoạt; hiển thị lỗi lời mời không hợp lệ. UC kết thúc đối với yêu cầu bị từ chối.

E3 — Tại bước 4: Mật khẩu không đáp ứng chính sách mật khẩu. Từ chối yêu cầu; Người thuê điều chỉnh mật khẩu. Sau khi điều chỉnh, thực hiện lại từ bước 3.

E4 — Tại bước 5: Email đã được đăng ký. Từ chối tạo tài khoản trùng. UC kết thúc đối với yêu cầu bị từ chối.

**Căn cứ đối chiếu:**

- `backend/src/tenants/dto/accept-tenant-invite.dto.ts:16`.

## 3 Thiếu sót mã nguồn và kiểm thử chưa xử lý

### K-01 Giữ phòng cũ khi cập nhật khu trọ mà bỏ trường phòng

**Trạng thái:** Đã xác nhận qua đọc mã nguồn và gọi trực tiếp phương thức xử lý với dữ liệu giả lập. Chưa sửa mã nguồn; liên quan UC-BIL-05.03, PX-32.

**Tình huống:** Khoản chi có khu trọ A và phòng A1. Gửi yêu cầu cập nhật chỉ đổi khu trọ sang B và không gửi trường phòng. Xử lý kiểm tra khu trọ B nhưng không kiểm tra phòng A1; khi lưu vẫn giữ phòng A1. Nếu A1 không thuộc B, dữ liệu khu trọ và phòng có thể không nhất quán.

**Bằng chứng:** `backend/src/expenses/expenses.service.ts:97` chỉ kiểm tra phòng khi có giá trị phòng trong yêu cầu cập nhật; phần lưu chỉ thay đổi phòng nếu trường này được cung cấp. Kiểm chứng với đối tượng giả lập cho thấy không có lần kiểm tra phòng, khu trọ đổi sang B và phòng A1 được giữ lại.

**Phân biệt với biểu mẫu:** `/Users/hoang/Rental_room_management/lib/data/expenses/expense_repository.dart:90` gửi rõ giá trị phòng rỗng khi sửa mà bỏ lựa chọn phòng; nhánh này xóa liên kết phòng. Vì vậy không kết luận thao tác bình thường trên biểu mẫu đã gây lỗi trên. Thiếu sót nằm ở trường hợp cập nhật một phần bỏ hẳn trường phòng.

**Hướng xử lý cần thống nhất:** Khi đổi khu trọ, hoặc xóa liên kết phòng, hoặc kiểm tra lại phòng giữ nguyên thuộc khu trọ mới. Cần chốt chính sách và bổ sung kiểm thử cho việc bỏ trường, gửi rỗng và chọn lại phòng. Đặc tả đã chuyển phần chưa bảo đảm sang PX-32, không âm thầm chọn một chính sách và không ghi như lỗi đã sửa trong chương trình.

### K-02 Hai kiểm thử onboarding không tìm thấy nút Next

**Trạng thái:** Xác nhận kiểm thử thất bại trong checkout hiện tại, không phát sinh từ việc hiệu chỉnh tài liệu. Chưa sửa kiểm thử hoặc màn hình.

- `onboarding create account marks completed before navigation`: `/Users/hoang/Rental_room_management/test/features/onboarding/onboarding_persistence_test.dart:222`.
- `onboarding log in marks completed before navigation`: `/Users/hoang/Rental_room_management/test/features/onboarding/onboarding_persistence_test.dart:259`.

Cả hai đều dừng khi thao tác chạm dùng bộ tìm `find.text("Next")` không tìm thấy widget. Kết quả này chưa đủ để kết luận lưu trạng thái onboarding bị hỏng; cần đối chiếu điều hướng và nhãn nút hiện tại với kịch bản kiểm thử. Đây là lỗi kiểm thử cần xử lý trước khi công bố toàn bộ bộ kiểm thử giao diện đạt.

### Các điểm chưa chốt và phạm vi chưa bổ sung

- PX-01 đến PX-03 về giá thuê, điều kiện phòng và tiền cọc vẫn chờ xác nhận; không chọn một phía kiểm tra làm chính sách chung.
- PX-13 bổ sung khác biệt về ngày xử lý giữa biểu mẫu sửa và chuyển trạng thái riêng; PX-19 chuyển chạy khi đến lịch về sự kiện độc lập, vẫn yêu cầu xác nhận vận hành thật.
- Các chức năng Nhân viên, tự đăng ký, đổi mật khẩu và trao đổi Zalo của Người thuê có dấu vết trong mã nguồn nhưng chưa được đưa vào bộ 24 UC tổng quan đã thống nhất. Đây là yêu cầu chốt phạm vi theo PX-30 và Phụ lục B, không tự động là lỗi thiếu chức năng và không tự thêm UC trong lần sửa này.
- Các giới hạn đã ghi ở PX khác được giữ lại, không chuyển thành cam kết đã hoàn thành chỉ vì có phần xử lý tương ứng.

## 4 Kết quả kiểm chứng

| Hạng mục | Cách kiểm tra | Kết quả | Giới hạn |
| --- | --- | --- | --- |
| Unit test phần xử lý nghiệp vụ | `node node_modules/jest/bin/jest.js --runInBand` tại thư mục API | 8 bộ kiểm thử, 59 test đạt | Không thay thế kiểm thử với cơ sở dữ liệu thực hoặc dịch vụ bên ngoài |
| Kiểm tra kiểu phần xử lý nghiệp vụ | `node node_modules/typescript/bin/tsc --noEmit --incremental false -p tsconfig.json` | Đạt, không có chẩn đoán | Không chạy triển khai hoặc tạo bản build |
| Phân tích tĩnh ứng dụng | `flutter analyze --no-pub` | No issues found | Không xác nhận hành vi lúc chạy |
| Bộ kiểm thử ứng dụng | `flutter test --reporter compact` | 110 đạt, 2 thất bại | Hai lỗi onboarding nêu ở K-02, chưa sửa |
| Kiểm chứng bằng phương thức xử lý thật với dữ liệu giả lập | Cập nhật khoản chi, cập nhật bảo trì, chuyển trạng thái và tổng số phòng | 6 điều kiện được xác nhận | Giả lập truy cập dữ liệu; không phải kiểm thử cơ sở dữ liệu thực |
| Đồng bộ đặc tả | Đối chiếu từng ô thuộc tính giữa Markdown và Word | 67 UC, 13 thuộc tính mỗi UC; tất cả ô khớp | Chỉ kiểm chứng nội dung và cấu trúc tài liệu |
| Bước và nhánh đã sửa | Kiểm tra phạm vi bước và các điều kiện hồi quy riêng | 232 tham chiếu bước hợp lệ; nhánh đã sửa đạt | Chỉ kiểm tra ngữ nghĩa đã được mã hóa, không chứng minh đầy đủ mọi nghiệp vụ |
| Liên kết và sơ đồ | Kiểm tra đích liên kết, số ảnh và dữ liệu ảnh | 254 liên kết nội bộ hợp lệ, 11 ảnh sơ đồ giữ nguyên | Không tự suy ra quan hệ include hoặc extend |
| Bố cục Word | Kết xuất và kiểm tra trang | 95 trang, không trang rỗng hoặc chữ vượt giới hạn kiểm tra; đã kiểm tra ảnh kết xuất | Đây là QA tài liệu, không phải nghiệm thu chức năng |

Việc đếm tham chiếu bước không đủ phát hiện lỗi E5: cả bước 3 và bước 5 đều nằm trong phạm vi hợp lệ. Do đó lần kiểm tra này bổ sung điều kiện riêng rằng nhánh phòng đã có hợp đồng phải trở lại bước chọn phòng, cũng như các điều kiện về thứ tự kiểm tra trước khi ghi nhận ở nhánh thay thế.

## 5 Ma trận rà soát 67 UC

Đã rà soát mô tả và đối chiếu tĩnh phần xử lý liên quan. “Chưa ghi nhận sai lệch bổ sung” không có nghĩa UC đã được nghiệm thu hoặc không còn lỗi; các điểm PX vẫn áp dụng. Căn cứ ở cột cuối là tệp xử lý chính trong thư mục API, không phải tất cả tệp giao diện và dữ liệu của UC.

| Nhóm | Mã UC | Tên UC | Kết quả rà soát tài liệu | Phần xử lý chính |
| --- | --- | --- | --- | --- |
| SYS | UC-SYS-01 | Đăng nhập | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/auth/auth.service.ts` |
| SYS | UC-SYS-01.01 | Kích hoạt tài khoản người thuê từ lời mời | Đã hiệu chỉnh HC-22 | `backend/src/tenants/tenant-invites.service.ts` |
| SYS | UC-SYS-02 | Đăng xuất | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/auth/auth.service.ts` |
| ADM | UC-ADM-01 | Xem tổng quan hệ thống | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-02.01 | Tra cứu tài khoản chủ trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-02.02 | Tạo tài khoản chủ trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-02.03 | Cập nhật thông tin tài khoản chủ trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-02.04 | Khóa hoặc mở khóa tài khoản chủ trọ | Đã hiệu chỉnh HC-03 | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-03.01 | Tra cứu khu trọ toàn hệ thống | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-03.02 | Tạo khu trọ cho chủ trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| ADM | UC-ADM-03.03 | Cập nhật thông tin khu trọ toàn hệ thống | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/admin/admin.service.ts` |
| OPT | UC-OPT-01 | Xem tổng quan vận hành | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/dashboard/dashboard.service.ts` |
| OPT | UC-OPT-02.01 | Tra cứu và chọn khu trọ | Đã hiệu chỉnh HC-07 | `backend/src/properties/properties.service.ts` |
| OPT | UC-OPT-02.02 | Tạo khu trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/properties/properties.service.ts` |
| OPT | UC-OPT-02.03 | Cập nhật thông tin khu trọ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/properties/properties.service.ts` |
| OPT | UC-OPT-02.04 | Lưu trữ hoặc khôi phục khu trọ | Đã hiệu chỉnh HC-04 | `backend/src/properties/properties.service.ts` |
| OPT | UC-OPT-02.05 | Xóa khu trọ chưa có phòng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/properties/properties.service.ts` |
| OPT | UC-OPT-03.01 | Tra cứu phòng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.02 | Tạo phòng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.03 | Cập nhật thông tin phòng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.04 | Chuyển trạng thái trống hoặc bảo trì của phòng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.05 | Vô hiệu hóa hoặc khôi phục phòng | Đã hiệu chỉnh HC-05 | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.06 | Xóa phòng chưa phát sinh nghiệp vụ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.07 | Quản lý tài sản phòng | Đã hiệu chỉnh HC-08 | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.08 | Quản lý phí dịch vụ phòng | Đã hiệu chỉnh HC-09 | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-03.09 | Theo dõi lịch kiểm tra phòng | Đã hiệu chỉnh HC-10 | `backend/src/rooms/rooms.service.ts` |
| OPT | UC-OPT-04.01 | Tra cứu hồ sơ người thuê | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenants/tenants.service.ts` |
| OPT | UC-OPT-04.02 | Tạo hồ sơ người thuê | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenants/tenants.service.ts` |
| OPT | UC-OPT-04.03 | Cập nhật hồ sơ người thuê | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenants/tenants.service.ts` |
| OPT | UC-OPT-04.04 | Vô hiệu hóa hoặc khôi phục hồ sơ người thuê | Đã hiệu chỉnh HC-06 | `backend/src/tenants/tenants.service.ts` |
| OPT | UC-OPT-04.05 | Xóa hồ sơ người thuê chưa phát sinh nghiệp vụ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenants/tenants.service.ts` |
| OPT | UC-OPT-04.06 | Mời người thuê kích hoạt tài khoản | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenants/tenant-invites.service.ts` |
| OPT | UC-OPT-05.01 | Tra cứu hợp đồng và lịch sử thuê | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-05.02 | Tạo hợp đồng thuê phòng | Đã hiệu chỉnh HC-01, HC-02 | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-05.03 | Cập nhật điều khoản hợp đồng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-05.04 | Gia hạn hợp đồng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-05.05 | Kết thúc hợp đồng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-05.06 | Ghi nhận thu, hoàn hoặc khấu trừ tiền cọc | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/leases/leases.service.ts` |
| OPT | UC-OPT-06.01 | Tra cứu yêu cầu bảo trì | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/maintenance/maintenance.service.ts` |
| OPT | UC-OPT-06.02 | Tạo yêu cầu bảo trì | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/maintenance/maintenance.service.ts` |
| OPT | UC-OPT-06.03 | Cập nhật nội dung và tiến độ bảo trì | Đã hiệu chỉnh HC-11 | `backend/src/maintenance/maintenance.service.ts` |
| OPT | UC-OPT-06.04 | Hoàn tất bảo trì và ghi nhận chi phí | Đã hiệu chỉnh HC-12 | `backend/src/maintenance/maintenance.service.ts` |
| BIL | UC-BIL-01 | Ghi chỉ số điện nước | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.01 | Lập hóa đơn cho một hợp đồng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.02 | Lập hóa đơn hàng loạt | Đã hiệu chỉnh HC-13, HC-14 | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.03 | Tra cứu hóa đơn và công nợ | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.04 | Điều chỉnh hóa đơn chưa thu tiền | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.05 | Hủy hóa đơn | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.06 | Xuất hoặc chia sẻ hóa đơn | Đã hiệu chỉnh HC-15 | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-02.07 | Cấu hình lập hóa đơn định kỳ | Đã hiệu chỉnh HC-16 | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-03.01 | Ghi nhận thanh toán hóa đơn | Đã hiệu chỉnh HC-17 | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-03.02 | Đảo khoản thanh toán đã ghi nhận | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-04 | Duyệt hoặc từ chối minh chứng thanh toán | Đã hiệu chỉnh HC-18 | `backend/src/billing/billing.service.ts` |
| BIL | UC-BIL-05.01 | Tra cứu chi phí vận hành | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/expenses/expenses.service.ts` |
| BIL | UC-BIL-05.02 | Ghi nhận chi phí vận hành | Đã hiệu chỉnh HC-19 | `backend/src/expenses/expenses.service.ts` |
| BIL | UC-BIL-05.03 | Cập nhật khoản chi | Đã hiệu chỉnh HC-20 | `backend/src/expenses/expenses.service.ts` |
| BIL | UC-BIL-06.01 | Xem báo cáo tháng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/reports/reports.service.ts` |
| BIL | UC-BIL-06.02 | Xuất báo cáo tháng | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/reports/reports.service.ts` |
| BIL | UC-BIL-07.01 | Theo dõi thông báo và việc cần xử lý | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/notifications/notifications.service.ts` |
| BIL | UC-BIL-07.02 | Gửi thông báo hoặc nhắc thanh toán | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/notifications/notifications.service.ts` |
| TEN | UC-TEN-01 | Xem thông tin thuê phòng | Đã hiệu chỉnh HC-21 | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-02 | Xem hợp đồng thuê của mình | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-03 | Xem và xuất hóa đơn của mình | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-04 | Gửi minh chứng thanh toán | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-05.01 | Gửi yêu cầu bảo trì | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-05.02 | Theo dõi và phản hồi yêu cầu bảo trì | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |
| TEN | UC-TEN-06 | Xem và đánh dấu thông báo đã đọc | Chưa ghi nhận sai lệch bổ sung trong lần rà soát này | `backend/src/tenant-portal/tenant-portal.service.ts` |

## 6 Việc cần hoàn tất trước khi phát triển hoặc nghiệm thu

1. Chủ trọ hoặc người phụ trách nghiệp vụ chốt các điểm PX liên quan đến phần sẽ triển khai, đặc biệt giá thuê, trạng thái phòng, tiền cọc và bảo trì.
2. Sửa thiếu sót K-01 theo chính sách được chọn, bổ sung kiểm thử cập nhật một phần và kiểm tra dữ liệu đang có nếu đã phát sinh tình huống này.
3. Xác định nguyên nhân và sửa hai kiểm thử onboarding; chạy lại toàn bộ bộ kiểm thử ứng dụng trước khi công bố trạng thái đạt.
4. Kiểm thử end-to-end với dữ liệu kiểm thử phù hợp cho vòng đời hợp đồng, lập hóa đơn, duyệt hoặc từ chối minh chứng, khoản thu một phần, bảo trì và phạm vi quyền.
5. Kiểm chứng lịch lập hóa đơn, múi giờ, cấu hình và gửi Zalo trên môi trường dự kiến triển khai. Không dùng việc lưu cấu hình thành công làm bằng chứng tác vụ tự động đã chạy.
6. Chốt có mở rộng sơ đồ tổng quan cho Nhân viên và các chức năng ngoài phạm vi hay không; chỉ sau quyết định này mới thêm UC và sơ đồ tương ứng.
