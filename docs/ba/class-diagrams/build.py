import html
import json
import math
import os
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import ImageFont


BASE = Path(__file__).resolve().parent
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
NODE = os.environ.get('CODEX_NODE', '/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node')
PACKAGES = os.environ.get('CODEX_NODE_MODULES', '/Users/hoang/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules')


def attribute(model, class_name, field):
    kind = model['models'][class_name]['fields'][field]['type']
    display = kind.replace('[]', ' [0..*]').replace('?', ' [0..1]')
    suffix = ' {id}' if field == 'id' else ' {unique}' if class_name == 'User' and field == 'email' else ''
    return field + ': ' + display + suffix


def text_width(text, size):
    return ImageFont.truetype(FONT, size).getlength(text)


def rectangle(node):
    return [node['x'], node['y'], node['x'] + node['width'], node['y'] + node['height']]


def intersects(first, second, gap=3):
    return first[0] < second[2] + gap and second[0] < first[2] + gap and first[1] < second[3] + gap and second[1] < first[3] + gap


def path_middle(points):
    lengths = [math.dist(start, end) for start, end in zip(points, points[1:])]
    remaining = sum(lengths) / 2
    for start, end, length in zip(points, points[1:], lengths):
        if remaining <= length:
            ratio = remaining / length if length else 0
            return [start[0] + (end[0] - start[0]) * ratio, start[1] + (end[1] - start[1]) * ratio]
        remaining -= length
    return points[-1]


def inverse_role(model, relation):
    source = relation['source']
    target = relation['target']
    attributes = model['models'][source]['fields'][relation['field']]['attributes']
    name = attributes.split('"')[1] if '"' in attributes else None
    candidates = []
    for field, details in model['models'][target]['fields'].items():
        if details['type'].rstrip('?').removesuffix('[]') != source or 'fields:' in details['attributes']:
            continue
        other_name = details['attributes'].split('"')[1] if '"' in details['attributes'] else None
        if name == other_name:
            candidates.append(field)
    return candidates[0] if len(candidates) == 1 else None


def prepare_nodes(model, diagram, layout):
    for node in layout['nodes']:
        previous_height = node['height']
        if not diagram.get('object') and not diagram.get('overview') and not node['reference']:
            node['fields'] = model['models'][node['id']]['selected_fields']
            node['lines'] = [attribute(model, node['id'], field) for field in node['fields']]
        elif not diagram.get('object'):
            node['lines'] = [attribute(model, node['id'], field) for field in node['fields']]
        else:
            instance = model['snapshot'][node['id']]
            node['title'] = node['id'] + ' : ' + instance['class']
        node['height'] = node['header'] + layout.get('line_step', 26) * len(node['lines']) + 14
        delta = node['height'] - previous_height
        if not delta:
            continue
        for route in layout['routes']:
            if route['source'] == node['id'] and route['target'] == node['id']:
                route['points'] = [[point[0], point[1] + delta] for point in route['points']]
                continue
            if route['source'] == node['id'] and abs(route['points'][0][1] - node['y'] - previous_height) < 1:
                route['points'][0][1] += delta
            if route['target'] == node['id'] and abs(route['points'][-1][1] - node['y'] - previous_height) < 1:
                route['points'][-1][1] += delta


