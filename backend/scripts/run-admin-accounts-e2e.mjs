import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

export function accountE2eConfig(sourceEnv) {
  let source;
  try { source = new URL(sourceEnv.DATABASE_URL ?? ''); }
  catch { throw new Error('DATABASE_URL must be a local PostgreSQL URL.'); }
  if (!['postgresql:', 'postgres:'].includes(source.protocol) ||
      !['localhost', '127.0.0.1', '[::1]'].includes(source.hostname) || source.pathname.length <= 1) {
    throw new Error('Admin account E2E requires a local PostgreSQL server and explicit source database.');
  }
  const databaseName = `rental_admin_accounts_test_${Date.now()}_${randomBytes(6).toString('hex')}`;
  const target = new URL(source);
  target.pathname = `/${databaseName}`;
  target.search = '?schema=public';
  const env = {
    ...sourceEnv, NODE_ENV: 'test', DATABASE_URL: target.toString(),
    ADMIN_MFA_REQUIRED: 'false', ADMIN_STEP_UP_REQUIRED: 'false',
    ADMIN_MFA_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString('base64'),
    AUTH_DELIVERY_WEBHOOK_URL: '', AUTH_DELIVERY_WEBHOOK_SECRET: '',
    AUTH_PUBLIC_APP_URL: '', DELIVERY_ENCRYPTION_KEY: '', OPERATIONS_ALERT_WEBHOOK_URL: '',
    SUPPORT_SLA_WORKER_ENABLED: 'false', DELIVERY_WORKER_ENABLED: 'false',
    ADMIN_REPORT_WORKER_ENABLED: 'false', NOTIFICATION_DELIVERY_ENABLED: 'false',
    OPERATIONS_MONITOR_ENABLED: 'false', BILLING_AUTOMATION_WORKER_ENABLED: 'false',
    BILLING_OUTBOX_WORKER_ENABLED: 'false', VIEWING_REMINDER_WORKER_ENABLED: 'false',
    OPERATIONS_SCHEDULER_ENABLED: 'false', ZALO_ZNS_ENABLED: 'false', CHATBOT_ENABLED: 'false',
  };
  const pgEnv = {
    ...sourceEnv, PGHOST: source.hostname.replace(/^\[|\]$/g, ''), PGPORT: source.port || '5432',
    PGUSER: decodeURIComponent(source.username), PGPASSWORD: decodeURIComponent(source.password),
    PGDATABASE: 'postgres', PGCONNECT_TIMEOUT: '10',
  };
  for (const key of ['PGHOSTADDR', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS']) delete pgEnv[key];
  return { databaseName, env, pgEnv };
}

export function runAdminAccountsE2e(sourceEnv = process.env, execute = spawnSync) {
  const { databaseName, env, pgEnv } = accountE2eConfig(sourceEnv);
  const run = (command, args, commandEnv = env) => {
    const result = execute(command, args, {
      cwd: fileURLToPath(new URL('..', import.meta.url)), env: commandEnv, stdio: 'inherit',
    });
    if (result.error || result.status !== 0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}).`);
  };
  let created = false;
  try {
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], pgEnv);
    created = true;
    run('npx', ['--no-install', 'prisma', 'migrate', 'deploy']);
    run('npm', ['run', 'test:e2e', '--', '--runTestsByPath',
      'test/e2e/admin-accounts.e2e-spec.ts', 'test/e2e/admin-inventory.e2e-spec.ts', 'test/e2e/admin-console.e2e-spec.ts',
      'test/e2e/admin-next-sprints.e2e-spec.ts', 'test/e2e/admin-operations-release.e2e-spec.ts',
      'test/e2e/admin-registry.e2e-spec.ts']);
  } finally {
    if (created) {
      if (!/^rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(databaseName)) throw new Error('Unsafe cleanup refused.');
      run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], pgEnv);
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try { runAdminAccountsE2e(); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
