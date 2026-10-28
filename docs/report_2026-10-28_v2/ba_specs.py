import re

# Each entry supplies a domain-specific success result and a legitimate alternative.
DETAILS = r'''
SYS-01|Tài khoản chủ trọ được tạo và phiên hợp lệ được lưu; mở không gian vận hành của chính tài khoản.|Nếu đã có tài khoản, người dùng chuyển sang đăng nhập, không tạo bản sao tài khoản.|Email và mật khẩu phải đáp ứng DTO; vai trò chủ trọ do máy chủ gán, không nhận quyền quản trị từ biểu mẫu.
SYS-02|Tạo tài khoản TENANT ở ngữ cảnh tìm phòng; chưa tự sinh hợp đồng hoặc hồ sơ đang thuê.|Chưa có hồ sơ thuê liên kết thì tiếp tục khám phá phòng, không truy cập dữ liệu thuê của người khác.|Thông tin đăng ký được kiểm tra như luồng tài khoản; liên kết hồ sơ thuê phải qua nghiệp vụ riêng.
SYS-03|Phiên truy cập mang đúng vai trò và quyền; mở màn hình phù hợp trạng thái thuê và xác thực.|Admin bị yêu cầu MFA phải hoàn tất bước xác minh trước khi tiếp tục luồng quản trị.|Không cho đăng nhập tài khoản bị vô hiệu; không suy ra quyền từ tên màn hình hoặc dữ liệu cục bộ.
SYS-04|Phiên còn hiệu lực được phục hồi hoặc token được luân chuyển thành công; yêu cầu đang chờ được thử lại có giới hạn.|Access token còn hợp lệ thì dùng phiên hiện tại; không thực hiện refresh không cần thiết.|Refresh phải dùng đúng phiên, thu hồi theo chính sách; chỉ một yêu cầu refresh được xử lý khi nhiều request cùng hết hạn.
SYS-05.1|Phiên hiện tại bị thu hồi; token và dữ liệu gắn danh tính được xóa khỏi thiết bị.|Người dùng quay lại trước khi chọn đăng xuất thì giữ phiên, không phát sinh lệnh thu hồi.|Chỉ thu hồi phiên của người dùng hiện tại; không dùng thao tác này để ngầm đăng xuất mọi thiết bị.
SYS-05.2|Phiên được chọn hoặc các phiên khác được thu hồi; danh sách thiết bị phản ánh kết quả đọc lại.|Nếu không có phiên khác, hiển thị danh sách rỗng và không tạo yêu cầu thu hồi giả.|Kiểm tra phiên đích thuộc người dùng; phiên đã hết hiệu lực không được khôi phục qua thao tác xem.
SYS-06|Yêu cầu phục hồi được tiếp nhận; token hợp lệ cho phép đổi mật khẩu đúng một lần.|Người dùng chưa nhận được thư có thể yêu cầu lại theo chính sách; trạng thái tiếp nhận không chứng minh email đã tới.|Không lộ việc email có tồn tại; token phải đúng mục đích, còn hạn và chưa sử dụng.
SYS-07|Mật khẩu mới được ghi theo chính sách; trạng thái phiên được cập nhật theo kết quả máy chủ.|Nếu người dùng không nhớ mật khẩu hiện tại, chuyển luồng khôi phục, không bỏ qua xác minh.|Kiểm tra mật khẩu hiện tại và chính sách mật khẩu mới; không ghi mật khẩu vào nhật ký.
SYS-08|Lời mời người thuê được chấp nhận; tài khoản liên kết đúng hồ sơ thuê được chỉ định.|Nếu email đã đăng ký hoặc hồ sơ đã có tài khoản, từ chối kích hoạt theo luồng này; không tự gộp tài khoản.|Token mời còn hạn, chưa dùng, đúng người nhận; không dùng lời mời làm quyền truy cập hồ sơ bất kỳ.
DIS-01|Hiển thị danh sách tin công khai đáp ứng bộ lọc và trang được yêu cầu.|Không có tin phù hợp thì hiển thị trạng thái rỗng; người dùng có thể bỏ bớt điều kiện rồi tìm lại.|Chỉ trả tin đủ điều kiện công khai; khoảng giá, cơ sở học, bán kính và trang phải theo contract truy vấn.
DIS-02|Hiển thị thông tin tin đăng, giá, phí và đánh giá công khai; không lộ hồ sơ thuê riêng.|Tin đã ẩn hoặc không còn công khai thì báo không thể xem; quay lại danh sách để chọn tin khác.|Không tự suy rằng chủ trọ đã xác minh, có tọa độ hoặc có phí giữ xe nếu dữ liệu không cung cấp.
DIS-03|Tin được thêm hoặc bỏ khỏi danh sách yêu thích của tài khoản hiện tại.|Tin đã lưu thì thao tác bỏ lưu; tải lại danh sách để phản ánh trạng thái mới.|Yêu cầu phải có phiên TENANT; trạng thái yêu thích gắn tài khoản, không dùng chung bộ nhớ giữa hai phiên.
DIS-04|Bộ lọc cá nhân được lưu hoặc cập nhật; cảnh báo được đọc trong phạm vi tài khoản.|Có thể tắt hoặc thay bộ lọc thay vì tạo thêm nhiều bộ lọc giống nhau.|Tiêu chí tìm phải hợp lệ; lưu bộ lọc không chứng minh tác vụ tìm khớp hoặc gửi thông báo đã chạy.
DIS-05|Bản nháp tin đăng được lưu cho phòng thuộc chủ trọ, chưa tự xuất hiện công khai.|Bản nháp hiện có được mở để sửa; thay đổi bản nháp không được coi là đã gửi xét duyệt.|Phòng phải thuộc người đăng; giá quảng cáo và giá cơ sở của phòng là hai thông tin khác nhau.
DIS-06|Tin chuyển sang trạng thái gửi duyệt hoặc bị ẩn theo hành động được xác nhận.|Chủ trọ có thể tiếp tục sửa bản nháp thay vì gửi; việc ẩn không đồng nghĩa xóa phòng.|Kiểm tra chủ sở hữu, version và trạng thái hiện tại; chỉ xét duyệt phù hợp mới dẫn tới công khai.
DIS-07|Báo cáo vi phạm gắn đúng tin và người gửi; đưa vào quy trình tiếp nhận kiểm duyệt.|Người dùng bổ sung nội dung phản ánh rồi gửi; không kết luận tin vi phạm chỉ từ một báo cáo.|Phiên TENANT hợp lệ, lý do thuộc tập hỗ trợ; dữ liệu báo cáo không được thay thế quyền phán quyết của Admin.
DIS-08|Khung giờ xem được lưu theo chủ trọ; người thuê đọc được các khung còn phù hợp.|Chủ trọ điều chỉnh hoặc đóng khung không còn tiếp nhận; người thuê chỉ chọn khung, không sửa lịch của chủ trọ.|Thời điểm, sức chứa và phạm vi phòng theo quy tắc lịch xem; không mặc định mọi khung đều còn chỗ.
DIS-09|Lịch xem được ghi cho người thuê và tin/phòng hợp lệ; hiển thị trạng thái theo dõi.|Khung đã hết chỗ thì chọn khung khác và kiểm tra lại trước khi gửi.|Yêu cầu đặt lịch thuộc tài khoản; tính khả dụng của khung phải được xác minh lại tại thời điểm ghi.
DIS-10|Yêu cầu đổi/hủy hoặc quyết định xử lý lịch xem được lưu, có phiên bản mới.|Người thuê hủy lịch thuộc mình; chủ trọ xác nhận/từ chối lịch thuộc phòng của mình theo trạng thái.|Phân biệt người yêu cầu với người xử lý; không tự coi lịch đã hoàn thành chỉ vì được xác nhận.
DIS-11|Lịch xem phù hợp được liên kết với hợp đồng mới; bàn giao là bước xác nhận riêng.|Nếu chưa đủ điều kiện lập hợp đồng, giữ lịch xem và hoàn thiện hồ sơ thuê trước.|Chỉ chủ trọ thực hiện chuyển đổi; kiểm tra phòng, người thuê và hợp đồng hiệu lực để tránh tạo thuê trùng.
DIS-12|Đánh giá của người thuê được tạo, sửa hoặc rút theo hợp đồng đủ điều kiện.|Người thuê có thể sửa đánh giá của mình hoặc rút thay vì tạo đánh giá thứ hai trái quy tắc.|Kiểm tra quan hệ thuê, thời điểm và quyền sở hữu đánh giá; không cho đánh giá bằng hợp đồng của người khác.
DIS-13|Phản hồi của chủ trọ hoặc ý kiến thử nghiệm được lưu đúng loại đối tượng.|Nếu đợt thử nghiệm đã đóng, chỉ xem nội dung hiện có; không mở biểu mẫu gửi mới.|Trả lời đánh giá cần đúng chủ trọ; phản hồi thử nghiệm không tự chuyển thành đánh giá công khai.
OPT-01|Dashboard hiển thị chỉ số và trạng thái phòng đúng khu; chọn phòng dẫn đến đúng bản ghi.|Khu chưa có phòng hiển thị trạng thái rỗng, không tự chèn phòng hoặc công nợ mẫu.|Chỉ số, vị trí phòng và đích điều hướng dùng dữ liệu thực của tài khoản; không lấy ghi chú làm dấu nợ.
OPT-02|Danh sách khu được tải theo chủ trọ; khu đang chọn được dùng cho các màn hình liên quan.|Đổi khu thì tải lại các dữ liệu phụ thuộc; không để kết quả chậm của khu cũ ghi đè khu mới.|Khu phải thuộc chủ trọ; bộ lọc hoạt động/lưu trữ không làm thay đổi chủ sở hữu.
OPT-03.1|Khu mới thuộc chủ trọ được tạo và xuất hiện trong danh sách.|Người dùng hủy biểu mẫu thì không tạo khu; có thể mở lại danh sách để chọn khu đã có.|Tên, địa chỉ theo DTO; kiểm tra điều kiện tăng inventory và hạn gói trước khi ghi.
OPT-03.2|Tên và địa chỉ được cập nhật ở khu đích, không chuyển quyền sở hữu.|Người dùng không thay đổi dữ liệu thì quay lại; không phát sinh khu mới.|Chỉ nhận các trường được phép sửa; không dùng form khu để cập nhật tài chính hoặc xét duyệt.
OPT-04.1|Khu chuyển sang lưu trữ, phòng và lịch sử được bảo toàn.|Có hợp đồng đang hiệu lực thì xử lý nghiệp vụ thuê trước, không cưỡng ép lưu trữ.|Lưu trữ là đổi isArchived, không phải xóa; kiểm tra lại hợp đồng ACTIVE ở máy chủ.
OPT-04.2|Khu đã lưu trữ được khôi phục khi hạn mức khu và phòng cho phép.|Gói không cho tăng inventory thì giữ khu ở trạng thái lưu trữ và thông báo điều kiện cần xử lý.|Đếm cả phòng hoạt động được đưa lại inventory; không tự xóa phòng để đạt hạn mức.
OPT-04.3|Khu chưa có phòng và không có hợp đồng hiệu lực được xóa.|Nếu còn phòng, người dùng quay lại quản lý dữ liệu; không cascade xóa để đạt điều kiện.|Phải kiểm tra phụ thuộc tại thời điểm yêu cầu, không chỉ dựa vào danh sách hiển thị trước đó.
OPT-05|Hiển thị dữ liệu phòng và các lịch sử người dùng được quyền xem.|Có thể đổi khu, tìm theo tên hoặc mở lại phòng khác trong danh sách.|Lịch sử phòng phải gắn đúng ID; quyền xem phòng không đồng nghĩa được xem mọi dữ liệu người thuê.
OPT-06.1|Phòng mới được tạo trong khu đang hoạt động và thuộc chủ trọ.|Khu đã lưu trữ thì khôi phục khu theo điều kiện trước khi tạo phòng.|Không cho tự tạo phòng ở trạng thái OCCUPIED khi chưa có hợp đồng; giá và sức chứa theo DTO.
OPT-06.2|Các thông tin cho phép của phòng được lưu; hợp đồng và hóa đơn cũ không bị sửa theo.|Nếu phòng đã vô hiệu, cần xử lý vòng đời phòng trước khi chỉnh thông tin.|Không coi đổi basePrice là sửa điều khoản thuê hiện hành; trạng thái phải phù hợp hợp đồng.
OPT-07.1|Phòng chuyển giữa các trạng thái được phép, nhất quán với hợp đồng hiệu lực.|Phòng đang quy trình trả phòng chỉ được chuyển theo quy tắc hiện tại; không cho thuê lại sớm.|Không đặt trống khi còn hợp đồng ACTIVE; không đặt OCCUPIED nếu chưa có hợp đồng hiệu lực.
OPT-07.2|Phòng bị vô hiệu hoặc được khôi phục; lịch sử thuê vẫn giữ nguyên.|Khu đang lưu trữ thì không khôi phục phòng; phải xử lý khu trước.|Vô hiệu bị chặn nếu có hợp đồng ACTIVE; khôi phục phải kiểm tra điều kiện tăng inventory.
OPT-07.3|Phòng chưa có lịch sử nghiệp vụ được xóa khỏi danh sách.|Có lịch sử thuê/chỉ số/hóa đơn/lịch xem/turnover thì chọn vô hiệu thay vì xóa lịch sử.|Không xóa phòng bằng cách xóa ngầm bản ghi phụ thuộc; kiểm tra lại tại dịch vụ.
OPT-08.1|Tài sản được tạo/sửa/xóa hoặc tra cứu đúng phòng; danh sách được cập nhật.|Có thể sửa tình trạng tài sản đang có thay vì thêm tài sản trùng mục đích.|Tên, số lượng, giá trị và ngày mua theo DTO; tài sản đích phải thuộc phòng trong quyền quản lý.
OPT-08.2|Lịch hoặc kết quả kiểm tra hiện trạng phòng được lưu và truy xuất theo thời gian.|Lịch chưa hoàn thành có thể được cập nhật theo hành động hỗ trợ; không tự coi đã nghiệm thu.|Mốc kiểm tra và nội dung gắn đúng phòng; ghi kiểm tra không tự tạo chi phí hoặc sửa hợp đồng.
OPT-09|Phiên bản phí dịch vụ được lưu với kỳ hiệu lực; dữ liệu lịch sử được giữ.|Kỳ đã lập hóa đơn hoặc khóa thì chọn kỳ tiếp theo thay vì sửa hồi tố.|Phân biệt cấu hình phí tại phòng và đề xuất biểu phí có quy trình duyệt; không tự sửa hóa đơn đã phát hành.
TNT-01|Danh sách và tổng quan người thuê trong phạm vi chủ trọ được hiển thị.|Không có hồ sơ phù hợp thì đổi bộ lọc; không coi hồ sơ thuê là tài khoản đăng nhập.|Dữ liệu nhận diện chỉ được trả trong phạm vi sở hữu; trạng thái thuê được đối chiếu từ hợp đồng.
TNT-02.1|Hồ sơ người thuê được tạo thuộc chủ trọ, chưa tự có phiên đăng nhập.|Nếu đã có hồ sơ phù hợp, chọn hồ sơ cũ để tiếp tục lập hợp đồng.|Thông tin cá nhân theo DTO; quan hệ User–Tenant là liên kết riêng và có thể chưa tồn tại.
TNT-02.2|Thông tin hồ sơ được cập nhật mà không thay lịch sử hợp đồng/thu tiền.|Chỉ thay các trường cần sửa; nếu cần đổi người đứng hợp đồng thì dùng nghiệp vụ hợp đồng tương ứng.|Kiểm tra chủ sở hữu và trường được sửa; không đổi tài khoản liên kết bằng ID tùy ý trên form.
TNT-02.3|Hồ sơ chuyển trạng thái hoạt động theo điều kiện, không xóa lịch sử thuê.|Hồ sơ còn nghiệp vụ đang hiệu lực cần được giải quyết trước khi vô hiệu.|Trạng thái tài khoản đăng nhập và trạng thái hồ sơ nghiệp vụ không được đồng nhất.
TNT-02.4|Hồ sơ chưa phát sinh lịch sử được xóa khi dịch vụ cho phép.|Hồ sơ đã có hợp đồng hoặc chứng từ thì giữ lịch sử và dùng trạng thái thay thế phù hợp.|Không xóa hợp đồng, tiền cọc hoặc hóa đơn theo để hợp thức hóa thao tác xóa người thuê.
TNT-03|Lời mời portal gắn đúng hồ sơ người thuê được phát hành hoặc tiếp nhận theo delivery.|Lời mời chưa được nhận thì theo dõi trạng thái và gửi lại theo chính sách; không coi đã kích hoạt.|Chủ trọ chỉ mời vào hồ sơ của mình; liên kết được xác nhận bằng token và danh tính người nhận.
TNT-04|Hiển thị hợp đồng, trạng thái và cảnh báo thời hạn theo dữ liệu hiện có.|Đổi bộ lọc đang thuê/đã kết thúc hoặc thời gian để xem lịch sử.|Cảnh báo sắp hết hạn không tự gia hạn hoặc kết thúc hợp đồng.
TNT-05|Hợp đồng mới và giao dịch cọc ban đầu hợp lệ được ghi; phòng chuyển trạng thái tương ứng.|Nếu chưa có hồ sơ người thuê thì tạo/chọn hồ sơ trước; không nhập tên thay quan hệ thuê.|Kiểm tra phòng còn khả dụng, sức chứa, ngày thuê, tiền thuê/cọc; tránh hai hợp đồng hiệu lực trái quy tắc.
TNT-06.1|Điều khoản được cập nhật và truy vết theo dịch vụ, không sửa tiền đã ghi nhận trước đó.|Chỉ sửa trường được phép ở trạng thái hiện tại; cần trả phòng thì chuyển luồng quyết toán.|Phân biệt thay giá hợp đồng với thay giá cơ sở hoặc biểu phí; kiểm tra dữ liệu liên quan.
TNT-06.2|Ngày kết thúc mới hợp lệ được lưu; danh sách/cảnh báo cập nhật theo thời hạn mới.|Yêu cầu gia hạn từ người thuê có thể được duyệt và thực thi qua lifecycle thay vì sửa trực tiếp.|Hợp đồng và mốc ngày phải đáp ứng quy tắc; không tự tạo thêm kỳ hóa đơn chỉ vì gia hạn.
TNT-06.3|Hợp đồng kết thúc và trạng thái phòng được cập nhật khi không còn hợp đồng hiệu lực.|Có nhu cầu đối chiếu công nợ/cọc thì dùng quyết toán trả phòng trước khi xác nhận nghiệp vụ.|Kết thúc hợp đồng không đồng nghĩa đã thu đủ tiền hoặc đã chuyển hoàn cọc qua ngân hàng.
TNT-07|Giao dịch cọc được lưu theo loại và thời điểm; số dư được tính từ lịch sử.|Chỉ tra cứu thì không ghi thêm giao dịch; hoàn/khấu trừ phải đúng hành động được xác nhận.|Không sửa số dư bằng cách xóa lịch sử; không cộng tiền cọc vào doanh thu tiền thuê.
TNT-08|Preview được xác nhận với fingerprint đúng; quyết toán, dòng tiền liên quan và trạng thái thuê được lưu nhất quán.|Thay ngày/chỉ số/phí sau preview thì phải chạy lại; không xác nhận snapshot cũ.|Chỉ chủ trọ xác nhận; kiểm tra lại dữ liệu đang khóa; xác nhận quyết toán không tự chuyển tiền hoàn.
TNT-09|Khoản tiền thực tế đã hoàn được ghi vào quyết toán, có tham chiếu và lịch sử.|Quyết toán không còn khoản phải hoàn thì không tạo lệnh hoàn giả.|Chỉ ghi trong giới hạn còn phải hoàn; thao tác ghi sổ không phải lệnh chuyển tiền ngân hàng.
TNT-10|Yêu cầu lifecycle được chấp thuận/từ chối với version và lý do.|Có thể từ chối khi phòng đích không phù hợp; APPROVED vẫn chưa thay đổi hợp đồng.|Kiểm tra yêu cầu thuộc chủ trọ và còn trạng thái chờ; không gộp review với execute.
TNT-11|Yêu cầu đã duyệt được thực thi; hợp đồng/phòng và bản ghi execution nhất quán.|Phòng đích đổi trạng thái sau duyệt thì dừng thực thi, xem lại dữ liệu thay vì chuyển một phần.|Kiểm tra lại toàn bộ điều kiện lúc execute; chống thực thi lặp theo contract của dịch vụ.
TNT-12.1|Danh sách người ở cùng được cập nhật, có lịch sử trạng thái và không vượt sức chứa.|Người ở rời phòng thì kết thúc trạng thái tương ứng thay vì xóa lịch sử thuê.|Khóa/kiểm tra hợp đồng và sức chứa tại thời điểm ghi; không coi mọi người ở là tài khoản đăng nhập.
TNT-12.2|Biên bản được lưu theo version; người thuê xác nhận đúng nội dung được xem.|Chủ trọ sửa sau khi lưu thì tạo version mới; người thuê phải đọc lại trước xác nhận.|Người thuê chỉ xác nhận biên bản của mình; không tự coi thao tác này là chữ ký số pháp lý.
TNT-13|Hợp đồng PDF được dựng và mở/chia sẻ theo nền tảng; dữ liệu hợp đồng không thay đổi.|Thiết bị không hỗ trợ chia sẻ thì thông báo giới hạn và giữ nguyên hợp đồng.|Chỉ xuất dữ liệu được quyền xem; không mô tả file PDF là hợp đồng có chữ ký số.
BIL-01|Chỉ số hợp lệ của đúng phòng và kỳ được lưu để phục vụ lập hóa đơn.|Chưa có chỉ số kỳ trước thì xử lý theo dữ liệu nền mà API hỗ trợ, không tự đoán mức tiêu thụ.|Chỉ số số học và kỳ theo DTO; không ghi âm tiêu thụ hoặc sửa kỳ đã khóa trái quy tắc.
BIL-02|Hóa đơn được tạo từ preview và dữ liệu hợp lệ, có các dòng tiền/snapshot giá.|Preview phát hiện thiếu dữ liệu thì bổ sung trước, chưa phát hành hóa đơn.|Kiểm tra hợp đồng, kỳ, chỉ số và giá có hiệu lực; không tạo trùng hóa đơn kỳ cho cùng hợp đồng.
BIL-03|Kết quả đợt lập hóa đơn phân biệt từng hợp đồng đã tạo, đã tồn tại hoặc lỗi.|Chạy kiểm tra trước để xử lý phòng thiếu dữ liệu; chạy lại không tạo trùng các kỳ đã có.|Không báo thành công toàn bộ khi có mục lỗi; mỗi kết quả phải gắn đúng hợp đồng/phòng.
BIL-04|Danh sách, chi tiết và tuổi nợ phản ánh số dư hiện tại theo bộ lọc.|Lọc hóa đơn đã thanh toán/hủy hoặc thay kỳ; không thay đổi sổ tiền khi chỉ xem.|Công nợ phải dựa số dư và trạng thái hợp lệ; dữ liệu thử không được cộng vào tiền thật.
BIL-05|Hạn thanh toán hoặc ghi chú được cập nhật, không làm đổi tổng tiền trái quy tắc.|Muốn đổi tiền thì dùng replacement hoặc adjustment phù hợp, không sửa qua ghi chú.|Chỉ nhận trường được hỗ trợ; kiểm tra trạng thái hóa đơn và quyền sở hữu.
BIL-06|Hóa đơn gốc chưa có lịch sử thanh toán được thay bằng revision mới, có liên kết truy vết.|Hóa đơn đã có Payment thì chuyển sang xem xét adjustment, không xóa lịch sử để thay thế.|Khóa và kiểm tra lại payment history; giữ liên kết replaces/replacement và lý do.
BIL-07|Credit/debit note và dòng điều chỉnh được phát hành; tổng và công nợ được tính lại.|Người dùng có thể hủy trước xác nhận; muốn thay cả hóa đơn phải kiểm tra điều kiện replacement.|Phân biệt cộng/trừ; credit không vượt công nợ theo quy tắc; không sửa ngầm các khoản đã thu.
BIL-08.1|Hóa đơn đủ điều kiện chuyển CANCELLED; lý do và lịch sử còn để đối chiếu.|Có tiền hoặc trạng thái không cho hủy thì đọc lịch sử và chọn xử lý nghiệp vụ phù hợp.|Không coi hủy là xóa; không hủy để làm mất nghĩa vụ đối chiếu các giao dịch đã phát sinh.
BIL-08.2|PDF hóa đơn được dựng từ dữ liệu hiện hành và chia sẻ/in theo khả năng nền tảng.|Người dùng đóng preview thì kết thúc luồng, không thay đổi trạng thái hóa đơn.|Chỉ xuất thông tin được xem; không ghi Payment hoặc tự đánh dấu đã thanh toán khi xuất PDF.
BIL-09|Khoản thanh toán dương được ghi vào hóa đơn; số dư và trạng thái được cập nhật.|Chỉ thu một phần thì hóa đơn còn dư và mang trạng thái tương ứng.|Số tiền không vượt dư; phương thức/ngày theo DTO; kiểm tra lại dư tại thời điểm ghi.
BIL-10|Khoản thu được tạo cho người thuê, phần chưa phân bổ vẫn khả dụng trong ledger.|Nhận tiền chưa xác định hóa đơn thì giữ chưa phân bổ, không tạo Payment giả.|Kiểm tra số tiền, người thuê, phương thức và requestKey; receipt không đồng nghĩa đã thu vào từng hóa đơn.
BIL-11|Các allocation hợp lệ được tạo; hóa đơn, Payment và phần khả dụng cập nhật nhất quán.|Có thể phân bổ một phần và để lại tiền khả dụng; không bắt buộc phân bổ hết khoản thu.|Tổng phân bổ không vượt khả dụng; mỗi hóa đơn phải đúng người thuê và còn công nợ hợp lệ.
BIL-12|Allocation được giải phóng và Payment reversal âm được ghi; lịch sử gốc không bị xóa.|Phân bổ đã giải phóng thì đối chiếu kết quả cũ; không đảo thêm để tăng tiền khả dụng lần nữa.|Khóa khoản thu/phân bổ; ghi lý do và bảo toàn liên kết giao dịch gốc.
BIL-13|BillingRefund được ghi cho phần khả dụng; số tiền còn dùng giảm tương ứng.|Tiền đang phân bổ phải được giải phóng trước khi có thể hoàn từ phần đó.|Không hoàn vượt số dư khả dụng; ghi sổ hoàn không tự thực hiện chuyển khoản.
BIL-14|Proof được chấp thuận/từ chối; chỉ chấp thuận hợp lệ mới tạo Payment và cập nhật hóa đơn.|Proof bị từ chối vẫn giữ lịch sử; người thuê có thể gửi chứng cứ khác theo luồng được hỗ trợ.|Kiểm tra tệp, quyền đọc, trạng thái PENDING và dư mới; duyệt đồng thời không được ghi tiền hai lần.
BIL-15|Đề xuất biểu phí được lưu với phạm vi, kỳ và version; chưa tự thay hóa đơn cũ.|Giá mặc định khu và giá override phòng được chọn rõ; không gộp hai phạm vi thành một giá ngầm.|Đơn giá/bậc thang hợp lệ; kỳ không bị khóa hoặc đã phát hành theo ràng buộc dịch vụ.
BIL-16|Đề xuất được duyệt/từ chối; tác động được xem trước và hiệu lực được ghi theo version.|Chủ trọ có thể từ chối sau khi xem phòng chịu tác động; không sửa proposal để che chênh lệch.|So sánh giá cũ/mới đúng nguồn; không cho backdate hoặc xung đột thứ tự hiệu lực trái quy tắc.
BIL-17.1|Cấu hình lập hóa đơn được lưu theo khu và ngày; không tự chứng minh worker đang bật.|Có thể tắt cấu hình mà không xóa hóa đơn đã lập.|Ngày chạy/hạn thu và khu hợp lệ; phân biệt lưu cấu hình với enqueue hoặc chạy đợt.
BIL-17.2|Preview hoặc đợt chạy trả kết quả từng phòng, có số tạo/bỏ qua/lỗi.|Preview không ghi hóa đơn; chỉ sau quyết định chạy mới thực hiện nghiệp vụ phát hành.|Chạy lại phải tôn trọng kiểm tra hóa đơn đã có và điều kiện từng hợp đồng.
BIL-18|Chính sách nhắc nợ hoặc công việc outbox được cập nhật; trạng thái gửi phản ánh kết quả delivery.|Khu không có override thì dùng mặc định chủ trọ; lưu policy không gửi tin ngay.|Version/requestKey theo lệnh; tôn trọng lựa chọn nhận tin và cấu hình provider.
BIL-19|Khoản chi vận hành được tạo/sửa và tổng hợp theo ngày, khu phù hợp.|Chỉ xem danh sách thì không tạo khoản chi; khoản liên kết bảo trì được đối chiếu tránh ghi trùng.|Số tiền, loại và ngày hợp lệ; ghi Expense không phải bằng chứng ngân hàng đã chi.
BIL-20|Báo cáo tháng hiển thị các tổng và công nợ theo đúng định nghĩa dịch vụ.|Tháng chưa có dữ liệu trả giá trị rỗng/0/null theo contract; không tạo số ước lượng.|Payment ròng khác toàn bộ receipt; công nợ là số dư hiện tại của nhóm hóa đơn, không là snapshot cuối tháng quá khứ.
BIL-21|Nội dung CSV đúng tháng/khu được sao chép vào clipboard; UI thông báo đúng hành động.|Người dùng thay bộ lọc rồi xuất lại; không tự tạo file XLSX hoặc PDF.|Cần quyền export và scope phù hợp; chỉ báo đã sao chép sau khi API và clipboard thành công.
OPS-01|Ticket bảo trì hoặc phản hồi được lưu đúng phòng; danh sách phản ánh trạng thái hiện tại.|Chủ trọ xem ticket do người thuê gửi hoặc tự tạo ticket trong quyền quản lý.|Nội dung/tệp theo điều kiện; tạo comment không tự hoàn tất ticket hoặc tạo khoản chi.
OPS-02|Phân công và tiến độ/SLA được lưu theo hành động, có người phụ trách phù hợp.|Không chọn người xử lý thì giữ trạng thái chưa phân công theo quy tắc, không tạo một tác nhân mới.|Chủ trọ chịu trách nhiệm thao tác trong phạm vi báo cáo; người nhận phải đáp ứng điều kiện dịch vụ.
OPS-03|Ticket được hoàn tất; khoản chi liên quan được liên kết nếu đã được xác nhận.|Không có chi phí thì hoàn tất theo dữ liệu phù hợp, không tạo Expense số tiền tùy đoán.|Kiểm tra trạng thái trước hoàn tất, số tiền và liên kết chi; retry không tạo chi phí trùng.
OPS-04|Danh sách việc cần làm hiển thị đúng nguồn và mở đúng bản ghi đích.|Nguồn việc không còn hợp lệ thì đọc lại thay vì mở dữ liệu giả.|Việc cần làm tổng hợp từ nghiệp vụ, không tự thay đổi trạng thái công nợ chỉ vì đã mở.
OPS-05|Các bước chuẩn bị phòng sau trả được cập nhật; phòng chỉ sẵn sàng theo điều kiện pipeline.|Chưa đủ checklist thì giữ quy trình đang thực hiện, không đánh dấu sẵn sàng tự động.|Không dùng chuyển trạng thái phòng để bỏ qua pipeline đang hoạt động.
OPS-06|Lịch định kỳ và checklist được lưu; các lần thực hiện được theo dõi riêng.|Có thể tạm dừng lịch tương lai mà vẫn giữ lịch sử công việc đã phát sinh.|Lịch hợp lệ, phạm vi đúng chủ trọ; có cấu hình không chứng minh scheduler đã thực thi.
OPS-07|Thông báo được soạn/phát tới đúng nhóm người thuê theo hành động xác nhận.|Chọn mẫu chỉ điền nội dung hoặc preview; chưa xác nhận phát thì không coi đã gửi.|Kiểm tra người nhận theo khu/hợp đồng; trạng thái đã đọc khác trạng thái giao qua kênh.
OPS-08|Lượt gửi hoặc yêu cầu nhắc Zalo được ghi và truy xuất theo kênh.|Provider chưa sẵn sàng thì hiển thị pending/lỗi theo dịch vụ, không báo đã nhận tin.|Không lấy thành công enqueue làm bằng chứng delivery; retry tuân điều kiện để tránh gửi trùng.
OPS-09|Nhật ký được tra cứu theo tài nguyên và bộ lọc thuộc chủ trọ.|Không có sự kiện phù hợp thì đổi bộ lọc; không tự tạo audit cho hành vi không xảy ra.|Chỉ đọc projection được phép; không lộ thông tin của chủ trọ khác hoặc dữ liệu bí mật.
TEN-01|Người thuê xem hồ sơ và tổng quan công nợ/công việc của mình.|Tài khoản đang tìm phòng chưa có hồ sơ liên kết thì nhận trạng thái phù hợp, không giả dữ liệu đang thuê.|Máy chủ xác định hồ sơ từ phiên; không cho chọn tenantId khác bằng tham số tùy ý.
TEN-02|Hợp đồng, cọc và quyết toán của người thuê được hiển thị theo lịch sử.|Người thuê có thể chọn hợp đồng cũ để xem nhưng không sửa điều khoản phía chủ trọ.|Kiểm tra liên kết User–Tenant–Lease; phân biệt tiền cọc với số dư hóa đơn.
TEN-03|Hóa đơn của người thuê được hiển thị và PDF được chia sẻ theo nền tảng.|Hóa đơn còn dư hiển thị chờ thanh toán; không coi có chứng từ là đã thu tiền.|Chỉ xem hóa đơn thuộc hồ sơ mình; không tự thay trạng thái khi mở/chia sẻ PDF.
TEN-04|Tệp và proof được tiếp nhận ở trạng thái chờ xử lý; không tự ghi Payment.|Kết quả gửi chưa rõ thì đọc lại proof trước khi gửi lặp; không nhận định đã thanh toán.|Tệp thuộc quyền truy cập, loại/kích thước hợp lệ; số tiền và requestKey theo API, không vượt điều kiện nhận proof.
TEN-05|Phiên checkout thử hoặc trạng thái thanh toán demo được hiển thị, tách dữ liệu thật.|Hóa đơn thật được dùng làm nguồn tạo hóa đơn demo riêng nếu luồng hỗ trợ; không thu thẻ thật.|Chỉ mô phỏng nội bộ; trạng thái PAID của link không đồng nghĩa hóa đơn hết dư khi dữ liệu không khớp.
TEN-06|Yêu cầu bảo trì/comment của người thuê được lưu gắn phòng đang thuê.|Có thể bổ sung mô tả/tệp cho ticket của mình; không được phân công hoặc hoàn tất thay chủ trọ.|Máy chủ chọn phạm vi từ hồ sơ thuê; file và comment không được gắn vào ticket của người khác.
TEN-07|Yêu cầu gia hạn/chuyển/trả được tạo, hủy hoặc theo dõi trong quyền người thuê.|Yêu cầu còn PENDING có thể hủy theo contract; được duyệt vẫn cần chủ trọ execute.|Kiểm tra loại yêu cầu, thời điểm, hợp đồng và yêu cầu chờ trùng; không tự sửa phòng/hợp đồng khi gửi.
TEN-08|Danh sách người ở cùng và lựa chọn nhận thông báo được đọc/cập nhật đúng chức năng.|Không đổi sở thích thì giữ cấu hình cũ; người thuê không tự thêm người vượt sức chứa qua màn xem.|Tách quyền xem người ở với quyền quản lý danh sách; preference chỉ áp kênh được hỗ trợ.
TEN-09|Thông báo được xem/đánh dấu hoặc xác nhận theo thao tác rõ ràng; trao đổi gắn đúng portal.|Chỉ mở inbox chưa mặc nhiên xác nhận một thông báo cần hành động riêng.|Kiểm tra người nhận và loại thông báo; trạng thái đã đọc/xác nhận không thay thế kết quả nghiệp vụ khác.
ADM-01|Dashboard quản trị và chỉ số nền tảng hiển thị theo capability của phiên.|Panel không đủ quyền thì hiển thị denied/ẩn phù hợp, không trả số 0 giả là hệ thống trống.|Chỉ số là read model theo định nghĩa endpoint; không suy tổng tiền nền tảng từ gán gói quản trị.
ADM-02|Tài khoản và chi tiết projection được trả theo quyền; PII được che mặc định.|Thay tìm kiếm/bộ lọc/trang để thu hẹp kết quả; mở dữ liệu nhạy cảm qua lệnh reveal riêng.|Không dùng quyền xem để vô hiệu hoặc reset; chống lộ PII qua danh sách và lỗi.
ADM-03.1|Tài khoản/lời mời chủ trọ được tạo; job gửi phản ánh đúng trạng thái.|Chọn mời thay vì tạo trực tiếp theo luồng được hỗ trợ; email có sẵn không tạo tài khoản trùng.|Capability và email hợp lệ; không coi tạo job là thư mời đã giao thành công.
ADM-03.2|Hồ sơ chủ trọ được cập nhật, audit và version phản ánh thay đổi.|Dữ liệu đã đổi thì tải lại trước khi sửa; không ghi đè từ form cũ.|Chỉ trường cho phép; trạng thái và bảo vệ tài khoản được thực hiện qua hành động riêng.
ADM-04.1|Tài khoản bị đình chỉ, phiên liên quan được thu hồi theo chính sách và audit.|Người thao tác có thể hủy trước quyết định; không vô hiệu chỉ vì xem chi tiết.|Bắt buộc quyền/lý do/version theo contract; kiểm tra bảo vệ tài khoản quản trị.
ADM-04.2|Tài khoản được khôi phục hoạt động và có audit; token cũ không sống lại.|Nếu tài khoản đã hoạt động, đọc trạng thái hiện tại thay vì tạo một lần khôi phục giả.|Kiểm tra quyền, trạng thái và version; người dùng phải xác thực bằng phiên mới phù hợp.
ADM-04.3|Các phiên đích bị thu hồi; số phiên xử lý và audit được hiển thị.|Tài khoản không có phiên hiệu lực thì trả kết quả phù hợp, không khẳng định thu hồi một phiên không tồn tại.|Phạm vi thu hồi theo lệnh; không thay mật khẩu hoặc trạng thái tài khoản bằng hành động revoke.
ADM-05.1|Trường PII được phép được mở có kiểm soát và truy vết.|Thiếu step-up thì hoàn tất xác minh riêng rồi yêu cầu lại; không bỏ qua vì đã đăng nhập Admin.|Cần capability/lý do/grant theo policy; không cache kéo dài hoặc xuất dữ liệu ngoài quyền.
ADM-05.2|Công việc phục hồi truy cập được tạo hoặc xử lý theo policy và audit.|Delivery chưa hoàn thành thì theo dõi/retry đúng luồng, không báo người dùng đã đổi mật khẩu.|Admin không đọc mật khẩu; token phục hồi phải tôn trọng hạn và mục đích.
ADM-06.1|Profile, preset/quyền hoặc trạng thái Admin được cập nhật theo bảo vệ quản trị.|Không đủ quyền chỉnh thì chỉ xem; cấu hình không hợp lệ không được ghi một phần.|Kiểm tra tài khoản đích, bảo vệ quản trị viên và thu hồi phiên khi policy yêu cầu.
ADM-06.2|Đợt rà soát quyền được ghi với reviewer, đối tượng, quyết định và lý do.|Có thể giữ nguyên quyền sau review có căn cứ; không đồng nghĩa mặc nhiên cấp thêm capability.|Phân biệt quyền người rà soát và người được rà soát; ghi đầy đủ bằng chứng quyết định.
ADM-07|MFA được thiết lập/xác minh hoặc grant step-up được cấp theo policy.|Grant hết hạn thì xác minh lại; đăng nhập cơ bản không thay thế step-up cho hành động nhạy cảm.|Không đưa secret/OTP vào log hoặc hình minh họa; grant phải đúng mục đích, còn hạn.
ADM-08|Inventory khu/phòng được hiển thị ở mức projection cho phép, có giới hạn preview.|Muốn xem thêm phòng thì dùng phân trang/chi tiết được hỗ trợ; preview 20 phòng không phải toàn bộ inventory.|Inventory đọc không cho sửa hợp đồng, tenant hoặc tài chính; thông tin cá nhân được che.
ADM-09|Khu của chủ trọ đích được tạo/cập nhật với audit phù hợp; không tự được duyệt.|Chỉ có quyền xem thì không mở thao tác ghi; muốn xét duyệt thì chuyển UC-ADM-19.|Kiểm tra chủ trọ hoạt động, ownership, capability và hạn mức khi tạo; kiểm duyệt tin là quy trình riêng.
ADM-10|Kết quả tìm kiếm có loại tài nguyên và mở đúng ID mà Admin có quyền xem.|Không đủ quyền đối tượng đích thì không vượt quyền nhờ kết quả tìm kiếm.|UUID phải so đúng trường ID, không trúng nhầm UUID nằm trong tiêu đề bản ghi khác.
ADM-11|Tin được nhận xử lý và quyết định kiểm duyệt theo trạng thái/version hiện tại.|Có thể từ chối hoặc trả lại theo hành động hỗ trợ; không coi gửi duyệt là công khai.|Kiểm tra claim, capability, version và lý do; không tự duyệt trên dữ liệu cũ.
ADM-12|Quyết định về đánh giá/phản hồi/báo cáo vi phạm được lưu và truy vết.|Báo cáo chưa đủ căn cứ có thể được xử lý theo quyết định thích hợp; không xóa nội dung theo số lượng phản ánh đơn thuần.|Mỗi loại nội dung có phạm vi và trạng thái riêng; không áp quyết định cho sai đối tượng.
ADM-13|Chính sách, kháng nghị hoặc kết quả QA được ghi theo luồng tương ứng.|Kháng nghị được đọc và giải quyết riêng; quyết định gốc không tự mất khi có kháng nghị.|Version/quyền reviewer và trạng thái theo dịch vụ; không đồng nhất QA với kiểm duyệt ban đầu.
ADM-14|Audit quản trị được lọc/xuất theo quyền và phạm vi dữ liệu cho phép.|Không có sự kiện thì trả tập rỗng; thay bộ lọc không làm đổi lịch sử.|Không xuất bí mật hoặc mở PII ngoài capability; giữ liên kết actor, action, resource và thời gian.
ADM-15|Proposal đối soát được tạo và người kiểm tra khác duyệt/từ chối; lịch sử được giữ.|Dòng sao kê chưa ghép được thì giữ chưa đối soát, không tạo khoản thu tự suy đoán.|Maker không tự duyệt proposal của mình; đối soát cấp receipt, không nhân đôi các allocation.
ADM-16|Lịch/đợt báo cáo Admin được lưu hoặc kết quả được tải theo quyền.|Job còn chờ thì hiển thị trạng thái chờ; chưa có kết quả không cho giả tệp đã tạo.|Có lịch không chứng minh scheduler đang chạy; tải artifact phải qua kiểm tra quyền.
ADM-17|Feature flag hoặc nhóm Admin được cập nhật và có audit.|Đổi cấu hình chỉ tác động phạm vi được hỗ trợ; không hứa mở một tính năng chưa triển khai.|Kiểm tra capability, version và thành viên hợp lệ; không dùng nhóm để vượt policy bảo vệ.
ADM-18|Hồ sơ xác minh chủ trọ được nộp/xem hoặc duyệt/từ chối theo hai vai trò tách biệt.|Chủ trọ bổ sung chứng cứ trước khi gửi; Admin yêu cầu dữ liệu phù hợp thay vì suy đoán đã xác minh.|Chủ trọ không tự duyệt; APPROVED cần chủ trọ hoạt động, hồ sơ PENDING đúng version và chứng cứ SUPPORT_CLEAN.
ADM-19|Hồ sơ khu được trình và quyết định xét duyệt gắn snapshot hợp lệ.|Nội dung khu đổi sau gửi thì cần đọc snapshot mới theo quy trình; không duyệt nội dung đã thay đổi.|Kiểm tra version/snapshotHash và quyền; duyệt khu không đồng nghĩa duyệt mọi tin phòng trong khu.
ADM-20|Gói dịch vụ được tạo/sửa/bật tắt theo version; danh mục phản ánh trạng thái mới.|Gói tắt không được dùng cho đăng ký mới; lịch sử gói đã gán được giữ qua snapshot.|Giới hạn và giá phải hợp lệ; gói FREE có giá 0, không tự tạo doanh thu chỉ vì lưu danh mục.
ADM-21|Quyền sử dụng được gán cùng planSnapshot, SubscriptionEvent và audit.|Gói không phù hợp inventory hiện tại thì giữ đăng ký cũ; không xóa dữ liệu để ép hạ gói.|Khóa chủ trọ/gói, kiểm tra version/hạn/inventory; financialEffect=NONE, không tạo Payment hoặc hóa đơn thuê.
SUP-01|Ticket, phản hồi hoặc ghi chú hỗ trợ được lưu; trạng thái và lịch sử đúng quyền.|Phản hồi công khai và ghi chú nội bộ được chọn riêng; chưa gửi thì chỉ là nội dung đang soạn.|Support-context chỉ đọc dữ liệu tham chiếu, không cho sửa hóa đơn hoặc quyết toán qua ticket.
SUP-02|Team/người xử lý, SLA và escalation được cập nhật theo chính sách.|Auto-assign không tìm người phù hợp thì giữ trạng thái chưa nhận; không gán người giả.|Kiểm tra năng lực, trạng thái, tải và quyền; việc có SLA service không chứng minh worker đã chạy.
SUP-03|Tệp/mẫu/bộ lọc được lưu và truy xuất theo quyền của hồ sơ hỗ trợ.|Chọn mẫu để preview không tự gửi phản hồi; có thể sửa nội dung trước khi gửi.|Tệp cần kiểm tra truy cập và trạng thái; không lộ link tài liệu riêng của ticket khác.
SUP-04|Inbox, trạng thái đọc hoặc preference Admin được cập nhật đúng người dùng.|Không có thông báo thì hiển thị rỗng; thay kênh không tạo một delivery đã thành công.|Phân biệt NotificationRead và lượt giao email/thiết bị; lỗi count không được giả thành 0.
SUP-05|Sự cố/job được xem, acknowledge hoặc phục hồi trong phạm vi hành động cho phép.|Thiếu heartbeat phải hiển thị chưa sẵn sàng; không đánh dấu hệ thống khỏe từ dữ liệu vắng mặt.|Kiểm tra state/version/lý do, giữ audit; thao tác báo cáo không tự bật worker hoặc migrate DB thật.
SUP-06|Câu trả lời và nguồn hợp lệ được hiển thị; không tự sửa dữ liệu vận hành.|Thiếu dữ liệu hoặc tri thức thì nêu giới hạn, đề nghị làm rõ; không bịa công nợ hay trạng thái thuê.|Chỉ phiên LANDLORD; kiểm tra rate limit, khu và quyền nguồn; nội dung truy xuất không phải lệnh hệ thống.
'''

