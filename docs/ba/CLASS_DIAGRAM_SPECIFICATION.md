# 2.4.3 Mô hình lớp và đối tượng

Mô hình lớp xác định các thực thể, thuộc tính quan trọng và quan hệ của hệ thống quản lý nhà trọ. Mô hình đối tượng minh họa cách các thực thể được liên kết tại một thời điểm cụ thể. Tài liệu trình bày một sơ đồ tổng quan, tám sơ đồ lớp chi tiết theo sáu nhóm nghiệp vụ và hai góc nhìn của cùng một ví dụ đối tượng. Mục tiêu là hỗ trợ đọc hiểu thiết kế, đối chiếu đặc tả Use Case và đưa mục 2.4.3 vào báo cáo dự án.

Phạm vi gồm 23 lớp dữ liệu và 39 quan hệ cấu trúc. Sơ đồ tổng quan chỉ chọn 13 lớp và 14 quan hệ trọng tâm; toàn bộ quan hệ trong phạm vi được thể hiện ở các sơ đồ chi tiết và ma trận phụ lục. Tên lớp, tên thuộc tính và kiểu dữ liệu giữ nguyên để tránh sai lệch khi đối chiếu; phần diễn giải sử dụng ngôn ngữ nghiệp vụ.

## 1 Phạm vi và nguyên tắc mô hình hóa

- Ba vai trò sử dụng trong báo cáo là Admin, Chủ trọ và Người thuê. Vai trò được biểu diễn bằng `User.role`; không tạo ba lớp kế thừa vì mô hình hiện hành không khai báo cấu trúc kế thừa đó.

- Hai lớp `StaffProfile` và `StaffInvite` nằm ngoài phạm vi mô hình của mục này. Giá trị `STAFF` vẫn được giữ trong danh mục `UserRole` để không làm sai tập giá trị đang tồn tại; việc giữ giá trị này không mở rộng phạm vi actor đã chốt.

- Các lớp thể hiện thực thể dữ liệu cùng quan hệ liên kết. Không đưa màn hình, biểu mẫu, lớp xử lý yêu cầu hoặc tích hợp bên ngoài thành thực thể nghiệp vụ nếu không có cấu trúc dữ liệu tương ứng.

- Không bổ sung phương thức như tạo hợp đồng, duyệt minh chứng hoặc tính tiền vào ngăn thao tác của thực thể. Các thao tác này là hành vi xử lý nghiệp vụ, chưa được định nghĩa là phương thức trên các lớp dữ liệu đang mô hình hóa.

- Chỉ sử dụng quan hệ liên kết và tham chiếu theo mã. Không suy ra quan hệ hợp thành hoặc kết tập từ cơ chế xóa dữ liệu liên quan. Bội số mô tả cấu trúc lưu trữ; các giới hạn theo trạng thái hoặc theo thời điểm được giải thích riêng.

- Các thuộc tính trong hình và bảng là thuộc tính chính, không phải toàn bộ từ điển dữ liệu. Việc lược bớt trường định danh liên kết hoặc thời điểm cập nhật không có nghĩa các trường đó không tồn tại.

## 2 Quy ước đọc sơ đồ

| Ký hiệu | Cách hiểu |
| --- | --- |
| Hộp lớp | Ngăn trên ghi tên lớp, ngăn dưới ghi thuộc tính và kiểu. Không sử dụng dấu cộng hoặc trừ để suy đoán mức truy cập của thuộc tính. |
| Đường liền | Quan hệ cấu trúc đã khai báo giữa hai lớp. Không biểu diễn chiều gọi hàm hoặc trình tự thao tác. |
| Chú thích `<<IDRef>>` | Tham chiếu bằng mã định danh trong dữ liệu; không phải structural association UML. Không vẽ connector, không gán bội số; đây là quy ước chú thích, không phải UML Dependency. |
| 1 | Mỗi đối tượng ở đầu đối diện liên kết với đúng một đối tượng ở đầu có ký hiệu 1. |
| 0..1 | Liên kết là tùy chọn và có tối đa một đối tượng ở đầu được ghi ký hiệu. |
| 0..* | Có thể chưa có hoặc có nhiều đối tượng ở đầu được ghi ký hiệu. |
| `Type?` trong bảng | Giá trị có thể chưa được ghi nhận. Trong hình tương ứng là `Type [0..1]`. |
| `Type[]` trong bảng | Danh sách giá trị. Trong hình tương ứng là `Type [0..*]`. |
| `<<reference>>` | Lớp hoặc đối tượng được nhắc lại để đọc được liên kết trong nhóm hiện tại; không phải một lớp hoặc đối tượng mới. |
| Tên đối tượng được gạch chân | Một đối tượng cụ thể, theo dạng tênĐốiTượng: TênLớp; các dòng phía dưới là giá trị thuộc tính tại thời điểm minh họa. |

Ví dụ: ở quan hệ `Property — Room`, đầu `Property` có bội số 1 và đầu `Room` có bội số 0..*. Mỗi phòng thuộc đúng một khu trọ; một khu trọ có thể chưa có phòng hoặc có nhiều phòng. Ký hiệu 0..* không được thay bằng 1..* chỉ vì màn hình thường hiển thị khu trọ đã có phòng.

## 3 Sơ đồ lớp miền nghiệp vụ tổng quan (Domain Class Diagram)

Sơ đồ tổng quan tập trung vào chuỗi quản lý khu trọ, phòng, hồ sơ Người thuê, hợp đồng, chỉ số, hóa đơn và thanh toán, cùng các thực thể hỗ trợ tiền cọc, bảo trì, chi phí và lập hóa đơn định kỳ. Các lớp hỗ trợ tài khoản, lịch sử, thông báo và những liên kết bổ sung được tách sang sơ đồ chi tiết để giảm mật độ đường nối.

| Nhóm | Lớp chủ trì | Sơ đồ chi tiết |
| --- | --- | --- |
| Tài khoản và hồ sơ Người thuê | User, Tenant, TenantInvite, RefreshToken | CD-01 |
| Khu trọ và phòng | Property, Room, RoomAsset, RoomInspection, RoomServiceFee | CD-02 |
| Hợp đồng và tiền cọc | Lease, LeaseChange, DepositTransaction | CD-03 |
| Hóa đơn và thanh toán | MeterReading, Invoice, Payment, PaymentProof, BillingAutomation | CD-04A, CD-04B, CD-04C |
| Bảo trì và chi phí | Expense, MaintenanceTicket, MaintenanceComment | CD-05 |
| Thông báo và nhật ký | NotificationRead, NotificationDelivery, AuditLog | CD-06 |

