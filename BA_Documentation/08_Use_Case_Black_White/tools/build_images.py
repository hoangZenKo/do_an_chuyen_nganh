import csv
import hashlib
import html
import json
import math
import re
import shutil
import zipfile
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'BA_Documentation/08_Use_Case_Black_White'
SOURCE = ROOT / 'BA_Documentation/07_Report_Completion'
STANDARD = ROOT / 'BA_Documentation/05_Use_Case_Diagrams/data/diagram-manifest.json'
FONT_ROOT = Path('/System/Library/Fonts/Supplemental')
SCALE = 2
WIDTH = 1920


def font(size, bold=False):
    return ImageFont.truetype(str(FONT_ROOT / ('Arial Bold.ttf' if bold else 'Arial.ttf')), round(size * SCALE))


def wrap(text, width, size=25, bold=False):
    face = font(size, bold)
    lines = []
    line = ''
    for word in text.split():
        candidate = (line + ' ' + word).strip()
        if line and face.getlength(candidate) > width * SCALE:
            lines.append(line)
            line = word
        else:
            line = candidate
    if line:
        lines.append(line)
    return lines


class Canvas:
    def __init__(self, height, width=WIDTH):
        self.height = height
        self.image = Image.new('L', (width * SCALE, height * SCALE), 255)
        self.draw = ImageDraw.Draw(self.image)
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="white"/>']
        self.text_boxes = []
        self.association_segments = []

    def line(self, points, thickness=2.5):
        coordinates = [(round(x * SCALE), round(y * SCALE)) for x, y in points]
        self.draw.line(coordinates, fill=0, width=round(thickness * SCALE), joint='curve')
        values = ' '.join(f'{x:.2f},{y:.2f}' for x, y in points)
        self.parts.append(f'<polyline points="{values}" fill="none" stroke="black" stroke-width="{thickness}" stroke-linejoin="round" stroke-linecap="round"/>')

    def rect(self, box, fill='white', thickness=2.5):
        x1, y1, x2, y2 = box
        coordinates = tuple(round(value * SCALE) for value in box)
        self.draw.rectangle(coordinates, fill=255 if fill == 'white' else None, outline=0 if thickness else None, width=max(1, round(thickness * SCALE)))
        self.parts.append(f'<rect x="{x1}" y="{y1}" width="{x2-x1}" height="{y2-y1}" fill="{fill}" stroke="{"black" if thickness else "none"}" stroke-width="{thickness}"/>')

    def ellipse(self, box, thickness=2.5):
        x1, y1, x2, y2 = box
        self.draw.ellipse(tuple(round(value * SCALE) for value in box), fill=255, outline=0, width=round(thickness * SCALE))
        self.parts.append(f'<ellipse cx="{(x1+x2)/2}" cy="{(y1+y2)/2}" rx="{(x2-x1)/2}" ry="{(y2-y1)/2}" fill="white" stroke="black" stroke-width="{thickness}"/>')

    def text(self, text, x, y, size=25, bold=False, align='center'):
        face = font(size, bold)
        anchor = 'mm' if align == 'center' else 'lm'
        coordinates = (round(x * SCALE), round(y * SCALE))
        box = self.draw.textbbox(coordinates, text, font=face, anchor=anchor)
        assert 0 <= box[0] and box[2] < self.image.width and 0 <= box[1] and box[3] < self.image.height, (text, box)
        self.draw.text(coordinates, text, font=face, fill=0, anchor=anchor)
        self.text_boxes.append([value / SCALE for value in box])
        svg_anchor = 'middle' if align == 'center' else 'start'
        self.parts.append(f'<text x="{x}" y="{y}" font-family="Arial, sans-serif" font-size="{size}" font-weight="{"bold" if bold else "normal"}" fill="black" text-anchor="{svg_anchor}" dominant-baseline="central">{html.escape(text)}</text>')
        return box

    def actor(self, identifier, name, x, y):
        self.ellipse((x-23, y-73, x+23, y-27), 3)
        self.line([(x, y-27), (x, y+83)], 3)
        self.line([(x-70, y), (x+70, y)], 3)
        self.line([(x, y+83), (x-49, y+140)], 3)
        self.line([(x, y+83), (x+49, y+140)], 3)
        self.text(identifier, x, y+180, 26, True)
        for index, line in enumerate(wrap(name, 230, 25)):
            self.text(line, x, y+218+index*31, 25)

    def association(self, link, actor, bounds):
        actor_x, actor_y, side = actor
        start = (actor_x+70 if side=='left' else actor_x-70, actor_y)
        x1, y1, x2, y2 = bounds
        center_x, center_y = (x1+x2)/2, (y1+y2)/2
        end = (x1 if start[0]<center_x else x2,center_y)
        self.parts.append(f'<g class="association" data-actor="{link["actorId"]}" data-uc="{link["ucId"]}">')
        self.line([start, end], 2.4)
        self.parts.append('</g>')
        self.association_segments.append({'actorId':link['actorId'], 'ucId':link['ucId'], 'points':[start,end]})
        return start, end

    def save(self, stem):
        for index, first in enumerate(self.text_boxes):
            for second in self.text_boxes[index+1:]:
                assert not (max(first[0],second[0]) < min(first[2],second[2]) and max(first[1],second[1]) < min(first[3],second[3])), (stem, first, second)
        for index, first in enumerate(self.association_segments):
            for second in self.association_segments[index+1:]:
                first_start, first_end = first['points']
                second_start, second_end = second['points']
                cross = lambda start,end,point: (end[0]-start[0])*(point[1]-start[1])-(end[1]-start[1])*(point[0]-start[0])
                collinear = abs(cross(first_start,first_end,second_start))<0.01 and abs(cross(first_start,first_end,second_end))<0.01
                if collinear:
                    axis = 0 if abs(first_end[0]-first_start[0])>abs(first_end[1]-first_start[1]) else 1
                    first_interval = sorted([first_start[axis],first_end[axis]])
                    second_interval = sorted([second_start[axis],second_end[axis]])
                    assert min(first_interval[1],second_interval[1])-max(first_interval[0],second_interval[0])<0.1, (stem, first, second)
        self.image.save(OUT / 'PNG' / (stem + '.png'), dpi=(300, 300), optimize=True)
        self.parts.append('</svg>')
        (OUT / 'SVG' / (stem + '.svg')).write_text('\n'.join(self.parts), encoding='utf-8')