DETAIL_MAP={}
for line in DETAILS.strip().splitlines():
    key,success,alternate,validation=line.split('|')
    DETAIL_MAP['UC-'+key]=(success,alternate,validation)

READ_IDS=set('UC-DIS-01 UC-DIS-02 UC-OPT-01 UC-OPT-02 UC-OPT-05 UC-TNT-01 UC-TNT-04 UC-TNT-13 UC-BIL-04 UC-BIL-08.2 UC-BIL-20 UC-BIL-21 UC-OPS-04 UC-OPS-09 UC-TEN-01 UC-TEN-02 UC-TEN-03 UC-ADM-01 UC-ADM-02 UC-ADM-08 UC-ADM-10 UC-ADM-14 UC-SUP-06'.split())
DETAIL_MAP['UC-ADM-22']=('Đăng ký kết thúc hiệu lực tại thời điểm hủy, tăng version và ghi sự kiện CANCELLED/audit; dữ liệu khu/phòng hiện hữu được giữ.','Đăng ký đã hết hiệu lực hoặc version cũ thì đọc lại; không tạo sự kiện hủy lặp và không tự hoàn tiền.','Kiểm tra admin.plans.manage, lý do và version; khóa theo chủ trọ; financialEffect=NONE, không phát sinh hóa đơn thuê hoặc Payment.')