def labels_for(model, diagram, layout):
    labels = []
    pending_roles = []
    occupied = [rectangle(node) for node in layout['nodes']] + [rectangle(note) for note in layout.get('notes', [])]
    size = layout.get('label_size', 17)

    def place(text, candidates, edge_index, kind):
        width = math.ceil(text_width(text, size)) + 10
        height = size + 8
        for center in candidates:
            bounds = [center[0] - width / 2, center[1] - height / 2, center[0] + width / 2, center[1] + height / 2]
            if bounds[0] < 8 or bounds[2] > layout['width'] - 8 or bounds[1] < 90 or bounds[3] > layout['height'] - 35:
                continue
            if not any(intersects(bounds, obstacle) for obstacle in occupied):
                occupied.append(bounds)
                labels.append({'text': text, 'bounds': bounds, 'edge': edge_index, 'kind': kind})
                return
        raise ValueError(diagram['id'] + ': edge ' + str(edge_index) + ': no clear label position for ' + text)

    for index, (relation, route) in enumerate(zip(diagram['associations'], layout['routes']), 1):
        points = route['points']
        if not diagram.get('object'):
            for position, count in [(0, relation['source_multiplicity']), (-1, relation['target_multiplicity'])]:
                endpoint = points[position]
                neighbor = points[1] if position == 0 else points[-2]
                horizontal = abs(neighbor[0] - endpoint[0]) > abs(neighbor[1] - endpoint[1])
                direction = 1 if (neighbor[0] if horizontal else neighbor[1]) > (endpoint[0] if horizontal else endpoint[1]) else -1
                candidates = [[endpoint[0] + direction * distance, endpoint[1] + offset] if horizontal else [endpoint[0] + offset, endpoint[1] + direction * distance] for distance in [24, 36, 48, 60, 75] for offset in [-30, 30, -45, 45, -60, 60]]
                place(count, candidates, index, 'multiplicity')
        endpoint = points[-1]
        neighbor = points[-2]
        horizontal = abs(neighbor[0] - endpoint[0]) > abs(neighbor[1] - endpoint[1])
        direction = 1 if (neighbor[0] if horizontal else neighbor[1]) > (endpoint[0] if horizontal else endpoint[1]) else -1
        half_width = text_width(relation['field'], size) / 2 + 10
        candidates = [[endpoint[0] + direction * (half_width + shift), endpoint[1] + offset] if horizontal else [endpoint[0] + side * (half_width + shift), endpoint[1] + direction * offset] for shift in [0, 20, 40, 70] for side in [1, -1] for offset in [42, 65, 85, 105]]
        if relation['source'] == relation['target']:
            candidates = [[endpoint[0] + half_width, endpoint[1] + offset] for offset in [70, 100, 130]] + candidates
            opposite = inverse_role(model, relation)
            start, end = points[:2]
            source_candidates = [[start[0], start[1] + (end[1] - start[1]) * ratio] for ratio in [0.75, 0.5, 0.25]]
            pending_roles.append((opposite, source_candidates, index))
        inline_candidates = []
        for start, end in reversed(list(zip(points, points[1:]))):
            for ratio in [0.25, 0.5, 0.75]:
                middle = [start[0] + (end[0] - start[0]) * ratio, start[1] + (end[1] - start[1]) * ratio]
                inline_candidates.append(middle)
                for offset in [28, -28, 45, -45]:
                    candidates.append([middle[0], middle[1] + offset] if start[1] == end[1] else [middle[0] + offset, middle[1]])
        pending_roles.append((relation['field'], inline_candidates + candidates, index))
    for field, candidates, index in pending_roles:
        place(field, candidates, index, 'role')
    return labels