![CD-00 Sơ đồ lớp miền nghiệp vụ tổng quan (Domain Class Diagram)](class-diagrams/cd-00.png)

CD-00 — Sơ đồ lớp miền nghiệp vụ tổng quan (Domain Class Diagram). Sơ đồ gồm 13 lớp trọng tâm và 14 quan hệ được chọn. Đây không phải sơ đồ đầy đủ của 23 lớp.

## 4 Các nhóm lớp chi tiết

### 4.1 Tài khoản và hồ sơ Người thuê

Tài khoản phục vụ nhận diện người dùng và phiên đăng nhập; hồ sơ Người thuê phục vụ quản lý người thuê thuộc một Chủ trọ. Hai khái niệm này phải được phân biệt vì Chủ trọ có thể tạo hồ sơ trước khi Người thuê nhận lời mời và có tài khoản truy cập.

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `User`<br>Tài khoản người dùng | Xác định danh tính đăng nhập và vai trò; một tài khoản không đồng nhất với hồ sơ Người thuê. | `id: String`; `fullName: String`; `email: String`; `phone: String?`; `role: UserRole`; `isActive: Boolean` |
| `Tenant`<br>Hồ sơ Người thuê | Lưu thông tin người thuê do Chủ trọ quản lý; có thể chưa liên kết tài khoản truy cập. | `id: String`; `fullName: String`; `phone: String?`; `idNumber: String?`; `isActive: Boolean` |
| `TenantInvite`<br>Lời mời kích hoạt | Ghi lời mời gắn với hồ sơ Người thuê, email được mời, hạn sử dụng và thời điểm chấp nhận. | `id: String`; `email: String`; `expiresAt: DateTime`; `acceptedAt: DateTime?` |
| `RefreshToken`<br>Phiên làm mới đăng nhập | Lưu thông tin phiên làm mới của một tài khoản, phục vụ duy trì và thu hồi phiên. | `id: String`; `expiresAt: DateTime`; `revokedAt: DateTime?` |

Quan hệ `Tenant.landlord` xác định Chủ trọ quản lý hồ sơ: mỗi hồ sơ có một Chủ trọ, mỗi Chủ trọ có thể quản lý nhiều hồ sơ. Quan hệ `Tenant.user` là liên kết tài khoản truy cập tùy chọn và duy nhất, có bội số 0..1 ở cả hai đầu. Một tài khoản có thể chưa có hồ sơ Người thuê; một hồ sơ có thể chưa có tài khoản truy cập.

Mỗi lời mời gắn với một hồ sơ Người thuê và một Chủ trọ; một hồ sơ có thể có nhiều bản ghi lời mời theo lịch sử. `acceptedAt` có thể chưa được ghi nhận khi lời mời chưa được chấp nhận. Mỗi phiên làm mới thuộc một tài khoản; `revokedAt` để trống không phải là kết luận phiên luôn còn hiệu lực, vì còn phải xét `expiresAt`.

![CD-01 Tài khoản và hồ sơ Người thuê](class-diagrams/cd-01.png)

CD-01 — Phân biệt liên kết quản lý hồ sơ và liên kết tài khoản truy cập của Người thuê.

### 4.2 Khu trọ và phòng

Khu trọ là đơn vị quản lý các phòng. Tài sản, phí dịch vụ và lịch kiểm tra đều gắn với từng phòng; không được gộp phí dịch vụ vào chỉ số điện nước hoặc xem lịch kiểm tra là một trường trên hồ sơ phòng.

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `Property`<br>Khu trọ | Nhóm các phòng thuộc một Chủ trọ và ghi nhận tình trạng lưu trữ của khu trọ. | `id: String`; `name: String`; `address: String`; `isArchived: Boolean` |
| `Room`<br>Phòng trọ | Ghi thông tin phòng, giá tham khảo và trạng thái vận hành; trạng thái sử dụng được quản lý riêng. | `id: String`; `name: String`; `basePrice: Int`; `status: RoomStatus`; `isActive: Boolean`; `capacity: Int?` |
| `RoomAsset`<br>Tài sản phòng | Theo dõi tài sản, số lượng, tình trạng và giá trị của tài sản trong một phòng. | `id: String`; `name: String`; `quantity: Int`; `condition: String`; `value: Int?` |
| `RoomInspection`<br>Lịch kiểm tra phòng | Lưu nội dung kiểm tra, ngày dự kiến và thời điểm hoàn tất của một phòng. | `id: String`; `title: String`; `dueAt: DateTime`; `completedAt: DateTime?` |
| `RoomServiceFee`<br>Phí dịch vụ phòng | Ghi khoản phí dịch vụ và tình trạng áp dụng theo từng phòng. | `id: String`; `name: String`; `amount: Int`; `isActive: Boolean`; `note: String?` |

Mỗi khu trọ thuộc một Chủ trọ; mỗi phòng thuộc một khu trọ. Một phòng có thể chưa có hoặc có nhiều tài sản, phí dịch vụ và lịch kiểm tra. `Room.status` biểu diễn Trống, Đang thuê hoặc Bảo trì; `Room.isActive` biểu diễn phòng đang được sử dụng hay ngừng sử dụng trong quản lý. `Property.isArchived` là tình trạng lưu trữ khu trọ, không được đồng nhất với trạng thái của phòng.

`Room.basePrice` là giá phòng tham khảo; tiền thuê áp dụng theo hợp đồng nằm ở `Lease.monthlyRent`. `RoomServiceFee.amount` là số tiền của khoản phí; không đổi trường này thành `unitPrice`. Tình trạng tài sản được lưu bằng `RoomAsset.condition` kiểu chuỗi; không bổ sung một tập trạng thái chuẩn nếu chưa được thống nhất.

![CD-02 Khu trọ và phòng](class-diagrams/cd-02.png)

CD-02 — Tài sản, phí dịch vụ và lịch kiểm tra là ba loại dữ liệu riêng của phòng.

### 4.3 Hợp đồng và tiền cọc

