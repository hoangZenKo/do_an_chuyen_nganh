INTRO = [
('1.1 Đặt vấn đề',[
'Quản lý nhà trọ là một chuỗi hoạt động liên kết từ công bố phòng còn cho thuê, tiếp nhận người tìm phòng, lập lịch xem, xác lập hợp đồng, bàn giao đến thu tiền và kết thúc quá trình thuê. Khi một chủ trọ có nhiều khu và nhiều phòng, dữ liệu không chỉ là danh sách phòng mà còn gồm lịch sử giá, người ở, hóa đơn, chứng từ, tiền cọc và công việc vận hành. Một sai lệch tại khâu hợp đồng hoặc thanh toán có thể lan sang báo cáo và quyết toán.',
'Việc sử dụng đồng thời sổ tay, bảng tính và tin nhắn tạo ra nhiều bản ghi không thống nhất. Người quản lý phải tự nhớ phiên bản giá có hiệu lực, kỳ đã lập hóa đơn và khoản tiền đã nhận nhưng chưa phân bổ. Ở chiều ngược lại, người thuê cần xem được hóa đơn của mình, biết chứng từ đang chờ duyệt hay đã chấp thuận, gửi yêu cầu bảo trì và theo dõi yêu cầu gia hạn, chuyển phòng hoặc trả phòng.',
'Bài toán còn có một tầng quản trị nền tảng. Admin cần quản lý tài khoản, kiểm duyệt tin và đánh giá, xử lý hồ sơ hỗ trợ, giám sát sự cố và kiểm tra nhật ký, nhưng không vì thế được phép sửa tùy ý sổ tài chính của từng chủ trọ. Nhân viên vận hành cũng chỉ nên thao tác trong khu trọ được phân công. Do đó, role, permission, property scope và ownership phải được kiểm tra đồng thời ở máy chủ.',
'Đồ án Rental Room Management xây dựng một hệ thống mobile-first dùng Flutter kết nối REST API NestJS và cơ sở dữ liệu PostgreSQL. Báo cáo này mô tả trạng thái mã nguồn được đối chiếu ngày 28/10/2026. Số lượng UC, mô hình và endpoint là số kiểm kê của snapshot làm việc hiện tại, không phải số tính năng đã nghiệm thu production hoặc tuyên bố về số người dùng thực tế.'
]),
('1.2 Các giải pháp đã có',[
'Các phương án nền được xem xét gồm sổ sách, bảng tính, trao đổi qua tin nhắn và một ứng dụng quản lý tập trung. Phần này so sánh cách tổ chức dữ liệu và luồng xử lý, không khẳng định một sản phẩm thương mại cụ thể thiếu tính năng khi chưa có khảo sát độc lập.',
'Sổ sách phù hợp quy mô rất nhỏ nhưng khó truy vấn chéo giữa phòng, người thuê và công nợ. Bảng tính hỗ trợ công thức, lọc và tổng hợp, song quyền truy cập thường không gắn trực tiếp với từng hợp đồng và thao tác đồng thời dễ làm thay đổi lịch sử. Tin nhắn nhanh và quen thuộc nhưng không thay thế được một sổ giao dịch có định danh, trạng thái xử lý và ràng buộc toàn vẹn.',
'Giải pháp tập trung của đồ án không nhằm thay thế mọi công cụ kế toán hoặc nền tảng thanh toán. Giá trị hướng tới là duy trì một nguồn dữ liệu nghiệp vụ nhất quán, cho phép từng tác nhân làm việc theo đúng vai trò, đồng thời gắn kết các bước tìm phòng, vận hành và tự phục vụ của người thuê. Các yêu cầu ngân hàng thật, ký số pháp lý và phát hành hóa đơn thuế không nằm trong mức xác nhận hiện tại.'
]),
('1.3 Giải pháp đề xuất',[
'Hệ thống được tổ chức theo mô hình client–server. Flutter chịu trách nhiệm hiển thị và tương tác; Riverpod quản lý trạng thái và phụ thuộc, GoRouter điều hướng theo phiên, Dio gửi yêu cầu và xử lý làm mới token. NestJS gom các phân hệ trong một modular monolith; Prisma định nghĩa mô hình và truy cập PostgreSQL. Đây không phải kiến trúc microservices chỉ vì source chia thành nhiều module.',
'Bốn vai trò lưu trong hệ thống là ADMIN, LANDLORD, TENANT và STAFF. Khách chưa đăng nhập chỉ xem tài nguyên công khai; người tìm phòng dùng tài khoản TENANT trước khi có hồ sơ thuê. Sau khi hồ sơ User–Tenant được liên kết, người thuê truy cập portal của mình. Staff là tài khoản được chủ trọ giao quyền và khu quản lý, không phải một Admin rút gọn.',
'Luồng nghiệp vụ cốt lõi bắt đầu từ khu trọ và phòng, sau đó hình thành hồ sơ người thuê và hợp đồng. Hóa đơn được tạo theo kỳ và lưu các dòng giá có nguồn gốc; tiền nhận có thể ghi trực tiếp vào hóa đơn hoặc qua BillingReceipt để phân bổ. Công nợ, tiền chưa phân bổ, hoàn tiền, tiền cọc và quyết toán được tách thành các khái niệm khác nhau. Bảo trì và chi phí nối với vận hành nhưng không tự được coi là dòng tiền ngân hàng.',
'Mức hoàn thiện được đánh giá theo ba lớp: mã nguồn/contract có tồn tại, kiểm thử tự động đã chạy và nghiệm thu môi trường thực. Các chương sau giữ sự phân biệt này xuyên suốt. Trợ lý AI và cổng thẻ demo là các phần mở rộng có giới hạn quyền và môi trường, không làm thay đổi nguồn sự thật của sổ nghiệp vụ.'
])]

