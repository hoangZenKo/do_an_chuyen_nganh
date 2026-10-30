OVERRIDES = {}


def case(identifier, inputs, steps, alternatives, exceptions, rules, post, goal=None):
    OVERRIDES[identifier] = {
        'input': inputs,
        'steps': steps.split('|'),
        'alternatives': alternatives.split('|') if alternatives else [],
        'exceptions': exceptions.split('|') if exceptions else [],
        'rules': rules.split('|'),
        'post': post,
        **({'goal': goal} if goal else {}),
    }

case('UC-DIS-13.2', 'Khu vực thử nghiệm, điểm đánh giá và nội dung phản hồi.',
     'Chủ trọ hoặc người tìm phòng mở thông tin thử nghiệm.|Hệ thống cho biết khu vực đang nhận phản hồi.|Người sử dụng nhập và gửi phản hồi; hệ thống kiểm tra khu vực còn được mở và trùng với khu vực đã chọn.|Hệ thống lưu phản hồi dưới tài khoản người gửi và thông báo kết quả.',
     '', 'B3: Đợt thử nghiệm đã tắt hoặc đổi khu vực: không lưu phản hồi; người dùng xem lại thông tin thử nghiệm.',
     'Chỉ chủ trọ và người tìm phòng hoặc người thuê được gửi phản hồi.|Quản trị viên có thể xem thông tin thử nghiệm nhưng không gửi thay người sử dụng.|Gửi phản hồi không thay đổi phạm vi thử nghiệm.', 'Phản hồi được ghi nhận để phục vụ đánh giá thử nghiệm.')

case('UC-ADM-11', 'Tin cần xem xét, người phụ trách, kết quả dự kiến, lý do và thông tin lần cập nhật gần nhất.',
     'Quản trị viên mở danh sách tin chờ xem xét và đọc nội dung, lịch sử của tin.|Quản trị viên nhận xử lý hoặc phân công; hệ thống kiểm tra quyền, người đang phụ trách và việc hồ sơ chưa thay đổi.|Quản trị viên chọn xuất bản, từ chối hoặc ẩn tin; hệ thống kiểm tra trạng thái phù hợp và khả năng cho thuê của phòng nếu xuất bản.|Hệ thống ghi kết quả, lý do, người xử lý và thời điểm; thông báo trạng thái tin sau xử lý.',
     'B3: Xử lý nhiều tin: hệ thống cho xem trước điều kiện từng tin và trả kết quả riêng cho từng tin; một tin lỗi không hủy kết quả của những tin đã xử lý.|B3: Từ chối hoặc ẩn tin: quản trị viên phải nhập lý do trước khi tiếp tục B4.',
     'B2: Hồ sơ đang do người khác phụ trách hoặc đã thay đổi: không nhận đè; yêu cầu xem lại phân công.|B3: Tin không đúng trạng thái hoặc phòng không còn đủ điều kiện: không xuất bản; yêu cầu kiểm tra lại.',
     'Xuất bản hoặc từ chối áp dụng với tin chờ duyệt; ẩn áp dụng với tin đã xuất bản.|Phân công người khác cần quyền quản lý nhân sự quản trị.|Quyền kiểm duyệt tin không tự bao gồm quyền kiểm duyệt đánh giá hoặc phản hồi.', 'Tin có kết quả xử lý và lịch sử quyết định; xử lý nhiều tin có thể chỉ thành công một phần.')

case('UC-ADM-11.1', 'Tin đã xuất bản, dấu xác minh chủ trọ hoặc kiểm tra phòng, căn cứ ít nhất 10 ký tự và thông tin lần cập nhật gần nhất.',
     'Quản trị viên mở tin đã xuất bản.|Quản trị viên chọn nội dung xác minh và nhập căn cứ.|Hệ thống kiểm tra quyền, căn cứ, trạng thái tin và việc tin chưa thay đổi.|Hệ thống cập nhật dấu xác minh, ghi lịch sử và trả tin đã cập nhật.', '',
     'B3: Căn cứ quá ngắn, tin chưa xuất bản hoặc đã thay đổi: không cập nhật dấu xác minh; yêu cầu bổ sung hoặc tải lại tin.',
     'Dấu xác minh tin đăng không thay thế kết quả xét duyệt hồ sơ chủ trọ hoặc hồ sơ khu trọ.', 'Dấu xác minh trên tin được thêm hoặc gỡ theo yêu cầu hợp lệ.')

case('UC-ADM-12', 'Đánh giá hoặc phản hồi cần duyệt, kết quả duyệt, ghi chú và thông tin lần cập nhật gần nhất.',
     'Quản trị viên mở hàng chờ đánh giá hoặc hàng chờ phản hồi.|Hệ thống trình nội dung đúng loại; phản hồi phải có nội dung và gắn với đánh giá đang công khai, chưa bị rút.|Quản trị viên chọn duyệt, từ chối hoặc ẩn; hệ thống kiểm tra hồ sơ chưa thay đổi và nội dung chưa bị người thuê rút.|Hệ thống lưu quyết định cho đúng phần đánh giá hoặc phản hồi, ghi người xử lý, thời điểm và trả kết quả.', '',
     'B3: Nội dung đã bị rút, phản hồi không còn hoặc đánh giá gốc không còn công khai: không duyệt công khai; yêu cầu xem lại hồ sơ.|B3: Hồ sơ đã thay đổi hoặc chọn lại trạng thái hiện tại: không ghi đè kết quả.',
     'Đánh giá và phản hồi có kết quả kiểm duyệt riêng.|Không khôi phục công khai thay người thuê khi họ đã rút đánh giá.', 'Phần nội dung được chọn có kết quả kiểm duyệt và lịch sử tương ứng.')

case('UC-ADM-12.1', 'Báo cáo vi phạm, kết quả giải quyết hoặc bác bỏ, ghi chú và thông tin lần cập nhật nếu có.',
     'Quản trị viên mở báo cáo vi phạm và tin liên quan.|Quản trị viên xem xét, chọn kết quả xử lý và nhập ghi chú.|Hệ thống kiểm tra báo cáo còn mở và thông tin chưa thay đổi nếu có yêu cầu đối chiếu.|Hệ thống ghi kết quả, thời điểm và lịch sử quyết định; trả báo cáo đã xử lý.', '',
     'B3: Báo cáo đã được xử lý hoặc đã thay đổi: không ghi đè; yêu cầu xem kết quả mới nhất.',
     'Kết thúc báo cáo vi phạm không tự động ẩn hay xóa tin; việc xử lý tin là mục tiêu riêng.', 'Báo cáo vi phạm có kết quả giải quyết hoặc bác bỏ.')

case('UC-ADM-13.1', 'Loại chính sách, tiêu đề, nội dung và phiên bản chính sách cần kích hoạt.',
     'Quản trị viên xem danh mục chính sách kiểm duyệt.|Quản trị viên tạo bản nháp với loại và nội dung phù hợp.|Khi kích hoạt, hệ thống kiểm tra bản chính sách đang là bản nháp.|Hệ thống ngừng hiệu lực bản đang áp dụng cùng loại, kích hoạt bản đã chọn và ghi người thực hiện, thời điểm.',
     'B1: Chỉ xem danh mục: hệ thống trả tối đa 100 bản; không đổi chính sách; kết thúc.',
     'B3: Không tìm thấy chính sách hoặc bản đã được sử dụng: không kích hoạt lại.',
     'Mỗi loại chỉ duy trì bản có hiệu lực thông qua thay thế bản trước.|Chính sách mới không sửa lại lịch sử quyết định đã ban hành.', 'Bản nháp được tạo hoặc bản chính sách đã chọn được đưa vào áp dụng.')

case('UC-ADM-13.2', 'Kháng nghị, người phụ trách, kết quả xem xét, lý do và thông tin lần cập nhật gần nhất.',
     'Quản trị viên mở kháng nghị và lịch sử quyết định liên quan.|Quản trị viên nhận hoặc phân công xử lý; hệ thống kiểm tra kháng nghị còn mở, người nhận đủ quyền và không phải người quyết định ban đầu.|Người được giao xem xét và đưa ra kết quả; hệ thống kiểm tra tính độc lập và hồ sơ chưa thay đổi.|Hệ thống ghi kết quả; nếu mở lại, đưa nội dung đủ điều kiện về chờ duyệt hoặc đưa báo cáo bị bác về trạng thái mở; thông báo cho người kháng nghị.',
     'B4: Giữ nguyên hoặc ghi nhận quyết định đã được thay thế theo kết quả được phép: chốt kháng nghị, không tự thay đổi việc áp dụng quyết định.',
     'B3: Người quyết định ban đầu tự xét hoặc người xử lý không đúng phân công: từ chối xử lý.|B4: Nội dung đã thay đổi hoặc đã bị rút: không ghi đè nội dung mới.',
     'Người xem xét phải độc lập với người ra quyết định ban đầu.|Mở lại chỉ đưa nội dung về chờ xem xét, không trực tiếp công khai nội dung.', 'Kháng nghị có kết quả; nội dung có thể được đưa về hàng chờ xem xét.')

case('UC-ADM-13.3', 'Khoảng ngày tối đa 93 ngày, múi giờ, loại nội dung, quyết định được chọn, nhận xét chất lượng và thông tin lần cập nhật.',
     'Quản trị viên mở báo cáo chất lượng và danh sách quyết định cần đánh giá.|Hệ thống kiểm tra quyền, khoảng thời gian, múi giờ và loại nội dung được phép.|Quản trị viên mở một quyết định; hệ thống kiểm tra người đánh giá khác người quyết định ban đầu.|Quản trị viên ghi kết quả đánh giá; hệ thống kiểm tra chưa có đánh giá và hồ sơ chưa thay đổi rồi lưu kết quả.',
     'B2: Không có loại nội dung thuộc quyền được giao: trả danh sách rỗng; không mở rộng quyền.',
     'B2: Khoảng ngày hoặc múi giờ không hợp lệ: không lập báo cáo.|B3: Tự đánh giá quyết định của mình, hoặc B4 quyết định đã được đánh giá hay đã thay đổi: không ghi đánh giá mới.',
     'Đánh giá chất lượng độc lập với quyết định kiểm duyệt.|Kết quả đánh giá không tự thay trạng thái nội dung hoặc áp dụng chế tài.', 'Có báo cáo hoặc nhận xét chất lượng; quyết định áp dụng đối với nội dung không tự thay đổi.')

case('UC-DIS-07', 'Tin phòng cần báo cáo, lý do và mô tả chi tiết.',
     'Người tìm phòng hoặc người thuê chọn báo cáo tin không phù hợp.|Hệ thống kiểm tra tin và quyền gửi báo cáo.|Người sử dụng gửi lý do; hệ thống ghi báo cáo gắn với người gửi.|Hệ thống trả mã báo cáo và trạng thái chờ xử lý.', '',
     'B3: Người sử dụng đã báo cáo tin này: không tạo bản sao; thông báo báo cáo đã tồn tại.',
     'Một người không tạo nhiều báo cáo cho cùng tin.|Gửi báo cáo không lập tức ẩn tin hoặc kết luận tin vi phạm.', 'Báo cáo được ghi nhận để quản trị viên xem xét.')

case('UC-DIS-12', 'Hợp đồng hoặc đánh giá hiện có, bốn điểm đánh giá, nội dung và thông tin lần cập nhật khi sửa.',
     'Người thuê mở phần đánh giá gắn với lịch sử thuê của mình.|Hệ thống kiểm tra điều kiện lịch sử thuê: đã xác nhận bàn giao hoặc hợp đồng đã kết thúc theo trường hợp được phép.|Người thuê nhập điểm và nhận xét; hệ thống kiểm tra chưa có đánh giá cho cùng người thuê, phòng và chủ trọ.|Hệ thống lưu đánh giá chờ kiểm duyệt và cho người thuê xem kết quả.',
     'B3: Sửa đánh giá của mình: kiểm tra thông tin chưa thay đổi, cập nhật điểm và nhận xét, đưa về chờ duyệt; kết thúc.|B3: Rút đánh giá: kiểm tra chưa rút và hồ sơ chưa thay đổi, ẩn đánh giá và ghi nhận việc rút; kết thúc.',
     'B2: Không có lịch sử thuê đủ điều kiện: không tạo đánh giá.|B3: Đã có đánh giá cùng người thuê, phòng và chủ trọ: không tạo thêm; hướng dẫn sửa đánh giá đã có.',
     'Tài khoản chỉ tìm phòng chưa có lịch sử thuê không đủ điều kiện viết đánh giá.|Đánh giá sửa lại phải được duyệt lại.|Người thuê chỉ sửa hoặc rút đánh giá của mình.', 'Đánh giá được lưu chờ duyệt hoặc được rút theo lựa chọn hợp lệ.')

case('UC-DIS-13.1', 'Đánh giá thuộc phạm vi chủ trọ, nội dung phản hồi và thông tin lần cập nhật gần nhất.',
     'Chủ trọ mở đánh giá đã được duyệt, đang công khai và chưa bị người thuê rút.|Chủ trọ nhập phản hồi.|Hệ thống kiểm tra đánh giá vẫn đủ điều kiện, thuộc phạm vi quản lý và chưa thay đổi.|Hệ thống lưu phản hồi chờ kiểm duyệt rồi trả kết quả cho chủ trọ.', '',
     'B3: Đánh giá không còn công khai, đã bị rút hoặc đã thay đổi: không gửi phản hồi; yêu cầu xem lại.',
     'Phản hồi không công khai ngay sau khi gửi.|Chủ trọ không được sửa điểm hoặc nội dung đánh giá của người thuê.', 'Phản hồi được lưu chờ kiểm duyệt.')

case('UC-DIS-15', 'Quyết định liên quan đến mình, lý do kháng nghị hoặc bộ lọc tra cứu lịch sử.',
     'Chủ trọ hoặc người thuê xem quyết định thuộc phạm vi của mình.|Người sử dụng chọn kháng nghị; hệ thống kiểm tra quyết định bất lợi thuộc loại từ chối, ẩn hoặc bác bỏ và được ban hành trong 14 ngày.|Hệ thống kiểm tra chưa có quyết định thay thế và chưa có kháng nghị của người này cho cùng quyết định.|Hệ thống tạo kháng nghị chờ xử lý với hạn xem xét sau 72 giờ và thông báo người đủ quyền tiếp nhận.',
     'B1: Chỉ xem quyết định hoặc kháng nghị: trả thông tin thuộc phạm vi người sử dụng; không tạo kháng nghị; kết thúc.',
     'B2: Quyết định không thuộc loại được kháng nghị hoặc đã quá 14 ngày: không tiếp nhận.|B3: Quyết định đã được thay thế hoặc đã được người này kháng nghị: không tạo thêm.',
     'Nhân viên vận hành không được thực hiện mục tiêu này.|Quản trị viên chỉ có phạm vi xem liên quan đến chính mình; không mặc nhiên kháng nghị thay chủ trọ hoặc người thuê.', 'Kháng nghị chờ người xử lý độc lập hoặc lịch sử được cung cấp đúng phạm vi.')

case('UC-SUP-01', 'Tiêu đề, nội dung, loại yêu cầu, mức ưu tiên, ngữ cảnh; hồ sơ đang theo dõi và thông tin lần cập nhật khi trả lời; tệp nếu đính kèm.',
     'Người sử dụng gửi yêu cầu khi chức năng hỗ trợ đang được mở.|Hệ thống tạo hồ sơ và nội dung đầu tiên, ghi nhận thời hạn xử lý, phân công và thông báo theo thiết lập.|Người gửi theo dõi hồ sơ của mình; hệ thống chỉ trình nội dung được phép công khai.|Người gửi trả lời; hệ thống kiểm tra hồ sơ chưa thay đổi và còn cho phép trao đổi rồi lưu nội dung, cập nhật hồ sơ và thông báo bên xử lý.',
     'B4: Hồ sơ đã giải quyết chưa quá 7 ngày: phản hồi của người gửi mở lại hồ sơ; tiếp tục lưu tại B4.|B3: Đính kèm tệp: chỉ nhận ảnh JPEG, PNG, WEBP hoặc PDF tối đa 8 MB, tối đa 20 tệp mỗi hồ sơ; chỉ ghi nhận khi tệp đã qua kiểm tra an toàn; kết thúc nhánh.',
     'B4: Hồ sơ đã đóng hoặc đã giải quyết quá 7 ngày: không nhận phản hồi; hướng dẫn tạo yêu cầu mới.|B3: Không kiểm tra được an toàn tệp, tệp không an toàn hoặc sai loại: không nhận tệp đính kèm.',
     'Chỉ người gửi được xem hồ sơ theo phạm vi của mình; ghi chú nội bộ không hiển thị cho họ.|Nhân viên vận hành không được thực hiện mục tiêu này.|Chưa xác nhận vận hành thực tế của việc kiểm tra an toàn tệp.', 'Yêu cầu hoặc phản hồi được ghi nhận; việc nhận tệp phụ thuộc kết quả kiểm tra an toàn.')

case('UC-SUP-01.1', 'Bộ lọc hồ sơ, người hoặc nhóm phụ trách, mức ưu tiên, trạng thái, lý do, nội dung trao đổi, liên kết hồ sơ nghiệp vụ và thông tin lần cập nhật.',
     'Quản trị viên đủ quyền mở hồ sơ hỗ trợ và lịch sử xử lý.|Quản trị viên nhận hoặc phân công; hệ thống kiểm tra người nhận đang hoạt động, có quyền hỗ trợ, thuộc nhóm nếu chọn và hồ sơ chưa thay đổi.|Quản trị viên trao đổi công khai, ghi chú nội bộ hoặc liên kết hồ sơ nghiệp vụ; hệ thống kiểm tra quyền và phạm vi người gửi.|Quản trị viên chuyển trạng thái theo quy định; hệ thống cập nhật thời hạn, lịch sử, thông tin hồ sơ và thông báo người gửi.',
     'B3: Nhận tệp: áp dụng giới hạn loại tệp, 8 MB, 20 tệp và điều kiện kiểm tra an toàn; tệp nội bộ chỉ người xử lý đủ quyền được xem.|B3: Liên kết đã có: thông báo đã liên kết, không tạo bản sao.',
     'B2: Không đủ quyền phân công người khác, người nhận sai nhóm hoặc hồ sơ đã thay đổi: không phân công.|B4: Chuyển trạng thái ngoài quy định hoặc hồ sơ đã đóng: không thay đổi.',
     'Trạng thái mở được chuyển sang đang xử lý hoặc đã giải quyết; đang xử lý có thể chờ người gửi hoặc đã giải quyết; chờ người gửi có thể trở lại đang xử lý; đã giải quyết có thể mở lại hoặc đóng.|Hồ sơ đã đóng không có bước chuyển tiếp.|Tối đa 50 liên kết hồ sơ nghiệp vụ; liên kết không tự sửa nội dung hồ sơ được dẫn chiếu.|Ghi chú nội bộ không gửi cho người yêu cầu; nhân viên vận hành không được xử lý hỗ trợ.', 'Hồ sơ hỗ trợ và lịch sử được cập nhật theo quyền; thông tin nghiệp vụ liên kết không tự thay đổi.')

case('UC-SUP-02.1', 'Người tiếp nhận, nhóm chuyên môn, số hồ sơ mở tối đa và hồ sơ cần tự động phân công.',
     'Quản trị viên mở thông tin chuyên môn hỗ trợ.|Quản trị viên đặt chuyên môn và năng lực tiếp nhận; hệ thống kiểm tra người nhận đang hoạt động và đủ quyền hỗ trợ.|Quản trị viên yêu cầu phân công tự động; hệ thống kiểm tra quyền quản lý quản trị viên và hỗ trợ, lựa chọn người phù hợp chuyên môn còn khả năng tiếp nhận.|Hệ thống ghi phân công và trả kết quả.', '',
     'B2: Không có người nhận đủ điều kiện hoặc B3 không còn khả năng tiếp nhận: không phân công tùy ý.',
     'Người xử lý hỗ trợ là quản trị viên có quyền tương ứng, không phải một loại tài khoản mới.', 'Chuyên môn hoặc phân công hỗ trợ được ghi nhận.')

case('UC-SUP-02.2', 'Lịch làm việc, múi giờ, ngày nghỉ, thời hạn phản hồi và giải quyết theo mức ưu tiên, mốc chuyển cấp và thông tin lần cập nhật.',
     'Quản trị viên mở chính sách thời hạn hỗ trợ.|Hệ thống trình chính sách đang lưu hoặc giá trị mặc định.|Quản trị viên chỉnh sửa; hệ thống kiểm tra mỗi khung làm việc ít nhất 60 phút và không qua nửa đêm, ngày nghỉ hợp lệ, mốc chuyển cấp bắt đầu từ 0 và tăng dần, thời hạn giải quyết không ngắn hơn thời hạn phản hồi.|Hệ thống kiểm tra chính sách chưa thay đổi rồi lưu và thông báo chính sách chỉ áp dụng cho hồ sơ mới.', '',
     'B3: Lịch hoặc mốc thời gian không hợp lệ, hoặc B4 chính sách đã thay đổi: không ghi đè; yêu cầu sửa hoặc xem lại.',
     'Chính sách mới không tự tính lại hạn xử lý của hồ sơ đã có.', 'Chính sách thời hạn hỗ trợ mới được lưu cho những hồ sơ tạo sau đó.')