def parse(entry, text):
    actors = {match[1]: match[0].split(r'\n', 1)[1].replace(r'\n', ' ') for match in re.findall(r'^actor "(.*?)" as ([AE]\d+)$', text, re.M)}
    aliases = {match[1]: match[0] for match in re.findall(r'usecase "(UC-[A-Z]+-[\d.]+).*?" as (UC_\w+)', text)}
    links = []
    for match in re.finditer(r'^([AE]\d+|UC_\w+)\s+(--|-\[#[0-9a-fA-F]+\]-)\s+([AE]\d+|UC_\w+)(?:\s+:\s*(.*))?$', text, re.M):
        start, connector, end, label = match.groups()
        actor = start if start in actors else end
        alias = start if start in aliases else end
        assert actor in actors and alias in aliases
        links.append({'actorId': actor, 'ucId': aliases[alias], 'label': label or '', 'limited': connector != '--'})
    assert set(aliases.values()) == set(entry['ucIds'])
    assert set(actors) == set(entry['actorIds'])
    assert set(actors) == {link['actorId'] for link in links}
    return actors, links


def positions(actors, links, centers, bottom):
    identifiers = list(actors)
    external = [actor for actor in identifiers if actor.startswith('E')]
    humans = [actor for actor in identifiers if actor.startswith('A')]
    if len(humans) == 1:
        left, right = humans, external
    elif len(humans) == 2:
        left, right = humans[:1], humans[1:] + external
    else:
        left = [actor for actor in humans if actor in ['A01', 'A02', 'A04']]
        right = [actor for actor in humans if actor not in left] + external
        if len(left) > 2:
            right.insert(0, left.pop())
        if len(right) > 3 and 'A03' in right:
            right.remove('A03')
            left.append('A03')
    result = {}
    for side, group in [('left', left), ('right', right)]:
        mean = lambda actor: sum(centers[link['ucId']] for link in links if link['actorId'] == actor) / sum(1 for link in links if link['actorId'] == actor)
        group = sorted(group, key=mean)
        previous = -1000
        values = []
        for actor in group:
            value = max(170, mean(actor)-25, previous+410)
            values.append(value)
            previous = value
        if values and values[-1] > bottom-320:
            offset = values[-1] - (bottom-320)
            values = [value-offset for value in values]
        if values and values[0] < 155:
            values = [170+index*410 for index in range(len(group))]
        for actor, value in zip(group, values):
            result[actor] = (170 if side == 'left' else 1750, value, side)
    return result