def plantuml(model, diagram, layout):
    lines = ['@startuml', 'hide empty methods', 'skinparam classAttributeIconSize 0', 'skinparam shadowing false', 'skinparam defaultFontName Arial', 'title ' + diagram['id'] + ' ' + diagram['title']]
    if diagram.get('object'):
        lines[-1] += '\\nCác đối tượng, giá trị thuộc tính và liên kết tại một thời điểm của hệ thống.'
    used_enums = set()
    for node in layout['nodes']:
        if diagram.get('object'):
            instance = model['snapshot'][node['id']]
            lines.append('object "' + node['title'] + '" as ' + node['id'] + ' {')
            lines.extend('  ' + value for value in node['lines'])
        else:
            lines.append('class ' + node['id'] + (' <<reference>>' if node['reference'] else '') + ' {')
            lines.extend('  ' + value for value in node['lines'])
            for field in node['fields']:
                field_type = model['models'][node['id']]['fields'][field]['type'].rstrip('?').removesuffix('[]')
                if field_type in model['enums']:
                    used_enums.add(field_type)
        lines.append('}')
    for enum in sorted(used_enums):
        lines.extend(['enum ' + enum + ' {'] + ['  ' + value for value in model['enums'][enum]] + ['}'])
    for relation in diagram['associations']:
        if diagram.get('object'):
            lines.append(relation['source'] + ' -- ' + relation['target'] + ' : ' + relation['field'])
        else:
            inverse = inverse_role(model, relation)
            source_label = relation['source_multiplicity'] + ('\\n' + inverse if inverse else '')
            target_label = relation['target_multiplicity'] + '\\n' + relation['field']
            lines.append(f'{relation["source"]} "{source_label}" -- "{target_label}" {relation["target"]}')
    for note in layout.get('notes', []):
        lines.extend(['note ' + ('right of ' + note['class'] if note.get('class') else 'as ' + note['id']), note['title']] + note['lines'] + ['end note'])
    lines.extend(['legend bottom', 'Snapshot giả định: 06/10/2026; các hình OD là góc nhìn của cùng dữ liệu.' if diagram.get('object') else 'Đường liền: association. <<IDRef>>: chỉ tham chiếu bằng mã, không phải association.', 'endlegend', '@enduml'])
    return '\n'.join(lines) + '\n'


