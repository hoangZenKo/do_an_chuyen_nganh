import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function providerChecks(manifest, env = process.env) {
  if (env.PROVIDER_SMOKE_ENVIRONMENT !== 'staging') throw new Error('Set PROVIDER_SMOKE_ENVIRONMENT=staging. Use dedicated staging health endpoints.');
  if (!Array.isArray(manifest) || !manifest.length || manifest.length > 8) throw new Error('Configure 1 to 8 provider health checks.');
  const names = new Set();
  return manifest.map(entry => {
    if (!entry || !/^[a-z][a-z0-9_-]{0,39}$/.test(entry.name ?? '') || names.has(entry.name)) throw new Error('Provider names must be unique safe labels.');
    names.add(entry.name);
    if (!/^STAGING_[A-Z0-9_]+_HEALTH_URL$/.test(entry.urlEnv ?? '') ||
        (entry.tokenEnv !== undefined && !/^STAGING_[A-Z0-9_]+_(TOKEN|SECRET)$/.test(entry.tokenEnv))) throw new Error('Use dedicated STAGING_*_HEALTH_URL and STAGING_*_TOKEN/SECRET variables.');
    let url;
    try { url = new URL(env[entry.urlEnv] ?? ''); } catch {}
    const local = url?.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) && !!url.port;
    if (!url || (url.protocol !== 'https:' && !local) || url.username || url.password || url.search || url.hash) throw new Error(`Invalid health endpoint for ${entry.name}.`);
    const token = entry.tokenEnv ? env[entry.tokenEnv]?.trim() : undefined;
    if (entry.tokenEnv && !token) throw new Error(`Missing staging credential for ${entry.name}.`);
    return { name: entry.name, url, token };
  });
}

export async function probeProviders(checks, request = fetch) {
  return Promise.all(checks.map(async check => {
    try {
      const response = await request(check.url, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: check.token ? { authorization: `Bearer ${check.token}` } : {},
      });
      await response.body?.cancel();
      return { provider: check.name, passed: response.status === 200, status: response.status };
    } catch { return { provider: check.name, passed: false, failure: 'NETWORK_OR_REDIRECT' }; }
  }));
}

async function main() {
  if (!process.env.PROVIDER_SMOKE_MANIFEST) throw new Error('Set PROVIDER_SMOKE_MANIFEST to the provider health-check manifest path.');
  const checks = providerChecks(JSON.parse(await readFile(process.env.PROVIDER_SMOKE_MANIFEST, 'utf8')));
  const results = await probeProviders(checks);
  const passed = results.every(result => result.passed);
  console.log(JSON.stringify({ passed, checkedAt: new Date().toISOString(), readOnly: true, scope: 'connectivity-only-not-business-delivery', results }));
  process.exitCode = passed ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(() => {
    console.error('Provider smoke failed: verify the staging manifest, endpoint URLs and credential variables. No provider payloads, URLs or credentials are logged.');
    process.exitCode = 1;
  });
}