def render_overall(entry, actors, links, cases, stem):
    width, height = 2920, 2240
    canvas = Canvas(height, width)
    canvas.rect((420, 50, 2500, 2070))
    canvas.text('Hệ thống quản lý nhà trọ', 1460, 115, 36, True)
    layout = {
        'UC-SYS-03':(1000,500),
        'UC-TNT-05':(1000,800),
        'UC-TNT-08':(1000,1080),
        'UC-BIL-16':(1000,1360),
        'UC-OPT-03.1':(1000,1640),
        'UC-OPT-01':(1000,1920),
        'UC-DIS-01':(2000,260),
        'UC-DIS-09':(2000,540),
        'UC-TEN-03':(2000,820),
        'UC-ADM-02':(2000,1360),
        'UC-ADM-11':(2000,1640),
        'UC-ADM-15':(2000,1920),
    }
    actor_layout = {
        'A01':(170,260,'left'),
        'A02':(170,1000,'left'),
        'A03':(170,1700,'left'),
        'A04':(2750,540,'right'),
        'A05':(2750,1590,'right'),
    }
    bounds = {identifier:[center_x-420,center_y-92,center_x+420,center_y+92] for identifier,(center_x,center_y) in layout.items()}
    assert set(layout)==set(entry['ucIds'])
    for link in links:
        canvas.association(link,actor_layout[link['actorId']],bounds[link['ucId']])
    for identifier,(center_x,center_y) in layout.items():
        lines = wrap(cases[identifier]['title'],690,28)
        items = [(identifier,30,True)]+[(line,28,False) for line in lines]
        canvas.ellipse(bounds[identifier])
        first = center_y-(len(items)-1)*35/2
        for index,(text,size,bold) in enumerate(items):
            canvas.text(text,center_x,first+index*35,size,bold)
    for actor,(actor_x,actor_y,side) in actor_layout.items():
        canvas.actor(actor,actors[actor],actor_x,actor_y)
    note = 'Tổng quan: 12 mục tiêu đại diện; các hình nhóm trình bày đầy đủ 162 Use Case.'
    canvas.text(note,80,2140,26,align='left')
    canvas.save(stem)
    return {'width':width*SCALE,'height':height*SCALE,'links':links,'nodes':bounds,'notes':[note],'associationSegments':canvas.association_segments,'layout':'two-column-independent-links'}