def draw(model, diagram, layout, file_root):
    width, height = layout['width'], layout['height']
    diagram_xml = ET.SubElement(file_root, 'diagram', id=diagram['id'], name=diagram['id'] + ' ' + diagram['title'])
    graph = ET.SubElement(diagram_xml, 'mxGraphModel', grid='1', gridSize='10', page='1', pageScale='1', pageWidth=str(width), pageHeight=str(height))
    cells = ET.SubElement(graph, 'root')
    ET.SubElement(cells, 'mxCell', id='0')
    ET.SubElement(cells, 'mxCell', id='1', parent='0')
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img">', '<title>' + html.escape(diagram['id'] + ' ' + diagram['title']) + '</title>', '<desc>Domain/Entity Class Diagram; association, bội số và vai trò theo schema; IDRef chỉ là mã tham chiếu.</desc>', f'<rect width="{width}" height="{height}" fill="white"/>']

    def box(identifier, value, style, bounds, parent='1', kind=None):
        cell = ET.SubElement(cells, 'mxCell', id=identifier, value=value, style=style + ';fontFamily=Arial;html=0;', vertex='1', parent=parent)
        if kind:
            cell.set('umlKind', kind)
        ET.SubElement(cell, 'mxGeometry', x=str(bounds[0]), y=str(bounds[1]), width=str(bounds[2]), height=str(bounds[3]), attrib={'as': 'geometry'})
        return cell

    def svg_text(text, center_x, center_y, size=19, anchor='start', bold=False, underline=False):
        decoration = ' text-decoration="underline"' if underline else ''
        svg.append(f'<text x="{center_x}" y="{center_y}" font-family="Arial, sans-serif" font-size="{size}" font-weight="{"bold" if bold else "normal"}" text-anchor="{anchor}" dominant-baseline="central" fill="#222222"{decoration}>{html.escape(text)}</text>')

    box('title', diagram['id'] + ' ' + diagram['title'], 'text;strokeColor=none;fontSize=25;fontStyle=1;align=center', [20, 15, width - 40, 35])
    svg_text(diagram['id'] + '  ' + diagram['title'], width / 2, 32, 25, 'middle', True)
    subtitle = 'Các đối tượng, giá trị thuộc tính và liên kết tại một thời điểm của hệ thống.' if diagram.get('object') else 'Thực thể, thuộc tính và liên kết dữ liệu; không mô tả chiều gọi hàm'
    box('subtitle', subtitle, 'text;strokeColor=none;fontSize=17;align=center', [20, 55, width - 40, 25])
    svg_text(subtitle, width / 2, 67, 17, 'middle')
    for index, (relation, route) in enumerate(zip(diagram['associations'], layout['routes']), 1):
        points = route['points']
        edge = ET.SubElement(cells, 'mxCell', id='edge-' + str(index), value='', style='edgeStyle=none;rounded=0;startArrow=none;endArrow=none;strokeColor=#536579;strokeWidth=1.4;', edge='1', parent='1', source=relation['source'], target=relation['target'], umlKind='link' if diagram.get('object') else 'association', umlRelation=relation['id'])
        geometry = ET.SubElement(edge, 'mxGeometry', relative='1', attrib={'as': 'geometry'})
        for position, label in [(0, 'sourcePoint'), (-1, 'targetPoint')]:
            ET.SubElement(geometry, 'mxPoint', x=str(points[position][0]), y=str(points[position][1]), attrib={'as': label})
        array = ET.SubElement(geometry, 'Array', attrib={'as': 'points'})
        for point in points[1:-1]:
            ET.SubElement(array, 'mxPoint', x=str(point[0]), y=str(point[1]))
        source = next(node for node in layout['nodes'] if node['id'] == relation['source'])
        target = next(node for node in layout['nodes'] if node['id'] == relation['target'])
        edge.set('style', edge.get('style') + f'exitX={(points[0][0] - source["x"]) / source["width"]};exitY={(points[0][1] - source["y"]) / source["height"]};entryX={(points[-1][0] - target["x"]) / target["width"]};entryY={(points[-1][1] - target["y"]) / target["height"]};')
        svg.append('<polyline points="' + ' '.join(f'{point[0]},{point[1]}' for point in points) + '" fill="none" stroke="#536579" stroke-width="1.4"/>')
    for node in layout['nodes']:
        left, top, node_width, node_height = node['x'], node['y'], node['width'], node['height']
        fill = '#EEF1F4' if node['reference'] else '#E4ECF6'
        box(node['id'], '', 'group;container=1;collapsible=0;recursiveResize=1', [left, top, node_width, node_height])
        box(node['id'] + '-body', '', 'rectangle;fillColor=#FFFFFF;strokeColor=#364354;', [0, 0, node_width, node_height], node['id'])
        title = node['title'] + ('\n«reference» — cùng lớp/đối tượng' if node['reference'] else '')
        box(node['id'] + '-title', title, 'rectangle;fillColor=' + fill + ';strokeColor=#364354;fontSize=21;fontStyle=' + ('5' if diagram.get('object') else '1') + ';align=center;whiteSpace=wrap', [0, 0, node_width, node['header']], node['id'])
        svg.append(f'<rect x="{left}" y="{top}" width="{node_width}" height="{node_height}" fill="white" stroke="#364354" stroke-width="1.4"/><rect x="{left}" y="{top}" width="{node_width}" height="{node["header"]}" fill="{fill}" stroke="#364354" stroke-width="1.4"/>')
        svg_text(node['title'], left + node_width / 2, top + 20, 21, 'middle', True, diagram.get('object', False))
        if node['reference']:
            svg_text('«reference» — cùng lớp/đối tượng', left + node_width / 2, top + 44, 13, 'middle')
        for index, line in enumerate(node['lines']):
            vertical = node['header'] + index * layout.get('line_step', 26) + 4
            kind = 'idRef' if node['id'] == 'NotificationDelivery' and line.split(':')[0] in ['landlordId', 'tenantId', 'invoiceId'] else 'attribute'
            box(node['id'] + '-attr-' + str(index), line, f'text;strokeColor=none;fillColor=none;fontSize={layout.get("attribute_size", 19)};align=left;verticalAlign=middle', [10, vertical, node_width - 20, layout.get('line_step', 26)], node['id'], kind)
            svg_text(line, left + 11, top + vertical + layout.get('line_step', 26) / 2, layout.get('attribute_size', 19))
    for note in layout.get('notes', []):
        note_size = layout.get('note_size', 17)
        box(note['id'], note['title'] + '\n' + '\n'.join(note['lines']), f'shape=note;fillColor=#FFFDF2;strokeColor=#8A826D;align=left;verticalAlign=top;spacing=10;fontSize={note_size};whiteSpace=wrap', [note['x'], note['y'], note['width'], note['height']], kind='constraintNote')
        svg.append(f'<rect x="{note["x"]}" y="{note["y"]}" width="{note["width"]}" height="{note["height"]}" fill="#FFFDF2" stroke="#8A826D"/>')
        svg_text(note['title'], note['x'] + 10, note['y'] + 18, note_size, bold=True)
        for index, line in enumerate(note['lines']):
            svg_text(line, note['x'] + 10, note['y'] + 43 + index * (note_size + 6), note_size)
    for index, label in enumerate(layout['labels']):
        bounds = label['bounds']
        center = [(bounds[0] + bounds[2]) / 2, (bounds[1] + bounds[3]) / 2]
        edge_number = label['edge']
        middle = path_middle(layout['routes'][edge_number - 1]['points'])
        cell = ET.SubElement(cells, 'mxCell', id='label-' + str(index), value=label['text'], style=f'edgeLabel;html=0;fontFamily=Arial;fontSize={layout.get("label_size", 17)};align=center;verticalAlign=middle;fillColor=#FFFFFF;strokeColor=none;', vertex='1', connectable='0', parent='edge-' + str(edge_number), umlKind=label['kind'])
        geometry = ET.SubElement(cell, 'mxGeometry', x='0', y='0', width=str(bounds[2] - bounds[0]), height=str(bounds[3] - bounds[1]), relative='1', attrib={'as': 'geometry'})
        ET.SubElement(geometry, 'mxPoint', x=str(bounds[0] - middle[0]), y=str(bounds[1] - middle[1]), attrib={'as': 'offset'})
        svg.append(f'<rect x="{bounds[0]}" y="{bounds[1]}" width="{bounds[2] - bounds[0]}" height="{bounds[3] - bounds[1]}" fill="white"/>')
        svg_text(label['text'], center[0], center[1], layout.get('label_size', 17), 'middle')
    footer = 'Snapshot giả định 06/10/2026; góc nhìn chọn lọc của cùng các đối tượng.' if diagram.get('object') else 'Đường liền: association. Nhãn liên kết: role từ lớp nguồn. <<IDRef>> không phải association.'
    box('footer', footer, 'text;strokeColor=none;fontSize=16;align=center', [20, height - 30, width - 40, 24])
    svg_text(footer, width / 2, height - 18, 16, 'middle')
    svg.append('</svg>')
    (BASE / (diagram['id'].lower() + '.svg')).write_text(''.join(svg))
    (BASE / (diagram['id'].lower() + '.puml')).write_text(plantuml(model, diagram, layout))


