import { createHash, createHmac, randomUUID } from 'node:crypto';
import { rename, unlink, writeFile } from 'node:fs/promises';
import { isAbsolute } from 'node:path';

export function telemetryConfiguration(env = process.env) {
  if (!env.BACKUP_TELEMETRY_PATH && !env.BACKUP_TELEMETRY_SECRET) return null;
  if (!env.BACKUP_TELEMETRY_PATH || !isAbsolute(env.BACKUP_TELEMETRY_PATH) || Buffer.byteLength(env.BACKUP_TELEMETRY_SECRET ?? '') < 32) {
    throw new Error('Configure an absolute BACKUP_TELEMETRY_PATH and a separate secret of at least 32 bytes.');
  }
  const url = new URL(env.DATABASE_URL ?? '');
  if (!['postgresql:', 'postgres:'].includes(url.protocol)) throw new Error('Invalid backup database protocol.');
  return { path: env.BACKUP_TELEMETRY_PATH, secret: env.BACKUP_TELEMETRY_SECRET, database: decodeURIComponent(url.pathname.slice(1)),
    fingerprint: createHash('sha256').update(JSON.stringify([url.hostname.toLowerCase(), url.port || '5432', decodeURIComponent(url.pathname.slice(1))])).digest('hex') };
}

export async function publishBackupTelemetry(verifiedManifest, receipt, env = process.env, now = new Date()) {
  const config = telemetryConfiguration(env);
  if (!config) return false;
  if (!receipt || receipt.durable !== true || receipt.sha256 !== verifiedManifest.sha256 || receipt.file !== verifiedManifest.file ||
      verifiedManifest.database !== config.database || !/^[a-f0-9]{64}$/.test(verifiedManifest.sha256 ?? '') ||
      !Number.isFinite(Date.parse(verifiedManifest.createdAt)) || Date.parse(verifiedManifest.createdAt) > now.getTime() ||
      !Number.isFinite(Date.parse(receipt.uploadedAt)) || Date.parse(receipt.uploadedAt) > now.getTime() ||
      !Number.isFinite(Date.parse(receipt.retainedUntil)) || Date.parse(receipt.retainedUntil) <= now.getTime()) {
    throw new Error('Backup telemetry requires an authenticated archive and a matching durable off-site receipt.');
  }
  const payload = JSON.stringify({ version: 1, databaseFingerprint: config.fingerprint, createdAt: verifiedManifest.createdAt,
    sha256: verifiedManifest.sha256, archiveVerified: true, archiveVerifiedAt: now.toISOString(), durable: true,
    uploadedAt: receipt.uploadedAt, retainedUntil: receipt.retainedUntil });
  const signature = createHmac('sha256', config.secret).update(payload).digest('hex');
  const temporary = `${config.path}.${randomUUID()}.tmp`;
  try {
    await writeFile(temporary, JSON.stringify({ payload, signature }), { flag: 'wx', mode: 0o600 });
    await rename(temporary, config.path);
  } finally { await unlink(temporary).catch(() => undefined); }
  return true;
}