NFR = [
('NFR-01','Cách ly dữ liệu','Mỗi truy vấn quản lý phải ràng buộc chủ trọ; Staff phải có property scope, người thuê chỉ truy cập hồ sơ của mình.','Roles/Permissions guards, property-scope.ts và kiểm tra tại service. Không suy mức bao phủ từ riêng route guard.'),
('NFR-02','Bảo mật phiên','Token/phiên hết hiệu lực không được tiếp tục sử dụng; cache không lẫn giữa tài khoản.','JWT, AuthSession, refresh token luân chuyển; Flutter secure storage và session-identity tests.'),
('NFR-03','Toàn vẹn tài chính','Không tạo receipt, allocation, refund hoặc settlement lặp do retry; không làm âm số dư ngoài quy tắc.','BillingCommand, requestKey/hash, transaction và khóa tại các đường ghi tiền.'),
('NFR-04','Truy vết','Giao dịch và quyết định nhạy cảm có tác nhân, lý do, thời điểm và liên kết nguồn.','AuditLog, invoice timeline, revision/adjustment, moderation decision; mức bắt buộc audit tùy nghiệp vụ.'),
('NFR-05','Nhất quán dữ liệu','Thay đổi liên quan nhiều thực thể phải commit/rollback theo đơn vị nghiệp vụ.','Prisma transaction; repeatable-read ở các truy vấn thống kê được chỉ định; optimistic version/fingerprint.'),
('NFR-06','Khả dụng giao diện','Danh sách có loading, empty, error/retry; thao tác tài chính không báo thành công khi kết quả chưa rõ.','Kiểm thử widget/contract theo feature; 11 lỗi navigation Flutter được ghi rõ tại phần kiểm chứng.'),
('NFR-07','Khả năng tiếp cận','Nội dung tiếng Việt dễ đọc, thao tác dùng được trên màn hình hẹp và chữ lớn.','Ảnh widget có viewport/chữ lớn; đây chưa phải chứng nhận WCAG hoặc nghiệm thu mọi thiết bị.'),
('NFR-08','Hiệu năng có kiểm soát','Các endpoint có phân trang/giới hạn phải giữ thứ tự ổn định; không lấy preview thay danh sách đầy đủ.','Inventory đọc repeatable-read, preview 20 phòng, room limit tối đa 100; một số danh sách cũ còn giới hạn riêng.'),
('NFR-09','An toàn tệp','Tệp phải qua kiểm tra đầu vào và truy cập theo quyền; không lộ URL tĩnh của chứng từ riêng tư.','UploadsService, metadata UploadedFile và access endpoint; scanner/provider production chưa được xác nhận.'),
('NFR-10','Khôi phục và vận hành','Có migration/runbook/backup trước thay đổi dữ liệu; tình trạng worker được quan sát.','Các safety scripts, heartbeat, metric và incident; không coi unit test thay bằng chứng restore.'),
('NFR-11','Khả năng bảo trì','Module nghiệp vụ có contract rõ; thay đổi API phải nối đúng model/provider/UI/test.','Tổ chức lib/features, lib/data, lib/models và backend/src; ma trận truy vết trong phụ lục.'),
('NFR-12','Chất lượng thông tin','AI và báo cáo phải nêu đúng nguồn/phạm vi/thời điểm, không giả số khi thiếu dữ liệu.','Chatbot giới hạn LANDLORD; analytics trả definitions/asOf; giới hạn thu tiền của báo cáo được giải thích riêng.')
]

