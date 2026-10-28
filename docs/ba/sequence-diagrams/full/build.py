import argparse
import copy
import hashlib
import json
import math
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]
MODEL = json.loads((BASE / 'model.json').read_text())
COLOR = '#800000'
FILL = '#FFFFB9'
FONT_PATH = '/System/Library/Fonts/Supplemental/Tahoma.ttf'
FONT = ImageFont.truetype(FONT_PATH, 24)
SVG_NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG_NS)


def wrap(text, width, size=24):
    font = ImageFont.truetype(FONT_PATH, size)
    lines = []
    current = ''
    for word in text.split():
        candidate = (current + ' ' + word).strip()
        if current and font.getlength(candidate) > width:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or ['']


class Figure:
    def __init__(self, view):
        self.view = view
        self.width = 1760 if len(view['participants']) == 5 else 1420
        self.centers = [150 + index * 365 for index in range(len(view['participants']))]
        self.shapes = []
        self.messages = []
        self.fragments = []
        header_height = max(len(wrap(person['name'], 292, 25)) for person in view['participants']) * 30
        self.lifeline_start = 111 + header_height + 5
        self.position = self.lifeline_start + 17
        self.counter = 0
        self.render_items(view['items'], [])
        self.height = self.position + 45
        self.participants()
        self.activations()

    def add(self, kind, **values):
        self.shapes.append(dict(kind=kind, **values))

    def line(self, points, dashed=False, arrow=None, z=5):
        self.add('line', points=points, dashed=dashed, arrow=arrow, z=z)

    def rect(self, x, y, width, height, fill='none', stroke=COLOR, z=1):
        self.add('rect', x=x, y=y, width=width, height=height, fill=fill, stroke=stroke, z=z)

    def text(self, text, x, y, width, size=24, align='center', underline=False, z=6, bold=False, background=False):
        lines = wrap(text, width - 8, size)
        if background:
            self.rect(x, y, min(width, max(ImageFont.truetype(FONT_PATH, size).getlength(line) for line in lines) + 8), len(lines) * (size + 5), fill='#FFFFFF', stroke='none', z=5)
        self.add('text', text=text, lines=lines, x=x, y=y, width=width,
                 height=len(lines) * (size + 5), size=size, align=align,
                 underline=underline, bold=bold, z=z)
        return len(lines) * (size + 5)

    def render_items(self, items, guards, implementation_guards=None):
        implementation_guards = implementation_guards or []
        for item in items:
            if item['type'] == 'message':
                self.counter += 1
                item['number'] = self.counter
                source = self.centers[item['from']]
                target = self.centers[item['to']]
                self_call = source == target
                label_width = 320 if self_call else abs(target - source) - 28
                label = str(self.counter) + ': ' + item['label']
                lines = wrap(label, label_width)
                label_y = self.position + 7
                arrow_y = label_y + 29 * len(lines) + 5
                if self_call:
                    self.text(label, source + 24, label_y, label_width, align='left')
                    self.line([(source + 7, arrow_y), (source + 92, arrow_y),
                               (source + 92, arrow_y + 19), (source + 7, arrow_y + 19)],
                              item['reply'], 'open' if item['reply'] else 'block')
                    self.position = arrow_y + 36
                else:
                    left = min(source, target)
                    self.text(label, left + 14, label_y, label_width)
                    direction = 1 if target > source else -1
                    self.line([(source + direction * 7, arrow_y), (target - direction * 7, arrow_y)],
                              item['reply'], 'open' if item['reply'] else 'block')
                    self.position = arrow_y + 21
                self.messages.append(dict(item, y=arrow_y, guards=list(guards), implementation_guards=list(implementation_guards)))
            elif item['type'] == 'ref':
                left = self.centers[item['from']] - 88
                right = self.centers[item['to']] + 100
                width = right - left
                lines = wrap(item['label'], width - 94, 22)
                height = max(54, len(lines) * 27 + 20)
                self.rect(left, self.position + 7, width, height, fill='#FFFFFF', z=4)
                self.rect(left, self.position + 7, 56, 29, fill=FILL, z=4)
                self.text('ref', left + 2, self.position + 8, 52, size=20, bold=True)
                self.text(item['label'], left + 68, self.position + 16, width - 82, size=22)
                self.position += height + 23
            elif item['type'] == 'fragment':
                start = self.position + 4
                left = 58 + len(guards) * 12
                width = self.width - left - 42 - len(guards) * 12
                for operand, branch in enumerate(item['branches']):
                    if operand:
                        self.position += 10
                        self.line([(left, self.position), (left + width, self.position)], dashed=True, z=1)
                    guard_x = left + (88 if operand == 0 else 17)
                    guard_text = '[' + branch['guard'] + ']'
                    height = self.text(guard_text, guard_x, self.position + 7,
                                       width - (guard_x - left) - 20, size=22, align='left', background=True)
                    self.position += height + 20
                    branch_implementation = [item['kind'] + ' ' + branch['implementation_guard']] if branch.get('implementation_guard') else []
                    self.render_items(branch['items'], guards + [item['kind'] + ' ' + branch['guard']], implementation_guards + branch_implementation)
                self.position += 9
                self.rect(left, start, width, self.position - start)
                self.line([(left, start + 34), (left + 65, start + 34),
                           (left + 78, start + 21), (left + 78, start)], z=1)
                self.text(item['kind'], left + 3, start + 1, 67, size=22, bold=True)
                self.fragments.append(dict(kind=item['kind'], guards=[branch['guard'] for branch in item['branches']]))
                self.position += 13

    def participants(self):
        for index, person in enumerate(self.view['participants']):
            center = self.centers[index]
            self.line([(center, self.lifeline_start), (center, self.height - 22)], dashed=True, z=2)
            if person['kind'] == 'actor':
                self.add('ellipse', x=center-12, y=26, width=24, height=24, fill=FILL, z=4)
                self.line([(center, 50), (center, 85)], z=4)
                self.line([(center-24, 61), (center+24, 61)], z=4)
                self.line([(center-24, 107), (center, 85), (center+24, 107)], z=4)
            elif person['kind'] == 'database':
                self.rect(center-40, 38, 80, 62, fill=FILL, z=4)
                self.add('ellipse', x=center-40, y=84, width=80, height=24, fill=FILL, z=4)
                self.rect(center-39, 75, 78, 22, fill=FILL, stroke='none', z=4)
                self.add('ellipse', x=center-40, y=25, width=80, height=26, fill=FILL, z=4)
            else:
                self.add('ellipse', x=center-40, y=29, width=80, height=74, fill=FILL, z=4)
                if person['kind'] == 'boundary':
                    self.line([(center-55, 45), (center-55, 87)], z=4)
                    self.line([(center-55, 66), (center-40, 66)], z=4)
                else:
                    self.line([(center+8, 17), (center-12, 29), (center+8, 40)], z=4)
            self.text(person['name'], center-150, 111, 300, size=25,
                      underline=person['kind'] != 'actor')

    def activations(self):
        for index, participant in enumerate(self.view['participants']):
            if participant['kind'] == 'actor':
                continue
            relevant = [message for message in self.messages if index in (message['from'], message['to'])]
            if not relevant:
                continue
            if participant['kind'] == 'database':
                for position, message in enumerate(self.messages):
                    if message['to'] != index or message['reply']:
                        continue
                    end = message['y'] + 20
                    if position + 1 < len(self.messages):
                        following = self.messages[position + 1]
                        if following['from'] == index and following['reply']:
                            end = following['y']
                    self.rect(self.centers[index]-7, message['y'], 14, max(20, end-message['y']), fill=FILL, z=3)
            else:
                self.rect(self.centers[index]-7, relevant[0]['y'], 14,
                          max(20, relevant[-1]['y']-relevant[0]['y']), fill=FILL, z=3)

    def svg(self):
        root = ET.Element('{%s}svg' % SVG_NS, width=str(self.width), height=str(self.height),
                          viewBox=f'0 0 {self.width} {self.height}')
        ET.SubElement(root, 'title').text = self.view['id'] + ' ' + self.view['title']
        ET.SubElement(root, 'desc').text = 'Biểu đồ tuần tự màu vàng nhạt không có khung ngoài; các khung chỉ là nhánh UML. '
        definitions = ET.SubElement(root, 'defs')
        for arrow in ['block', 'open']:
            marker = ET.SubElement(definitions, 'marker', id=arrow, viewBox='0 0 10 10', refX='9', refY='5',
                                   markerWidth='8', markerHeight='8', orient='auto-start-reverse')
            ET.SubElement(marker, 'path', d='M 1 1 L 9 5 L 1 9' + (' Z' if arrow == 'block' else ''),
                          fill=COLOR if arrow == 'block' else 'none', stroke=COLOR, **{'stroke-width':'1.2'})
        ET.SubElement(root, 'rect', x='0', y='0', width=str(self.width), height=str(self.height), fill='#FFFFFF')
        for shape in sorted(self.shapes, key=lambda value: value['z']):
            kind = shape['kind']
            if kind in ['rect', 'ellipse']:
                attributes = {'fill':shape['fill'], 'stroke':shape.get('stroke', COLOR), 'stroke-width':'1.5'}
                if kind == 'rect':
                    attributes.update({key:str(shape[key]) for key in ['x','y','width','height']})
                else:
                    attributes.update(cx=str(shape['x']+shape['width']/2), cy=str(shape['y']+shape['height']/2),
                                      rx=str(shape['width']/2), ry=str(shape['height']/2))
                ET.SubElement(root, kind, attributes)
            elif kind == 'line':
                attributes = dict(points=' '.join(f'{horizontal},{vertical}' for horizontal, vertical in shape['points']),
                                  fill='none', stroke=COLOR, **{'stroke-width':'1.5'})
                if shape['dashed']:
                    attributes['stroke-dasharray'] = '6 5'
                if shape['arrow']:
                    attributes['marker-end'] = 'url(#' + shape['arrow'] + ')'
                ET.SubElement(root, 'polyline', attributes)
            else:
                anchor = 'middle' if shape['align'] == 'center' else 'start'
                horizontal = shape['x']+shape['width']/2 if anchor == 'middle' else shape['x']
                for index, text in enumerate(shape['lines']):
                    element = ET.SubElement(root, 'text', x=str(horizontal), y=str(shape['y']+shape['size']+index*(shape['size']+5)),
                                            fill='#000000', **{'font-family':'Tahoma, Arial, sans-serif', 'font-size':str(shape['size']),
                                            'text-anchor':anchor, 'font-weight':'bold' if shape['bold'] else 'normal'})
                    if shape['underline']:
                        element.set('text-decoration', 'underline')
                    element.text = text
        return ET.tostring(root, encoding='unicode')

    def mxgraph(self):
        diagram = ET.Element('diagram', id=self.view['id'], name=self.view['id']+' '+self.view['title'])
        model = ET.SubElement(diagram, 'mxGraphModel', dx=str(self.width), dy=str(self.height), grid='1', gridSize='10',
                              page='0', pageWidth=str(self.width), pageHeight=str(self.height), background='#ffffff')
        cells = ET.SubElement(model, 'root')
        ET.SubElement(cells, 'mxCell', id='0')
        ET.SubElement(cells, 'mxCell', id='1', parent='0')
        for index, shape in enumerate(sorted(self.shapes, key=lambda value:value['z'])):
            identifier = self.view['id']+'-'+str(index+2)
            kind = shape['kind']
            if kind == 'line':
                style = 'edgeStyle=none;rounded=0;html=0;strokeColor='+COLOR+';strokeWidth=1.5;endArrow='+('classic' if shape['arrow']=='block' else 'open' if shape['arrow']=='open' else 'none')+';'
                if shape['dashed']:
                    style += 'dashed=1;dashPattern=6 5;'
                cell = ET.SubElement(cells, 'mxCell', id=identifier, edge='1', parent='1', style=style)
                geometry = ET.SubElement(cell, 'mxGeometry', relative='1', **{'as':'geometry'})
                first, last = shape['points'][0], shape['points'][-1]
                ET.SubElement(geometry, 'mxPoint', x=str(first[0]), y=str(first[1]), **{'as':'sourcePoint'})
                ET.SubElement(geometry, 'mxPoint', x=str(last[0]), y=str(last[1]), **{'as':'targetPoint'})
                if len(shape['points']) > 2:
                    points = ET.SubElement(geometry, 'Array', **{'as':'points'})
                    for point in shape['points'][1:-1]:
                        ET.SubElement(points, 'mxPoint', x=str(point[0]), y=str(point[1]))
            else:
                if kind == 'text':
                    font_style = (4 if shape['underline'] else 0) + (1 if shape['bold'] else 0)
                    style = f'text;html=0;whiteSpace=wrap;overflow=visible;strokeColor=none;fillColor=none;align={shape["align"]};verticalAlign=top;spacing=0;fontFamily=Tahoma;fontSize={shape["size"]};fontColor=#000000;fontStyle={font_style};'
                    value = '\n'.join(shape['lines'])
                else:
                    style = ('ellipse;' if kind == 'ellipse' else 'rounded=0;')+'html=0;strokeColor='+shape.get('stroke',COLOR)+';strokeWidth=1.5;fillColor='+shape['fill']+';'
                    value = ''
                cell = ET.SubElement(cells, 'mxCell', id=identifier, value=value, vertex='1', parent='1', style=style)
                ET.SubElement(cell, 'mxGeometry', x=str(shape['x']), y=str(shape['y']), width=str(shape['width']), height=str(shape['height']), **{'as':'geometry'})
        return diagram


