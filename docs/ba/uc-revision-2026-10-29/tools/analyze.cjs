const fs = require('node:fs');
const path = require('node:path');
const ts = require(path.resolve(__dirname, '../../../../backend/node_modules/typescript'));
const root = process.argv[2];
const out = path.resolve(__dirname, '../evidence');
function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const file = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
  }).sort();
}
const sources = walk(path.join(root, 'backend')).filter(file => file.endsWith('.ts'));
const classes = [];
const routes = [];
const tests = [];
const decorators = (node, source) => (ts.canHaveDecorators(node) ? ts.getDecorators(node) ?? [] : []).map(item => item.getText(source));
for (const file of sources) {
  const text = fs.readFileSync(file, 'utf8');
  const source = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true);
  const position = node => source.getLineAndCharacterOfPosition(node.getStart(source)).line + 1;
  const relative = path.relative(root, file);
  function visit(node) {
    if (ts.isClassDeclaration(node)) {
      const info = { file: relative, line: position(node), name: node.name?.text,
        decorators: decorators(node, source), bases: node.heritageClauses?.map(item => item.getText(source)) ?? [],
        fields: [], methods: [], injections: {} };
      for (const member of node.members) {
        if (ts.isConstructorDeclaration(member)) {
          for (const parameter of member.parameters) info.injections[parameter.name.getText(source)] = parameter.type?.getText(source);
        }
        if (ts.isPropertyDeclaration(member)) info.fields.push({ name: member.name.getText(source),
          type: member.type?.getText(source) ?? '', optional: !!member.questionToken,
          initializer: member.initializer?.getText(source), decorators: decorators(member, source), line: position(member) });
        if (ts.isMethodDeclaration(member)) info.methods.push({ name: member.name.getText(source),
          line: position(member), endLine: source.getLineAndCharacterOfPosition(member.end).line + 1,
          parameters: member.parameters.map(parameter => ({ name: parameter.name.getText(source), type: parameter.type?.getText(source), decorators: decorators(parameter, source) })),
          decorators: decorators(member, source), body: member.body?.getText(source) ?? '' });
      }
      classes.push(info);
      const controller = info.decorators.find(item => item.startsWith('@Controller('));
      if (controller) {
        const prefix = controller.match(/@Controller\(['"]([^'"]*)['"]\)/)?.[1] ?? '';
        for (const method of info.methods) {
          const decorator = method.decorators.find(item => /^@(Get|Post|Put|Patch|Delete|Head|Options)\(/.test(item));
          if (!decorator) continue;
          const match = decorator.match(/^@(\w+)\((?:['"]([^'"]*)['"])?/);
          const calls = [...method.body.matchAll(/this\.(\w+)\.(\w+)\(/g)].map(call => ({ field: call[1], type: info.injections[call[1]], method: call[2] }));
          const effective = key => method.decorators.find(item => item.startsWith(`@${key}(`)) ?? info.decorators.find(item => item.startsWith(`@${key}(`));
          routes.push({ id: `${info.name}.${method.name}`, file: relative, line: method.line,
            class: info.name, method: method.name, verb: match[1].toUpperCase(), path: '/api/v1/' + [prefix, match[2]].filter(Boolean).join('/').replace(/\/+/g, '/').replace(/^\//, ''),
            roles: effective('Roles') ?? '', adminPermissions: effective('AdminPermissions') ?? '', staffPermissions: effective('RequirePermissions') ?? '',
            decorators: method.decorators, parameters: method.parameters, calls });
        }
      }
    }
    if (/(?:\.spec|e2e-spec)\.ts$/.test(file) && ts.isCallExpression(node)) {
      const call = node.expression.getText(source);
      if (/^(it|test|describe)(\.(only|skip))?$/.test(call) && node.arguments[0] && ts.isStringLiteralLike(node.arguments[0])) {
        tests.push({ file: relative, line: position(node), kind: call, title: node.arguments[0].text });
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
}
fs.writeFileSync(path.join(out, 'analysis-index.json'), JSON.stringify({ classes, routes, tests }, null, 2));
console.log(JSON.stringify({ classes: classes.length, routes: routes.length, tests: tests.length, uniqueTests: new Set(tests.map(item => item.file)).size }));