CONSTRAINTS = {
'2.3.1 Các ràng buộc về triển khai':[
'Frontend và backend ở chung repository nhưng chạy thành hai tiến trình riêng. Backend có prefix /api/v1; PostgreSQL là dịch vụ bên ngoài source. Việc dựng báo cáo không thực hiện migrate, seed, reset database hoặc bật worker gửi thông báo.',
'Flutter yêu cầu Dart SDK >=3.4.0 và <4.0.0 theo pubspec. Các constraint phụ thuộc trong manifest không phải phiên bản runtime đã kiểm chứng trên mọi thiết bị. Backend khai báo NestJS 10, Prisma 6 và TypeScript 5; môi trường PostgreSQL 16 được tài liệu dự án hướng dẫn. Cần khóa phiên bản và kiểm tra lockfile trước release.',
'Ảnh của báo cáo lấy từ widget test với dữ liệu fixture, hoặc ảnh kiểm thử có sẵn đã ghi nguồn. Không thay chúng bằng mockup để tuyên bố hệ thống đã chạy hoàn chỉnh. Tích hợp email/Zalo, storage, AI và scheduler chỉ hoạt động khi được cấu hình và nghiệm thu tương ứng.',
'Nhóm tác nhân Staff chịu một giới hạn quan trọng của snapshot: PropertyScopeInterceptor chỉ cho controller đã chuyển sang xử lý scope. Chức năng P1 operations, thông báo hoặc audit ngoài allowlist không được mặc định mở cho Staff dù decorator thể hiện permission. Luồng settlement và phê duyệt biểu phí chỉ dành chủ trọ.'
],
'2.3.2 Các ràng buộc kinh tế':[
'Chi phí tối thiểu gồm máy phát triển, thiết bị/simulator, dịch vụ PostgreSQL, nơi chạy backend, lưu trữ tệp và đường truyền. Chi phí thực tế phụ thuộc quy mô dữ liệu, lưu lượng và lựa chọn triển khai; repository không có chứng từ hoặc ngân sách đã phê duyệt để kết luận một số tiền thực chi.',
'Bảng ngân sách trong báo cáo là cấu trúc hạng mục cần dự toán, không phải hóa đơn hay dữ liệu đã chi. Nguồn lực ưu tiên cho tính đúng đắn tiền và quyền, sau đó mới đến mở rộng provider, native push và tối ưu phân tích ở quy mô lớn. Cổng thẻ mô phỏng được dùng để tránh phát sinh giao dịch tiền thật trong đồ án.'
],
'2.3.3 Các ràng buộc về đạo đức':[
'Dữ liệu thuê nhà có thể chứa danh tính, liên hệ, giấy tờ và chứng từ chuyển tiền. Báo cáo và môi trường demo chỉ dùng dữ liệu giả định hoặc dữ liệu đã được cho phép; ảnh minh họa không được làm lộ mật khẩu, token, mã MFA, giấy tờ hoặc thông tin ngân hàng cá nhân.',
'Khóa tài khoản, kiểm duyệt tin/đánh giá, từ chối chứng từ và giải quyết kháng nghị đều cần lý do và lịch sử. Sự hiện diện của Admin không hợp thức hóa việc truy cập PII không mục đích. Thông tin nhạy cảm cần được che mặc định và chỉ mở qua capability/hành động được ghi audit.',
'Nội dung AI chỉ hỗ trợ tra cứu. Khi chưa có dữ liệu, hệ thống phải nói rõ thay vì tạo số liệu. Không trình bày trạng thái hàng đợi là người dùng đã nhận thông báo, không trình bày hoàn tiền ghi sổ là ngân hàng đã chuyển, và không trình bày xác nhận bàn giao trong ứng dụng là chữ ký số pháp lý.'
]}

