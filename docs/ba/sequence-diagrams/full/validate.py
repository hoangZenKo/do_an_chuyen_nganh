import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from PIL import Image, ImageFont
from build import BASE, ROOT, MODEL, Figure, FONT_PATH, is_implementation_text, message_implementation


def walk(items):
    for item in items:
        yield item
        for branch in item.get('branches', []):
            yield from walk(branch['items'])


def validate():
    assert len(MODEL['scenarios']) == 10
    views = [view for scenario in MODEL['scenarios'] for view in scenario['views']]
    assert len(views) == 22
    assert len({view['id'] for view in views}) == 22
    assert len({use_case for scenario in MODEL['scenarios'] for use_case in scenario['ucs']}) == 15
    manifest = json.loads((BASE / 'manifest.json').read_text())
    assert manifest['figures'] == 22
    assert MODEL['version'] == '1.2'
    assert MODEL['languagePolicy']
    business_labels = 0
    technical_rows = 0
    component_lifelines = 0
    entries = {entry['id']: entry for entry in manifest['diagrams']}
    aggregate = ET.parse(BASE / 'SEQUENCE_DIAGRAMS.drawio').getroot()
    assert len(aggregate.findall('diagram')) == 22
    specification = (ROOT / 'docs/ba/SEQUENCE_DIAGRAM_SPECIFICATION.md').read_text()
    proposal = (ROOT / 'PROPOSAL_QUAN_LY_TRO.md').read_text()
    fragment_counts = {}
    total_messages = 0
    total_cells = 0
    for view in views:
        labels_on_image = [view['title']]
        for participant in view['participants']:
            assert not participant['name'].startswith(('Tiếp nhận ', 'Xử lý '))
            if participant.get('component_class'):
                assert participant['name'] == participant['component_class']
                assert participant['name'].endswith(('Controller', 'Service'))
                expected_kind = 'boundary' if participant['name'].endswith('Controller') else 'control'
                assert participant['kind'] == expected_kind
                source = ROOT / 'backend' / participant['component_file']
                assert re.search(r'export class\s+' + re.escape(participant['name']) + r'\b', source.read_text())
                component_lifelines += 1
            else:
                labels_on_image.append(participant['name'])
        for item in walk(view['items']):
            if item['type'] in ['message', 'ref']:
                labels_on_image.append(item['label'])
            for branch in item.get('branches', []):
                labels_on_image.append(branch['guard'])
        assert not any(is_implementation_text(label) for label in labels_on_image), view['id']
        assert not any("cổng" in label.lower() or "Bảo vệ mật khẩu" in label for label in labels_on_image), view['id']
        business_labels += len(labels_on_image)
        figure = Figure(view)
        for message in figure.messages:
            if message_implementation(message):
                technical_rows += 1
                assert message.get('business_detail')
        total_messages += len(figure.messages)
        assert [message['number'] for message in figure.messages] == list(range(1,len(figure.messages)+1))
        entry = entries[view['id']]
        assert entry['messages'] == len(figure.messages)
        assert entry['width'] == figure.width and entry['height'] == figure.height
        for item in walk(view['items']):
            if item['type'] == 'message':
                assert 0 <= item['from'] < len(view['participants'])
                assert 0 <= item['to'] < len(view['participants'])
            elif item['type'] == 'fragment':
                fragment_counts[item['kind']] = fragment_counts.get(item['kind'],0)+1
                assert all(branch['guard'] and branch['items'] for branch in item['branches'])
                if item['kind'] == 'alt':
                    assert len(item['branches']) >= 2
            elif item['type'] == 'ref':
                for target in re.findall(r'SD-\d{2}[A-Z]',item['label']):
                    assert target in entries, target
        for shape in figure.shapes:
            if shape['kind'] in ['rect','ellipse','text']:
                assert 0 <= shape['x'] <= figure.width
                assert shape['x']+shape['width'] <= figure.width
                assert 0 <= shape['y'] <= figure.height
                assert shape['y']+shape['height'] <= figure.height
            if shape['kind'] == 'text':
                font = ImageFont.truetype(FONT_PATH,shape['size'])
                for line in shape['lines']:
                    assert font.getlength(line) <= shape['width']-8, (view['id'],line)
        for extension in ['svg','drawio','png']:
            file = BASE / (view['file']+'.'+extension)
            assert file.is_file() and file.stat().st_size > 0
            assert hashlib.sha256(file.read_bytes()).hexdigest() == entry['sha256'][extension]
        with Image.open(BASE/(view['file']+'.png')) as image:
            assert image.mode == 'RGB'
            assert image.width == figure.width*2 and image.height == figure.height*2
        vector = ET.parse(BASE/(view['file']+'.svg')).getroot()
        assert not any(element.tag.split('}')[-1] in ['foreignObject','image'] for element in vector.iter())
        labels = [element.text or '' for element in vector.iter() if element.tag.endswith('text')]
        assert len([label for label in labels if re.match(r'^\d+:',label)]) == len(figure.messages)
        native = ET.parse(BASE/(view['file']+'.drawio')).getroot()
        for root in native.findall('.//root'):
            cells = root.findall('mxCell')
            total_cells += len(cells)
            assert len({cell.get('id') for cell in cells}) == len(cells)
            assert not any('image' in cell.get('style','').lower() for cell in cells)
            assert not any(cell.get('id') in ['sd-frame','sd-frame-label'] for cell in cells)
        assert view['file']+'.png' in specification and view['file']+'.png' in proposal
    for scenario in MODEL['scenarios']:
        for source in scenario['sources']:
            origin = ROOT / 'backend' if source['root']=='api' else ROOT
            text = (origin/source['file']).read_text()
            if source['line']:
                assert source['method'].replace('async ','') in text.splitlines()[source['line']-1]
    document_file = ROOT/'docs/ba/SEQUENCE_DIAGRAM_SPECIFICATION.docx'
    with zipfile.ZipFile(document_file) as archive:
        document = ET.fromstring(archive.read('word/document.xml'))
        namespaces = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main','wp':'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'}
        assert len(document.findall('.//wp:inline',namespaces)) == 22
        word_tables = len(document.findall('.//w:tbl',namespaces))
        assert word_tables == 34
        word_text = '\n'.join(node.text or '' for node in document.findall('.//w:t',namespaces))
        assert all(view['id'] in word_text for view in views)
        assert 'Clipboard.setData' in word_text
        assert 'Băm mật khẩu mới' in word_text
        assert 'Điều hướng đến giao diện người thuê' in word_text
        assert 'Hiển thị giao diện người thuê' in word_text
        assert all(participant['name'] in word_text for view in views for participant in view['participants'] if participant.get('component_class'))
        for identifier in ['POST /auth/login', 'ACTIVE', 'P2002', 'recordSafe', 'ROLLBACK']:
            assert identifier in word_text, identifier
        assert 'Diễn giải nghiệp vụ' in word_text and 'Chi tiết triển khai khi cần' in word_text
        assert 'API lược tiền tố' not in word_text
        assert all(source['file'] in word_text for scenario in MODEL['scenarios'] for source in scenario['sources'])
    assert component_lifelines == 43
    assert total_messages == 315
    assert fragment_counts == {'alt': 36, 'opt': 4, 'loop': 3, 'break': 5}
    report = {'result':'PASS','scenarios':10,'useCases':15,'figures':22,'messages':total_messages,'drawioCells':total_cells,'fragments':fragment_counts,'wordFigures':22,'wordTables':word_tables,'businessLabelsChecked':business_labels,'implementationMessageRows':technical_rows,'componentLifelinesVerified':component_lifelines,'onImageImplementationDetails':0,'geometryOverflows':0}
    (BASE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))


if __name__ == '__main__':
    validate()
