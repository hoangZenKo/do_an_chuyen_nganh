import { spawn } from 'node:child_process';
import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';
import { createReadStream, createWriteStream } from 'node:fs';
import { chmod, mkdir, mkdtemp, readFile, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { pipeline } from 'node:stream/promises';
import { fileURLToPath } from 'node:url';
import { offsiteConfiguration, uploadOffsiteBackup } from './offsite-backup.mjs';
import { publishBackupTelemetry, telemetryConfiguration } from './backup-telemetry.mjs';

const backendRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export function databaseConfig(raw, env = process.env) {
  const url = new URL(raw ?? '');
  if (!['postgresql:', 'postgres:'].includes(url.protocol)) throw new Error('DATABASE_URL must be PostgreSQL.');
  const database = decodeURIComponent(url.pathname.slice(1));
  if (!/^[A-Za-z][A-Za-z0-9_]{2,62}$/.test(database)) throw new Error('Use an explicit safe database name.');
  const pgEnv = { ...env, PGHOST: url.hostname, PGPORT: url.port || '5432', PGDATABASE: database,
    PGUSER: decodeURIComponent(url.username), PGPASSWORD: decodeURIComponent(url.password), PGCONNECT_TIMEOUT: '10' };
  if (url.searchParams.has('sslmode')) pgEnv.PGSSLMODE = url.searchParams.get('sslmode');
  return { database, env: pgEnv };
}

export function encryptionKey(raw) {
  const key = Buffer.from(raw ?? '', 'base64');
  if (key.length !== 32) throw new Error('BACKUP_ENCRYPTION_KEY must encode 32 bytes.');
  return key;
}

function pgProcess(name, args, env) {
  const executable = process.env.PG_BIN_DIR ? join(process.env.PG_BIN_DIR, name) : name;
  const child = spawn(executable, args, { env, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stderr.resume();
  const done = new Promise((success, failure) => {
    child.on('error', () => failure(new Error(`${name} could not start. Check PG_BIN_DIR/toolchain.`)));
    child.on('close', code => code === 0 ? success() : failure(new Error(`${name} failed. No credentials or raw database errors logged.`)));
  });
  return { child, done };
}

async function pgRun(name, args, env) {
  const { child, done } = pgProcess(name, args, env);
  child.stdout.resume();
  await done;
}

async function digest(path) {
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest('hex');
}

export async function verifyBackup(manifestFile, key) {
  const manifest = JSON.parse(await readFile(manifestFile, 'utf8'));
  if (manifest.format !== 'rental-pg-aes-gcm-v1' || basename(manifest.file ?? '') !== manifest.file || !/^[a-zA-Z0-9_.-]+\.dump\.enc$/.test(manifest.file)) throw new Error('Invalid backup manifest.');
  const archive = join(dirname(resolve(manifestFile)), manifest.file);
  if (await digest(archive) !== manifest.sha256) throw new Error('Backup checksum mismatch.');
  const nonce = Buffer.from(manifest.nonce, 'base64');
  const tag = Buffer.from(manifest.tag, 'base64');
  if (nonce.length !== 12 || tag.length !== 16) throw new Error('Invalid backup encryption metadata.');
  const directory = await mkdtemp(join(tmpdir(), 'rental-restore-'));
  await chmod(directory, 0o700);
  const plaintext = join(directory, 'verified.dump');
  try {
    const decipher = createDecipheriv('aes-256-gcm', key, nonce);
    decipher.setAAD(Buffer.from(JSON.stringify({ database: manifest.database, createdAt: manifest.createdAt })));
    decipher.setAuthTag(tag);
    await pipeline(createReadStream(archive), decipher, createWriteStream(plaintext, { flags: 'wx', mode: 0o600 }));
    return { manifest, plaintext, cleanup: () => rm(directory, { recursive: true, force: true }) };
  } catch {
    await rm(directory, { recursive: true, force: true });
    throw new Error('Backup authentication failed. No restore was attempted.');
  }
}

export async function backup() {
  offsiteConfiguration();
  const telemetry = telemetryConfiguration();
  if (telemetry && !offsiteConfiguration()) throw new Error('Signed backup telemetry requires durable off-site storage.');
  const config = databaseConfig(process.env.DATABASE_URL);
  const key = encryptionKey(process.env.BACKUP_ENCRYPTION_KEY);
  const directory = resolve(process.env.BACKUP_DIR || join(backendRoot, '.backups'));
  await mkdir(directory, { recursive: true, mode: 0o700 });
  await chmod(directory, 0o700);
  const createdAt = new Date().toISOString();
  const file = `${config.database}-${createdAt.replace(/[:.]/g, '-')}-${randomBytes(4).toString('hex')}.dump.enc`;
  const pending = join(directory, `${file}.partial`);
  const archive = join(directory, file);
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from(JSON.stringify({ database: config.database, createdAt })));
  const { child, done } = pgProcess('pg_dump', ['--format=custom', '--no-owner', '--no-privileges'], config.env);
  try {
    await Promise.all([pipeline(child.stdout, cipher, createWriteStream(pending, { flags: 'wx', mode: 0o600 })), done]);
    await rename(pending, archive);
    const manifest = { format: 'rental-pg-aes-gcm-v1', file, database: config.database, createdAt,
      nonce: nonce.toString('base64'), tag: cipher.getAuthTag().toString('base64'), sha256: await digest(archive), bytes: (await stat(archive)).size };
    await writeFile(`${archive}.json`, JSON.stringify(manifest, null, 2), { mode: 0o600, flag: 'wx' });
    const offsite = await uploadOffsiteBackup(`${archive}.json`);
    if (telemetry) {
      const verified = await verifyBackup(`${archive}.json`, key);
      try { await publishBackupTelemetry(verified.manifest, offsite); }
      finally { await verified.cleanup(); }
    }
    console.log(JSON.stringify({ backupManifest: `${archive}.json`, bytes: manifest.bytes, offsiteDurable: offsite?.durable ?? false }));
    return `${archive}.json`;
  } catch (error) {
    child.kill('SIGTERM');
    await rm(pending, { force: true });
    throw error;
  }
}

export function restoreTargetUrl(source, target) {
  const config = databaseConfig(source);
  if (!/^[A-Za-z][A-Za-z0-9_]{2,62}$/.test(target) || !/(_test|restore_check)/i.test(target) || target === config.database) throw new Error('Restore target must be a separate test/restore_check database.');
  const url = new URL(source);
  url.pathname = `/${target}`;
  return url.toString();
}

async function rehearseMigrations(databaseUrl) {
  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient({ datasourceUrl: databaseUrl });
  try {
    const before = await prisma.user.count();
    const preflight = await migrationPreflight(prisma);
    const child = spawn(process.execPath, [join(backendRoot, 'node_modules/prisma/build/index.js'), 'migrate', 'deploy'], {
      cwd: backendRoot, env: { ...process.env, DATABASE_URL: databaseUrl }, stdio: 'ignore',
    });
    await new Promise((success, failure) => {
      const timeout = setTimeout(() => { child.kill('SIGTERM'); failure(new Error('Migration rehearsal timed out.')); }, 240000);
      child.on('error', () => { clearTimeout(timeout); failure(new Error('Could not start migration rehearsal.')); });
      child.on('close', code => { clearTimeout(timeout); code === 0 ? success() : failure(new Error('Migration rehearsal failed on the isolated restore target.')); });
    });
    if ((await migrationPreflight(prisma)).pending.length || await prisma.user.count() !== before) throw new Error('Migration rehearsal validation failed.');
    await prisma.authSession.count();
    await prisma.adminProfile.findFirst({ select: { accessReviewedAt: true } });
    await prisma.refreshToken.findFirst({ select: { sessionId: true } });
    return { migrationsApplied: preflight.pending, userCountPreserved: true, authSchemaReady: true };
  } finally { await prisma.$disconnect(); }
}

export async function restoreCheck(manifestFile, rehearsal = false) {
  if (process.env.ALLOW_RESTORE_CHECK !== 'true') throw new Error('Set ALLOW_RESTORE_CHECK=true for an isolated restore drill.');
  const config = databaseConfig(process.env.DATABASE_URL);
  const target = process.env.RESTORE_CHECK_DATABASE || `rental_restore_check_${Date.now()}`;
  const targetUrl = restoreTargetUrl(process.env.DATABASE_URL, target);
  const verified = await verifyBackup(manifestFile, encryptionKey(process.env.BACKUP_ENCRYPTION_KEY));
  let created = false;
  try {
    await pgRun('pg_restore', ['--list', verified.plaintext], config.env);
    await pgRun('createdb', ['--maintenance-db=postgres', '--', target], { ...config.env, PGDATABASE: 'postgres' });
    created = true;
    const targetEnv = { ...config.env, PGDATABASE: target };
    await pgRun('pg_restore', ['--dbname', target, '--single-transaction', '--exit-on-error', '--no-owner', '--no-privileges', verified.plaintext], targetEnv);
    await pgRun('psql', ['--no-psqlrc', '--set=ON_ERROR_STOP=1', '--command', 'SELECT COUNT(*) FROM "_prisma_migrations"; SELECT COUNT(*) FROM "User";'], targetEnv);
    const migrations = rehearsal ? await rehearseMigrations(targetUrl) : undefined;
    console.log(JSON.stringify({ restoreCheck: 'passed', targetDatabase: target, sourceDatabaseUntouched: true, ...(rehearsal ? { migrationRehearsal: migrations } : {}) }));
  } finally {
    try {
      if (created) await pgRun('dropdb', ['--maintenance-db=postgres', '--', target], { ...config.env, PGDATABASE: 'postgres' });
    } finally {
      await verified.cleanup();
    }
  }
}

export async function migrationPreflight(prisma) {
  const files = (await readdir(join(backendRoot, 'prisma/migrations'), { withFileTypes: true })).filter(entry => entry.isDirectory()).map(entry => entry.name).sort();
  const applied = await prisma.$queryRawUnsafe('SELECT migration_name, checksum, finished_at, rolled_back_at FROM "_prisma_migrations"');
  if (applied.some(row => !row.finished_at && !row.rolled_back_at)) throw new Error('Unfinished/failed migration exists; investigate before deploy.');
  for (const row of applied.filter(item => item.finished_at && !item.rolled_back_at)) {
    if (!files.includes(row.migration_name)) throw new Error('Applied migration is missing from source.');
    const hash = createHash('sha256').update(await readFile(join(backendRoot, 'prisma/migrations', row.migration_name, 'migration.sql'))).digest('hex');
    if (hash !== row.checksum) throw new Error('Applied migration checksum differs from source.');
  }
  const complete = new Set(applied.filter(row => row.finished_at && !row.rolled_back_at).map(row => row.migration_name));
  return { pending: files.filter(name => !complete.has(name)), driftCheck: 'migration-history-only', readOnly: true };
}

async function migrate(manifestFile) {
  const config = databaseConfig(process.env.DATABASE_URL);
  if (process.env.MIGRATION_CONFIRM_DATABASE !== config.database) throw new Error('MIGRATION_CONFIRM_DATABASE must exactly match the intended database.');
  const verified = await verifyBackup(manifestFile, encryptionKey(process.env.BACKUP_ENCRYPTION_KEY));
  try {
    const age = Date.now() - new Date(verified.manifest.createdAt).getTime();
    if (verified.manifest.database !== config.database || !Number.isFinite(age) || age < 0 || age > 86400000) throw new Error('A verified backup of this database from the last 24 hours is required.');
  } finally { await verified.cleanup(); }
  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient();
  try {
    console.log(JSON.stringify(await migrationPreflight(prisma)));
    await prisma.$transaction(async tx => {
      const locks = await tx.$queryRawUnsafe('SELECT pg_try_advisory_xact_lock(62102517) AS locked');
      if (!locks[0].locked) throw new Error('Another guarded migration is running.');
      const child = spawn(process.execPath, [join(backendRoot, 'node_modules/prisma/build/index.js'), 'migrate', 'deploy'], { cwd: backendRoot, env: process.env, stdio: 'ignore' });
      await new Promise((success, failure) => {
        const timer = setTimeout(() => { child.kill('SIGTERM'); failure(new Error('Migration timed out; inspect migration status before retrying.')); }, 240000);
        child.on('error', () => { clearTimeout(timer); failure(new Error('Could not start Prisma migration.')); });
        child.on('close', code => { clearTimeout(timer); code === 0 ? success() : failure(new Error('Migration failed; inspect migration status before retrying.')); });
      });
    }, { timeout: 270000, maxWait: 10000 });
    console.log(JSON.stringify({ migration: 'deployed' }));
  } finally { await prisma.$disconnect(); }
}

export async function main(args = process.argv.slice(2)) {
  const [command, manifest] = args;
  if (command === 'backup') return backup();
  if (command === 'restore-check' && manifest) return restoreCheck(resolve(manifest));
  if (command === 'rehearse' && manifest) return restoreCheck(resolve(manifest), true);
  if (command === 'migrate' && manifest) return migrate(resolve(manifest));
  if (command === 'preflight') {
    databaseConfig(process.env.DATABASE_URL);
    const { PrismaClient } = await import('@prisma/client');
    const prisma = new PrismaClient();
    try { console.log(JSON.stringify(await migrationPreflight(prisma))); }
    finally { await prisma.$disconnect(); }
    return;
  }
  throw new Error('Usage: database-safety.mjs backup | preflight | restore-check <manifest> | rehearse <manifest> | migrate <manifest>');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => {
    console.error(error instanceof Error && !(error.constructor.name.startsWith('Prisma')) ? error.message : 'Database operation failed. Credentials and raw errors are not logged.');
    process.exitCode = 1;
  });
}
