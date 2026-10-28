import { createHash } from 'node:crypto';
import { open, realpath } from 'node:fs/promises';
import { extname, isAbsolute, relative, resolve } from 'node:path';
import { TextDecoder } from 'node:util';
import { ChatbotError, IndexedChunk, isRecord, KnowledgeDocumentMetadata, validVector } from './chatbot.types';
import { chunkMarkdown, normalizeKnowledgeText } from './knowledge-chunker';

export type DocumentIdentity = Omit<KnowledgeDocumentMetadata, 'embeddingDimensions'> & { embeddingDimensions?: number };

export interface ImportRepository {
  validateScope(input: Pick<KnowledgeDocumentMetadata, 'scope' | 'landlordId' | 'propertyId'>): Promise<void>;
  isCurrent(input: DocumentIdentity): Promise<boolean>;
  replaceDocument(input: KnowledgeDocumentMetadata, chunks: IndexedChunk[]): Promise<void>;
}

export interface EmbeddingClient {
  verifyEmbeddingModel(digest: string, signal: AbortSignal): Promise<void>;
  embed(texts: string[], signal: AbortSignal): Promise<number[][]>;
}

interface ManifestDocument {
  stableKey: string;
  file: string;
  title: string;
  scope: KnowledgeDocumentMetadata['scope'];
  landlordId?: string;
  propertyId?: string;
  approved: true;
  approvedBy: string;
  approvedAt: string;
}

export interface ImportResult {
  stableKey: string;
  status: 'imported' | 'unchanged';
  chunks: number;
}

export class KnowledgeImporter {
  constructor(
    private readonly repository: ImportRepository,
    private readonly client: EmbeddingClient,
    private readonly options: { root: string; embeddingModelDigest: string; embeddingDimensions?: number },
  ) {}

  async importManifest(filename: string, signal: AbortSignal): Promise<ImportResult[]> {
    if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
    if (!/^[a-f0-9]{64}$/.test(this.options.embeddingModelDigest)) throw new ChatbotError('AI_EMBED_DIGEST_REQUIRED');
    const root = await realpath(this.options.root);
    let manifest: unknown;
    try { manifest = JSON.parse(await this.readWithinRoot(root, resolve(filename), '.json')); }
    catch (error) {
      if (error instanceof ChatbotError) throw error;
      throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    }
    if (!isRecord(manifest) || manifest.version !== 1 || !Array.isArray(manifest.documents) ||
        !manifest.documents.length || manifest.documents.length > 100 ||
        Object.keys(manifest).some((key) => !['version', 'documents'].includes(key))) {
      throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    }
    const documents = manifest.documents.map((entry) => this.validateEntry(entry));
    if (new Set(documents.map((entry) => entry.stableKey)).size !== documents.length) {
      throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    }
    const prepared: Array<{ identity: DocumentIdentity; chunks: ReturnType<typeof chunkMarkdown> }> = [];
    for (const document of documents) {
      if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
      const text = normalizeKnowledgeText(await this.readWithinRoot(root, resolve(root, document.file), '.md'));
      const chunks = chunkMarkdown(text);
      const identity: DocumentIdentity = {
        stableKey: document.stableKey, title: document.title, scope: document.scope,
        landlordId: document.landlordId, propertyId: document.propertyId,
        approvedBy: document.approvedBy, approvedAt: new Date(document.approvedAt),
        contentHash: createHash('sha256').update(`chatbot-chunker-v1\0${text}`).digest('hex'),
        embeddingModelDigest: this.options.embeddingModelDigest,
        embeddingDimensions: this.options.embeddingDimensions,
      };
      await this.repository.validateScope(identity);
      prepared.push({ identity, chunks });
    }
    if (prepared.reduce((total, document) => total + document.chunks.length, 0) > 1000) {
      throw new ChatbotError('KNOWLEDGE_CAPACITY_EXCEEDED');
    }
    await this.client.verifyEmbeddingModel(this.options.embeddingModelDigest, signal);
    const results: ImportResult[] = [];
    let dimension = this.options.embeddingDimensions;
    for (const document of prepared) {
      if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
      if (await this.repository.isCurrent(document.identity)) {
        results.push({ stableKey: document.identity.stableKey, status: 'unchanged', chunks: document.chunks.length });
        continue;
      }
      const indexed: IndexedChunk[] = [];
      for (let offset = 0; offset < document.chunks.length; offset += 8) {
        const batch = document.chunks.slice(offset, offset + 8);
        const vectors = await this.client.embed(batch.map((chunk) => chunk.text), signal);
        dimension ??= Array.isArray(vectors?.[0]) ? vectors[0].length : 0;
        if (!Array.isArray(vectors) || vectors.length !== batch.length ||
            !vectors.every((vector) => validVector(vector, dimension))) {
          throw new ChatbotError('AI_INVALID_EMBEDDING');
        }
        indexed.push(...batch.map((chunk, index) => ({ ...chunk, embedding: vectors[index] })));
      }
      await this.client.verifyEmbeddingModel(this.options.embeddingModelDigest, signal);
      if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
      await this.repository.replaceDocument({ ...document.identity, embeddingDimensions: dimension! }, indexed);
      results.push({ stableKey: document.identity.stableKey, status: 'imported', chunks: indexed.length });
    }
    return results;
  }

