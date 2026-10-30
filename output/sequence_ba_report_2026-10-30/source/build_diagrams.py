import hashlib
import json
import re
import subprocess
import textwrap
from contextlib import contextmanager
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from lxml import etree
from PIL import Image, ImageDraw, ImageFont


ROOT = Path('/Users/hoang/Rental_room_management')
BASE = ROOT / 'output/sequence_ba_report_2026-10-30'
SOURCE = BASE / 'source'
IMAGES = BASE / 'PNG'
JAVA = '/opt/homebrew/opt/openjdk@17/bin/java'
JAR = '/tmp/ba-sequence-v4-tools/plantuml.jar'
REPORT = next(Path('/Users/hoang/Desktop').glob('*/Bao_cao_Quan_ly_Nha_tro_V4_2026-10-29_BA.docx'))

STYLE = '''@startuml
skinparam backgroundColor white
skinparam shadowing false
skinparam dpi 240
skinparam defaultFontName "Times New Roman"
skinparam defaultFontSize 17
skinparam defaultFontColor black
skinparam titleFontSize 21
skinparam titleFontColor black
skinparam roundcorner 0
skinparam maxMessageSize 270
skinparam ParticipantPadding 30
skinparam sequence {
  ArrowColor #800000
  ArrowThickness 1.2
  LifeLineBorderColor #999999
  LifeLineBackgroundColor #FFFFB9
  ParticipantBackgroundColor #FFFFB9
  ParticipantBorderColor #800000
  ParticipantFontColor black
  ActorBackgroundColor #FFFFB9
  ActorBorderColor #800000
  ActorFontColor black
  BoundaryBackgroundColor #FFFFB9
  BoundaryBorderColor #800000
  ControlBackgroundColor #FFFFB9
  ControlBorderColor #800000
  EntityBackgroundColor #FFFFB9
  EntityBorderColor #800000
  DatabaseBackgroundColor #FFFFB9
  DatabaseBorderColor #800000
  GroupBackgroundColor #FFFFB9
  GroupBodyBackgroundColor white
  GroupBorderColor #888888
  GroupFontColor black
  GroupHeaderFontColor black
  GroupFontSize 15
  GroupHeaderFontSize 16
  MessageAlign center
}
hide footbox
<style>
sequenceDiagram {
 actor { BackgroundColor #FFFFB9
 LineColor #800000 }
 boundary { BackgroundColor #FFFFB9
 LineColor #800000 }
 control { BackgroundColor #FFFFB9
 LineColor #800000 }
 database { BackgroundColor #FFFFB9
 LineColor #800000 }
 activationBox { BackgroundColor #FFFFB9
 LineColor #800000 }
}
</style>
autonumber "<b>0.</b>"
'''


class Diagram:
    def __init__(self, number, title, actor, screen, control, data_scope, second=None):
        self.key = f'SD-{number:02}'
        self.title = title
        self.data_scope = data_scope.replace(r'\n', ' ')
        self.lines = [STYLE, f'title {self.key}. {title}', f'actor "{actor}" as A']
        if second:
            self.lines.append(f'actor "{second}" as B')
        for kind, label, alias in [('boundary', screen, 'U'), ('control', control, 'C'), ('database', 'Cơ sở dữ liệu', 'D')]:
            label = r'\n'.join(f'<u>{line}</u>' for line in label.split(r'\n'))
            self.lines.append(f'{kind} "{label}" as {alias} #FFFFB9')
        self.evidence = []
        self.notes = []

    def raw(self, *lines):
        self.lines.extend(lines)

    def request(self, actor, interaction, business=None):
        self.raw(f'{actor} -> U: {interaction}', 'activate U',
                 f'U -> C: {business or interaction}', 'activate C')

    def finish(self):
        self.raw('deactivate C', 'deactivate U')

    def answer(self, actor, result, display=None):
        outcome = result.split(';')[0]
        if outcome.startswith('Hiển thị '):
            outcome = 'Kết quả: ' + outcome[len('Hiển thị '):]
        self.raw(f'C --> U: {outcome}', f'U --> {actor}: {display or result}')

    def data(self, operation, result):
        self.raw(f'C -> D ++: {operation}', f'D --> C --: {result}')

    def process(self, operation):
        self.raw(f'C -> C: {operation}')

    def checked_change(self, actor, query, records, check, operation, saved, success, failure):
        self.data(query, records)
        self.process(check)
        with self.frame('alt', 'Đủ quyền và dữ liệu đáp ứng điều kiện xử lý'):
            self.data(operation, saved)
            self.answer(actor, success)
            self.otherwise('Không đáp ứng điều kiện xử lý')
            self.answer(actor, failure)

    @contextmanager
    def frame(self, kind, guard):
        self.raw(f'{kind} ' + r'\n'.join(textwrap.wrap(guard, 94)))
        yield
        self.raw('end')

    def otherwise(self, guard):
        self.raw('else ' + r'\n'.join(textwrap.wrap(guard, 94)))

    def trace(self, path, *symbols):
        self.evidence.append({'path': path, 'symbols': list(symbols)})

    def write(self):
        body = '\n'.join(self.lines + ['@enduml', ''])
        assert not re.search(r'\b(?:Service|Controller|Repository|PostgreSQL|Flutter|HTTP|SQL|JWT|TX|requestKey|version)\b', body)
        (SOURCE / f'{self.key}.puml').write_text(body, encoding='utf-8')
        return body


diagrams = []


def new(*args, **kwargs):
    diagram = Diagram(*args, **kwargs)
    diagrams.append(diagram)
    return diagram


diagram = new(1, 'Đăng nhập và duy trì phiên sử dụng', 'Người dùng',
              'Giao diện\\nđăng nhập', 'Xác thực\\ntài khoản', 'Tài khoản\\nvà phiên sử dụng')
with diagram.frame('loop', 'Mỗi lần gửi đăng nhập; dừng khi thành công hoặc người dùng dừng'):
    diagram.request('A', 'Nhập email, mật khẩu; bổ sung mã xác thực nếu được yêu cầu', 'Yêu cầu đăng nhập bằng thông tin đã nhập')
    diagram.data('Tra cứu tài khoản và thông tin bảo mật đã đăng ký', 'Thông tin tài khoản, trạng thái và thiết lập bảo mật')
    diagram.process('Kiểm tra mật khẩu, trạng thái tài khoản và mã xác thực nếu bắt buộc')
    with diagram.frame('alt', 'Email, mật khẩu sai hoặc tài khoản ngừng hoạt động'):
        diagram.answer('A', 'Không chấp nhận đăng nhập')
        diagram.otherwise('Thông tin đúng; quản trị viên cần mã nhưng chưa cung cấp')
        diagram.answer('A', 'Yêu cầu mã xác thực hoặc mã khôi phục')
        diagram.otherwise('Thông tin đúng; quản trị viên cần mã nhưng mã đã gửi sai hoặc đã sử dụng')
        diagram.answer('A', 'Mã không được chấp nhận; chưa đăng nhập')
        diagram.otherwise('Thông tin đúng và đáp ứng yêu cầu xác thực')
        diagram.data('Ghi nhận phiên sử dụng hợp lệ', 'Phiên được cấp theo tài khoản hiện hành')
        diagram.answer('A', 'Đăng nhập thành công; xác định quyền sử dụng', 'Mở trang phù hợp; mở thiết lập bảo mật nếu bắt buộc')
    diagram.finish()
with diagram.frame('opt', 'Đã đăng nhập; hệ thống cần duy trì phiên khi tiếp tục sử dụng'):
    diagram.raw('activate U', 'U -> C: Yêu cầu duy trì phiên sử dụng', 'activate C')
    diagram.data('Tra cứu tài khoản và phiên sử dụng', 'Trạng thái, thời hạn và lịch sử thu hồi phiên')
    diagram.process('Kiểm tra tài khoản còn hoạt động và phiên còn được phép sử dụng')
    with diagram.frame('alt', 'Tài khoản và phiên vẫn hợp lệ'):
        diagram.data('Gia hạn hiệu lực sử dụng và thay thông tin phiên cũ', 'Phiên tiếp tục có hiệu lực')
        diagram.answer('A', 'Tiếp tục sử dụng theo quyền được cấp')
        diagram.otherwise('Phiên hết hạn, bị thu hồi hoặc tài khoản không còn hợp lệ')
        diagram.answer('A', 'Yêu cầu đăng nhập lại')
    diagram.finish()
diagram.trace('backend/src/auth/auth.service.ts', 'login', 'refresh', 'issueSession')
diagram.trace('lib/features/auth/login_screen.dart', '_submit')
diagram.trace('lib/features/auth/auth_navigation.dart', 'homeRouteForSession')
diagram.trace('lib/data/auth/auth_repository.dart', 'restore')

diagram = new(2, 'Đặt lịch xem phòng và lập hợp đồng từ lịch xem', 'Người tìm thuê',
              'Giao diện\\nlịch xem phòng', 'Quản lý\\nlịch xem và nhận thuê', 'Lịch xem, tin đăng\\nvà hợp đồng', second='Chủ trọ')
