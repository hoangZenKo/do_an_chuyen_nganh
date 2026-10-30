from pathlib import Path
import json
import re
import subprocess
import os
import textwrap

from business_language import business_text

ROOT = Path('/Users/hoang/Rental_room_management')
OUT = ROOT / 'BA_Documentation/07_Report_Completion'
SOURCE = ROOT / 'BA_Documentation/05_Use_Case_Diagrams'
CONTENT = json.loads((OUT / 'data/business-report-content.json').read_text())
CASES = {item['id']: item for item in CONTENT['useCases']}
MANIFEST = json.loads((SOURCE / 'data/diagram-manifest.json').read_text())
TITLES = {
    'UC_G01_01_SYS_Public': 'G01 Đăng ký và tiếp nhận lời mời',
    'UC_G01_02_SYS_Sessions': 'G01 Đăng nhập và bảo vệ tài khoản',
    'UC_G06_01_Tenant_Records': 'G06 Hồ sơ người thuê và quyền truy cập',
    'UC_G06_02_Leases_Deposits': 'G06 Hợp đồng và tiền cọc',
    'UC_G08_01_Invoices': 'G08 Chỉ số và hóa đơn',
    'UC_G08_02_Collections': 'G08 Thu tiền và thanh toán',
    'UC_G08_03_Tariffs_Periods': 'G08 Biểu phí và kỳ thanh toán',
    'UC_G08_04_Reminders': 'G08 Chính sách và thông báo nhắc nợ',
}

def main():
    target = OUT / 'diagrams'
    target.mkdir(exist_ok=True)
    selected = []
    entries = []
    for entry in MANIFEST['diagrams']:
        if entry['kind'] not in ['overall', 'module']:
            continue
        entry = {**entry, 'title': TITLES.get(entry['id'], entry['title'])}
        if entry['kind'] == 'module' and len(entry['ucIds']) > 8:
            midpoint = (len(entry['ucIds']) + 1) // 2
            for index, identifiers in enumerate([entry['ucIds'][:midpoint], entry['ucIds'][midpoint:]], 1):
                entries.append({**entry, 'id': entry['id'] + '_BA_' + str(index), 'sourceFile': entry['file'], 'file': entry['file'].replace('.puml', '_BA_' + str(index) + '.puml'), 'ucIds': identifiers, 'title': entry['title'] + ' phần ' + str(index)})
        else:
            entries.append(entry)
    for entry in entries:
        text = (SOURCE / entry.get('sourceFile', entry['file'])).read_text()
        if 'sourceFile' in entry:
            keep = {identifier.replace('-', '_').replace('.', '_') for identifier in entry['ucIds']}
            text = '\n'.join(line for line in text.splitlines() if not (line.strip().startswith('usecase ') and re.search(r'as (\w+)', line).group(1) not in keep) and not (re.match(r'^(?:[AE]\d+|UC_\w+)\s+', line) and not set(re.findall(r'\bUC_\w+\b',line)).issubset(keep)))
            text = re.sub(r'(?m)^title .*$', 'title ' + entry['title'].replace(' · ', ' '), text)
            used = set()
            for line in text.splitlines():
                if re.match(r'^(?:[AE]\d+|UC_\w+)\s+',line):
                    used.update(re.findall(r'\b[AE]\d+\b',line))
            text = re.sub(r'(?m)^actor .* as ([AE]\d+)$', lambda match: match.group(0) if match.group(1) in used else '', text)
        text = re.sub(r'^caption .*$', '', text, flags=re.M)
        text = re.sub(r'legend bottom left.*?endlegend', '''legend bottom left
  Đường liền: tác nhân tham gia mục tiêu nghiệp vụ.
  Đường xanh có nhãn: chỉ tham gia trong phạm vi giới hạn được nêu.
  Nhân viên cần quyền phù hợp và khu được giao; quản trị viên cần đúng thẩm quyền.
  Vàng: đáp ứng một phần. Cam: thanh toán thử nghiệm. Xám: trao đổi mô phỏng.
  Không thể hiện thứ tự thực hiện; không suy ra quyền từ vị trí tác nhân.
endlegend''', text, flags=re.S)
        def uc_label(match):
            identifier = match.group(1)
            label = '\\n'.join(textwrap.wrap(CASES[identifier]['title'], 32))
            return 'usecase "' + identifier + '\\n' + label + '" as '
        text = re.sub(r'usecase "(UC-[A-Z]+-\d+(?:\.\d+)*).*?" as ', uc_label, text)
        text = text.replace('Khách/chưa đăng nhập', 'Khách vãng lai')
        text = text.replace('Người tìm phòng/người\\nthuê', 'Người tìm phòng\\nhoặc người thuê')
        text = text.replace('MFA', 'xác thực nhiều yếu tố')
        text = text.replace('Dịch vụ giao link/thông báo', 'Đơn vị gửi thư hoặc thông báo')
        text = text.replace('Dịch vụ giao liên\\nkết/thông báo bên ngoài', 'Đơn vị gửi thư\\nhoặc thông báo')
        text = text.replace('Dịch vụ mô hình AI', 'Dịch vụ trợ lý thông minh')
        text = text.replace('nếu cấu hình/bật', 'khi sử dụng kênh này')
        labels = {
            'chỉ ngữ cảnh ownerId của mình': 'chỉ xem thông tin liên quan đến mình',
            'checkout: token DEMO hợp lệ': 'chỉ mở liên kết thanh toán thử nghiệm còn hiệu lực',
            'chỉ đọc nhân viên/preset': 'chỉ xem nhân viên và bộ quyền mẫu',
        }
        for before, after in labels.items():
            text = text.replace(before, after)
        text = re.sub(r'(?m)^(.* : )(.*)$', lambda match: match.group(1) + business_text(match.group(2)), text)
        (target / entry['file']).write_text(text)
        result = {key: entry[key] for key in ['id', 'file', 'kind', 'groupId', 'title', 'ucIds', 'actorIds']}
        result['actorIds'] = re.findall(r'^actor .* as ([AE]\d+)$', text, re.M)
        selected.append(result)
    (OUT / 'data/report-diagrams.json').write_text(json.dumps(selected, ensure_ascii=False, indent=2))
    environment = dict(os.environ, GRAPHVIZ_DOT='/tmp/ba-stage3-tooling/dot')
    command = ['/opt/homebrew/opt/openjdk@17/bin/java', '-Djava.awt.headless=true', '-DPLANTUML_LIMIT_SIZE=16000', '-jar', '/tmp/ba-stage3-tooling/plantuml-1.2026.9.jar', '-charset', 'UTF-8', '-tpng']
    subprocess.run(command + [str(target / item['file']) for item in selected], check=True, env=environment)
    retained = {item['file'] for item in selected} | {item['file'].replace('.puml','.png') for item in selected}
    for artifact in target.iterdir():
        if artifact.suffix in ['.puml','.png'] and artifact.name not in retained:
            artifact.unlink()
    print(f'Rendered {len(selected)} report diagrams')

if __name__ == '__main__':
    main()
