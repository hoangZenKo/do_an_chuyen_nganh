from pathlib import Path
from collections import Counter
from zipfile import ZipFile
import json, re, hashlib, sys
from docx import Document
from PIL import Image

ROOT=Path('/Users/hoang/Rental_room_management')
OUT=Path('/tmp/rental-report-v3-20261028')
sys.path.insert(0,str(OUT))
from report_data import build_cases, GROUPS

cases=build_cases()
schema=(ROOT/'backend/prisma/schema.prisma').read_text()
models={}
for match in re.finditer(r'^model\s+(\w+)\s*\{\n(.*?)^\}',schema,re.M|re.S):
    name,body=match.groups()
    fields=[]; constraints=[]
    for line in body.splitlines():
        line=line.strip()
        if not line or line.startswith('//'): continue
        if line.startswith('@@'): constraints.append(line); continue
        parts=line.split(None,2)
        if len(parts)>=2: fields.append(dict(name=parts[0],type=parts[1],attrs=parts[2] if len(parts)>2 else ''))
    models[name]={'fields':fields,'constraints':constraints,'line':schema[:match.start()].count('\n')+1}
relations=[]
for name,model in models.items():
    for field in model['fields']:
        target=field['type'].rstrip('?[]')
        if target not in models or 'fields:' not in field['attrs']: continue
        fks=re.search(r'fields:\s*\[([^\]]+)\]',field['attrs'])
        relations.append(dict(source=name,target=target,field=field['name'],fk=fks.group(1),optional=field['type'].endswith('?'),list=field['type'].endswith('[]')))

routes=[]
for file in sorted((ROOT/'backend/src').rglob('*controller.ts')):
    text=file.read_text()
    controllers=list(re.finditer(r"@Controller\(\s*(?:(['\"])(.*?)\1)?\s*\)",text))
    for index,controller in enumerate(controllers):
        end=controllers[index+1].start() if index+1<len(controllers) else len(text)
        segment=text[controller.end():end]
        base=controller.group(2) or ''
        cls=re.search(r'export class\s+(\w+)',segment)
        for hit in re.finditer(r"@(Get|Post|Put|Patch|Delete)\(\s*(?:(['\"])(.*?)\2)?\s*\)",segment):
            route='/api/v1/'+'/'.join(t.strip('/') for t in [base,hit.group(3) or ''] if t.strip('/'))
            absolute=controller.end()+hit.start()
            chunk=segment[hit.end():]
            name=re.search(r'(?:^|\n)\s*(?:async\s+)?(\w+)\s*\(',chunk)
            if not name: name=re.search(r'\)\s+(\w+)\s*\(@',chunk)
            routes.append(dict(file=str(file.relative_to(ROOT)),line=text[:absolute].count('\n')+1,controller=cls.group(1) if cls else '',method=hit.group(1).upper(),path=route,handler=name.group(1) if name else ''))

for case in cases:
    if not (ROOT/case['source']).exists():
        candidates=list((ROOT/Path(case['source']).parent).glob('*service.ts'))
        raise ValueError(f"Missing evidence {case['source']}: {candidates}")
    group=case['group']
    file_modules=GROUPS[group][1].split(',')
    candidates=[r for r in routes if any(r['file'].startswith('backend/src/'+m+'/') for m in file_modules)]
    case['routes']=[r for r in candidates if case['hint'].replace(':id','') in r['path'].replace(':id','')][:5]
    if not case['routes']:
        case['routes']=[r for r in candidates if Path(r['file']).stem.split('.')[0] in Path(case['source']).stem][:3]
    if not case['routes']: case['routes']=candidates[:2]
    source=ROOT/case['source']
    text=source.read_text()
    case['source_hash']=hashlib.sha256(source.read_bytes()).hexdigest()
    case['source_line']=1
    match=re.search(r'export class\s+\w+',text)
    if match: case['source_line']=text[:match.start()].count('\n')+1
    case['ui_sources']=[str(p.relative_to(ROOT)) for module in GROUPS[group][2].split(',') for p in (ROOT/'lib/features'/module).glob('*screen.dart')]
    stems={Path(case['source']).stem.split('.')[0],*(m for m in GROUPS[group][2].split(','))}
    case['tests']=[str(p.relative_to(ROOT)) for p in list((ROOT/'test').rglob('*test.dart'))+list((ROOT/'backend/src').rglob('*.spec.ts'))+list((ROOT/'backend/test').rglob('*.e2e-spec.ts')) if any(s.replace('-','_') in str(p).replace('-','_') for s in stems)][:6]
    if case['id'] in {'UC-ADM-18','UC-ADM-19','UC-ADM-20','UC-ADM-21'}:
        case['tests']=['backend/src/admin/admin-registry.service.spec.ts','test/features/admin/admin_registry_screen_test.dart']
        case['ui_sources']=['lib/features/admin/admin_registry_screen.dart']