diagram.request('A', 'Chọn tin đăng và thời gian; gửi yêu cầu xem phòng', 'Yêu cầu đặt lịch xem phòng')
diagram.data('Tra cứu tin đăng và lịch hẹn hai bên', 'Tình trạng tin và các lịch hẹn hiện có')
diagram.process('Kiểm tra tin còn nhận khách, thời gian hợp lệ và không trùng lịch')
with diagram.frame('alt', 'Tin không khả dụng hoặc thời gian không đáp ứng quy định'):
    diagram.answer('A', 'Không đặt được lịch; thông báo lý do')
    diagram.otherwise('Tin và thời gian hợp lệ; không trùng lịch')
    diagram.data('Lưu lịch chờ xác nhận và nội dung thông báo cho chủ trọ', 'Yêu cầu xem phòng đã được ghi nhận')
    diagram.answer('A', 'Lịch đang chờ chủ trọ xác nhận')
diagram.finish()
with diagram.frame('opt', 'Có lịch chờ xác nhận; chủ trọ chọn xử lý'):
    diagram.request('B', 'Xác nhận lịch hẹn còn trong tương lai', 'Yêu cầu xác nhận lịch xem')
    diagram.data('Tra cứu chủ tin, lịch hiện hành và tình trạng phòng', 'Thông tin chủ tin, phòng và lịch hẹn')
    diagram.process('Kiểm tra quyền xác nhận, trạng thái lịch và khả năng nhận khách')
    with diagram.frame('alt', 'Lịch hoặc phòng đã thay đổi; lịch không còn hợp lệ'):
        diagram.answer('B', 'Không xác nhận; yêu cầu kiểm tra lại')
        diagram.otherwise('Lịch còn đủ điều kiện')
        diagram.data('Lưu lịch đã xác nhận và nội dung thông báo người xem', 'Lịch đã được xác nhận')
        diagram.answer('B', 'Xác nhận lịch xem thành công')
    diagram.finish()
with diagram.frame('opt', 'Lịch đã xác nhận và đã đến giờ hẹn'):
    diagram.request('B', 'Ghi nhận khách đã xem phòng', 'Yêu cầu hoàn tất lịch xem')
    diagram.checked_change('B', 'Tra cứu chủ tin và lịch hẹn hiện hành', 'Người quản lý, thời gian và trạng thái lịch',
                           'Kiểm tra quyền xử lý, lịch đã xác nhận và đã đến giờ hẹn',
                           'Lưu trạng thái lịch đã hoàn tất', 'Lịch được ghi nhận đã xem',
                           'Đã ghi nhận khách xem phòng', 'Không hoàn tất lịch; thông báo điều kiện chưa đáp ứng')
    diagram.finish()
with diagram.frame('opt', 'Chủ trọ chọn lập hợp đồng từ lịch đã hoàn tất'):
    diagram.request('B', 'Nhập điều khoản và yêu cầu lập hợp đồng', 'Yêu cầu lập hợp đồng từ lịch đã xem')
    diagram.data('Tra cứu lịch xem, phòng, hợp đồng và hồ sơ người thuê', 'Trạng thái lịch, phòng và hồ sơ nhận thuê hiện hành')
    diagram.process('Kiểm tra quyền lập hợp đồng, lịch đã hoàn tất và điều kiện nhận thuê')
    with diagram.frame('alt', 'Lịch, phòng hoặc người thuê không còn đủ điều kiện'):
        diagram.answer('B', 'Không tạo hợp đồng; thông báo lý do')
        diagram.otherwise('Đủ điều kiện nhận thuê')
        diagram.data('Lưu hợp đồng, phòng có người ở, tin ẩn và các lịch bị hủy', 'Các thay đổi được lưu cùng nhau; chưa ghi thu cọc')
        diagram.answer('B', 'Lập hợp đồng thành công; hiển thị người thuê và hợp đồng')
    diagram.finish()
diagram.trace('backend/src/housing/housing.service.ts', 'book', 'update', 'createLease')
diagram.trace('backend/src/leases/leases.service.ts', 'createWithinTransaction')
diagram.trace('lib/features/listings/housing_screen.dart', '_viewingAction')
diagram.trace('lib/features/listings/housing_dialog.dart')

diagram = new(3, 'Lập hợp đồng thuê phòng và ghi nhận cọc ban đầu', 'Chủ trọ',
              'Giao diện\\nlập hợp đồng', 'Quản lý\\nhợp đồng thuê', 'Phòng, người thuê\\nvà hợp đồng')
diagram.request('A', 'Chọn phòng, người thuê; nhập điều khoản và tiền cọc', 'Yêu cầu lập hợp đồng với thông tin đã nhập')
diagram.data('Tra cứu phòng, hồ sơ người thuê và hợp đồng đang hiệu lực', 'Chủ quản lý, trạng thái phòng và các hợp đồng hiện có')
diagram.process('Kiểm tra quyền quản lý, dữ liệu điều khoản và khả năng nhận thuê của phòng')
with diagram.frame('alt', 'Ngoài quyền, dữ liệu sai, phòng bảo trì hoặc chưa sẵn sàng'):
    diagram.answer('A', 'Không lập hợp đồng; chỉ rõ điều kiện chưa đáp ứng')
    diagram.otherwise('Phòng đã có hợp đồng còn hiệu lực')
    diagram.answer('A', 'Không lập hợp đồng; phòng đã được thuê')
    diagram.otherwise('Phòng và người thuê đủ điều kiện')
    with diagram.frame('group', 'Lưu đồng bộ; có lỗi thì không lưu phần thay đổi của lần lập hợp đồng'):
        diagram.data('Lưu hợp đồng có hiệu lực và tình trạng phòng có người ở', 'Hợp đồng và tình trạng phòng đã ghi nhận')
        with diagram.frame('opt', 'Tiền cọc ban đầu lớn hơn 0'):
            diagram.data('Lưu khoản cọc đã thu cho hợp đồng', 'Khoản thu cọc được lưu vào lịch sử')
    diagram.answer('A', 'Lập hợp đồng thành công; hiển thị thông tin hợp đồng')
diagram.finish()
diagram.trace('backend/src/leases/leases.service.ts', 'create', 'createWithinTransaction')
diagram.trace('lib/features/tenants/lease_form_screen.dart')

diagram = new(4, 'Đề xuất và xét duyệt biểu phí', 'Chủ trọ',
              'Giao diện\\nbiểu phí', 'Quản lý\\nbiểu phí', 'Biểu phí\\nvà kỳ tính tiền')
diagram.request('A', 'Nhập mức phí, phạm vi và tháng hiệu lực; gửi đề xuất', 'Yêu cầu ghi nhận đề xuất biểu phí')
diagram.checked_change('A', 'Tra cứu khu trọ và biểu phí hiện hành', 'Phạm vi quản lý và biểu phí đang áp dụng',
                       'Kiểm tra quyền đề xuất, mức phí và tháng hiệu lực',
                       'Lưu đề xuất biểu phí chờ duyệt', 'Đề xuất đã được ghi nhận',
                       'Đã gửi đề xuất biểu phí', 'Không gửi đề xuất; thông báo dữ liệu cần sửa')
diagram.finish()
with diagram.frame('opt', 'Có đề xuất; người dùng có quyền duyệt chọn xem tác động'):
    diagram.request('A', 'Yêu cầu xem phạm vi ảnh hưởng của đề xuất')
    diagram.data('Tra cứu giá hiện hành, phòng áp dụng, hóa đơn và kỳ đã khóa', 'Biểu phí, danh sách phòng, hóa đơn và trạng thái kỳ')
    diagram.process('Xác định phạm vi ảnh hưởng và các điều kiện ngăn phê duyệt')
    diagram.answer('A', 'Hiển thị tác động và khả năng phê duyệt')
    diagram.finish()
    diagram.request('A', 'Chọn chấp thuận hoặc từ chối; nhập lý do', 'Yêu cầu xét duyệt đề xuất biểu phí')
    diagram.data('Tra cứu lại đề xuất, kỳ hiệu lực, hóa đơn và kỳ đã khóa', 'Trạng thái đề xuất và dữ liệu áp dụng mới nhất')
    diagram.process('Kiểm tra quyền duyệt, trạng thái đề xuất và điều kiện tháng hiệu lực')
    with diagram.frame('alt', 'Đề xuất đã được xử lý hoặc ngoài quyền'):
        diagram.answer('A', 'Không ghi quyết định; yêu cầu tải lại')
        diagram.otherwise('Còn chờ duyệt; người duyệt chọn từ chối')
        diagram.data('Lưu quyết định từ chối và lý do', 'Đề xuất bị từ chối; không áp dụng mức phí')
        diagram.answer('A', 'Đã từ chối đề xuất')
        diagram.otherwise('Chọn duyệt nhưng kỳ đã tính tiền, khóa hoặc sai thứ tự hiệu lực')
        diagram.answer('A', 'Không phê duyệt; hiển thị lý do chặn')
        diagram.otherwise('Chọn duyệt và đủ điều kiện áp dụng')
        diagram.data('Lưu biểu phí được duyệt theo tháng hiệu lực', 'Biểu phí được phê duyệt; giữ lịch sử giá')
        diagram.answer('A', 'Đã phê duyệt biểu phí')
    diagram.finish()
diagram.trace('backend/src/billing/billing-tariffs.service.ts', 'propose', 'impact', 'review')
diagram.trace('lib/features/billing/billing_tariffs_screen.dart')

diagram = new(5, 'Xem trước và phát hành hóa đơn tháng', 'Chủ trọ',
              'Giao diện\\nlập hóa đơn', 'Quản lý\\nhóa đơn', 'Hợp đồng, chỉ số\\nvà hóa đơn')