def walk_items(items):
    for item in items:
        yield item
        for branch in item.get('branches', []):
            yield from walk_items(branch['items'])


def is_implementation_text(text):
    pattern = r'\b(?:API|DTO|JWT|SQL|POST|GET|INSERT|COMMIT|ROLLBACK|BEGIN|UNIQUE|P2002|User|Tenant|Invoice|Lease|Payment|Proof|Ticket|Expense|Room|Prisma|PostgreSQL|ACTIVE|PENDING|CANCELLED|APPROVED|REJECTED|PARTIAL|PAID|UNPAID|ENDED|VACANT|OCCUPIED|DONE|IN_PROGRESS)\b|\b[a-z]+[A-Z][A-Za-z]*\b|[A-Z]+_[A-Z_]+|[A-Za-z]+Service\b|\b(?:me|refresh|role|amount|remaining|deposit|cost|status|transaction|commit|token|catch)\b'
    pattern += r'|[A-Za-z_][A-Za-z0-9_.]*\(|/(?:auth|admin|billing|uploads|leases|tenant|maintenance|properties|invitations)|\b(?:argon2|trim|lowercase|endpoint|multipart|Flutter|NestJS|Firebase)\b'
    pattern += r'|\b[A-Z][a-z]+(?:[A-Z][A-Za-z0-9]+)+\b|[A-Z]+_[A-Z_]*|/[a-z][a-z0-9-]*(?:/|\b)|\b(?:Argon2|hash|active|filename|URL|YYYY)\b'
    return bool(re.search(pattern, text))