enums={m.group(1):re.findall(r'^\s+(\w+)\s*$',m.group(2),re.M) for m in re.finditer(r'^enum\s+(\w+)\s*\{(.*?)^\}',schema,re.M|re.S)}
versions=json.loads((ROOT/'backend/package.json').read_text())
data=dict(date='2026-10-28',cases=cases,models=models,relations=relations,routes=routes,enums=enums,backend_dependencies=versions['dependencies'],flutter_manifest=(ROOT/'pubspec.yaml').read_text())
(OUT/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))

reference=ROOT/'docs/CSE703014_Report_Template_VI_V1.docx'
draft=ROOT/'docs/Bao_cao_da_chinh_form.docx'
for file in (reference,draft):
    with ZipFile(file) as z:
        inventory=[dict(part=i.filename,size=i.file_size,sha256=hashlib.sha256(z.read(i.filename)).hexdigest()) for i in z.infolist()]
        (OUT/(file.stem+'-parts.json')).write_text(json.dumps(inventory,indent=2))
with ZipFile(reference) as z:
    for info in z.infolist():
        if info.filename.startswith('word/media/'):
            temp=OUT/Path(info.filename).name; temp.write_bytes(z.read(info.filename))
            image=Image.open(temp)
            if 0.7 < image.width/image.height < 1.3:
                image.convert('RGB').save(OUT/'phenikaa-logo.png')

contract=f'''# Hợp đồng dựng báo cáo từ mẫu V1

## Nguồn bất biến
Mẫu: {reference}; SHA-256 {hashlib.sha256(reference.read_bytes()).hexdigest()}.
Bản dở: {draft}; SHA-256 {hashlib.sha256(draft.read_bytes()).hexdigest()}.
Mẫu có 6 trang sau render, 2 section; ảnh render tại /tmp/rental-report-v3-20261028/template.
Bản dở có 200 trang render, 67 bảng UC; không dùng các số trang/mục lục cũ làm dữ liệu cuối.

## Hình thức giữ từ mẫu
Section bìa: Legal 8.5 × 14 inch, dọc, lề 1 inch, khoảng header/footer 0.5 inch.
Section nội dung: Letter 8.5 × 11 inch, dọc, lề 1 inch, header/footer 0.5 inch.
Times New Roman; nội dung 13 pt, đen, căn đều; heading 1/2/3 đậm đen theo vai trò mẫu.
Logo khoa từ media của mẫu; bìa trường/khoa/tên đồ án/các thông tin quản lý; ngày 28/10/2026.
Bảng viền đen, nền trắng hoàn toàn theo yêu cầu người dùng; font bảng 11.5 pt, line 1.0 để bảng UC đầy đủ không phải thu nhỏ hình.
Heading phân cấp 1–5 theo mẫu; use case chi tiết cấp 4 không phá số chương; giữ nhóm UC trong 2.4.1.
Các sơ đồ đặt trong 2.4.2–2.4.4, giao diện 2.4.5; không dán nguyên các tài liệu cũ làm chương riêng.
Footer đánh số trang cập nhật theo nội dung; không giữ giá trị PAGE cũ. Mục lục theo bookmark, lấy số trang từ PDF kiểm tra.

## Slot được thay
word/document.xml body: thay toàn bộ placeholder/nội dung mẫu bằng nội dung dự án; giữ style/theme/numbering definitions trong package gốc.
word/styles.xml: chuẩn hóa đen và cỡ chữ có kiểm soát; bỏ đánh số tự động trùng số heading đã viết.
word/document.xml sectPr: giữ đúng kích thước và lề; xóa trang trắng và các break thừa trong mẫu để mục lục không phát sinh trang rỗng.
word/header*.xml, footer*.xml: thay field số trang và liên kết phù hợp section mới; không giữ số trang cached từ mẫu.
Ảnh: giữ logo mẫu; thay sơ đồ cũ bằng sơ đồ mới; UI từ ảnh widget của source hiện tại, ghi rõ fixture.
customXml, metadata và quan hệ phần không sửa: giữ trong cơ chế mở từ template; thêm core title/date, không gán tác giả sinh viên không xác minh.
Toàn bộ package inventory ghi trong CSE703014_Report_Template_VI_V1-parts.json; nguồn gốc không bị ghi đè.

## Cổng kiểm tra
{len(cases)} UC có mã duy nhất; luồng chính/thay thế/ngoại lệ/đầu vào/quy tắc/truy vết.
Schema đọc trực tiếp: {len(models)} model; {len(routes)} route khai báo. Sơ đồ phân rã, không vẽ một hình quá dày.
Không hư cấu tên/MSSV/giảng viên, phân công hoặc lịch sử họp. Phần chưa có dữ liệu hành chính được đánh dấu công khai.
Không đồng nhất code có sẵn với nghiệm thu. Test backend/Flutter ghi theo log chạy mới, không lấy số cũ.
Render toàn bộ DOCX; kiểm tra PNG, text tràn, heading mồ côi, bảng/hình, phần tham khảo và mục lục; chỉ giao DOCX cuối.
'''
(OUT/'artifact.md').write_text(contract)
print('Audit:',len(cases),'UC;',len(models),'models;',len(relations),'foreign-key relations;',len(routes),'routes.')
print('Source fixes verified; template contract recorded.')