Hợp đồng kết nối một phòng và một hồ sơ Người thuê. Lịch sử thay đổi và giao dịch tiền cọc giúp theo dõi diễn biến của hợp đồng mà không làm mất thông tin đã ghi nhận.

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `Lease`<br>Hợp đồng thuê | Liên kết một phòng với một hồ sơ Người thuê và ghi điều khoản thuê, tình trạng hiệu lực. | `id: String`; `startDate: DateTime`; `endDate: DateTime?`; `monthlyRent: Int`; `deposit: Int`; `status: LeaseStatus` |
| `LeaseChange`<br>Lịch sử thay đổi hợp đồng | Lưu loại thay đổi, giá trị trước và sau cùng thời điểm ghi nhận. | `id: String`; `changeType: String`; `previousValues: Json`; `newValues: Json`; `note: String?`; `createdAt: DateTime` |
| `DepositTransaction`<br>Giao dịch tiền cọc | Theo dõi giao dịch thu, hoàn, khấu trừ hoặc điều chỉnh cọc; không đồng nhất với tiền cọc thỏa thuận. | `id: String`; `type: DepositTransactionType`; `amount: Int`; `occurredAt: DateTime`; `note: String?` |

Mỗi hợp đồng có đúng một phòng và một hồ sơ Người thuê. Mỗi phòng và mỗi hồ sơ có thể có nhiều hợp đồng trong lịch sử, nên bội số tại đầu `Lease` là 0..*. Kiểm tra không cho lập thêm hợp đồng hiệu lực trên cùng một phòng là giới hạn khi xử lý nghiệp vụ, không thay bội số lịch sử thành 0..1. Chính sách nhiều hợp đồng hiệu lực của một Người thuê vẫn thuộc điểm PX-02 cần xác nhận.

`Lease.deposit` ghi tiền cọc thỏa thuận. `DepositTransaction` ghi từng lần thu, hoàn, khấu trừ hoặc điều chỉnh; không sử dụng trực tiếp tiền cọc thỏa thuận để khẳng định số cọc đã thu hoặc số dư cọc. Mỗi giao dịch cọc có một hợp đồng và một Chủ trọ. Mỗi thay đổi hợp đồng cũng có một hợp đồng và một Chủ trọ; `previousValues` và `newValues` lưu dữ liệu trước và sau dưới dạng `Json`.

![CD-03 Hợp đồng và tiền cọc](class-diagrams/cd-03.png)

CD-03 — Bội số phản ánh lịch sử hợp đồng; số hợp đồng hiệu lực được kiểm tra riêng theo trạng thái.

### 4.4 Hóa đơn và thanh toán

Nhóm này được chia thành ba sơ đồ để tách dữ liệu đầu vào tính tiền, kết quả thu tiền và cấu hình lập hóa đơn định kỳ. Các hộp tham chiếu đến Room, Lease, Tenant, User và Property là các lớp đã được định nghĩa ở những nhóm trước.

#### 4.4.1 Chỉ số và hóa đơn

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `MeterReading`<br>Chỉ số dịch vụ | Mỗi bản ghi lưu một loại dịch vụ điện hoặc nước của một phòng trong một kỳ. | `id: String`; `utilityType: UtilityType`; `billingMonth: DateTime`; `previousReading: Int`; `currentReading: Int`; `unitPrice: Int`; `usage: Int`; `amount: Int` |
| `Invoice`<br>Hóa đơn | Ghi các thành phần tiền và tình trạng thu tiền của một hợp đồng theo kỳ tính. | `id: String`; `billingMonth: DateTime`; `rentAmount: Int`; `electricityAmount: Int`; `waterAmount: Int`; `otherAmount: Int`; `totalAmount: Int`; `paidAmount: Int`; `status: InvoiceStatus`; `dueDate: DateTime?` |

Một bản ghi `MeterReading` chỉ lưu một loại dịch vụ, xác định bằng `utilityType`, cho một phòng trong một kỳ. Điện và nước cần hai bản ghi riêng. Các thuộc tính là `previousReading`, `currentReading`, `unitPrice`, `usage` và `amount`; không có bốn trường cũ mới riêng cho điện nước trong cùng bản ghi. Tổ hợp phòng, loại dịch vụ và kỳ được xác định duy nhất.

Mỗi hóa đơn liên kết trực tiếp với một hợp đồng, một phòng và một hồ sơ Người thuê. Tổ hợp hợp đồng và kỳ hóa đơn được xác định duy nhất. Các thành phần tiền gồm `rentAmount`, `electricityAmount`, `waterAmount`, `otherAmount`; `totalAmount` là tổng tiền và `paidAmount` là tiền đã ghi nhận thu. Không vẽ liên kết trực tiếp Invoice — MeterReading vì hóa đơn không lưu mã bản ghi chỉ số; việc đối chiếu chỉ số thực hiện theo phòng, loại dịch vụ và kỳ tính.

![CD-04A Chỉ số và hóa đơn](class-diagrams/cd-04a.png)

CD-04A — Bản ghi chỉ số và hóa đơn cùng liên quan đến phòng nhưng không có liên kết trực tiếp giữa hai lớp.

#### 4.4.2 Thanh toán và minh chứng

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `Payment`<br>Khoản thanh toán | Ghi tiền đã thu hoặc khoản đảo của một khoản thu; giữ liên kết với hóa đơn. | `id: String`; `amount: Int`; `method: PaymentMethod`; `type: PaymentType`; `paidAt: DateTime` |
| `PaymentProof`<br>Minh chứng thanh toán | Ghi thông tin Người thuê gửi để đối soát và quyết định duyệt; chưa đồng nghĩa tiền đã thu. | `id: String`; `amount: Int`; `method: PaymentMethod`; `status: PaymentProofStatus`; `submittedAt: DateTime`; `reviewedAt: DateTime?`; `reviewNote: String?`; `proofImageUrls: String[]` |

Mỗi khoản thanh toán thuộc một hóa đơn. Khoản thu thông thường có `type = PAYMENT`; khoản đảo có `type = REVERSAL` và liên kết tùy chọn đến khoản gốc bằng `reversalOfPaymentId`. Mỗi khoản gốc được liên kết tối đa một khoản đảo và mỗi khoản đảo liên kết tối đa một khoản gốc, nên quan hệ tự liên kết có bội số 0..1 ở cả hai đầu. Khoản đảo được ghi bằng số tiền âm để bù khoản gốc, không xóa khoản thu gốc.

Mỗi minh chứng thuộc một hóa đơn và một hồ sơ Người thuê; tài khoản duyệt là liên kết tùy chọn. Trạng thái Chờ duyệt không làm tăng `Invoice.paidAmount`. Khi được duyệt hợp lệ, hệ thống ghi khoản thu và cập nhật hóa đơn. Minh chứng không có trường mã khoản thanh toán được tạo, vì vậy không vẽ quan hệ trực tiếp PaymentProof — Payment. Việc hai dữ liệu cùng liên quan đến một hóa đơn không tạo ra liên kết một một giữa chúng.

![CD-04B Thanh toán và minh chứng](class-diagrams/cd-04b.png)