def message_implementation(message):
    details = message.get('implementation', '')
    if not is_implementation_text(details):
        details = ''
    conditions = [guard for guard in message.get('implementation_guards', []) if is_implementation_text(guard)]
    if conditions:
        details += (' ' if details else '') + 'Điều kiện triển khai: ' + ' / '.join(conditions) + '.'
    return details


def reference_rows(view):
    rows = []
    for item in walk_items(view['items']):
        if item['type'] == 'ref' and is_implementation_text(item.get('implementation', '')):
            rows.append(('TC'+str(len(rows)+1), 'Tham chiếu', item['label'], item['implementation']))
    for participant in view['participants']:
        original = participant.get('implementation_name', '')
        if participant.get('component_file'):
            rows.append(('TP'+str(len(rows)+1), 'Thành phần', participant['name'], participant['component_file']))
        elif original == 'PostgreSQL':
            rows.append(('TP'+str(len(rows)+1), 'Thành phần', participant['name'], original))
    return rows


def scenario_implementation_rows(scenario):
    rows = []
    for heading, text in [('Dữ liệu đầu vào', scenario.get('implementation_input', '')), ('Kết quả ghi nhận', scenario.get('implementation_post', ''))]:
        if is_implementation_text(text):
            rows.append((heading, text))
    for text in scenario.get('implementation_notes', []):
        if is_implementation_text(text):
            rows.append(('Lưu ý triển khai', text))
    seen_links = set()
    for view in scenario['views']:
        for number, interaction, business, implementation in reference_rows(view):
            key = (business, implementation)
            if key not in seen_links:
                rows.append((interaction + ' ' + business, implementation))
                seen_links.add(key)
    for source in scenario['sources']:
        reference = ('Backend ' if source['root'] == 'api' else 'Flutter ') + source['file'] + ' ' + source['method']
        reference += ' tại dòng ' + str(source['line']) if source['line'] else ' đối chiếu ở mức tệp'
        rows.append(('Căn cứ kiểm chứng', reference))
    return rows