case('UC-SUP-03.2', 'Tên mẫu, nội dung, tình trạng sử dụng, lý do và thông tin lần cập nhật khi sửa.',
     'Quản trị viên mở danh sách mẫu trả lời.|Quản trị viên tạo hoặc sửa mẫu; hệ thống kiểm tra tên chưa trùng, mẫu tồn tại và chưa thay đổi khi sửa.|Hệ thống lưu mẫu và ghi lịch sử thay đổi.|Hệ thống trả mẫu để sử dụng khi soạn trả lời.', '',
     'B2: Tên đã có hoặc mẫu đã thay đổi: không ghi đè; yêu cầu chọn tên khác hoặc xem lại.',
     'Lưu mẫu không tự gửi câu trả lời vào hồ sơ hỗ trợ.|Không xác định có chức năng xóa vĩnh viễn mẫu; có thể thay tình trạng sử dụng.', 'Mẫu trả lời được ghi nhận hoặc cập nhật.')

case('UC-SUP-03.2.1', 'Hồ sơ nguồn, hồ sơ đích, lý do và thông tin lần cập nhật của cả hai hồ sơ.',
     'Quản trị viên chọn hai hồ sơ cần hợp nhất.|Hệ thống kiểm tra hai hồ sơ khác nhau, cùng người gửi, chưa hợp nhất, chưa giải quyết hoặc đóng và chưa thay đổi.|Hệ thống chuyển nội dung trao đổi và tệp của hồ sơ nguồn sang hồ sơ đích.|Hệ thống đóng hồ sơ nguồn, ghi nơi chuyển đến, cập nhật cả hai hồ sơ và trả kết quả.', '',
     'B2: Khác người gửi, đã đóng, đã hợp nhất hoặc đã thay đổi: không chuyển nội dung hay tệp.',
     'Phạm vi hợp nhất đã xác định gồm nội dung trao đổi và tệp; không mặc định mọi thông tin liên quan đều được chuyển.', 'Hồ sơ nguồn đã đóng; nội dung trao đổi và tệp được tập trung tại hồ sơ đích.')

case('UC-SUP-03.2.2', 'Hồ sơ hỗ trợ, điểm đánh giá và ý kiến về kết quả hỗ trợ.',
     'Người gửi mở hồ sơ hỗ trợ của mình.|Hệ thống kiểm tra người đánh giá chính là người gửi yêu cầu.|Hệ thống kiểm tra hồ sơ đã giải quyết hoặc đóng, chưa hợp nhất và chưa được đánh giá.|Hệ thống lưu điểm, nội dung, thời điểm đánh giá và trả kết quả.', '',
     'B2: Không phải người gửi: không cho đánh giá thay.|B3: Chưa giải quyết, đã đánh giá hoặc đã hợp nhất: không ghi đánh giá mới.',
     'Mỗi hồ sơ đủ điều kiện chỉ nhận một đánh giá.|Quản trị viên chỉ đánh giá khi chính mình là người gửi yêu cầu.', 'Một đánh giá kết quả hỗ trợ được ghi nhận.')

case('UC-SUP-03.3', 'Tên bộ lọc, điều kiện lọc, lý do và thông tin lần cập nhật khi sửa hoặc xóa.',
     'Quản trị viên mở các bộ lọc hỗ trợ đã lưu của mình.|Quản trị viên tạo hoặc sửa; hệ thống kiểm tra điều kiện hợp lệ, tên chưa trùng, quyền sở hữu và thông tin chưa thay đổi; khi tạo phải chưa đạt 50 bộ lọc.|Hệ thống lưu bộ lọc riêng của quản trị viên.|Hệ thống trả bộ lọc để áp dụng khi tìm hồ sơ.',
     'B2: Xóa bộ lọc: kiểm tra đúng chủ sở hữu và thông tin chưa thay đổi rồi xóa; không xóa hồ sơ hỗ trợ.',
     'B2: Đủ 50 bộ lọc, trùng tên, không thuộc mình hoặc đã thay đổi: không ghi nhận.',
     'Bộ lọc chỉ giúp tra cứu, không mở rộng quyền xem hồ sơ.', 'Bộ lọc cá nhân được lưu, cập nhật hoặc xóa theo lựa chọn.')

case('UC-ADM-18', 'Hồ sơ xác minh chủ trọ, kết quả chấp thuận, từ chối hoặc yêu cầu bổ sung, lý do và thông tin lần cập nhật.',
     'Quản trị viên mở danh sách và hồ sơ xác minh.|Hệ thống kiểm tra hồ sơ hỗ trợ chứa minh chứng không thay đổi và người xét không tự duyệt yêu cầu của mình.|Hệ thống kiểm tra hồ sơ đang chờ xét, chưa thay đổi; khi chấp thuận, chủ trọ phải hoạt động và minh chứng riêng tư, đúng người gửi, đã qua kiểm tra an toàn.|Hệ thống ghi kết quả, người xét, thời điểm và lý do; trả hồ sơ.',
     'B3: Từ chối hoặc yêu cầu bổ sung: ghi kết quả và lý do tại B4; không ghi nhận đã xác minh.',
     'B2: Tự duyệt, minh chứng đã thay đổi, hoặc B3 sai trạng thái, hồ sơ cũ, minh chứng chưa hợp lệ: không chấp thuận.',
     'Xác minh chủ trọ khác với dấu xác minh trên tin đăng.|Có minh chứng trong hồ sơ chưa đủ chứng minh việc kiểm tra an toàn tệp đã vận hành thực tế.', 'Hồ sơ xác minh chủ trọ có kết quả xét duyệt.')

case('UC-ADM-18.1', 'Chủ trọ được xác minh, hồ sơ hỗ trợ chứa minh chứng và thông tin lần cập nhật khi nộp lại.',
     'Chủ trọ mở hồ sơ của mình hoặc quản trị viên chọn hỗ trợ nộp hồ sơ cho chủ trọ.|Hệ thống kiểm tra chủ trọ đang hoạt động, hồ sơ hỗ trợ thuộc chủ trọ và có minh chứng riêng tư đã qua kiểm tra an toàn.|Hệ thống kiểm tra hồ sơ chưa thay đổi; chỉ nhận lần đầu hoặc nộp lại sau yêu cầu bổ sung hay từ chối.|Hệ thống ghi hồ sơ chờ xét duyệt và trả kết quả.',
     'B1: Chủ trọ chỉ xem hồ sơ hiện tại: cung cấp thông tin, không nộp lại hay tự duyệt; kết thúc.',
     'B2: Thiếu minh chứng hợp lệ hoặc B3 hồ sơ đang chờ, đã chấp thuận hay đã thay đổi: không nhận bản trùng.',
     'Chủ trọ không có quyền xét duyệt hồ sơ của mình.|Hệ thống không bắt buộc người xét khác quản trị viên đã hỗ trợ nộp; quản trị viên đó vẫn có thể xét nếu đủ quyền và điều kiện. Điều kiện không tự duyệt chỉ đối chiếu tài khoản người xét với chủ trọ được xác minh.', 'Hồ sơ ở trạng thái chờ xét; chưa mặc nhiên được xác minh.')

case('UC-ADM-19', 'Khu trọ, hồ sơ trình xét, kết quả, lý do và thông tin lần cập nhật.',
     'Quản trị viên có quyền quản lý khu trọ chọn trình hồ sơ của khu đang hoạt động.|Hệ thống ghi nhận nội dung khu tại thời điểm trình, kiểm tra hồ sơ chưa thay đổi và chưa có bản chờ hoặc đã duyệt cho cùng nội dung.|Quản trị viên xét hồ sơ; hệ thống kiểm tra còn chờ, chưa thay đổi, khu chưa ngừng quản lý và nội dung khu còn khớp bản đã trình.|Hệ thống ghi kết quả, người xét, thời điểm và trả hồ sơ.',
     'B2: Nội dung khu đã thay đổi so với hồ sơ cũ: có thể trình bản mới nếu đáp ứng điều kiện; tiếp tục B3.',
     'B3: Khu hoặc nội dung đã thay đổi: không duyệt hồ sơ cũ; yêu cầu trình lại.',
     'Trong phạm vi đã xác minh, chủ trọ chưa có chức năng tự trình hồ sơ khu này.|Duyệt khu trọ không tự gắn dấu xác minh cho tin đăng.', 'Hồ sơ khu trọ ghi đúng nội dung được trình và kết quả xét duyệt.')

case('UC-ADM-20', 'Mã, tên, giá, hạn mức khu và phòng, tình trạng sử dụng, lý do và thông tin lần cập nhật gói.',
     'Quản trị viên mở danh mục gói dịch vụ.|Hệ thống kiểm tra quyền xem hoặc quản lý và trình điều kiện, hạn mức của gói.|Quản trị viên tạo hoặc sửa gói; hệ thống kiểm tra gói miễn phí có giá bằng 0, mã chưa trùng và thông tin chưa thay đổi.|Hệ thống lưu gói, ghi lịch sử và trả kết quả.', '',
     'B3: Gói miễn phí có giá dương, mã bị trùng hoặc gói đã thay đổi: không ghi đè.',
     'Gói được quản lý để cấp quyền sử dụng và hạn mức bằng nghiệp vụ quản trị.|Chưa xác minh quy trình mua, thu tiền gói hoặc ghi doanh thu nền tảng.', 'Điều kiện và hạn mức gói được lưu; không phát sinh thanh toán mua gói.')

case('UC-ADM-21', 'Chủ trọ, gói được chọn, ngày hết hạn nếu có, lý do và thông tin lần cập nhật gói, quyền sử dụng.',
     'Quản trị viên xem quyền sử dụng gói của chủ trọ và chọn gói cần gán.|Hệ thống kiểm tra chủ trọ và gói đang hoạt động, gói chưa thay đổi và ngày hết hạn ở tương lai nếu có.|Hệ thống kiểm tra quyền sử dụng chưa thay đổi và số khu, phòng hiện có không vượt hạn mức của gói.|Hệ thống ghi quyền sử dụng theo điều kiện gói tại thời điểm gán, lưu lịch sử và trả kết quả.',
     'B1: Chỉ xem lịch sử: cung cấp các lần thay đổi của quyền sử dụng đã có; không gán lại gói.',
     'B2: Gói hoặc ngày hết hạn không hợp lệ, hoặc B3 vượt hạn mức hay dữ liệu đã thay đổi: không gán gói; không xóa khu, phòng để giảm số lượng.',
     'Hạn mức được áp dụng khi chủ trọ đã được gán gói.|Gói hết hạn chặn việc tăng khu, phòng; không xóa dữ liệu hiện có.|Gán gói là nghiệp vụ quản trị, chưa xác minh có thanh toán mua gói.', 'Chủ trọ được gán quyền sử dụng gói và có lịch sử thay đổi.')

case('UC-ADM-22', 'Quyền sử dụng gói cần hủy, lý do và thông tin lần cập nhật.',
     'Quản trị viên chọn quyền sử dụng gói cần kết thúc.|Hệ thống xác định chủ trọ và kiểm tra thông tin chưa thay đổi.|Hệ thống kiểm tra gói chưa hết hạn rồi đặt thời điểm kết thúc là hiện tại.|Hệ thống ghi lần hủy trong lịch sử và trả kết quả.', '',
     'B2: Không tìm thấy hoặc đã thay đổi, hoặc B3 đã hết hạn: không ghi thêm lần hủy.',
     'Hủy gói không hoàn tiền, không xóa khu hoặc phòng.|Chưa xác minh có nghiệp vụ thu tiền gói để phát sinh hoàn trả.', 'Quyền sử dụng gói kết thúc tại thời điểm hủy.')

case('UC-ADM-15', 'Khu trọ, tài khoản đối soát, mã lần nhập, các dòng sao kê gồm mã giao dịch, số tiền, ngày phát sinh, diễn giải; đề xuất ghép, bỏ ghép hoặc đánh dấu, lý do và thông tin lần cập nhật.',
     'Quản trị viên chọn sao kê đã có từ bên ngoài để nhập.|Hệ thống kiểm tra ngày, mã giao dịch chưa trùng, mã lần nhập và nội dung tương ứng; tài khoản đối soát không được thuộc khu khác.|Hệ thống lưu sao kê; chỉ tự ghép với khoản thu đã có khi đủ căn cứ, còn lại để chờ rà soát.|Quản trị viên xem các khoản có thể ghép và lập đề xuất; hệ thống kiểm tra dòng chưa thay đổi, chưa có đề xuất chờ duyệt, khoản thu đúng khu và số tiền trước khi lưu.',
     'B2: Cùng mã lần nhập và cùng nội dung: trả kết quả đã nhập, không nhập lại.|B3: Chưa có căn cứ ghép chắc chắn: giữ dòng chưa ghép để rà soát tại B4; không tạo khoản thu mới.',
     'B2: Mã lần nhập dùng cho nội dung khác, tài khoản thuộc khu khác hoặc mã giao dịch đã có: không nhập trùng.|B4: Khoản thu sai điều kiện, đã ghép, đang có đề xuất hoặc dòng đã thay đổi: không lưu đề xuất.',
     'Nhập sao kê không kết nối ngân hàng, không tự thu tiền.|Ghép chỉ tham chiếu khoản thu đã tồn tại; việc lập đề xuất không thay đổi số tiền đã ghi nhận.', 'Sao kê hoặc đề xuất đối soát được lưu; không tự phát sinh khoản thu.')

case('UC-ADM-15.1', 'Đề xuất đối soát, quyết định duyệt hoặc từ chối, lý do và thông tin lần cập nhật dòng sao kê.',
     'Quản trị viên độc lập mở đề xuất đang chờ duyệt.|Hệ thống kiểm tra người duyệt khác người lập và dòng sao kê chưa thay đổi so với đề xuất.|Khi duyệt ghép, hệ thống kiểm tra lại khoản chuyển khoản thật hoặc biên nhận hợp lệ, cùng khu, đúng số tiền, chưa đảo, chưa ghép và đáp ứng điều kiện phân bổ.|Hệ thống ghi kết quả ghép, bỏ ghép hoặc cần rà soát theo đề xuất, chốt kết quả duyệt và lưu lịch sử.',
     'B3: Từ chối đề xuất: ghi lý do và kết quả từ chối, không thay đổi việc ghép dòng sao kê.',
     'B2: Người lập tự duyệt hoặc dòng đã thay đổi, hoặc B3 khoản thu không còn hợp lệ: không duyệt ghép.',
     'Áp dụng nguyên tắc người lập và người duyệt độc lập.|Duyệt đối soát không tự tạo khoản thu hoặc sửa số tiền của khoản thu gốc.', 'Đề xuất có kết quả; dòng sao kê được cập nhật nếu được duyệt.')

case('UC-ADM-17.1', 'Tính năng trong danh mục, tình trạng bật tắt, tỷ lệ áp dụng, vai trò áp dụng, lý do và thông tin lần cập nhật.',
     'Quản trị viên mở danh sách tính năng và trạng thái áp dụng.|Hệ thống kiểm tra quyền cấu hình và tính năng thuộc danh mục cho phép.|Quản trị viên lưu lựa chọn; hệ thống kiểm tra cấu hình chưa thay đổi.|Hệ thống lưu điều kiện áp dụng, ghi lịch sử và trả cấu hình.',
     'B1: Chỉ xem trạng thái áp dụng: cung cấp kết quả theo người sử dụng và vai trò; không đổi cấu hình.',
     'B2: Tính năng ngoài danh mục hoặc B3 cấu hình đã thay đổi: không ghi đè.',
     'Bật tính năng không thay thế điều kiện đăng nhập và quyền nghiệp vụ.|Tỷ lệ áp dụng không phải là quyền sử dụng chức năng.', 'Cấu hình tính năng được lưu hoặc trạng thái áp dụng được cung cấp.')

case('UC-ADM-17.2', 'Tên, mô tả, tình trạng nhóm; thành viên và vai trò trong nhóm; lý do và thông tin lần cập nhật.',
     'Quản trị viên xem nhóm và thành viên; hệ thống che bớt địa chỉ thư điện tử khi trình thông tin.|Quản trị viên tạo hoặc sửa nhóm; hệ thống kiểm tra nhóm chưa thay đổi khi sửa.|Quản trị viên thêm hoặc cập nhật thành viên; hệ thống yêu cầu nhóm đang hoạt động và thành viên là quản trị viên đang hoạt động.|Hệ thống lưu nhóm hoặc thành viên, ghi lịch sử và yêu cầu rà soát lại quyền khi thành viên thay đổi.',
     'B3: Xóa thành viên: chỉ cho phép khi người này không còn hồ sơ hỗ trợ chưa giải quyết trong nhóm; sau khi xóa, yêu cầu rà soát lại quyền.',
     'B2: Nhóm đã thay đổi, hoặc B3 người hay nhóm không hợp lệ: không ghi nhận thành viên.|B3: Thành viên còn hồ sơ hỗ trợ chưa giải quyết hoặc đóng: không xóa; cần chuyển hồ sơ trước.',
     'Tham gia nhóm không tự cấp thêm quyền quản trị ngoài bộ quyền cá nhân.', 'Nhóm hoặc thành viên được cập nhật; mốc rà soát quyền được đặt lại khi đổi thành viên.')

case('UC-ADM-23', 'Mã, tên cơ sở trường, địa bàn, tọa độ, tình trạng sử dụng và đánh dấu dữ liệu minh họa.',
     'Quản trị viên mở danh mục cơ sở trường.|Hệ thống trả danh sách quản trị, xếp dữ liệu minh họa sau dữ liệu thường rồi theo địa bàn và tên.|Quản trị viên tạo hoặc sửa; hệ thống kiểm tra thông tin hợp lệ và cơ sở tồn tại khi sửa.|Hệ thống lưu và trả cơ sở trường.',
     'B3: Ngừng sử dụng: cập nhật tình trạng, không xóa lịch sử; danh mục công khai chỉ hiển thị cơ sở đang hoạt động.',
     'B3: Không tìm thấy cơ sở cần sửa: không tạo đè thành cơ sở mới.',
     'Không xác định có chức năng xóa vĩnh viễn cơ sở trường.', 'Danh mục cơ sở trường được cập nhật để phục vụ tìm phòng.')

case('UC-ADM-24', 'Loại giao dịch, trạng thái, khoảng ngày, phạm vi tra cứu và trang kết quả; điều kiện đối chiếu tổng hợp khi yêu cầu.',
     'Quản trị viên chọn tra khoản thanh toán, liên kết thanh toán hoặc thông báo kết quả thanh toán.|Hệ thống kiểm tra quyền xem tài chính, khoảng tra tối đa 93 ngày và trạng thái phù hợp loại giao dịch.|Hệ thống cung cấp danh sách; khi đối chiếu tổng hợp, kiểm tra kỳ tối đa 366 ngày và mỗi tập không quá 5.000 dòng.|Hệ thống đối chiếu hóa đơn, khoản thu có căn cứ, tiền cọc và chi phí rồi trình các chênh lệch.',
     'B3: Không có giao dịch trong kỳ: trả danh sách rỗng và tổng tương ứng bằng 0; không tạo giao dịch.',
     'B2: Ngày hoặc trạng thái không hợp lệ, hoặc B3 quá giới hạn dòng: không coi kết quả bị cắt là báo cáo đầy đủ; yêu cầu thu hẹp phạm vi.',
     'Đây là tra cứu và đối chiếu chỉ đọc, không thay thế quy trình đối soát sao kê có người lập và người duyệt.|Kết quả chênh lệch không cho phép tự sửa tiền từ báo cáo.', 'Danh sách giao dịch hoặc kết quả đối chiếu được cung cấp; số tiền gốc không thay đổi.')

case('UC-ADM-26', 'Bộ quyền quản trị và quyền cần kiểm tra nếu có.',
     'Quản trị viên chọn bộ quyền cần mô phỏng.|Hệ thống kiểm tra quyền sử dụng công cụ mô phỏng.|Hệ thống xác định các quyền trong bộ đã chọn và đối chiếu quyền cần kiểm tra.|Hệ thống trả kết quả có hoặc không có quyền theo bộ đã chọn, kèm giới hạn của kết quả.',
     'B3: Không chọn quyền cần kiểm tra: chỉ trả danh sách quyền; không kết luận người dùng đã được cấp một quyền cụ thể.',
     'B2: Không đủ quyền dùng công cụ hoặc bộ quyền không hợp lệ: không thực hiện mô phỏng.',
     'Mô phỏng không cấp quyền thật, không bỏ qua xác minh nhiều yếu tố, tình trạng tài khoản hoặc phạm vi nghiệp vụ.', 'Có kết quả mô phỏng; quyền thật không thay đổi.')

case('UC-ADM-27', 'Bộ lọc phản hồi thử nghiệm tìm phòng và trang kết quả.',
     'Quản trị viên mở phản hồi thử nghiệm tìm phòng.|Hệ thống kiểm tra quyền xem phản hồi.|Hệ thống lấy phản hồi và tổng hợp theo bộ lọc, trang được yêu cầu.|Hệ thống trả danh sách, thông tin tổng hợp và số trang.',
     'B3: Chưa có phản hồi: trả danh sách rỗng và tổng tương ứng; không tạo phản hồi.',
     'B2: Không đủ quyền hoặc điều kiện lọc không hợp lệ: không cung cấp dữ liệu ngoài quyền.',
     'Đọc phản hồi không tự mở khu vực thử nghiệm hoặc gửi phản hồi thay người khác.', 'Phản hồi thử nghiệm được cung cấp ở chế độ xem.')


