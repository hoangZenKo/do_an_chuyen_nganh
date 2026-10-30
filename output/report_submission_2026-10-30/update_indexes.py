import json
import re
import sys
import unicodedata
from pathlib import Path
from zipfile import ZipFile

from lxml import etree
from pypdf import PdfReader

BASE = Path(sys.argv[2]).parent if len(sys.argv) > 2 else Path('/Users/hoang/Rental_room_management/output/report_submission_2026-10-30')
OUTPUT = Path(sys.argv[2]) if len(sys.argv) > 2 else BASE / 'Report_final_BA_Da_chinh_form_2026-10-30.docx'
PDF = Path(sys.argv[1])
NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'


def normalize(text):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', text)).strip()


def roman(number):
    result = ''
    for value, token in [(100, 'c'), (90, 'xc'), (50, 'l'), (40, 'xl'), (10, 'x'), (9, 'ix'), (5, 'v'), (4, 'iv'), (1, 'i')]:
        while number >= value:
            result += token
            number -= value
    return result


manifest = json.loads((BASE / 'manifest.json').read_text())
reader = PdfReader(PDF)
texts = [normalize(page.extract_text()) for page in reader.pages]
main = next(index for index, text in enumerate(texts) if '1 Giới thiệu 1.1 Đặt vấn đề Quản lý nhà trọ' in text)
assignment = next(index for index, text in enumerate(texts[:main]) if 'Phân công thực hiện đồ án Người thực hiện Phạm vi công việc' in text)
page_map = {}
for entry in manifest['toc'] + manifest['figures']:
    title = normalize(entry['title'])
    if title == 'Phân công thực hiện đồ án':
        index = assignment
    else:
        matches = [index for index in range(main, len(texts)) if title in texts[index]]
        if not matches:
            raise ValueError('Missing printed heading or figure: ' + title)
        index = matches[0]
    entry['physical_page'] = index + 1
    entry['page'] = str(index - main + 1) if index >= main else roman(index)
    page_map[entry['anchor']] = entry['page']

with ZipFile(OUTPUT) as package:
    members = {info.filename: (info, package.read(info.filename)) for info in package.infolist()}
document = etree.fromstring(members['word/document.xml'][1])
count = 0
for paragraph in document.xpath('//w:body/w:p', namespaces=NS):
    links = paragraph.xpath('w:hyperlink/@w:anchor', namespaces=NS)
    if links and links[0] in page_map:
        texts_in_paragraph = paragraph.xpath('w:r/w:t', namespaces=NS)
        assert texts_in_paragraph
        texts_in_paragraph[-1].text = page_map[links[0]]
        count += 1
assert count == len(page_map), (count, len(page_map))
members['word/document.xml'] = (members['word/document.xml'][0], etree.tostring(document, xml_declaration=True, encoding='UTF-8', standalone=True))
if 'docProps/app.xml' in members:
    app = etree.fromstring(members['docProps/app.xml'][1])
    pages = app.find('{http://schemas.openxmlformats.org/officeDocument/2006/extended-properties}Pages')
    if pages is not None:
        pages.text = str(len(reader.pages))
    members['docProps/app.xml'] = (members['docProps/app.xml'][0], etree.tostring(app, xml_declaration=True, encoding='UTF-8', standalone=True))
temporary = OUTPUT.with_suffix('.tmp.docx')
with ZipFile(temporary, 'w') as package:
    for name, (info, data) in members.items():
        package.writestr(info, data)
temporary.replace(OUTPUT)
manifest['pages'] = len(reader.pages)
manifest['main_starts_at_physical_page'] = main + 1
(BASE / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print(json.dumps({'pages': len(reader.pages), 'main_starts_at': main + 1, 'updated_index_entries': count}, indent=2))
