import { mkdtemp, mkdir, writeFile, symlink, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { KnowledgeImporter } from './knowledge-importer';

describe('KnowledgeImporter', () => {
  let directory: string;
  let root: string;
  const digest = 'a'.repeat(64);
  const entry = () => ({
    stableKey: 'guide', file: 'guide.md', title: 'Guide', scope: 'GLOBAL',
    approved: true, approvedBy: 'TEST FIXTURE REVIEWER', approvedAt: '2026-10-01T00:00:00.000Z',
  });
  const repository = {
    validateScope: jest.fn(),
    isCurrent: jest.fn(),
    replaceDocument: jest.fn(),
  };
  const client = { embed: jest.fn(), verifyEmbeddingModel: jest.fn() };
  const signal = () => new AbortController().signal;
  const importer = () => new KnowledgeImporter(repository, client, {
    root, embeddingModelDigest: digest,
  });
  const manifest = async (entries: unknown[]) => {
    const filename = join(root, 'manifest.json');
    await writeFile(filename, JSON.stringify({ version: 1, documents: entries }));
    return filename;
  };

  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), 'knowledge-test-'));
    root = join(directory, 'knowledge');
    await mkdir(root);
    await writeFile(join(root, 'guide.md'), '# Guide\nTest fixture, not a real policy.');
    jest.resetAllMocks();
    repository.validateScope.mockResolvedValue(undefined);
    repository.isCurrent.mockResolvedValue(false);
    repository.replaceDocument.mockResolvedValue(undefined);
    client.verifyEmbeddingModel.mockResolvedValue(undefined);
    client.embed.mockImplementation(async (texts: string[]) => texts.map(() => [1, 0]));
  });
  afterEach(async () => rm(directory, { recursive: true, force: true }));

  it('imports a reviewed document and pins the embedding model before and after embedding', async () => {
    const result = await importer().importManifest(await manifest([entry()]), signal());
    expect(result).toEqual([{ stableKey: 'guide', status: 'imported', chunks: 1 }]);
    expect(client.verifyEmbeddingModel).toHaveBeenCalledTimes(2);
    expect(repository.replaceDocument).toHaveBeenCalledWith(expect.objectContaining({
      stableKey: 'guide', embeddingModelDigest: digest, embeddingDimensions: 2,
      contentHash: expect.stringMatching(/^[a-f0-9]{64}$/),
    }), [expect.objectContaining({ ordinal: 0, heading: 'Guide', embedding: [1, 0] })]);
  });

  it('rejects drafts before calling Ollama or writing to the database', async () => {
    await expect(importer().importManifest(await manifest([{ ...entry(), approved: false }]), signal()))
      .rejects.toThrow('KNOWLEDGE_APPROVAL_REQUIRED');
    expect(client.embed).not.toHaveBeenCalled();
    expect(repository.replaceDocument).not.toHaveBeenCalled();
  });

  it('preflights every entry before importing any document', async () => {
    await expect(importer().importManifest(await manifest([
      entry(), { ...entry(), stableKey: 'bad', approved: false },
    ]), signal())).rejects.toThrow('KNOWLEDGE_APPROVAL_REQUIRED');
    expect(repository.replaceDocument).not.toHaveBeenCalled();
  });

  it.each(['../outside.md', 'linked.md'])('rejects path escape %s', async (file) => {
    await writeFile(join(directory, 'outside.md'), '# Secret\nNot allowed.');
    await symlink(join(directory, 'outside.md'), join(root, 'linked.md'));
    await expect(importer().importManifest(await manifest([{ ...entry(), file }]), signal()))
      .rejects.toThrow('KNOWLEDGE_INVALID_PATH');
    expect(client.embed).not.toHaveBeenCalled();
  });

  it('rejects a manifest outside the knowledge root', async () => {
    const outside = join(directory, 'manifest.json');
    await writeFile(outside, JSON.stringify({ version: 1, documents: [entry()] }));
    await expect(importer().importManifest(outside, signal())).rejects.toThrow('KNOWLEDGE_INVALID_PATH');
  });

  it.each([
    { approvedBy: '' }, { approvedAt: 'not-date' }, { scope: 'GLOBAL', landlordId: 'owner' },
    { scope: 'PROPERTY', landlordId: 'owner' }, { file: 'guide.pdf' }, { unexpected: true },
  ])('rejects invalid metadata %j', async (override) => {
    await expect(importer().importManifest(await manifest([{ ...entry(), ...override }]), signal()))
      .rejects.toThrow();
    expect(repository.replaceDocument).not.toHaveBeenCalled();
  });

  it('rejects duplicate keys and invalid UTF-8', async () => {
    await expect(importer().importManifest(await manifest([entry(), entry()]), signal()))
      .rejects.toThrow('KNOWLEDGE_INVALID_MANIFEST');
    await writeFile(join(root, 'guide.md'), Buffer.from([0xc3, 0x28]));
    await expect(importer().importManifest(await manifest([entry()]), signal()))
      .rejects.toThrow('KNOWLEDGE_INVALID_CONTENT');
  });

  it('rejects remote/model-changing manifests and destination property escape', async () => {
    await expect(importer().importManifest(await manifest([{ ...entry(), url: 'https://example.invalid/policy' }]), signal()))
      .rejects.toThrow('KNOWLEDGE_INVALID_MANIFEST');
    repository.validateScope.mockRejectedValueOnce(new Error('KNOWLEDGE_INVALID_SCOPE'));
    await expect(importer().importManifest(await manifest([{
      ...entry(), scope: 'PROPERTY', landlordId: 'owner-a', propertyId: 'someone-elses-property',
    }]), signal())).rejects.toThrow('KNOWLEDGE_INVALID_SCOPE');
    expect(client.embed).not.toHaveBeenCalled();
  });

  it('skips identical imports without generating vectors', async () => {
    repository.isCurrent.mockResolvedValue(true);
    expect(await importer().importManifest(await manifest([entry()]), signal()))
      .toEqual([{ stableKey: 'guide', status: 'unchanged', chunks: 1 }]);
    expect(client.embed).not.toHaveBeenCalled();
  });

  it('leaves the previous index untouched after an embedding failure or changed model', async () => {
    const filename = await manifest([entry()]);
    client.embed.mockRejectedValueOnce(new Error('AI_UNAVAILABLE'));
    await expect(importer().importManifest(filename, signal())).rejects.toThrow('AI_UNAVAILABLE');
    expect(repository.replaceDocument).not.toHaveBeenCalled();
    client.verifyEmbeddingModel.mockReset()
      .mockResolvedValueOnce(undefined).mockRejectedValueOnce(new Error('KNOWLEDGE_INDEX_INCOMPATIBLE'));
    await expect(importer().importManifest(filename, signal())).rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
    expect(repository.replaceDocument).not.toHaveBeenCalled();
  });

  it('rejects invalid vectors even when a client implementation bypasses adapter validation', async () => {
    client.embed.mockResolvedValueOnce([[0, 0]]);
    await expect(importer().importManifest(await manifest([entry()]), signal()))
      .rejects.toThrow('AI_INVALID_EMBEDDING');
    expect(repository.replaceDocument).not.toHaveBeenCalled();
  });
});
