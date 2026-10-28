import { randomBytes } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { PrismaClient } from '@prisma/client';

let source;
try { source = new URL(process.env.DATABASE_URL ?? ''); }
catch { throw new Error('DATABASE_URL must be a valid local PostgreSQL URL.'); }
if (!['postgresql:', 'postgres:'].includes(source.protocol) ||
    !['localhost', '127.0.0.1', '[::1]'].includes(source.hostname)) {
  throw new Error('Invoice/tariff E2E only supports a local PostgreSQL server.');
}
const databaseName = `rental_invoice_test_${Date.now()}_${randomBytes(6).toString('hex')}`;
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
let temporary;
try {
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], { env: pgEnv });
  created = true;
  temporary = mkdtempSync(join(tmpdir(), 'rental-tariff-migration-'));
  cpSync('prisma/schema.prisma', join(temporary, 'schema.prisma'));
  for (const entry of readdirSync('prisma/migrations')) {
    if (entry === '20261026150000_invoice_line_items_service_tariffs') continue;
    cpSync(join('prisma/migrations', entry), join(temporary, 'migrations', entry), { recursive: true });
  }
  run('npx', ['prisma', 'migrate', 'deploy', '--schema', join(temporary, 'schema.prisma')]);
  const legacy = new PrismaClient({ datasources: { db: { url: testUrl.toString() } } });
  let invoiceId;
  let feeId;
  try {
    const owner = await legacy.user.create({ data: { fullName: 'Migration rehearsal', email: 'tariff-migration@example.test', passwordHash: 'not-a-login-hash' } });
    const property = await legacy.property.create({ data: { landlordId: owner.id, name: 'Migration fixture' } });
    const room = await legacy.room.create({ data: { propertyId: property.id, name: 'Old room' } });
    const tenant = await legacy.tenant.create({ data: { landlordId: owner.id, fullName: 'Migration tenant' } });
    const lease = await legacy.lease.create({ data: { roomId: room.id, tenantId: tenant.id, startDate: new Date('2026-08-01Z'), monthlyRent: 1_000_000 } });
    invoiceId = (await legacy.invoice.create({ data: { roomId: room.id, tenantId: tenant.id, leaseId: lease.id, billingMonth: new Date('2026-08-01Z'), rentAmount: 1_000_000, electricityAmount: 20_000, waterAmount: 30_000, otherAmount: 100_000, totalAmount: 1_150_000 } })).id;
    feeId = (await legacy.roomServiceFee.create({ data: { roomId: room.id, name: 'Legacy Internet', amount: 75_000 } })).id;
  } finally { await legacy.$disconnect(); }
  run('npx', ['prisma', 'migrate', 'deploy']);
  const migrated = new PrismaClient({ datasources: { db: { url: testUrl.toString() } } });
  try {
    const invoice = await migrated.invoice.findUniqueOrThrow({ where: { id: invoiceId }, include: { lineItems: true } });
    assert.equal(invoice.lineItems.length, 4);
    assert.equal(invoice.lineItems.reduce((total, line) => total + line.amount, 0), invoice.totalAmount);
    assert.ok(invoice.lineItems.every((line) => line.source === 'LEGACY' && line.tariffVersionId === null));
    const tariff = await migrated.serviceTariffVersion.findFirstOrThrow({ where: { serviceFeeId: feeId } });
    assert.equal(tariff.amount, 75_000);
    assert.equal(tariff.version, 1);
    assert.equal(tariff.effectiveFrom.toISOString().slice(0, 10), '1970-01-01');
    console.log('Legacy invoice/tariff backfill rehearsal passed in the disposable database.');
  } finally { await migrated.$disconnect(); }
  run('npm', ['run', 'test:e2e', '--', 'invoice-tariffs.e2e-spec.ts']);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (temporary) rmSync(temporary, { recursive: true, force: true });
  if (created) {
    if (!/^rental_invoice_test_\d+_[a-f0-9]+$/.test(databaseName)) throw new Error('Refusing unsafe cleanup.');
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], { env: pgEnv });
  }
}