BUSINESS_RULES = [
('BR-01','Role không thay thế phạm vi','Staff phải có permission, đúng propertyIds và controller đã hỗ trợ scope. Tenant chỉ truy cập tài nguyên hồ sơ liên kết.'),
('BR-02','Hồ sơ khác tài khoản','Tenant là hồ sơ người thuê; User là danh tính đăng nhập. Người tìm phòng chưa có hợp đồng vẫn dùng role TENANT.'),
('BR-03','Phòng và tin đăng tách biệt','Room.basePrice dùng nội bộ; RoomListing.monthlyRent là giá quảng cáo. Kiểm duyệt tin không sửa hợp đồng đang thuê.'),
('BR-04','Hợp đồng và lịch sử','Lịch sử có nhiều Lease; dịch vụ chặn nhiều hợp đồng hiệu lực cho cùng một phòng. Ngày và trạng thái phải được kiểm tra khi ghi.'),
('BR-05','Hóa đơn giữ nguồn giá','InvoiceLineItem lưu loại, số lượng, đơn giá, nguồn và version liên quan; đổi biểu phí không sửa các dòng lịch sử.'),
('BR-06','Phát hành thay thế khác sửa tiền','Replacement hủy bản gốc và tạo revision; khi có lịch sử Payment phải dùng điều chỉnh đúng quy tắc.'),
('BR-07','Ghi nợ và giảm nợ','Credit/debit note bổ sung lịch sử; tỷ lệ tính trên tổng hóa đơn, credit không vượt số còn phải thu theo dịch vụ.'),
('BR-08','Khoản thu và phân bổ','BillingReceipt ghi tiền nhận; PaymentAllocation nối một phần tiền với một Invoice và Payment; chưa phân bổ chưa giảm nợ hóa đơn.'),
('BR-09','Không xóa để đảo tiền','Reversal là Payment âm nối khoản gốc; release trả phần khả dụng về Receipt, không phải chuyển tiền ra ngân hàng.'),
('BR-10','Giới hạn hoàn khoản thu','BillingRefund chỉ sử dụng tiền chưa phân bổ. Số tiền hoàn, lý do và tham chiếu được lưu; không có bank transfer tự động.'),
('BR-11','Proof chưa phải tiền','PaymentProof ở trạng thái PENDING không tăng paidAmount. Duyệt phải kiểm tra lại trạng thái và số dư dưới transaction.'),
('BR-12','Retry an toàn','RequestKey gắn nội dung lệnh; cùng key/cùng payload trả kết quả đã ghi, khác payload là xung đột ở luồng có BillingCommand.'),
('BR-13','Quyết toán và tiền cọc','Cọc, khoản phải thu, phí và hoàn trả được đối chiếu riêng. Preview/fingerprint không được bỏ qua ở lần confirm.'),
('BR-14','Duyệt khác thực thi','TenantLifecycleRequest APPROVED chưa đồng nghĩa Lease đã thay đổi; execute kiểm tra lại và ghi TenantLifecycleExecution.'),
('BR-15','Thông báo theo trạng thái','Job/queued, sent, failed, read và acknowledgement là các trạng thái khác nhau. Tùy chọn nhận tin của tenant phải được tôn trọng.'),
('BR-16','Số liệu kỳ và số liệu hiện tại','Invoices theo billingMonth; payments/expenses theo ngày phát sinh; active leases/occupancy và nợ hiện tại không phải snapshot lịch sử mặc định.'),
('BR-17','Dữ liệu demo cách ly','Cổng thẻ nội bộ chạy hóa đơn demo riêng; hóa đơn isDemo bị loại khỏi báo cáo thật.'),
('BR-18','Kiểm duyệt có phiên bản','Claim/assignment, version và lý do được kiểm tra; quyền inventory.view không phải quyền listings.moderate.'),
('BR-19','Đối soát tách nhiệm vụ','Maker tạo đề xuất; checker khác duyệt. Match receipt toàn khoản, không match từng PaymentAllocation độc lập.'),
('BR-20','Mức bằng chứng','Có code và unit test không thay thế E2E DB, kiểm tra thiết bị, provider, restore và nghiệm thu production.')
]

