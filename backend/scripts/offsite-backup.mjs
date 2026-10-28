import { createReadStream } from 'node:fs';
import { readFile, writeFile } from 'node:fs/promises';
import { basename, dirname, join } from 'node:path';

export function offsiteConfiguration(env = process.env) {
  const required = env.NODE_ENV === 'production' || env.BACKUP_OFFSITE_REQUIRED === 'true';
  if (!env.BACKUP_OFFSITE_URL) {
    if (required) throw new Error('An off-site backup gateway is required.');
    return null;
  }
  const url = new URL(env.BACKUP_OFFSITE_URL);
  const secret = env.BACKUP_OFFSITE_SECRET?.trim();
  const days = Number(env.BACKUP_RETENTION_DAYS || 30);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash || !secret || !Number.isInteger(days) || days < 7 || days > 3650) {
    throw new Error('Configure HTTPS off-site storage, a secret and retention of 7-3650 days.');
  }
  return { base: url.toString().replace(/\/$/, ''), secret, days };
}

export async function uploadOffsiteBackup(manifestPath, env = process.env, send = fetch) {
  const config = offsiteConfiguration(env);
  if (!config) return null;
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  if (basename(manifest.file ?? '') !== manifest.file || !/^[a-zA-Z0-9_.-]+\.dump\.enc$/.test(manifest.file) || !/^[a-f0-9]{64}$/.test(manifest.sha256)) throw new Error('Invalid off-site backup manifest.');
  const expiresAt = new Date(Date.now() + config.days * 86400000).toISOString();
  const headers = { authorization: `Bearer ${config.secret}`, 'x-retain-until': expiresAt, 'x-content-sha256': manifest.sha256 };
  const target = `${config.base}/${encodeURIComponent(manifest.file)}`;
  const archive = createReadStream(join(dirname(manifestPath), manifest.file));
  try {
    const response = await send(target, { method: 'PUT', redirect: 'error', signal: AbortSignal.timeout(120000), duplex: 'half', headers: { ...headers, 'content-type': 'application/octet-stream' }, body: archive });
    await response.body?.cancel();
    if (!response.ok) throw new Error('Off-site archive transfer failed; local backup retained.');
  } finally { archive.destroy(); }
  const response = await send(`${target}.json`, { method: 'PUT', redirect: 'error', signal: AbortSignal.timeout(15000), headers: { ...headers, 'content-type': 'application/json' }, body: JSON.stringify(manifest) });
  if (!response.ok) { await response.body?.cancel(); throw new Error('Off-site manifest transfer failed; local backup retained.'); }
  const receipt = await response.json();
  if (receipt.sha256 !== manifest.sha256 || receipt.durable !== true || new Date(receipt.retainedUntil).getTime() < new Date(expiresAt).getTime() || !Number.isFinite(new Date(receipt.retainedUntil).getTime())) {
    throw new Error('Off-site gateway did not confirm checksum and retention.');
  }
  const result = { file: manifest.file, sha256: manifest.sha256, uploadedAt: new Date().toISOString(), retainedUntil: receipt.retainedUntil, durable: true };
  await writeFile(`${manifestPath}.remote-receipt.json`, JSON.stringify(result, null, 2), { flag: 'wx', mode: 0o600 });
  return result;
}
