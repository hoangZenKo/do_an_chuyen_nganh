import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { accountE2eConfig } from './run-admin-accounts-e2e.mjs';

const { databaseName, env, pgEnv } = accountE2eConfig(process.env);
env.MAINTENANCE_SLA_WORKER_ENABLED = 'false';
env.DEMO_PAYMENTS_ENABLED = 'false';
const run = (command, args, commandEnv = env) => {
  const result = spawnSync(command, args, { cwd: fileURLToPath(new URL('..', import.meta.url)), env: commandEnv, stdio: 'inherit' });
  if (result.error || result.status !== 0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}).`);
};
let created = false;
try {
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], pgEnv);
  created = true;
  run('npx', ['--no-install', 'prisma', 'migrate', 'deploy']);
  run('npm', ['run', 'test:e2e', '--', '--runTestsByPath', 'test/e2e/manual-transfers.e2e-spec.ts', 'test/e2e/demo-card-payments.e2e-spec.ts']);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (created) {
    if (!/^rental_admin_accounts_test_\d+_[a-f0-9]{12}$/.test(databaseName)) throw new Error('Unsafe cleanup refused.');
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], pgEnv);
  }
}