CD-04B — Phân biệt minh chứng gửi để đối soát với khoản thu đã được ghi nhận; thể hiện quan hệ tự liên kết khi đảo khoản thu.

#### 4.4.3 Cấu hình lập hóa đơn định kỳ

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `BillingAutomation`<br>Cấu hình lập hóa đơn định kỳ | Ghi bật tắt, ngày lập, ngày đến hạn và thông tin lần chạy theo khu trọ. | `id: String`; `isEnabled: Boolean`; `invoiceDay: Int`; `dueDay: Int`; `lastRunMonth: DateTime?`; `lastRunAt: DateTime?` |

Mỗi cấu hình thuộc một khu trọ và một Chủ trọ. Một khu trọ có thể chưa có cấu hình hoặc có tối đa một cấu hình, do mã khu trọ là duy nhất trong lớp này. `invoiceDay` và `dueDay` là ngày thiết lập để lập hóa đơn và xác định hạn thu; `lastRunMonth` và `lastRunAt` có thể chưa có trước lần chạy đầu tiên. Lớp này là cấu hình và thông tin lần chạy, không phải lớp hóa đơn và không có liên kết trực tiếp tới từng Invoice.

![CD-04C Lập hóa đơn định kỳ](class-diagrams/cd-04c.png)

CD-04C — Một khu trọ có tối đa một cấu hình lập hóa đơn định kỳ.

### 4.5 Bảo trì và chi phí

Yêu cầu bảo trì theo dõi sự cố và quá trình xử lý; khoản chi theo dõi số tiền vận hành. Hai dữ liệu có thể liên quan nhưng không mặc định mỗi yêu cầu bảo trì đã có khoản chi.

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `Expense`<br>Khoản chi vận hành | Lưu chi phí của khu trọ; có thể gắn thêm phòng và được liên kết từ yêu cầu bảo trì. | `id: String`; `category: ExpenseCategory`; `amount: Int`; `expenseDate: DateTime`; `title: String` |
| `MaintenanceTicket`<br>Yêu cầu bảo trì | Ghi sự cố, trạng thái, ngày xử lý và chi phí theo phòng, khu trọ; không có liên kết trực tiếp đến Tenant. | `id: String`; `title: String`; `status: MaintenanceStatus`; `priority: MaintenancePriority`; `reportedAt: DateTime`; `actualCost: Int?` |
| `MaintenanceComment`<br>Trao đổi bảo trì | Lưu nội dung phản hồi, ảnh và tác giả là tài khoản người dùng trong một yêu cầu bảo trì. | `id: String`; `body: String`; `authorRole: UserRole`; `imageUrls: String[]`; `createdAt: DateTime` |

Mỗi khoản chi có một Chủ trọ và một khu trọ; liên kết tới phòng là tùy chọn. Mỗi yêu cầu bảo trì có một Chủ trọ, một khu trọ và một phòng; liên kết tới khoản chi là tùy chọn. Cấu trúc hiện hành không đặt mã khoản chi là duy nhất trên yêu cầu bảo trì, nên một khoản chi có thể được 0..* yêu cầu bảo trì tham chiếu. Không tự đổi quan hệ này thành một một.

Yêu cầu bảo trì không có thuộc tính `tenantId` hoặc quan hệ trực tiếp đến `Tenant`. Người thuê có thể gửi yêu cầu thông qua phòng và hợp đồng của mình, nhưng hành vi này không tạo thêm một quan hệ lưu trữ. Mỗi phản hồi có một yêu cầu bảo trì và một tài khoản tác giả; nội dung phản hồi là `body`, ảnh đính kèm là `imageUrls` và vai trò người gửi được lưu ở `authorRole`.

![CD-05 Bảo trì và chi phí](class-diagrams/cd-05.png)

CD-05 — Yêu cầu bảo trì, trao đổi và khoản chi là các thực thể riêng; không bổ sung liên kết trực tiếp đến hồ sơ Người thuê.

### 4.6 Thông báo và nhật ký

Nhóm này phân biệt thông tin lượt gửi, dấu đã đọc và lịch sử thao tác. Các thông tin này không được gộp thành một lớp Notification nếu chưa có thực thể dữ liệu tương ứng.

| Lớp và tên nghiệp vụ | Trách nhiệm | Thuộc tính chính |
| --- | --- | --- |
| `NotificationRead`<br>Dấu đã đọc thông báo | Ghi mã thông báo đã đọc cho từng tài khoản; không phải quan hệ đến một lớp Notification riêng. | `id: String`; `notificationId: String`; `readAt: DateTime` |
| `NotificationDelivery`<br>Lượt gửi thông báo | Ghi người nhận, kênh, mục đích và kết quả gửi; các mã liên quan chưa khai báo quan hệ trực tiếp. | `id: String`; `landlordId: String`; `tenantId: String?`; `invoiceId: String?`; `channel: NotificationDeliveryChannel`; `purpose: String`; `recipient: String`; `status: NotificationDeliveryStatus`; `sentAt: DateTime?`; `errorCode: String?` |
| `AuditLog`<br>Nhật ký thao tác | Ghi người thực hiện, vai trò, phạm vi Chủ trọ và đối tượng được mô tả bằng loại cùng mã. | `id: String`; `actorRole: UserRole`; `action: String`; `resourceType: String`; `resourceId: String?`; `summary: String`; `createdAt: DateTime` |

`NotificationDelivery.recipient` là chuỗi địa chỉ hoặc thông tin người nhận, không phải `recipientId` liên kết đến User. Các trường `landlordId`, `tenantId` và `invoiceId` là tham chiếu bằng mã nhưng chưa có quan hệ cấu trúc khai báo. Sơ đồ ghi các trường mã và chú thích <<IDRef>>, không vẽ đường nối tới các lớp ngữ cảnh. Tham chiếu bằng mã định danh trong dữ liệu; không phải structural association UML.

`NotificationRead` chỉ có quan hệ cấu trúc đến tài khoản. `notificationId` là chuỗi nhận diện thông báo, có thể là mã thông báo được tổng hợp hoặc mã lượt gửi trong luồng đọc tin nhắn. Mặc dù một luồng sử dụng mã lượt gửi, lớp này không có quan hệ khai báo đến `NotificationDelivery`; không vẽ đường liên kết cấu trúc giữa hai lớp. Một tài khoản chỉ có tối đa một dấu đã đọc cho cùng một mã thông báo.

