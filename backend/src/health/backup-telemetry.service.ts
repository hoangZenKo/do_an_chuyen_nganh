import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { open } from 'node:fs/promises';

export function backupDatabaseFingerprint(raw: string) {
  const url = new URL(raw);
  if (!['postgresql:', 'postgres:'].includes(url.protocol)) throw new Error('Invalid database protocol.');
  return createHash('sha256').update(JSON.stringify([url.hostname.toLowerCase(), url.port || '5432', decodeURIComponent(url.pathname.slice(1))])).digest('hex');
}

@Injectable()
export class BackupTelemetryService {
  constructor(private readonly config: ConfigService) {}

  async inspect(now = new Date()) {
    const unknown = { available: false, createdAt: null, ageMinutes: null, source: null, status: 'UNKNOWN',
      durable: false, archiveVerifiedAt: null, restoreVerified: false, reason: 'No verified database-bound backup telemetry is available to this API.' };
    const path = this.config.get<string>('BACKUP_TELEMETRY_PATH');
    const secret = this.config.get<string>('BACKUP_TELEMETRY_SECRET');
    if (!path || !secret || Buffer.byteLength(secret) < 32) return unknown;
    try {
      const maximum = Number(this.config.get('BACKUP_MAX_AGE_HOURS') || 24);
      if (!Number.isFinite(maximum) || maximum < 1 || maximum > 168) return unknown;
      const handle = await open(path, 'r');
      let content: string;
      try {
        if (!(await handle.stat()).isFile()) return unknown;
        const buffer = Buffer.alloc(8193);
        const { bytesRead } = await handle.read(buffer, 0, buffer.length, 0);
        if (bytesRead > 8192) return unknown;
        content = buffer.subarray(0, bytesRead).toString('utf8');
      } finally { await handle.close(); }
      const envelope = JSON.parse(content);
      if (typeof envelope.payload !== 'string' || !/^[a-f0-9]{64}$/.test(envelope.signature ?? '')) return unknown;
      const signature = createHmac('sha256', secret).update(envelope.payload).digest();
      if (!timingSafeEqual(signature, Buffer.from(envelope.signature, 'hex'))) return unknown;
      const snapshot = JSON.parse(envelope.payload);
      const created = new Date(snapshot.createdAt), verified = new Date(snapshot.archiveVerifiedAt);
      const uploaded = new Date(snapshot.uploadedAt), retained = new Date(snapshot.retainedUntil);
      if (snapshot.version !== 1 || snapshot.databaseFingerprint !== backupDatabaseFingerprint(this.config.get<string>('DATABASE_URL') ?? '') ||
          snapshot.archiveVerified !== true || snapshot.durable !== true || !/^[a-f0-9]{64}$/.test(snapshot.sha256 ?? '') ||
          ![created, verified, uploaded, retained].every(date => Number.isFinite(date.getTime())) ||
          created > verified || created > uploaded || verified > now || uploaded > now || retained <= now) return unknown;
      const ageMinutes = Math.floor((now.getTime() - created.getTime()) / 60000);
      return { available: true, createdAt: created.toISOString(), ageMinutes, source: 'SIGNED_BACKUP_WORKER',
        status: ageMinutes >= maximum * 60 ? 'STALE' : 'OK', durable: true, archiveVerifiedAt: verified.toISOString(), restoreVerified: false,
        reason: 'Signed archive authentication and off-site retention receipt; restore rehearsal remains a separate acceptance gate.' };
    } catch { return unknown; }
  }
}
