import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { offsiteConfiguration, uploadOffsiteBackup } from './offsite-backup.mjs';

test('production backup requires off-site gateway and rejects insecure configuration', () => {
  assert.throws(() => offsiteConfiguration({ NODE_ENV: 'production' }));
  assert.equal(offsiteConfiguration({}), null);
  for (const url of ['http://storage.test', 'https://secret@storage.test', 'https://storage.test?secret=bad']) {
    assert.throws(() => offsiteConfiguration({ BACKUP_OFFSITE_URL: url, BACKUP_OFFSITE_SECRET: 'secret' }));
  }
});

test('off-site upload requires durable checksum/retention receipt without exposing credentials', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'rental-offsite-test-'));
  const filename = 'rental-test.dump.enc', manifestPath = join(directory, `${filename}.json`), sha256 = 'a'.repeat(64);
  const env = { BACKUP_OFFSITE_URL: 'https://storage.test/private', BACKUP_OFFSITE_SECRET: 'secret' };
  try {
    await writeFile(join(directory, filename), 'encrypted-test');
    await writeFile(manifestPath, JSON.stringify({ file: filename, sha256 }));
    const calls = [];
    const send = async (url, init) => {
      calls.push({ url, init });
      if (init.body?.[Symbol.asyncIterator]) for await (const chunk of init.body) assert.ok(chunk);
      return url.endsWith('.json') ? new Response(JSON.stringify({ sha256, durable: true, retainedUntil: new Date(Date.now() + 31 * 86400000).toISOString() })) : new Response('');
    };
    const receipt = await uploadOffsiteBackup(manifestPath, env, send);
    assert.equal(receipt.durable, true); assert.equal(calls.length, 2);
    const saved = await readFile(`${manifestPath}.remote-receipt.json`, 'utf8');
    assert.ok(!saved.includes('secret')); assert.ok(!saved.includes('storage.test'));
  } finally { await rm(directory, { recursive: true, force: true }); }
});
