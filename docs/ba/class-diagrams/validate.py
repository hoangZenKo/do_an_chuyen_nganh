import hashlib
from itertools import combinations
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile


BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]


def schema_model(schema):
    models = {}
    for match in re.finditer(r'model\s+(\w+)\s*\{([^}]+)\}', schema, re.S):
        fields = {}
        for line in match.group(2).splitlines():
            field = re.match(r'\s*(\w+)\s+(\w+[?\[\]]*)[ \t]*(.*)$', line)
            if field:
                fields[field.group(1)] = (field.group(2), field.group(3))
        models[match.group(1)] = fields
    return models


def overlaps(first, second):
    return first[0] < second[2] - 2 and second[0] < first[2] - 2 and first[1] < second[3] - 2 and second[1] < first[3] - 2

def segments_intersect(first, second):
    first_horizontal = first[0][1] == first[1][1]
    second_horizontal = second[0][1] == second[1][1]
    if first_horizontal == second_horizontal:
        axis = 0 if first_horizontal else 1
        fixed = 1 - axis
        return first[0][fixed] == second[0][fixed] and max(min(point[axis] for point in first), min(point[axis] for point in second)) <= min(max(point[axis] for point in first), max(point[axis] for point in second))
    horizontal, vertical = (first, second) if first_horizontal else (second, first)
    return min(point[0] for point in horizontal) <= vertical[0][0] <= max(point[0] for point in horizontal) and min(point[1] for point in vertical) <= horizontal[0][1] <= max(point[1] for point in vertical)

def penetrates(segment, node):
    left, top = node['x'], node['y']
    right, bottom = left + node['width'], top + node['height']
    if segment[0][1] == segment[1][1]:
        return top < segment[0][1] < bottom and max(min(point[0] for point in segment), left) < min(max(point[0] for point in segment), right)
    return left < segment[0][0] < right and max(min(point[1] for point in segment), top) < min(max(point[1] for point in segment), bottom)