GLOSSARY = [
('Property','Khu trọ thuộc một chủ trọ; đơn vị phân công phạm vi cho Staff.'),('Room','Phòng vật lý; có trạng thái sử dụng, sức chứa và giá cơ sở.'),('RoomListing','Tin quảng cáo riêng của phòng; có trạng thái công khai và kiểm duyệt.'),('Tenant','Hồ sơ nghiệp vụ người thuê; liên kết User là tùy chọn.'),('Lease','Quan hệ thuê giữa phòng và hồ sơ người thuê cùng điều khoản theo thời gian.'),('Invoice','Hóa đơn kỳ có các dòng tiền và trạng thái số dư.'),('Payment','Khoản ghi vào một hóa đơn, gồm thu dương hoặc reversal âm.'),('BillingReceipt','Khoản tiền nhận của một người thuê, có phần khả dụng chưa phân bổ.'),('PaymentAllocation','Liên kết phân bổ tiền từ receipt sang invoice/payment.'),('BillingRefund','Ghi nhận khoản hoàn từ tiền chưa phân bổ, không chuyển khoản thật.'),('DepositTransaction','Lịch sử thu, hoàn hoặc khấu trừ tiền cọc gắn hợp đồng.'),('LeaseSettlement','Bản quyết toán trả phòng có snapshot, dòng đối chiếu và trạng thái hoàn.'),('Permission / Capability','Quyền cho thao tác; Admin dùng capability theo preset/policy, không đồng nhất ownership.'),('Property Scope','Các khu Staff được giao; scope rỗng không được hiểu là tất cả khu.'),('RequestKey','Khóa nhận diện lệnh retry ở các luồng có idempotency.'),('Version / Fingerprint','Dữ liệu kiểm soát đồng thời và chống xác nhận một snapshot đã cũ.'),('Outbox / Delivery','Sự kiện cần xử lý và kết quả gửi theo kênh; không phải bằng chứng người nhận đã đọc.'),('Read Model','Góc nhìn dữ liệu phục vụ đọc/phân tích; không phải mọi API analytics đã có materialized view.'),('SLA','Mốc và quy tắc xử lý công việc; hiệu quả thực phụ thuộc lịch và worker.'),('Fixture','Dữ liệu thử cố định để tái hiện giao diện hoặc hợp đồng API; không là dữ liệu vận hành thật.')
]

