from pathlib import Path
import json
import re
import unicodedata
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'BA_Documentation/09_Code_Documentation_Audit'
PDF = next((WORK / 'QA/final-word').glob('*.pdf'))
NAV = json.loads((ROOT / 'BA_Documentation/07_Report_Completion/data/navigation.json').read_text())

def normalize(value):
    return re.sub(r'\s+', '', unicodedata.normalize('NFC', value)).replace('\u00ad', '')

reader = PdfReader(PDF)
texts = []
footers = []
for page in reader.pages:
    numbers = []
    def visitor(text, matrix, coordinates, font, size):
        if coordinates[5] < 60 and re.fullmatch(r'(?:\d+|[ivxlcdm]+)', text.strip()):
            numbers.append(text.strip())
    texts.append(page.extract_text(visitor_text=visitor))
    footers.append(numbers[0] if numbers else '')
normalized = [normalize(text) for text in texts]
mapping = {}
locations = {}
missing = []
for title, name, level in NAV['headings'] + NAV['captions']:
    matches = [index for index, text in enumerate(normalized) if normalize(title) in text]
    if not matches:
        missing.append(title)
        continue
    index = matches[-1]
    mapping[name] = footers[index] or str(index + 1)
    locations[name] = {'title': title, 'physicalPage': index + 1, 'number': mapping[name]}
changed = ['UC-SYS-05.1', 'UC-OPT-07.3', 'UC-TNT-05', 'UC-TNT-12.1', 'UC-ADM-18.1']
case_pages = {identifier: [index + 1 for index, text in enumerate(texts) if identifier in text and ('Đặc tả nghiệp vụ' in text or 'Thuộc tính' in text)] for identifier in changed}
result = {'pdfPageCount': len(reader.pages), 'pageMap': mapping, 'locations': locations, 'missing': missing, 'correctedUseCasePages': case_pages}
(WORK / 'data/audited-pagination.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'pages': len(reader.pages), 'navigation': len(mapping), 'missing': missing, 'correctedUseCasePages': case_pages}, ensure_ascii=False, indent=2))
assert not missing

