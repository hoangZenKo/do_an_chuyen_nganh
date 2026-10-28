import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { httpsEndpoint } from '../delivery/delivery.service';

@Injectable()
export class ReportObjectStorageService {
  constructor(private readonly config: ConfigService) {}
  ready() {
    const endpoint = httpsEndpoint(this.config.get<string>('REPORT_STORAGE_URL'));
    return !!endpoint && !new URL(endpoint).search && !!this.config.get<string>('REPORT_STORAGE_SECRET')?.trim();
  }
  required() { return this.config.get('NODE_ENV') === 'production'; }
  private endpoint(key: string) {
    if (!/^admin-reports\/[a-zA-Z0-9_-]+$/.test(key) || !this.ready()) throw new ServiceUnavailableException('Report object storage is not configured.');
    const base = httpsEndpoint(this.config.get<string>('REPORT_STORAGE_URL'))!;
    return `${base.replace(/\/$/, '')}/${key.split('/').map(encodeURIComponent).join('/')}`;
  }
  async put(key: string, encrypted: string, expiresAt: Date) {
    const response = await fetch(this.endpoint(key), { method: 'PUT', redirect: 'error', signal: AbortSignal.timeout(10000),
      headers: { authorization: `Bearer ${this.config.get<string>('REPORT_STORAGE_SECRET')}`, 'content-type': 'application/octet-stream', 'x-expires-at': expiresAt.toISOString() }, body: encrypted });
    await response.body?.cancel();
    if (!response.ok) throw new ServiceUnavailableException('Report object storage write failed.');
  }
  async get(key: string) {
    const response = await fetch(this.endpoint(key), { redirect: 'error', signal: AbortSignal.timeout(10000), headers: { authorization: `Bearer ${this.config.get<string>('REPORT_STORAGE_SECRET')}` } });
    if (!response.ok) { await response.body?.cancel(); throw new ServiceUnavailableException('Report object storage read failed.'); }
    const reader = response.body?.getReader();
    if (!reader) throw new ServiceUnavailableException('Report object missing.');
    const chunks: Uint8Array[] = []; let size = 0;
    try {
      while (true) {
        const chunk = await reader.read(); if (chunk.done) break;
        size += chunk.value.length;
        if (size > 8 * 1024 * 1024) throw new ServiceUnavailableException('Report exceeds storage limit.');
        chunks.push(chunk.value);
      }
    } finally { await reader.cancel().catch(() => undefined); }
    return Buffer.concat(chunks).toString('utf8');
  }
}
