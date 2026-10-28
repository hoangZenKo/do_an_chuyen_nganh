import assert from 'node:assert/strict';
import test from 'node:test';
import { accountE2eConfig, runAdminAccountsE2e } from './run-admin-accounts-e2e.mjs';

const source = 'postgresql://operator:secret@localhost:5432/rental_management?schema=custom';

test('uses a fresh database and keeps the working database unchanged', () => {
  const first = accountE2eConfig({ DATABASE_URL: source });
  const second = accountE2eConfig({ DATABASE_URL: source });
  assert.notEqual(first.databaseName, second.databaseName);
  assert.match(first.databaseName, /^rental_admin_accounts_test_\d+_[a-f0-9]{12}$/);
  assert.ok(first.databaseName.length <= 63);
  const target = new URL(first.env.DATABASE_URL);
  assert.equal(target.pathname, `/${first.databaseName}`);
  assert.equal(target.search, '?schema=public');
  assert.equal(new URL(source).pathname, '/rental_management');
  assert.equal(first.pgEnv.PGDATABASE, 'postgres');
});

test('rejects missing, non-PostgreSQL and non-local database sources', () => {
  for (const url of ['', 'not-a-url', 'https://localhost/working',
    'postgresql://operator@production.example/working',
    'postgresql://operator@localhost.attacker.example/working',
    'postgresql://operator@localhost/']) {
    assert.throws(() => accountE2eConfig({ DATABASE_URL: url }));
  }
});

test('disables background workers and removes inherited provider configuration', () => {
  const { env, pgEnv } = accountE2eConfig({ DATABASE_URL: source, NODE_ENV: 'production',
    AUTH_DELIVERY_WEBHOOK_URL: 'https://real.example/mail', AUTH_DELIVERY_WEBHOOK_SECRET: 'real-secret',
    DELIVERY_ENCRYPTION_KEY: 'real-key', AUTH_PUBLIC_APP_URL: 'https://real.example',
    ADMIN_STEP_UP_REQUIRED: 'true', PGHOSTADDR: 'remote-host', PGSERVICE: 'production', PGOPTIONS: '-c role=admin' });
  assert.equal(env.NODE_ENV, 'test');
  assert.equal(env.ADMIN_STEP_UP_REQUIRED, 'false');
  assert.equal(env.DELIVERY_WORKER_ENABLED, 'false');
  assert.equal(env.NOTIFICATION_DELIVERY_ENABLED, 'false');
  assert.equal(env.BILLING_OUTBOX_WORKER_ENABLED, 'false');
  assert.equal(env.AUTH_DELIVERY_WEBHOOK_URL, '');
  assert.equal(env.AUTH_DELIVERY_WEBHOOK_SECRET, '');
  assert.equal(env.DELIVERY_ENCRYPTION_KEY, '');
  assert.equal(env.AUTH_PUBLIC_APP_URL, '');
  assert.equal(pgEnv.PGHOSTADDR, undefined);
  assert.equal(pgEnv.PGSERVICE, undefined);
  assert.equal(pgEnv.PGOPTIONS, undefined);
});

test('supports loopback IPv6 and encoded credentials without leaking source options', () => {
  const { pgEnv, env } = accountE2eConfig({ DATABASE_URL: 'postgresql://test%40user:p%40ss@[::1]:5433/working?host=remote' });
  assert.equal(pgEnv.PGHOST, '::1');
  assert.equal(pgEnv.PGPORT, '5433');
  assert.equal(pgEnv.PGUSER, 'test@user');
  assert.equal(pgEnv.PGPASSWORD, 'p@ss');
  assert.equal(new URL(env.DATABASE_URL).searchParams.has('host'), false);
});

test('migrates only the fresh database and drops that exact database after success', () => {
  const calls = [];
  runAdminAccountsE2e({ DATABASE_URL: source }, (command, args, options) => {
    calls.push({ command, args, ...options });
    return { status: 0 };
  });
  assert.equal(calls.length, 4);
  const name = new URL(calls[1].env.DATABASE_URL).pathname.slice(1);
  assert.equal(calls[0].args.at(-1), `CREATE DATABASE "${name}"`);
  assert.deepEqual(calls[1].args, ['--no-install', 'prisma', 'migrate', 'deploy']);
  assert.equal(calls[2].env.DATABASE_URL, calls[1].env.DATABASE_URL);
  assert.ok(calls[2].args.includes('--runTestsByPath'));
  assert.ok(calls[2].args.includes('test/e2e/admin-inventory.e2e-spec.ts'));
  assert.equal(calls[3].args.at(-1), `DROP DATABASE "${name}" WITH (FORCE)`);
});

for (const failureAt of [0, 1, 2]) {
  test(`fails closed and cleans up only if database creation succeeded (step ${failureAt})`, () => {
    const calls = [];
    assert.throws(() => runAdminAccountsE2e({ DATABASE_URL: source }, (command, args, options) => {
      calls.push({ command, args, ...options });
      return { status: calls.length - 1 === failureAt ? 1 : 0 };
    }));
    const cleanup = calls.filter(call => call.args.at(-1).startsWith('DROP DATABASE'));
    assert.equal(cleanup.length, failureAt === 0 ? 0 : 1);
    if (cleanup.length) assert.equal(cleanup[0].args.at(-1).match(/"([^"]+)"/)[1],
      calls[0].args.at(-1).match(/"([^"]+)"/)[1]);
  });
}