def render(entry, actors, links, cases, stem):
    if entry['kind']=='overall':
        return render_overall(entry,actors,links,cases,stem)
    centers = {identifier: 235 + index*205 for index, identifier in enumerate(entry['ucIds'])}
    bottom = max(centers.values()) + 130
    left_count = math.ceil(len(actors)/2)
    bottom = max(bottom, 170 + 330*(left_count-1) + 350)
    positions_by_actor = positions(actors, links, centers, bottom)
    bottom = max(bottom, max(value[1]+330 for value in positions_by_actor.values()))
    notes = []
    numbered = {}
    for index, link in enumerate(links):
        if link['label'] and link['limited']:
            number = len(notes)+1
            numbered[index] = number
            notes.append(f"[{number}] {link['actorId']} - {link['ucId']}: {link['label']}.")
    if entry['kind'] == 'overall':
        notes.append('Tổng quan gồm 12 mục tiêu đại diện; các hình nhóm trình bày đầy đủ 162 Use Case.')
    note_lines = [line for note in notes for line in wrap(note, WIDTH-160, 23)]
    height = math.ceil(bottom + 55 + len(note_lines)*34 + 35)
    canvas = Canvas(height)
    canvas.rect((460, 40, 1460, bottom))
    canvas.text('Hệ thống quản lý nhà trọ', 960, 99, 31, True)
    segments = {}
    for index, link in enumerate(links):
        center = centers[link['ucId']]
        case = cases[link['ucId']]
        line_count = 1+len(wrap(case['title'],630,25))+(case['status']!='Xác minh tĩnh')
        radius = max(78,line_count*30/2+26)
        bounds = (595,center-radius,1325,center+radius)
        segments[index] = canvas.association(link,positions_by_actor[link['actorId']],bounds)
    for index, number in numbered.items():
        link = links[index]
        start, end = segments[index]
        factor = 0.74
        marker_x = start[0]*(1-factor)+end[0]*factor
        marker_y = start[1]*(1-factor)+end[1]*factor
        canvas.rect((marker_x-19, marker_y-16, marker_x+19, marker_y+16), thickness=0)
        canvas.text(f'[{number}]', marker_x, marker_y, 21, True)
    node_bounds = {}
    for identifier, center in centers.items():
        case = cases[identifier]
        title_lines = wrap(case['title'], 630, 25)
        status = {'Một phần': 'Một phần', 'Đã triển khai — DEMO': 'Thử nghiệm', 'Đã triển khai — MÔ PHỎNG': 'Mô phỏng'}.get(case['status'])
        items = [(identifier, 27, True)] + [(line, 25, False) for line in title_lines]
        if status:
            items.append((f'[{status}]', 20, False))
        radius = max(78, len(items)*30/2+26)
        canvas.ellipse((595, center-radius, 1325, center+radius))
        first = center - (len(items)-1)*30/2
        node_bounds[identifier] = [595, center-radius, 1325, center+radius]
        for index, (text, size, bold) in enumerate(items):
            canvas.text(text, 960, first+index*30, size, bold)
            extent = font(size, bold).getlength(text)/SCALE/2
            vertical = abs(first+index*30-center) + size/2
            assert (extent/365)**2 + (vertical/radius)**2 < 1, (identifier, text)
    for actor, (x, y, side) in positions_by_actor.items():
        canvas.actor(actor, actors[actor], x, y)
    for index, note in enumerate(note_lines):
        canvas.text(note, 80, bottom+52+index*34, 23, align='left')
    canvas.save(stem)
    return {'width': WIDTH*SCALE, 'height': height*SCALE, 'links': links, 'nodes': node_bounds, 'notes': notes, 'associationSegments':canvas.association_segments, 'layout':'independent-direct-links'}