diagram.request('A', 'Chọn tháng và hợp đồng hoặc khu trọ; nhập chỉ số điện nước', 'Yêu cầu xem trước tiền thuê và phí trong kỳ')
diagram.data('Tra cứu hợp đồng, biểu phí, chỉ số và hóa đơn đã có', 'Dữ liệu tính tiền và các thông tin còn thiếu')
diagram.process('Kiểm tra dữ liệu và tính trước tiền thuê, điện nước cùng các khoản phí')
diagram.answer('A', 'Hiển thị dự tính, dữ liệu thiếu và hóa đơn đã có')
diagram.finish()
with diagram.frame('opt', 'Đã bổ sung đủ dữ liệu; chủ trọ xác nhận phát hành'):
    diagram.request('A', 'Xác nhận phát hành cho một hợp đồng hoặc cả khu', 'Yêu cầu phát hành hóa đơn đã xác nhận')
    diagram.data('Tra cứu lại khu trọ, hợp đồng, kỳ, chỉ số và hóa đơn đã có', 'Dữ liệu lập hóa đơn hiện hành')
    diagram.process('Kiểm tra quyền, điều kiện phát hành và tính các khoản tiền của hóa đơn mới')
    with diagram.frame('alt', 'Dữ liệu không hợp lệ, hợp đồng hết hiệu lực hoặc kỳ đã khóa'):
        diagram.answer('A', 'Không phát hành; giữ nguyên dữ liệu đã có')
        diagram.otherwise('Đủ điều kiện; chọn một hợp đồng')
        with diagram.frame('alt', 'Hợp đồng đã có hóa đơn trong kỳ'):
            diagram.answer('A', 'Không tạo trùng; thông báo hóa đơn đã tồn tại')
            diagram.otherwise('Hợp đồng chưa có hóa đơn trong kỳ')
            diagram.data('Ghi chỉ số và hóa đơn cùng các khoản tiền', 'Hóa đơn mới được lưu')
            diagram.answer('A', 'Phát hành hóa đơn thành công')
        diagram.otherwise('Đủ điều kiện; chọn phát hành hàng loạt')
        diagram.data('Lưu hóa đơn mới của đợt; giữ nguyên các hóa đơn đã tồn tại', 'Kết quả lưu toàn bộ phần tạo mới')
        with diagram.frame('alt', 'Toàn bộ phần tạo mới thành công'):
            diagram.answer('A', 'Hoàn tất đợt; phòng đã có hóa đơn được bỏ qua')
            diagram.otherwise('Có lỗi trong phần tạo mới')
            diagram.answer('A', 'Không lưu hóa đơn mới nào của đợt; thông báo lỗi')
    diagram.finish()
diagram.trace('backend/src/billing/billing.service.ts', 'createInvoice', 'bulkInvoicePreflight', 'createBulkInvoices')
diagram.trace('backend/src/billing/billing-tariffs.service.ts', 'preview')
diagram.trace('lib/features/billing/bulk_invoice_screen.dart', '_submit')

diagram = new(6, 'Ghi nhận khoản thu và phân bổ thanh toán', 'Chủ trọ',
              'Giao diện\\nkhoản thu', 'Quản lý\\nthu tiền', 'Khoản thu\\nvà công nợ hóa đơn')
diagram.request('A', 'Chọn người thuê; nhập tiền đã nhận và các hóa đơn phân bổ', 'Yêu cầu ghi khoản thu và phân bổ thanh toán')
diagram.data('Tra cứu lần ghi nhận trước, người thuê, khoản thu và hóa đơn', 'Lịch sử yêu cầu, khoản thu và số tiền trên hóa đơn')
diagram.process('Đối chiếu yêu cầu gửi lại; kiểm tra cùng người thuê và giới hạn phân bổ')
with diagram.frame('alt', 'Gửi lại đúng yêu cầu đã ghi nhận trước đó'):
    diagram.answer('A', 'Trả kết quả đã có; không ghi thu lần nữa')
    diagram.otherwise('Dùng lại lần ghi nhận nhưng đổi nội dung; hoặc lần mới có phân bổ sai')
    diagram.answer('A', 'Không ghi khoản thu hoặc phân bổ; thông báo lý do')
    diagram.otherwise('Yêu cầu mới hợp lệ; cùng người thuê; không vượt tiền và dư nợ')
    diagram.data('Ghi khoản đã nhận và toàn bộ phân bổ được chọn', 'Khoản thu, phần đã thanh toán và tiền chưa phân bổ')
    diagram.answer('A', 'Hiển thị khoản thu và công nợ sau phân bổ')
diagram.finish()
with diagram.frame('opt', 'Khoản thu còn tiền chưa phân bổ; chọn phân bổ thêm'):
    diagram.request('A', 'Chọn hóa đơn còn nợ và số tiền phân bổ thêm', 'Yêu cầu phân bổ tiền còn dư')
    diagram.data('Tra cứu yêu cầu trước, khoản thu và các hóa đơn được chọn', 'Lịch sử xử lý, khoản thu và thanh toán hiện hành')
    diagram.process('Đối chiếu yêu cầu; kiểm tra người thuê, tiền chưa phân bổ và dư nợ')
    with diagram.frame('alt', 'Gửi lại đúng yêu cầu đã hoàn tất'):
        diagram.answer('A', 'Trả kết quả đã có; không phân bổ thêm')
        diagram.otherwise('Yêu cầu mới và toàn bộ khoản phân bổ hợp lệ')
        diagram.data('Lưu toàn bộ phân bổ và cập nhật thanh toán hóa đơn', 'Phân bổ đã lưu; không ghi dở dang')
        diagram.answer('A', 'Hiển thị tiền còn dư và công nợ mới')
        diagram.otherwise('Yêu cầu đổi nội dung hoặc phân bổ không hợp lệ')
        diagram.answer('A', 'Không phân bổ; thông báo điều kiện chưa đáp ứng')
    diagram.finish()
diagram.trace('backend/src/billing/billing-ledger.service.ts', 'createReceipt', 'allocate', 'allocateLines')
diagram.trace('backend/src/billing/billing-commands.service.ts', 'execute')
diagram.trace('lib/features/billing/billing_receipts_screen.dart')

diagram = new(7, 'Gỡ phân bổ và ghi nhận hoàn tiền khoản thu', 'Chủ trọ',
              'Giao diện\\nkhoản thu', 'Quản lý\\nphân bổ và hoàn tiền', 'Lịch sử thanh toán\\nvà tiền chưa phân bổ')
with diagram.frame('opt', 'Chọn gỡ một phân bổ đang có hiệu lực'):
    diagram.request('A', 'Chọn phân bổ; nhập lý do gỡ', 'Yêu cầu gỡ phân bổ thanh toán')
    diagram.data('Tra cứu lần yêu cầu trước, khoản thu, phân bổ và hóa đơn', 'Lịch sử xử lý, phân bổ và số tiền đã thanh toán')
    diagram.process('Đối chiếu yêu cầu gửi lại, quyền xử lý và tình trạng phân bổ')
    with diagram.frame('alt', 'Gửi lại đúng yêu cầu gỡ đã hoàn tất'):
        diagram.answer('A', 'Trả kết quả đã có; không ghi bút toán đảo thêm')
        diagram.otherwise('Ngoài quyền, đã gỡ bằng yêu cầu khác hoặc số liệu không khớp')
        diagram.answer('A', 'Không gỡ phân bổ; hiển thị lý do')
        diagram.otherwise('Phân bổ còn hiệu lực và số liệu hợp lệ')
        diagram.data('Ghi bút toán đảo; tăng tiền chưa phân bổ; cập nhật dư nợ', 'Giữ khoản gốc; lưu lịch sử gỡ phân bổ')
        diagram.answer('A', 'Đã gỡ phân bổ; hiển thị số dư và công nợ mới')
    diagram.finish()
with diagram.frame('opt', 'Có tiền chưa phân bổ; chủ trọ chọn ghi nhận khoản đã hoàn'):
    diagram.request('A', 'Nhập tiền hoàn, lý do và thông tin đối chiếu', 'Yêu cầu ghi nhận khoản đã hoàn')
    diagram.data('Tra cứu lần ghi nhận trước, khoản thu, phân bổ và khoản hoàn', 'Lịch sử yêu cầu và các khoản tiền đã ghi nhận')
    diagram.process('Đối chiếu yêu cầu gửi lại; tính tiền còn dư và kiểm tra số tiền hoàn')
    with diagram.frame('alt', 'Gửi lại đúng yêu cầu đã ghi nhận'):
        diagram.answer('A', 'Trả kết quả đã có; không ghi hoàn thêm')
        diagram.otherwise('Yêu cầu mới vượt số dư; hoặc dữ liệu không hợp lệ, nội dung gửi lại khác trước')
        diagram.answer('A', 'Không ghi hoàn tiền; yêu cầu kiểm tra hoặc gỡ phân bổ trước')
        diagram.otherwise('Yêu cầu mới hợp lệ và không vượt số dư')
        diagram.data('Lưu khoản hoàn; giảm tiền chưa phân bổ', 'Lịch sử hoàn tiền được cập nhật')
        diagram.answer('A', 'Đã ghi nhận hoàn tiền; không thực hiện chuyển tiền')
    diagram.finish()
diagram.trace('backend/src/billing/billing-ledger.service.ts', 'release', 'refund')
diagram.trace('backend/src/billing/billing-commands.service.ts', 'execute')
diagram.trace('lib/features/billing/billing_receipts_screen.dart')

