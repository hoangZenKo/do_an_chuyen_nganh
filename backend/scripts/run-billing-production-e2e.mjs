import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { cpSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { PrismaClient } from '@prisma/client';

const source = new URL(process.env.DATABASE_URL ?? '');
if (!['postgresql:', 'postgres:'].includes(source.protocol) || !['localhost', '127.0.0.1', '[::1]'].includes(source.hostname)) throw new Error('Billing rehearsal supports only local PostgreSQL.');
const databaseName = `rental_billing_test_${Date.now()}_${randomBytes(6).toString('hex')}`;
const testUrl = new URL(source); testUrl.pathname = `/${databaseName}`; testUrl.search = '?schema=public';
const env = { ...process.env, NODE_ENV: 'test', DATABASE_URL: testUrl.toString(), BILLING_OUTBOX_WORKER_ENABLED: 'false', BILLING_AUTOMATION_WORKER_ENABLED: 'false', OPERATIONS_SCHEDULER_ENABLED: 'false', SUPPORT_SLA_WORKER_ENABLED: 'false', DELIVERY_WORKER_ENABLED: 'false', ADMIN_REPORT_WORKER_ENABLED: 'false', NOTIFICATION_DELIVERY_ENABLED: 'false', OPERATIONS_MONITOR_ENABLED: 'false', VIEWING_REMINDER_WORKER_ENABLED: 'false', ZALO_ZNS_ENABLED: 'false', CHATBOT_ENABLED: 'false' };
const pgEnv = { ...process.env, PGHOST: source.hostname.replace(/^\[|\]$/g, ''), PGPORT: source.port || '5432', PGUSER: decodeURIComponent(source.username), PGPASSWORD: decodeURIComponent(source.password), PGDATABASE: 'postgres', PGCONNECT_TIMEOUT: '10' };
env.MAINTENANCE_SLA_WORKER_ENABLED = 'false';
delete pgEnv.PGHOSTADDR; delete pgEnv.PGSERVICE; delete pgEnv.PGSERVICEFILE;
function run(command, args, options = {}) {
  const result = spawnSync(command, args, { env, stdio: 'inherit', ...options });
  if (result.error || result.status !== 0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}).`);
}
let created = false;
let temporary;
try {
  run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `CREATE DATABASE "${databaseName}"`], { env: pgEnv }); created = true;
  temporary = mkdtempSync(join(tmpdir(), 'rental-billing-rehearsal-'));
  cpSync('prisma/schema.prisma', join(temporary, 'schema.prisma'));
  for (const entry of readdirSync('prisma/migrations')) {
    if (entry >= '20261026150000_invoice_line_items_service_tariffs' && entry !== 'migration_lock.toml') continue;
    cpSync(join('prisma/migrations', entry), join(temporary, 'migrations', entry), { recursive: true });
  }
  run('npx', ['prisma', 'migrate', 'deploy', '--schema', join(temporary, 'schema.prisma')]);
  const legacy = new PrismaClient({ datasources: { db: { url: testUrl.toString() } } });
  const invoiceId = randomUUID();
  try {
    const owner = await legacy.user.create({ data: { fullName: 'Billing rehearsal owner', email: 'billing-rehearsal@example.test', passwordHash: 'not-for-login' } });
    const property = await legacy.property.create({ data: { landlordId: owner.id, name: 'Rehearsal property' } });
    const room = await legacy.room.create({ data: { propertyId: property.id, name: 'Legacy room' } });
    const tenant = await legacy.tenant.create({ data: { landlordId: owner.id, fullName: 'Legacy tenant' } });
    const lease = await legacy.lease.create({ data: { roomId: room.id, tenantId: tenant.id, startDate: new Date('2026-01-01Z'), monthlyRent: 1000000 } });
    await legacy.$executeRaw`INSERT INTO "Invoice" (id, "leaseId", "roomId", "tenantId", "billingMonth", "rentAmount", "electricityAmount", "waterAmount", "otherAmount", "totalAmount", "paidAmount", status, "updatedAt") VALUES (${invoiceId}, ${lease.id}, ${room.id}, ${tenant.id}, TIMESTAMP '2026-08-01', 1000000, 120000, 50000, 30000, 1200000, 300000, 'PARTIAL', NOW())`;
    await legacy.payment.create({ data: { invoiceId, amount: 300000, method: 'BANK_TRANSFER', note: 'Legacy receipt' } });
  } finally { await legacy.$disconnect(); }
  run('npx', ['prisma', 'migrate', 'deploy']);
  const migrated = new PrismaClient({ datasources: { db: { url: testUrl.toString() } } });
  try {
    const invoice = await migrated.invoice.findUniqueOrThrow({ where: { id: invoiceId }, include: { lineItems: true } });
    assert.equal(invoice.revision, 1); assert.equal(invoice.replacesInvoiceId, null);
    assert.equal(invoice.totalAmount, 1200000); assert.equal(invoice.paidAmount, 300000); assert.equal(invoice.status, 'PARTIAL');
    assert.equal(invoice.lineItems.length, 4); assert.ok(invoice.lineItems.every(line => line.source === 'LEGACY'));
    assert.equal(invoice.lineItems.reduce((sum, line) => sum + line.amount, 0), invoice.totalAmount);
    assert.equal(await migrated.payment.count({ where: { invoiceId } }), 1);
    assert.equal(await migrated.billingReceipt.count(), 0);
    console.log('Billing migration rehearsal: legacy invoice lines backfilled; totals, payment history and partial balance preserved.');
  } finally { await migrated.$disconnect(); }
  run('npx', ['prisma', 'migrate', 'diff', '--from-schema-datasource', 'prisma/schema.prisma', '--to-schema-datamodel', 'prisma/schema.prisma', '--exit-code']);
  run('npm', ['run', 'test:e2e', '--', 'billing-production.e2e-spec.ts', 'invoice-tariffs.e2e-spec.ts', 'admin-completion.e2e-spec.ts', 'staff-lifecycle.e2e-spec.ts', '--runInBand']);
} catch (error) {
  console.error(error.message); process.exitCode = 1;
} finally {
  if (temporary) rmSync(temporary, { recursive: true, force: true });
  if (created) {
    if (!/^rental_billing_test_\d+_[a-f0-9]+$/.test(databaseName)) throw new Error('Unsafe cleanup refused.');
    run('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-c', `DROP DATABASE "${databaseName}" WITH (FORCE)`], { env: pgEnv });
  }
}
