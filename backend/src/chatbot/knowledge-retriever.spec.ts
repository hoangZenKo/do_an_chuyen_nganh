import { ChatbotError, KnowledgeScope } from './chatbot.types';
import { KnowledgeRetriever, cosineSimilarity, lexicalSimilarity } from './knowledge-retriever';

describe('cosineSimilarity', () => {
  it('ranks identical, opposite, and orthogonal vectors', () => {
    expect(cosineSimilarity([1, 0], [1, 0])).toBeCloseTo(1);
    expect(cosineSimilarity([1, 0], [-1, 0])).toBeCloseTo(-1);
    expect(cosineSimilarity([1, 0], [0, 1])).toBeCloseTo(0);
  });
  it.each([[[0, 0], [1, 0]], [[1], [1, 0]], [[Infinity], [1]], [[], []]])
    ('rejects invalid vectors %j', (left, right) => {
      expect(() => cosineSimilarity(left, right)).toThrow('AI_INVALID_EMBEDDING');
    });
});

describe('KnowledgeRetriever', () => {
  const scope: KnowledgeScope = { landlordId: 'owner-a', propertyId: 'property-a1' };
  const repository = { listActiveChunks: jest.fn() };
  const client = { embed: jest.fn(), verifyEmbeddingModel: jest.fn() };
  const retriever = () => new KnowledgeRetriever(repository, client, {
    embeddingModelDigest: 'a'.repeat(64), minScore: 0.5,
  });
  const row = (id: string, embedding: number[], scopeName: string) => ({
    id, documentId: id, contentHash: 'b'.repeat(64), title: id, heading: 'Heading',
    text: `TEST FIXTURE ${scopeName}`, embedding,
  });

  beforeEach(() => { jest.resetAllMocks(); });

  it('embeds the question and returns the best three eligible chunks without vector data', async () => {
    repository.listActiveChunks.mockResolvedValue([
      row('owner-1', [1, 0], 'landlord'), row('property-1', [0.99, 0.01], 'property'),
      row('global-1', [0.95, 0.05], 'global'), row('irrelevant', [0, 1], 'landlord'),
    ]);
    client.embed.mockResolvedValue([[1, 0]]);
    expect(await retriever().search('Cách tạo hóa đơn?', scope, new AbortController().signal))
      .toMatchObject([{ id: 'owner-1' }, { id: 'property-1' }, { id: 'global-1' }]);
    expect((await retriever().search('Tạo hóa đơn', scope, new AbortController().signal))
      .every((chunk) => !('embedding' in chunk))).toBe(true);
    expect(repository.listActiveChunks).toHaveBeenCalledWith(scope, 'a'.repeat(64));
    expect(client.embed).toHaveBeenCalledWith(['Cách tạo hóa đơn?'], expect.any(AbortSignal));
  });

  it('returns no evidence under the calibrated threshold', async () => {
    repository.listActiveChunks.mockResolvedValue([row('opposite', [-1, 0], 'landlord')]);
    client.embed.mockResolvedValue([[1, 0]]);
    expect(await retriever().search('unknown', scope, new AbortController().signal)).toEqual([]);
  });

  it('uses Vietnamese topic terms in titles and headings to rerank generic passages', () => {
    const question = 'Làm sao lập hóa đơn cho khu trọ?';
    expect(lexicalSimilarity(question, {
      title: 'Điện nước và hóa đơn', heading: 'Lập hóa đơn',
      text: 'Chọn lập hóa đơn hàng loạt, chọn kỳ và khu trọ.',
    })).toBeGreaterThan(lexicalSimilarity(question, {
      title: 'FAQ và hướng dẫn', heading: 'Tra cứu trạng thái',
      text: 'Mở hồ sơ người thuê hoặc hợp đồng để xem thông tin do ứng dụng lưu.',
    }));
    expect(lexicalSimilarity('Người thuê gửi chứng từ thanh toán ở đâu?', {
      title: 'Thanh toán và chứng từ', heading: 'Chứng từ thanh toán',
      text: 'Người thuê gửi chứng từ tại chi tiết hóa đơn.',
    })).toBeGreaterThan(0.3);
  });

  it('reranks exact Vietnamese matches and returns at most one chunk per document', async () => {
    repository.listActiveChunks.mockResolvedValue([
      { ...row('invoice', [0.8, 0.6], 'billing'), title: 'Điện nước và hóa đơn',
        heading: 'Lập hóa đơn', text: 'Chọn lập hóa đơn hàng loạt, chọn kỳ và khu trọ.' },
      { ...row('invoice-other-section', [1, 0], 'billing'), title: 'FAQ và hướng dẫn',
        heading: 'Tra cứu trạng thái', text: 'Mở hồ sơ người thuê để xem thông tin do ứng dụng lưu.' },
      { ...row('generic', [1, 0], 'generic'), title: 'FAQ và hướng dẫn',
        heading: 'Tra cứu trạng thái', text: 'Mở hồ sơ người thuê để xem thông tin do ứng dụng lưu.' },
    ]);
    client.embed.mockResolvedValue([[1, 0]]);
    const results = await retriever().search('Làm sao lập hóa đơn cho khu trọ?', scope, new AbortController().signal);
    expect(results[0].id).toBe('invoice');
    expect(results.filter((result) => result.documentId === 'invoice')).toHaveLength(1);
  });

  it('returns empty evidence for a truly empty corpus without embedding', async () => {
    repository.listActiveChunks.mockResolvedValue([]);
    expect(await retriever().search('unknown', scope, new AbortController().signal)).toEqual([]);
    expect(client.embed).not.toHaveBeenCalled();
    expect(client.verifyEmbeddingModel).not.toHaveBeenCalled();
  });

  it('checks the live digest before embedding nonempty scoped candidates', async () => {
    repository.listActiveChunks.mockResolvedValue([row('one', [1, 0], 'fixture')]);
    client.verifyEmbeddingModel.mockRejectedValue(new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE'));
    await expect(retriever().search('question', scope, new AbortController().signal))
      .rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
    expect(client.verifyEmbeddingModel).toHaveBeenCalledWith('a'.repeat(64), expect.any(AbortSignal));
    expect(client.embed).not.toHaveBeenCalled();
  });

  it('does not convert an index-version error into empty evidence', async () => {
    repository.listActiveChunks.mockRejectedValue(new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE'));
    await expect(retriever().search('question', scope, new AbortController().signal))
      .rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
  });

  it('fails closed on invalid query vectors and malformed rows', async () => {
    repository.listActiveChunks.mockResolvedValue([row('one', [1, 0], 'fixture')]);
    client.embed.mockResolvedValue([[0, 0]]);
    await expect(retriever().search('question', scope, new AbortController().signal))
      .rejects.toThrow('AI_INVALID_EMBEDDING');
    client.embed.mockResolvedValue([[1, 0]]);
    repository.listActiveChunks.mockResolvedValue([row('one', [1], 'fixture')]);
    await expect(retriever().search('question', scope, new AbortController().signal))
      .rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
  });
});