case('UC-DIS-01', 'Từ khóa, địa bàn, khoảng giá, tiện ích, cơ sở trường, bán kính, ngân sách và mức điện nước dự kiến; lựa chọn sắp xếp và trang kết quả.',
     'Người tìm phòng nhập hoặc thay đổi tiêu chí tìm kiếm.|Hệ thống chọn các tin được công khai, phòng đang hoạt động và còn trống, thuộc khu và chủ trọ đang hoạt động.|Hệ thống lọc theo tiêu chí; nếu có ngân sách, tính cả tiền thuê, dịch vụ, gửi xe và điện nước dự kiến.|Hệ thống hiển thị số lượng kết quả, danh sách tin, chi phí ước tính và khoảng cách đến cơ sở trường khi có dữ liệu.',
     'B3: Không có tin phù hợp: hiển thị danh sách rỗng; không làm thay đổi tin đăng; kết thúc tra cứu.',
     'B1: Giá trị bộ lọc không hợp lệ: không thực hiện tìm theo thông tin sai; người dùng sửa tiêu chí tại B1.',
     'Lựa chọn tin mới xác nhận còn phòng áp dụng mốc 14 ngày; tin cũ hơn không tự bị ẩn chỉ vì không thỏa bộ lọc này.|Nếu không nhập mức sử dụng, chi phí dự kiến sử dụng 50 kWh điện và 3 m³ nước; đây không phải số tiền hóa đơn.',
     'Người dùng nhận danh sách tin phù hợp; chưa đặt lịch hoặc giữ chỗ phòng.')

case('UC-DIS-02', 'Tin phòng cần xem; trang đánh giá công khai nếu có nhiều đánh giá.',
     'Người dùng mở một tin phòng.|Hệ thống kiểm tra tin vẫn được phép hiển thị công khai và lấy thông tin phòng.|Hệ thống chọn đánh giá đã được chấp thuận, chưa rút và các phản hồi được phép công khai; không đưa nội dung minh họa thử nghiệm vào đánh giá thực.|Hệ thống trình bày chi tiết tin, điểm tổng hợp và đánh giá với thông tin tác giả được ẩn danh.',
     'B3: Chưa có đánh giá phù hợp: hiển thị phần đánh giá trống; không tạo đánh giá thay thế; kết thúc.',
     'B2: Tin không còn công khai: thông báo tin không còn hiển thị; không cung cấp nội dung bị ẩn; kết thúc.',
     'Điểm tổng hợp dựa trên bốn tiêu chí: phòng ở, chi phí, chủ trọ và khu vực.|Xem công khai không đồng nghĩa được viết hoặc duyệt đánh giá.',
     'Người dùng xem được thông tin công khai; tin và lịch sử đánh giá không thay đổi.')

case('UC-DIS-03', 'Tin cần lưu hoặc bỏ lưu; trang danh sách yêu thích.',
     'Người dùng đã đăng nhập mở danh sách yêu thích hoặc chọn lưu một tin.|Hệ thống kiểm tra tin còn công khai và xác định danh sách thuộc tài khoản hiện tại.|Hệ thống ghi nhận tin yêu thích nếu chưa có, không tạo bản sao nếu đã lưu.|Hệ thống hiển thị danh sách yêu thích và tình trạng còn khả dụng của từng tin.',
     'B3: Người dùng bỏ lưu: hệ thống gỡ tin khỏi danh sách của chính người dùng; kết thúc.|B4: Tin đã không còn khả dụng: vẫn thể hiện tình trạng này trong danh sách, không tự công khai lại tin; kết thúc.',
     'B2: Tin không còn được hiển thị: không thêm vào yêu thích; thông báo từ chối; kết thúc.',
     'Danh sách yêu thích được quản lý riêng cho từng tài khoản.|Lưu yêu thích không giữ chỗ hoặc tạo lịch xem.',
     'Tin được lưu hoặc gỡ đúng danh sách cá nhân.')

case('UC-DIS-04', 'Tên và tiêu chí tìm kiếm; lựa chọn bật theo dõi; bộ lọc hoặc thông báo cần xóa, đánh dấu đã đọc. Tối đa 10 bộ lọc mỗi tài khoản.',
     'Người dùng chọn lưu bộ lọc tìm phòng.|Hệ thống kiểm tra số bộ lọc đã lưu chưa đạt 10 và cơ sở trường được chọn còn hoạt động.|Hệ thống lưu tiêu chí; khi tra cảnh báo, xác định các tin mới phù hợp và không tạo cùng một kết quả hai lần.|Hệ thống hiển thị các tin khớp còn khả dụng, số chưa đọc và danh sách từng trang 20 mục.',
     'B3: Bật lại bộ lọc đã tắt: theo dõi từ thời điểm bật lại, không tự coi mọi tin cũ là cảnh báo mới; kết thúc.|B4: Xóa bộ lọc hoặc đánh dấu cảnh báo đã đọc: chỉ cập nhật thông tin của tài khoản hiện tại; kết thúc.',
     'B2: Đã đủ 10 bộ lọc hoặc cơ sở trường không còn hoạt động: không lưu thêm; người dùng điều chỉnh lựa chọn.|B3: Bộ lọc hoặc cảnh báo không thuộc người dùng: không cập nhật; kết thúc.',
     'Không lưu số trang và số mục trên trang vào tiêu chí tìm kiếm.|Chưa xác nhận chức năng sửa trực tiếp bộ tiêu chí đã lưu; theo dõi tin không tự gửi thư hoặc đặt phòng.',
     'Bộ lọc và tình trạng theo dõi được ghi nhận theo từng tài khoản.')

case('UC-DIS-16', 'Các tin phòng được chọn; tối đa ba tin trong danh sách so sánh.',
     'Người dùng chọn tin muốn so sánh.|Hệ thống kiểm tra tin đã được chọn chưa và số mục hiện có.|Nếu chưa có tin đó và danh sách chưa đủ ba mục, hệ thống thêm tin vào danh sách đang sử dụng.|Người dùng mở so sánh; hệ thống trình bày các thuộc tính phòng cạnh nhau.',
     'B2: Chọn lại một tin đã có: gỡ tin khỏi danh sách; tiếp tục xem so sánh nếu còn mục.|B3: Người dùng xóa toàn bộ lựa chọn: danh sách so sánh trống; kết thúc.',
     'B3: Danh sách đã đủ ba tin: không thêm tin thứ tư; danh sách hiện tại được giữ nguyên; kết thúc lần chọn.',
     'Danh sách chỉ phục vụ phiên sử dụng hiện tại, không xác nhận được lưu lâu dài theo tài khoản.|So sánh không giữ chỗ hoặc thay đổi tin phòng.',
     'Người dùng có bảng so sánh tối đa ba tin; dữ liệu nghiệp vụ không thay đổi.')

case('UC-DIS-17', 'Tin phòng, số người ở, mức điện nước, phí gửi xe và số tháng cọc theo các lựa chọn trên màn hình ước tính.',
     'Người dùng mở công cụ ước tính từ tin phòng.|Người dùng điều chỉnh số người và các giả định chi phí theo lựa chọn được cung cấp.|Hệ thống tính chi phí tháng, phần chi phí mỗi người và chi phí ban đầu từ giá niêm yết và các giả định.|Hệ thống trình bày từng khoản cùng tổng ước tính để người dùng cân nhắc.',
     'B2: Người dùng thay đổi giả định: hệ thống tính lại và thay kết quả trên màn hình; không ghi hóa đơn; kết thúc lần tính.',
     'B2: Giá trị nhập hoặc lựa chọn ngoài phạm vi màn hình cho phép: không dùng giá trị đó để tính; người dùng điều chỉnh tại B2.',
     'Kết quả chỉ là ước tính, không là giá đã thỏa thuận hoặc nghĩa vụ thanh toán.|Không tự tạo hồ sơ người thuê, hợp đồng hay hóa đơn từ kết quả ước tính.',
     'Người dùng nhận bảng ước tính trong phiên sử dụng.')

case('UC-DIS-05', 'Phòng thuộc quyền quản lý; tiêu đề, mô tả, giá thuê, chi phí và thông tin tin đăng theo biểu mẫu; lần cập nhật gần nhất khi xác nhận.',
     'Chủ trọ chọn phòng và soạn hoặc mở tin của mình.|Hệ thống kiểm tra quyền quản lý, tình trạng phòng và dữ liệu tin.|Chủ trọ lưu nội dung; hệ thống tạo bản nháp hoặc cập nhật tin theo trạng thái được phép.|Chủ trọ gửi duyệt; hệ thống kiểm tra điều kiện và chuyển tin sang chờ kiểm duyệt, chưa tự công khai.',
     'B3: Chủ trọ xác nhận lại còn phòng ở tin đủ điều kiện: hệ thống ghi thời điểm xác nhận; kết thúc nhánh duy trì thông tin.',
     'B2: Phòng không thuộc chủ trọ hoặc không đủ điều kiện đăng: không lưu tin; kết thúc.|B4: Tin thay đổi hoặc trạng thái không cho gửi duyệt: không ghi đè quyết định trước; chủ trọ xem lại thông tin.',
     'Tin đăng là nội dung chào thuê, không tự thay điều khoản hợp đồng đang có.|Gửi duyệt không đồng nghĩa được công khai; quyết định kiểm duyệt thuộc chức năng riêng.',
     'Bản nháp, nội dung cập nhật hoặc yêu cầu kiểm duyệt được lưu theo kết quả xử lý.')

case('UC-DIS-06.2', 'Tin của chủ trọ và thông tin đối chiếu lần cập nhật hiện tại.',
     'Chủ trọ chọn ẩn tin cho thuê của mình.|Hệ thống kiểm tra quyền quản lý và tình trạng tin.|Hệ thống cập nhật tin sang trạng thái đã ẩn, giữ nội dung và lịch sử liên quan.|Hệ thống trả tình trạng mới; tin không còn xuất hiện trong tìm kiếm công khai.',
     '', 'B2: Tin không thuộc chủ trọ hoặc đã thay đổi so với thông tin đang xem: từ chối cập nhật; không ẩn tin của người khác; kết thúc.',
     'Ẩn tin không xóa phòng, hợp đồng hay lịch sử tin.|Không coi ẩn tin là hủy mọi lịch xem đã được đặt.',
     'Tin ngừng công khai và vẫn còn lịch sử để quản lý.')

case('UC-DIS-08', 'Tin đăng, thời gian bắt đầu và kết thúc của khung xem; khung cần gỡ.',
     'Chủ trọ mở quản lý khung giờ xem của tin thuộc mình.|Chủ trọ nhập khoảng thời gian; hệ thống kiểm tra tin và điều kiện thời gian.|Hệ thống tạo khung giờ hợp lệ và ghi nhận tình trạng đặt.|Hệ thống hiển thị các khung giờ để chủ trọ quản lý và người tìm phòng lựa chọn.',
     'B4: Chủ trọ gỡ một khung đủ điều kiện: hệ thống kiểm tra các lịch xem liên quan trước khi gỡ; kết thúc.',
     'B2: Thời gian không hợp lệ hoặc tin không thuộc phạm vi quản lý: không tạo khung; quay lại nhập.|B4: Khung có lịch xem ràng buộc không cho gỡ: không xóa để làm mất lịch đã đặt; kết thúc.',
     'Khung giờ được quản lý theo tin của chủ trọ.|Tạo khung chưa tạo lịch hẹn với người tìm phòng.',
     'Danh sách khung giờ hợp lệ được cập nhật.')

case('UC-DIS-09', 'Tin và khung giờ còn khả dụng; thông tin đặt lịch; lịch cần đổi hoặc hủy cùng mốc cập nhật nếu được yêu cầu.',
     'Người tìm phòng chọn một tin và khung giờ xem.|Hệ thống kiểm tra tin còn công khai, khung giờ phù hợp và điều kiện đặt lịch.|Hệ thống ghi lịch xem của người đặt ở trạng thái chờ chủ trọ phản hồi.|Người đặt mở lịch của mình; hệ thống hiển thị thời gian và tình trạng xử lý.',
     'B4: Người đặt đổi sang khung hợp lệ hoặc hủy trong trạng thái được phép: hệ thống kiểm tra lại rồi cập nhật lịch; kết thúc.',
     'B2: Khung giờ không còn khả dụng hoặc yêu cầu trùng: không tạo lịch mới; người đặt chọn lại.|B4: Lịch đã chuyển sang trạng thái không cho đổi/hủy hoặc đã thay đổi: không ghi đè lịch; kết thúc.',
     'Người dùng chỉ quản lý lịch do mình đặt.|Đặt lịch chưa xác lập quan hệ thuê hoặc giữ chắc phòng.',
     'Lịch xem được tạo hoặc cập nhật đúng phạm vi của người đặt.')

case('UC-DIS-10', 'Lịch xem thuộc tin của chủ trọ; quyết định xác nhận, từ chối, hủy hoặc hoàn tất; ghi chú và mốc cập nhật khi yêu cầu.',
     'Chủ trọ mở các lịch xem trên tin của mình.|Hệ thống kiểm tra quyền quản lý và trạng thái mới nhất của lịch.|Chủ trọ chọn quyết định; hệ thống kiểm tra bước chuyển được phép và các điều kiện thời gian.|Hệ thống lưu tình trạng, người xử lý và ghi chú; lịch được trả về để các bên theo dõi.',
     'B3: Chủ trọ từ chối hoặc hủy ở trạng thái cho phép: hệ thống lưu kết quả tương ứng, không tạo hợp đồng; kết thúc.',
     'B2: Lịch không thuộc phạm vi quản lý: không trả hoặc sửa lịch.|B3: Trạng thái đã thay đổi hoặc chưa đủ điều kiện ghi hoàn tất: từ chối cập nhật; chủ trọ xem lại lịch.',
     'Xác nhận hoặc hoàn tất lịch xem không tự lập hợp đồng.|Tạo hợp đồng từ lịch đã hoàn tất là biến thể của UC-TNT-05.',
     'Lịch xem có quyết định của chủ trọ và giữ lịch sử xử lý.')

case('UC-TNT-12.2', 'Hợp đồng, hiện trạng nhận phòng, chỉ số điện nước, ảnh minh chứng và mốc cập nhật biên bản.',
     'Chủ trọ mở biên bản nhận phòng của hợp đồng thuộc mình.|Chủ trọ ghi hiện trạng, chỉ số và hình ảnh theo biểu mẫu.|Hệ thống kiểm tra hợp đồng và tính hợp lệ của thông tin, đối chiếu lần cập nhật hiện tại.|Hệ thống lưu biên bản để người thuê xem và xác nhận đúng nội dung.',
     'B2: Sửa biên bản trong điều kiện cho phép: hệ thống ghi phiên bản thông tin mới; việc xác nhận phải dựa trên nội dung mới; kết thúc.',
     'B3: Hợp đồng không thuộc quyền quản lý hoặc nội dung đã thay đổi: không ghi đè biên bản; chủ trọ tải lại thông tin.',
     'Ghi biên bản khác với người thuê xác nhận biên bản.|Biên bản ghi nhận hiện trạng, không tự tạo khoản thanh toán.',
     'Biên bản nhận phòng được lưu theo hợp đồng và sẵn sàng để đối chiếu.')

case('UC-TNT-12.3', 'Hợp đồng của người thuê và phiên bản biên bản cần xác nhận.',
     'Người thuê mở biên bản nhận phòng của mình.|Hệ thống kiểm tra hợp đồng thuộc người thuê, đã đến ngày hiệu lực và có biên bản phù hợp.|Người thuê đọc thông tin rồi xác nhận.|Hệ thống đối chiếu đúng phiên bản biên bản và ghi nhận thời điểm xác nhận.',
     '', 'B2: Chưa đến ngày hiệu lực hoặc biên bản không thuộc hợp đồng của người thuê: không xác nhận.|B4: Biên bản đã thay đổi: không xác nhận nội dung cũ; người thuê đọc lại bản hiện hành trước khi quyết định.',
     'Người thuê xác nhận đúng phiên bản đã xem, không được sửa biên bản thay chủ trọ.',
     'Biên bản ghi nhận người thuê đã xác nhận nội dung hiện hành.')

case('UC-OPT-02', 'Từ khóa và trạng thái hoạt động hoặc lưu trữ của khu trọ.',
     'Người vận hành mở danh sách khu trọ và chọn bộ lọc.|Hệ thống xác định các khu thuộc chủ trọ hoặc được giao cho nhân viên.|Hệ thống lọc danh sách và thông tin khu theo điều kiện.|Hệ thống hiển thị kết quả để người dùng chọn khu cần làm việc.',
     'B3: Không có khu phù hợp: hiển thị danh sách trống, không tạo thêm khu; kết thúc.',
     'B2: Không đủ quyền xem: không cung cấp dữ liệu quản lý ngoài phạm vi; kết thúc.',
     'Nhân viên chỉ được thấy các khu trong phạm vi đã giao.', 'Danh sách khu được cung cấp đúng phạm vi; dữ liệu không thay đổi.')

case('UC-OPT-03.1', 'Tên, địa chỉ khu trọ và các trường thông tin được biểu mẫu cho phép.',
     'Chủ trọ nhập thông tin khu mới.|Hệ thống kiểm tra quyền tạo khu và hạn mức gói hiện đang áp dụng.|Hệ thống lưu khu mới gắn với chủ trọ.|Hệ thống hiển thị khu vừa tạo trong danh mục quản lý.',
     '', 'B2: Dữ liệu không hợp lệ hoặc vượt hạn mức khu: không tạo khu; người dùng điều chỉnh thông tin hoặc quyền sử dụng gói.',
     'Chỉ chủ trọ được tạo khu qua chức năng vận hành này; nhân viên không được tạo khu.|Tạo khu không tự tạo phòng.',
     'Khu trọ mới được bổ sung trong hạn mức được phép.')

case('UC-OPT-03.2', 'Khu cần sửa, tên và địa chỉ mới.',
     'Người vận hành mở khu được phép quản lý.|Hệ thống kiểm tra quyền và cung cấp thông tin hiện tại.|Người vận hành sửa tên hoặc địa chỉ; hệ thống kiểm tra dữ liệu được gửi.|Hệ thống lưu và hiển thị thông tin khu sau cập nhật.',
     '', 'B2: Khu không tồn tại trong phạm vi: không cung cấp hoặc cập nhật thông tin.|B3: Thông tin sửa không hợp lệ: không lưu; người dùng sửa lại tại B3.',
     'Không chuyển quyền sở hữu khu hoặc tự sửa hợp đồng bằng việc cập nhật tên, địa chỉ.',
     'Thông tin khu được cập nhật trong phạm vi được cấp.')

case('UC-OPT-04.1', 'Khu cần lưu trữ hoặc khôi phục; lựa chọn trạng thái đích.',
     'Người vận hành chọn lưu trữ hoặc khôi phục khu.|Hệ thống kiểm tra khu thuộc phạm vi, trạng thái hiện tại và các hợp đồng liên quan.|Đối với khôi phục, hệ thống kiểm tra hạn mức đang áp dụng; đối với lưu trữ, kiểm tra điều kiện ngừng vận hành.|Hệ thống thay đổi tình trạng sử dụng khu và giữ lịch sử.',
     'B3: Khôi phục khu đủ điều kiện: đưa khu về trạng thái hoạt động; không tự tạo lại hợp đồng; kết thúc.',
     'B2: Còn hợp đồng đang hiệu lực ngăn lưu trữ: không ngừng khu.|B3: Khôi phục vượt hạn mức: không kích hoạt khu; kết thúc.',
     'Lưu trữ khác với xóa; lịch sử khu, phòng và giao dịch không bị xóa để thực hiện thao tác này.',
     'Khu chuyển tình trạng sử dụng theo điều kiện được phép.')

case('UC-OPT-04.3', 'Khu trọ cần xóa.',
     'Người vận hành yêu cầu xóa khu.|Hệ thống kiểm tra quyền quản lý, số phòng và lịch sử xét duyệt của khu.|Nếu không còn ràng buộc ngăn xóa, hệ thống xóa khu khỏi danh mục.|Hệ thống thông báo hoàn tất yêu cầu.',
     '', 'B2: Khu còn phòng hoặc lịch sử xét duyệt: từ chối xóa; khu được giữ nguyên.|B3: Còn lịch sử phụ thuộc ngăn xóa: thông báo khu có lịch sử liên quan; không xóa khu.',
     'Không xóa dây chuyền lịch sử để làm khu đủ điều kiện xóa.', 'Khu không còn trong danh mục khi yêu cầu xóa thành công.')

case('UC-OPT-05', 'Khu, phòng và trạng thái sử dụng cần tra cứu.',
     'Người vận hành chọn khu hoặc mở chi tiết phòng.|Hệ thống kiểm tra quyền xem khu và phòng.|Hệ thống tổng hợp thông tin phòng cùng lịch sử liên quan được phép xem.|Giao diện hiển thị danh sách hoặc chi tiết tương ứng.',
     'B3: Không có phòng thỏa bộ lọc: hiển thị danh sách rỗng; kết thúc.',
     'B2: Khu hoặc phòng ngoài phạm vi: không cung cấp thông tin; kết thúc.',
     'Tra cứu không tự tạo hợp đồng hay sửa tình trạng sử dụng phòng.', 'Người dùng xem được thông tin phòng đúng phạm vi.')

