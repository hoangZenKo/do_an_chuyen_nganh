import { parseImportArgs, parseRevokeArgs } from './knowledge-import.cli';
import { resolve } from 'node:path';

describe('knowledge import CLI arguments', () => {
  it('requires an explicit manifest file', () => {
    expect(parseImportArgs(['--manifest', 'knowledge/manifest.json']).manifest)
      .toBe(resolve('knowledge/manifest.json'));
    expect(() => parseImportArgs([])).toThrow('KNOWLEDGE_INVALID_ARGUMENTS');
  });

  it('accepts only a stable key for revocation', () => {
    expect(parseRevokeArgs(['--key', 'guide-1'])).toBe('guide-1');
    expect(() => parseRevokeArgs(['guide-1'])).toThrow('KNOWLEDGE_INVALID_ARGUMENTS');
    expect(() => parseRevokeArgs(['--key', 'bad key'])).toThrow('KNOWLEDGE_INVALID_ARGUMENTS');
  });
});
