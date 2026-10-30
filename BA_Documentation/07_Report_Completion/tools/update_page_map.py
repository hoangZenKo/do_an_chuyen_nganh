from pathlib import Path
import json
import re
import sys
import unicodedata

from pypdf import PdfReader

WORK = Path('/Users/hoang/Rental_room_management/BA_Documentation/07_Report_Completion')

def normalize(value):
    return re.sub(r'\s+','',unicodedata.normalize('NFC',value)).replace('\u00ad','')

def main():
    pdf=PdfReader(sys.argv[1])
    texts=[]; footers=[]
    for page in pdf.pages:
        numbers=[]
        def visitor(text,cm,tm,font,size):
            if tm[5]<60 and re.fullmatch(r'(?:\d+|[ivxlcdm]+)',text.strip()):
                numbers.append(text.strip())
        texts.append(normalize(page.extract_text(visitor_text=visitor)))
        footers.append(numbers[0] if numbers else '')
    navigation=json.loads((WORK/'data/navigation.json').read_text())
    mapping={};locations={};missing=[]
    for title,name,level in navigation['headings']+navigation['captions']:
        candidates=[index for index,text in enumerate(texts) if normalize(title) in text]
        if not candidates:
            missing.append(title);continue
        index=candidates[-1]
        mapping[title]=footers[index] or str(index+1)
        locations[title]=index+1
    old=json.loads((WORK/'data/page-map.json').read_text())
    changed={key:{'before':old.get(key),'after':value} for key,value in mapping.items() if old.get(key)!=value}
    (WORK/'data/page-map.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2))
    result={'pdfPages':len(pdf.pages),'navigationEntries':len(mapping),'missing':missing,'changed':changed,'physicalLocations':locations}
    (WORK/'data/pagination-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    print(json.dumps({key:value for key,value in result.items() if key!='physicalLocations'},ensure_ascii=False,indent=2))
    assert not missing

if __name__=='__main__':main()