`AuditLog.actor` là tài khoản thực hiện; `AuditLog.landlord` là tài khoản xác định phạm vi Chủ trọ. Đây là hai vai trò liên kết khác nhau và đều tùy chọn; mỗi tài khoản có thể xuất hiện trong nhiều bản ghi theo từng vai trò. `resourceType` và `resourceId` mô tả đối tượng được tác động bằng loại và mã, không tạo quan hệ trực tiếp từ AuditLog đến mọi lớp nghiệp vụ.

![CD-06 Thông báo và nhật ký](class-diagrams/cd-06.png)

CD-06 — Tách quan hệ tài khoản của dấu đã đọc và nhật ký khỏi các tham chiếu theo mã của lượt gửi.

## 5 Các ràng buộc cần đọc cùng sơ đồ

| Mã | Ràng buộc hoặc ý nghĩa | Tác động đến cách hiểu |
| --- | --- | --- |
| CL-01 | Tài khoản và hồ sơ Người thuê là hai thực thể; liên kết tài khoản truy cập là tùy chọn và duy nhất. | Không tạo Tenant bắt buộc cho mọi User; không đồng nhất người quản lý hồ sơ với tài khoản của Người thuê. |
| CL-02 | Phòng có nhiều hợp đồng theo lịch sử. Xử lý lập hợp đồng kiểm tra phòng chưa có hợp đồng hiệu lực. | Bội số Room — Lease là 1 và 0..*, không phải 1 và 0..1. Đây là kiểm tra khi xử lý, không phải ràng buộc duy nhất tổng quát trên roomId. |
| CL-03 | Phòng và hồ sơ phải còn được sử dụng; khu trọ chưa lưu trữ khi lập hợp đồng. | Không rút gọn điều kiện thành “phòng Trống” khi chính sách trạng thái Bảo trì chưa thống nhất tại PX-02. |
| CL-04 | Tiền cọc thỏa thuận và giao dịch cọc được lưu riêng. | Thu, hoàn, khấu trừ và điều chỉnh là lịch sử giao dịch. Cách ghi nhận thu cọc khi lập hợp đồng cần chốt tại PX-03. |
| CL-05 | Một bản ghi chỉ số cho mỗi tổ hợp phòng, loại dịch vụ và kỳ. | Không gộp điện nước vào bốn trường của một MeterReading. Chênh lệch chỉ số tạo usage; usage nhân unitPrice tạo amount. |
| CL-06 | Một hóa đơn cho mỗi tổ hợp hợp đồng và kỳ. | Tính duy nhất áp dụng theo leaseId và billingMonth; không chuyển sang tính duy nhất toàn hệ thống theo tháng. |
| CL-07 | Minh chứng Chờ duyệt chưa là khoản thu. Duyệt hợp lệ mới ghi nhận thanh toán và cập nhật hóa đơn. | Không cộng tiền của PaymentProof đang PENDING vào paidAmount. Không suy ra quan hệ trực tiếp PaymentProof — Payment. |
| CL-08 | Một khoản thu gốc được đảo tối đa một lần trong luồng xử lý hiện hành; khoản đảo không được đảo tiếp. | Giữ khoản gốc, tạo khoản REVERSAL có amount âm và liên kết tới khoản gốc. |
| CL-09 | Mỗi khu trọ có tối đa một cấu hình lập hóa đơn định kỳ. | Bội số Property — BillingAutomation là 1 và 0..1, không phải một nhiều. |
| CL-10 | Một yêu cầu bảo trì có thể chưa gắn khoản chi; expenseId không được đặt duy nhất. | Một Expense có thể được nhiều yêu cầu tham chiếu ở mức cấu trúc. Nếu nghiệp vụ muốn một một, cần quyết định và thay đổi riêng. |
| CL-11 | Các mã ngữ cảnh trong lượt gửi và mã đối tượng trong nhật ký không phải toàn bộ là quan hệ cấu trúc. | Không vẽ đường liền chỉ dựa vào tên trường có hậu tố Id. |

## 6 Mô hình đối tượng minh họa

Ví dụ sau là dữ liệu giả định tại ngày 6 tháng 10 năm 2026, không được trích từ dữ liệu vận hành. Các mã như ct01, phongA01 và hopDong01 là ký hiệu rút gọn để đọc sơ đồ, không phải mã UUID hợp lệ. Sơ đồ chỉ chọn một số thuộc tính và liên kết; không sử dụng trực tiếp làm dữ liệu khởi tạo hoặc nội dung yêu cầu gửi lên hệ thống.

Một Chủ trọ quản lý Khu trọ A; phòng A01 đang có hợp đồng hiệu lực với một hồ sơ Người thuê đã liên kết tài khoản truy cập. Hợp đồng bắt đầu ngày 1 tháng 10 năm 2026, tiền thuê 3.000.000 đồng và tiền cọc thỏa thuận 0 đồng. Chọn cọc 0 trong ví dụ để không giả định quyết định đang chờ xác nhận ở PX-03.

| Đối tượng | Lớp | Giá trị hoặc liên kết quan trọng |
| --- | --- | --- |
| chuTro01 | User | role = LANDLORD; isActive = true |
| taiKhoanThue01 | User | role = TENANT; isActive = true |
| khuA | Property | name = Khu trọ A; landlord = chuTro01 |
| phongA01 | Room | name = A01; property = khuA; status = OCCUPIED; basePrice = 3.000.000 |
| hoSo01 | Tenant | landlord = chuTro01; user = taiKhoanThue01; isActive = true |
| hopDong01 | Lease | room = phongA01; tenant = hoSo01; monthlyRent = 3.000.000; deposit = 0; status = ACTIVE |
| chiSoDien01 | MeterReading | room = phongA01; utilityType = ELECTRICITY; billingMonth = 2026-10-01 |
| chiSoNuoc01 | MeterReading | room = phongA01; utilityType = WATER; billingMonth = 2026-10-01 |
| hoaDon01 | Invoice | lease = hopDong01; room = phongA01; tenant = hoSo01; totalAmount = 3.120.000; paidAmount = 2.000.000; status = PARTIAL |
| khoanThu01 | Payment | invoice = hoaDon01; amount = 2.000.000; method = BANK_TRANSFER; type = PAYMENT; paidAt = 2026-10-05 |
| minhChung01 | PaymentProof | invoice = hoaDon01; tenant = hoSo01; amount = 1.120.000; status = PENDING; submittedAt = 2026-10-06 |

![OD-01 Đối tượng tài khoản và hợp đồng](class-diagrams/od-01.png)

OD-01 — Góc nhìn tài khoản, khu trọ, phòng, hồ sơ và hợp đồng của ví dụ giả định.

