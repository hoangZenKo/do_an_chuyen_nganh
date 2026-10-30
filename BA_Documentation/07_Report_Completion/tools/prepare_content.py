from pathlib import Path
import json
import re
import sys

from business_language import business_text, business_title, PERMISSION_LABELS
from business_overrides import OVERRIDES


ROOT = Path('/Users/hoang/Rental_room_management')
OUTPUT = ROOT / 'BA_Documentation/07_Report_Completion'
CATALOG = json.loads((ROOT / 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json').read_text())
MANIFEST = json.loads((ROOT / 'BA_Documentation/06_Detailed_Use_Cases/data/spec-manifest.json').read_text())
ANALYSIS = json.loads((ROOT / 'BA_Documentation/06_Detailed_Use_Cases/data/behavioral-analysis.json').read_text())
NOTES = {record['id']: record for record in ANALYSIS['useCases']}
INPUT_CHECKS = json.loads((OUTPUT / 'data/input-checks.json').read_text())
ACTORS = {'A01': 'Khách vãng lai', 'A02': 'Chủ trọ', 'A03': 'Nhân viên vận hành', 'A04': 'Người tìm phòng hoặc người thuê', 'A05': 'Quản trị viên nền tảng'}
EXTERNAL = {'E01': 'Đơn vị gửi thư điện tử hoặc thông báo, khi kênh gửi đã được thiết lập', 'E02': 'Đơn vị cung cấp Zalo ZNS, khi sử dụng kênh này', 'E03': 'Đơn vị kiểm tra an toàn tệp đính kèm', 'E04': 'Dịch vụ trợ lý trả lời bằng trí tuệ nhân tạo, khi được bật', 'E05': 'Đơn vị lưu giữ kết quả báo cáo, tùy phương thức đã thiết lập'}
PASSWORD = 'Mật khẩu dài 12–128 ký tự, có ít nhất một chữ hoa, một chữ thường, một chữ số và một ký tự đặc biệt.'
G01 = {}


def account_case(identifier, description, inputs, steps, alternatives, exceptions, rules, post, pre='', failure=''):
    G01[identifier] = dict(id=identifier, groupId='G01', input=inputs, steps=steps, alternatives=alternatives, exceptions=exceptions, rules=rules, post=post, pre=pre, failure=failure, description=description)


for identifier, purpose, role_name in [('UC-SYS-01', 'quản lý nhà trọ', 'Chủ trọ'), ('UC-SYS-02', 'tìm phòng', 'Người tìm phòng hoặc người thuê')]:
    account_case(identifier,
        f'Khách vãng lai đăng ký tài khoản với mục đích {purpose}, sau đó bắt đầu sử dụng các chức năng phù hợp.',
        'Họ tên bắt buộc, tối đa 120 ký tự; địa chỉ thư điện tử hợp lệ; số điện thoại hợp lệ; mật khẩu và xác nhận mật khẩu; chấp thuận điều khoản. ' + PASSWORD,
        [f'Khách mở đăng ký, chọn mục đích {purpose}, nhập thông tin và chấp thuận điều khoản.',
         'Hệ thống kiểm tra các trường nhập, mật khẩu xác nhận và việc chấp thuận điều khoản; hướng dẫn sửa thông tin chưa hợp lệ.',
         'Hệ thống chuẩn hóa địa chỉ thư điện tử và kiểm tra địa chỉ này chưa được đăng ký.',
         f'Hệ thống tạo tài khoản với vai trò {role_name}; không cho người đăng ký tự cấp quyền khác.',
         'Hệ thống cấp phiên truy cập và đưa người dùng vào khu vực phù hợp với vai trò.'],
        ['B1: Khách quay về đăng nhập trước khi gửi đăng ký; không tạo tài khoản; kết thúc.'],
        ['B2: Thông tin thiếu, mật khẩu xác nhận không khớp hoặc chưa chấp thuận điều khoản: không gửi đăng ký; khách sửa tại B1.',
         'B3: Địa chỉ thư điện tử đã có: không tạo thêm tài khoản; thông báo để khách đăng nhập hoặc dùng địa chỉ khác; quay lại B1.',
         'B3: Quá 5 lần đăng ký trong 60 giây: từ chối lần gửi; khách chờ hết thời gian giới hạn.',
         'B5: Không hoàn tất cấp phiên hoặc ghi nhớ đăng nhập: có thể tài khoản đã được tạo; chưa xác nhận truy cập thành công; người dùng kiểm tra lại bằng đăng nhập.'],
        ['Địa chỉ thư điện tử được chuẩn hóa chữ thường và không trùng tài khoản đã có.', PASSWORD,
         'Đăng ký tìm phòng không tự tạo hồ sơ thuê hoặc hợp đồng.' if identifier.endswith('02') else 'Đăng ký chủ trọ không tự tạo khu trọ, phòng hay hồ sơ xác minh.',
         'Thông tin xác nhận mật khẩu và đồng ý điều khoản được kiểm tra trên biểu mẫu đăng ký.'],
        f'Tài khoản {role_name} được tạo; khi cấp phiên thành công, người dùng vào khu vực chức năng tương ứng.',
        'Người sử dụng chưa đăng nhập và truy cập được chức năng đăng ký.',
        'Lỗi dữ liệu hoặc trùng thư điện tử không tạo thêm tài khoản. Nếu lỗi xảy ra sau bước tạo tài khoản, tài khoản có thể đã tồn tại dù chưa đăng nhập thành công. Không mặc định toàn bộ quá trình đã được hủy.')

account_case('UC-SYS-03', 'Người đã có tài khoản xác minh danh tính để sử dụng chức năng được cấp.',
    'Địa chỉ thư điện tử và mật khẩu; quản trị viên cung cấp thêm mã xác thực hoặc mã khôi phục khi được yêu cầu.',
    ['Người dùng mở đăng nhập, nhập thư điện tử và mật khẩu.',
     'Hệ thống kiểm tra thông tin đăng nhập và tình trạng hoạt động của tài khoản; đối với nhân viên, kiểm tra thêm tình trạng chủ trọ và hồ sơ nhân sự.',
     'Nếu tài khoản quản trị yêu cầu xác thực nhiều yếu tố, người dùng cung cấp mã hợp lệ và hệ thống kiểm tra.',
     'Hệ thống cấp phiên truy cập, ghi nhận thông tin đăng nhập và hiển thị khu vực chức năng theo vai trò.'],
    ['B3: Người quản trị dùng mã khôi phục còn hiệu lực thay mã từ ứng dụng xác thực; mã khôi phục đó chỉ dùng một lần; tiếp tục B4.'],
    ['B2: Thư điện tử hoặc mật khẩu không đúng: không cấp phiên; người dùng kiểm tra và nhập lại tại B1.',
     'B2: Tài khoản hoặc điều kiện hoạt động liên quan không còn hợp lệ: từ chối truy cập; kết thúc lần đăng nhập.',
     'B3: Thiếu hoặc sai mã xác thực, mã khôi phục đã dùng: không cấp phiên; quay lại bước cung cấp mã.'],
    ['Đăng nhập không làm thay đổi vai trò hoặc tự mở rộng quyền sử dụng.', 'Chỉ quyền được cấp và dữ liệu trong phạm vi cho phép mới được sử dụng sau đăng nhập.'],
    'Người dùng có phiên truy cập hợp lệ và vào khu vực phù hợp với vai trò.', 'Tài khoản đã được tạo và còn đủ điều kiện hoạt động.')

account_case('UC-SYS-05.1', 'Người dùng kết thúc phiên đang sử dụng mà không yêu cầu thu hồi các thiết bị khác.',
    'Phiên đang được sử dụng; người dùng không phải chọn tài khoản khác để đăng xuất.',
    ['Người dùng chọn đăng xuất.', 'Ứng dụng yêu cầu thu hồi phiên đang sử dụng nếu còn thông tin phiên.', 'Hệ thống thu hồi phiên tương ứng và thông tin duy trì phiên của lần đăng nhập đó.', 'Ứng dụng xóa thông tin truy cập đang giữ; người dùng không tiếp tục ở khu vực yêu cầu đăng nhập.'],
    ['B2: Không còn thông tin phiên hoặc phiên đã không tồn tại: vẫn kết thúc đăng nhập trên ứng dụng; không tạo phiên mới; kết thúc.'],
    ['B3: Không liên lạc được với hệ thống: ứng dụng vẫn thực hiện kết thúc đăng nhập tại thiết bị; chưa có căn cứ xác nhận phiên phía hệ thống đã thu hồi; kết thúc.'],
    ['Đăng xuất này không thu hồi mọi phiên của tài khoản.', 'Đăng xuất tại thiết bị và thu hồi hiệu lực truy cập trên hệ thống là hai kết quả cần phân biệt.'],
    'Ứng dụng ở trạng thái chưa đăng nhập; phiên được thu hồi khi yêu cầu đến hệ thống và được xử lý thành công.', '',
    'Không khẳng định đã thu hồi phiên trên hệ thống chỉ vì thiết bị đã thoát. Trường hợp lỗi lưu trữ trên thiết bị cũng chưa bảo đảm việc xóa thông tin hoàn tất.')

account_case('UC-SYS-05.2', 'Chủ tài khoản kiểm tra các lần đăng nhập và thu hồi các phiên không muốn tiếp tục sử dụng.',
    'Phiên cần thu hồi hoặc lựa chọn thu hồi các phiên khác; chỉ áp dụng cho tài khoản của chính người dùng.',
    ['Người dùng mở danh sách phiên truy cập của mình.', 'Hệ thống cung cấp tối đa 100 phiên còn hiệu lực, gồm thông tin thiết bị tham khảo, thời điểm và dấu phiên đang dùng.', 'Người dùng chọn một phiên khác và xác nhận thu hồi.', 'Hệ thống thu hồi phiên đã chọn và ghi nhật ký; danh sách được cập nhật. Thiết bị bị thu hồi không tiếp tục truy cập ở lần kiểm tra kế tiếp.'],
    ['B3: Thu hồi tất cả phiên khác: hệ thống giữ lại phiên đang dùng và thu hồi các phiên còn lại, kể cả phiên không nằm trong 100 mục hiển thị; kết thúc.'],
    ['B3: Phiên không thuộc tài khoản hoặc đã bị thu hồi: không thay đổi phiên của người khác; thông báo kết quả từ chối; kết thúc.', 'B4: Mất phản hồi sau xác nhận: có thể việc thu hồi đã hoàn tất; người dùng kiểm tra lại danh sách trước thao tác tiếp.'],
    ['Không dùng chức năng này để thu hồi phiên của tài khoản khác.', 'Thông tin thiết bị và địa chỉ mạng được che một phần, chỉ phục vụ tham khảo.', 'Giao diện quản lý phiên chưa được xác nhận đồng đều cho tất cả vai trò.'],
    'Phiên được chọn mất quyền tiếp tục truy cập; phiên đang sử dụng được giữ khi chọn thu hồi các phiên khác.')

account_case('UC-SYS-06', 'Người dùng quên mật khẩu yêu cầu hướng dẫn và đặt mật khẩu mới bằng liên kết dùng một lần.',
    'Địa chỉ thư điện tử đã đăng ký; liên kết đặt lại mật khẩu; mật khẩu mới và xác nhận. ' + PASSWORD,
    ['Khách chọn quên mật khẩu, nhập thư điện tử và yêu cầu gửi hướng dẫn.', 'Hệ thống kiểm tra tài khoản và điều kiện gửi; nếu đủ điều kiện, tạo yêu cầu giao liên kết có thời hạn.', 'Khách mở liên kết, nhập và xác nhận mật khẩu mới.', 'Hệ thống kiểm tra liên kết còn hiệu lực, chưa dùng và tài khoản đang hoạt động; cập nhật mật khẩu.', 'Hệ thống làm mất hiệu lực các phiên cũ và các liên kết truy cập chưa dùng của tài khoản; yêu cầu người dùng đăng nhập bằng mật khẩu mới.'],
    ['B2: Thư điện tử không tồn tại, tài khoản ngừng hoạt động hoặc kênh gửi chưa sẵn sàng: vẫn trả thông báo tiếp nhận chung, không tiết lộ tài khoản có tồn tại; không khẳng định liên kết đã gửi; kết thúc.'],
    ['B4: Liên kết sai, hết hạn hoặc đã dùng: không đổi mật khẩu; người dùng cần yêu cầu liên kết mới tại B1.', 'B3: Mật khẩu không đạt quy định hoặc xác nhận không khớp: không hoàn tất đặt lại; sửa thông tin tại B3.'],
    ['Liên kết có hiệu lực 30 phút và chỉ dùng một lần.', PASSWORD, 'Thông báo tiếp nhận yêu cầu không chứng minh thư đã được chuyển đến người nhận.'],
    'Mật khẩu được thay đổi, phiên cũ mất hiệu lực; người dùng đăng nhập lại.', 'Không cần đăng nhập để yêu cầu hướng dẫn; đặt lại thành công cần liên kết hợp lệ và tài khoản còn hoạt động.')

account_case('UC-SYS-07', 'Người đang đăng nhập thay mật khẩu bằng cách xác minh mật khẩu hiện tại.',
    'Mật khẩu hiện tại, mật khẩu mới và xác nhận. ' + PASSWORD,
    ['Người dùng mở đổi mật khẩu và nhập thông tin.', 'Hệ thống kiểm tra phiên truy cập, mật khẩu hiện tại và quy định mật khẩu mới.', 'Hệ thống kiểm tra thông tin chưa bị thay đổi đồng thời rồi lưu mật khẩu mới.', 'Hệ thống vô hiệu hóa tất cả phiên cũ, bao gồm phiên hiện tại; ứng dụng yêu cầu đăng nhập lại.'],
    [],
    ['B2: Mật khẩu hiện tại sai hoặc mật khẩu mới không hợp lệ: không đổi mật khẩu; người dùng sửa tại B1.', 'B3: Mật khẩu đã bị thay đổi trong lúc xử lý: không ghi đè lần thay đổi khác; kết thúc lần gửi.'],
    [PASSWORD, 'Không giữ phiên hiện tại sau khi đổi mật khẩu.', 'Chưa có căn cứ về kiểm tra lịch sử mật khẩu, cấm dùng lại mật khẩu cũ hoặc thu hồi liên kết truy cập chưa dùng trong chức năng này.'],
    'Mật khẩu được thay và các phiên cũ không còn dùng được; người dùng đăng nhập lại.', '',
    'Sai mật khẩu hoặc thiếu quyền không làm thay đổi mật khẩu. Nếu đã thay đổi thành công nhưng ứng dụng không nhận được phản hồi, cần kiểm tra lại; không mặc định mật khẩu cũ còn hiệu lực.')

for identifier, target, target_detail in [('UC-SYS-08', 'người thuê', 'hồ sơ người thuê đã được chủ trọ mời'), ('UC-SYS-09', 'nhân viên', 'quyền nghiệp vụ và các khu được chủ trọ giao')]:
    account_case(identifier,
        f'Người nhận lời mời kích hoạt tài khoản {target} theo thông tin chủ trọ đã xác lập.',
        'Mã lời mời từ 16–256 ký tự và mật khẩu mới. ' + PASSWORD,
        [f'Người nhận mở liên kết kích hoạt tài khoản {target}, cung cấp mã mời và mật khẩu.',
         'Hệ thống kiểm tra mã mời còn hiệu lực, chưa được chấp nhận và các thông tin liên quan còn hợp lệ.',
         f'Hệ thống tạo tài khoản {target}, gắn đúng {target_detail} và ghi lời mời đã được chấp nhận.',
         f'Hệ thống cấp phiên truy cập và mở khu vực sử dụng dành cho {target}.'],
        [],
        ['B2: Mã không tồn tại, hết hạn hoặc đã được dùng: không tạo thêm tài khoản; cần liên hệ chủ trọ để kiểm tra lời mời.', 'B3: Thư điện tử đã có tài khoản hoặc điều kiện liên kết đã thay đổi: từ chối tạo tài khoản; không chuyển vai trò tài khoản đang có.'],
        ['Lời mời loại này có hiệu lực mặc định 7 ngày; không đồng nhất với liên kết đặt mật khẩu 30 phút.', 'Vai trò và phạm vi nhận từ lời mời đã lưu, không do người nhận tự chọn.', PASSWORD],
        f'Tài khoản {target} được tạo và liên kết đúng phạm vi lời mời.',
        'Có lời mời đúng loại, chưa dùng, chưa hết hạn; người nhận chưa có tài khoản trùng địa chỉ thư điện tử.')

account_case('UC-SYS-10', 'Người nhận lời mời thiết lập mật khẩu cho tài khoản đã được tạo trước đó.',
    'Liên kết hoặc mã kích hoạt từ 32–128 ký tự; mật khẩu mới và xác nhận. ' + PASSWORD,
    ['Người nhận mở liên kết thiết lập mật khẩu.', 'Người nhận nhập mật khẩu mới và xác nhận.', 'Hệ thống kiểm tra liên kết còn hiệu lực, chưa dùng và tài khoản đang hoạt động.', 'Hệ thống cập nhật mật khẩu cho tài khoản đã có, làm mất hiệu lực các liên kết chưa dùng và các phiên cũ.', 'Hệ thống thông báo hoàn tất; người nhận đăng nhập lại bằng mật khẩu vừa thiết lập.'],
    ['B1: Người nhận có mã và nhập trực tiếp vào biểu mẫu; hệ thống tiếp tục kiểm tra như liên kết tại B3; chưa đổi mật khẩu trước xác nhận.'],
    ['B3: Liên kết sai, hết hạn, đã dùng hoặc tài khoản ngừng hoạt động: không cập nhật mật khẩu; người nhận cần được cấp lại liên kết hợp lệ.'],
    ['Liên kết có hiệu lực 30 phút và chỉ dùng một lần.', 'Không tạo thêm tài khoản hoặc cho chọn lại vai trò trong bước đặt mật khẩu.', PASSWORD],
    'Tài khoản đã có được đặt mật khẩu mới; người nhận đăng nhập lại.', 'Tài khoản đã được tạo và người nhận có liên kết còn hiệu lực.')

account_case('UC-ADM-07.1', 'Quản trị viên thiết lập bước xác minh bổ sung để bảo vệ truy cập quản trị.',
    'Tài khoản quản trị đang đăng nhập; mã xác thực 6 chữ số từ ứng dụng tạo mã; thao tác xác nhận đã lưu mã khôi phục.',
    ['Quản trị viên mở bảo mật tài khoản và xem tình trạng xác thực nhiều yếu tố.', 'Quản trị viên chọn bắt đầu thiết lập; hệ thống cung cấp thông tin thêm vào ứng dụng xác thực và mã quét.', 'Quản trị viên thêm vào ứng dụng xác thực, nhập mã 6 chữ số và xác nhận.', 'Hệ thống kiểm tra mã hợp lệ, bật xác thực nhiều yếu tố, vô hiệu hóa các phiên cũ và cung cấp 8 mã khôi phục.', 'Quản trị viên lưu mã khôi phục rồi chọn đăng nhập lại; lần đăng nhập sau thực hiện bước xác thực bổ sung.'],
    [],
    ['B3: Mã sai, đã được dùng hoặc vượt thời gian chấp nhận: không bật xác thực; thông tin thiết lập trước đó vẫn có thể còn; nhập mã mới tại B3.', 'B4: Mất phản hồi hoặc chưa lưu được mã khôi phục: không kết luận việc bật bảo mật đã bị hủy; kiểm tra tình trạng tài khoản trước khi thao tác lại.'],
    ['Chỉ quản trị viên có hồ sơ quản trị đang hoạt động được thiết lập.', 'Mã xác thực gồm 6 chữ số, thay đổi mỗi 30 giây; chấp nhận lệch một khoảng 30 giây và không dùng lại mã đã xác nhận.', 'Có 8 mã khôi phục, mỗi mã dùng một lần; mã khôi phục không dùng để xác nhận bật bảo mật.', 'Chưa có chức năng tắt hoặc cấp lại mã khôi phục trong phạm vi thiết lập này.'],
    'Bảo mật nhiều yếu tố được bật; phiên cũ mất hiệu lực và quản trị viên có bộ mã khôi phục.',
    'Đã đăng nhập bằng tài khoản quản trị đang hoạt động; chưa bật xác thực nhiều yếu tố.',
    'Xác nhận sai không bật bảo mật nhưng không xóa thông tin của bước bắt đầu thiết lập. Khi đã bật thành công, việc người dùng chưa lưu mã khôi phục không làm hoàn tác kết quả bật.')

NOTES.update(G01)
for identifier, override in OVERRIDES.items():
    NOTES[identifier] = {**NOTES[identifier], **override}
NOTES['UC-BIL-20']['rules'].extend([
    'Xuất báo cáo tháng hiện hỗ trợ sao chép nội dung bảng dữ liệu; không mô tả là đã có tệp tải về trong mọi trường hợp.',
    'Chưa xác nhận mọi chỉ số phân tích đều được trình bày trên màn hình; cần phân biệt kết quả tổng hợp đã có với phần thông tin người dùng thực sự xem được.',
])


def parse_table(filename):
    result = {}
    for line in filename.read_text().splitlines():
        if not line.startswith('|'):
            continue
        columns = re.split(r'(?<!\\)\|', line)[1:-1]
        if len(columns) == 2:
            result[columns[0].strip()] = columns[1].strip()
    return result


def permission_text(record):
    if record['id'] == 'UC-SYS-05.1':
        return 'Người dùng rời phiên của mình, không phải xác minh lại mật khẩu hoặc hoàn thành xác thực bổ sung để đăng xuất. Việc thu hồi được xác định từ thông tin duy trì phiên mà ứng dụng đang giữ; không chọn tài khoản khác để đăng xuất. Đăng xuất tại thiết bị vẫn được thực hiện khi không liên lạc được với hệ thống.'
    pieces = []
    matrix = record['matrix']
    for actor_id in record['primaryActorIds']:
        description = matrix_condition(matrix.get(actor_id, ''))
        if record['id'] in ['UC-SYS-01','UC-SYS-02'] and actor_id == 'A01':
            description = 'Được đăng ký theo mục đích sử dụng; không tự lựa chọn quyền ngoài vai trò tương ứng.'
        if record['id'] in ['UC-SYS-08','UC-SYS-09','UC-SYS-10'] and actor_id == 'A01':
            description = 'Chỉ kích hoạt tài khoản đã được mời bằng thông tin mời hợp lệ; không tự chọn vai trò hoặc cấp quyền.'
        if record['id'] == 'UC-ADM-07.1' and actor_id == 'A05':
            description = 'Quản trị viên đang hoạt động thực hiện thiết lập cho tài khoản của mình.'
        pieces.append(ACTORS[actor_id] + ': ' + description)
    variants = [(actor_id, value) for actor_id, value in matrix.items() if value.startswith('V')]
    for actor_id, value in variants:
        detail = matrix_condition(value)
        if record['id'] == 'UC-TEN-05' and actor_id == 'A01':
            detail = 'Chỉ mở liên kết thanh toán thử nghiệm còn hiệu lực; không dùng thẻ để chuyển tiền thật.'
        pieces.append(ACTORS[actor_id] + ' chỉ có phạm vi tham gia giới hạn: ' + detail)
    if record['businessGroup'] != 'G01' and ('A03' in record['primaryActorIds'] or any(actor == 'A03' for actor, _ in variants)):
        pieces.append('Nhân viên chỉ thao tác ở khu được giao và với quyền đã cấp; điều kiện của từng nghiệp vụ vẫn phải được đáp ứng.')
    if 'A04' in record['primaryActorIds'] and record['businessGroup'] not in ['G01', 'G02', 'G03', 'G13', 'G16']:
        pieces.append('Người thuê chỉ xem hoặc thay đổi thông tin gắn với hồ sơ của mình; tài khoản tìm phòng chưa có hồ sơ thuê không tự được truy cập dữ liệu thuê.')
    if 'A05' in record['primaryActorIds']:
        pieces.append('Quản trị viên phải có quyền phù hợp, hoàn thành các bước xác minh được yêu cầu; quyền quản trị không thay thế quyền vận hành của chủ trọ.')
    return '\n'.join(pieces)


def matrix_condition(value):
    if value == '—' or not value:
        return 'Không xác định là tác nhân thực hiện mục tiêu này.'
    if value.startswith('B'):
        return 'Không được phép thực hiện.'
    detail = value.partition(' — ')[2]
    for key, label in sorted(PERMISSION_LABELS.items(), key=lambda item: -len(item[0])):
        detail = detail.replace(key, label)
    detail = business_text(detail)
    replacements = {
        'điều kiện quy tắc nghiệp vụ': 'đáp ứng điều kiện nghiệp vụ',
        'dữ liệu thuộc mình': 'dữ liệu thuộc phạm vi quản lý của mình',
        'theo hành vi + phạm vi được phép': 'theo thao tác và khu được giao',
        'kiểm vai trò trong nhóm chức năng': 'đúng vai trò được phép',
        'kiểm tra phạm vi được giao chặn': 'không được cấp cho nhân viên',
        'không suy quyền menu': 'không đồng nghĩa được dùng chức năng quản lý',
        'theo mã truy cập': 'có mã truy cập hợp lệ',
    }
    for before, after in replacements.items():
        detail = detail.replace(before, after)
    detail = detail.replace(' + ', ' và ')
    return detail.rstrip('.;') + '.'


def strip_branch_prefix(value, prefix):
    return re.sub(r'^' + prefix + r'\d+\s*[—.-]\s*', '', value)


FIELDS = ['Mã Use Case', 'Tên Use Case', 'Mô tả nghiệp vụ', 'Phạm vi và cấp độ', 'Tác nhân chính', 'Tác nhân phối hợp', 'Mục tiêu nghiệp vụ', 'Sự kiện kích hoạt', 'Tiền điều kiện', 'Dữ liệu đầu vào và kiểm tra hợp lệ', 'Luồng thành công chính', 'Luồng thay thế', 'Luồng ngoại lệ', 'Hậu điều kiện thành công', 'Bảo đảm tối thiểu khi thất bại', 'Quy tắc nghiệp vụ', 'Phân quyền và bảo mật', 'Kết quả đầu ra', 'Quan hệ với Use Case khác', 'Căn cứ và mức độ hoàn thiện']
STATUS = {'Xác minh tĩnh': 'Đã đối chiếu hiện trạng; chưa thay thế nghiệm thu sử dụng thực tế.', 'Một phần': 'Đáp ứng một phần; giới hạn được ghi nhận dưới đây.', 'Đã triển khai — DEMO': 'Chỉ dành cho thử nghiệm; không thanh toán thẻ bằng tiền thật.', 'Đã triển khai — MÔ PHỎNG': 'Chỉ mô phỏng; chưa xác nhận trao đổi với người nhận qua dịch vụ thực.'}
GOALS = {
    'UC-ADM-07.1': 'Tăng mức bảo vệ tài khoản quản trị bằng bước xác minh bổ sung và mã khôi phục.',
    'UC-SYS-03': 'Truy cập hệ thống bằng đúng tài khoản và sử dụng các chức năng được phép.',
    'UC-SYS-05.1': 'Kết thúc lần đăng nhập đang sử dụng để bảo vệ tài khoản.',
    'UC-SYS-06': 'Đặt lại mật khẩu qua liên kết riêng để lấy lại quyền truy cập tài khoản.',
    'UC-OPT-04.3': 'Loại bỏ khu trọ không còn cần quản lý khi không còn ràng buộc nghiệp vụ ngăn xóa.',
    'UC-OPT-07.3': 'Loại bỏ phòng không còn cần quản lý sau khi kiểm tra đầy đủ lịch sử và thông tin liên quan.',
    'UC-STF-01': 'Mời nhân viên tham gia vận hành và giao quyền, khu trọ phù hợp công việc.',
    'UC-STF-02': 'Điều chỉnh quyền, khu được giao và tình trạng làm việc của nhân viên.',
    'UC-STF-03': 'Kiểm tra nhân viên có được thực hiện một công việc tại khu đã chọn hay không, không thay đổi quyền thật.',
    'UC-ADM-03.2': 'Cập nhật hồ sơ chủ trọ trong phạm vi quản trị mà không thay đổi quyền quản trị viên.',
    'UC-ADM-04.3': 'Chấm dứt các lần đăng nhập của tài khoản khác theo thẩm quyền, không xóa dữ liệu nghiệp vụ.',
    'UC-ADM-08': 'Tra cứu khu, phòng và tình trạng tin đăng trên toàn nền tảng theo quyền được giao.',
    'UC-ADM-10': 'Tìm đúng hồ sơ nghiệp vụ thuộc các loại thông tin được phép tra cứu.',
    'UC-ADM-13.3': 'Đánh giá độc lập chất lượng quyết định kiểm duyệt để theo dõi và cải thiện công tác kiểm duyệt.',
    'UC-ADM-19': 'Trình và xem xét hồ sơ khu trọ dựa trên nội dung đã được ghi nhận tại thời điểm trình.',
    'UC-ADM-22': 'Kết thúc quyền sử dụng gói theo thẩm quyền mà không xóa dữ liệu khu, phòng.',
    'UC-ADM-24': 'Tra cứu giao dịch và nhận diện chênh lệch tài chính trong phạm vi quản trị.',
    'UC-ADM-26': 'Kiểm tra quyền dự kiến của một bộ quyền quản trị mà không cấp hoặc thay đổi quyền thật.',
    'UC-DIS-15': 'Đề nghị xem xét lại quyết định kiểm duyệt liên quan đến nội dung của mình.',
}
GROUPS = {record['id']: record for record in CATALOG['groups']}
SPECS = {record['id']: record for record in MANIFEST['useCases']}


def numbered(items, prefix):
    if not items:
        return 'Không áp dụng.'
    return '\n'.join(f'{prefix}{index:02d} — {business_text(item)}' if prefix == 'BR-' else f'{prefix}{index} — {business_text(item)}' for index, item in enumerate(items, 1))


def default_preconditions(record):
    if record['id'] == 'UC-SYS-05.1':
        return 'Ứng dụng đang có trạng thái hoặc thông tin đăng nhập cần kết thúc; không bắt buộc quyền truy cập hiện tại còn hiệu lực hoặc tài khoản còn hoạt động để dọn phiên tại thiết bị. Thu hồi trên hệ thống cần thông tin duy trì phiên tương ứng.'
    if record['id'] in ['UC-DIS-16', 'UC-DIS-17']:
        return 'Có thông tin tin phòng cần so sánh hoặc ước tính; không cần đăng nhập. Kết quả chỉ phục vụ phiên sử dụng hiện tại.'
    if 'A01' in record['primaryActorIds']:
        return 'Truy cập được chức năng công khai. Các điều kiện về lời mời, liên kết hoặc đối tượng cụ thể được kiểm tra trong luồng nghiệp vụ.'
    return 'Tác nhân đã đăng nhập bằng tài khoản còn hoạt động và có quyền phù hợp. Thông tin được chọn phải thuộc phạm vi tác nhân được phép sử dụng; điều kiện trạng thái cụ thể được kiểm tra trong luồng.'


def build_record(record):
    note = NOTES[record['id']]
    manifest_record = SPECS[record['id']]
    specification = parse_table(ROOT / 'BA_Documentation/06_Detailed_Use_Cases' / manifest_record['file'])
    group = GROUPS[record['businessGroup']]
    steps = note['steps']
    rules = list(note['rules'])
    exceptions = list(note['exceptions'])
    if record['businessGroup'] != 'G01' and 'A01' not in record['primaryActorIds'] and record['id'] not in ['UC-DIS-16', 'UC-DIS-17']:
        exceptions.append('B1: Đăng nhập không còn hiệu lực hoặc không đủ quyền: không thực hiện yêu cầu; người dùng đăng nhập lại hoặc liên hệ người quản lý quyền.')
    relation_overrides = {
        'UC-DIS-06.2': 'UC-DIS-05 quản lý tin; UC-ADM-11 xét duyệt việc công khai. Ẩn tin của mình là mục tiêu riêng.',
        'UC-DIS-09': 'UC-DIS-10 là mục tiêu tiếp nhận lịch của chủ trọ. UC-TNT-05 chỉ lập hợp đồng từ lịch xem khi đáp ứng điều kiện đã xem phòng.',
        'UC-TNT-05': 'UC-TNT-06.1 cập nhật điều khoản; UC-TNT-06.2 gia hạn. UC-DIS-10 chỉ kết thúc lịch xem, không tự lập hợp đồng.',
        'UC-OPT-07.1': 'UC-OPT-07.2 ngừng hoặc khôi phục hoạt động của phòng; không thay thế mục tiêu đổi tình trạng sử dụng.',
        'UC-BIL-02': 'UC-BIL-03 lập hóa đơn cho nhiều hợp đồng. Xem trước là một phần của mục tiêu lập hóa đơn.',
    }
    relations = relation_overrides.get(record['id']) or business_text(note.get('relations', ''))
    if not relations or 'include' in relations or 'extend' in relations:
        ids = list(dict.fromkeys(re.findall(r'UC-[A-Z]+-\d+(?:\.\d+)*', relations)))
        relations = ('Liên quan ' + ', '.join(ids) + '; các mục tiêu được mô tả độc lập, không mặc định thực hiện thay nhau.') if ids else 'Không xác lập quan hệ bao hàm hoặc mở rộng bắt buộc trong bộ danh mục đã chuẩn hóa.'
    evidence = STATUS[record['status']]
    gaps = {
        'UC-SYS-06': 'Đã có quy trình khôi phục; chưa xác nhận người nhận nhận được thư khôi phục thực tế.',
        'UC-BIL-18.2': 'Thông báo trong ứng dụng đã có; chưa xác nhận việc giao nhận qua thư điện tử và Zalo thực tế.',
        'UC-SUP-06': 'Đã có nội dung tham chiếu và phương án trả lời thay thế; chưa kiểm tra việc trả lời bằng dịch vụ trí tuệ nhân tạo thực tế.',
        'UC-SUP-05.2': 'Đã có theo dõi và gửi lại; chưa xác nhận đơn vị gửi bên ngoài giao thông báo thành công.',
        'UC-ADM-03.1': 'Chưa xác nhận người nhận nhận được lời mời thực tế; cách đặt mật khẩu trực tiếp chỉ dành cho môi trường phát triển, không mô tả là quy trình vận hành chính thức.',
        'UC-ADM-05.2': 'Yêu cầu khôi phục được ghi nhận; chưa xác nhận thư khôi phục đã đến người nhận.',
        'UC-ADM-06.1': 'Đã có cấp quyền, mời và gửi lại; chưa xác nhận người được mời nhận được thông tin kích hoạt thực tế.',
        'UC-SUP-01': 'Đã có gửi và theo dõi yêu cầu; chưa xác nhận vận hành kiểm tra an toàn tệp. Không tiếp nhận tệp khi không kiểm tra được. Nhân viên vận hành không có quyền dùng chức năng này.',
        'UC-SUP-01.1': 'Đã có xử lý hỗ trợ; chưa xác nhận việc kiểm tra an toàn và lưu giữ tệp thực tế. Nhân viên vận hành không có quyền xử lý hồ sơ hỗ trợ.',
    }
    if record['status'] == 'Một phần':
        evidence += ' ' + gaps[record['id']]
    evidence += f' Đối chiếu theo đặc tả {record["id"]} trong bộ tài liệu phân tích hiện trạng, cập nhật ngày 29/10/2026. Chi tiết bằng chứng được lưu riêng, không thay thế cho kết quả thực hiện nghiệp vụ.'
    minimum = note.get('failure') or 'Các trường hợp bị từ chối trước khi ghi nhận không làm thay đổi đối tượng nghiệp vụ đích. Nếu mất phản hồi sau khi xác nhận, chưa thể kết luận thao tác chưa được ghi nhận; cần kiểm tra lại kết quả trước khi gửi thêm yêu cầu.'
    goal = GOALS.get(record['id']) or note.get('goal') or record['goal']
    values = [record['id'], business_title(record), business_text(note.get('description') or goal),
              'Hệ thống quản lý nhà trọ; nhóm ' + group['name'] + '; mục tiêu của người sử dụng.',
              '; '.join(ACTORS[actor] for actor in record['primaryActorIds']),
              '; '.join(EXTERNAL[actor] for actor in record['supportingActorIds']) or 'Không áp dụng.',
              business_text(goal), business_text(steps[0]),
              business_text(note.get('pre') or default_preconditions(record)),
              business_text(note['input']) + INPUT_CHECKS.get(record['id'], ''), numbered(steps, 'B'), numbered(note['alternatives'], 'A'),
              numbered(exceptions, 'E'), business_text(note['post']), business_text(minimum),
              numbered(rules, 'BR-'), permission_text(record), business_text(note['post']), relations, evidence]
    return {'id': record['id'], 'groupId': record['businessGroup'], 'title': business_title(record), 'catalogTitle': record['title'], 'primaryActorIds': record['primaryActorIds'], 'supportingActorIds': record['supportingActorIds'], 'status': record['status'], 'fields': dict(zip(FIELDS, values)), 'matrix': {actor: matrix_condition(value) for actor, value in record['matrix'].items()}, 'evidenceFile': manifest_record['file']}


def main():
    cases = [build_record(record) for record in CATALOG['useCases']]
    output = {'sourceDate': '2026-10-29', 'groups': CATALOG['groups'], 'actors': ACTORS, 'externalActors': EXTERNAL, 'fields': FIELDS, 'useCases': cases}
    destination = OUTPUT / 'data/business-report-content.json'
    destination.write_text(json.dumps(output, ensure_ascii=False, indent=2) + '\n')
    readable = '\n\n'.join(record['id'] + ' ' + record['title'] + '\n' + '\n'.join(field + ': ' + value for field, value in record['fields'].items()) for record in cases)
    Path('/tmp/ba-report-20261029/business-review.txt').write_text(readable)
    print(f'{len(cases)} UC; {len(CATALOG["groups"])} nhóm; {len(FIELDS)} trường mỗi UC')


if __name__ == '__main__':
    main()