def verify():
    failures = []
    checks = []

    def check(condition, message):
        checks.append(message)
        if not condition:
            failures.append(message)

    model = json.loads((BASE / 'class-model.json').read_text())
    layouts = json.loads((BASE / 'diagram-manifest.json').read_text())
    schema = (ROOT / model['schema']).read_text()
    models = schema_model(schema)
    check(hashlib.sha256(schema.encode()).hexdigest() == model['schema_sha256'], 'Schema fingerprint is unchanged')
    check(len(models) == 25 and len(model['included']) == 23 and len(model['enums']) == 14, '25 schema models, 23 report classes, 14 enums')
    relations = {}
    for class_name, fields in models.items():
        for field_name, (field_type, attributes) in fields.items():
            foreign = re.search(r'fields:\s*\[([^]]+)\]', attributes)
            if not foreign or '@relation' not in attributes:
                continue
            target = field_type.rstrip('?')
            if class_name not in model['included'] or target not in model['included']:
                continue
            foreign_key = foreign.group(1).strip()
            source_count = '0..1' if '@unique' in fields[foreign_key][1] else '0..*'
            target_count = '0..1' if field_type.endswith('?') else '1'
            relations[class_name + '.' + field_name] = (target, source_count, target_count)
    declared = {relation['id']: (relation['target'], relation['source_multiplicity'], relation['target_multiplicity']) for relation in model['associations']}
    check(len(relations) == 39 and relations == declared, 'All 39 relationships independently match Prisma')
    use_cases = set(re.findall(r'^### (UC-[A-Z]+-\d+(?:\.\d+)?)', (ROOT / 'docs/ba/USE_CASE_SPECIFICATION.md').read_text(), re.M))
    check(len(use_cases) == 67, 'Current Use Case specification has 67 detailed UCs')
    for class_name in model['included']:
        selected = model['models'][class_name]['selected_fields']
        check(all(field in models[class_name] for field in selected), class_name + ': attributes exist in schema')
        foreign_keys = {foreign_key for relation in model['associations'] if relation['source'] == class_name for foreign_key in relation['foreign_keys']}
        check(not foreign_keys.intersection(selected), class_name + ': no FK duplicates association')
        check(set(model['models'][class_name]['use_cases']).issubset(use_cases), class_name + ': UC references resolve')
    check('tokenHash' not in model['models']['TenantInvite']['selected_fields'] and 'tokenHash' not in model['models']['RefreshToken']['selected_fields'], 'Token hashes remain outside report attributes')
    xml = ET.parse(BASE / 'CLASS_DIAGRAMS.drawio').getroot()
    check(len(xml.findall('diagram')) == 11, 'Draw.io has 11 editable pages')
    coverage = set()
    for page, layout, diagram in zip(xml.findall('diagram'), layouts, model['diagrams']):
        identifier = diagram['id']
        cells = {cell.get('id'): cell for cell in page.findall('.//mxCell')}
        edges = [cell for cell in cells.values() if cell.get('edge') == '1' and cell.get('umlKind') in ['association', 'link']]
        check(page.get('id') == layout['id'] == identifier, identifier + ': page identifiers agree')
        check(len(edges) == len(diagram['associations']), identifier + ': editable relationship coverage')
        for route in layout['routes']:
            check(not any(penetrates(segment, node) for segment in zip(route['points'], route['points'][1:]) for node in layout['nodes']), identifier + ': connectors outside class/object interiors ' + route['source'] + '.' + route['field'])
        for index, relation in enumerate(diagram['associations'], 1):
            edge = cells.get('edge-' + str(index))
            check(edge is not None and edge.get('source') == relation['source'] and edge.get('target') == relation['target'], identifier + ': endpoints ' + relation['id'])
            roles = [cell for cell in cells.values() if cell.get('parent') == 'edge-' + str(index) and cell.get('umlKind') == 'role']
            check(any(cell.get('value') == relation['field'] for cell in roles), identifier + ': visible role ' + relation['id'])
            if relation['source'] == relation['target'] == 'Payment':
                check({cell.get('value') for cell in roles} == {'reversalOfPayment', 'reversalPayment'}, identifier + ': both self-association end roles')
            if not diagram.get('object'):
                counts = [cell.get('value') for cell in cells.values() if cell.get('parent') == 'edge-' + str(index) and cell.get('umlKind') == 'multiplicity']
                check(counts == [relation['source_multiplicity'], relation['target_multiplicity']], identifier + ': multiplicities ' + relation['id'])
                if not diagram.get('overview'):
                    coverage.add(relation['id'])
        bounds = []
        for node in layout['nodes']:
            geometry = cells[node['id']].find('mxGeometry')
            current = tuple(float(geometry.get(key)) for key in ['x', 'y', 'width', 'height'])
            expected = tuple(node[key] for key in ['x', 'y', 'width', 'height'])
            check(current == expected, identifier + ': manifest position ' + node['id'])
            rectangle = (node['x'], node['y'], node['x'] + node['width'], node['y'] + node['height'])
            check(not any(overlaps(rectangle, previous) for previous in bounds), identifier + ': class boxes do not overlap ' + node['id'])
            bounds.append(rectangle)
        for suffix in ['svg', 'png', 'puml']:
            check((BASE / (identifier.lower() + '.' + suffix)).stat().st_size > 0, identifier + ': ' + suffix + ' export exists')
        plantuml = (BASE / (identifier.lower() + '.puml')).read_text()
        check('..>' not in plantuml and '-->' not in plantuml, identifier + ': no invented Dependency or navigability')
    check(coverage == set(relations), 'Eight detail diagrams cover exactly 39 structural relationships')
    maintenance = next(layout for layout in layouts if layout['id'] == 'CD-05')
    for first, second in combinations(maintenance['routes'], 2):
        first_segments = list(zip(first['points'], first['points'][1:]))
        second_segments = list(zip(second['points'], second['points'][1:]))
        check(not any(segments_intersect(first_segment, second_segment) for first_segment in first_segments for second_segment in second_segments), 'CD-05: separate routes ' + first['source'] + '.' + first['field'] + ' / ' + second['source'] + '.' + second['field'])
    for route in maintenance['routes']:
        check(not any(penetrates(segment, node) for segment in zip(route['points'], route['points'][1:]) for node in maintenance['nodes']), 'CD-05: routes outside class interiors ' + route['source'] + '.' + route['field'])
    check(all(note['y'] + note['height'] <= maintenance['height'] - 35 for note in maintenance.get('notes', [])), 'CD-05: notes do not overlap footer')
    audit = (BASE.parent / 'CLASS_DIAGRAM_AUDIT.md').read_text()
    matrix = audit.split('## PHẦN B')[1].split('## PHẦN C')[0]
    audit_relations = set()
    audit_counts = []
    for line in matrix.splitlines():
        cells = [cell.strip() for cell in line.split('|')[1:-1]]
        if len(cells) == 7 and cells[0] in model['included'] and cells[1] in model['included']:
            audit_relations.add(cells[0] + '.' + cells[2])
            audit_counts.append(cells)
            expected = relations[cells[0] + '.' + cells[2]]
            check(cells[1] == expected[0] and cells[4] == ' — '.join(expected[1:]), 'Audit matrix multiplicity: ' + cells[0] + '.' + cells[2])
    check(len(audit_counts) == 39 and audit_relations == set(relations), 'Audit matrix covers exactly 39 declared relationships')
    embedded = re.findall(r'```plantuml\n(.*?)```', audit, re.S)
    check(len(embedded) == 11 and embedded == [(BASE / (diagram['id'].lower() + '.puml')).read_text() for diagram in model['diagrams']], 'Audit embeds exactly the 11 current PlantUML sources')
    page = next(page for page in xml.findall('diagram') if page.get('id') == 'CD-06')
    id_refs = [cell for cell in page.findall('.//mxCell') if cell.get('umlKind') == 'idRef']
    check(len(id_refs) == 3 and not any(cell.get('edge') == '1' and 'dashed=1' in cell.get('style', '') for cell in page.findall('.//mxCell')), 'CD-06: three IDRef attributes and no dashed reference arrows')
    for name, instance in model['snapshot'].items():
        class_name = instance['class']
        for field, value in instance['slots'].items():
            check(field in models[class_name], name + ': slot ' + field)
            field_type = models[class_name][field][0].rstrip('?')
            if field_type in model['enums']:
                check(value in model['enums'][field_type], name + ': enum ' + field)
        for field, target in instance.get('links', {}).items():
            check(target in model['snapshot'] and models[class_name][field][0].rstrip('?') == model['snapshot'][target]['class'], name + ': legal link ' + field)
    invoice = model['snapshot']['hoaDon01']['slots']
    check(invoice['totalAmount'] == sum(invoice[field] for field in ['rentAmount', 'electricityAmount', 'waterAmount', 'otherAmount']), 'Object snapshot: invoice arithmetic')
    check(invoice['paidAmount'] == model['snapshot']['khoanThu01']['slots']['amount'] and invoice['status'] == 'PARTIAL' and model['snapshot']['minhChung01']['slots']['status'] == 'PENDING', 'Object snapshot: pending proof is not a payment')
    for filename in ['CLASS_DIAGRAM_REPORT_SECTION.docx', 'CLASS_DIAGRAM_SPECIFICATION.docx']:
        with ZipFile(BASE.parent / filename) as archive:
            text = archive.read('word/document.xml').decode()
            check('nét đứt' not in text, filename + ': no obsolete dashed reference notation')
            media = [archive.read(name) for name in archive.namelist() if name.startswith('word/media/')]
            expected = [(BASE / (diagram['id'].lower() + '.png')).read_bytes() for diagram in model['diagrams']]
            check(len(media) == 11 and {hashlib.sha256(image).hexdigest() for image in media} == {hashlib.sha256(image).hexdigest() for image in expected}, filename + ': all 11 images match current exports')
    print(json.dumps({'checks': len(checks), 'failures': failures, 'status': 'PASS' if not failures else 'FAIL'}, ensure_ascii=False, indent=2))
    return not failures


if __name__ == '__main__':
    sys.exit(0 if verify() else 1)
