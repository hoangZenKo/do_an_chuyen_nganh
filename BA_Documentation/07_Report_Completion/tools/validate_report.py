from pathlib import Path
from collections import Counter
from zipfile import ZipFile
import json
import re
import hashlib

from docx import Document

ROOT = Path('/Users/hoang/Rental_room_management')
WORK = ROOT / 'BA_Documentation/07_Report_Completion'
SOURCE = Path('/Users/hoang/Desktop/ĐỒ ÁN/Bao_cao_Quan_ly_Nha_tro_V3_2026-10-28.docx')
OUTPUT = SOURCE.with_name('Bao_cao_Quan_ly_Nha_tro_V4_2026-10-29_BA.docx')

def main():
    catalog = json.loads((ROOT / 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json').read_text())
    content = json.loads((WORK / 'data/business-report-content.json').read_text())
    diagrams = json.loads((WORK / 'data/report-diagrams.json').read_text())
    canonical = json.loads((ROOT / 'BA_Documentation/05_Use_Case_Diagrams/data/diagram-manifest.json').read_text())
    checks = []
    def check(name,passed,detail=''):
        checks.append({'name':name,'passed':bool(passed),**({'detail':detail} if detail else {})})
    check('Original Word unchanged',hashlib.sha256(SOURCE.read_bytes()).hexdigest()=='198de27e5e6f96734a12125d2c8e3dc1e9c653e82cab2f30dabe8b402cdb3c31')
    check('162 unique Use Cases',len(content['useCases'])==len({u['id'] for u in content['useCases']})==162)
    check('Catalog ID equality',{u['id'] for u in content['useCases']}=={u['id'] for u in catalog['useCases']})
    lookup={u['id']:u for u in catalog['useCases']}
    check('Unchanged status distribution',Counter(u['status'] for u in content['useCases'])==Counter(u['status'] for u in catalog['useCases']))
    for record in content['useCases']:
        identifier=record['id']; original=lookup[identifier]
        check(identifier+' 20 attributes',len(record['fields'])==20)
        check(identifier+' unchanged actor and status',all(record[key]==original[key] for key in ['primaryActorIds','supportingActorIds','status']) and record['groupId']==original['businessGroup'])
        text=' '.join(record['fields'].values())
        check(identifier+' business wording',not re.search(r'\b(?:API|DTO|JWT|MFA|RBAC|Controller|Service|handler|endpoint|runtime|snapshot|token|transaction|webhook|outbox|rollback|frontend|backend|schema|worker|decorator)\b|(?:backend/src|lib/features)/',text,re.I))
        main_steps=re.findall(r'^B(\d+) —',record['fields']['Luồng thành công chính'],re.M)
        check(identifier+' consecutive main steps',list(map(int,main_steps))==list(range(1,len(main_steps)+1)))
        references=re.findall(r'B(\d+)',record['fields']['Luồng thay thế']+' '+record['fields']['Luồng ngoại lệ'])
        check(identifier+' branch references valid',all(1<=int(value)<=len(main_steps) for value in references))
        check(identifier+' evidence exists',(ROOT/'BA_Documentation/06_Detailed_Use_Cases'/record['evidenceFile']).exists())
    declared=[]; observed=set()
    expected=set()
    def alias(identifier):return identifier.replace('-','_').replace('.','_')
    for diagram in canonical['diagrams']:
        if diagram['kind']=='module':
            for association in diagram['associations']:
                expected.add((association['actorId'],alias(association['ucId']),association['kind']))
    variant_pairs={(a,u) for a,u,k in expected if k=='limited'}
    for entry in diagrams:
        text=(WORK/'diagrams'/entry['file']).read_text()
        declared_aliases={alias(value) for value in entry['ucIds']}
        actors=set(re.findall(r'^actor .* as ([AE]\d+)$',text,re.M))
        actual=set(re.findall(r'^\s*usecase .* as (UC_\w+)',text,re.M))
        check(entry['id']+' declarations equal manifest',actual==declared_aliases)
        check(entry['id']+' rendered image exists',(WORK/'diagrams'/entry['file'].replace('.puml','.png')).exists())
        if entry['kind']=='module':declared.extend(entry['ucIds'])
        for line in text.splitlines():
            if not re.match(r'^(?:[AE]\d+|UC_\w+)\s+.*--|^(?:[AE]\d+|UC_\w+)\s+.*-\[#',line):continue
            endpoints=re.findall(r'\b(?:[AE]\d+|UC_\w+)\b',line.split(' : ')[0])
            check(entry['id']+' no undeclared association '+str(endpoints),set(endpoints).issubset(actual|actors))
            if entry['kind']!='module':continue
            actor=next(value for value in endpoints if re.fullmatch(r'[AE]\d+',value))
            identifier=next(value for value in endpoints if value.startswith('UC_'))
            kind='supporting' if actor.startswith('E') else ('limited' if (actor,identifier) in variant_pairs else 'primary')
            observed.add((actor,identifier,kind))
    check('Module diagrams cover every UC exactly once',Counter(declared)==Counter(u['id'] for u in content['useCases']))
    check('All report associations equal canonical associations',observed==expected,str(sorted(expected-observed)))
    doc=Document(OUTPUT)
    tables=[table for table in doc.tables if len(table.rows)==21 and table.rows[0].cells[0].text=='Thuộc tính']
    check('Exactly 162 continuous specification tables',len(tables)==162)
    word_cases={table.rows[1].cells[1].text:table for table in tables}
    check('All specification IDs present',set(word_cases)==set(lookup))
    for record in content['useCases']:
        table=word_cases.get(record['id'])
        if table is None:continue
        values={row.cells[0].text:row.cells[1].text for row in table.rows[1:]}
        check(record['id']+' Word values equal reviewed content',values==record['fields'])
        check(record['id']+' repeated header identifies UC',record['id'] in table.rows[0].cells[1].text and bool(table.rows[0]._tr.xpath('./w:trPr/w:tblHeader')))
    protected=json.loads((ROOT/'BA_Documentation/06_Detailed_Use_Cases/data/protected-hashes.json').read_text())
    changed=[name for name,hashvalue in protected['hashes'].items() if not (ROOT/name).exists() or hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=hashvalue]
    check('Protected source Catalog and canonical UML unchanged',not changed,', '.join(changed))
    with ZipFile(OUTPUT) as archive:
        check('Word archive integrity',archive.testzip() is None)
    result={'date':'2026-10-29','output':str(OUTPUT),'checks':len(checks),'passed':sum(item['passed'] for item in checks),'failed':[item for item in checks if not item['passed']],'useCaseCount':162,'groupCount':16,'humanActorCount':5,'reportDiagramCount':len(diagrams),'statusDistribution':dict(Counter(u['status'] for u in content['useCases'])),'checksDetail':checks,'limits':'Đối chiếu nội dung và cấu trúc báo cáo; không phải kết quả nghiệm thu ứng dụng.'}
    (WORK/'Validation_Result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({key:value for key,value in result.items() if key!='checksDetail'},ensure_ascii=False,indent=2))
    assert not result['failed']

if __name__=='__main__':main()