GROUP_CONTEXT={
 'SYS':('Tài khoản và phiên làm việc','Xác thực, trạng thái tài khoản, token/phiên và quyền do máy chủ cấp; không dùng dữ liệu nhập để tự chọn quyền.'),
 'DIS':('Khám phá và kết nối thuê phòng','Tin/phòng đích và trạng thái công khai; thao tác cá nhân lấy danh tính từ phiên, thao tác quản lý kiểm tra chủ sở hữu.'),
 'OPT':('Quản lý khu trọ và phòng','Khu/phòng phải thuộc chủ trọ; trạng thái lưu trữ, hoạt động, hợp đồng và lịch sử được kiểm tra theo hành động.'),
 'TNT':('Quản lý hồ sơ và hợp đồng thuê','Hồ sơ, phòng và hợp đồng cùng phạm vi chủ trọ; đối chiếu trạng thái thuê, ngày hiệu lực và lịch sử tiền liên quan.'),
 'BIL':('Hóa đơn và sổ thu chi','Đối tượng tiền thuộc chủ trọ; loại tiền, dấu tiền, kỳ, phần khả dụng và công nợ không được suy từ giao diện cũ.'),
 'OPS':('Bảo trì vận hành và nhật ký','Đúng khu/phòng và chủ sở hữu; phân biệt xem việc, lưu tiến độ, hoàn tất và ghi nhận chi phí hoặc gửi tin.'),
 'TEN':('Cổng thông tin người thuê','Có phiên TENANT và hồ sơ thuê liên kết phù hợp; máy chủ xác định dữ liệu của chính người dùng.'),
 'ADM':('Quản trị nền tảng','Có phiên ADMIN, capability phù hợp; MFA/step-up theo policy. Không mặc định Admin được sửa tài chính của chủ trọ.'),
 'SUP':('Hỗ trợ và vận hành nền tảng','Có phiên ADMIN và quyền tương ứng trên hồ sơ/hàng đợi; ghi chú nội bộ và dữ liệu người dùng phải đúng đối tượng.'),
}