def build():
    model = json.loads((BASE / 'class-model.json').read_text())
    layouts = json.loads((BASE / 'diagram-manifest.json').read_text())
    file_root = ET.Element('mxfile', host='app.diagrams.net', type='device')
    for diagram, layout in zip(model['diagrams'], layouts):
        prepare_nodes(model, diagram, layout)
        layout['labels'] = labels_for(model, diagram, layout)
        draw(model, diagram, layout, file_root)
    ET.indent(file_root)
    (BASE / 'CLASS_DIAGRAMS.drawio').write_text(ET.tostring(file_root, encoding='unicode'))
    (BASE / 'diagram-manifest.json').write_text(json.dumps(layouts, ensure_ascii=False, indent=2) + '\n')
    program = f'const fs=require("fs");const sharp=require({json.dumps(PACKAGES + "/sharp")});(async()=>{{for(const file of fs.readdirSync(process.argv[1]).filter(name=>name.endsWith(".svg"))){{const source=process.argv[1]+"/"+file;const meta=await sharp(source).metadata();await sharp(source).resize(meta.width*3).png().toFile(source.replace(/\\.svg$/,".png"));}}}})().catch(error=>{{console.error(error);process.exit(1)}});'
    subprocess.run([NODE, '-e', program, str(BASE)], check=True)
    print('Built 11 Draw.io pages, SVG, PNG and PlantUML; business schema unchanged.')


if __name__ == '__main__':
    build()