FR_GROUPS = [
('FR-SYS','Tài khoản và phiên','Đăng ký chủ trọ/người tìm phòng; đăng nhập và MFA Admin; khôi phục/luân chuyển phiên; đăng xuất, đổi mật khẩu và kích hoạt lời mời.','SYS'),
('FR-DIS','Khám phá và tiếp nhận thuê','Tìm/lọc tin, yêu thích, lưu tìm kiếm, lịch xem, quản lý tin, báo cáo vi phạm, đánh giá và bàn giao từ hành trình thuê.','DIS'),
('FR-OPT','Khu trọ và phòng','Dashboard dữ liệu thật, chọn khu, CRUD có điều kiện, archive/lifecycle, tài sản và phí phòng theo phiên bản.','OPT'),
('FR-TNT','Hồ sơ và hợp đồng','Hồ sơ, lời mời, lịch sử thuê, gia hạn/kết thúc, cọc, settlement, lifecycle execution và người ở cùng.','TNT'),
('FR-BIL','Tài chính vận hành','Chỉ số, preview/hóa đơn đơn lẻ/hàng loạt, adjustment/replacement, receipt/allocation/refund, tariffs, automation, expense và báo cáo.','BIL'),
('FR-OPS','Vận hành và thông báo','Bảo trì, phân công/SLA, action items, turnover, checklist định kỳ, announcement và delivery có giới hạn scope.','OPS'),
('FR-TEN','Tự phục vụ người thuê','Xem dữ liệu của mình, chứng từ, cổng demo, bảo trì, yêu cầu vòng đời, sở thích thông báo và trao đổi portal.','TEN'),
('FR-STF','Nhân viên và lịch sử','Lời mời/quản lý Staff của chủ trọ, scope theo khu, mô phỏng quyền và nhật ký có kiểm soát.','STF'),
('FR-ADM','Quản trị nền tảng','Tài khoản, MFA/step-up, inventory, moderation, access review, finance maker–checker, báo cáo Admin, xác minh chủ trọ/duyệt khu và gán gói sử dụng không ghi nhận doanh thu.','ADM'),
('FR-SUP','Hỗ trợ và quan sát vận hành','Support case/message/attachment/SLA, notification center, hàng đợi/sự cố và chatbot chỉ đọc theo quyền.','SUP')
]

QUALITY_SCENARIOS = [
('QT-01','Role + scope','Staff có permission nhưng không có khu được giao','Không trả toàn bộ dữ liệu chủ trọ; controller chưa hỗ trợ scope bị chặn.'),
('QT-02','Cache/session','Đổi từ tài khoản A sang B khi request A còn chạy','Không hiển thị dữ liệu hoặc kết quả mutation của A trong phiên B.'),
('QT-03','Cạnh tranh thuê','Hai yêu cầu cùng lập hợp đồng cho một phòng','Không tạo hai hợp đồng hiệu lực trái quy tắc; trạng thái phòng nhất quán.'),
('QT-04','Idempotency','Gửi lặp receipt/settlement/proof cùng requestKey','Không ghi trùng; khác nội dung với cùng khóa phải báo xung đột theo contract.'),
('QT-05','Phân bổ','Hai lệnh cùng phân bổ hết số dư receipt','Không availableAmount âm và không thu vượt công nợ invoice.'),
('QT-06','Hoàn tiền','Hoàn tiền đang được phân bổ','Bị từ chối; release trước; receipt/refund/payment giữ liên kết.'),
('QT-07','Biểu phí','Sửa giá ở kỳ đã khóa/phát hành','Không hồi tố hóa đơn; giữ snapshot giá; tác động phải phân biệt override.'),
('QT-08','Proof','Duyệt hai lần hoặc công nợ đổi trước review','Không tạo tiền trùng/vượt dư; lịch sử review chính xác.'),
('QT-09','Quyết toán','Dữ liệu thay đổi sau preview','Fingerprint mismatch dừng confirm; đọc lại rồi xác nhận.'),
('QT-10','Lifecycle','Chấp thuận transfer rồi phòng đích bị thuê','Execute kiểm tra lại, không chuyển một phần hoặc coi APPROVED là đã thực thi.'),
('QT-11','Inventory','Admin chỉ xem mở URL ghi trực tiếp','UI và API đều chặn; không lộ tenant/lease/financial fields.'),
('QT-12','Moderation','UUID trong tiêu đề bản ghi khác và bản đích cùng xuất hiện','Tìm UUID trúng chính xác ID; claim/version bảo vệ quyết định.'),
('QT-13','Maker–checker','Maker tự duyệt proposal sao kê','Bị từ chối; đối soát trên receipt, không trên các allocation con.'),
('QT-14','Demo separation','Thanh toán thử thành công','Chỉ dữ liệu isDemo đổi; báo cáo thật không cộng tiền thử.'),
('QT-15','Delivery','Provider/email/Zalo/scanner chưa có cấu hình','Không khẳng định đã gửi/đã quét; trạng thái lỗi/chờ được ghi đúng.'),
('QT-16','UI hẹp/chữ lớn','320–430 px và text scale lớn','Không tràn, thao tác đủ chạm; lỗi navigation hiện tại phải được xử lý trước acceptance.')
]