diagram = new(8, 'Gửi và xét duyệt chứng từ thanh toán', 'Người thuê',
              'Giao diện\\nchứng từ thanh toán', 'Quản lý\\nchứng từ', 'Chứng từ, khoản thu\\nvà hóa đơn', second='Chủ trọ')
diagram.request('A', 'Chọn hóa đơn; gửi số tiền, thông tin và ảnh chứng từ', 'Yêu cầu tiếp nhận chứng từ thanh toán')
diagram.data('Tra cứu hóa đơn của người thuê, chứng từ đang chờ và lần gửi trước', 'Hóa đơn, thanh toán và lịch sử chứng từ')
diagram.process('Kiểm tra quyền gửi, nội dung gửi lại và số tiền còn được gửi chứng từ')
with diagram.frame('alt', 'Gửi lại đúng nội dung đã được tiếp nhận'):
    diagram.answer('A', 'Trả chứng từ đã có; không tạo thêm')
    diagram.otherwise('Lần mới có hóa đơn không hợp lệ, tiền vượt phần còn được gửi; hoặc gửi lại khác nội dung')
    diagram.answer('A', 'Không nhận chứng từ; hiển thị lý do')
    diagram.otherwise('Lần gửi mới hợp lệ')
    diagram.data('Lưu chứng từ chờ duyệt', 'Chứng từ đã gửi; chưa ghi giảm công nợ')
    diagram.answer('A', 'Chứng từ chờ chủ trọ xét duyệt')
diagram.finish()
with diagram.frame('opt', 'Chủ trọ chọn xử lý chứng từ đang chờ'):
    diagram.request('B', 'Xem chứng từ; gửi quyết định và lý do nếu từ chối', 'Yêu cầu xét duyệt chứng từ')
    diagram.data('Tra cứu chứng từ, chủ quản lý, hóa đơn và thanh toán mới nhất', 'Trạng thái chứng từ, hóa đơn và số tiền đã thanh toán')
    diagram.process('Kiểm tra quyền duyệt, trạng thái chứng từ và dư nợ hiện hành')
    with diagram.frame('alt', 'Ngoài quyền hoặc chứng từ đã được xét duyệt'):
        diagram.answer('B', 'Không xét duyệt lại; yêu cầu tải lại')
        diagram.otherwise('Chọn từ chối; có lý do hợp lệ')
        diagram.data('Lưu quyết định từ chối và lý do', 'Chứng từ bị từ chối; công nợ không đổi')
        diagram.answer('B', 'Đã từ chối chứng từ')
        diagram.otherwise('Chọn duyệt nhưng hóa đơn hủy, đã trả đủ hoặc tiền vượt dư nợ')
        diagram.answer('B', 'Không chấp thuận chứng từ; chưa ghi thu')
        diagram.otherwise('Chọn duyệt và hóa đơn còn đủ điều kiện')
        diagram.data('Lưu chấp thuận; ghi khoản thu và phân bổ vào hóa đơn', 'Chứng từ được duyệt; công nợ giảm đúng một lần')
        diagram.answer('B', 'Duyệt thành công; hiển thị trạng thái hóa đơn mới')
    diagram.finish()
diagram.trace('backend/src/tenant-portal/tenant-portal.service.ts', 'submitPaymentProof')
diagram.trace('backend/src/billing/billing.service.ts', 'reviewPaymentProof')
diagram.trace('lib/features/billing/payment_proof_review_dialog.dart')
diagram.trace('lib/features/tenant_portal/tenant_payment_proof_dialog.dart')

diagram = new(9, 'Thay thế hoặc điều chỉnh hóa đơn', 'Chủ trọ',
              'Giao diện\\nchi tiết hóa đơn', 'Quản lý\\nđiều chỉnh hóa đơn', 'Hóa đơn\\nvà lịch sử điều chỉnh')
diagram.request('A', 'Chọn thay thế hoặc điều chỉnh; nhập nội dung và lý do', 'Yêu cầu sửa hóa đơn theo cách đã chọn')
diagram.data('Tra cứu hóa đơn, lịch sử thanh toán và thay thế', 'Hóa đơn và lịch sử hiện hành')
diagram.process('Kiểm tra quyền, loại thay đổi, điều kiện thay thế và giới hạn điều chỉnh')
with diagram.frame('alt', 'Ngoài quyền, dữ liệu đề nghị sai hoặc hóa đơn không còn được điều chỉnh'):
    diagram.answer('A', 'Không thay đổi hóa đơn; hiển thị lý do')
    diagram.otherwise('Chọn thay thế')
    with diagram.frame('alt', 'Có lịch sử thanh toán hoặc đã có hóa đơn thay thế'):
        diagram.answer('A', 'Không thay thế; hóa đơn có thanh toán cần dùng điều chỉnh')
        diagram.otherwise('Chưa thanh toán, chưa bị thay thế; các khoản tiền hợp lệ')
        diagram.data('Hủy hiệu lực hóa đơn cũ; lập hóa đơn mới và liên kết thay thế', 'Hóa đơn mới được lập; giữ lịch sử hóa đơn cũ')
        diagram.answer('A', 'Hiển thị hóa đơn thay thế và liên kết hóa đơn gốc')
    diagram.otherwise('Chọn điều chỉnh tăng hoặc giảm')
    with diagram.frame('alt', 'Loại điều chỉnh sai, phí trễ hạn chưa đủ điều kiện hoặc mức giảm vượt dư nợ'):
        diagram.answer('A', 'Không ghi điều chỉnh; thông báo giới hạn')
        diagram.otherwise('Loại và số tiền điều chỉnh hợp lệ')
        diagram.data('Lưu khoản điều chỉnh; cập nhật tổng tiền và dư nợ', 'Hóa đơn sau điều chỉnh; giữ lịch sử trước đó')
        diagram.answer('A', 'Hiển thị kết quả và lịch sử điều chỉnh')
diagram.finish()
diagram.trace('backend/src/billing/billing-ledger.service.ts', 'replace', 'adjust')
diagram.trace('lib/features/billing/invoice_replacement_screen.dart')
diagram.trace('lib/features/billing/invoice_adjustment_dialog.dart')

diagram = new(10, 'Quyết toán trả phòng và ghi nhận hoàn cọc', 'Chủ trọ',
              'Giao diện\\nquyết toán', 'Quản lý\\nquyết toán thuê', 'Quyết toán, hợp đồng\\nvà sổ tiền cọc')
diagram.request('A', 'Nhập ngày trả, chỉ số cuối và các khoản phí; xem trước', 'Yêu cầu tính dự kiến quyết toán')
diagram.data('Tra cứu hợp đồng, hóa đơn, chỉ số và lịch sử cọc', 'Hợp đồng, các khoản tiền và chỉ số hiện hành')
diagram.process('Kiểm tra điều kiện trả phòng; tính chi phí cuối kỳ, khấu trừ và cọc cần hoàn')
diagram.answer('A', 'Hiển thị dự tính quyết toán; báo lỗi nếu chưa đủ điều kiện')
diagram.finish()
with diagram.frame('opt', 'Có bản xem trước hợp lệ; chủ trọ xác nhận'):
    diagram.request('A', 'Xác nhận quyết toán theo bản đã xem', 'Yêu cầu ghi nhận quyết toán')
    diagram.data('Tra cứu lại dữ liệu thuê, cọc và quyết toán đã có', 'Dữ liệu hiện hành và lịch sử xác nhận quyết toán')
    diagram.process('Đối chiếu lần xác nhận trước; tính lại và so khớp bản xem trước')
    with diagram.frame('alt', 'Gửi lại đúng lần xác nhận đã hoàn tất'):
        diagram.answer('A', 'Hiển thị quyết toán đã có; không ghi thêm')
        diagram.otherwise('Quyết toán khác đã có; hoặc chưa quyết toán nhưng dữ liệu đã đổi, không hợp lệ')
        diagram.answer('A', 'Không xác nhận; yêu cầu kiểm tra và xem trước lại')
        diagram.otherwise('Chưa quyết toán; dữ liệu còn khớp và đủ điều kiện')
        diagram.data('Lưu quyết toán, khấu trừ cọc; kết thúc thuê và chuyển phòng chờ xử lý', 'Quyết toán được xác nhận; khoản hoàn cọc chưa trả')
        diagram.answer('A', 'Hiển thị quyết toán; hóa đơn còn nợ không tự tất toán')
    diagram.finish()
with diagram.frame('opt', 'Có khoản cọc chờ hoàn; chủ trọ đã hoàn tiền thực tế'):
    diagram.request('A', 'Ghi nhận đã hoàn cọc; nhập thông tin đối chiếu và lý do', 'Yêu cầu ghi nhận khoản cọc đã hoàn')
    diagram.data('Tra cứu quyết toán, lịch sử cọc và lần ghi hoàn trước', 'Khoản cọc cần hoàn và các khoản đã ghi nhận')
    diagram.process('Đối chiếu yêu cầu gửi lại, số dư cọc và trạng thái khoản hoàn')
    with diagram.frame('alt', 'Khoản chờ hoàn hợp lệ và số dư vẫn khớp'):
        diagram.data('Ghi cọc đã hoàn và cập nhật trạng thái đã trả', 'Lịch sử cọc và quyết toán được cập nhật')
        diagram.answer('A', 'Đã ghi nhận hoàn cọc; không tự chuyển tiền')
        diagram.otherwise('Gửi lại đúng lần ghi nhận đã hoàn tất')
        diagram.answer('A', 'Trả kết quả đã có; không ghi hoàn thêm')
        diagram.otherwise('Đã ghi khác trước, số dư đổi hoặc không có tiền cần hoàn')
        diagram.answer('A', 'Không ghi hoàn; yêu cầu kiểm tra lại')
    diagram.finish()
