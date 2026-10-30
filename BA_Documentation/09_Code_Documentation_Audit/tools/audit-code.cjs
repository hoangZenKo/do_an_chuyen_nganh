const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../..');
const req = require('node:module').createRequire(path.join(root, 'backend/package.json'));
const ts = req('typescript');
const trace = JSON.parse(fs.readFileSync(path.join(root, 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/traceability.json')));
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'BA_Documentation/02_Functional_Decomposition_Use_Case_Catalog/data/catalog.json')));
const tests = JSON.parse(fs.readFileSync(path.join(__dirname, '../data/unit-tests-result.json')));
const symbols = new Map();
const routes = [];
function decorators(node) { return ts.canHaveDecorators(node) ? ts.getDecorators(node) || [] : []; }
function deco(node, name) {
  const found = decorators(node).find(item => ts.isCallExpression(item.expression) && item.expression.expression.getText() === name);
  return found ? [...found.expression.arguments].map(arg => arg.getText()) : null;
}
function listArgs(args) { return (args || []).map(arg => arg.replace(/^AuthRole\./, '').replace(/^['"]|['"]$/g, '')); }
for (const file of Object.keys(trace.sourceHashes).filter(file => file.endsWith('.ts') && file.startsWith('backend/src/'))) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const source = ts.createSourceFile(file, text, ts.ScriptTarget.Latest, true);
  source.forEachChild(node => {
    if (!ts.isClassDeclaration(node) || !node.name) return;
    const className = node.name.text;
    const constructor = node.members.find(member => ts.isConstructorDeclaration(member));
    const injected = Object.fromEntries((constructor?.parameters || []).filter(parameter => parameter.type).map(parameter => [parameter.name.getText(source), parameter.type.getText(source)]));
    for (const member of node.members) {
      if (!member.name || !member.body) continue;
      const method = member.name.getText(source);
      const binding = className + '.' + method;
      const calls = [];
      function visit(child) {
        if (ts.isCallExpression(child)) calls.push(child.expression.getText(source));
        ts.forEachChild(child, visit);
      }
      visit(member.body);
      const resolvedCalls = calls.map(call => {
        const match = /^this\.(\w+)\.(\w+)$/.exec(call);
        return match && injected[match[1]] ? injected[match[1]] + '.' + match[2] : call.startsWith('this.') && !call.slice(5).includes('.') ? className + call.slice(4) : null;
      }).filter(Boolean);
      const item = { binding, file, line: source.getLineAndCharacterOfPosition(member.name.getStart(source)).line + 1, declarationLine: source.getLineAndCharacterOfPosition(member.getStart(source)).line + 1, endLine: source.getLineAndCharacterOfPosition(member.end).line + 1, calls, resolvedCalls, text: member.getText(source) };
      symbols.set(binding, item);
      const verb = ['Get', 'Post', 'Put', 'Patch', 'Delete', 'Options', 'Head'].find(name => deco(member, name));
      if (!verb) continue;
      const roles = listArgs(deco(member, 'Roles') ?? deco(node, 'Roles'));
      const permissions = listArgs(deco(member, 'RequirePermissions') ?? deco(node, 'RequirePermissions'));
      const adminPermissions = listArgs(deco(member, 'AdminPermissions') ?? deco(node, 'AdminPermissions'));
      routes.push({ ...item, className, method, verb: verb.toUpperCase(), roles, permissions, adminPermissions, guards: deco(member, 'UseGuards') ?? deco(node, 'UseGuards') ?? [], controllerPath: listArgs(deco(node, 'Controller'))[0] || '', methodPath: listArgs(deco(member, verb))[0] || '' });
    }
  });
}
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true, emitDecoratorMetadata: false, esModuleInterop: true } }).outputText, filename);
req('reflect-metadata');
const { RolesGuard } = req(path.join(root, 'backend/src/common/roles.guard.ts'));
const { PropertyScopeInterceptor } = req(path.join(root, 'backend/src/common/property-scope.ts'));
const { ROLES_KEY } = req(path.join(root, 'backend/src/common/roles.constants.ts'));
const { PERMISSIONS_KEY, STAFF_PERMISSIONS } = req(path.join(root, 'backend/src/common/permissions.constants.ts'));
const { ADMIN_PERMISSIONS_KEY, ADMIN_PERMISSIONS } = req(path.join(root, 'backend/src/common/admin-permissions.ts'));
const { of, firstValueFrom } = req('rxjs');
async function probe(route, role, mode = 'granted') {
  const metadata = { [ROLES_KEY]: route.roles.length ? route.roles.map(value => value.toLowerCase()) : undefined, [PERMISSIONS_KEY]: route.permissions, [ADMIN_PERMISSIONS_KEY]: route.adminPermissions };
  const guard = new RolesGuard({ getAllAndOverride: key => metadata[key] });
  const actor = { userId: 'audit-user', role, landlordId: 'audit-landlord', propertyIds: ['audit-property'], permissions: mode === 'no-permissions' ? [] : role === 'STAFF' ? STAFF_PERMISSIONS : ADMIN_PERMISSIONS, adminMfaRequired: true, adminMfaVerified: mode !== 'mfa-missing' };
  actor.role = role.toLowerCase();
  const request = { user: actor, body: mode === 'scope-missing' ? {} : { propertyId: 'audit-property' }, query: {}, method: route.verb, originalUrl: '/api/v1/' + route.controllerPath + '/' + route.methodPath };
  const context = { getClass: () => ({ name: route.className }), getHandler: () => ({ name: route.method }), switchToHttp: () => ({ getRequest: () => request }) };
  let layer = 'roles-guard';
  try {
    const permitted = await guard.canActivate(context);
    if (!permitted) return { allowed: false, layer };
    layer = 'property-scope-interceptor';
    await firstValueFrom(new PropertyScopeInterceptor().intercept(context, { handle: () => of(true) }));
    return { allowed: true, layer: 'passed-tested-layers' };
  } catch (error) { return { allowed: false, layer, message: error.message, response: error.getResponse?.() }; }
}
(async () => {
  for (const route of routes) {
    route.accessProbes = {};
    for (const role of ['LANDLORD', 'STAFF', 'TENANT', 'ADMIN']) route.accessProbes[role] = await probe(route, role);
    if (route.roles.includes('STAFF')) {
      route.accessProbes.staffNoPermissions = await probe(route, 'STAFF', 'no-permissions');
      route.accessProbes.staffNoScopeInput = await probe(route, 'STAFF', 'scope-missing');
    }
    if (route.roles.includes('ADMIN')) {
      route.accessProbes.adminNoPermissions = await probe(route, 'ADMIN', 'no-permissions');
      route.accessProbes.adminNoMfa = await probe(route, 'ADMIN', 'mfa-missing');
    }
    delete route.text;
  }
  const byBinding = new Map(routes.map(route => [route.binding, route]));
  const perUc = trace.useCases.map(uc => {
    const evidence = [...uc.handlers.map(handler => ({ ...handler, symbol: handler.binding })), ...uc.services];
    const anchors = evidence.map(ref => {
      const actual = symbols.get(ref.symbol);
      return { symbol: ref.symbol, file: ref.file, declaredLine: ref.line, actualLine: actual?.line, exists: !!actual && actual.file === ref.file, lineWithinDeclaration: !!actual && ref.line >= actual.declarationLine && ref.line <= actual.endLine, calls: actual?.calls, resolvedCalls: actual?.resolvedCalls };
    });
    const handlers = uc.handlers.map(handler => {
      const actual = byBinding.get(handler.binding);
      const staff = actual?.accessProbes.STAFF;
      const expectedStaff = handler.staffAllowedAfterInterceptor;
      const comparison = expectedStaff === null || expectedStaff === undefined ? 'not-asserted' : staff?.allowed === expectedStaff ? 'match' : 'mismatch';
      return { binding: handler.binding, actual, expectedStaff, comparison };
    });
    const relatedTests = uc.relatedTestsNotRun.map(file => {
      const test = tests.testResults.find(result => path.relative(root, result.name) === file);
      return { file, execution: test ? test.status : 'not-run', passed: test?.assertionResults.filter(result => result.status === 'passed').length || 0, skipped: test?.assertionResults.filter(result => result.status === 'pending').length || 0 };
    });
    const queue = uc.handlers.map(handler => handler.binding);
    const reachable = new Set();
    while (queue.length) {
      const symbol = queue.shift();
      if (reachable.has(symbol)) continue;
      reachable.add(symbol);
      for (const callee of symbols.get(symbol)?.resolvedCalls || []) if (symbols.has(callee)) queue.push(callee);
    }
    const serviceReachability = uc.services.map(service => ({ symbol: service.symbol, reachable: reachable.has(service.symbol) }));
    return { id: uc.id, title: catalog.useCases.find(item => item.id === uc.id).title, anchors, handlers, serviceReachability, localOnly: !uc.handlers.length, relatedTests };
  });
  const hashChanges = Object.entries(trace.sourceHashes).filter(([file, hash]) => !fs.existsSync(path.join(root, file)) || crypto.createHash('sha256').update(fs.readFileSync(path.join(root, file))).digest('hex') !== hash).map(([file]) => file);
  const missing = perUc.flatMap(uc => uc.anchors.filter(anchor => !anchor.exists).map(anchor => ({ uc: uc.id, ...anchor })));
  const aclMismatches = perUc.flatMap(uc => uc.handlers.filter(handler => handler.comparison === 'mismatch').map(handler => ({ uc: uc.id, ...handler })));
  const result = { date: new Date().toISOString(), method: 'Independent TypeScript AST plus execution of actual RolesGuard and PropertyScopeInterceptor with mocked request. JWT, DTO, service, database and provider NOT executed by access probes. No Roles metadata does NOT imply public access.', totals: { useCases: perUc.length, routes: routes.length, anchors: perUc.reduce((sum, uc) => sum + uc.anchors.length, 0), missingAnchors: missing.length, aclMismatches: aclMismatches.length, sourceHashChanges: hashChanges.length, testsPassed: tests.numPassedTests, testsSkipped: tests.numPendingTests }, missing, aclMismatches, hashChanges, useCases: perUc, routes };
  fs.writeFileSync(path.join(__dirname, '../data/independent-code-audit.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result.totals, null, 2));
  console.log(JSON.stringify({ missing, aclMismatches: aclMismatches.map(item => ({ uc: item.uc, binding: item.binding, expectedStaff: item.expectedStaff, actual: item.actual?.accessProbes.STAFF })) }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });

