const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');

const root = path.resolve(__dirname, '../../../..');
const output = path.resolve(__dirname, '../evidence');
const ts = require(path.join(root, 'backend/node_modules/typescript'));
const relative = (file) => path.relative(root, file).split(path.sep).join('/');
const hash = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function walk(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
  }).sort();
}
const files = ['backend/src', 'backend/test', 'backend/prisma', 'lib', 'test', 'integration_test']
  .flatMap((directory) => walk(path.join(root, directory)))
  .filter((file) => /\.(ts|dart|prisma|sql)$/.test(file));
const snapshotFile = path.join(output, 'source-snapshot.json');
if (process.argv.includes('--check')) {
  const snapshot = JSON.parse(fs.readFileSync(snapshotFile, 'utf8'));
  const previous = new Map(snapshot.files.map((entry) => [entry.file, entry.sha256]));
  const current = new Map(files.map((file) => [relative(file), hash(file)]));
  const changed = [...new Set([...previous.keys(), ...current.keys()])]
    .filter((file) => previous.get(file) !== current.get(file));
  console.log(JSON.stringify({ unchanged: changed.length === 0, changed }, null, 2));
  process.exit(changed.length ? 1 : 0);
}
if (fs.existsSync(snapshotFile)) throw new Error('Snapshot exists; use --check instead of overwriting evidence.');
fs.mkdirSync(output, { recursive: true });
const line = (source, node) => source.getLineAndCharacterOfPosition(node.getStart(source)).line + 1;
const decorators = (node, source) => (ts.canHaveDecorators(node) ? ts.getDecorators(node) ?? [] : [])
  .map((decorator) => decorator.getText(source));
const routes = [];
const methods = [];
const tests = [];
for (const file of files.filter((entry) => entry.endsWith('.ts'))) {
  const text = fs.readFileSync(file, 'utf8');
  const source = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true);
  function visit(node) {
    if (ts.isClassDeclaration(node)) {
      const classDecorators = decorators(node, source);
      const controller = classDecorators.find((entry) => entry.startsWith('@Controller('));
      const prefix = controller?.match(/@Controller\(['"]([^'"]*)['"]\)/)?.[1] ?? '';
      for (const member of node.members) {
        if (!ts.isMethodDeclaration(member)) continue;
        const memberDecorators = decorators(member, source);
        const body = member.body?.getText(source) ?? '';
        const calls = [...body.matchAll(/this\.([\w]+)\.([\w]+)\(/g)].map((match) => `${match[1]}.${match[2]}`);
        const entry = {
          file: relative(file), line: line(source, member), class: node.name?.text,
          method: member.name.getText(source), decorators: memberDecorators,
          calls: [...new Set(calls)],
          errors: [...body.matchAll(/throw new (\w+Exception)\(([^\n]*)/g)].map((match) => `${match[1]}(${match[2]}`),
          transaction: body.includes('$transaction'),
        };
        methods.push(entry);
        for (const decorator of memberDecorators) {
          const route = decorator.match(/^@(Get|Post|Patch|Put|Delete|Head|Options|All)\((?:['"]([^'"]*)['"])?/);
          if (!controller || !route) continue;
          routes.push({ ...entry, verb: route[1].toUpperCase(),
            route: `/api/v1/${[prefix, route[2] ?? ''].filter(Boolean).join('/')}`.replace(/\/{2,}/g, '/'),
            classDecorators,
            parameters: member.parameters.map((parameter) => parameter.getText(source)),
          });
        }
      }
    }
    if (/\.spec\.ts$/.test(file) && ts.isCallExpression(node)) {
      const name = node.expression.getText(source);
      if (/^(describe|it|test)(\.(each|skip|only))?$/.test(name) && node.arguments[0] && ts.isStringLiteralLike(node.arguments[0])) {
        tests.push({ file: relative(file), line: line(source, node), kind: name, name: node.arguments[0].text });
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
}
const schema = fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8');
const database = [...schema.matchAll(/^(model|enum) (\w+) \{([\s\S]*?)^\}/gm)].map((match) => ({
  kind: match[1], name: match[2], line: schema.slice(0, match.index).split('\n').length,
  definition: match[0],
}));
const flutterTests = files.filter((file) => file.endsWith('_test.dart')).map((file) => ({ file: relative(file) }));
const json = (name, data) => fs.writeFileSync(path.join(output, name), JSON.stringify(data, null, 2) + '\n');
json('source-snapshot.json', {
  capturedAt: new Date().toISOString(), businessDate: '2026-10-29', timezone: 'Asia/Ho_Chi_Minh',
  commit: childProcess.execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  warning: 'Working tree, including uncommitted and untracked source; not a production snapshot.',
  files: files.map((file) => ({ file: relative(file), sha256: hash(file) })),
});
json('routes.json', routes);
json('methods.json', methods);
json('database.json', database);
json('test-inventory.json', { backend: tests, flutterFiles: flutterTests, executed: false });
fs.writeFileSync(path.join(output, 'routes.tsv'), ['Verb\tRoute\tController\tMethod\tSource\tCalls',
  ...routes.map((entry) => [entry.verb, entry.route, entry.class, entry.method, `${entry.file}:${entry.line}`, entry.calls.join(', ')].join('\t')),
].join('\n') + '\n');
console.log(JSON.stringify({ sourceFiles: files.length, routes: routes.length,
  controllers: new Set(routes.map((entry) => entry.class)).size,
  models: database.filter((entry) => entry.kind === 'model').length,
  enums: database.filter((entry) => entry.kind === 'enum').length,
  backendTestFiles: new Set(tests.map((entry) => entry.file)).size, flutterTestFiles: flutterTests.length }, null, 2));