diagram.trace('backend/src/leases/settlements.service.ts', 'preview', 'confirm', 'recordRefund', 'calculate')
diagram.trace('lib/features/tenants/lease_settlement_screen.dart')

diagram = new(11, 'Gửi, xét duyệt và thực hiện yêu cầu thay đổi thuê', 'Người thuê',
              'Giao diện\\nyêu cầu thuê', 'Quản lý\\nthay đổi thuê', 'Yêu cầu, hợp đồng\\nvà quyết toán', second='Chủ trọ')
diagram.request('A', 'Gửi yêu cầu gia hạn, chuyển phòng hoặc trả phòng', 'Yêu cầu tiếp nhận thay đổi thuê')
diagram.data('Tra cứu hợp đồng, phòng đến và yêu cầu đang chờ', 'Thông tin thuê, phòng đến và lịch sử yêu cầu')
diagram.process('Kiểm tra người gửi, thời gian và điều kiện của loại yêu cầu đã chọn')
with diagram.frame('alt', 'Dữ liệu sai, không thuộc người thuê hoặc trùng yêu cầu chờ'):
    diagram.answer('A', 'Không tiếp nhận; thông báo lý do')
    diagram.otherwise('Đáp ứng điều kiện theo loại yêu cầu')
    diagram.data('Lưu yêu cầu chờ chủ trọ xét duyệt', 'Yêu cầu đã được tiếp nhận')
    diagram.answer('A', 'Yêu cầu đang chờ xử lý; hợp đồng chưa thay đổi')
diagram.finish()
with diagram.frame('opt', 'Chủ trọ chọn xử lý yêu cầu đang chờ'):
    diagram.request('B', 'Chấp thuận hoặc từ chối; nhập lý do', 'Yêu cầu xét duyệt thay đổi thuê')
    diagram.checked_change('B', 'Tra cứu yêu cầu, hợp đồng và phòng đến nếu chuyển phòng', 'Người quản lý, trạng thái yêu cầu, hợp đồng và phòng',
                           'Kiểm tra quyền duyệt, yêu cầu còn chờ và điều kiện chấp thuận theo loại yêu cầu',
                           'Lưu quyết định và lý do xét duyệt', 'Quyết định đã lưu; hợp đồng chưa thay đổi',
                           'Đã xét duyệt; chấp thuận chưa đồng nghĩa đã thực hiện',
                           'Không ghi quyết định; thông báo điều kiện chưa đáp ứng')
    diagram.finish()
with diagram.frame('opt', 'Yêu cầu được chấp thuận; chủ trọ chọn thực hiện'):
    diagram.request('B', 'Xác nhận thực hiện; xác nhận giá thuê mới khi chuyển phòng', 'Yêu cầu thực hiện thay đổi đã được duyệt')
    diagram.data('Tra cứu lần thực hiện trước, hợp đồng, quyết toán và phòng đến', 'Lịch sử thực hiện và dữ liệu thuê hiện hành')
    diagram.process('Đối chiếu yêu cầu gửi lại; kiểm tra điều kiện gia hạn, trả hoặc chuyển phòng')
    with diagram.frame('alt', 'Gửi lại đúng lần thực hiện đã hoàn tất'):
        diagram.answer('B', 'Hiển thị kết quả đã có; không thực hiện thêm')
        diagram.otherwise('Yêu cầu đổi hoặc điều kiện thực hiện không đáp ứng')
        diagram.answer('B', 'Không thực hiện; hiển thị điều kiện cần xử lý')
        diagram.otherwise('Gia hạn; hợp đồng đủ điều kiện')
        diagram.data('Gia hạn ngày kết thúc; lưu kết quả thực hiện', 'Hợp đồng đã được gia hạn')
        diagram.answer('B', 'Gia hạn hoàn tất')
        diagram.otherwise('Trả phòng; hợp đồng đã kết thúc và có quyết toán')
        diagram.data('Lưu kết quả hoàn tất yêu cầu trả phòng', 'Yêu cầu đã được thực hiện')
        diagram.answer('B', 'Hoàn tất yêu cầu trả phòng')
        diagram.otherwise('Chuyển phòng; đã quyết toán, đến ngày chuyển; phòng đến đủ điều kiện')
        diagram.data('Lưu hợp đồng phòng mới, người ở cùng và kết quả chuyển phòng', 'Hợp đồng mới được lập; không thu cọc mới trong bước này')
        diagram.answer('B', 'Chuyển phòng hoàn tất; hiển thị hợp đồng mới')
    diagram.finish()
diagram.trace('backend/src/tenant-lifecycle/tenant-lifecycle.service.ts', 'createRequest', 'decideRequest', 'executeRequest')
diagram.trace('lib/features/tenants/tenant_lifecycle_screen.dart', '_review', '_execute')

diagram = new(12, 'Tiếp nhận và hoàn tất yêu cầu bảo trì', 'Người thuê',
              'Giao diện\\nbảo trì', 'Quản lý\\nbảo trì', 'Phiếu bảo trì\\nvà chi phí sửa chữa', second='Chủ trọ /\\nnhân viên được phân quyền')
diagram.request('A', 'Gửi sự cố của phòng đang thuê và thông tin mô tả', 'Yêu cầu tiếp nhận sự cố bảo trì')
diagram.checked_change('A', 'Tra cứu hồ sơ người thuê và phòng đang thuê', 'Hợp đồng và phòng thuộc người thuê',
                       'Kiểm tra phòng đang thuê và thông tin mô tả sự cố',
                       'Lưu phiếu yêu cầu bảo trì', 'Phiếu bảo trì đã được ghi nhận',
                       'Đã gửi yêu cầu bảo trì', 'Không tiếp nhận; thông báo thông tin cần kiểm tra')
diagram.finish()
with diagram.frame('opt', 'Có phiếu thuộc quyền quản lý; chọn phân công'):
    diagram.request('B', 'Phân công người xử lý và cập nhật tiến độ', 'Yêu cầu cập nhật xử lý bảo trì')
    diagram.checked_change('B', 'Tra cứu phiếu, người quản lý và người phụ trách', 'Phiếu và phạm vi phụ trách hiện hành',
                           'Kiểm tra quyền phân công, người phụ trách và tiến độ được phép cập nhật',
                           'Lưu người phụ trách, tiến độ và lịch sử xử lý', 'Phiếu đã được cập nhật',
                           'Đã cập nhật phiếu bảo trì', 'Không cập nhật; thông báo điều kiện chưa đáp ứng')
    diagram.finish()
with diagram.frame('loop', 'Mỗi lần một bên có quyền gửi trao đổi cho phiếu'):
    with diagram.frame('alt', 'Người thuê gửi trao đổi'):
        diagram.request('A', 'Gửi nội dung trao đổi về phiếu')
        diagram.checked_change('A', 'Tra cứu phiếu và người thuê liên quan', 'Phiếu và thông tin thuê liên quan',
                               'Kiểm tra quyền xem phiếu và nội dung trao đổi',
                               'Lưu nội dung trao đổi của người thuê', 'Nội dung đã lưu',
                               'Đã gửi nội dung trao đổi', 'Không gửi trao đổi; thông báo lý do')
        diagram.finish()
        diagram.otherwise('Chủ trọ hoặc nhân viên có quyền gửi trao đổi')
        diagram.request('B', 'Gửi nội dung trao đổi về phiếu')
        diagram.checked_change('B', 'Tra cứu phiếu và phạm vi phụ trách', 'Phiếu và người phụ trách hiện hành',
                               'Kiểm tra quyền xử lý phiếu và nội dung trao đổi',
                               'Lưu nội dung trao đổi của người xử lý', 'Nội dung đã lưu',
                               'Đã gửi nội dung trao đổi', 'Không gửi trao đổi; thông báo lý do')
        diagram.finish()
with diagram.frame('opt', 'Người có quyền hoàn tất chọn kết thúc sửa chữa'):
    diagram.request('B', 'Xác nhận hoàn tất; nhập chi phí và chọn ghi chi nếu cần', 'Yêu cầu hoàn tất phiếu bảo trì')
    diagram.data('Tra cứu phiếu và khoản chi đã liên kết', 'Tình trạng phiếu và khoản chi đã có')
    diagram.process('Kiểm tra quyền hoàn tất, trạng thái phiếu và chi phí thực tế')
    with diagram.frame('alt', 'Phiếu đã hủy hoặc thay đổi chi phí đã gắn khoản chi'):
        diagram.answer('B', 'Không hoàn tất; thông báo lý do')
        diagram.otherwise('Phiếu đủ điều kiện hoàn tất')
        with diagram.frame('group', 'Lưu đồng bộ phiếu và khoản chi; có lỗi thì không lưu thay đổi'):
            with diagram.frame('opt', 'Chọn ghi chi; chi phí lớn hơn 0; chưa có khoản chi liên kết'):
                diagram.data('Lưu khoản chi sửa chữa và liên kết phiếu', 'Khoản chi được tạo một lần')
            diagram.data('Lưu phiếu đã hoàn tất và chi phí thực tế', 'Phiếu được cập nhật')
        diagram.answer('B', 'Hiển thị phiếu hoàn tất và khoản chi nếu có')
    diagram.finish()
