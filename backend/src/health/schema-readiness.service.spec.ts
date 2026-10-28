import { createHash } from 'node:crypto';
import { mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { compareMigrations, migrationCatalog, MigrationRecord, SchemaReadinessService } from './schema-readiness.service';
import { HealthController } from './health.controller';

describe('Schema readiness release gate', () => {
  const catalog = [{ name: '20261025200000_auth_sessions', checksum: 'auth' }, { name: '20261026120000_incident_snooze_constraint', checksum: 'latest' }];
  const completed = catalog.map(entry => ({ migration_name: entry.name, checksum: entry.checksum, finished_at: new Date(), rolled_back_at: null }));

  it('requires every migration, not just the latest marker', () => {
    expect(compareMigrations(catalog, completed.slice(1))).toMatchObject({ ready: false, missing: [catalog[0].name] });
    expect(compareMigrations(catalog, completed)).toMatchObject({ ready: true });
    expect(compareMigrations([], [])).toMatchObject({ ready: false });
  });

  it('blocks checksum drift, failed migrations and a database newer than the API', () => {
    expect(compareMigrations(catalog, [{ ...completed[0], checksum: 'changed' }, completed[1]])).toMatchObject({ ready: false, drifted: [catalog[0].name] });
    expect(compareMigrations(catalog, [...completed, { ...completed[0], finished_at: null }])).toMatchObject({ ready: false, failed: [catalog[0].name] });
    expect(compareMigrations(catalog, [...completed, { ...completed[0], migration_name: 'unknown_migration' }])).toMatchObject({ ready: false, unexpected: ['unknown_migration'] });
    expect(compareMigrations(catalog, [...completed, { ...completed[0], finished_at: null, rolled_back_at: new Date() }])).toMatchObject({ ready: true });
  });

  it('loads only SQL migrations and fingerprints exact source bytes', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'rental-catalog-test-'));
    try {
      await mkdir(join(directory, catalog[0].name));
      await writeFile(join(directory, catalog[0].name, 'migration.sql'), 'SELECT 1;\n');
      await writeFile(join(directory, 'migration_lock.toml'), 'provider = "postgresql"');
      expect(await migrationCatalog(directory)).toEqual([{ name: catalog[0].name, checksum: createHash('sha256').update('SELECT 1;\n').digest('hex') }]);
    } finally { await rm(directory, { recursive: true, force: true }); }
  });

  it('keeps liveness available but returns sanitized 503 for incompatible schema', async () => {
    const schema = { inspect: jest.fn().mockResolvedValue({ ready: false, missing: ['private_schema_name'] }) };
    const controller = new HealthController({} as never, schema as never);
    expect(controller.live()).toEqual({ status: 'ok' });
    await expect(controller.ready()).rejects.toMatchObject({ status: 503, response: { status: 'error', database: 'unavailable' } });
    schema.inspect.mockResolvedValue({ ready: true });
    await expect(controller.ready()).resolves.toEqual({ status: 'ok', database: 'ok' });
  });

  it('checks the actual auth schema even with a complete migration history', async () => {
    const actual = await migrationCatalog(join(__dirname, '../../prisma/migrations'));
    const records: MigrationRecord[] = actual.map(entry => ({ migration_name: entry.name, checksum: entry.checksum, finished_at: new Date(), rolled_back_at: null }));
    const prisma = { $queryRaw: jest.fn().mockResolvedValueOnce(records).mockResolvedValueOnce([{ ready: false }]) };
    expect(await new SchemaReadinessService(prisma as never).inspect()).toMatchObject({ ready: false, authSchemaReady: false, missing: [], failed: [] });
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(2);
  });

  it('keeps billing readiness tied to receipt reconciliation and maintenance SLA columns', async () => {
    const actual = await migrationCatalog(join(__dirname, '../../prisma/migrations'));
    const records: MigrationRecord[] = actual.map(entry => ({ migration_name: entry.name, checksum: entry.checksum, finished_at: new Date(), rolled_back_at: null }));
    const prisma = { $queryRaw: jest.fn().mockResolvedValueOnce(records).mockResolvedValueOnce([{ ready: true }]).mockResolvedValueOnce([{ ready: false }]) };
    const result = await new SchemaReadinessService(prisma as never).inspect();
    expect(result).toMatchObject({ ready: false, authSchemaReady: true, billingSchemaReady: false });
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(3);
  });
});