case('UC-OPT-06.1', 'Khu trọ, tên phòng, giá cơ sở, trạng thái ban đầu và các đặc điểm phòng.',
     'Người vận hành nhập thông tin phòng mới.|Hệ thống kiểm tra khu còn hoạt động, quyền được cấp và hạn mức phòng.|Hệ thống kiểm tra trạng thái khởi tạo phù hợp; không cho tự khai phòng đang có người thuê khi chưa có hợp đồng.|Hệ thống tạo và hiển thị phòng trong khu.',
     '', 'B2: Khu đã lưu trữ hoặc hết hạn mức: không tạo phòng.|B3: Khai trạng thái đang có người thuê không qua hợp đồng: từ chối; quay lại nhập.',
     'Phòng đang có người thuê phải được xác lập qua hợp đồng.|Không tự tạo hạn mức ngoài gói đang áp dụng.', 'Phòng mới được tạo trong khu đang hoạt động.')

case('UC-OPT-06.2', 'Phòng cần sửa và các thông tin phòng được phép thay đổi.',
     'Người vận hành mở phòng thuộc phạm vi.|Người vận hành sửa thông tin; hệ thống kiểm tra dữ liệu và các ràng buộc hiện tại.|Hệ thống lưu thông tin phòng hợp lệ.|Hệ thống hiển thị kết quả sau cập nhật.',
     '', 'B2: Phòng không thuộc phạm vi hoặc thay đổi không đáp ứng ràng buộc: không lưu; kết thúc lần gửi.',
     'Thay giá cơ sở của phòng không tự sửa giá đã thỏa thuận trong hợp đồng.', 'Thông tin phòng được sửa; điều khoản hợp đồng không bị ghi đè.')

case('UC-OPT-07.1', 'Phòng và trạng thái sử dụng mong muốn.',
     'Người vận hành chọn thay đổi trạng thái phòng.|Hệ thống đối chiếu hợp đồng đang hiệu lực và hồ sơ chuẩn bị lại phòng.|Hệ thống chỉ chấp nhận trạng thái không mâu thuẫn với việc thuê và điều kiện chuẩn bị phòng.|Hệ thống lưu trạng thái được phép và trả thông tin phòng.',
     '', 'B3: Trạng thái yêu cầu mâu thuẫn hợp đồng hoặc hồ sơ chuẩn bị phòng: từ chối; giữ trạng thái trước đó.',
     'Không dùng sửa trạng thái để thay thế lập hoặc kết thúc hợp đồng.|Phòng sau trả phòng còn phải đáp ứng quy trình chuẩn bị lại trước khi trống sẵn sàng.',
     'Phòng có trạng thái sử dụng phù hợp hiện trạng thuê.')

case('UC-OPT-07.2', 'Phòng cần ngừng hoặc khôi phục hoạt động.',
     'Người vận hành chọn ngừng hoặc khôi phục phòng.|Hệ thống kiểm tra quyền, hợp đồng và điều kiện sử dụng của khu.|Đối với khôi phục, hệ thống kiểm tra hạn mức và điều kiện được phép.|Hệ thống đổi tình trạng hoạt động của phòng, giữ lịch sử.',
     '', 'B2: Phòng còn hợp đồng đang hiệu lực hoặc khu không phù hợp: từ chối ngừng hoặc khôi phục theo điều kiện.|B3: Vượt hạn mức khi khôi phục: không đưa phòng vào hoạt động.',
     'Ngừng hoạt động khác với xóa; thông tin thuê và giao dịch cũ được giữ.', 'Phòng được ngừng hoặc đưa trở lại sử dụng đúng điều kiện.')

case('UC-OPT-07.3', 'Phòng cần xóa khỏi danh mục.',
     'Người vận hành chọn xóa phòng.|Hệ thống kiểm tra quyền, hợp đồng, chỉ số điện nước, hóa đơn, lịch xem và hồ sơ chuẩn bị lại phòng.|Nếu không có lịch sử thuộc các nhóm ngăn xóa này, hệ thống xóa phòng.|Hệ thống thông báo kết quả.',
     '', 'B2: Phòng còn lịch sử hoặc ràng buộc phụ thuộc: từ chối xóa; giữ nguyên phòng và lịch sử.',
     'Không tự xóa hợp đồng, giao dịch hoặc lịch sử chỉ số để xóa được phòng.|Tài sản, lịch kiểm tra và phí dịch vụ riêng của phòng không được dùng làm điều kiện chặn xóa; các thông tin này bị xóa cùng phòng theo quan hệ lưu trữ hiện có.', 'Phòng được xóa chỉ khi đủ điều kiện; các thông tin phụ thuộc được xử lý theo quy tắc nêu trên.')

case('UC-OPT-08.1', 'Phòng, tên tài sản, số lượng, ngày mua, tình trạng và các thuộc tính tài sản được cho phép.',
     'Người vận hành mở tài sản của phòng.|Hệ thống kiểm tra phòng trong phạm vi và cung cấp danh sách hiện tại.|Người vận hành thêm, sửa hoặc gỡ tài sản; hệ thống kiểm tra thông tin và ràng buộc liên quan.|Hệ thống lưu thay đổi, trả danh sách tài sản sau cập nhật.',
     'B3: Chỉ xem danh sách: hệ thống trả thông tin tài sản, không ghi thay đổi; kết thúc.',
     'B2: Phòng hoặc tài sản không thuộc phạm vi: không cập nhật.|B3: Thông tin tài sản sai quy định hoặc không đủ điều kiện gỡ: từ chối lần gửi.',
     'Tài sản được quản lý theo phòng; không tự trở thành khoản chi hay khoản bồi thường của người thuê.', 'Danh mục tài sản phòng được duy trì đúng phạm vi.')

case('UC-OPT-08.2', 'Phòng, thời điểm, nội dung và kết quả kiểm tra phòng.',
     'Người vận hành mở lịch sử kiểm tra phòng.|Hệ thống kiểm tra quyền xem và phòng được giao.|Người vận hành ghi kết quả kiểm tra theo các trường cho phép.|Hệ thống lưu và hiển thị lần kiểm tra trong lịch sử phòng.',
     'B3: Chỉ tra lịch sử: không tạo lần kiểm tra mới; kết thúc.',
     'B2: Phòng ngoài phạm vi hoặc không tồn tại: không ghi kiểm tra.|B3: Dữ liệu kiểm tra không hợp lệ: không lưu; người dùng sửa thông tin.',
     'Ghi kiểm tra không tự đổi trạng thái phòng hoặc phát sinh tiền phải thu.', 'Kết quả kiểm tra được ghi cùng lịch sử phòng.')

case('UC-OPT-09', 'Phòng, tên và mức phí dịch vụ, kỳ hiệu lực, tình trạng áp dụng và phiên bản thông tin khi sửa.',
     'Chủ trọ mở danh sách phí và các phiên bản của phòng.|Chủ trọ nhập hoặc sửa mức phí với kỳ hiệu lực.|Hệ thống kiểm tra quyền quản lý, phiên bản và kỳ áp dụng không xung đột.|Hệ thống lưu phiên bản phí; khi lập hóa đơn, mức phí được chọn theo kỳ phù hợp.',
     'B1: Nhân viên có quyền xem phòng chỉ tra cứu phí và lịch sử; không lưu thay đổi; kết thúc.',
     'B3: Phiên bản đã thay đổi hoặc kỳ hiệu lực xung đột: không ghi đè; chủ trọ xem lại và điều chỉnh.',
     'Chỉ chủ trọ được ghi phí phòng; quyền xem không đồng nghĩa được sửa.|Thay đổi phí không tự tính lại hóa đơn đã phát hành.', 'Phiên bản phí phòng được lưu với thời gian áp dụng rõ ràng.')

case('UC-STF-01', 'Thông tin người được mời, mẫu quyền hoặc danh sách quyền và các khu được giao.',
     'Chủ trọ nhập lời mời nhân viên và chọn quyền, khu phụ trách.|Hệ thống kiểm tra khu thuộc chủ trọ, các quyền hợp lệ và thông tin người nhận.|Hệ thống lưu lời mời có thời hạn cùng phạm vi đã chọn.|Hệ thống trả thông tin kích hoạt để chủ trọ chuyển cho người được mời.',
     '', 'B2: Khu hoặc quyền không hợp lệ, thông tin trùng theo ràng buộc: không tạo lời mời; chủ trọ điều chỉnh.',
     'Nhân viên nhận quyền và khu từ lời mời, không tự chọn khi kích hoạt.|Lời mời chưa đồng nghĩa tài khoản nhân viên đã hoạt động.', 'Lời mời nhân viên được tạo; kích hoạt thực hiện tại UC-SYS-09.')

case('UC-STF-02', 'Nhân viên, lựa chọn quyền, danh sách khu và tình trạng hoạt động.',
     'Chủ trọ mở hồ sơ nhân viên của mình.|Chủ trọ điều chỉnh quyền, khu được giao hoặc tình trạng làm việc.|Hệ thống kiểm tra nhân viên và khu thuộc chủ trọ, các quyền được phép cấp.|Hệ thống lưu thay đổi và điều chỉnh hiệu lực truy cập của nhân viên theo quy định hiện có.',
     '', 'B3: Nhân viên hoặc khu không thuộc chủ trọ, quyền ngoài danh mục: không lưu thay đổi.',
     'Chủ trọ chỉ cấp quyền trong phạm vi nhân sự của mình.|Khôi phục nhân viên không tự khôi phục các phiên đã thu hồi.', 'Phạm vi vận hành và tình trạng nhân viên được cập nhật.')

case('UC-STF-03', 'Nhân viên, khu trọ và quyền muốn kiểm tra.',
     'Chủ trọ chọn nhân viên, khu và quyền để kiểm tra.|Hệ thống đối chiếu tình trạng nhân viên, quyền đã cấp, khu được giao và tình trạng khu.|Hệ thống xác định các lý do không được phép, kể cả hành động chỉ dành cho chủ trọ.|Hệ thống trình bày kết quả mô phỏng và nhắc rằng hành động thực tế còn phải đáp ứng điều kiện nghiệp vụ.',
     'B3: Có lý do từ chối: hiển thị không được phép và các lý do; không thay quyền; kết thúc.',
     'B2: Không có nhân viên hoặc khu thuộc chủ trọ: không đánh giá đối tượng ngoài phạm vi.',
     'Kết quả mô phỏng không cấp thêm quyền và không bảo đảm mọi hành động cụ thể đều được chấp nhận.', 'Chủ trọ nhận đánh giá quyền; hồ sơ cấp quyền không đổi.')

case('UC-STF-04', 'Phạm vi khu đã được giao và quyền xem nhân sự.',
     'Nhân viên mở danh sách nhân sự hoặc danh mục mẫu quyền.|Hệ thống xác định chủ trọ và các khu nhân viên được phép xem.|Hệ thống chọn thông tin nhân sự trong phạm vi và các mẫu quyền tương ứng.|Hệ thống cung cấp danh sách để tham khảo.',
     'B3: Không có nhân sự phù hợp: hiển thị danh sách trống; kết thúc.',
     'B2: Không đủ quyền xem: từ chối cung cấp danh sách.',
     'Quyền xem nhân sự không bao gồm mời, sửa quyền hoặc thay khu được giao.', 'Nhân viên xem được thông tin trong phạm vi, không thay đổi nhân sự.')

case('UC-TEN-01', 'Tài khoản người thuê có hồ sơ thuê được liên kết.',
     'Người thuê mở trang tổng quan cá nhân.|Hệ thống xác định hồ sơ thuê được liên kết với tài khoản hiện tại.|Hệ thống tổng hợp thông tin cá nhân, hợp đồng, hóa đơn còn phải trả, bảo trì và thông báo thuộc người thuê.|Hệ thống hiển thị tổng quan và các nội dung được phép tra cứu.',
     'B3: Một nhóm nội dung chưa có dữ liệu: hiển thị danh sách rỗng hoặc số lượng tương ứng; không tự tạo dữ liệu; kết thúc.',
     'B2: Tài khoản tìm phòng chưa có hồ sơ thuê liên kết: không cấp dữ liệu thuê; thông báo chưa có hồ sơ phù hợp.',
     'Tài khoản tìm phòng không đồng nghĩa đã ký hợp đồng.|Chỉ dữ liệu của người thuê hiện tại được cung cấp.', 'Người thuê xem tổng quan của mình; hồ sơ nghiệp vụ không đổi.')

case('UC-TEN-02', 'Hợp đồng thuộc hồ sơ người thuê; lựa chọn xem quyết toán khi có.',
     'Người thuê mở danh sách hợp đồng của mình.|Hệ thống lấy các hợp đồng qua hồ sơ thuê được liên kết.|Người thuê chọn hợp đồng; hệ thống kiểm tra quyền sở hữu trước khi cung cấp quyết toán.|Hệ thống hiển thị hợp đồng và quyết toán đã có.',
     'B4: Chưa có quyết toán: hiển thị chưa có kết quả; không tạo quyết toán mới; kết thúc.',
     'B3: Hợp đồng không thuộc tài khoản: không cung cấp thông tin; kết thúc.',
     'Người thuê không lập hoặc xác nhận quyết toán thay chủ trọ.|Chưa xác nhận đầy đủ khả năng xuất bản hợp đồng từ giao diện người thuê.', 'Hợp đồng và quyết toán cá nhân được tra cứu, không thay đổi.')

case('UC-TEN-08.1', 'Hợp đồng cần xem người ở cùng; có thể không chọn hợp đồng riêng khi tra danh sách cá nhân.',
     'Người thuê yêu cầu xem người ở cùng.|Hệ thống kiểm tra hồ sơ thuê và hợp đồng thuộc người dùng.|Hệ thống lấy các thành viên gắn với hợp đồng được phép xem.|Hệ thống trình bày danh sách người ở cùng.',
     'B3: Chưa có thành viên: hiển thị danh sách trống; kết thúc.',
     'B2: Hợp đồng không thuộc người thuê: không trả danh sách.',
     'Người thuê chỉ tra cứu ở chức năng này, không được thêm hoặc xóa thành viên.', 'Người thuê xem đúng người ở cùng hợp đồng của mình.')

case('UC-TNT-01', 'Bộ lọc trạng thái hồ sơ; người thuê cần xem chi tiết hoặc tổng quan.',
     'Người vận hành tra cứu hồ sơ người thuê.|Hệ thống xác định phạm vi chủ trọ và các khu nhân viên được giao.|Hệ thống lấy hồ sơ, hợp đồng hiện hành và thông tin tài chính, lịch sử liên quan được phép xem.|Hệ thống hiển thị danh sách hoặc tổng quan theo lựa chọn.',
     'B3: Không có hồ sơ khớp bộ lọc: hiển thị danh sách trống; kết thúc.',
     'B2: Hồ sơ ngoài phạm vi: không cung cấp thông tin.',
     'Đối với nhân viên, hồ sơ phải có hợp đồng trong phạm vi và mọi hợp đồng, hóa đơn của hồ sơ đều thuộc khu được giao.', 'Hồ sơ được tra cứu trong phạm vi; không tạo hồ sơ mới.')

case('UC-TNT-02.1', 'Họ tên, số điện thoại, thông tin giấy tờ và ghi chú người thuê.',
     'Người vận hành nhập hồ sơ người thuê mới.|Hệ thống kiểm tra quyền tạo hồ sơ và các trường nhập.|Hệ thống lưu hồ sơ thuộc chủ trọ với thông tin đã chuẩn hóa.|Hệ thống hiển thị hồ sơ vừa tạo.',
     '', 'B2: Thông tin không hợp lệ hoặc không có quyền: không tạo hồ sơ; người dùng sửa hoặc dừng.',
     'Hồ sơ người thuê khác với tài khoản đăng nhập; tạo hồ sơ chưa tạo tài khoản hoặc hợp đồng.|Hồ sơ mới chưa có hợp đồng không tự đáp ứng điều kiện tra cứu hồ sơ của nhân viên.', 'Hồ sơ người thuê được tạo, chưa mặc nhiên có quyền đăng nhập.')

case('UC-TNT-02.2', 'Người thuê cần sửa và thông tin cá nhân được phép cập nhật.',
     'Người vận hành mở hồ sơ trong phạm vi.|Hệ thống kiểm tra quyền quản lý hồ sơ.|Người vận hành sửa thông tin; hệ thống kiểm tra và chuẩn hóa dữ liệu.|Hệ thống lưu hồ sơ cập nhật.',
     '', 'B2: Hồ sơ ngoài phạm vi: từ chối.|B3: Thông tin sửa không hợp lệ: không lưu; người dùng điều chỉnh.',
     'Sửa hồ sơ không tự thay thông tin đăng nhập hoặc điều khoản hợp đồng.', 'Thông tin hồ sơ người thuê được cập nhật.')

case('UC-TNT-02.3', 'Hồ sơ người thuê và lựa chọn ngừng hoặc khôi phục hoạt động.',
     'Người vận hành chọn ngừng hoặc khôi phục hồ sơ.|Hệ thống kiểm tra quyền, tình trạng hồ sơ và các ràng buộc liên quan.|Hệ thống cập nhật tình trạng hồ sơ theo điều kiện được phép.|Hệ thống trả thông tin sau thay đổi.',
     'B3: Khôi phục hồ sơ đủ điều kiện: đưa hồ sơ về hoạt động, không tạo lại lịch sử thuê; kết thúc.',
     'B2: Không thuộc phạm vi hoặc còn ràng buộc không cho đổi trạng thái: không lưu thay đổi.',
     'Ngừng hoạt động hồ sơ không là xóa lịch sử thuê hay xóa tài khoản.', 'Hồ sơ có tình trạng sử dụng mới và giữ lịch sử.')

case('UC-TNT-02.4', 'Hồ sơ người thuê cần xóa.',
     'Người vận hành yêu cầu xóa hồ sơ.|Hệ thống kiểm tra phạm vi và lịch sử thuê, hóa đơn, cọc hoặc các dữ liệu liên quan.|Nếu không còn ràng buộc ngăn xóa, hệ thống xóa hồ sơ.|Hệ thống thông báo kết quả.',
     '', 'B2: Còn lịch sử hoặc liên kết ngăn xóa: không xóa hồ sơ; kết thúc.',
     'Không xóa dây chuyền lịch sử để làm hồ sơ đủ điều kiện xóa.', 'Hồ sơ được xóa khi đủ điều kiện.')

case('UC-TNT-03', 'Hồ sơ người thuê chưa có tài khoản; thư điện tử và thông tin lời mời.',
     'Chủ trọ chọn hồ sơ người thuê cần mời.|Hệ thống kiểm tra hồ sơ thuộc chủ trọ và điều kiện liên kết tài khoản.|Hệ thống tạo lời mời có thời hạn gắn đúng hồ sơ.|Hệ thống trả thông tin kích hoạt để chủ trọ chuyển cho người thuê.',
     '', 'B2: Hồ sơ đã có tài khoản, thư điện tử đã đăng ký hoặc không đủ điều kiện: không tạo lời mời.',
     'Nhân viên không được tạo lời mời qua chức năng này.|Người nhận kích hoạt tại UC-SYS-08; lời mời không tự xác nhận đã giao qua thư điện tử.', 'Có lời mời truy cập gắn với hồ sơ đã chọn.')

case('UC-TNT-03.1', 'Hồ sơ người thuê, thư điện tử và mật khẩu theo quy định tạo tài khoản.',
     'Người vận hành chọn tạo tài khoản cho một hồ sơ.|Hệ thống kiểm tra quyền, hồ sơ chưa liên kết tài khoản và thư điện tử chưa được dùng.|Hệ thống tạo tài khoản người thuê và liên kết đúng hồ sơ.|Hệ thống trả kết quả tạo tài khoản.',
     '', 'B2: Hồ sơ đã liên kết hoặc thư điện tử đã tồn tại: không tạo tài khoản khác; giữ liên kết hiện có.',
     'Không chuyển tài khoản đang có sang hồ sơ khác bằng chức năng tạo trực tiếp.|Nhân viên chỉ thực hiện khi có quyền quản lý người thuê và hồ sơ thuộc phạm vi được giao.', 'Hồ sơ có tài khoản đăng nhập liên kết, không tự phát sinh hợp đồng.')

case('UC-TNT-04', 'Người thuê, phòng hoặc hợp đồng cần tra cứu; lựa chọn xuất hoặc chia sẻ bản hợp đồng.',
     'Người vận hành mở danh sách hoặc chi tiết hợp đồng.|Hệ thống kiểm tra hợp đồng thuộc phạm vi được phép.|Hệ thống cung cấp điều khoản và thông tin liên quan.|Người vận hành có thể xuất hoặc chia sẻ bản hợp đồng từ thông tin được phép xem.',
     'B4: Chỉ xem hợp đồng: không tạo thay đổi nghiệp vụ; kết thúc.',
     'B2: Hợp đồng ngoài phạm vi: không cung cấp hoặc xuất thông tin.',
     'Bản xuất là kết quả tra cứu, không tự thay đổi điều khoản hoặc ký kết mới.', 'Người vận hành xem hoặc nhận bản hợp đồng đúng phạm vi.')

