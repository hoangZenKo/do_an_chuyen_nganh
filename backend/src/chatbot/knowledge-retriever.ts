import { ChatbotError, KnowledgeScope, RetrievedChunk, validVector } from './chatbot.types';

interface Embeddable {
  verifyEmbeddingModel?(expectedDigest: string, signal: AbortSignal): Promise<void>;
  embed(texts: string[], signal: AbortSignal): Promise<number[][]>;
}

interface Searchable {
  listActiveChunks(scope: KnowledgeScope, embeddingModelDigest: string): Promise<Array<
    Omit<RetrievedChunk, 'score'> & { embedding: number[] }
  >>;
}

export function cosineSimilarity(left: number[], right: number[]): number {
  if (!validVector(left) || !validVector(right, left.length)) throw new ChatbotError('AI_INVALID_EMBEDDING');
  const leftNorm = Math.hypot(...left);
  const rightNorm = Math.hypot(...right);
  const dot = left.reduce((total, value, index) => total + value * right[index], 0);
  const score = dot / (leftNorm * rightNorm);
  if (!Number.isFinite(score)) throw new ChatbotError('AI_INVALID_EMBEDDING');
  return Math.max(-1, Math.min(1, score));
}

const ignoredTerms = new Set([
  'anh', 'bạn', 'bao', 'bằng', 'biết', 'cach', 'cái', 'cua', 'của', 'gi', 'gì', 'hay',
  'hoac', 'hoặc', 'khong', 'không', 'lam', 'làm', 'la', 'là', 'nào', 'nay', 'này', 'nhu',
  'như', 'sao', 'the', 'thế', 'toi', 'tôi', 'trong', 'tren', 'trên', 'va', 'và', 'voi',
  'với', 'ở', 'o', 'đâu', 'dau', 'được', 'duoc', 'có', 'co', 'cho', 'theo',
]);

function terms(text: string): Set<string> {
  return new Set(text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
    .split(/[^\p{L}\p{N}]+/u).filter((term) => term.length > 1 && !ignoredTerms.has(term)));
}

export function lexicalSimilarity(
  question: string,
  chunk: Pick<RetrievedChunk, 'title' | 'heading' | 'text'>,
): number {
  const queryTerms = terms(question);
  if (!queryTerms.size) return 0;
  const titleTerms = terms(chunk.title);
  const headingTerms = terms(chunk.heading);
  const contentTerms = terms(chunk.text);
  let score = 0;
  for (const term of queryTerms) {
    if (headingTerms.has(term)) score += 0.55;
    else if (titleTerms.has(term)) score += 0.3;
    else if (contentTerms.has(term)) score += 0.15;
  }
  return score / queryTerms.size;
}

export class KnowledgeRetriever {
  constructor(
    private readonly repository: Searchable,
    private readonly embeddings: Embeddable,
    private readonly options: { embeddingModelDigest: string; minScore: number },
  ) {}

  async search(question: string, scope: KnowledgeScope, signal: AbortSignal): Promise<RetrievedChunk[]> {
    if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
    if (typeof question !== 'string' || !question.trim() || question.length > 1000 ||
        !scope.landlordId || !/^[a-f0-9]{64}$/.test(this.options.embeddingModelDigest) ||
        !Number.isFinite(this.options.minScore) || this.options.minScore < -1 || this.options.minScore > 1) {
      throw new ChatbotError('AI_INVALID_INPUT');
    }
    const candidates = await this.repository.listActiveChunks(scope, this.options.embeddingModelDigest);
    if (!candidates.length) return [];
    await this.embeddings.verifyEmbeddingModel?.(this.options.embeddingModelDigest, signal);
    const vectors = await this.embeddings.embed([question], signal);
    if (!Array.isArray(vectors) || vectors.length !== 1 || !validVector(vectors[0])) {
      throw new ChatbotError('AI_INVALID_EMBEDDING');
    }
    const queryVector = vectors[0];
    const ranked = candidates.map((chunk) => {
      if (!chunk.id || !chunk.documentId || !chunk.contentHash || !chunk.title ||
          typeof chunk.heading !== 'string' || typeof chunk.text !== 'string' || chunk.text.length > 1200 ||
          !validVector(chunk.embedding, queryVector.length)) throw new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE');
      const semanticScore = cosineSimilarity(queryVector, chunk.embedding);
      const lexicalScore = lexicalSimilarity(question, chunk);
      return { ...chunk, score: semanticScore * 0.65 + lexicalScore * 0.35 };
    }).filter((chunk) => chunk.score >= this.options.minScore)
      .sort((left, right) => right.score - left.score || left.id.localeCompare(right.id));
    const selected: typeof ranked = [];
    const usedDocuments = new Set<string>();
    for (const chunk of ranked) {
      if (usedDocuments.has(chunk.documentId)) continue;
      selected.push(chunk);
      usedDocuments.add(chunk.documentId);
      if (selected.length === 3) break;
    }
    return selected.map(({ embedding: _embedding, ...chunk }) => chunk);
  }
}
