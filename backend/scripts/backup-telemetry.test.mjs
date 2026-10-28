import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createHmac } from 'node:crypto';
import { publishBackupTelemetry, telemetryConfiguration } from './backup-telemetry.mjs';

test('telemetry is opt-in, rejects partial/weak configuration and never accepts non-durable receipts', async () => {
  assert.equal(telemetryConfiguration({}), null);
  assert.throws(() => telemetryConfiguration({ BACKUP_TELEMETRY_PATH: '/tmp/latest.json' }));
  const directory = await mkdtemp(join(tmpdir(), 'rental-telemetry-test-'));
  const env = { DATABASE_URL: 'postgresql://user:private@localhost:5432/rental_test', BACKUP_TELEMETRY_PATH: join(directory, 'latest.json'), BACKUP_TELEMETRY_SECRET: 's'.repeat(40) };
  const now = new Date('2026-10-27T12:00:00Z');
  const manifest = { database: 'rental_test', createdAt: '2026-10-27T10:00:00Z', sha256: 'a'.repeat(64), file: 'test.dump.enc' };
  const receipt = { sha256: manifest.sha256, file: manifest.file, uploadedAt: '2026-10-27T10:01:00Z', durable: true, retainedUntil: '2026-11-27T10:01:00Z' };
  try {
    for (const change of [{ durable: false }, { sha256: 'b'.repeat(64) }, { file: 'other.dump.enc' }, { retainedUntil: '2026-10-26T00:00:00Z' }]) {
      await assert.rejects(() => publishBackupTelemetry(manifest, { ...receipt, ...change }, env, now));
    }
    assert.equal(await publishBackupTelemetry(manifest, receipt, env, now), true);
    const envelope = JSON.parse(await readFile(env.BACKUP_TELEMETRY_PATH, 'utf8'));
    assert.equal(envelope.signature, createHmac('sha256', env.BACKUP_TELEMETRY_SECRET).update(envelope.payload).digest('hex'));
    assert.equal((await stat(env.BACKUP_TELEMETRY_PATH)).mode & 0o777, 0o600);
    assert.doesNotMatch(envelope.payload, /private|postgresql|localhost|rental_test/);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