diagram.trace('backend/src/tenant-portal/tenant-portal.service.ts', 'createMaintenance', 'addMaintenanceComment')
diagram.trace('backend/src/maintenance/maintenance.service.ts', 'update', 'updateStatus', 'addComment', 'complete')
diagram.trace('lib/features/maintenance/maintenance_screen.dart')

diagram = new(13, 'Xem báo cáo tháng và sao chép dữ liệu CSV', 'Chủ trọ',
              'Giao diện\\nbáo cáo', 'Tổng hợp\\nbáo cáo tháng', 'Hóa đơn, thanh toán,\\nchi phí và tiền cọc')
diagram.request('A', 'Chọn tháng và khu trọ; yêu cầu xem báo cáo', 'Yêu cầu báo cáo theo tháng và khu trọ')
diagram.data('Tra cứu hóa đơn, thanh toán, chi phí, cọc và hợp đồng trong phạm vi', 'Dữ liệu tháng của các khu trọ được phép xem')
diagram.process('Kiểm tra phạm vi; tổng hợp thanh toán sau khoản đảo, chi phí, cọc và dư nợ')
with diagram.frame('alt', 'Tháng không hợp lệ hoặc khu ngoài quyền'):
    diagram.answer('A', 'Không hiển thị báo cáo; thông báo lý do')
    diagram.otherwise('Tháng và phạm vi hợp lệ')
    diagram.answer('A', 'Hiển thị báo cáo tháng và chi tiết hóa đơn')
diagram.finish()
with diagram.frame('opt', 'Người dùng có quyền xuất chọn sao chép CSV'):
    diagram.request('A', 'Yêu cầu xuất dữ liệu tháng đang chọn')
    diagram.data('Tra cứu lại dữ liệu tháng trong phạm vi được phép xem', 'Hóa đơn, thanh toán, chi phí, cọc và hợp đồng')
    diagram.process('Kiểm tra phạm vi; tổng hợp báo cáo và lập nội dung xuất')
    with diagram.frame('alt', 'Không còn quyền hoặc dữ liệu yêu cầu không hợp lệ'):
        diagram.answer('A', 'Không xuất dữ liệu; thông báo lý do')
        diagram.otherwise('Đủ điều kiện xuất')
        diagram.raw('C --> U: Nội dung CSV của báo cáo tháng',
                    'U -> U: Sao chép nội dung CSV vào bộ nhớ tạm',
                    'U --> A: Thông báo đã sao chép; không tự tải tệp')
    diagram.finish()
diagram.trace('backend/src/reports/reports.service.ts', 'monthly', 'monthlyExport')
diagram.trace('lib/features/reports/reports_screen.dart', '_exportCsv')

diagram = new(14, 'Đình chỉ và khôi phục tài khoản khách hàng', 'Quản trị viên',
              'Giao diện\\nquản lý tài khoản', 'Quản lý\\ntrạng thái tài khoản', 'Tài khoản\\nvà quyền truy cập')
diagram.request('A', 'Chọn tài khoản khách hàng; nhập lý do đình chỉ', 'Yêu cầu đình chỉ tài khoản khách hàng')
diagram.data('Tra cứu loại tài khoản, trạng thái và các phiên đã cấp', 'Thông tin tài khoản và phiên sử dụng hiện hành')
diagram.process('Kiểm tra quyền xử lý, loại tài khoản và trạng thái chưa thay đổi')
with diagram.frame('alt', 'Không đủ quyền, là quản trị viên hoặc tình trạng đã thay đổi'):
    diagram.answer('A', 'Không đình chỉ; yêu cầu kiểm tra lại')
    diagram.otherwise('Tài khoản khách hàng đủ điều kiện đình chỉ')
    diagram.data('Đình chỉ tài khoản; thu hồi quyền dùng các phiên đã cấp', 'Tài khoản bị đình chỉ và lịch sử xử lý được lưu')
    with diagram.frame('opt', 'Tài khoản bị đình chỉ là chủ trọ'):
        diagram.data('Thu hồi phiên của nhân viên thuộc chủ trọ', 'Nhân viên không tiếp tục truy cập bằng phiên cũ')
    diagram.answer('A', 'Đình chỉ thành công; giữ dữ liệu và lịch sử tài chính')
diagram.finish()
with diagram.frame('opt', 'Tài khoản đang bị đình chỉ; chọn khôi phục'):
    diagram.request('A', 'Yêu cầu khôi phục tài khoản và nhập lý do')
    diagram.checked_change('A', 'Tra cứu tài khoản và trạng thái hiện hành', 'Loại tài khoản và trạng thái mới nhất',
                           'Kiểm tra quyền xử lý và điều kiện khôi phục tài khoản',
                           'Lưu tài khoản hoạt động và lịch sử khôi phục', 'Tài khoản đã khôi phục; phiên cũ vẫn bị thu hồi',
                           'Đã khôi phục; người dùng cần đăng nhập lại',
                           'Không khôi phục; yêu cầu kiểm tra trạng thái hiện hành')
    diagram.finish()
diagram.trace('backend/src/admin/admin-console.service.ts', 'status')
diagram.trace('lib/features/admin/admin_accounts_screen.dart')

diagram = new(15, 'Tra cứu phòng và xử lý kiểm duyệt tin đăng', 'Quản trị viên',
              'Giao diện\\ntra cứu và kiểm duyệt', 'Quản lý\\ntra cứu và kiểm duyệt', 'Thông tin phòng\\nvà hồ sơ tin đăng')
diagram.request('A', 'Lọc khu trọ và phòng; yêu cầu tra cứu', 'Yêu cầu tra cứu phòng theo bộ lọc')
diagram.data('Tra cứu phòng trong phạm vi được xem', 'Danh sách phòng và trạng thái tin liên quan')
diagram.answer('A', 'Hiển thị thông tin chỉ đọc; không sửa phòng từ kết quả tra cứu')
diagram.finish()
with diagram.frame('opt', 'Có quyền kiểm duyệt; chọn tin đăng của phòng'):
    diagram.request('A', 'Mở đúng hồ sơ tin đăng cần kiểm duyệt', 'Yêu cầu xem hồ sơ kiểm duyệt của tin')
    diagram.data('Tra cứu tin đăng và việc phân công xử lý', 'Nội dung tin, trạng thái và người phụ trách')
    diagram.answer('A', 'Hiển thị hồ sơ kiểm duyệt đúng tin đăng')
    diagram.finish()
    with diagram.frame('opt', 'Tin đang chờ; quản trị viên chọn nhận xử lý'):
        diagram.request('A', 'Yêu cầu nhận xử lý tin đăng')
        diagram.checked_change('A', 'Tra cứu công việc và phân công hiện hành', 'Trạng thái công việc và người đang phụ trách',
                               'Kiểm tra quyền nhận việc và tình trạng phân công',
                               'Lưu phân công người nhận việc', 'Phân công đã lưu',
                               'Đã nhận việc kiểm duyệt', 'Không nhận được việc; thông báo lý do')
        diagram.finish()
    diagram.request('A', 'Gửi quyết định duyệt, từ chối hoặc ẩn tin; nhập lý do khi cần', 'Yêu cầu ghi nhận quyết định kiểm duyệt')
    diagram.data('Tra cứu phân công, trạng thái tin và tình trạng phòng', 'Người phụ trách và dữ liệu kiểm duyệt hiện hành')
    diagram.process('Kiểm tra quyền xử lý, phân công và điều kiện ra quyết định')
    with diagram.frame('alt', 'Không có quyền xử lý, tin đã đổi hoặc điều kiện không đạt'):
        diagram.answer('A', 'Không lưu quyết định; yêu cầu kiểm tra lại')
        diagram.otherwise('Quyết định phù hợp trạng thái và đủ điều kiện')
        diagram.data('Lưu quyết định, trạng thái tin và lịch sử kiểm duyệt', 'Tin đăng được cập nhật')
        diagram.answer('A', 'Hiển thị kết quả kiểm duyệt')
    diagram.finish()
diagram.trace('backend/src/admin/admin.service.ts', 'rooms')
diagram.trace('backend/src/admin/admin-console.service.ts', 'work', 'moderationItem')
diagram.trace('backend/src/listings/listings.service.ts', 'review', 'mutate')
diagram.trace('lib/features/admin/admin_inventory_widgets.dart')

diagram = new(16, 'Nhập sao kê và xét duyệt đề nghị đối soát', 'Quản trị viên\\nngười lập đề nghị',
              'Giao diện\\nđối soát', 'Quản lý\\nđối soát thu tiền', 'Sao kê, khoản thu\\nvà đề nghị đối soát', second='Quản trị viên\\nngười kiểm tra độc lập')
diagram.request('A', 'Nhập sao kê CSV và chọn dòng cần đối soát', 'Yêu cầu nhập sao kê và tìm khoản thu phù hợp')
diagram.process('Kiểm tra quyền nhập và nội dung sao kê')
with diagram.frame('break', 'Không có quyền nhập hoặc nội dung sao kê không hợp lệ'):
    diagram.answer('A', 'Không nhập sao kê; thông báo nội dung cần kiểm tra')