case('UC-TNT-05', 'Phòng, hồ sơ người thuê, tiền thuê, tiền cọc và ngày bắt đầu. Lập trực tiếp cho phép bỏ trống ngày bắt đầu; lập từ lịch xem phải có ngày bắt đầu và thông tin lần cập nhật lịch. Chưa nhập ngày kết thúc trong chức năng lập mới.',
     'Người vận hành chọn phòng và người thuê để lập hợp đồng trực tiếp.|Hệ thống kiểm tra quyền; khu chưa lưu trữ, phòng đang hoạt động, không có hợp đồng hiệu lực và đã sẵn sàng cho thuê; người thuê đang hoạt động, đúng phạm vi.|Hệ thống kiểm tra ngày bắt đầu, tiền thuê và tiền cọc; nếu bỏ trống ngày bắt đầu thì dùng thời điểm hiện tại.|Hệ thống tạo hợp đồng có hiệu lực, chuyển phòng sang có người thuê; nếu tiền cọc dương thì ghi nhận khoản cọc đã thu.|Hệ thống cung cấp hợp đồng vừa lập.',
     'B1: Chủ trọ lập từ lịch xem đã hoàn tất: hệ thống kiểm tra lịch, tin phòng và người xem đủ điều kiện, tạo hoặc sử dụng hồ sơ người thuê rồi lập hợp đồng; chỉ lưu tiền cọc thỏa thuận, không tự ghi khoản cọc đã thu. Hệ thống đánh lịch đã có hợp đồng, ẩn tin và hủy các lịch đang chờ hoặc đã xác nhận khác của tin; kết thúc sau khi trả kết quả.',
     'B2: Phòng không còn đủ điều kiện cho thuê hoặc người thuê ngoài phạm vi: không lập hợp đồng.|B3: Ngày bắt đầu, tiền thuê hoặc tiền cọc không hợp lệ: không ghi hợp đồng; người vận hành điều chỉnh.',
     'Lập mới chưa nhận ngày kết thúc; ngày kết thúc được quản lý tại chức năng cập nhật hoặc gia hạn.|Lập trực tiếp ghi cọc đã thu khi tiền cọc dương; lập từ lịch xem không tự ghi giao dịch thu cọc dù có tiền cọc thỏa thuận.|Không xác định kiểm tra số người so với sức chứa là quy tắc của thao tác lập hợp đồng trực tiếp; việc thêm người ở cùng và chuyển phòng có kiểm tra riêng.|Nhân viên chỉ lập trực tiếp, không dùng biến thể lập từ lịch xem.', 'Hợp đồng có hiệu lực và phòng có người thuê. Tiền cọc thỏa thuận được lưu; khoản cọc đã thu chỉ được ghi tự động trong nhánh lập trực tiếp khi có số tiền dương.')

case('UC-TNT-06.1', 'Hợp đồng đang được quản lý và các điều khoản được cho phép cập nhật.',
     'Người vận hành mở hợp đồng cần sửa.|Hệ thống kiểm tra quyền và tình trạng hợp đồng.|Người vận hành thay đổi điều khoản được cho phép; hệ thống kiểm tra thời hạn, giá và ràng buộc liên quan.|Hệ thống lưu và cung cấp điều khoản mới.',
     '', 'B2: Hợp đồng ngoài phạm vi hoặc không còn trạng thái cho sửa: từ chối.|B3: Thay đổi không hợp lệ: không lưu; quay lại nhập.',
     'Không dùng sửa hợp đồng để tự thay toàn bộ hóa đơn đã phát hành.', 'Điều khoản hợp đồng được cập nhật theo phạm vi cho phép.')

case('UC-TNT-06.2', 'Hợp đồng đang hiệu lực và ngày kết thúc mới.',
     'Người vận hành chọn gia hạn hợp đồng.|Hệ thống kiểm tra quyền và hợp đồng còn hiệu lực.|Hệ thống kiểm tra ngày kết thúc mới phải phù hợp khoảng thuê hiện tại.|Hệ thống lưu thời hạn gia hạn và trả hợp đồng.',
     '', 'B2: Hợp đồng không còn hiệu lực hoặc ngoài phạm vi: không gia hạn.|B3: Ngày gia hạn không hợp lệ: giữ thời hạn cũ.',
     'Gia hạn thay thời hạn thuê, không tự là thu tiền hoặc lập hóa đơn kỳ mới.', 'Hợp đồng có thời hạn kết thúc mới hợp lệ.')

case('UC-TNT-06.3', 'Hợp đồng cần kết thúc.',
     'Người vận hành chọn kết thúc hợp đồng.|Hệ thống kiểm tra quyền và tình trạng hiện tại.|Hệ thống cập nhật hợp đồng sang kết thúc và mở hồ sơ chuẩn bị lại phòng theo quy trình.|Hệ thống cung cấp kết quả kết thúc.',
     '', 'B2: Hợp đồng ngoài phạm vi hoặc không đủ điều kiện: không thay đổi trạng thái.',
     'Kết thúc hợp đồng không tự hoàn cọc, xóa công nợ hoặc đưa phòng ngay về trống sẵn sàng.', 'Hợp đồng kết thúc; công nợ và hoàn cọc được xử lý theo mục tiêu riêng.')

case('UC-TNT-07', 'Hợp đồng, loại giao dịch cọc, số tiền và nội dung tham chiếu theo lựa chọn được phép.',
     'Người vận hành mở sổ tiền cọc của hợp đồng.|Hệ thống kiểm tra quyền và cung cấp giao dịch, số dư cọc.|Người vận hành ghi loại giao dịch cọc được phép.|Hệ thống kiểm tra điều kiện, ghi giao dịch và trả số dư sau cập nhật.',
     'B3: Chỉ tra cứu: không phát sinh giao dịch cọc mới; kết thúc.',
     'B2: Hợp đồng ngoài phạm vi: không cung cấp hoặc ghi cọc.|B3: Loại giao dịch hoặc số tiền không hợp lệ: không ghi; kết thúc lần gửi.',
     'Sổ cọc khác với khoản thu thanh toán hóa đơn.|Ghi hoàn cọc là ghi nhận nghiệp vụ, không tự chuyển tiền ngân hàng.', 'Sổ cọc thể hiện giao dịch hợp lệ và số dư liên quan.')

case('UC-TNT-12.1', 'Hợp đồng, họ tên và thông tin người ở cùng, quan hệ hoặc lựa chọn gỡ thành viên.',
     'Người vận hành mở danh sách người ở cùng hợp đồng.|Khi thêm người, hệ thống kiểm tra quyền, hợp đồng còn hiệu lực, người thuê chính đang hoạt động và khu chưa lưu trữ.|Người vận hành nhập người ở cùng; hệ thống kiểm tra thông tin và tổng số người, tính cả người thuê chính, không vượt sức chứa.|Hệ thống lưu người được thêm và cung cấp danh sách.',
     'B1: Chỉ xem danh sách: cung cấp dữ liệu thuộc phạm vi, không thay đổi thành viên; kết thúc.|B2: Gỡ thành viên: hệ thống kiểm tra người đó thuộc hợp đồng còn hiệu lực trong phạm vi rồi gỡ; không áp dụng kiểm tra sức chứa như khi thêm.',
     'B2: Hợp đồng hoặc thành viên ngoài phạm vi, hợp đồng không còn hiệu lực: từ chối thay đổi.|B3: Đã đủ sức chứa hoặc thông tin không hợp lệ: không thêm người.',
     'Phạm vi hiện có gồm xem, thêm và gỡ; chưa có thao tác sửa trực tiếp thông tin thành viên.|Ghi người ở cùng không tự tạo tài khoản đăng nhập hoặc hợp đồng thuê riêng.|Sức chứa tính cả người thuê chính; khi phòng chưa quy định sức chứa thì áp dụng mức 100 người theo hiện trạng.', 'Danh sách thành viên được bổ sung hoặc gỡ đúng điều kiện.')

case('UC-TNT-08', 'Ngày trả phòng, chỉ số điện nước cuối và đơn giá khi cần, các khoản bổ sung, bản xem trước và mã đối chiếu lần xác nhận.',
     'Chủ trọ nhập thông tin trả phòng và yêu cầu xem trước quyết toán.|Hệ thống kiểm tra hợp đồng đang hiệu lực, chưa quyết toán; ngày trả từ ngày bắt đầu đến hôm nay theo giờ Việt Nam và không có hóa đơn sau tháng trả.|Hệ thống tính tiền thuê đến cả ngày trả nếu tháng đó chưa có hóa đơn, điện nước cuối, khoản bổ sung, cọc bù trừ; trình bày nợ hóa đơn cũ riêng.|Chủ trọ xác nhận; hệ thống tính lại, đối chiếu đúng bản xem trước và mã xác nhận.|Hệ thống lưu quyết toán, khấu trừ cọc khi có, kết thúc hợp đồng và mở công việc chuẩn bị lại phòng.',
     'B4: Cùng yêu cầu đã chốt trước đó: trả kết quả cũ, không khấu trừ cọc lần hai; kết thúc.|B3: Tháng trả đã có hóa đơn: tiền thuê trong quyết toán bằng không, không tự hoàn phần thuê thừa; tiếp tục B4.',
     'B2: Ngày không hợp lệ hoặc có hóa đơn sau tháng trả: không chốt; điều chỉnh thông tin trước khi xem lại.|B4: Bản xem trước đã thay đổi hoặc mã xác nhận không khớp kết quả đã chốt: không chốt đè; quay lại B1.',
     'Cọc bù trừ bằng số nhỏ hơn giữa số dư cọc và tổng khoản quyết toán; phần còn lại là tiền phải hoàn.|Nợ hóa đơn cũ không tự được cấn cọc hoặc tất toán; không tự tạo thanh toán hóa đơn từ quyết toán.', 'Quyết toán được ghi nhận; hợp đồng kết thúc; tiền hoàn cọc có thể vẫn chờ thực hiện.')

case('UC-TNT-09', 'Hợp đồng, phiên bản quyết toán, mã xác nhận, tham chiếu hoàn cọc và lý do.',
     'Chủ trọ xác nhận khoản hoàn cọc đã thực hiện.|Hệ thống xác định quyết toán thuộc hợp đồng và phạm vi quản lý.|Hệ thống kiểm tra còn khoản phải hoàn, phiên bản chưa thay đổi và số dư cọc bằng khoản phải hoàn.|Hệ thống ghi giao dịch hoàn cọc, đánh đã hoàn và lưu tham chiếu.',
     'B2: Cùng khoản hoàn đã được xác nhận với cùng mã và tham chiếu: trả kết quả trước, không ghi lần hai; kết thúc.',
     'B2: Chưa có quyết toán hoặc đã ghi hoàn bằng yêu cầu khác: từ chối.|B3: Phiên bản hoặc số dư đã đổi, không còn khoản cần hoàn: không đánh đã hoàn.',
     'Đây là ghi nhận đã hoàn, không phải lệnh chuyển tiền ngân hàng.', 'Sổ cọc và quyết toán ghi nhận khoản hoàn đã thực hiện.')

case('UC-TNT-10', 'Yêu cầu gia hạn, chuyển hoặc trả phòng; quyết định chấp thuận/từ chối, lý do và mốc thông tin đang xem.',
     'Người vận hành mở yêu cầu thuộc phạm vi.|Người vận hành chọn quyết định; hệ thống kiểm tra yêu cầu còn chờ và hợp đồng chưa thay đổi.|Nếu chấp thuận, hệ thống kiểm tra hợp đồng còn hiệu lực và các điều kiện ngày hoặc phòng đích.|Hệ thống ghi quyết định, người xét duyệt và thời điểm; với chấp thuận, thể hiện còn bước thực hiện thay đổi hợp đồng.',
     'B3: Từ chối: hệ thống lưu lý do và quyết định từ chối; hợp đồng không đổi; kết thúc sau B4.',
     'B2: Yêu cầu đã được xử lý, hủy hoặc hợp đồng thay đổi: không ghi đè quyết định.|B3: Phòng hoặc thời gian không còn phù hợp: không chấp thuận.',
     'Xét duyệt không tự gia hạn, trả hoặc chuyển hợp đồng.', 'Yêu cầu có quyết định; thay đổi hợp đồng chưa được thực hiện trong bước này.')

case('UC-TNT-11', 'Yêu cầu đã chấp thuận, mã đối chiếu lần thực hiện và mốc cập nhật; tiền thuê mới khi chuyển phòng.',
     'Người vận hành chọn thực hiện yêu cầu đã chấp thuận.|Hệ thống kiểm tra thông tin mới nhất và lịch sử thực hiện để tránh ghi lặp.|Với gia hạn, hệ thống thực hiện gia hạn; với trả hoặc chuyển phòng, kiểm tra hợp đồng cũ đã kết thúc và có quyết toán.|Với chuyển phòng, hệ thống kiểm tra đã đến ngày chuyển, phòng và sức chứa phù hợp, giá thuê đã xác nhận; tạo hợp đồng mới và chuyển thông tin người ở cùng.|Hệ thống ghi kết quả thực hiện, trả hợp đồng kết quả khi có.',
     'B2: Cùng yêu cầu đã thực hiện với cùng mã và nội dung: trả kết quả cũ, không tạo hợp đồng mới; kết thúc.|B3: Trả phòng đủ điều kiện: ghi hoàn tất, không tạo hợp đồng đích; tiếp tục B5.',
     'B2: Chưa chấp thuận, thông tin cũ hoặc đã thực hiện bằng nội dung khác: từ chối.|B3: Chưa quyết toán hoặc B4 phòng đích không đủ điều kiện: không thực hiện chuyển hợp đồng.',
     'Không tự chốt quyết toán để vượt tiền điều kiện.|Không thu cọc thêm lần nữa chỉ vì tạo hợp đồng chuyển phòng.', 'Yêu cầu có kết quả thực hiện; chỉ chuyển phòng tạo hợp đồng đích mới.')

case('UC-BIL-01', 'Phòng, kỳ, loại điện hoặc nước, chỉ số trước, chỉ số hiện tại và đơn giá.',
     'Người vận hành mở chỉ số theo phòng và kỳ.|Người vận hành nhập số liệu; hệ thống kiểm tra phòng thuộc phạm vi và kỳ hợp lệ.|Hệ thống kiểm tra chỉ số hiện tại không nhỏ hơn chỉ số trước, đơn giá lớn hơn không; tính tiêu thụ và thành tiền.|Hệ thống lưu chỉ số, trả số liệu đã ghi.',
     'B1: Chỉ tra cứu chỉ số đã có: trả kết quả đúng phạm vi, không ghi chỉ số mới; kết thúc.',
     'B3: Chỉ số giảm hoặc đơn giá không dương: không ghi; quay lại nhập.|B4: Đã có chỉ số cùng phòng, kỳ và loại: không tạo bản trùng; người dùng kiểm tra số liệu hiện hành.',
     'Mỗi phòng, kỳ và loại tiện ích có chỉ số theo ràng buộc không trùng.|Ghi chỉ số chưa phát hành hóa đơn.', 'Chỉ số hợp lệ có mức tiêu thụ và thành tiền.')

case('UC-BIL-02', 'Hợp đồng, kỳ thanh toán, hạn trả, ghi chú và chỉ số điện nước khi cần.',
     'Người vận hành chọn hợp đồng đang hiệu lực và kỳ để xem trước.|Hệ thống kiểm tra phạm vi, lấy phí áp dụng theo kỳ và chỉ số; trình bày khoản còn thiếu.|Người vận hành xác nhận lập; hệ thống kiểm tra kỳ thuộc thời gian thuê, hợp đồng chưa thay đổi và kỳ chưa khóa.|Hệ thống ghi chỉ số được cung cấp, tính khoản mục và lưu hóa đơn chưa thanh toán cùng giá áp dụng tại thời điểm lập.|Hệ thống trả hóa đơn vừa phát hành.',
     'B2: Thiếu chỉ số điện nước: trả danh sách còn thiếu; chưa lập hóa đơn; bổ sung rồi xem trước lại.',
     'B3: Hợp đồng đã thay đổi, kết thúc hoặc kỳ bị khóa: không phát hành.|B4: Trùng hóa đơn hoặc chỉ số trong lần lập: hủy các thay đổi của lần xác nhận, không tạo bản trùng.',
     'Khoản mục giá của hóa đơn được giữ theo thời điểm phát hành.|Không lấy ước tính trên tin phòng làm hóa đơn thực tế.', 'Hóa đơn và căn cứ tính tiền được lưu; chưa ghi nhận thu tiền.')

case('UC-BIL-03', 'Khu, kỳ, danh sách hợp đồng, hạn trả và chỉ số điện nước cho lần lập hàng loạt.',
     'Người vận hành chọn khu và kỳ lập hóa đơn.|Hệ thống kiểm tra trước các hợp đồng đang hiệu lực, số liệu phí, chỉ số và hóa đơn đã có.|Người vận hành gửi danh sách; hệ thống kiểm tra hợp đồng đều thuộc phạm vi và chỉ số không trùng.|Hệ thống bỏ qua hóa đơn đã có, sử dụng chỉ số hiện có hoặc ghi chỉ số còn thiếu và lập hóa đơn cho các hợp đồng còn lại.|Hệ thống trả kết quả từng hợp đồng và tổng số đã tạo, đã có.',
     'B4: Hợp đồng đã có hóa đơn kỳ đó: ghi kết quả đã có, không lập lại; tiếp tục các hợp đồng còn lại.',
     'B3: Danh sách có hợp đồng ngoài phạm vi hoặc chỉ số lặp: không lập theo dữ liệu sai.|B4: Thông tin xung đột trong lúc lập: hủy thay đổi thuộc lần lập hàng loạt và trả lỗi; người vận hành xem lại từ B1.',
     'Kiểm tra trước không giữ chỗ hoặc bảo đảm dữ liệu chưa đổi; hệ thống kiểm tra lại khi lập.', 'Kết quả lập cho từng hợp đồng được cung cấp, không tạo lại hóa đơn đã có.')

case('UC-BIL-04', 'Bộ lọc khu, phòng, người thuê, trạng thái; hóa đơn cần xem; ngày chốt và cách nhóm tuổi nợ.',
     'Người vận hành tra danh sách, chi tiết hóa đơn hoặc báo cáo tuổi nợ.|Hệ thống giới hạn dữ liệu theo phạm vi, cung cấp các khoản phải thu, đã thu và khoản mục.|Khi tính tuổi nợ, hệ thống bỏ hóa đơn mô phỏng, đã hủy; tính dư nợ dương theo ngày nghiệp vụ Việt Nam.|Hệ thống trả danh sách, tổng nợ, nhóm tuổi nợ và tiền chưa phân bổ khi cách lọc cho phép.',
     'B4: Lọc theo một khu hoặc phòng: không tự chia tiền chưa phân bổ toàn người thuê cho phòng đó; kết thúc.|B2: Chủ trọ xem tình trạng liên kết thanh toán mô phỏng: hệ thống có thể cập nhật liên kết đã hết hạn hoặc không còn đúng số dư; không thu tiền thật; kết thúc.',
     'B2: Hóa đơn ngoài phạm vi: không cung cấp chứng từ.',
     'Tiền chưa phân bổ khác với số tiền đã thanh toán cho hóa đơn.|Nhân viên không mặc nhiên được xem thông tin liên kết thanh toán ngoài phạm vi chức năng được cấp.', 'Người vận hành nhận hóa đơn và số liệu công nợ đúng phạm vi.')

case('UC-BIL-05', 'Hóa đơn, hạn thanh toán hoặc ghi chú cần sửa.',
     'Người vận hành mở hóa đơn cần điều chỉnh hạn hoặc ghi chú.|Hệ thống kiểm tra hóa đơn thật, chưa bị hủy và thuộc phạm vi.|Hệ thống kiểm tra hóa đơn vẫn chưa thanh toán và số tiền đã thu bằng không.|Hệ thống lưu hạn hoặc ghi chú, trả hóa đơn.',
     '', 'B3: Hóa đơn đã có tiền thu hoặc không còn trạng thái chưa thanh toán: từ chối sửa; giữ thông tin cũ.',
     'Không thay số tiền, khoản mục hoặc lịch sử thu bằng chức năng sửa hạn và ghi chú.', 'Hạn hoặc ghi chú được thay; giá trị tiền và lịch sử thu không đổi.')

case('UC-BIL-06', 'Hóa đơn cần thay, thông tin lập hóa đơn mới và lý do, mã đối chiếu yêu cầu.',
     'Người vận hành chọn thay thế hóa đơn.|Hệ thống kiểm tra quyền, hóa đơn thật, chưa hủy và chưa có lịch sử thanh toán.|Hệ thống lập hóa đơn mới theo thông tin hợp lệ và ghi mối liên hệ thay thế.|Hệ thống giữ lịch sử hóa đơn cũ theo trạng thái thay thế, trả kết quả.',
     '', 'B2: Đã có lịch sử thanh toán hoặc không đủ điều kiện thay: từ chối, không tạo hóa đơn thay thế.',
     'Không dùng thay thế để xóa dấu vết hóa đơn đã có lịch sử thu.|Mã đối chiếu và nội dung giúp không thực hiện lặp cùng yêu cầu.', 'Có hóa đơn thay thế hợp lệ và giữ quan hệ với chứng từ cũ.')

