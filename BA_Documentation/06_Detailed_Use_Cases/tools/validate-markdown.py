import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from markdown_it import MarkdownIt


document_root = Path(__file__).resolve().parent.parent
manifest = json.loads((document_root / 'data/spec-manifest.json').read_text(encoding='utf-8'))
parser = MarkdownIt('commonmark').enable('table')
expected = {
    'heading_open': 1,
    'table_open': 1,
    'thead_open': 1,
    'tbody_open': 1,
    'th_open': 2,
    'td_open': 40,
    'tr_open': 21,
}
results = []
for specification in manifest['useCases']:
    source = document_root / specification['file']
    content = source.read_bytes()
    tokens = parser.parse(content.decode('utf-8'))
    counts = {name: sum(token.type == name for token in tokens) for name in expected}
    results.append({
        'file': specification['file'],
        'sha256': hashlib.sha256(content).hexdigest(),
        'counts': counts,
        'success': counts == expected,
    })

report = {
    'checkedAt': datetime.now(timezone.utc).isoformat(),
    'parser': 'markdown-it-py / commonmark + table',
    'scope': 'Markdown AST: one table, two headers, twenty data rows; not Word/PDF visual QA or application runtime verification.',
    'success': len(results) == manifest['scope']['expectedCount'] and all(result['success'] for result in results),
    'files': results,
}
(document_root / 'Markdown_Parse_Result.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8',
)
print(json.dumps({'success': report['success'], 'files': len(results)}, indent=2))
if not report['success']:
    raise SystemExit(1)
