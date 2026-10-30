const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');

const documentRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(documentRoot, '../..');
const readJson = (filename) => JSON.parse(fs.readFileSync(filename, 'utf8'));
const manifest = readJson(path.join(documentRoot, 'data/spec-manifest.json'));
const baseline = readJson(path.join(documentRoot, 'data/protected-hashes.json'));
const catalog = readJson(path.join(repositoryRoot, 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json'));
const diagramManifest = readJson(path.join(repositoryRoot, 'BA_Documentation/05_Use_Case_Diagrams/data/diagram-manifest.json'));
const tests = readJson(path.join(documentRoot, 'Test_Execution_Result.json'));
const markdownParse = readJson(path.join(documentRoot, 'Markdown_Parse_Result.json'));
const checks = [];
const evidenceFiles = new Set();
const check = (name, passed, detail = '') => checks.push({ name, passed: Boolean(passed), ...(detail ? { detail } : {}) });
const equalSets = (left, right) => JSON.stringify([...left].sort()) === JSON.stringify([...right].sort());
const expected = catalog.useCases;
const moduleDiagrams = diagramManifest.diagrams.filter((diagram) => diagram.kind === 'module');
const splitRow = (row) => row.split(/(?<!\\)\|/).slice(1, -1).map((value) => value.trim());
const numbered = (value, prefix) => [...value.matchAll(new RegExp('(?:^|<br>)' + prefix + '(\\d+) —', 'g'))].map((match) => Number(match[1]));
const consecutive = (numbers) => numbers.every((value, index) => value === index + 1);

check('scope: Catalog IDs exactly match specification manifest', equalSets(expected.map((record) => record.id), manifest.useCases.map((record) => record.id)));
check('scope: 162 specifications in 16 groups', expected.length === 162 && manifest.useCases.length === 162 && manifest.groups.length === 16);
check('scope: full system specified, no remaining', catalog.useCases.length === manifest.scope.completedCount && manifest.scope.remainingCount === 0);
check('scope: unique IDs', new Set(manifest.useCases.map((record) => record.id)).size === expected.length);
const onDisk = fs.readdirSync(documentRoot, { recursive: true }).filter((filename) => /(?:^|[\\/])UC-.*\.md$/.test(filename)).map((filename) => filename.replaceAll('\\', '/')).sort();
check('scope: exactly all UC files on disk', equalSets(onDisk, manifest.useCases.map((record) => record.file)));
for (const group of manifest.groups) {
  const records = manifest.useCases.filter((record) => record.groupId === group.id);
  check('group coverage: ' + group.id, records.length === group.ucCount && records.every((record) => record.file.startsWith(group.directory + '/')));
}

for (const spec of manifest.useCases) {
  const canonical = expected.find((record) => record.id === spec.id);
  const filename = path.join(documentRoot, spec.file);
  const text = fs.readFileSync(filename, 'utf8');
  const lines = text.trimEnd().split('\n');
  const rows = lines.filter((line) => line.startsWith('|'));
  const dataRows = rows.slice(2).map(splitRow);
  const values = Object.fromEntries(dataRows);
  const prefix = spec.id + ': ';
  check(prefix + 'single title then continuous table', lines[0] === '# ' + spec.id + ' — ' + canonical.title && lines[1] === '' && lines.slice(2).every((line) => line.startsWith('|')));
  check(prefix + 'exactly one table header and separator', text.split('| Thuộc tính | Nội dung đặc tả |').length === 2 && rows.filter((row) => /^\|\s*-+\s*\|\s*-+\s*\|$/.test(row)).length === 1);
  check(prefix + 'exactly 20 rows and two columns', rows.length === 22 && rows.every((row) => splitRow(row).length === 2));
  check(prefix + '20 unique fields in required order', equalSets(dataRows.map((row) => row[0]), manifest.format.fields) && dataRows.every((row, index) => row[0] === manifest.format.fields[index]));
  check(prefix + 'all fields nonempty', dataRows.every((row) => row[1] && row[1].trim().length > 0));
  check(prefix + 'ID and title from Catalog', values['Mã Use Case'] === canonical.id && values['Tên Use Case'] === canonical.title && spec.title === canonical.title);
  check(prefix + 'primary Actor exact from Catalog', values['Tác nhân chính'] === canonical.primaryActor && equalSets(spec.primaryActorIds, canonical.primaryActorIds));
  check(prefix + 'supporting Actor exact from Catalog', equalSets(spec.supportingActorIds, canonical.supportingActorIds) && (spec.supportingActorIds.length ? spec.supportingActorIds.every((actor) => values['Tác nhân phối hợp'].includes(actor)) : values['Tác nhân phối hợp'] === 'Không áp dụng'));
  check(prefix + 'goal unchanged', values['Mục tiêu nghiệp vụ'] === canonical.goal);
  check(prefix + 'status unchanged, static limit stated', spec.status === canonical.status && values['Truy vết source code và trạng thái xác minh'].includes('Trạng thái Catalog: ' + canonical.status + '.') && values['Truy vết source code và trạng thái xác minh'].includes('đối chiếu tĩnh'));
  const steps = numbered(values['Luồng thành công chính'], 'B');
  const alternatives = numbered(values['Luồng thay thế'], 'A');
  const exceptions = numbered(values['Luồng ngoại lệ'], 'E');
  const rules = [...values['Quy tắc nghiệp vụ'].matchAll(/(?:^|<br>)BR-(\d+) —/g)].map((match) => Number(match[1]));
  check(prefix + 'main steps B1..Bn consecutive', steps.length >= 3 && consecutive(steps));
  check(prefix + 'alternatives consecutive or not applicable', values['Luồng thay thế'] === 'Không áp dụng' || (alternatives.length > 0 && consecutive(alternatives)));
  check(prefix + 'exceptions E1..En consecutive', exceptions.length > 0 && consecutive(exceptions));
  check(prefix + 'business rules BR-01.. consecutive', rules.length > 0 && consecutive(rules));
  for (const field of ['Luồng thay thế', 'Luồng ngoại lệ']) {
    for (const branch of values[field].split('<br>')) {
      if (branch === 'Không áp dụng') continue;
      const references = [...branch.matchAll(/B(\d+)/g)].map((match) => Number(match[1]));
      check(prefix + field + ' branch has valid main origin: ' + branch.slice(0, 3), references.length > 0 && references.every((reference) => steps.includes(reference)));
    }
  }
  const tracing = values['Truy vết source code và trạng thái xác minh'];
  const labels = new Set([...tracing.matchAll(/(?:^|<br>)([A-Z][A-Z0-9-]*) —/g)].map((match) => match[1]));
  const prose = text.replace(/(`+)[\s\S]*?\1/g, '');
  const usedLabels = new Set([...prose.matchAll(/\[([A-Z][A-Z0-9-]*(?:, [A-Z][A-Z0-9-]*)*)\]/g)].flatMap((match) => match[1].split(', ')));
  check(prefix + 'all source labels declared in same table', [...usedLabels].every((label) => labels.has(label)), [...usedLabels].filter((label) => !labels.has(label)).join(', '));
  const evidence = [...tracing.matchAll(/\x60([^\x60]+):(\d+)\x60/g)];
  const hasTestEvidenceOrGap = evidence.some((match) => /(?:\.(?:e2e-)?spec\.ts|_test\.dart)$/.test(match[1])) || tracing.includes('Chưa xác minh được từ source code test trực tiếp');
  check(prefix + 'explicit multi-layer evidence or documented test gap', spec.localOnly ? evidence.length >= 3 && tracing.includes('/lib/') && tracing.includes('DB —') && tracing.includes('API — Không áp dụng') && hasTestEvidenceOrGap : evidence.length >= 10 && tracing.includes('/lib/') && tracing.includes('/backend/src/') && tracing.includes('/backend/prisma/schema.prisma:') && hasTestEvidenceOrGap);
  for (const match of evidence) {
    const sourcePath = match[1];
    const sourceLine = Number(match[2]);
    let valid = false;
    if (path.isAbsolute(sourcePath) && sourcePath.startsWith(repositoryRoot + path.sep) && fs.existsSync(sourcePath)) {
      const lineCount = fs.readFileSync(sourcePath, 'utf8').split('\n').length;
      valid = sourceLine >= 1 && sourceLine <= lineCount;
      evidenceFiles.add(path.relative(repositoryRoot, sourcePath));
    }
    check(prefix + 'source path/line exists: ' + path.relative(repositoryRoot, sourcePath) + ':' + sourceLine, valid);
  }
  const diagrams = moduleDiagrams.filter((diagram) => diagram.ucIds.includes(spec.id));
  check(prefix + 'exactly one module diagram', diagrams.length === 1);
  const associations = diagrams.flatMap((diagram) => diagram.associations.filter((association) => association.ucId === spec.id));
  check(prefix + 'UML primary associations match', equalSets(associations.filter((association) => association.kind === 'primary').map((association) => association.actorId), canonical.primaryActorIds));
  check(prefix + 'UML supporting associations match', equalSets(associations.filter((association) => association.kind === 'supporting').map((association) => association.actorId), canonical.supportingActorIds));
  check(prefix + 'no invented include/extend', diagrams.every((diagram) => diagram.relationships.length === 0) && values['Quan hệ với Use Case khác'].includes('include'));
}

for (const [relativePath, expectedHash] of Object.entries(manifest.preservedG01SpecHashes)) {
  const actualHash = crypto.createHash('sha256').update(fs.readFileSync(path.join(repositoryRoot, relativePath))).digest('hex');
  check('preserved G01 table: ' + relativePath, actualHash === expectedHash);
}
const analysis = readJson(path.join(documentRoot, 'data/behavioral-analysis.json'));
check('behavioral analysis covers exactly G02-G16', equalSets(analysis.useCases.map((record) => record.id), expected.filter((record) => record.businessGroup !== 'G01').map((record) => record.id)));
for (const record of analysis.useCases) {
  check('analysis: specific flow and rules for ' + record.id, record.steps.length >= 3 && record.exceptions.length > 0 && record.rules.length > 0 && Boolean(record.post));
}

const changedFiles = [];
const missingFiles = [];
for (const [relativePath, expectedHash] of Object.entries(baseline.hashes)) {
  const absolutePath = path.join(repositoryRoot, relativePath);
  if (!fs.existsSync(absolutePath)) { missingFiles.push(relativePath); continue; }
  const actualHash = crypto.createHash('sha256').update(fs.readFileSync(absolutePath)).digest('hex');
  if (actualHash !== expectedHash) changedFiles.push(relativePath);
}
check('integrity: protected source/Catalog/UML unchanged', changedFiles.length === 0 && missingFiles.length === 0, [...changedFiles, ...missingFiles].join(', '));
check('integrity: protected source count 846', baseline.sourceFileCount === 846);
const gitDiff = childProcess.execFileSync('git', ['diff', 'HEAD', '--name-status'], { cwd: repositoryRoot, encoding: 'utf8' }).trim().split('\n').filter(Boolean);
const unauthorized = gitDiff.filter((record) => {
  const [status, relativePath] = record.split('\t');
  return !(status === 'D' && manifest.allowedTrackedDeletion.includes(relativePath));
});
check('integrity: only user-approved tracked deletion', unauthorized.length === 0, unauthorized.join('\n'));
check('tests: fresh unit/mock record, 71 suites / 736 tests', tests.success && tests.passedSuites === 71 && tests.totalSuites === 71 && tests.passedTests === 736 && tests.totalTests === 736 && tests.suites.length === tests.totalSuites && tests.suites.reduce((count, suite) => count + suite.tests.length, 0) === tests.totalTests && tests.suites.every((suite) => suite.tests.every((test) => test.status === 'passed')));
check('Markdown AST: all 162 parsed specifications', markdownParse.success && equalSets(markdownParse.files.map((record) => record.file), manifest.useCases.map((record) => record.file)));
for (const parsed of markdownParse.files) {
  const actualHash = crypto.createHash('sha256').update(fs.readFileSync(path.join(documentRoot, parsed.file))).digest('hex');
  check('Markdown AST current file: ' + parsed.file, parsed.success && parsed.sha256 === actualHash && parsed.counts.table_open === 1 && parsed.counts.th_open === 2 && parsed.counts.td_open === 40 && parsed.counts.tr_open === 21);
}
for (const report of ['README.md', 'Coverage_Matrix.md', 'Quality_Review.md', 'Verification_Method.md', ...manifest.groups.flatMap((group) => [group.directory + '/README.md', group.directory + '/Quality_Review.md'])]) check('reports: ' + report, fs.existsSync(path.join(documentRoot, report)));
const integrity = { checkedAt: new Date().toISOString(), snapshotCommit: baseline.snapshotCommit, sourceFileCount: baseline.sourceFileCount, protectedFileCount: Object.keys(baseline.hashes).length, changedFiles, missingFiles, trackedDiff: gitDiff, approvedDeletion: manifest.allowedTrackedDeletion, success: changedFiles.length === 0 && missingFiles.length === 0 && unauthorized.length === 0 };
fs.writeFileSync(path.join(documentRoot, 'Source_Integrity_Result.json'), JSON.stringify(integrity, null, 2) + '\n');
const result = { checkedAt: new Date().toISOString(), scope: manifest.scope, checkCount: checks.length, passed: checks.filter((record) => record.passed).length, failed: checks.filter((record) => !record.passed).length, evidenceFileCount: evidenceFiles.size, limits: 'Kiểm cấu trúc/truy vết và hash, không chứng minh đủ ngữ nghĩa hoặc runtime/DB/provider.', checks };
fs.writeFileSync(path.join(documentRoot, 'Validation_Result.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ checks: result.checkCount, passed: result.passed, failed: result.failed, evidenceFiles: result.evidenceFileCount, integrity: integrity.success }, null, 2));
if (result.failed) { console.error(JSON.stringify(checks.filter((record) => !record.passed), null, 2)); process.exitCode = 1; }