case('UC-BIL-07', 'Hóa đơn, loại điều chỉnh tăng hoặc giảm, số tiền, lý do và mã đối chiếu.',
     'Người vận hành mở hóa đơn và chọn điều chỉnh.|Hệ thống kiểm tra quyền, trạng thái hóa đơn và thông tin điều chỉnh.|Hệ thống tính lại số phải thu theo khoản điều chỉnh được phép, giữ các khoản đã thu.|Hệ thống lưu chứng từ điều chỉnh, cập nhật tổng và tình trạng hóa đơn, trả kết quả.',
     'B2: Chọn điều chỉnh giảm: hệ thống áp giới hạn theo số đã thu và tổng hiện có trước khi ghi; kết thúc sau B4.',
     'B2: Số tiền, loại hoặc trạng thái không hợp lệ: không điều chỉnh.|B3: Giảm vượt mức được phép hoặc làm sổ tiền không hợp lệ: từ chối.',
     'Điều chỉnh tạo lịch sử tăng giảm, không xóa khoản thu cũ.|Không tự hoàn tiền người thuê chỉ vì giảm khoản phải thu.', 'Hóa đơn có khoản điều chỉnh và tổng phải thu mới hợp lệ.')

case('UC-BIL-08.1', 'Hóa đơn cần hủy, lý do và mã đối chiếu yêu cầu.',
     'Người vận hành chọn hủy hóa đơn.|Hệ thống kiểm tra quyền, phạm vi và các điều kiện lịch sử thanh toán.|Nếu đủ điều kiện, hệ thống chuyển hóa đơn sang đã hủy và xử lý các liên kết liên quan theo quy định.|Hệ thống trả chứng từ giữ lại lịch sử.',
     '', 'B2: Hóa đơn có lịch sử hoặc trạng thái không cho hủy: không hủy, trả lý do từ chối.',
     'Hủy không là xóa hóa đơn khỏi lịch sử.|Không hủy để tự xóa công nợ hoặc hoàn lại khoản đã thu.', 'Hóa đơn đủ điều kiện được đánh đã hủy, lịch sử còn nguyên.')

case('UC-BIL-09', 'Hóa đơn, số tiền thu, phương thức, ngày thu hoặc ghi chú theo biểu mẫu và mã đối chiếu.',
     'Người vận hành chọn ghi nhận thanh toán trực tiếp cho hóa đơn.|Hệ thống kiểm tra quyền, hóa đơn thật còn thu được và số dư hiện tại.|Hệ thống kiểm tra số tiền dương không vượt số còn phải thu.|Hệ thống ghi thanh toán, cập nhật số đã thu và trạng thái hóa đơn; trả kết quả.',
     'B2: Cùng yêu cầu đã được ghi với cùng nội dung: trả kết quả trước; không thu ghi thêm lần nữa; kết thúc.',
     'B2: Hóa đơn đã hủy, là dữ liệu mô phỏng hoặc ngoài phạm vi: không ghi thanh toán.|B3: Số tiền vượt dư hoặc không hợp lệ: không ghi; quay lại nhập.',
     'Ghi thanh toán trực tiếp khác với tạo khoản thu chờ phân bổ.|Đây là ghi nhận tiền đã nhận, không là lệnh thu tiền ngân hàng.', 'Hóa đơn phản ánh khoản đã thu và dư nợ mới.')

case('UC-BIL-10', 'Người thuê, số tiền, phương thức và tham chiếu khoản thu; các phân bổ ban đầu nếu có; mã đối chiếu.',
     'Người vận hành nhập khoản tiền đã nhận của người thuê.|Hệ thống kiểm tra quyền, hồ sơ và số tiền.|Hệ thống tạo khoản thu; khi có phân bổ, kiểm tra hóa đơn cùng người thuê và đủ điều kiện nhận phân bổ.|Hệ thống ghi các phân bổ hợp lệ, trả khoản thu và phần tiền còn chưa phân bổ.',
     'B3: Chưa chọn hóa đơn: lưu toàn bộ khoản thu là tiền chưa phân bổ; kết thúc sau B4.',
     'B2: Người thuê hoặc số tiền không hợp lệ: không tạo khoản thu.|B3: Phân bổ không đúng người thuê hoặc vượt số dư được phép: không hoàn tất lần xác nhận.',
     'Tiền đã nhận chưa phân bổ không tự là tiền đã thu của từng hóa đơn.', 'Khoản thu được lưu và xác định rõ tiền đã phân bổ, tiền còn khả dụng.')

case('UC-BIL-11', 'Khoản thu, mã đối chiếu và danh sách hóa đơn kèm số tiền phân bổ cho từng hóa đơn.',
     'Người vận hành chọn khoản thu và các hóa đơn cần phân bổ.|Hệ thống đối chiếu yêu cầu đã thực hiện; với yêu cầu mới, kiểm số tiền khả dụng và mỗi hóa đơn chỉ xuất hiện một lần.|Hệ thống kiểm tra các hóa đơn cùng người thuê, chưa hủy, không là mô phỏng và từng số phân bổ không vượt dư nợ.|Hệ thống ghi phân bổ và thanh toán liên quan, cập nhật số đã thu trên hóa đơn và tiền khả dụng khoản thu; trả kết quả.',
     'B2: Mã và nội dung trùng yêu cầu đã thành công: trả kết quả cũ, không tạo phân bổ lần hai; kết thúc.',
     'B2: Hóa đơn lặp hoặc tổng phân bổ vượt tiền còn khả dụng: không phân bổ.|B3: Khác người thuê hoặc vượt từng dư nợ: không lưu các thay đổi của lần xác nhận.',
     'Không chuyển tiền của người thuê này để thanh toán hóa đơn của người thuê khác.', 'Khoản thu và hóa đơn thể hiện phần phân bổ vừa được ghi.')

case('UC-BIL-12.1', 'Khoản thu, phân bổ cần giải phóng, lý do và mã đối chiếu.',
     'Người vận hành chọn giải phóng một phân bổ khoản thu.|Hệ thống kiểm tra khoản thu và phân bổ đúng phạm vi, chưa được giải phóng.|Hệ thống ghi khoản đối ứng cho thanh toán gắn với phân bổ và cập nhật hóa đơn.|Hệ thống đánh phân bổ đã giải phóng, trả lại tiền khả dụng khoản thu và cung cấp kết quả.',
     '', 'B2: Phân bổ không tồn tại hoặc đã giải phóng: không ghi thêm.|B3: Số đã thu của hóa đơn không khớp sổ: từ chối, không làm số dư âm.',
     'Giải phóng không xóa thanh toán gốc; có dấu vết đối ứng.|Tiền được trả về khoản thu chưa phân bổ, không tự hoàn cho người thuê.', 'Phân bổ được giải phóng, số dư hóa đơn và khoản thu được cập nhật.')

case('UC-BIL-12.2', 'Thanh toán trực tiếp cần đảo, lý do và mã đối chiếu.',
     'Người vận hành chọn đảo một lần thanh toán trực tiếp.|Hệ thống kiểm tra thanh toán còn đủ điều kiện và không thuộc phân bổ khoản thu.|Hệ thống kiểm tra chưa có bút toán đảo rồi ghi khoản đối ứng.|Hệ thống cập nhật số đã thu và trạng thái hóa đơn; trả kết quả.',
     '', 'B2: Thanh toán thuộc phân bổ khoản thu: không đảo trực tiếp; phải dùng giải phóng phân bổ.|B3: Thanh toán đã đảo hoặc bản thân là bút toán đảo: không ghi lần hai.',
     'Giữ thanh toán gốc và chứng từ đối ứng, không xóa dấu vết thu.', 'Hóa đơn có số dư mới sau đảo thanh toán trực tiếp.')

case('UC-BIL-13', 'Khoản thu, số tiền hoàn, lý do, tham chiếu hoàn và mã đối chiếu.',
     'Người vận hành ghi nhận tiền đã hoàn từ khoản thu.|Hệ thống kiểm tra khoản thu thuộc phạm vi và số tiền còn khả dụng.|Hệ thống kiểm tra số hoàn không vượt tiền chưa phân bổ.|Hệ thống ghi giao dịch hoàn, giảm tiền còn khả dụng và tăng số đã hoàn; trả khoản thu.',
     '', 'B3: Số hoàn vượt tiền khả dụng: không ghi hoàn; phải giải phóng phân bổ trước nếu cần dùng phần đã phân bổ.',
     'Ghi nhận hoàn không thực hiện chuyển tiền ngân hàng và không tự đảo phân bổ.', 'Sổ khoản thu phản ánh số đã hoàn và phần còn sử dụng được.')

case('UC-BIL-14', 'Chứng từ chuyển khoản đang chờ, quyết định chấp thuận hoặc từ chối và ghi chú; từ chối cần lý do.',
     'Người vận hành mở chứng từ đang chờ trong phạm vi.|Người vận hành quyết định; hệ thống kiểm tra chứng từ chưa được xử lý và quyết định hợp lệ.|Nếu chấp thuận, hệ thống kiểm tra hóa đơn thật chưa hủy và số chứng từ không vượt dư hiện tại.|Hệ thống ghi khoản thu, thanh toán và phân bổ; tăng số đã thu, chấm dứt liên kết chờ không còn phù hợp và đánh chứng từ đã chấp thuận.',
     'B3: Từ chối: chỉ lưu quyết định, người xét duyệt và lý do; không tạo khoản thu hay tăng tiền đã thu; kết thúc.',
     'B2: Chứng từ đã có quyết định: không duyệt lần nữa.|B3: Hóa đơn mô phỏng, đã hủy, đã đủ tiền hoặc chứng từ vượt dư: không ghi thanh toán.',
     'Nhân viên xem cần quyền xem hóa đơn; quyết định cần quyền duyệt chứng từ và khu được giao.', 'Chứng từ có quyết định; chỉ chấp thuận mới làm tăng số đã thu.')

case('UC-BIL-15', 'Khu, phòng khi áp dụng riêng, loại phí, tên, đơn vị tính, mức phí hoặc bậc tiêu thụ, kỳ hiệu lực, lý do và mã đối chiếu.',
     'Người vận hành chọn khu và nhập đề xuất biểu phí.|Hệ thống kiểm tra kỳ hiệu lực không ở quá khứ, thông tin loại phí và các bậc hợp lệ.|Hệ thống kiểm tra phòng thuộc khu khi có, xác định phiên bản trước và tạo đề xuất mới kèm người lập.|Hệ thống trả phiên bản chờ xét duyệt.',
     'B1: Chỉ đọc danh mục: chọn rõ khu và xem các phiên bản theo kỳ; không đổi phí; kết thúc.',
     'B2: Kỳ hiệu lực hoặc thông tin phí không hợp lệ: không tạo đề xuất.',
     'Phí dịch vụ không sử dụng bậc tiêu thụ.|Đề xuất chưa là biểu phí được áp dụng và không sửa hóa đơn đã lập.', 'Biểu phí được đề xuất, chưa tự có hiệu lực.')

case('UC-BIL-16', 'Đề xuất biểu phí, quyết định, lý do và mã đối chiếu.',
     'Chủ trọ mở phân tích tác động của đề xuất.|Hệ thống tổng hợp phòng chịu ảnh hưởng, giá riêng, hóa đơn đã lập và kỳ đã khóa; trình bày lý do chưa thể duyệt.|Chủ trọ quyết định; khi duyệt, hệ thống kiểm tra đề xuất còn chờ, kỳ không quá khứ, không ảnh hưởng kỳ đã lập hoặc khóa và sau phiên bản đã duyệt gần nhất.|Hệ thống lưu quyết định, người duyệt và thời điểm, trả phiên bản.',
     'B3: Từ chối: lưu quyết định từ chối, không đưa biểu phí vào tính tiền; kết thúc sau B4.',
     'B3: Đã có quyết định hoặc kỳ không đủ điều kiện: không chấp thuận, giữ trạng thái trước.',
     'Nhân viên có quyền xem hóa đơn chỉ xem phân tích tác động; không được xét duyệt biểu phí.|Hóa đơn cũ giữ nguyên khoản mục.', 'Đề xuất có quyết định; mức được duyệt chỉ dùng theo kỳ hợp lệ.')

case('UC-BIL-17.1', 'Khu, lựa chọn bật hoặc tắt lập định kỳ, ngày lập và quy định hạn trả.',
     'Người vận hành mở thiết lập lập hóa đơn của khu.|Hệ thống kiểm tra khu hoạt động và thuộc phạm vi, cung cấp cấu hình hiện có hoặc mặc định.|Người vận hành điều chỉnh; hệ thống kiểm tra giá trị và quyền lưu.|Hệ thống lưu thiết lập, trả kết quả.',
     'B2: Chưa có cấu hình đã lưu: chỉ hiển thị mặc định; chưa tự chạy lập hóa đơn; tiếp tục B3 nếu lưu.',
     'B2: Khu ngoài phạm vi hoặc đã lưu trữ: không lưu cấu hình.',
     'Nhân viên xem bằng quyền xem hóa đơn, thay đổi bằng quyền lập hóa đơn và khu được giao.|Lưu cấu hình chưa đồng nghĩa phát hành hóa đơn.', 'Thiết lập định kỳ được ghi nhận.')

case('UC-BIL-17.2', 'Khu và kỳ cần xem trước hoặc chạy lập hóa đơn.',
     'Người vận hành chọn khu và kỳ.|Hệ thống kiểm tra cấu hình, hợp đồng, chỉ số, phí và hóa đơn đã có; trả kết quả kiểm tra trước.|Người vận hành chọn chạy; hệ thống kiểm tra đã bật lập định kỳ, tính hạn trả từ cấu hình và thực hiện lập hàng loạt.|Hệ thống ghi kỳ, thời điểm chạy gần nhất khi thành công và trả tổng hợp.',
     'B2: Chỉ xem trước: không tạo hóa đơn hoặc ghi đã chạy; kết thúc.',
     'B3: Chưa bật cấu hình: không chạy.|B3: Dữ liệu xung đột khi lập: trả lỗi theo lần lập, không khẳng định đã tạo đầy đủ hóa đơn.',
     'Nhân viên cần quyền lập hóa đơn để xem trước hoặc chạy và chỉ trong khu được giao.', 'Có kết quả lập hàng loạt và mốc chạy thành công được ghi nhận.')

case('UC-BIL-18.1', 'Khu áp dụng, bật/tắt, mốc trước hạn, ngày đến hạn, mốc quá hạn, kênh gửi, phiên bản, lý do và mã đối chiếu.',
     'Người vận hành mở chính sách nhắc nợ.|Hệ thống kiểm tra phạm vi, cung cấp chính sách hiện hành hoặc mặc định tắt; mặc định nhắc trước 3 và 1 ngày, sau hạn 1, 7 và 30 ngày.|Người vận hành lưu; hệ thống kiểm tra khi bật có ít nhất một kênh và phiên bản chưa đổi.|Hệ thống ghi phiên bản chính sách mới, trả kết quả.',
     '', 'B3: Bật nhưng thiếu kênh hoặc phiên bản đã đổi: không lưu; người dùng sửa hoặc tải lại.',
     'Nhân viên cần quyền chính sách nhắc nợ và phải chọn khu được giao.|Chính sách này không tự thay cấu hình gửi Zalo ZNS riêng.', 'Chính sách được lưu; chưa mặc nhiên đã gửi nhắc nợ.')

case('UC-BIL-18.2', 'Khu cần tạo nhắc nợ; chính sách, lựa chọn nhận của người thuê và điều kiện kênh gửi tương ứng.',
     'Người vận hành yêu cầu tạo nhắc nợ theo chính sách.|Hệ thống chọn hóa đơn thật chưa hoặc mới thanh toán một phần, còn dư và có hạn trả, thuộc khu và chủ trọ hoạt động.|Hệ thống đối chiếu ngày Việt Nam, chính sách đang áp dụng, tình trạng người thuê và kênh được cho phép.|Hệ thống ghi các thông báo chờ gửi không trùng cùng sự kiện và trả số đã xếp chờ; việc giao nhận diễn ra theo kênh.',
     'B4: Chủ trọ chọn gửi bằng Zalo ZNS: hệ thống kiểm số điện thoại, mẫu và kênh gửi, ghi kết quả từng mục theo phản hồi; không đồng nhất với chỉ tạo thông báo trong ứng dụng.|B3: Hóa đơn không đến mốc nhắc hoặc người thuê không cho phép kênh: bỏ qua mục đó, tiếp tục kiểm các hóa đơn còn lại.',
     'B2: Khu ngoài phạm vi: không tạo nhắc nợ.|B4: Kênh ZNS thiếu điều kiện hoặc gửi lỗi: ghi kết quả thất bại cho mục tương ứng; không khẳng định đã giao.',
     'Đưa thông báo vào danh sách chờ không chứng minh người nhận đã nhận qua thư, Zalo hoặc kênh ngoài.|Nhân viên chỉ tạo nhắc theo chính sách ở khu được giao; không được tự dùng chức năng ZNS riêng.', 'Có danh sách chờ hoặc nhật ký gửi; việc giao bên ngoài chưa được xác nhận đầy đủ.')

case('UC-BIL-18.3', 'Bộ lọc danh sách thông báo hóa đơn; thông báo cần gửi lại, lý do và mã đối chiếu.',
     'Chủ trọ mở danh sách thông báo hóa đơn.|Hệ thống cung cấp mục thuộc chủ trọ theo bộ lọc trạng thái, thời gian.|Chủ trọ yêu cầu gửi lại; hệ thống chỉ đưa các mục đã hết lượt gửi hoặc đã lưu chờ về trạng thái chờ gửi, đặt lại số lần thử và lỗi.|Hệ thống thông báo có đưa lại vào danh sách chờ hay không.',
     'B3: Mục không thuộc phạm vi hoặc không ở trạng thái cho phép: không đưa lại; trả kết quả chưa thực hiện; kết thúc.',
     'B2: Nhân viên gọi chức năng này: không cho xem hoặc gửi lại; kết thúc.',
     'Gửi lại không đồng nghĩa giao thành công và không ghi thu tiền hoặc tạo hóa đơn mới.', 'Thông báo đủ điều kiện được đưa vào danh sách chờ gửi lại.')

case('UC-BIL-22', 'Khu, tháng cần khóa, lý do và mã đối chiếu.',
     'Chủ trọ chọn khóa kỳ thanh toán.|Hệ thống kiểm tra khu thuộc quyền quản lý và tháng hợp lệ.|Hệ thống ghi khóa kỳ theo khu và tháng cùng lý do, người xác nhận.|Hệ thống trả thông tin kỳ đã khóa.',
     'B3: Đã có khóa cho cùng khu và tháng: trả khóa hiện có, không tạo bản trùng; kết thúc.',
     'B2: Khu ngoài phạm vi hoặc tháng không hợp lệ: không khóa kỳ.',
     'Chỉ chủ trọ được khóa kỳ.|Chưa có chức năng mở khóa được xác nhận trong phạm vi này.', 'Kỳ được ghi nhận đã khóa theo khu.')

case('UC-BIL-23', 'Khu, tên ngân hàng, chủ tài khoản, số tài khoản và thông tin mã chuyển khoản theo biểu mẫu.',
     'Chủ trọ mở thông tin nhận chuyển khoản của khu.|Hệ thống kiểm tra khu thuộc chủ trọ.|Chủ trọ nhập hoặc điều chỉnh tài khoản nhận; hệ thống kiểm tra dữ liệu.|Hệ thống lưu thông tin để cung cấp cùng hướng dẫn chuyển khoản hóa đơn.',
     '', 'B2: Khu ngoài phạm vi: không xem hoặc sửa thông tin nhận.|B3: Thông tin không hợp lệ: không lưu; người dùng sửa lại.',
     'Lưu tài khoản nhận không xác nhận ngân hàng đã nhận tiền.|Nhân viên không có quyền thay tài khoản nhận của chủ trọ.', 'Thông tin nhận chuyển khoản của khu được cập nhật.')

case('UC-TEN-03', 'Bộ lọc hóa đơn cá nhân hoặc hóa đơn cần xem, tải và chia sẻ.',
     'Người thuê mở danh sách hóa đơn của mình.|Hệ thống xác định hồ sơ thuê liên kết và chọn hóa đơn được phép xem.|Người thuê mở chi tiết; hệ thống cung cấp khoản mục, số đã thu, còn phải trả và hướng dẫn thanh toán khi có.|Người thuê xem hoặc sử dụng bản xuất hóa đơn theo khả năng giao diện được cung cấp.',
     'B2: Chưa có hóa đơn phù hợp: hiển thị danh sách rỗng; kết thúc.',
     'B2: Chưa có hồ sơ thuê hoặc hóa đơn không thuộc người dùng: không cung cấp dữ liệu.',
     'Người thuê không sửa hóa đơn hoặc tự đánh đã thanh toán từ chức năng tra cứu.', 'Người thuê nhận thông tin hóa đơn của mình.')