![OD-02 Đối tượng hóa đơn và thanh toán](class-diagrams/od-02.png)

OD-02 — Góc nhìn chỉ số, hóa đơn, khoản thu và minh chứng của cùng ví dụ; các hộp tham chiếu là cùng các đối tượng ở OD-01.

| Thành phần | Cách tính hoặc căn cứ | Số tiền đồng |
| --- | --- | --- |
| Tiền phòng | Tiền thuê tháng của hợp đồng | 3.000.000 |
| Tiền điện | (1.020 − 1.000) × 3.500 = 20 × 3.500 | 70.000 |
| Tiền nước | (25 − 20) × 10.000 = 5 × 10.000 | 50.000 |
| Khoản khác | Không phát sinh trong ví dụ | 0 |
| Tổng hóa đơn | 3.000.000 + 70.000 + 50.000 + 0 | 3.120.000 |
| Đã ghi nhận thu | Khoản thu khoanThu01 ngày 5 tháng 10 năm 2026 | 2.000.000 |
| Còn phải thu | 3.120.000 − 2.000.000 | 1.120.000 |
| Minh chứng Chờ duyệt | minhChung01 gửi để đối soát, chưa cộng vào tiền đã thu | 1.120.000 |

Tại thời điểm minh họa, hóa đơn vẫn ở trạng thái Thanh toán một phần vì chỉ có 2.000.000 đồng được ghi nhận thu. Minh chứng 1.120.000 đồng đang Chờ duyệt không làm hóa đơn chuyển thành Đã thanh toán. Kỳ 2026-10-01 biểu diễn tháng 10 năm 2026; ngày đến hạn của hóa đơn trong ví dụ là 10 tháng 10 năm 2026. Đây là ảnh chụp trạng thái, không phải biểu đồ trình tự duyệt minh chứng.

## 7 Liên hệ với đặc tả Use Case

Bảng dưới đây chọn các Use Case tiêu biểu đã có trong đặc tả để truy vết từ chức năng đến dữ liệu. Một Use Case có thể sử dụng nhiều nhóm lớp; bảng này không phân chia cứng trách nhiệm và không thay thế danh mục 67 Use Case.

| Nhóm dữ liệu | Use Case tiêu biểu | Lớp liên quan |
| --- | --- | --- |
| Tài khoản và hồ sơ | UC-SYS-01; UC-SYS-01.01; UC-SYS-02; UC-OPT-04.06; UC-TEN-01 | User, RefreshToken, Tenant, TenantInvite |
| Khu trọ và phòng | UC-OPT-02.01; UC-OPT-03.02; UC-OPT-03.07; UC-OPT-03.08; UC-OPT-03.09 | Property, Room, RoomAsset, RoomServiceFee, RoomInspection |
| Hợp đồng và tiền cọc | UC-OPT-05.02; UC-OPT-05.03; UC-OPT-05.04; UC-OPT-05.06; UC-TEN-02 | Lease, LeaseChange, DepositTransaction, Room, Tenant |
| Hóa đơn và thanh toán | UC-BIL-01; UC-BIL-02.01; UC-BIL-02.07; UC-BIL-03.01; UC-BIL-04; UC-TEN-04 | MeterReading, Invoice, BillingAutomation, Payment, PaymentProof |
| Bảo trì và chi phí | UC-OPT-06.01; UC-OPT-06.04; UC-BIL-05.02; UC-TEN-05.01; UC-TEN-05.02 | MaintenanceTicket, MaintenanceComment, Expense |
| Thông báo và nhật ký | UC-BIL-07.01; UC-BIL-07.02; UC-TEN-06; UC-ADM-02.04 | NotificationRead, NotificationDelivery, AuditLog, User |

## 8 Các điểm cần xác nhận và giới hạn

Mô hình mô tả cấu trúc hiện hành, không thay thế quyết định nghiệp vụ và không chứng nhận mọi xử lý đã được nghiệm thu. Các điểm dưới đây kế thừa mã PX trong đặc tả Use Case để tránh âm thầm chọn một cách diễn giải mới.

| Điểm | Nội dung cần xác nhận | Cách xử lý trong tài liệu này |
| --- | --- | --- |
| PX-01 | Có cho phép giá thuê 0 đồng hay không; yêu cầu nhập liệu và xử lý tiếp nhận chưa thống nhất. | Giữ monthlyRent kiểu Int; không tự đưa điều kiện lớn hơn 0 thành ràng buộc chung của lớp. Ví dụ sử dụng giá thuê dương. |
| PX-02 | Phòng Bảo trì có được lập hợp đồng không; một Người thuê có được nhiều hợp đồng hiệu lực không. | Giữ bội số lịch sử 0..*. Không tuyên bố phòng đủ điều kiện luôn phải là phòng Trống; không tự giới hạn Tenant — Lease thành một một. |
| PX-03 | Nhập tiền cọc khi lập hợp đồng là tiền cọc thỏa thuận hay khoản đã thực thu. | Mô hình giữ Lease.deposit riêng DepositTransaction. Xử lý hiện tại tạo khoản Thu cọc ban đầu nếu cọc dương; chính sách vẫn cần xác nhận. |
| PX-32 | Khi thay khu trọ của khoản chi nhưng giữ phòng cũ, chưa bảo đảm phòng còn thuộc khu trọ đã chọn. | Quan hệ riêng đến Property và Room chưa bảo đảm tính nhất quán giữa hai liên kết. Ghi nhận thiếu sót, không khẳng định đã sửa mã nguồn. |
| Quan hệ tham chiếu bằng mã | Có nâng các mã ngữ cảnh của lượt gửi thành quan hệ cấu trúc hay không. | Giữ chú thích <<IDRef>>, không vẽ đường nối và không gán bội số. Nếu bổ sung khóa ngoại, cần cập nhật mô hình sau thay đổi thiết kế. |
| Bảo trì và khoản chi | Có yêu cầu một khoản chi chỉ được gắn với một yêu cầu bảo trì hay không. | Chưa có ràng buộc duy nhất expenseId; giữ bội số 0..* ở đầu MaintenanceTicket. Không tự áp đặt quy tắc một một. |

Các lớp không có ngăn phương thức không có nghĩa hệ thống không có hành vi. Hành vi được phân tích trong đặc tả Use Case và biểu đồ tuần tự; nếu cần sơ đồ lớp thiết kế ở mức xử lý, phải lập một sơ đồ khác và chỉ bổ sung các phương thức có định nghĩa thực. Mô hình này không liệt kê toàn bộ quy tắc kiểm tra đầu vào, không mô tả chuyển trạng thái đầy đủ và không suy đoán chính sách chưa được chốt.

