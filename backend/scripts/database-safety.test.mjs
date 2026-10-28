import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createCipheriv, createHash, randomBytes } from 'node:crypto';
import { databaseConfig, encryptionKey, verifyBackup, restoreTargetUrl } from './database-safety.mjs';

test('database config does not put credentials in process arguments', () => {
  const result = databaseConfig('postgresql://user:secret@localhost:5432/rental_test?schema=public', {});
  assert.equal(result.database, 'rental_test');
  assert.equal(result.env.PGPASSWORD, 'secret');
  assert.throws(() => databaseConfig('postgresql://host/-unsafe'));
  assert.throws(() => encryptionKey('short'));
});

test('migration rehearsal cannot target the source or an unnamed working database', () => {
  const source = 'postgresql://user:secret@localhost:5432/rental_working?schema=public';
  const target = new URL(restoreTargetUrl(source, 'rental_restore_check_20261026'));
  assert.equal(target.pathname, '/rental_restore_check_20261026');
  assert.equal(target.password, 'secret');
  assert.equal(target.searchParams.get('schema'), 'public');
  for (const database of ['rental_working', 'rental_production', '-unsafe', '']) assert.throws(() => restoreTargetUrl(source, database));
});

test('encrypted backups authenticate before returning plaintext and reject corruption/path traversal', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'rental-backup-test-'));
  const key = randomBytes(32), nonce = randomBytes(12);
  const database = 'rental_test', createdAt = new Date().toISOString();
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from(JSON.stringify({ database, createdAt })));
  const bytes = Buffer.concat([cipher.update('PGDMP-test'), cipher.final()]);
  const manifest = { format: 'rental-pg-aes-gcm-v1', file: 'test.dump.enc', database, createdAt,
    nonce: nonce.toString('base64'), tag: cipher.getAuthTag().toString('base64'), sha256: createHash('sha256').update(bytes).digest('hex') };
  const archive = join(directory, manifest.file), file = `${archive}.json`;
  try {
    await writeFile(archive, bytes); await writeFile(file, JSON.stringify(manifest));
    const verified = await verifyBackup(file, key); await verified.cleanup();
    await assert.rejects(() => verifyBackup(file, randomBytes(32)), /authentication failed/);
    await writeFile(archive, Buffer.from('corrupted'));
    await assert.rejects(() => verifyBackup(file, key), /checksum mismatch/);
    await writeFile(file, JSON.stringify({ ...manifest, file: '../test.dump.enc' }));
    await assert.rejects(() => verifyBackup(file, key), /Invalid backup/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('restore drill removes decrypted files even when dropping its test database fails', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'rental-restore-cleanup-test-'));
  const key = randomBytes(32), nonce = randomBytes(12);
  const database = 'rental_test', createdAt = new Date().toISOString();
  const cipher = createCipheriv('aes-256-gcm', key, nonce);
  cipher.setAAD(Buffer.from(JSON.stringify({ database, createdAt })));
  const bytes = Buffer.concat([cipher.update('PGDMP-test'), cipher.final()]);
  const manifest = { format: 'rental-pg-aes-gcm-v1', file: 'test.dump.enc', database, createdAt,
    nonce: nonce.toString('base64'), tag: cipher.getAuthTag().toString('base64'), sha256: createHash('sha256').update(bytes).digest('hex') };
  const file = join(directory, 'backup.json'), marker = join(directory, 'plaintext-path');
  const executable = `#!${process.execPath}\nconst fs = require('node:fs');\nconst name = require('node:path').basename(process.argv[1]);\nif (name === 'dropdb') process.exit(1);\nif (name === 'pg_restore') fs.writeFileSync(process.env.RESTORE_DUMP_MARKER, process.argv.at(-1));\n`;
  try {
    await writeFile(join(directory, manifest.file), bytes);
    await writeFile(file, JSON.stringify(manifest));
    for (const name of ['pg_restore', 'createdb', 'psql', 'dropdb']) {
      await writeFile(join(directory, name), executable, { mode: 0o700 });
    }
    await assert.rejects(() => promisify(execFile)(process.execPath,
      [new URL('./database-safety.mjs', import.meta.url).pathname, 'restore-check', file], {
        env: { ...process.env, DATABASE_URL: 'postgresql://user@localhost/rental_test',
          ALLOW_RESTORE_CHECK: 'true', RESTORE_CHECK_DATABASE: 'rental_restore_check_cleanup',
          BACKUP_ENCRYPTION_KEY: key.toString('base64'), PG_BIN_DIR: directory, RESTORE_DUMP_MARKER: marker },
      }), /dropdb failed/);
    const plaintext = await readFile(marker, 'utf8');
    assert.match(plaintext, /verified\.dump$/);
    await assert.rejects(() => stat(plaintext), { code: 'ENOENT' });
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('smoke rejects insecure origins and disguised loopback credentials before sending tokens', async () => {
  for (const origin of ['http://staging.example.test', 'http://localhost:3000@evil.example.test', 'https://user:secret@staging.example.test', 'https://staging.example.test/api/v1', 'not-a-url']) {
    await assert.rejects(() => promisify(execFile)(process.execPath,
      [new URL('./staging-admin-smoke.mjs', import.meta.url).pathname], {
        env: { ...process.env, STAGING_API_URL: origin }, timeout: 5000,
      }), /Set STAGING_API_URL/);
  }
});