case('UC-TEN-04', 'Hóa đơn của người thuê, số tiền đã chuyển, tham chiếu hoặc ghi chú và ảnh chứng từ.',
     'Người thuê mở hóa đơn và chọn gửi chứng từ chuyển khoản.|Hệ thống kiểm tra hóa đơn thuộc người thuê và còn đủ điều kiện gửi.|Người thuê cung cấp thông tin, hình ảnh; hệ thống kiểm tra số tiền và các chứng từ đang chờ.|Hệ thống lưu chứng từ ở trạng thái chờ duyệt, trả tình trạng để theo dõi.',
     '', 'B2: Hóa đơn không thuộc người dùng, đã hủy hoặc không còn số phải trả: không nhận chứng từ.|B3: Số tiền không hợp lệ hoặc vượt mức còn được phép đề nghị: không lưu; người thuê chỉnh thông tin.',
     'Gửi chứng từ chưa làm tăng số đã thanh toán; cần quyết định tại UC-BIL-14.', 'Chứng từ được gửi chờ xét duyệt; hóa đơn chưa tự được tất toán.')

case('UC-TEN-05', 'Hóa đơn thử nghiệm; liên kết thanh toán còn hiệu lực; số thẻ 4242424242424242, hạn thẻ dạng tháng/năm không trước tháng hiện tại theo giờ quốc tế, mã bảo mật ba chữ số. Chỉ nhận ba trường thông tin thẻ, mỗi trường tối đa 24 ký tự.',
     'Người thuê chọn thanh toán thử nghiệm.|Hệ thống kiểm tra chế độ thử nghiệm được bật, hóa đơn thuộc người dùng và là dữ liệu thử nghiệm.|Hệ thống tạo hoặc tái dùng liên kết đúng số dư, hiệu lực 30 phút; người dùng mở trang thanh toán.|Người dùng nhập bộ thông tin thẻ thử nghiệm và xác nhận; hệ thống kiểm tra liên kết, thông tin thẻ, trạng thái, thời hạn và số dư còn khớp.|Hệ thống ghi thanh toán mô phỏng, cập nhật hóa đơn và phiên thử nghiệm, hiển thị kết quả; không phát sinh tiền thật.',
     'B3: Đã có liên kết còn hạn, cùng số tiền: sử dụng liên kết đó, không tạo phiên mới; tiếp tục B4.|B4: Đã thanh toán trước đó và thông tin thẻ vẫn hợp lệ: trả kết quả đã ghi, không tạo thanh toán lần hai; kết thúc.',
     'B2: Đang vận hành chính thức, chưa bật chế độ thử hoặc là hóa đơn thật: không mở thanh toán.|B4: Thẻ sai, liên kết không có, hết hạn, bị hủy hoặc số dư đổi: không ghi thanh toán; người dùng chỉnh thông tin hoặc tạo liên kết mới theo thông báo.|B4: Yêu cầu xác nhận từ trang không được chấp nhận: từ chối, không ghi tiền.',
     'Không sử dụng thông tin thẻ ngân hàng thật.|Tạo liên kết yêu cầu người thuê đăng nhập và sở hữu hóa đơn; người có liên kết thử nghiệm hợp lệ có thể mở trang xác nhận mà không đăng nhập lại.|Kiểm tra thẻ được thực hiện trước cả nhánh trả kết quả đã thanh toán.', 'Chỉ dữ liệu mô phỏng được cập nhật; không thu tiền thực.')

case('UC-TEN-08.2', 'Lựa chọn nhận nhắc nợ trong ứng dụng, qua thư điện tử hoặc Zalo theo các kênh được cung cấp.',
     'Người thuê mở lựa chọn nhận nhắc nợ.|Hệ thống xác định hồ sơ cá nhân và cung cấp lựa chọn hiện có hoặc mặc định.|Người thuê bật hoặc tắt từng kênh; hệ thống kiểm tra và lưu lựa chọn.|Hệ thống trả thiết lập cá nhân; các lần tạo nhắc nợ dùng lựa chọn đang áp dụng.',
     'B2: Chưa có thiết lập riêng: hiển thị giá trị mặc định, chưa gửi thông báo chỉ vì mở trang; tiếp tục B3.',
     'B2: Không có hồ sơ người thuê hợp lệ hoặc phiên hết hiệu lực: không thay lựa chọn.',
     'Lựa chọn kênh không thay chính sách nhắc nợ của chủ trọ và không bảo đảm kênh ngoài đã được kết nối.', 'Sở thích nhận nhắc nợ của người thuê được lưu.')

for identifier, action, details, constraints in [
    ('UC-TEN-07.1', 'gia hạn', 'ngày kết thúc đề nghị', 'Ngày kết thúc đề nghị phải sau thời hạn hiện tại; không kèm phòng chuyển hoặc ngày bắt đầu trả phòng.'),
    ('UC-TEN-07.2', 'chuyển phòng', 'phòng đích và ngày chuyển đề nghị', 'Phòng đích phải thuộc khu được phép, đang hoạt động và còn trống; ngày đề nghị phải hợp lệ.'),
    ('UC-TEN-07.3', 'trả phòng', 'ngày trả đề nghị', 'Ngày trả không trước hôm nay hoặc ngày bắt đầu hợp đồng; không nhận phòng chuyển hoặc ngày kết thúc gia hạn.'),
]:
    case(identifier, f'Hợp đồng của người thuê, {details} và nội dung đề nghị.',
         f'Người thuê mở đề nghị {action} của mình.|Hệ thống kiểm tra có hợp đồng đang hiệu lực và chưa có yêu cầu đang chờ tương ứng.|Người thuê nhập đề nghị; hệ thống kiểm tra ngày và thông tin liên quan.|Hệ thống lưu yêu cầu chờ xét duyệt và cung cấp để theo dõi.',
         'B4: Người thuê hủy khi yêu cầu vẫn chờ và thông tin chưa thay đổi: hệ thống đánh đã hủy, không đổi hợp đồng; kết thúc.',
         'B2: Không có hợp đồng hiệu lực hoặc đã có đề nghị đang chờ: không tạo yêu cầu trùng.|B3: Ngày hoặc phòng không hợp lệ: không lưu; người thuê điều chỉnh.',
         constraints + '|Gửi đề nghị không tự thay đổi thời hạn, chuyển hoặc kết thúc hợp đồng.', 'Có yêu cầu chờ xét duyệt; hợp đồng hiện tại chưa thay đổi.')

case('UC-BIL-19', 'Khu, phòng khi có, ngày chi, nhóm chi, số tiền, ghi chú và chứng từ theo biểu mẫu.',
     'Người vận hành mở sổ chi hoặc nhập khoản chi.|Hệ thống kiểm tra khu, phòng thuộc phạm vi và dữ liệu khoản chi.|Hệ thống lưu khoản chi hoặc cập nhật theo thao tác được phép.|Hệ thống trả danh sách hoặc khoản chi sau xử lý.',
     'B1: Chỉ tra cứu: cung cấp danh sách theo bộ lọc; không tạo khoản chi; kết thúc.',
     'B2: Ngoài phạm vi hoặc dữ liệu không hợp lệ: không lưu khoản chi.',
     'Khoản chi vận hành được tách với tiền thuê và tiền cọc; ghi nhận không tự chuyển tiền ngân hàng.', 'Sổ chi phản ánh thông tin đã được xác nhận.')

case('UC-OPS-01', 'Khu hoặc phòng, nội dung, mức ưu tiên bảo trì; phiếu và nội dung trao đổi khi theo dõi.',
     'Người vận hành mở danh sách hoặc tạo phiếu bảo trì.|Hệ thống kiểm tra phạm vi khu, phòng và dữ liệu yêu cầu.|Hệ thống ghi phiếu và cung cấp thông tin để theo dõi.|Người vận hành bổ sung trao đổi; hệ thống kiểm tra quyền phiếu rồi lưu nội dung.',
     'B1: Chỉ xem hoặc gỡ phiếu trong điều kiện được phép: hệ thống kiểm tra ràng buộc trước khi thực hiện; kết thúc nhánh.',
     'B2: Khu hoặc phòng không hợp lệ; hoặc B4 phiếu ngoài phạm vi: không ghi thay đổi.',
     'Tạo phiếu hoặc trao đổi không đồng nghĩa bảo trì đã hoàn thành hay có khoản chi.', 'Phiếu và trao đổi được lưu, chưa tự tạo chi phí.')

case('UC-OPS-02', 'Phiếu, người phụ trách, tiến độ, hạn xử lý và thông tin được phép cập nhật.',
     'Người vận hành mở phiếu và danh sách người có thể nhận.|Hệ thống chỉ cung cấp nhân viên đang hoạt động, có quyền bảo trì phù hợp và được giao khu.|Người vận hành phân công hoặc sửa tiến độ; hệ thống kiểm tra tình trạng phiếu và khoản chi đã liên kết.|Hệ thống lưu nội dung, trạng thái, phân công và trả phiếu.',
     'B1: Chủ trọ kiểm tra quá hạn: hệ thống ghi chuyển cấp cho phiếu mới hoặc đang xử lý đã quá hạn và chưa được chuyển; trả số kiểm tra, số chuyển cấp; kết thúc.',
     'B2: Người nhận không còn đủ quyền hoặc khu: không phân công.|B3: Đã liên kết khoản chi nhưng sửa khu, phòng hoặc chi phí thực tế trái ràng buộc: không cập nhật.',
     'Nhân viên không được chạy chức năng chuyển cấp quá hạn riêng của chủ trọ.', 'Phiếu được phân công, cập nhật hoặc ghi mốc chuyển cấp hợp lệ.')

case('UC-OPS-03', 'Phiếu, chi phí thực tế, có ghi khoản chi hay không, thời điểm hoàn thành và ghi chú.',
     'Người vận hành yêu cầu hoàn tất phiếu.|Hệ thống kiểm tra phiếu thuộc phạm vi và chưa bị hủy.|Hệ thống đối chiếu chi phí thực tế; không cho thay số đã gắn với khoản chi.|Nếu có yêu cầu ghi chi, chi phí dương và chưa liên kết, hệ thống ghi khoản chi sửa chữa; đánh phiếu đã xong và lưu liên kết.|Hệ thống cung cấp phiếu đã hoàn tất.',
     'B4: Không yêu cầu ghi chi, chi phí bằng không hoặc đã có khoản chi: không tạo khoản chi mới; chỉ cập nhật phiếu đủ điều kiện; tiếp tục B5.',
     'B2: Phiếu đã hủy hoặc ngoài phạm vi: không hoàn tất.|B3: Chi phí khác với khoản đã liên kết: từ chối, không ghi chi lần nữa.',
     'Không phải mỗi lần xác nhận hoàn tất đều tạo khoản chi; chỉ tạo một lần theo liên kết.', 'Phiếu đã xong và có khoản chi liên kết khi đủ điều kiện.')

case('UC-TEN-06', 'Nội dung, mức ưu tiên bảo trì và phiếu, nội dung trao đổi khi theo dõi.',
     'Người thuê mở bảo trì của mình.|Người thuê gửi yêu cầu; hệ thống tìm hợp đồng đang hiệu lực thuộc hồ sơ cá nhân.|Hệ thống tạo phiếu mới gắn đúng khu, phòng hợp đồng.|Người thuê trao đổi trên phiếu của mình; hệ thống kiểm tra quyền trước khi lưu.',
     'B1: Chỉ xem danh sách: không tạo phiếu; kết thúc.',
     'B2: Không có hợp đồng hiệu lực: không tạo yêu cầu.|B4: Phiếu không thuộc người thuê: không cung cấp hoặc ghi trao đổi.',
     'Người thuê không tự hoàn tất bảo trì hoặc gắn khoản chi thay người vận hành.', 'Yêu cầu hoặc trao đổi được lưu đúng hồ sơ cá nhân.')

case('UC-OPS-04', 'Nhóm việc, khu và trang kết quả; mục cần đánh dấu đã đọc.',
     'Chủ trọ mở danh sách việc cần xử lý.|Hệ thống kiểm tra quyền theo nhóm việc và khu.|Hệ thống tổng hợp lịch xem, nợ, chứng từ, bảo trì, hợp đồng sắp hạn và kiểm tra định kỳ; tính số lượng và chưa đọc.|Hệ thống trình bày theo mức ưu tiên, hạn và trang kết quả.',
     'B4: Đánh đã đọc một mục còn trong danh sách: hệ thống lưu dấu đọc theo tài khoản; kết thúc.',
     'B2: Không có quyền xem nhóm hoặc khu: không trả danh sách.|B4: Mục không còn thuộc danh sách: không tạo dấu đọc tùy ý.',
     'Nhân viên chưa được phép dùng chức năng này.|Đánh đã đọc không tự hoàn thành công việc nguồn.', 'Có danh sách việc và dấu đọc cá nhân khi được chọn.')

case('UC-OPS-05', 'Phòng, hồ sơ chuẩn bị lại phòng, bước hiện tại, phiên bản và ghi chú xác nhận.',
     'Chủ trọ mở hồ sơ hoặc bắt đầu cho phòng hoạt động không có hợp đồng đang hiệu lực.|Hệ thống ghi nhận đã tiếp nhận phòng trả lại và phòng chờ bảo trì.|Chủ trọ xác nhận bước; hệ thống kiểm tra đúng phiên bản, đúng bước và không có hợp đồng hiệu lực.|Hệ thống lần lượt chuyển kiểm tra, sửa chữa, vệ sinh và sẵn sàng; không cho rời sửa chữa khi còn việc mới hoặc đang xử lý.|Khi hoàn tất, hệ thống đánh hồ sơ xong và đưa phòng về trống, xóa tên người thuê hiển thị cũ.',
     'B1: Chỉ tra cứu: không chuyển bước; kết thúc.',
     'B3: Phiên bản hoặc bước đã thay đổi, có hợp đồng hiệu lực: không chuyển bước.|B4: Còn sửa chữa chưa xong: không đưa phòng sẵn sàng.',
     'Không đưa phòng về trống chỉ vì hợp đồng đã kết thúc.', 'Phòng đủ điều kiện cho thuê lại khi quy trình được hoàn tất.')

case('UC-OPS-06', 'Khu hoặc phòng, nội dung công việc, chu kỳ, thời gian, hạn và danh sách mục kiểm tra.',
     'Chủ trọ mở thiết lập công việc định kỳ.|Chủ trọ nhập hoặc sửa quy tắc, chọn khu hoặc phòng và chu kỳ.|Hệ thống kiểm tra phạm vi, dữ liệu lịch và trạng thái.|Hệ thống lưu quy tắc bật hoặc tắt để tạo công việc theo lịch.',
     'B3: Tắt quy tắc: ngừng áp dụng lịch theo cấu hình, không xóa lịch sử công việc; kết thúc.',
     'B3: Khu, phòng hoặc lịch không hợp lệ: không lưu quy tắc.',
     'Quy tắc công việc khác với việc đã được tạo và hoàn thành.', 'Lịch công việc được lưu theo phạm vi của chủ trọ.')

case('UC-OPS-06.1', 'Đầu việc đã tạo từ lịch, mục kiểm tra, tình trạng hoàn thành và phiên bản thông tin.',
     'Chủ trọ mở đầu việc định kỳ.|Hệ thống kiểm tra đầu việc thuộc phạm vi và cung cấp danh sách kiểm tra.|Chủ trọ cập nhật mục kiểm tra hoặc xác nhận hoàn thành; hệ thống đối chiếu thông tin hiện hành.|Hệ thống lưu tiến độ và kết quả đầu việc.',
     'B3: Chỉ cập nhật một mục: lưu mục đó và giữ phần còn lại theo hiện trạng; kết thúc.',
     'B2: Đầu việc ngoài phạm vi hoặc đã thay đổi: không ghi đè.|B3: Chưa đáp ứng điều kiện hoàn tất: không đánh đầu việc đã xong.',
     'Hoàn thành đầu việc không tự sửa lịch lặp hoặc ghi chi phí.', 'Tiến độ và kết quả công việc định kỳ được ghi nhận.')

case('UC-OPS-07', 'Tiêu đề, nội dung, khu, người nhận, lịch gửi hoặc mẫu thông báo và nhóm người nhận.',
     'Chủ trọ soạn thông báo hoặc chọn mẫu và nhóm nhận.|Hệ thống kiểm tra người nhận và khu thuộc phạm vi.|Chủ trọ lưu hoặc phát theo lịch; hệ thống ghi thông báo và danh sách nhận.|Chủ trọ theo dõi thời điểm gửi, lượt đọc và kết quả theo từng người nhận.',
     'B1: Quản lý mẫu hoặc nhóm người nhận: hệ thống lưu thông tin trong phạm vi chủ trọ; chưa gửi thông báo; kết thúc.',
     'B2: Người nhận hoặc khu không hợp lệ: không phát theo danh sách sai.|B3: Chưa đến lịch: không coi thông báo đã được phát đến người nhận.',
     'Lượt đọc, xác nhận đã nhận và giao qua dịch vụ ngoài là các kết quả khác nhau.', 'Thông báo và tình trạng người nhận được ghi theo tiến trình thực tế.')

case('UC-SUP-04', 'Hộp thông báo được cấp, trang kết quả, mục đánh đã đọc và các lựa chọn nhận thông báo cá nhân.',
     'Người dùng mở hộp thông báo phù hợp vai trò.|Hệ thống xác định tài khoản và chỉ cung cấp thông báo được phép xem.|Người dùng mở hoặc đánh đã đọc; hệ thống lưu trạng thái theo tài khoản.|Người dùng thay lựa chọn nhận nếu chức năng hỗ trợ; hệ thống lưu và trả kết quả.',
     'B3: Chọn đánh tất cả đã đọc: cập nhật các mục của tài khoản trong hộp được chọn; kết thúc.',
     'B2: Không có quyền với hộp hoặc thông báo: không cung cấp và không sửa dấu đọc.',
     'Thông báo người thuê, vận hành và quản trị có phạm vi riêng, không tự trộn thành một hộp dùng chung.', 'Người dùng nhận thông báo cá nhân, dấu đọc và thiết lập khi có.')

case('UC-SUP-06', 'Câu hỏi và ngữ cảnh hướng dẫn trong phạm vi chủ trọ; nguồn hướng dẫn cần đọc khi chọn.',
     'Chủ trọ đặt câu hỏi về cách sử dụng.|Hệ thống kiểm tra quyền, độ hợp lệ của câu hỏi và phạm vi nguồn hướng dẫn.|Hệ thống tìm căn cứ phù hợp và, khi dịch vụ trả lời đã sẵn sàng, tạo câu trả lời theo căn cứ.|Hệ thống hiển thị câu trả lời cùng nguồn được phép xem hoặc thông báo chưa đủ căn cứ.',
     'B3: Không đủ nguồn hoặc dịch vụ trả lời chưa khả dụng: cung cấp cách trả lời dự phòng có giới hạn, không bịa thông tin nghiệp vụ; kết thúc.',
     'B2: Câu hỏi không hợp lệ hoặc tính năng chưa bật: không xử lý.|B3: Đang bận hoặc quá thời gian: trả trạng thái tương ứng, không xác nhận đã thực hiện nghiệp vụ.',
     'Trợ lý hướng dẫn, không thay người dùng lập hợp đồng, thu tiền hoặc sửa hồ sơ.|Chưa kiểm chứng đầy đủ việc trả lời qua dịch vụ bên ngoài.', 'Người dùng có hướng dẫn kèm căn cứ hoặc thông báo giới hạn rõ ràng.')

case('UC-TEN-09.2', 'Nội dung tin nhắn và hội thoại mô phỏng của người thuê.',
     'Người thuê mở kênh trao đổi mô phỏng.|Hệ thống xác định người thuê và hội thoại được phép xem.|Người thuê gửi nội dung; hệ thống lưu tin trong ứng dụng theo chế độ mô phỏng.|Hệ thống hiển thị tin và tình trạng ghi nhận mô phỏng.',
     'B1: Chỉ xem lịch sử: không tạo tin mới; kết thúc.',
     'B2: Không có hồ sơ hoặc không đúng hội thoại: không xem, gửi tin.|B3: Nội dung không hợp lệ: không lưu; người dùng sửa lại.',
     'Không coi trạng thái đã gửi trong mô phỏng là bằng chứng tin đã được giao qua Zalo thật.', 'Tin được lưu trong ứng dụng; chưa xác nhận giao nhận Zalo thực tế.')

case('UC-TEN-09.3', 'Thông báo chủ trọ gửi cho người thuê và lựa chọn xác nhận đã nhận khi được yêu cầu.',
     'Người thuê mở thông báo của chủ trọ.|Hệ thống kiểm tra người thuê có trong phạm vi người nhận.|Hệ thống cung cấp nội dung và ghi lượt đọc theo chức năng.|Người thuê xác nhận đã nhận nếu thông báo hỗ trợ; hệ thống lưu thời điểm xác nhận.',
     'B3: Chỉ đọc thông báo: ghi tình trạng đọc, không tự coi là đã xác nhận riêng; kết thúc.',
     'B2: Không thuộc người nhận: không cung cấp hoặc ghi lượt đọc.',
     'Đã đọc và xác nhận đã nhận là hai trạng thái riêng.', 'Lượt đọc hoặc xác nhận của đúng người nhận được ghi.')