diagram.data('Tra cứu khu trọ, lần nhập trước và giao dịch sao kê đã có', 'Thông tin khu trọ và lịch sử nhập sao kê')
diagram.process('Đối chiếu lần nhập, tài khoản sao kê và giao dịch trùng')
with diagram.frame('alt', 'Gửi lại đúng lần nhập với nội dung đã lưu'):
    diagram.answer('A', 'Trả kết quả lần nhập trước; không lưu sao kê trùng')
    diagram.otherwise('Khu trọ không tồn tại, lần nhập đổi nội dung hoặc giao dịch đã nhập')
    diagram.answer('A', 'Không nhập sao kê; thông báo nội dung cần kiểm tra')
    diagram.otherwise('Lần nhập mới hợp lệ')
    diagram.data('Tra cứu khoản thu và thanh toán liên quan đến các dòng sao kê', 'Số tiền, mã đối chiếu, thời gian và tình trạng đã ghép')
    diagram.process('Tìm khoản phù hợp duy nhất theo khu trọ, số tiền, mã đối chiếu và thời gian')
    diagram.data('Lưu sao kê và các dòng; lưu liên kết tự động khi có khoản phù hợp duy nhất', 'Sao kê, dòng đã ghép tự động và dòng chưa ghép')
    diagram.answer('A', 'Hiển thị kết quả nhập, số dòng tự ghép và số dòng cần xử lý')
diagram.finish()
diagram.raw('opt Có dòng sao kê chưa ghép; người lập chọn đề nghị ghép')
diagram.request('A', 'Chọn khoản thu và gửi đề nghị ghép; nhập lý do', 'Yêu cầu lập đề nghị đối soát khoản thu')
diagram.data('Tra cứu dòng sao kê, khoản thu và đề nghị đang chờ', 'Số tiền, lịch sử ghép và các đề nghị hiện có')
diagram.process('Kiểm tra quyền đề nghị, số tiền và điều kiện ghép khoản thu')
with diagram.frame('alt', 'Sai số tiền, sai phạm vi hoặc dòng đã có đề nghị chờ'):
    diagram.answer('A', 'Không lập đề nghị; thông báo lý do')
    diagram.otherwise('Khoản thu và dòng sao kê đủ điều kiện')
    diagram.data('Lưu đề nghị chờ người khác xét duyệt', 'Đề nghị chưa làm thay đổi kết quả đối soát')
    diagram.answer('A', 'Đề nghị đang chờ kiểm tra độc lập')
diagram.finish()
diagram.raw('end')
with diagram.frame('opt', 'Có đề nghị đang chờ; quản trị viên chọn kiểm tra'):
    diagram.request('B', 'Gửi quyết định chấp thuận hoặc từ chối và lý do', 'Yêu cầu xét duyệt đề nghị đối soát')
    diagram.data('Tra cứu người lập, đề nghị và dòng sao kê hiện hành', 'Danh tính người lập và tình trạng đề nghị')
    diagram.process('Kiểm tra người duyệt khác người lập và đề nghị còn chờ xử lý')
    with diagram.frame('alt', 'Người kiểm tra là người lập hoặc đề nghị, sao kê đã đổi'):
        diagram.answer('B', 'Không cho xét duyệt đề nghị')
        diagram.otherwise('Người khác kiểm tra; chọn từ chối')
        diagram.data('Lưu quyết định từ chối và lý do', 'Đề nghị bị từ chối; chưa ghép khoản thu')
        diagram.answer('B', 'Đã từ chối đề nghị')
        diagram.otherwise('Người khác kiểm tra; chọn chấp thuận')
        diagram.data('Tra cứu lại khoản thu, số tiền và liên kết đối soát', 'Khoản thu và các liên kết hiện hành')
        diagram.process('Đối chiếu số tiền và kiểm tra khoản thu chưa được ghép')
        with diagram.frame('alt', 'Khoản thu không còn đủ điều kiện'):
            diagram.answer('B', 'Không chấp thuận; chưa ghi kết quả ghép')
            diagram.otherwise('Khoản thu còn hợp lệ')
            diagram.data('Ghi liên kết đối soát và quyết định chấp thuận', 'Dòng sao kê được ghép một lần với khoản thu')
            diagram.answer('B', 'Đối soát hoàn tất; không nhân tiền theo từng phân bổ')
    diagram.finish()
diagram.trace('backend/src/platform/finance-reconciliation.service.ts', 'importStatement', 'propose', 'review', 'validateReceipt')
diagram.trace('lib/features/admin/admin_finance_workflow.dart')

diagram = new(17, 'Hỏi hướng dẫn sử dụng và đọc nguồn được phép', 'Chủ trọ',
              'Giao diện\\ntrợ lý hướng dẫn', 'Tư vấn\\nhướng dẫn sử dụng', 'Tài liệu hướng dẫn\\ntheo quyền sử dụng')
diagram.request('A', 'Nhập câu hỏi và phạm vi khu trọ nếu cần', 'Yêu cầu hướng dẫn sử dụng theo phạm vi đã chọn')
with diagram.frame('alt', 'Trợ lý tắt, bận, quá thời gian hoặc phạm vi không được phép'):
    diagram.answer('A', 'Chưa thể trả lời; thông báo lý do')
    diagram.otherwise('Câu hỏi thiếu ngữ cảnh hoặc yêu cầu số liệu hoạt động hiện tại')
    diagram.answer('A', 'Yêu cầu làm rõ hoặc nêu giới hạn; không cung cấp số liệu trực tiếp')
    diagram.otherwise('Câu hỏi hướng dẫn hợp lệ và được phép')
    diagram.data('Tra cứu tài liệu hướng dẫn trong phạm vi được đọc', 'Nội dung hướng dẫn và thông tin nguồn còn hiệu lực')
    diagram.process('Chọn các đoạn hướng dẫn liên quan đến câu hỏi; kiểm tra mức độ đủ căn cứ')
    with diagram.frame('alt', 'Không có nguồn đủ căn cứ'):
        diagram.answer('A', 'Thông báo chưa đủ căn cứ để trả lời')
        diagram.otherwise('Có tài liệu phù hợp')
        diagram.raw('C -> C: Soạn câu trả lời và đối chiếu trích dẫn với tài liệu')
        diagram.data('Tra cứu lại trạng thái và phạm vi của nguồn đã dùng', 'Tình trạng nguồn tại thời điểm trả lời')
        diagram.process('Kiểm tra nguồn còn hiệu lực và người dùng vẫn được phép đọc')
        with diagram.frame('alt', 'Câu trả lời hợp lệ và nguồn vẫn được phép sử dụng'):
            diagram.answer('A', 'Hiển thị hướng dẫn và nguồn tham khảo')
            diagram.otherwise('Nội dung không đủ căn cứ, không hợp lệ hoặc nguồn đã thay đổi')
            diagram.answer('A', 'Thông báo chưa thể cung cấp câu trả lời có căn cứ')
diagram.finish()
with diagram.frame('opt', 'Có nguồn tham khảo; chủ trọ chọn đọc'):
    diagram.request('A', 'Yêu cầu mở nguồn tham khảo')
    diagram.data('Tra cứu nguồn tham khảo, trạng thái và phạm vi được đọc', 'Nội dung nguồn cùng thông tin phạm vi và hiệu lực')
    diagram.process('Kiểm tra lại quyền đọc và hiệu lực nguồn')
    with diagram.frame('alt', 'Nguồn còn hiệu lực và có quyền đọc'):
        diagram.answer('A', 'Hiển thị nội dung nguồn hướng dẫn')
        diagram.otherwise('Nguồn không còn khả dụng hoặc không được phép')
        diagram.answer('A', 'Không mở nguồn; thông báo lý do')
    diagram.finish()
diagram.trace('backend/src/chatbot/chatbot.service.ts', 'ask', 'answer', 'getSource', 'validateAnswer')
diagram.trace('backend/src/chatbot/knowledge.repository.ts')
diagram.trace('lib/features/chatbot/chatbot_screen.dart', '_send')
diagram.trace('lib/features/chatbot/widgets/chat_source_sheet.dart')

diagram = new(18, 'Xét duyệt hồ sơ xác minh chủ trọ', 'Quản trị viên',
              'Giao diện\\nhồ sơ xác minh', 'Quản lý\\nxác minh chủ trọ', 'Hồ sơ xác minh\\nvà chứng cứ hỗ trợ')
