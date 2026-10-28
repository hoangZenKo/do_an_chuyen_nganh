import { Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { PrismaService } from '../prisma/prisma.service';

export interface MigrationRecord {
  migration_name: string;
  checksum: string;
  finished_at: Date | null;
  rolled_back_at: Date | null;
}

export async function migrationCatalog(directory: string) {
  const entries = await readdir(directory, { withFileTypes: true });
  const catalog = await Promise.all(entries.filter(entry => entry.isDirectory() && /^\d{14}_[a-z0-9_]+$/.test(entry.name)).map(async entry => ({
    name: entry.name,
    checksum: createHash('sha256').update(await readFile(resolve(directory, entry.name, 'migration.sql'))).digest('hex'),
  })));
  if (!catalog.length) throw new Error('Migration catalog is empty.');
  return catalog.sort((left, right) => left.name.localeCompare(right.name));
}

export function compareMigrations(catalog: { name: string; checksum: string }[], records: MigrationRecord[]) {
  const applied = records.filter(record => record.finished_at && !record.rolled_back_at);
  const expected = new Set(catalog.map(entry => entry.name));
  const missing = catalog.filter(entry => !applied.some(record => record.migration_name === entry.name)).map(entry => entry.name);
  const drifted = catalog.filter(entry => applied.some(record => record.migration_name === entry.name && record.checksum !== entry.checksum)).map(entry => entry.name);
  const failed = records.filter(record => !record.finished_at && !record.rolled_back_at).map(record => record.migration_name);
  const unexpected = applied.filter(record => !expected.has(record.migration_name)).map(record => record.migration_name);
  return { ready: catalog.length > 0 && ![missing, drifted, failed, unexpected].some(entries => entries.length), missing, drifted, failed, unexpected };
}

@Injectable()
export class SchemaReadinessService {
  constructor(private readonly prisma: PrismaService) {}

  async inspect() {
    let catalog: Awaited<ReturnType<typeof migrationCatalog>> | undefined;
    for (const directory of [resolve(__dirname, '../../prisma/migrations'), resolve(__dirname, '../../../prisma/migrations')]) {
      try { catalog = await migrationCatalog(directory); break; }
      catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error; }
    }
    if (!catalog) throw new Error('Migration catalog is unavailable. Ship prisma/migrations with the API.');
    const records = await this.prisma.$queryRaw<MigrationRecord[]>`SELECT migration_name, checksum, finished_at, rolled_back_at FROM "_prisma_migrations"`;
    const migrations = compareMigrations(catalog, records);
    let authSchemaReady = false;
    let billingSchemaReady = false;
    if (migrations.ready) {
      const checks = await this.prisma.$queryRaw<{ ready: boolean }[]>`
        SELECT COUNT(*) = 4 AS ready FROM information_schema.columns
        WHERE table_schema = 'public' AND (table_name, column_name) IN
          (('AuthSession', 'userVersion'), ('RefreshToken', 'sessionId'), ('AdminProfile', 'accessReviewedAt'), ('User', 'sessionVersion'))`;
      authSchemaReady = checks[0]?.ready === true;
      if (authSchemaReady) {
        const billing = await this.prisma.$queryRaw<{ ready: boolean }[]>`
          SELECT (
            (SELECT COUNT(*) = 9 FROM information_schema.columns WHERE table_schema = 'public' AND
              (table_name, column_name) IN (('Invoice', 'revision'), ('Invoice', 'replacesInvoiceId'), ('BillingReceipt', 'availableAmount'), ('BillingOutboxEvent', 'leaseUntil'), ('FinanceStatementLine', 'receiptId'), ('FinanceReconciliationProposal', 'receiptId'), ('MaintenanceTicket', 'assigneeStaffProfileId'), ('MaintenanceTicket', 'dueAt'), ('MaintenanceTicket', 'escalatedAt')))
            AND (SELECT COUNT(*) = 3 FROM pg_trigger WHERE NOT tgisinternal AND tgname IN ('InvoiceLineItem_immutable', 'BillingTariffVersion_immutable', 'maintenance_sla_deadline_trigger'))
          ) AS ready`;
        billingSchemaReady = billing[0]?.ready === true;
      }
    }
    return { ...migrations, ready: migrations.ready && authSchemaReady && billingSchemaReady, authSchemaReady, billingSchemaReady, catalogSize: catalog.length, checkedAt: new Date().toISOString() };
  }
}
