import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';

let source;
try { source = new URL(process.env.DATABASE_URL ?? ''); }
catch { throw new Error('DATABASE_URL must be a valid local PostgreSQL URL.'); }
if (!['postgresql:', 'postgres:'].includes(source.protocol) ||
    !['localhost', '127.0.0.1', '[::1]'].includes(source.hostname)) {
  throw new Error('Settlement E2E only supports a local PostgreSQL server.');
}
const databaseName = `rental_settlement_test_${Date.now()}_${randomBytes(6).toString('hex')}`;
const testUrl = new URL(source);
testUrl.pathname = `/${databaseName}`;
testUrl.search = '?schema=public';
const env = {
  ...process.env, NODE_ENV: 'test', DATABASE_URL: testUrl.toString(),
  SUPPORT_SLA_WORKER_ENABLED: 'false', DELIVERY_WORKER_ENABLED: 'false',
  ADMIN_REPORT_WORKER_ENABLED: 'false', NOTIFICATION_DELIVERY_ENABLED: 'false',
  OPERATIONS_MONITOR_ENABLED: 'false', BILLING_AUTOMATION_WORKER_ENABLED: 'false',
  VIEWING_REMINDER_WORKER_ENABLED: 'false', OPERATIONS_SCHEDULER_ENABLED: 'false',
  ZALO_ZNS_ENABLED: 'false', CHATBOT_ENABLED: 'false',
};
const pgEnv = {
  ...process.env, PGHOST: source.hostname.replace(/^\[|\]$/g, ''), PGPORT: source.port || '5432',
  PGUSER: decodeURIComponent(source.username), PGPASSWORD: decodeURIComponent(source.password), PGDATABASE: 'postgres', PGCONNECT_TIMEOUT: '10',
};
delete pgEnv.PGHOSTADDR;
delete pgEnv.PGSERVICE;
delete pgEnv.PGSERVICEFILE;

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { env, stdio: 'inherit', ...options });
  if (result.error || result.status !== 0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}).`);
}

let created = false;
try {
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], { env: pgEnv });
  created = true;
  run('npx', ['prisma', 'migrate', 'deploy']);
  run('npm', ['run', 'test:e2e', '--', 'lease-settlement.e2e-spec.ts']);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (created) {
    if (!/^rental_settlement_test_\d+_[a-f0-9]+$/.test(databaseName)) throw new Error('Refusing unsafe cleanup.');
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], { env: pgEnv });
  }
}