MAIN_OVERRIDES={
 'UC-SYS-01':[
 ('Khách vãng lai','Chọn đăng ký với vai trò chủ trọ; nhập thông tin tài khoản và mật khẩu theo biểu mẫu.'),
 ('Hệ thống','Kiểm tra trường bắt buộc và định dạng; không cho biểu mẫu tự cấp quyền Admin.'),
 ('Khách vãng lai','Rà soát thông tin và xác nhận gửi đăng ký.'),
 ('Hệ thống','Kiểm tra DTO, chuẩn hóa dữ liệu theo dịch vụ và kiểm tra email đã được sử dụng.'),
 ('Hệ thống','Tạo tài khoản LANDLORD và dữ liệu xác thực theo quy trình của AuthService; không tạo tài khoản nếu đầu vào không hợp lệ.'),
 ('Hệ thống','Trả thông tin tài khoản và phiên; ứng dụng lưu phiên an toàn và thay trạng thái xác thực.'),
 ('Hệ thống','Điều hướng vào không gian chủ trọ của tài khoản mới; chỉ tải dữ liệu thuộc danh tính này.')],
 'UC-SYS-08':[
 ('Người thuê','Mở liên kết mời do chủ trọ cung cấp, nhập mật khẩu mới và xác nhận kích hoạt.'),
 ('Hệ thống','Kiểm tra token đúng loại, chưa hết hạn và chưa được sử dụng; xác định hồ sơ đích từ lời mời.'),
 ('Hệ thống','Trong transaction, khóa/đọc lại các bản ghi liên quan và kiểm tra chủ trọ, hồ sơ còn hoạt động.'),
 ('Hệ thống','Kiểm tra hồ sơ chưa liên kết tài khoản; email chưa được tài khoản khác sử dụng. Không tự liên kết vào tài khoản email đã có.'),
 ('Hệ thống','Tạo tài khoản TENANT với mật khẩu được xử lý an toàn và liên kết vào đúng hồ sơ người thuê.'),
 ('Hệ thống','Đánh dấu lời mời đã dùng và tạo phiên theo contract; lỗi trong giao dịch không để lại tài khoản liên kết dở.'),
 ('Hệ thống','Trả phiên và thông tin liên kết; ứng dụng mở cổng người thuê với dữ liệu của chính hồ sơ đó.')],
 'UC-ADM-19':[
 ('Admin','Mở khu trọ cần trình duyệt và kiểm tra thông tin hiện tại.'),
 ('Hệ thống','Xác minh capability quản lý khu; đọc khu chưa lưu trữ và snapshot cần trình.'),
 ('Admin','Xác nhận trình hồ sơ kèm version theo dữ liệu hiện tại.'),
 ('Hệ thống','Lưu hồ sơ PENDING với snapshotHash; trình duyệt chưa đồng nghĩa hồ sơ đã được chấp thuận.'),
 ('Admin','Mở hồ sơ PENDING, đối chiếu thông tin và chọn quyết định, nhập lý do xét duyệt.'),
 ('Hệ thống','Khóa/đọc lại dữ liệu; so version, snapshotHash và trạng thái. Nếu khu đã đổi thì từ chối quyết định trên hồ sơ cũ.'),
 ('Hệ thống','Ghi quyết định, tác nhân, thời điểm và audit trong giao dịch; trả version và trạng thái mới.'),
 ('Admin','Đọc kết quả; không coi phê duyệt khu là đã duyệt tất cả tin phòng trong khu.')],
 'UC-ADM-22':[
 ('Admin','Mở chủ trọ và đăng ký dịch vụ cần hủy; rà gói, quyền lợi và thời hạn.'),
 ('Hệ thống','Tải đăng ký cùng version hiện tại; kiểm tra capability admin.plans.manage của phiên.'),
 ('Admin','Nhập lý do, kiểm tra tác động kết thúc quyền sử dụng và xác nhận hủy.'),
 ('Hệ thống','Tiếp nhận mã đăng ký, version và lý do; trong transaction khóa User của chủ trọ rồi đọc lại đăng ký.'),
 ('Hệ thống','Kiểm tra đăng ký còn hiệu lực và version trùng; nếu đã hết hạn hoặc có thay đổi thì dừng, yêu cầu đọc lại.'),
 ('Hệ thống','Đặt endsAt bằng thời điểm hủy, tăng version và ghi SubscriptionEvent CANCELLED cùng audit financialEffect=NONE.'),
 ('Hệ thống','Commit và trả trạng thái/lịch sử mới; không tạo hoàn tiền, không xóa khu/phòng hay lịch sử đăng ký.')],
 'UC-BIL-11':[
 ('Chủ trọ','Mở khoản thu còn tiền khả dụng và chọn chức năng phân bổ.'),
 ('Hệ thống','Tải khoản thu, người thuê và các hóa đơn còn công nợ được phép phân bổ; hiển thị số dư đang có.'),
 ('Chủ trọ','Chọn từng hóa đơn, nhập số tiền cho mỗi dòng và rà soát tổng phân bổ trước khi xác nhận.'),
 ('Hệ thống','Kiểm tra đầu vào và quyền; gửi lệnh với định danh khoản thu, các dòng phân bổ và khóa yêu cầu theo contract.'),
 ('Hệ thống','Trong transaction, khóa dữ liệu tiền liên quan và đọc lại số khả dụng cùng công nợ từng hóa đơn.'),
 ('Hệ thống','Kiểm tra tổng không vượt khả dụng, mỗi hóa đơn đúng người thuê và không nhận vượt công nợ; sai một điều kiện thì không ghi phần còn lại.'),
 ('Hệ thống','Tạo PaymentAllocation và Payment tương ứng; tính lại số dư khoản thu, số đã thanh toán và trạng thái hóa đơn.'),
 ('Hệ thống','Trả kết quả có liên kết; giao diện tải lại ledger và các hóa đơn để chủ trọ đối chiếu.')],
 'UC-TNT-08':[
 ('Chủ trọ','Mở hợp đồng trả phòng, nhập ngày trả, chỉ số điện nước và các khoản điều chỉnh được hỗ trợ.'),
 ('Hệ thống','Kiểm tra quyền sở hữu, dữ liệu đầu vào và trạng thái hợp đồng trước khi yêu cầu preview.'),
 ('Hệ thống','Đọc công nợ, lịch sử cọc và dữ liệu tính phí; trả bảng quyết toán cùng snapshot/fingerprint, chưa kết thúc hợp đồng.'),
 ('Chủ trọ','Đối chiếu từng dòng tiền, số cọc được trừ và khoản còn phải thu/hoàn; chọn xác nhận khi đồng ý.'),
 ('Hệ thống','Gửi lệnh xác nhận với fingerprint và requestKey; không tự tái tạo preview ngầm để bỏ qua việc đối chiếu.'),
 ('Hệ thống','Khóa dữ liệu liên quan, đối chiếu snapshot hiện tại; nếu đã thay đổi thì dừng để chạy preview lại.'),
 ('Hệ thống','Lưu quyết toán, các dòng ghi nhận và thay đổi trạng thái thuê/phòng trong đơn vị giao dịch của service.'),
 ('Hệ thống','Hiển thị kết quả đã xác nhận; khoản hoàn thực tế vẫn được ghi riêng qua UC-TNT-09, không tự chuyển tiền.')],
 'UC-TEN-04':[
 ('Người thuê','Mở hóa đơn của mình và chọn gửi chứng từ; kiểm tra khoản còn phải thanh toán.'),
 ('Hệ thống','Tải thông tin hóa đơn theo phiên, hiển thị số dư và các chứng từ đã gửi để tránh gửi lặp.'),
 ('Người thuê','Chọn tệp ảnh/PDF được hỗ trợ, nhập số tiền, phương thức, ngày hoặc tham chiếu theo biểu mẫu.'),
 ('Hệ thống','Kiểm tra đầu vào; tải tệp qua endpoint có bảo vệ và nhận định danh tệp, không dùng URL tùy ý làm bằng chứng.'),
 ('Người thuê','Rà thông tin và xác nhận gửi; có thể quay lại sửa trước khi phát sinh lệnh.'),
 ('Hệ thống','Xác minh hồ sơ thuê, quyền tệp, hóa đơn và requestKey theo API; lưu proof ở trạng thái chờ xử lý.'),
 ('Hệ thống','Trả trạng thái PENDING và tải lại lịch sử chứng từ; chưa ghi Payment hoặc đánh dấu hóa đơn đã thanh toán.'),
 ('Người thuê','Theo dõi quyết định chấp thuận/từ chối trong lần đọc tiếp theo; việc duyệt thuộc UC-BIL-14 của chủ trọ.')],
 'UC-ADM-18':[
 ('Chủ trọ','Mở hồ sơ xác minh của mình, chuẩn bị dữ liệu và minh chứng gắn ticket hỗ trợ hợp lệ.'),
 ('Hệ thống','Lấy chủ trọ đích từ phiên LANDLORD, kiểm tra dữ liệu/chứng cứ rồi lưu hồ sơ theo trạng thái cho phép.'),
 ('Chủ trọ','Xem hồ sơ và kết quả của chính mình; không có thao tác tự duyệt.'),
 ('Admin','Dùng phiên ADMIN có capability xác minh và support.read để mở hàng đợi/chi tiết.'),
 ('Hệ thống','Trả dữ liệu được phép xem, version hiện tại và chứng cứ qua quyền truy cập bảo vệ.'),
 ('Admin','Đối chiếu thông tin; nhập quyết định, lý do và xác nhận theo policy của hành động.'),
 ('Hệ thống','Kiểm tra PENDING/version, bảo vệ tự duyệt, chủ trọ hoạt động và chứng cứ SUPPORT_CLEAN khi chấp thuận; cập nhật có điều kiện và audit.'),
 ('Hệ thống','Trả quyết định/version mới; mỗi bên xem projection phù hợp. Kết quả không được mô tả là chứng nhận pháp lý ngoài chức năng hệ thống.')],
 'UC-SUP-06':[
 ('Chủ trọ','Mở trợ lý AI, chọn khu nếu cần và nhập câu hỏi về nghiệp vụ quản lý của mình.'),
 ('Hệ thống','Kiểm tra phiên LANDLORD, định dạng câu hỏi, giới hạn tần suất và quyền với khu được chọn.'),
 ('Hệ thống','Truy xuất tri thức và công cụ đọc nghiệp vụ được cho phép trong phạm vi danh tính hiện tại.'),
 ('Hệ thống','Tổng hợp câu trả lời dựa trên dữ liệu có căn cứ; không thực hiện lệnh ghi sổ từ nội dung truy xuất.'),
 ('Hệ thống','Trả nội dung, trạng thái trả lời và danh sách nguồn khi có; thiếu căn cứ thì nêu giới hạn.'),
 ('Chủ trọ','Đọc câu trả lời và có thể mở nguồn hoặc đặt câu hỏi làm rõ.'),
 ('Hệ thống','Khi mở nguồn, kiểm tra lại quyền qua endpoint bảo vệ; không cấp quyền chỉ vì đã có ID nguồn.')],
}

