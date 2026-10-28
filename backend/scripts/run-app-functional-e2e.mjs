import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';

const source = new URL(process.env.DATABASE_URL ?? '');
if (!['postgres:', 'postgresql:'].includes(source.protocol) || !['localhost', '127.0.0.1', '[::1]'].includes(source.hostname)) {
  throw new Error('Functional tests require local PostgreSQL; remote databases are refused.');
}
const databaseName = `rental_functional_test_${Date.now()}_${randomBytes(6).toString('hex')}`;
const target = new URL(source);
target.pathname = `/${databaseName}`;
target.search = '?schema=public';
const env = { ...process.env, NODE_ENV: 'test', DATABASE_URL: target.toString() };
for (const name of ['BILLING_OUTBOX', 'BILLING_AUTOMATION', 'OPERATIONS_SCHEDULER', 'SUPPORT_SLA', 'DELIVERY', 'ADMIN_REPORT',
  'OPERATIONS_MONITOR', 'VIEWING_REMINDER', 'MAINTENANCE_SLA']) env[`${name}_WORKER_ENABLED`] = 'false';
Object.assign(env, { OPERATIONS_SCHEDULER_ENABLED: 'false', NOTIFICATION_DELIVERY_ENABLED: 'false',
  ZALO_ZNS_ENABLED: 'false', CHATBOT_ENABLED: 'false', AUTH_PUBLIC_APP_URL: 'https://app.example.test',
  AUTH_DELIVERY_WEBHOOK_URL: 'https://delivery.example.test', DELIVERY_ENCRYPTION_KEY: randomBytes(32).toString('base64') });
const pgEnv = { ...process.env, PGHOST: source.hostname.replace(/^\[|\]$/g, ''), PGPORT: source.port || '5432',
  PGUSER: decodeURIComponent(source.username), PGPASSWORD: decodeURIComponent(source.password), PGDATABASE: 'postgres', PGCONNECT_TIMEOUT: '10' };
delete pgEnv.PGSERVICE; delete pgEnv.PGSERVICEFILE; delete pgEnv.PGHOSTADDR;
function run(command, args, executionEnv = env) {
  const result = spawnSync(command, args, { env: executionEnv, stdio: 'inherit' });
  if (result.error || result.status !== 0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}).`);
}
let created = false;
try {
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], pgEnv);
  created = true;
  run('npx', ['prisma', 'migrate', 'deploy']);
  run('npx', ['prisma', 'migrate', 'diff', '--from-schema-datasource', 'prisma/schema.prisma', '--to-schema-datamodel', 'prisma/schema.prisma', '--exit-code']);
  run('npm', ['run', 'test:e2e', '--', 'app-functional.e2e-spec.ts', '--runInBand']);
} catch (error) {
  console.error(error.message); process.exitCode = 1;
} finally {
  if (created) {
    if (!/^rental_functional_test_\d+_[a-f0-9]+$/.test(databaseName)) throw new Error('Unsafe cleanup refused.');
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], pgEnv);
  }
}
