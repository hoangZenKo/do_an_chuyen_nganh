import test from 'node:test';
import assert from 'node:assert/strict';
import { providerChecks, probeProviders } from './provider-smoke.mjs';

const manifest = [{ name: 'scanner', urlEnv: 'STAGING_SCANNER_HEALTH_URL', tokenEnv: 'STAGING_SCANNER_TOKEN' }];
const env = { PROVIDER_SMOKE_ENVIRONMENT: 'staging', STAGING_SCANNER_HEALTH_URL: 'https://scanner.example.test/health', STAGING_SCANNER_TOKEN: 'private-secret' };

test('validates all staging configuration before making a provider request', () => {
  assert.throws(() => providerChecks(manifest, { ...env, PROVIDER_SMOKE_ENVIRONMENT: 'production' }));
  assert.throws(() => providerChecks([...manifest, ...manifest], env));
  assert.throws(() => providerChecks([{ ...manifest[0], tokenEnv: 'JWT_ACCESS_SECRET' }], env));
  assert.throws(() => providerChecks(manifest, { ...env, STAGING_SCANNER_TOKEN: '' }));
  for (const url of ['http://scanner.example.test', 'http://localhost:3000@other.example.test/health', 'https://user:secret@scanner.example.test', 'https://scanner.example.test/health?token=secret']) {
    assert.throws(() => providerChecks(manifest, { ...env, STAGING_SCANNER_HEALTH_URL: url }));
  }
});

test('performs bounded read-only health probes without leaking credentials or URLs', async () => {
  const calls = [];
  const result = await probeProviders(providerChecks(manifest, env), async (url, options) => {
    calls.push({ url, options }); return new Response('provider-private-payload', { status: 200 });
  });
  assert.equal(calls[0].options.method, 'GET');
  assert.equal(calls[0].options.redirect, 'error');
  assert.equal(calls[0].options.headers.authorization, 'Bearer private-secret');
  assert.deepEqual(result, [{ provider: 'scanner', passed: true, status: 200 }]);
  assert.doesNotMatch(JSON.stringify(result), /private-secret|example\.test|provider-private/);
});

test('fails closed on bad HTTP status or transport/redirect errors', async () => {
  const checks = providerChecks(manifest, env);
  assert.equal((await probeProviders(checks, async () => new Response('', { status: 503 })))[0].passed, false);
  assert.deepEqual(await probeProviders(checks, async () => { throw new Error('https://secret@private.test'); }), [{ provider: 'scanner', passed: false, failure: 'NETWORK_OR_REDIRECT' }]);
});