## 9 Nhật ký hiệu chỉnh mô hình cũ

Bảng ghi những thay đổi so với nội dung mục 2.4.3 trước lần triển khai này. Đây là hiệu chỉnh tài liệu, không phải danh sách thay đổi mã nguồn hoặc hiệu chỉnh lại 67 Use Case.

| Mã | Nội dung trước | Nội dung sau và lý do |
| --- | --- | --- |
| CD-HC-01 | RoomServiceFee có unitPrice. | Đổi thành amount kiểu Int, đúng thuộc tính khoản phí đang tồn tại. |
| CD-HC-02 | MeterReading có oldElectric, newElectric, oldWater, newWater. | Thay bằng utilityType, previousReading, currentReading, unitPrice, usage, amount và billingMonth; một bản ghi cho một loại dịch vụ. |
| CD-HC-03 | MaintenanceTicket có tenantId và quan hệ đến Tenant. | Bỏ thuộc tính và quan hệ không tồn tại; bổ sung liên kết thực đến User, Property, Room và Expense tùy chọn. |
| CD-HC-04 | MaintenanceComment sử dụng content. | Đổi thành body; giữ tác giả, vai trò tác giả và ảnh theo cấu trúc hiện hành. |
| CD-HC-05 | NotificationDelivery có recipientId và được nối đến User như người nhận. | Đổi thành recipient kiểu String; các mã landlordId, tenantId, invoiceId được thể hiện bằng chú thích <<IDRef>>, không vẽ đường nối, không gán bội số. |
| CD-HC-06 | Liên kết tài khoản của Tenant thể hiện một User bắt buộc. | Sửa quan hệ truy cập thành 0..1 ở cả hai đầu; tách rõ với quan hệ Chủ trọ quản lý hồ sơ. |
| CD-HC-07 | Quan hệ AuditLog chỉ thể hiện người thực hiện bắt buộc. | Tách actor và landlord, đều có bội số 0..1 tại đầu User; phân biệt tài khoản thực hiện và phạm vi Chủ trọ. |
| CD-HC-08 | Thiếu hộp RoomInspection, DepositTransaction, BillingAutomation và RefreshToken. | Bổ sung bốn lớp cùng thuộc tính và liên kết. RefreshToken trước đây chỉ được nhắc trong bảng diễn giải. |
| CD-HC-09 | Payment chưa thể hiện loại giao dịch và liên kết khoản đảo. | Bổ sung type, reversalOfPaymentId và quan hệ tự liên kết 0..1 — 0..1. |
| CD-HC-10 | Nhiều liên kết thực bị lược bỏ và bội số nhiều ghi chung là many. | Chuẩn hóa 39 quan hệ trong phạm vi; phân biệt 0..*, 0..1 và 1, gồm liên kết người duyệt, Chủ trọ, phòng, khu trọ và cấu hình định kỳ. |
| CD-HC-11 | Nhiều trạng thái, ngày và trường tùy chọn chỉ ghi String hoặc Date, không nêu tùy chọn. | Giữ đúng các kiểu enum, DateTime, Json và khả năng để trống; bảng và hình dùng quy ước tùy chọn thống nhất. |
| CD-HC-12 | Chưa có sơ đồ đối tượng và đối chiếu số tiền. | Bổ sung cùng một ví dụ giả định ở hai góc nhìn và bảng kiểm tra tổng hóa đơn, đã thu, còn phải thu; không dùng dữ liệu vận hành. |

## Phụ lục A Ma trận quan hệ cấu trúc

Bảng dưới liệt kê đủ 39 quan hệ trong phạm vi. “Nguồn trên một đích” là số đối tượng của lớp nguồn có thể liên kết với một đối tượng của lớp đích; “Đích trên một nguồn” đọc theo chiều ngược lại. Vai trò là tên liên kết từ lớp nguồn. Mỗi quan hệ chỉ liệt kê một lần dù cả hai lớp có thể xuất hiện trong nhiều hình. Ba trường IDRef của NotificationDelivery không nằm trong tổng 39 này.

| Lớp nguồn và vai trò | Lớp đích | Nguồn trên một đích | Đích trên một nguồn |
| --- | --- | --- | --- |
| `AuditLog.landlord` | `User` | 0..* | 0..1 |
| `AuditLog.actor` | `User` | 0..* | 0..1 |
| `Property.landlord` | `User` | 0..* | 1 |
| `Room.property` | `Property` | 0..* | 1 |
| `RoomAsset.room` | `Room` | 0..* | 1 |
| `RoomInspection.room` | `Room` | 0..* | 1 |
| `RoomServiceFee.room` | `Room` | 0..* | 1 |
| `Tenant.landlord` | `User` | 0..* | 1 |
| `Tenant.user` | `User` | 0..1 | 0..1 |
| `TenantInvite.landlord` | `User` | 0..* | 1 |
| `TenantInvite.tenant` | `Tenant` | 0..* | 1 |
| `Lease.room` | `Room` | 0..* | 1 |
| `Lease.tenant` | `Tenant` | 0..* | 1 |
| `DepositTransaction.lease` | `Lease` | 0..* | 1 |
| `DepositTransaction.landlord` | `User` | 0..* | 1 |
| `LeaseChange.lease` | `Lease` | 0..* | 1 |
| `LeaseChange.landlord` | `User` | 0..* | 1 |
| `NotificationRead.user` | `User` | 0..* | 1 |
| `MeterReading.room` | `Room` | 0..* | 1 |
| `Invoice.lease` | `Lease` | 0..* | 1 |
| `Invoice.room` | `Room` | 0..* | 1 |
| `Invoice.tenant` | `Tenant` | 0..* | 1 |
| `PaymentProof.invoice` | `Invoice` | 0..* | 1 |
| `PaymentProof.tenant` | `Tenant` | 0..* | 1 |
| `PaymentProof.reviewedBy` | `User` | 0..* | 0..1 |
| `Payment.invoice` | `Invoice` | 0..* | 1 |
| `Payment.reversalOfPayment` | `Payment` | 0..1 | 0..1 |
| `BillingAutomation.landlord` | `User` | 0..* | 1 |
| `BillingAutomation.property` | `Property` | 0..1 | 1 |
| `Expense.landlord` | `User` | 0..* | 1 |
| `Expense.property` | `Property` | 0..* | 1 |
| `Expense.room` | `Room` | 0..* | 0..1 |
| `MaintenanceTicket.landlord` | `User` | 0..* | 1 |
| `MaintenanceTicket.property` | `Property` | 0..* | 1 |
| `MaintenanceTicket.room` | `Room` | 0..* | 1 |
| `MaintenanceTicket.expense` | `Expense` | 0..* | 0..1 |
| `MaintenanceComment.ticket` | `MaintenanceTicket` | 0..* | 1 |
| `MaintenanceComment.author` | `User` | 0..* | 1 |
| `RefreshToken.user` | `User` | 0..* | 1 |

