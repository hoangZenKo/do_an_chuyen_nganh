import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  assertLocalDatabase, databaseForRun, discoverRoutes, resolveRoute,
  parseOptions, runCase, writeReport, finder, loginDelay, stopOwned,
} from './system_demo.mjs';

test('refuses remote PostgreSQL and non-PostgreSQL before preparing data', () => {
  for (const url of ['postgres://u:p@prod.example/db', 'file:///tmp/db', '', 'postgres://u:p@localhost.evil/db']) {
    assert.throws(() => assertLocalDatabase(url));
  }
  assert.equal(assertLocalDatabase('postgresql://u:p@127.0.0.1:5432/personal').hostname, '127.0.0.1');
});

test('creates a new database name, never rewrites or truncates the source database', () => {
  const url = databaseForRun('postgresql://u:p@localhost/personal?schema=private', '1234', 'abcdef123456');
  assert.equal(new URL(url).pathname, '/rental_ui_test_1234_abcdef123456');
  assert.equal(new URL(url).search, '?schema=public');
  assert.throws(() => databaseForRun('postgres://u:p@localhost/personal', '1234', 'bad;DROP'));
});

test('delay defaults to visible speed; invalid CLI options are refused', () => {
  assert.equal(parseOptions([]).delay, 2000);
  assert.equal(parseOptions(['--delay=500', '--sections=login,screens']).delay, 500);
  assert.throws(() => parseOptions(['--delay=-1']));
  assert.throws(() => parseOptions(['--sections=unknown']));
  assert.throws(() => parseOptions(['--made-up']));
});

test('inventory discovers registered routes, excludes constants never registered', () => {
  const routes = discoverRoutes("const loginRoute = '/auth/login';\nconst detailRoute = '/rooms/:id';\nconst unusedRoute = '/unused';", 'GoRoute(path: loginRoute, builder: foo), GoRoute(path: detailRoute, builder: bar)');
  assert.deepEqual(routes.map(item => item.path), ['/auth/login', '/rooms/:id']);
  assert.throws(() => discoverRoutes('', 'GoRoute(path: missingRoute, builder: foo)'));
});

test('route fixture substitution is strict and encoded', () => {
  assert.equal(resolveRoute('/rooms/:id', { roomId: 'room 1' }), '/rooms/room%201');
  assert.throws(() => resolveRoute('/rooms/:id', {}));
  assert.equal(resolveRoute('/admin/properties/:id', { propertyId: 'p1' }), '/admin/properties/p1');
});

test('serializes Flutter finders without lossy base64 conversions', () => {
  assert.deepEqual(JSON.parse(Buffer.from(finder('Text', 'Sửa chữa'), 'base64').toString()), {
    finderType: 'DemoFinder', kind: 'Text', value: 'Sửa chữa', index: '0',
  });
});

test('assertion failures and unmet dependencies cannot become successful cases', async () => {
  const results = [];
  await runCase(results, 'broken', 'UI', [], async () => { throw new Error('Expected 0, got 1'); });
  let called = false;
  await runCase(results, 'dependent', 'UI', ['broken'], async () => { called = true; });
  assert.equal(results[0].status, 'failed');
  assert.match(results[0].error, /Expected 0/);
  assert.equal(results[1].status, 'blocked');
  assert.equal(called, false);
});

test('fast validation still respects the real login rate limit', () => {
  assert.equal(loginDelay([], 1000), 0);
  assert.equal(loginDelay([0, 1, 2, 3, 4, 5, 6, 7], 1000), 60000);
  assert.equal(loginDelay([0, 1, 2, 3, 4, 5, 6, 7], 62000), 0);
});

test('process-group cleanup falls back without aborting report generation', () => {
  let signal;
  const child = { pid: 123456, exitCode: null, kill: value => { signal = value; return true; } };
  stopOwned(child, (pid, value) => {
    assert.equal(pid, -123456); assert.equal(value, 'SIGTERM');
    throw Object.assign(new Error('group unavailable'), { code: 'EPERM' });
  });
  assert.equal(signal, 'SIGTERM');
  assert.doesNotThrow(() => stopOwned({ ...child, exitCode: 0 }, () => { throw new Error('must not kill exited child'); }));
});

test('reports separate screen smoke from business tests and escape HTML', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'rental-demo-report-'));
  try {
    const report = await writeReport(directory, [
      { id: '<unsafe>', layer: 'screen', status: 'passed' },
      { id: 'payment', layer: 'UI', status: 'blocked', error: '<not run>' },
    ], { routes: [{ path: '/billing' }], runId: 'test' });
    assert.equal(report.success, false);
    const html = await readFile(join(directory, 'report.html'), 'utf8');
    assert.ok(html.includes('&lt;unsafe&gt;'));
    assert.ok(!html.includes('<unsafe>'));
    assert.equal(JSON.parse(await readFile(join(directory, 'report.json'), 'utf8')).results.length, 2);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('successful selected checks never certify untested functionality', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'rental-demo-coverage-'));
  try {
    const report = await writeReport(directory, [{ id: 'login', layer: 'UI', status: 'passed' }], {
      runId: 'partial', selectedSections: ['login'], pendingCoverage: ['Native picker not tested'],
    });
    assert.equal(report.success, true);
    assert.equal(report.allFunctionsVerified, false);
    assert.ok(report.notSelectedSections.includes('billing'));
    assert.deepEqual(report.counts, { passed: 1, failed: 0, blocked: 0 });
  } finally { await rm(directory, { recursive: true, force: true }); }
});