def markdown(figures):
    lines = ['# Các biểu đồ tuần tự của hệ thống quản lý nhà trọ', '',
             '## 1 Mục đích và phạm vi', '',
             'Bộ sơ đồ mô tả 10 kịch bản trọng tâm, liên quan 15 Use Case đã đặc tả, chia thành 22 hình để giữ chữ dễ đọc. Ba actor là Admin, Chủ trọ và Người thuê. Không phải bộ 67 sơ đồ tương ứng toàn bộ 67 Use Case.', '',
             'Phiên bản 1.2, chuẩn hóa tên thành phần và văn phong ngày 7 tháng 10 năm 2026. Căn cứ đối chiếu mã nguồn ngày 6 tháng 10 năm 2026 được giữ nguyên. Nội dung phân tích không thay thế nghiệm thu.', '',
             '## 2 Quy ước biểu diễn', '',
             '- Nhãn trên hình sử dụng ngôn ngữ nghiệp vụ: hành động, dữ liệu trao đổi, kết quả và điều kiện. Đường dẫn API, tên hàm, mã lỗi, biến và trạng thái mã nguồn nằm ở cột chi tiết triển khai khi cần. Tên lớp Controller/Service được giữ trên lifeline; thao tác băm mật khẩu dùng đúng thuật ngữ, còn thuật toán nằm trong bảng.',
             '- Lifeline dùng tên thành phần hoặc đối tượng: Controller/Service giữ đúng tên lớp hiện có; giao diện, actor và kho dữ liệu dùng danh từ tiếng Việt. Tệp định nghĩa thành phần được đối chiếu trong bảng, không tạo thêm lớp hoặc lifeline.',
             '- Màu vàng nhạt #FFFFB9, viền đỏ nâu #800000, chữ Tahoma trên nền trắng; mô phỏng phong cách StarUML cổ điển, không phải dự án .mdj.',
             '- Không có khung bao ngoài hoặc tab sd. Chỉ giữ các khung alt, opt, loop, break và ref; đây là ký hiệu UML, không phải tên hàm trong mã nguồn.',
             '- alt chọn một nhánh; opt chạy khi điều kiện đúng; loop lặp theo dữ liệu; break kết thúc tương tác khi điều kiện lỗi đúng; ref dẫn tới đoạn được phân rã.',
             '- Đường liền biểu diễn lời gọi, nét đứt biểu diễn phản hồi. Thanh vàng mảnh biểu diễn thời gian thực thi ở mức khái quát.',
             '- Actor dùng hình người; boundary cho giao diện và Controller; control cho Service; cylinder cho kho dữ liệu. Không thêm Entity chỉ để đủ ký hiệu.',
             '- Số thông điệp bắt đầu từ 1 trong mỗi hình. Các nhánh alt không chạy lần lượt trong cùng một yêu cầu.',
             '- Hai hình nối bằng ref có thể là hai đoạn của cùng một lần ghi nhận. Các thao tác xác nhận hoặc hủy thay đổi biểu diễn tính thống nhất của dữ liệu, không phải câu lệnh SQL trên hình.', '',
             '## 3 Điều kiện và ngoại lệ dùng chung', '',
             'Hệ thống kiểm tra phiên đăng nhập, tình trạng sử dụng tài khoản, vai trò, quyền thao tác và dữ liệu đầu vào trước khi xử lý nghiệp vụ. Nếu biểu mẫu sai thì chưa gửi yêu cầu. Nếu không đủ quyền hoặc điều kiện thì không đi tiếp nhánh thành công.', '',
             'Nếu chưa lưu thành công, lỗi xử lý hủy các thay đổi trong lần ghi nhận. Lỗi sau khi lưu hoặc mất phản hồi không chứng minh dữ liệu đã bị hủy; cần tra cứu trước khi gửi lại. Ghi nhật ký không làm hủy kết quả nghiệp vụ đã lưu thành công.', '',
             '## 4 Danh mục sơ đồ', '', '| Kịch bản | Nội dung | Use Case | Hình |', '| --- | --- | --- | --- |']
    for scenario in MODEL['scenarios']:
        lines.append('| '+scenario['id']+' | '+scenario['title']+' | '+', '.join(scenario['ucs'])+' | '+', '.join(view['id'] for view in scenario['views'])+' |')
    for scenario in MODEL['scenarios']:
        lines += ['', '## '+scenario['id']+' '+scenario['title'], '',
                  '**Điều kiện trước:** '+scenario['pre'], '', '**Dữ liệu đầu vào:** '+scenario['input'], '',
                  '**Điều kiện sau khi thành công:** '+scenario['post'], '',
                  '**Khi bị từ chối:** Không đi tiếp nhánh thành công. Nếu kết quả đã được lưu nhưng mất phản hồi thì cần kiểm tra lại trước khi thực hiện lại.', '',
                  '### Lưu ý nghiệp vụ', '']
        lines += ['- '+note for note in scenario['notes']]
        for view in scenario['views']:
            figure = figures[view['id']]
            lines += ['', '### '+view['id']+' '+view['title'], '',
                      '!['+view['id']+' '+view['title']+'](sequence-diagrams/full/'+view['file']+'.png)', '',
                      '[SVG vector](sequence-diagrams/full/'+view['file']+'.svg) · [Nguồn draw.io](sequence-diagrams/full/'+view['file']+'.drawio)', '',
                      '| Bước | Bên gửi → Bên nhận | Điều kiện nhánh | Diễn giải nghiệp vụ | Chi tiết triển khai khi cần |',
                      '| --- | --- | --- | --- | --- |']
            for message in figure.messages:
                people = view['participants']
                values = [str(message['number']), people[message['from']]['name']+' → '+people[message['to']]['name'],
                          ' / '.join(message['guards']) or 'Luồng chung', message.get('business_detail', message['label']),
                          message_implementation(message) or 'Không cần bổ sung']
                lines.append('| '+' | '.join(value.replace('|','/').replace('\n',' ') for value in values)+' |')

        lines += ['', '### Đối chiếu đặc tả Use Case', '']
        for spec in scenario['ucSpecs']:
            lines += ['**'+spec['id']+'**', '', '| Thuộc tính | Đặc tả |', '| --- | --- |']
            for line in spec['text'].splitlines():
                if '**Luồng chính**' in line or '**Luồng thay thế**' in line or '**Luồng ngoại lệ**' in line:
                    lines.append(line)
            lines.append('')
        lines += ['### Liên hệ triển khai và căn cứ kiểm chứng', '', '| Nội dung | Chi tiết |', '| --- | --- |']
        for heading, text in scenario_implementation_rows(scenario):
            lines.append('| '+heading+' | '+text.replace('|','/').replace('\n',' ')+' |')
    lines += ['', '## 5 Bàn giao và chỉnh sửa', '',
              '- SEQUENCE_DIAGRAM_SPECIFICATION.docx là bản Word độc lập, có hình và bảng thông điệp chi tiết; không ghi đè báo cáo Word tổng.',
              '- sequence-diagrams/full/SEQUENCE_DIAGRAMS.drawio có 22 trang chỉnh sửa được; các ký hiệu và chữ là đối tượng riêng, không phải ảnh PNG nhúng.',
              '- model.json tách nhãn nghiệp vụ với thông tin triển khai. build.py tạo hình và Markdown; build_document.py tạo Word; manifest.json và validation.json ghi kết quả kiểm tra.',
              '- Mục 2.4.4 của PROPOSAL_QUAN_LY_TRO.md dùng cùng hình và nội dung nghiệp vụ; chi tiết kỹ thuật tra cứu ở các bảng trong đặc tả độc lập.',
              '- Trong bộ chính thức, SD-01 là đăng nhập và SD-04 là tạo hợp đồng. Bộ demo cũ ở thư mục cha chỉ là lịch sử duyệt form.', '']
    return '\n'.join(lines)


def make_figures():
    figures = {}
    aggregate = ET.Element('mxfile', host='app.diagrams.net', version='26.0.0', type='device')
    manifest = []
    for scenario in MODEL['scenarios']:
        for view in scenario['views']:
            figure = Figure(view)
            figures[view['id']] = figure
            (BASE / (view['file']+'.svg')).write_text(figure.svg(), encoding='utf8')
            native = ET.Element('mxfile', host='app.diagrams.net', type='device')
            native.append(figure.mxgraph())
            ET.ElementTree(native).write(BASE / (view['file']+'.drawio'), encoding='utf-8', xml_declaration=True)
            aggregate.append(figure.mxgraph())
            manifest.append(dict(id=view['id'], scenario=scenario['id'], file=view['file'], width=figure.width,
                                 height=figure.height, messages=len(figure.messages), fragments=figure.fragments))
    ET.ElementTree(aggregate).write(BASE / 'SEQUENCE_DIAGRAMS.drawio', encoding='utf-8', xml_declaration=True)
    sharp_script = "const fs=require('fs');const sharp=require(process.argv[1]);const base=process.argv[2];const files=fs.readdirSync(base).filter(name=>name.endsWith('.svg'));Promise.all(files.map(name=>sharp(base+'/'+name,{density:144}).flatten({background:'#ffffff'}).toColourspace('srgb').removeAlpha().png().toFile(base+'/'+name.replace('.svg','.png')))).catch(error=>{console.error(error);process.exitCode=1;});"
    subprocess.run(['/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node', '-e', sharp_script,
                    '/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp', str(BASE)], check=True)
    for entry in manifest:
        entry['sha256'] = {extension:hashlib.sha256((BASE / (entry['file']+'.'+extension)).read_bytes()).hexdigest() for extension in ['svg','png','drawio']}
    (BASE / 'manifest.json').write_text(json.dumps(dict(scenarios=10, figures=len(manifest), diagrams=manifest), indent=2, ensure_ascii=False)+'\n')
    (ROOT / 'docs/ba/SEQUENCE_DIAGRAM_SPECIFICATION.md').write_text(markdown(figures), encoding='utf8')
    sheet = Image.new('RGB', (1200, math.ceil(len(manifest)/3)*310), 'white')
    drawing = ImageDraw.Draw(sheet)
    label_font = ImageFont.truetype(FONT_PATH, 18)
    for index, entry in enumerate(manifest):
        image = Image.open(BASE / (entry['file']+'.png'))
        image.thumbnail((380, 275))
        horizontal = (index % 3)*400+(400-image.width)//2
        vertical = (index // 3)*310+30
        sheet.paste(image, (horizontal, vertical))
        drawing.text(((index % 3)*400+12, (index // 3)*310+5), entry['id'], font=label_font, fill='black')
    sheet.save(BASE / 'contact-sheet.png')
    return figures


if __name__ == '__main__':
    make_figures()
    print('Generated 10 scenarios and 22 SVG PNG drawio figures with detailed Markdown')
