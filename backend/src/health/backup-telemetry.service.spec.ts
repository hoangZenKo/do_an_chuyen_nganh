import { createHmac } from 'node:crypto';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { BackupTelemetryService, backupDatabaseFingerprint } from './backup-telemetry.service';

describe('BackupTelemetryService', () => {
  it('accepts only signed, database-bound, durable telemetry', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'rental-backup-telemetry-'));
    const path = join(dir, 'latest.json');
    const secret = 'a'.repeat(40);
    const now = new Date('2026-10-27T12:00:00Z');
    const payload = JSON.stringify({ version: 1, databaseFingerprint: backupDatabaseFingerprint('postgresql://user:secret@localhost:5432/rental_test'), createdAt: '2026-10-27T10:00:00Z', sha256: 'a'.repeat(64), archiveVerified: true, archiveVerifiedAt: '2026-10-27T10:01:00Z', durable: true, uploadedAt: '2026-10-27T10:02:00Z', retainedUntil: '2026-11-27T10:02:00Z' });
    await writeFile(path, JSON.stringify({ payload, signature: createHmac('sha256', secret).update(payload).digest('hex') }));
    try {
      const config = { get: jest.fn((key: string) => ({ BACKUP_TELEMETRY_PATH: path, BACKUP_TELEMETRY_SECRET: secret, BACKUP_MAX_AGE_HOURS: '24', DATABASE_URL: 'postgresql://user:secret@localhost:5432/rental_test' } as Record<string, string>)[key]) };
      await expect(new BackupTelemetryService(config as never).inspect(now)).resolves.toMatchObject({ status: 'OK', durable: true, ageMinutes: 120 });
      await writeFile(path, JSON.stringify({ payload, signature: 'b'.repeat(64) }));
      await expect(new BackupTelemetryService(config as never).inspect(now)).resolves.toMatchObject({ status: 'UNKNOWN', available: false });
    } finally { await rm(dir, { recursive: true, force: true }); }
  });
});