  private validateEntry(value: unknown): ManifestDocument {
    if (!isRecord(value)) throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    if (value.approved !== true) throw new ChatbotError('KNOWLEDGE_APPROVAL_REQUIRED');
    const allowed = ['stableKey', 'file', 'title', 'scope', 'landlordId', 'propertyId', 'approved', 'approvedBy', 'approvedAt'];
    if (Object.keys(value).some((key) => !allowed.includes(key)) ||
        !['stableKey', 'file', 'title', 'approvedBy', 'approvedAt'].every((key) =>
          typeof value[key] === 'string' && (value[key] as string).trim().length > 0) ||
        !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$/.test(value.stableKey as string) ||
        (value.title as string).length > 200 || (value.approvedBy as string).length > 200 ||
        !['GLOBAL', 'LANDLORD', 'PROPERTY'].includes(value.scope as string)) {
      throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    }
    const approvedAt = Date.parse(value.approvedAt as string);
    if (!Number.isFinite(approvedAt) || approvedAt > Date.now()) throw new ChatbotError('KNOWLEDGE_INVALID_MANIFEST');
    const hasLandlord = typeof value.landlordId === 'string' && value.landlordId.trim().length > 0;
    const hasProperty = typeof value.propertyId === 'string' && value.propertyId.trim().length > 0;
    if ((value.scope === 'GLOBAL' && (value.landlordId !== undefined || value.propertyId !== undefined)) ||
        (value.scope === 'LANDLORD' && (!hasLandlord || value.propertyId !== undefined)) ||
        (value.scope === 'PROPERTY' && (!hasLandlord || !hasProperty))) {
      throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    }
    return value as unknown as ManifestDocument;
  }

  private async readWithinRoot(root: string, filename: string, extension: string): Promise<string> {
    let canonical: string;
    try { canonical = await realpath(filename); } catch { throw new ChatbotError('KNOWLEDGE_INVALID_PATH'); }
    const relativePath = relative(root, canonical);
    if (!relativePath || relativePath === '..' || relativePath.startsWith('../') || isAbsolute(relativePath) ||
        extname(filename).toLowerCase() !== extension || extname(canonical).toLowerCase() !== extension) {
      throw new ChatbotError('KNOWLEDGE_INVALID_PATH');
    }
    const file = await open(canonical, 'r');
    try {
      const stats = await file.stat();
      if (!stats.isFile() || stats.size > 100 * 1024) throw new ChatbotError('KNOWLEDGE_INVALID_CONTENT');
      const bytes = Buffer.alloc(100 * 1024 + 1);
      let size = 0;
      while (size < bytes.length) {
        const read = await file.read(bytes, size, bytes.length - size, null);
        if (!read.bytesRead) break;
        size += read.bytesRead;
      }
      if (size > 100 * 1024) throw new ChatbotError('KNOWLEDGE_INVALID_CONTENT');
      try { return new TextDecoder('utf-8', { fatal: true }).decode(bytes.subarray(0, size)); }
      catch { throw new ChatbotError('KNOWLEDGE_INVALID_CONTENT'); }
    } finally { await file.close(); }
  }
}