case('UC-ADM-01', 'Khoảng thời gian và trang danh sách việc cần xử lý theo quyền quản trị.',
     'Quản trị viên mở tổng quan nền tảng.|Hệ thống kiểm tra quyền tổng quan và quyền xem từng nhóm dữ liệu.|Hệ thống tổng hợp tài khoản, khu, phòng, hợp đồng, tài chính và công việc được phép.|Hệ thống hiển thị thời điểm số liệu, chỉ số và tình trạng từng nguồn; phần chưa sẵn sàng được ghi rõ.',
     'B3: Không có quyền ở một nhóm: không cung cấp dữ liệu nhóm đó; các nhóm còn được phép tiếp tục hiển thị.',
     'B2: Không có quyền tổng quan: từ chối.|B3: Một nguồn chưa sẵn sàng: không lấy số không làm kết quả thật; trình bày giới hạn.',
     'Chưa có nghiệp vụ thu tiền gói nên không trình bày giá gói là doanh thu đã thu.', 'Quản trị viên nhận tổng quan theo thẩm quyền, không làm thay đổi giao dịch.', 'Theo dõi hoạt động nền tảng và công việc cần xử lý theo quyền được cấp.')

case('UC-ADM-14', 'Khoảng ngày, người thực hiện, loại đối tượng và hành động; lựa chọn xuất bảng dữ liệu.',
     'Quản trị viên mở nhật ký.|Hệ thống kiểm tra quyền xem và điều kiện lọc.|Hệ thống cung cấp hoạt động trong phạm vi được phép.|Nếu chọn xuất và có quyền xuất, hệ thống tạo bảng dữ liệu; nếu không, chỉ trả kết quả xem.',
     'B3: Không có hoạt động khớp: trả danh sách trống; kết thúc.',
     'B2: Không đủ quyền hoặc thời gian không hợp lệ: không cung cấp dữ liệu.|B4: Thiếu quyền xuất: không xuất dù có thể vẫn được xem.',
     'Quyền xuất khác quyền xem.|Nhật ký được đọc, không sửa hoặc xóa dấu vết bằng chức năng này.', 'Có danh sách hoặc bản xuất nhật ký theo quyền.', 'Tra cứu và xuất lịch sử quản trị phục vụ theo dõi trách nhiệm xử lý.')

case('UC-ADM-16', 'Tên và loại báo cáo, lịch, múi giờ, điều kiện lọc; lần chạy hoặc kết quả cần tải.',
     'Quản trị viên mở lịch báo cáo của mình.|Quản trị viên thiết lập thời gian và điều kiện; hệ thống kiểm tra quyền và giá trị.|Hệ thống ghi lịch; khi đến hạn, kiểm tra lại quyền chủ lịch trước khi tạo báo cáo.|Hệ thống cung cấp tình trạng từng lần tạo và cho tải kết quả còn hiệu lực, đúng chủ sở hữu.',
     'B3: Chỉ lưu hoặc tắt lịch: không coi báo cáo đã được tạo; kết thúc.',
     'B3: Quyền bị thu hồi hoặc dữ liệu không thể cung cấp: không xác nhận có báo cáo hoàn chỉnh.|B4: Kết quả hết hạn hoặc không thuộc người dùng: không cho tải.',
     'Kết quả có thời hạn 7 ngày; cách lưu bên ngoài tùy cấu hình.|Đã chờ tạo không có nghĩa đã có báo cáo để tải.', 'Lịch và các kết quả được theo dõi theo tình trạng thực tế.', 'Chủ động nhận và tải báo cáo quản trị theo lịch đã thiết lập.')

case('UC-BIL-20', 'Khu, kỳ hoặc khoảng thời gian phân tích; các bộ lọc và lựa chọn xuất.',
     'Người vận hành chọn báo cáo thu, chi, công nợ hoặc công suất.|Hệ thống kiểm tra quyền xem và phạm vi khu.|Hệ thống tổng hợp theo định nghĩa của từng báo cáo, tách tiền đã thu, cọc, chi và tiền chưa phân bổ.|Hệ thống hiển thị kết quả; khi có quyền xuất, tạo bảng dữ liệu theo bộ lọc.',
     'B3: Không có số liệu trong kỳ: hiển thị tập rỗng hoặc tổng tương ứng; không tạo giao dịch; kết thúc.',
     'B2: Không đủ quyền hoặc bộ lọc không hợp lệ: không cung cấp báo cáo.|B4: Thiếu quyền xuất: không tạo bản xuất.',
     'Không coi mọi khoản nhận, tiền cọc hoặc số phải thu là cùng một loại doanh thu.', 'Người vận hành có báo cáo và bản xuất trong phạm vi được cấp.')

case('UC-OPS-09', 'Bộ lọc hành động, người thực hiện, đối tượng và thời gian nhật ký vận hành.',
     'Chủ trọ mở nhật ký vận hành.|Hệ thống giới hạn nhật ký theo chủ trọ và các điều kiện được chọn.|Hệ thống lấy hoạt động theo thứ tự, trang kết quả.|Hệ thống hiển thị dấu vết đã ghi.',
     'B3: Không có hoạt động phù hợp: trả danh sách trống; kết thúc.',
     'B2: Nhân viên hoặc tác nhân không được cấp chức năng: từ chối.',
     'Tra cứu nhật ký không sửa nội dung giao dịch hoặc dấu vết.', 'Nhật ký được cung cấp chỉ đọc đúng phạm vi.')

case('UC-OPT-01', 'Khu và điều kiện tổng quan, lựa chọn phòng trên sơ đồ phòng.',
     'Người vận hành mở trang tổng quan hoặc sơ đồ phòng.|Hệ thống xác định khu được phép và kiểm tra quyền xem báo cáo.|Hệ thống tổng hợp chỉ số và trạng thái phòng trong phạm vi.|Hệ thống hiển thị tổng quan; người dùng mở phòng cụ thể từ sơ đồ.',
     'B3: Chưa có khu hoặc phòng phù hợp: trả trạng thái trống theo dữ liệu, không thêm phòng minh họa vào nghiệp vụ; kết thúc.',
     'B2: Không có quyền xem báo cáo: không cung cấp tổng quan.',
     'Quyền xem phòng không tự thay cho quyền xem tổng quan báo cáo.', 'Người dùng theo dõi phòng và chỉ số đúng phạm vi.', 'Theo dõi hoạt động và truy cập nhanh thông tin phòng được giao quản lý.')

case('UC-SUP-05.1', 'Bộ lọc sự cố; hành động tiếp nhận, phân công, tạm hoãn, mở lại hoặc kết thúc; phiên bản và lý do.',
     'Quản trị viên mở tình trạng hoạt động và các sự cố.|Hệ thống cung cấp điều kiện đang có vấn đề, lịch sử và hướng dẫn xử lý trong phạm vi quyền.|Quản trị viên chọn hành động; hệ thống kiểm tra phiên bản, bước chuyển và người phụ trách đủ điều kiện.|Hệ thống lưu người xử lý, trạng thái, thời điểm và nhật ký.',
     'B3: Tạm hoãn tối đa 24 giờ, tiếp nhận sự cố mới hoặc mở lại sự cố đã kết thúc: xử lý đúng điều kiện hành động; tiếp tục B4.',
     'B3: Phiên bản cũ, chuyển sai bước hoặc muốn kết thúc khi nguyên nhân còn tồn tại: không cập nhật.',
     'Ghi sự cố đã xử lý không tự khắc phục nguyên nhân.|Báo cáo còn cần nghiệm thu không được coi là đã sẵn sàng vận hành chính thức.', 'Tình trạng xử lý sự cố và dấu vết trách nhiệm được cập nhật.')

case('UC-SUP-05.2', 'Loại yêu cầu giao nhận, trạng thái và mục cần gửi lại.',
     'Quản trị viên tra danh sách giao nhận theo quyền.|Hệ thống cung cấp tình trạng gửi, thông tin lỗi đã che và khả năng gửi lại của từng loại.|Quản trị viên xem thông báo nền tảng; hệ thống trả số lượng và tối đa 100 mục hết lượt gửi.|Quản trị viên gửi lại thông báo đủ điều kiện, chưa quá 7 ngày; hệ thống chuyển về chờ và đặt lại số lần thử.',
     'B2: Yêu cầu giao liên kết truy cập được đánh không cho gửi lại: chỉ xem; không tự mở rộng quyền gửi lại; kết thúc.',
     'B4: Không ở trạng thái hết lượt gửi hoặc quá 7 ngày: không đưa lại vào danh sách chờ.',
     'Mỗi loại yêu cầu có điều kiện gửi lại riêng; đã chờ gửi không chứng minh dịch vụ ngoài đã giao.', 'Thông báo phù hợp được xếp chờ lại; kết quả giao nhận chưa được xác nhận chỉ bằng thao tác này.', 'Theo dõi giao nhận và đưa lại các thông báo đủ điều kiện vào danh sách chờ.')

case('UC-ADM-02', 'Loại tài khoản, tình trạng, khoảng ngày và tài khoản cần xem.',
     'Quản trị viên mở tra cứu tài khoản.|Hệ thống kiểm tra quyền xem; một số chức năng quản lý chủ trọ còn yêu cầu quyền quản lý tài khoản.|Hệ thống kiểm tra khoảng ngày và loại tài khoản, cung cấp thông tin cá nhân được che.|Khi xem chủ trọ, hệ thống cung cấp tổng khu, phòng, người thuê và hợp đồng tương ứng.',
     'B3: Không có tài khoản phù hợp: trả trang trống; kết thúc.',
     'B3: Khoảng ngày đảo ngược, loại tài khoản không được phép hoặc tài khoản không có: không cung cấp dữ liệu.',
     'Quyền xem tài khoản không tự được xem đầy đủ thông tin cá nhân.|Không dùng tra cứu khách hàng để đọc hồ sơ quản trị viên ngoài quyền.', 'Thông tin tài khoản và số liệu liên quan được cung cấp chỉ đọc.', 'Tra cứu tài khoản và tình trạng sử dụng trong phạm vi quản trị.')

case('UC-ADM-03.1', 'Họ tên, thư điện tử, số điện thoại và lý do mời chủ trọ; mật khẩu chỉ khi tạo trực tiếp ở môi trường thử nghiệm.',
     'Quản trị viên chọn tạo hoặc mời chủ trọ.|Với lời mời, hệ thống kiểm tra quyền tổng quan, quyền quản lý tài khoản và kênh giao liên kết đã sẵn sàng.|Hệ thống kiểm tra thư điện tử chưa có, tạo tài khoản chủ trọ và yêu cầu giao liên kết kích hoạt.|Hệ thống trả kết quả đã tiếp nhận chờ gửi, không cung cấp mã liên kết riêng cho người quản trị.',
     'B1: Ở môi trường thử nghiệm, tạo trực tiếp với mật khẩu: hệ thống lưu tài khoản và trả hồ sơ; không khẳng định đã gửi thư; kết thúc.',
     'B2: Chưa sẵn sàng giao liên kết: không xác nhận đã gửi lời mời.|B3: Thư điện tử trùng: không tạo tài khoản thứ hai.',
     'Môi trường vận hành chính thức không cho tạo trực tiếp bằng mật khẩu, phải theo lời mời.', 'Tài khoản và lời mời được tạo theo nhánh được phép; giao liên kết còn phụ thuộc kênh ngoài.', 'Tạo quyền truy cập cho chủ trọ mới theo phương thức được phép.')

case('UC-ADM-03.2', 'Chủ trọ, họ tên hoặc số điện thoại cần cập nhật.',
     'Quản trị viên mở hồ sơ chủ trọ.|Hệ thống kiểm tra mục tiêu đúng là tài khoản chủ trọ và còn tồn tại.|Quản trị viên gửi thông tin; hệ thống chuẩn hóa, lưu họ tên hoặc điện thoại và nhật ký.|Hệ thống trả hồ sơ cập nhật.',
     '', 'B2: Không có chủ trọ phù hợp: không cập nhật tài khoản loại khác.',
     'Không thay thư điện tử, mật khẩu hoặc quyền qua chức năng sửa hồ sơ này.', 'Thông tin cá nhân được phép của chủ trọ được cập nhật.')

case('UC-ADM-04.1', 'Tài khoản khách hàng, phiên bản, trạng thái đình chỉ hoặc khôi phục và lý do.',
     'Quản trị viên chọn đình chỉ hoặc khôi phục tài khoản.|Hệ thống đối chiếu phiên bản, loại tài khoản và trạng thái đích khác hiện tại.|Hệ thống cập nhật tình trạng, thu hồi các phiên cũ và làm mất hiệu lực các liên kết truy cập chưa dùng.|Nếu đình chỉ chủ trọ, hệ thống còn thu hồi phiên nhân viên phụ thuộc; ghi nhật ký và trả tài khoản.',
     'B1: Thực hiện tại hồ sơ quản lý chủ trọ: vẫn kiểm tra thẩm quyền, không cho tự thay trạng thái trái điều kiện; kết thúc sau cập nhật.',
     'B2: Phiên bản hoặc trạng thái đã đổi: không ghi đè; người quản trị tải lại.',
     'Khôi phục không làm sống lại phiên đã thu hồi.|Trạng thái quản trị viên được quản lý qua nghiệp vụ quản trị riêng; không xóa dữ liệu thuê khi đình chỉ.', 'Tình trạng tài khoản và hiệu lực truy cập thay đổi; dữ liệu nghiệp vụ được giữ.')

case('UC-ADM-04.3', 'Tài khoản cần thu hồi phiên, lý do và phiên bản khi chức năng yêu cầu.',
     'Quản trị viên chọn thu hồi phiên của tài khoản khác.|Hệ thống kiểm tra thẩm quyền theo loại tài khoản đích.|Hệ thống làm mất hiệu lực các phiên và thông tin duy trì truy cập của mục tiêu theo phạm vi lệnh.|Hệ thống ghi nhật ký và cung cấp kết quả.',
     '', 'B2: Không đủ quyền với loại tài khoản hoặc mục tiêu không hợp lệ: không thu hồi.',
     'Đây là thu hồi phiên tài khoản khác, khác với tự quản lý phiên cá nhân.|Không xóa hồ sơ hoặc dữ liệu tài chính khi thu hồi phiên.', 'Phiên bị chỉ định không tiếp tục được dùng.')

case('UC-ADM-05.1', 'Tài khoản, trường thông tin cá nhân muốn xem, lý do và thông tin xác minh bảo mật theo yêu cầu.',
     'Quản trị viên yêu cầu xem thông tin đang được che.|Hệ thống kiểm tra quyền xem thông tin cá nhân và bước xác nhận bảo mật cần thiết.|Hệ thống kiểm tra tài khoản và lý do trước khi cung cấp dữ liệu.|Hệ thống ghi dấu vết người xem, nội dung yêu cầu và trả thông tin được phép.',
     '', 'B2: Thiếu quyền hoặc chưa hoàn thành xác minh: không mở thông tin.|B3: Không có mục tiêu phù hợp: không cung cấp dữ liệu.',
     'Quyền xem danh sách tài khoản không bao gồm mở dữ liệu cá nhân đầy đủ.', 'Thông tin cần thiết được cung cấp có kiểm soát và có nhật ký.')

case('UC-ADM-05.2', 'Tài khoản cần khôi phục, lý do và xác nhận bảo mật theo yêu cầu.',
     'Quản trị viên chọn yêu cầu khôi phục truy cập cho tài khoản.|Hệ thống kiểm tra quyền, tình trạng tài khoản và điều kiện gửi liên kết.|Hệ thống tạo yêu cầu giao liên kết đặt mật khẩu mới.|Hệ thống trả kết quả đã tiếp nhận chờ giao, ghi nhật ký.',
     '', 'B2: Tài khoản hoặc kênh giao không đủ điều kiện: không xác nhận đã gửi liên kết.',
     'Không trả mật khẩu mới hoặc cho quản trị viên đọc mật khẩu người dùng.|Chỉ người có liên kết hợp lệ thực hiện đặt mật khẩu; chưa chứng minh thư đã đến.', 'Yêu cầu khôi phục được ghi nhận; chưa đồng nghĩa người dùng đã khôi phục thành công.', 'Hỗ trợ người dùng nhận lại quyền truy cập bằng liên kết đặt mật khẩu.')

case('UC-ADM-06.1', 'Quản trị viên mục tiêu, mẫu quyền hoặc quyền cụ thể, tình trạng hoạt động, phiên bản và lý do; thông tin người nhận khi mời.',
     'Quản trị viên đủ thẩm quyền mở hồ sơ cấp quyền mục tiêu.|Hệ thống kiểm tra quyền hợp lệ, không trùng, có quyền tổng quan và không vượt quyền người cấp; quyền tùy biến cần quản trị viên toàn quyền đang hoạt động.|Hệ thống kiểm tra không tự sửa mình, phiên bản hiện hành và giữ ít nhất một quản trị viên toàn quyền hoạt động.|Hệ thống lưu hồ sơ quyền, đặt lại mốc rà soát và thu hồi các phiên cũ; khi ngừng tài khoản, làm mất hiệu lực liên kết chưa dùng.',
     'B1: Mời quản trị viên mới: cần quyền tổng quan, quản lý quản trị viên và xác thực nhiều yếu tố; chỉ mời theo mẫu hỗ trợ, kiểm duyệt hoặc phân tích trong quyền được ủy quyền; kết thúc.|B1: Gửi lại lời mời đủ điều kiện và cách lần trước ít nhất 60 giây: hệ thống ghi lại phiên bản và yêu cầu giao mới; kết thúc.',
     'B2: Cấp vượt quyền, mẫu sai hoặc B3 tự sửa mình, loại quản trị viên toàn quyền cuối, phiên bản cũ: không thay quyền.|B1: Kênh giao chưa sẵn sàng: không khẳng định đã gửi lời mời.',
     'Mẫu quyền không tạo tác nhân mới.|Quản trị viên không mặc nhiên có quyền vận hành nhà trọ của chủ trọ.', 'Quyền và hiệu lực truy cập được cập nhật, hoặc lời mời được ghi chờ giao.', 'Cấp và duy trì quyền quản trị phù hợp thẩm quyền ủy quyền.')

case('UC-ADM-06.2', 'Đối tượng rà soát quyền, kết luận, lý do, phiên bản và hạn rà soát tiếp theo.',
     'Quản trị viên mở danh sách quyền cần rà soát.|Hệ thống cung cấp quyền hiện hành và mốc kiểm tra theo thẩm quyền.|Quản trị viên ghi kết luận; hệ thống kiểm tra phiên bản và ngày rà soát tiếp theo.|Hệ thống lưu kết quả, người rà soát và nhật ký.',
     'B1: Chỉ xem lịch rà soát: không thay quyền hoặc mốc; kết thúc.',
     'B3: Phiên bản cũ hoặc thời hạn không hợp lệ: không ghi kết luận.',
     'Ghi rà soát không tự cấp thêm quyền ngoài chức năng quản lý quyền.', 'Có kết quả và lịch rà soát quyền mới.', 'Định kỳ xác nhận tính phù hợp của quyền quản trị.')

case('UC-ADM-08', 'Bộ lọc khu, phòng, chủ trọ, trạng thái và khoảng giá khi áp dụng.',
     'Quản trị viên mở danh mục khu và phòng.|Hệ thống kiểm tra quyền xem tài nguyên nền tảng và điều kiện lọc.|Hệ thống cung cấp danh sách hoặc chi tiết theo quyền, có thông tin tình trạng hoạt động.|Quản trị viên xem kết quả để hỗ trợ quản lý.',
     'B3: Không có kết quả phù hợp: trả danh sách trống; kết thúc.',
     'B2: Không đủ quyền hoặc bộ lọc không hợp lệ: không trả dữ liệu.',
     'Xem toàn nền tảng không đồng nghĩa được lập hợp đồng hoặc ghi thu thay chủ trọ.', 'Quản trị viên tra được khu, phòng theo thẩm quyền.')

case('UC-ADM-09', 'Chủ trọ, khu cần tạo hoặc sửa, tên, địa chỉ và thông tin được phép.',
     'Quản trị viên chọn chủ trọ cần hỗ trợ quản lý khu.|Hệ thống kiểm tra quyền thay mặt và chủ trọ mục tiêu.|Quản trị viên nhập dữ liệu; hệ thống áp điều kiện hợp lệ và hạn mức tương ứng.|Hệ thống tạo hoặc cập nhật khu, ghi nhật ký và trả kết quả.',
     'B3: Sửa khu đang có: kiểm tra đúng chủ trọ và giữ quan hệ sở hữu; kết thúc sau B4.',
     'B2: Không đủ quyền hoặc không có chủ trọ phù hợp: không thao tác.|B3: Dữ liệu hoặc hạn mức không cho phép: không tạo/sửa khu.',
     'Không chuyển khu sang chủ trọ khác chỉ bằng sửa hồ sơ.', 'Khu của chủ trọ được hỗ trợ cập nhật có dấu vết quản trị.')

case('UC-ADM-10', 'Từ khóa hoặc mã tài nguyên, loại thông tin cần tìm.',
     'Quản trị viên nhập nội dung tìm kiếm.|Hệ thống xác định các nhóm dữ liệu người dùng được quyền đọc.|Hệ thống tìm tài khoản, phòng, hợp đồng hoặc hóa đơn trong các nhóm được phép.|Hệ thống trả kết quả và đường đến thông tin chi tiết phù hợp.',
     'B3: Không có kết quả: trả danh sách trống; kết thúc.',
     'B2: Không có quyền với nhóm dữ liệu: không trả tài nguyên của nhóm đó.',
     'Tìm kiếm và định vị không mở vượt quyền của hồ sơ chi tiết.', 'Người quản trị tìm được tài nguyên được phép xem.')