def lower(text):
 return text[0].lower()+text[1:] if text else text

def specification(case):
 key=case['id'];success,alternate,validation=DETAIL_MAP[key]
 actors=case['diagram_actors'];primary=actors[0]
 context,pre=GROUP_CONTEXT[case['group']]
 if case['group']=='SYS':pre='Ứng dụng truy cập được dịch vụ; có tài khoản, token hoặc lời mời đúng loại nếu luồng yêu cầu. Chức năng đăng ký/đăng nhập/khôi phục công khai không yêu cầu phiên sẵn có.'
 if key=='UC-SYS-08':pre='Người thuê nhận được lời mời hợp lệ từ chủ trọ; token đúng hồ sơ và đáp ứng điều kiện tiếp nhận của service.'
 if key in {'UC-DIS-01','UC-DIS-02'}:pre='Khách vãng lai hoặc người thuê truy cập chức năng công khai; tin được xem phải đủ điều kiện xuất hiện công khai.'
 if key=='UC-ADM-18':pre='Chủ trọ dùng phiên LANDLORD để nộp/xem hồ sơ của mình; Admin dùng phiên riêng với quyền xác minh và support.read để xử lý. Minh chứng liên kết đúng ticket.'
 if key=='UC-ADM-19':pre='Admin có capability quản lý khu để trình và xử lý hồ sơ; sử dụng version và snapshot tương ứng. Controller hiện không cung cấp bước trình khu này cho chủ trọ.'
 if key=='UC-TNT-12.2':pre='Chủ trọ có quyền với hợp đồng để lập biên bản; người thuê liên kết hợp đồng dùng phiên riêng để xem và xác nhận version được trình bày.'
 if key=='UC-SUP-06':pre='Có phiên LANDLORD; khu được chọn thuộc chủ trọ, dịch vụ tri thức/mô hình đáp ứng cấu hình truy cập.'
 steps=MAIN_OVERRIDES.get(key)
 if steps is None:
  steps=[]
  for index,step in enumerate(case['steps']):
   text=step.rstrip('.');human=bool(re.match(r'^(Mở|Chọn|Nhập|Xác nhận|Rà|Đọc tác động|Đọc cảnh báo|Chủ trọ|Người thuê|Người dùng|Admin)',text))
   actor=primary if human else 'Hệ thống'
   steps.append((actor,text+'.'))
   if index==0:
    if key in READ_IDS:steps.append(('Hệ thống','Tiếp nhận yêu cầu xem, kiểm tra danh tính/phạm vi áp dụng và tải dữ liệu phục vụ '+lower(case['title'])+'.'))
    else:steps.append(('Hệ thống','Hiển thị dữ liệu hiện tại và các trường của thao tác: '+case['inputs'].rstrip('.')+'.'))
  if not any('Hệ thống'==a and ('Kiểm tra' in b or 'kiểm tra' in b) for a,b in steps):steps.insert(-1,('Hệ thống',validation))
  steps.append(('Hệ thống',success))
 data=case['inputs'].rstrip('.')+'. '+validation
 if key in READ_IDS:minimum='Không phát sinh thay đổi vào dữ liệu nghiệp vụ khi chỉ xem/xuất; dữ liệu ngoài quyền không được trả về, kể cả khi đổi ID trên yêu cầu.'
 else:minimum='Nếu kiểm tra đầu vào, quyền hoặc trạng thái thất bại, không coi thao tác là thành công. Giữ các bản ghi trước lệnh; các bước tải tệp/job riêng được đối chiếu theo trạng thái thực, không mặc định đã rollback toàn bộ tác vụ ngoài transaction.'
 alt2='A2. Người dùng đổi bộ lọc hoặc tài nguyên: truy vấn lại trong cùng phạm vi; dữ liệu chưa tải xong không được thay bằng số liệu giả.' if key in READ_IDS else 'A2. Người dùng quay lại trước bước xác nhận cuối: kết thúc hoặc sửa nội dung chưa gửi; các thay đổi đã được một lệnh riêng xác nhận phải đọc lại theo trạng thái máy chủ.'
 if 'requestKey' in case['inputs'] or 'requestKey' in case['rules'] or key in {'UC-BIL-10','UC-BIL-11','UC-BIL-12','UC-BIL-13','UC-TNT-08','UC-TEN-04'}:
  alt2='A2. Mất phản hồi sau gửi: đối chiếu kết quả hiện tại. Khi API hỗ trợ requestKey, retry cùng khóa và cùng nội dung; không đổi khóa để gửi lại một khoản tiền chưa biết đã ghi hay chưa.'
 exceptions='E1. '+case['error'].rstrip('.')+'.\nE2. Không xác minh được quyền/phiên hoặc dữ liệu đích đã thay đổi: dừng luồng, trả thông báo phù hợp và yêu cầu đọc lại/đăng nhập; không dùng dữ liệu cache để vượt kiểm tra máy chủ.'
 return {'id':key,'context':context,'primary':primary,'secondary':'; '.join(actors[1:]) or 'Không có tác nhân con người phối hợp bắt buộc trong luồng này.','goal':success,'trigger':case['steps'][0].rstrip('.')+'.','pre':pre,'data':data,'steps':steps,'alternatives':'A1. '+alternate+'\n'+alt2,'exceptions':exceptions,'success':success,'minimum':minimum,'rules':case['rules']+' '+validation,'result':'Dữ liệu trả về được gắn đúng đối tượng và trạng thái nêu ở kết quả thành công; giao diện cần đọc lại khi có xung đột hoặc phản hồi chưa xác định.','related':'Tra cứu nhóm '+case['group']+' trong sơ đồ phân rã; các UC có mã cha dùng chung miền nghiệp vụ nhưng không mặc nhiên có quan hệ include/extend.'}