CHANGE_LOG = [
('Tác nhân','Bản dở mô tả ba vai trò chính, Staff ngoài mô hình lớp.','Bổ sung Staff có scope và người tìm phòng như trạng thái nghiệp vụ TENANT; khách công khai là tác nhân không có role.'),
('Use case','67 bảng UC gắn nhóm phân tích cũ.','132 đặc tả theo mục tiêu hiện tại, có tiền/hậu điều kiện, luồng chính/thay thế/ngoại lệ và căn cứ source.'),
('Cấu trúc chương','Tài liệu UC/class/sequence được dán vào làm heading cấp 1, phá thứ tự chương.','Đưa UC, sơ đồ và UI về 2.4.1–2.4.5; thêm triển khai/kiểm chứng dưới chương 2, giữ chương 3–5 của template.'),
('Mô hình lớp','Bản dở giới hạn 23 thực thể và 39 quan hệ theo tài liệu cũ.','Phân rã 18 sơ đồ lớp theo các miền nghiệp vụ chính; chỉ trình bày thực thể cần cho UC, không chép toàn bộ schema.'),
('Thanh toán','Tập trung Payment trực tiếp và proof.','Bổ sung BillingReceipt, PaymentAllocation, BillingRefund, command idempotency, replacement và credit/debit note.'),
('Hợp đồng','Tạo/gia hạn/kết thúc và cọc theo luồng cũ.','Bổ sung settlement preview/fingerprint/refund, yêu cầu vòng đời có review khác execute, occupants/capacity và bàn giao.'),
('Admin','Chủ yếu tổng quan và quản lý chủ trọ/khu.','Bổ sung capability/MFA/step-up, accounts/sessions, inventory read-only, moderation/QA/appeal, support, finance và schedule.'),
('Báo cáo','Nội dung cũ gợi ý UI hiển thị mọi cơ cấu report.','Phân biệt response API với widget thực có; CSV hiện copy clipboard; analytics chưa nối màn hình; tiền receipt chưa phân bổ nằm ngoài Payment ròng.'),
('Giao diện','Chưa có bằng chứng ảnh hiện trạng đủ các phần mới.','Dùng ảnh widget capture có nguồn/fixture, không dùng mockup thay ảnh nghiệm thu.'),
('Kết quả','Số liệu kiểm thử rải rác từ các mốc trước.','Dùng log chạy mới 28/10/2026: backend 672 đạt/7 bỏ qua; Flutter features+data 503 đạt/12 lỗi; build backend đạt.')
]