## Phụ lục B Danh mục kiểu liệt kê

Các giá trị dưới đây giữ nguyên để đối chiếu, không tự bổ sung trạng thái mới. Một số trường như purpose, changeType hoặc condition là chuỗi trong mô hình hiện hành, không được chuyển thành enum chỉ vì có thể đặt tên một nhóm giá trị.

| Kiểu liệt kê | Giá trị hiện hành |
| --- | --- |
| UserRole | LANDLORD, ADMIN, TENANT, STAFF |
| RoomStatus | OCCUPIED, VACANT, MAINTENANCE |
| LeaseStatus | ACTIVE, ENDED |
| UtilityType | ELECTRICITY, WATER |
| InvoiceStatus | UNPAID, PARTIAL, PAID, CANCELLED |
| PaymentMethod | CASH, BANK_TRANSFER, OTHER |
| PaymentType | PAYMENT, REVERSAL |
| PaymentProofStatus | PENDING, APPROVED, REJECTED |
| NotificationDeliveryChannel | ZALO |
| NotificationDeliveryStatus | PENDING, SENT, FAILED, SKIPPED |
| DepositTransactionType | COLLECTED, REFUNDED, DEDUCTED, ADJUSTMENT |
| ExpenseCategory | REPAIR, UTILITIES, INTERNET, CLEANING, FURNITURE, SALARY, TAX, OTHER |
| MaintenanceStatus | OPEN, IN_PROGRESS, DONE, CANCELLED |
| MaintenancePriority | LOW, MEDIUM, URGENT |

## Phụ lục C Căn cứ đối chiếu và phiên bản

Ngày lập tài liệu: 6 tháng 10 năm 2026. Các căn cứ kỹ thuật được đặt ở phụ lục để phần chính tập trung vào mô hình và ý nghĩa nghiệp vụ. Tài liệu không chứa dữ liệu cá nhân vận hành, mật khẩu hoặc mã thông báo phiên thực tế.

| Căn cứ | Vị trí và nội dung đối chiếu |
| --- | --- |
| Cấu trúc dữ liệu | `backend/prisma/schema.prisma:1` — 25 mô hình, 14 enum; lựa chọn 23 lớp, loại StaffProfile và StaffInvite khỏi phạm vi báo cáo. |
| Tạo hợp đồng | `backend/src/leases/leases.service.ts:85` — phạm vi quản lý, phòng và hồ sơ đang sử dụng, khu trọ chưa lưu trữ, phòng chưa có hợp đồng hiệu lực; ghi cọc ban đầu khi cọc dương. |
| Chỉ số và hóa đơn | `backend/src/billing/billing.service.ts:215` và `:279` — ghi chỉ số, chênh lệch, đơn giá, tìm chỉ số theo phòng và kỳ; các thành phần tiền hóa đơn. |
| Duyệt và đảo khoản thu | `backend/src/billing/billing.service.ts:1057` và `:1163` — duyệt minh chứng ghi khoản thu, cập nhật tiền đã thu; tạo giao dịch đảo có amount âm và mã khoản gốc. |
| Thông báo đã đọc | `backend/src/notifications/notifications.service.ts:58`; `backend/src/tenant-portal/tenant-portal.service.ts:246` và `:322` — đọc theo mã thông báo; luồng tin nhắn dùng deliveryId làm notificationId. |
| Điểm chưa thống nhất | `Rental_room_management/docs/ba/USE_CASE_SPECIFICATION.md` — PX-01, PX-02, PX-03 và PX-32. Không đưa các quyết định còn mở thành quy tắc đã chốt. |

Dấu vân tay SHA256 của tệp cấu trúc đã đối chiếu: `a09a28988b7c6d9872328658cd1b37fd32548a1a0b11cfdc3ee58845f0ac0ec5`. Nếu cấu trúc dữ liệu thay đổi sau thời điểm này, cần cập nhật hình, bảng thuộc tính và ma trận quan hệ cùng nhau.

Gói tài liệu đi kèm gồm bản Markdown, bản Word độc lập của mục 2.4.3, 11 ảnh PNG, 11 ảnh SVG, 11 tệp nguồn PlantUML và một tệp draw.io gồm 11 trang. Tệp class-model.json lưu danh mục lớp và quan hệ; diagram-manifest.json lưu bố cục và kết quả dựng hình. Các tệp nguồn sơ đồ được cung cấp để tiếp tục chỉnh sửa, không chỉ có ảnh chụp.

## 10 Hiệu chỉnh trình bày ngày 7 tháng 10 năm 2026

Bản hiệu chỉnh giữ 23 lớp và 39 association cấu trúc. Bỏ FK trùng association khỏi hình, lược tokenHash khỏi thuộc tính báo cáo, bổ sung thành phần tiền hóa đơn và danh sách ảnh minh chứng. Các ràng buộc unique có căn cứ được ghi trên hình; nhãn liên kết là tên vai trò từ lớp nguồn, còn PlantUML ghi tên vai trò tại các đầu association. Các lớp nhắc lại dùng cùng tên và thuộc tính của cùng classifier. CD-05 đặt Expense dưới MaintenanceTicket và dùng các tuyến nối không giao nhau; CD-06 dùng chú thích <<IDRef>>, không còn connector tham chiếu ID. Các nhãn bội số và vai trò trong Draw.io gắn với connector tương ứng.

Một Expense được phép có nhiều MaintenanceTicket ở mức schema vì expenseId không unique. Luồng complete hiện tạo khoản chi mới, không cung cấp thao tác chọn một Expense đã tồn tại để chia sẻ. Việc cho phép chia sẻ khoản chi và đồng bộ actualCost với Expense.amount vẫn cần xác nhận, không được suy ra từ structural multiplicity. Các điểm PX-01, PX-02, PX-03, PX-14, PX-19, PX-24, PX-25, PX-26 và PX-32 không bị quyết định thay trong lần hiệu chỉnh này.

Xem `CLASS_DIAGRAM_AUDIT.md` để tra ma trận 39 quan hệ, 3 IDRef, danh sách 23 lớp, changelog, cấu trúc 11 hình và checklist. Không thay schema, code hay đặc tả Use Case.