def main():
    for folder in ['PNG', 'SVG', 'data', 'QA']:
        (OUT/folder).mkdir(parents=True, exist_ok=True)
    entries = json.loads((SOURCE/'data/report-diagrams.json').read_text())
    content = json.loads((SOURCE/'data/business-report-content.json').read_text())
    cases = {item['id']:item for item in content['useCases']}
    standard = json.loads(STANDARD.read_text())
    canonical = {entry['id']:entry for entry in standard['diagrams']}
    results = []
    for index, entry in enumerate(entries, 1):
        text = (SOURCE/'diagrams'/entry['file']).read_text()
        actors, links = parse(entry, text)
        for actor in list(actors):
            if actor in content['actors']:
                actors[actor] = content['actors'][actor]
        actors.update({actor: {'E03':'Đơn vị kiểm tra an toàn tệp (có điều kiện)'}.get(actor, label) for actor,label in actors.items() if actor.startswith('E')})
        base_id = re.sub(r'_BA_\d+$', '', entry['id'])
        expected = {(link['actorId'], link['ucId'], link['kind']=='limited') for link in canonical[base_id]['associations'] if link['ucId'] in entry['ucIds']}
        actual = {(link['actorId'], link['ucId'], link['limited']) for link in links}
        assert expected == actual, (entry['id'], expected-actual, actual-expected)
        stem = f"{index:02d}_Hinh_2_{index+2:02d}_{entry['id']}"
        result = render(entry, actors, links, cases, stem)
        results.append({**entry, 'order':index, 'caption':f'Hình 2.{index+2}', 'png':f'PNG/{stem}.png', 'svg':f'SVG/{stem}.svg', 'sourceSha256':hashlib.sha256(text.encode()).hexdigest(), **result})
    counts = Counter(identifier for entry in entries if entry['kind']=='module' for identifier in entry['ucIds'])
    assert len(results)==30 and len(counts)==162 and set(counts.values())=={1} and set(counts)==set(cases)
    checks = []
    for result in results:
        path = OUT/result['png']
        with Image.open(path) as image:
            assert image.mode=='L' and image.getextrema()==(0,255)
            assert image.size==(result['width'],result['height'])
            assert image.getpixel((0,0))==255
            assert image.getpixel((image.width-1,image.height-1))==255
            assert min(image.size)>1500
        tree = ElementTree.parse(OUT/result['svg'])
        namespace = {'svg':'http://www.w3.org/2000/svg'}
        texts = [node.text for node in tree.findall('.//svg:text', namespace)]
        assert all(identifier in texts for identifier in result['ucIds'])
        assert all(actor in texts for actor in result['actorIds'])
        assert len(result['links']) == len({(link['actorId'],link['ucId']) for link in result['links']})
        groups = tree.findall('.//svg:g[@class="association"]',namespace)
        assert len(groups)==len(result['links'])
        actual_edges = {(node.attrib['data-actor'],node.attrib['data-uc']) for node in groups}
        assert actual_edges=={(link['actorId'],link['ucId']) for link in result['links']}
        for group in groups:
            segments = group.findall('svg:polyline',namespace)
            assert len(segments)==1 and len(segments[0].attrib['points'].split())==2
        checks.append({'file':result['png'], 'grayscale':True, 'ucIds':True, 'actors':True, 'associations':True, 'bounds':True,'independentDirectAssociations':True,'noSharedAssociationSegments':True})
    (OUT/'data/image-manifest.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    validation = {'imageCount':len(results), 'moduleImageCount':29, 'uniqueModuleUseCases':len(counts), 'eachModuleUseCaseOccursOnce':True, 'limitedAssociations':sum(link['limited'] for result in results for link in result['links']), 'resolutionDpi':300, 'checks':checks}
    (OUT/'data/validation.json').write_text(json.dumps(validation, ensure_ascii=False, indent=2))
    with (OUT/'Danh_sach_anh.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer = csv.writer(handle)
        writer.writerow(['STT','Hình trong báo cáo V4','Nhóm chức năng','File PNG','File SVG','Số UC'])
        for result in results:
            writer.writerow([result['order'], result['caption'], result['title'], result['png'], result['svg'], len(result['ucIds'])])
    readme = ['# Bộ ảnh Use Case trắng đen', '', 'Bộ ảnh thay thế cho phần Mô hình Use Case trong Bao_cao_Quan_ly_Nha_tro_V4_2026-10-29_BA.docx.', '', '- 30 ảnh: 1 hình tổng quan và 29 hình nhóm; giữ thứ tự Hình 2.3 đến Hình 2.32.', '- Thư mục PNG: ảnh nền trắng, chữ và nét đen, 300 dpi, rộng 3.840 pixel.', '- Thư mục SVG: bản vector để phóng to không vỡ hình.', '- Các hình nhóm bao phủ đủ 162 UC, mỗi UC xuất hiện một lần; hình tổng quan chỉ có 12 mục tiêu đại diện.', '- Mã UC, tác nhân và liên kết được đối chiếu với danh mục đã xác minh, không suy ra thêm quyền.', '- Ký hiệu [1], [2] trên đường nối dẫn đến ghi chú giới hạn ngay dưới hình; đây không phải quan hệ bao hàm hoặc mở rộng.', '- Nhãn Một phần, Thử nghiệm, Mô phỏng được ghi bằng chữ thay cho màu.', '- Nhân viên chỉ thực hiện trong quyền và khu trọ được giao; quản trị viên thực hiện theo thẩm quyền.', '- Tác nhân phối hợp có điều kiện chỉ tham gia khi phương thức tương ứng được sử dụng.', '- Không sửa file Word, source ứng dụng hay bộ sơ đồ nguồn đã có.', '', '## Danh sách thay ảnh', '', '| Hình | Nội dung | File PNG |', '|---|---|---|']
    readme.extend(f"| {item['caption']} | {item['title']} | {item['png']} |" for item in results)
    (OUT/'README.md').write_text('\n'.join(readme)+'\n')
    readme_path = OUT/'README.md'
    readme_text = readme_path.read_text().replace('300 dpi, rộng 3.840 pixel.','300 dpi; ảnh nhóm rộng 3.840 pixel, ảnh tổng rộng 5.840 pixel.')
    readme_text = readme_text.replace('## Danh sách thay ảnh','## Điều chỉnh bố cục bản 2\n\n- Mỗi liên kết được vẽ bằng một nét thẳng riêng, tỏa trực tiếp từ tác nhân đến Use Case; không có đường gom hay nhánh chung.\n- Sơ đồ tổng được bố trí hai cột theo các cụm tác nhân và mục tiêu, thay cho một cột dài.\n- Giữ nguyên 12 mục tiêu đại diện và toàn bộ liên kết đã đối chiếu; không bổ sung quan hệ include/extend từ hình tham khảo.\n\n## Danh sách thay ảnh')
    readme_path.write_text(readme_text)
    for page in range(3):
        sheet = Image.new('RGB',(1600,1800),'white')
        draw = ImageDraw.Draw(sheet)
        for local, result in enumerate(results[page*10:(page+1)*10]):
            column, row = local%2, local//2
            with Image.open(OUT/result['png']) as image:
                image = image.convert('RGB')
                image.thumbnail((750,305))
                sheet.paste(image,(column*800+(800-image.width)//2,row*360+35))
            draw.text((column*800+20,row*360+8),f"{result['order']:02d} - {result['caption']} - {result['id']}",font=ImageFont.truetype(str(FONT_ROOT/'Arial.ttf'),17),fill='black')
        sheet.save(OUT/'QA'/f'Contact_sheet_{page+1}.png')
    archive = OUT/'Use_Case_Trang_Den_V2_Duong_Noi_Rieng.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
        for folder in ['PNG','SVG']:
            for path in sorted((OUT/folder).iterdir()):
                bundle.write(path,path.relative_to(OUT))
        for filename in ['README.md','Danh_sach_anh.csv','data/validation.json']:
            bundle.write(OUT/filename,filename)
    with zipfile.ZipFile(archive) as bundle:
        assert bundle.testzip() is None
        assert sum(name.endswith('.png') for name in bundle.namelist())==30
        assert sum(name.endswith('.svg') for name in bundle.namelist())==30
    desktop = Path('/Users/hoang/Desktop/ĐỒ ÁN')
    assert desktop.is_dir()
    destination = desktop/archive.name
    shutil.copy2(archive,destination)
    print(json.dumps({'png':30,'svg':30,'moduleUseCases':len(counts),'limitedLinks':validation['limitedAssociations'],'archive':str(destination),'archiveBytes':destination.stat().st_size},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()

