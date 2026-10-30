# Hoàn thiện phần Use Case trong báo cáo đồ án

Ngày đối chiếu: 29/10/2026.

## Bản đính chính sau kiểm tra code

Ngày 30/10/2026 đã sửa 23 trường thuộc 5 UC và thay 30 ảnh trắng đen trong bản V5, giữ nguyên V4. Nội dung `data/business-report-content.json` và bộ sinh văn bản ở đây đã được sửa tương ứng; bản Word V4 và các kết quả kiểm tra cũ là lịch sử trước đính chính. Xem `/Users/hoang/Rental_room_management/BA_Documentation/09_Code_Documentation_Audit/README.md:1` để lấy bản V5, kết quả kiểm tra hiện tại và những giới hạn chưa xác nhận. Không dùng validator dựa hash cũ để kết luận tài liệu hiện tại chưa từng thay đổi.

## Phạm vi bàn giao

- Bản báo cáo Word mới được lưu cạnh bản gốc trên Desktop, tên `Bao_cao_Quan_ly_Nha_tro_V4_2026-10-29_BA.docx`.
- Giữ nguyên bản gốc ngày 28/10/2026; không sửa ứng dụng, danh mục Use Case chuẩn hóa hoặc sơ đồ chuẩn ở các giai đoạn trước.
- Thay phần yêu cầu chức năng, tác nhân, danh mục, đặc tả, sơ đồ Use Case và các phụ lục liên quan; đồng bộ mục lục và danh mục hình theo bản đã kết xuất.
- Các chương khác, mô hình lớp, sơ đồ tương tác, ảnh giao diện và kết quả kiểm thử lịch sử được giữ theo bản trước. Một số mã tham chiếu cũ được chuyển về mục tiêu hiện hành; không coi việc cập nhật báo cáo là lần nghiệm thu ứng dụng mới.

## Nội dung đã chuẩn hóa

| Hạng mục | Kết quả |
| --- | --- |
| Danh mục | 162 Use Case thuộc 16 nhóm nghiệp vụ |
| Tác nhân chính | 5 tác nhân con người, có Nhân viên vận hành |
| Tác nhân phối hợp | Chỉ giữ các liên kết đã có căn cứ, tùy kênh hoặc phương thức sử dụng |
| Đặc tả | Một bảng liên tục, 20 thuộc tính cho mỗi Use Case; đầu bảng lặp lại có mã UC để đọc khi chuyển trang |
| Sơ đồ trong báo cáo | 1 sơ đồ tổng quan gồm 12 mục tiêu đại diện và 29 sơ đồ nhóm bao phủ đủ 162 UC |
| Phân quyền | Ma trận đủ 162 UC; phân biệt tác nhân chính, có điều kiện, biến thể giới hạn, bị chặn và chưa xác định quyền |
| Mức hoàn thiện | 151 đã đối chiếu, 9 một phần, 1 thanh toán thẻ thử nghiệm, 1 trao đổi Zalo mô phỏng |

Các sơ đồ nhóm được chia nhỏ về mặt trình bày để đọc được trên khổ A4. Không thay đổi tập mục tiêu hoặc đường liên kết tác nhân so với bộ sơ đồ chuẩn; không tự thêm quan hệ bao hàm, mở rộng hoặc kế thừa quyền.

## Nguyên tắc biên tập

Các bước trong đặc tả mô tả ai làm gì, thông tin nào được kiểm tra, khi nào được chấp nhận hoặc bị từ chối và kết quả nghiệp vụ là gì. Không đưa tên lớp, đường dẫn xử lý, thành phần kiến trúc hoặc mã phản hồi kỹ thuật vào lời đặc tả. Bằng chứng triển khai vẫn truy vết qua mã UC trong bộ tài liệu hiện trạng và đặc tả giai đoạn trước.

Các giới hạn về nhận thư, giao thông báo, trí tuệ nhân tạo, kiểm tra an toàn tệp, thanh toán thử và trao đổi mô phỏng được giữ rõ. Không diễn giải kết quả đã đối chiếu thành chức năng đã nghiệm thu toàn bộ ngoài thực tế.

## Tài nguyên đối chiếu

- `data/business-report-content.json`: nội dung 20 thuộc tính của 162 UC được đưa vào Word.
- `data/title-crosswalk.json`: tên danh mục gốc và tên diễn đạt trong báo cáo, giữ nguyên mã.
- `data/input-checks.json`: các kiểm tra dữ liệu được diễn đạt bằng thuật ngữ nghiệp vụ; không gán bắt buộc đồng thời cho các trường thuộc những biến thể khác nhau.
- `data/report-diagrams.json` và `diagrams/`: bản sơ đồ riêng của báo cáo; không ghi đè sơ đồ chuẩn giai đoạn trước.
- `Validation_Result.json`: kiểm tra mã, nhóm, tác nhân, mức hoàn thiện, bảng Word, liên kết sơ đồ, diễn đạt và bảo toàn tài nguyên được bảo vệ.
- `data/pagination-validation.json`: kiểm tra đối chiếu mục lục và danh mục hình với trang thực tế của bản kết xuất dùng để kiểm tra bố cục.

## Giới hạn cần người thực hiện lưu ý

Thông tin họ tên, mã số sinh viên, lớp và giảng viên hướng dẫn chưa được cung cấp trong bản gốc; không tự suy đoán để điền. Chưa có bộ ảnh riêng của Nhân viên vận hành trong phần giao diện được giữ lại. Người dùng cần bổ sung thông tin cá nhân trước khi nộp; các giới hạn nghiệm thu đã được nêu ngay trong báo cáo.

Việc kết xuất để kiểm tra sử dụng bộ phông chữ và công cụ trên máy hiện tại. Khi mở bằng một phiên bản Word hoặc bộ phông khác, số trang có thể thay đổi; các liên kết điều hướng vẫn trỏ theo tiêu đề, còn số trang tĩnh cần đối chiếu lại nếu thay đổi nội dung hoặc dàn trang.
