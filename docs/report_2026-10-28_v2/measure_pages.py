from pathlib import Path
import json
import re
import sys
import unicodedata
from pypdf import PdfReader

BASE = Path(__file__).resolve().parent


def normalize(text):
    return re.sub(r'\s+', ' ', unicodedata.normalize('NFC', text)).strip()


def measured(render):
    reader = PdfReader(next(render.glob('*.pdf')))
    texts = [page.extract_text() for page in reader.pages]
    main = next(index for index, text in enumerate(texts)
                if re.match(r'^1\s+1 Giới thiệu\s+1\.1 Đặt vấn đề', normalize(text)))
    normalized = [normalize(text) for text in texts]
    toc = {}
    for anchor, title, level in json.loads((BASE / 'toc-entries.json').read_text()):
        if title == 'Phân công thực hiện đồ án':
            hits = [index for index in range(main) if normalize(title) in normalized[index]
                    and 'Mẫu V1 yêu cầu bảng phân công' in normalized[index]]
        else:
            hits = [index for index in range(main, len(texts)) if normalize(title) in normalized[index]]
        if not hits:
            raise ValueError('Missing heading: ' + title)
        index = hits[0]
        toc[title] = str(index - main + 1) if index >= main else texts[index].strip().splitlines()[0]
    figures = {}
    for figure in json.loads((BASE / 'figure-entries.json').read_text()):
        hits = [index for index in range(main, len(texts))
                if normalize(figure['title']) in normalized[index]]
        if not hits:
            raise ValueError('Missing caption: ' + figure['title'])
        figures[figure['title']] = str(hits[0] - main + 1)
    return toc, figures, main, texts


if __name__ == '__main__':
    render = Path(sys.argv[1])
    toc, figures, main, texts = measured(render)
    (BASE / 'toc-pages.json').write_text(json.dumps(toc, ensure_ascii=False, indent=2))
    (BASE / 'figure-pages.json').write_text(json.dumps(figures, ensure_ascii=False, indent=2))
    print('Measured', len(texts), 'pages;', len(toc), 'headings;', len(figures), 'figures; main starts', main + 1)