diagram.request('A', 'Lọc và mở hồ sơ chủ trọ đang chờ xác minh', 'Yêu cầu tra cứu hồ sơ xác minh')
diagram.data('Tra cứu hồ sơ và chứng cứ gắn với yêu cầu hỗ trợ', 'Hồ sơ, trạng thái và chứng cứ được phép xem')
diagram.answer('A', 'Hiển thị hồ sơ để kiểm tra')
diagram.finish()
diagram.request('A', 'Chọn chấp thuận, từ chối hoặc yêu cầu bổ sung; nhập lý do', 'Yêu cầu xét duyệt hồ sơ xác minh')
diagram.data('Tra cứu người nộp, trạng thái hồ sơ và thông tin chứng cứ hiện hành', 'Tài khoản, hồ sơ và kết quả kiểm tra chứng cứ')
diagram.process('Kiểm tra quyền, người xét duyệt, trạng thái hồ sơ và điều kiện chứng cứ')
with diagram.frame('alt', 'Tự duyệt hồ sơ, hồ sơ đã đổi hoặc không còn chờ'):
    diagram.answer('A', 'Không ghi quyết định; thông báo lý do')
    diagram.otherwise('Chọn chấp thuận nhưng chủ trọ hoặc chứng cứ không đủ điều kiện')
    diagram.answer('A', 'Không xác minh; yêu cầu kiểm tra tài khoản và chứng cứ')
    diagram.otherwise('Chọn chấp thuận; tài khoản hoạt động, phiếu đúng chủ trọ chưa gộp, chứng cứ đã kiểm tra an toàn')
    diagram.data('Lưu chấp thuận, người duyệt và căn cứ chứng minh', 'Chủ trọ được ghi nhận đã xác minh')
    diagram.answer('A', 'Đã xác minh chủ trọ')
    diagram.otherwise('Chọn từ chối hoặc yêu cầu bổ sung; hồ sơ còn hợp lệ')
    diagram.data('Lưu quyết định và lý do; giữ căn cứ xét duyệt', 'Hồ sơ bị từ chối hoặc cần bổ sung')
    diagram.answer('A', 'Hiển thị trạng thái hồ sơ và lý do')
diagram.finish()
diagram.trace('backend/src/admin/admin-verification.service.ts', 'list', 'review')
diagram.trace('lib/features/admin/admin_production_panels.dart')

diagram = new(19, 'Gán và kết thúc quyền sử dụng gói', 'Quản trị viên',
              'Giao diện\\nquản lý gói', 'Quản lý\\nquyền sử dụng gói', 'Gói dịch vụ\\nvà quyền của chủ trọ')
diagram.request('A', 'Chọn chủ trọ, gói, hạn sử dụng và lý do gán gói', 'Yêu cầu gán quyền sử dụng gói')
diagram.data('Tra cứu tài khoản, gói, quyền hiện hành và số khu, phòng', 'Trạng thái tài khoản, gói và số lượng khu, phòng hiện có')
diagram.process('Kiểm tra quyền gán, hạn sử dụng, thay đổi dữ liệu và hạn mức của gói')
with diagram.frame('alt', 'Tài khoản, gói ngừng hoạt động; hạn sai hoặc dữ liệu đã đổi'):
    diagram.answer('A', 'Không gán gói; yêu cầu kiểm tra lại')
    diagram.otherwise('Số khu hoặc phòng hiện có vượt hạn mức gói')
    diagram.answer('A', 'Không gán gói; không xóa dữ liệu để ép theo hạn mức')
    diagram.otherwise('Đủ điều kiện gán hoặc thay gói')
    diagram.data('Ghi quyền sử dụng, điều kiện gói và lịch sử thay đổi', 'Quyền sử dụng gói được cập nhật; không ghi thu tiền')
    diagram.answer('A', 'Gán gói thành công; hiển thị quyền và thời hạn')
diagram.finish()
with diagram.frame('opt', 'Quyền sử dụng đang hiệu lực; chọn kết thúc'):
    diagram.request('A', 'Yêu cầu kết thúc gói và nhập lý do', 'Yêu cầu kết thúc quyền sử dụng gói')
    diagram.data('Tra cứu quyền sử dụng gói hiện hành', 'Trạng thái hiệu lực mới nhất')
    diagram.process('Kiểm tra quyền kết thúc và trạng thái chưa thay đổi')
    with diagram.frame('alt', 'Quyền đã đổi hoặc đã kết thúc'):
        diagram.answer('A', 'Không kết thúc lại; yêu cầu tải lại')
        diagram.otherwise('Quyền vẫn đang có hiệu lực')
        diagram.data('Ghi thời điểm kết thúc và lịch sử xử lý', 'Quyền sử dụng gói đã kết thúc')
        diagram.answer('A', 'Kết thúc gói; không hoàn tiền và không xóa dữ liệu')
    diagram.finish()
diagram.trace('backend/src/admin/admin-plans.service.ts', 'assign', 'cancel')
diagram.trace('lib/features/admin/admin_production_panels.dart')


def run():
    IMAGES.mkdir(parents=True, exist_ok=True)
    report_hash = hashlib.sha256(REPORT.read_bytes()).hexdigest()
    audit = []
    for diagram in diagrams:
        diagram.trace('backend/prisma/schema.prisma')
        body = diagram.write()
        assert 'database "<u>Cơ sở dữ liệu</u>" as D #FFFFB9' in body
        assert not re.search(r'(?m)^entity ', body)
        assert not re.search(r'(?m)^[AUDB] -> D', body)
        assert not re.search(r'(?m)^C -> D \+\+: (?:Kiểm tra|Đối chiếu|Tính|Xác định)', body)
        evidence = []
        for item in diagram.evidence:
            path = ROOT / item['path']
            assert path.exists(), path
            text = path.read_text()
            locations = {}
            for symbol in item['symbols']:
                match = re.search(r'(?m)^[ \t]*(?:(?:private|public|protected|static|async|override|void|String|Future(?:<[^>]+>)?)\s+)*' + re.escape(symbol) + r'\s*(?:<[^>]+>)?\s*\(', text)
                assert match, (path, symbol)
                locations[symbol] = text[:match.start()].count('\n') + 1
            evidence.append({**item, 'lines': locations, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        audit.append({'id': diagram.key, 'title': diagram.title, 'data_scope': diagram.data_scope, 'sources': evidence})
    command = [JAVA, '-Djava.awt.headless=true', '-Dfile.encoding=UTF-8',
               '-DPLANTUML_LIMIT_SIZE=12000', '-jar', JAR, '-charset', 'UTF-8']
    paths = [str(SOURCE / f'{diagram.key}.puml') for diagram in diagrams]
    subprocess.run(command + ['-checkonly'] + paths, check=True)
    subprocess.run(command + ['-tsvg'] + paths, check=True)
    subprocess.run(command + ['-tpng', '-o', str(IMAGES)] + paths, check=True)
    for item in audit:
        svg_path = SOURCE / f'{item["id"]}.svg'
        svg = etree.parse(str(svg_path))
        texts = svg.xpath('//*[local-name()="text"]/text()')
        assert not any('Syntax Error' in text or 'Error line' in text for text in texts)
        assert not any(re.search(r'</?\w+>', text) for text in texts), (svg_path, texts)
        assert not svg.xpath('//*[local-name()="a"]'), svg_path
        assert all(shape.get('fill') == '#FFFFB9' for shape in svg.xpath('//*[local-name()="ellipse"]'))
        viewbox = [float(value) for value in svg.getroot().get('viewBox').split()]
        for text in svg.xpath('//*[local-name()="text"]'):
            x, y = float(text.get('x')), float(text.get('y'))
            width = float(text.get('textLength', '0'))
            assert x >= 0 and x + width <= viewbox[2] + 1 and 0 < y < viewbox[3], (svg_path, text.text)
        labels = [int(match.group(1)) for text in texts if (match := re.fullmatch(r'(\d+)\.', text))]
        assert labels == list(range(1, len(labels) + 1)), (svg_path, labels)
        png = IMAGES / f'Sequence_Diagram_{item["id"]}.png'
        generated = IMAGES / f'{item["id"]}.png'
        with Image.open(generated) as image:
            image.convert('RGB').save(png, dpi=(300, 300))
        generated.unlink()
        with Image.open(png) as image:
            image.verify()
        with Image.open(png) as image:
            assert min(image.size) >= 1500
            assert image.getpixel((0, 0)) == (255, 255, 255)
            item['pixels'] = list(image.size)
            item['dpi'] = image.info['dpi']
        item['sha256'] = hashlib.sha256(png.read_bytes()).hexdigest()
        for source in item['sources']:
            assert hashlib.sha256((ROOT / source['path']).read_bytes()).hexdigest() == source['sha256']
    assert hashlib.sha256(REPORT.read_bytes()).hexdigest() == report_hash
    (SOURCE / 'verification.json').write_text(json.dumps({'report_sha256': report_hash, 'diagrams': audit}, ensure_ascii=False, indent=2))
    trace = ['# Truy vết nội dung sơ đồ', '',
             'Các đường dẫn tính từ thư mục gốc dự án. Số dòng trỏ tới khai báo thao tác được dùng làm căn cứ.',
             'Nội dung trong hình là diễn giải nghiệp vụ, không phải tên thao tác triển khai.', '']
    for item in audit:
        trace.extend([f'## {item["id"]}. {item["title"]}', ''])
        for evidence in item['sources']:
            if evidence['lines']:
                trace.extend(f'- `{evidence["path"]}:{line}` - `{symbol}`' for symbol, line in evidence['lines'].items())
            else:
                trace.append(f'- `{evidence["path"]}`')
        trace.append('')
    (BASE / 'TRUY_VET.md').write_text('\n'.join(trace), encoding='utf-8')
    archive = ROOT / 'output/So_Do_Tuan_Tu_BA_Bao_Cao_2026-10-30_19_PNG.zip'
    with ZipFile(archive, 'w', ZIP_DEFLATED) as bundle:
        for image_path in sorted(IMAGES.glob('Sequence_Diagram_*.png')):
            bundle.write(image_path, image_path.name)
    with ZipFile(archive) as bundle:
        assert len(bundle.namelist()) == 19
        assert bundle.testzip() is None
    print(json.dumps({'archive': str(archive), 'diagrams': [{key: item[key] for key in ('id', 'title', 'pixels')} for item in audit]}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    run()
