import { ChatbotService } from './chatbot.service';
import { Logger } from '@nestjs/common';
import { ChatbotError, RetrievedChunk } from './chatbot.types';

const chunk: RetrievedChunk = { id: 'c1', documentId: 'd1', contentHash: 'hash',
  title: 'Hóa đơn', heading: 'Tạo hóa đơn', text: 'Mở Hóa đơn.', score: 0.8 };

describe('ChatbotService', () => {
  const scope = { landlordId: 'owner', propertyId: 'property' };
  let repository: any;
  let model: any;
  let retriever: any;
  let service: ChatbotService;
  beforeEach(() => {
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    repository = { assertScope: jest.fn().mockResolvedValue(undefined),
      isSourceActive: jest.fn().mockResolvedValue(true), getSource: jest.fn().mockResolvedValue(chunk) };
    model = { verifyEmbeddingModel: jest.fn().mockResolvedValue(undefined),
      answer: jest.fn().mockResolvedValue({ answer: 'Mở Hóa đơn.', sourceIds: ['c1'], insufficientEvidence: false }) };
    retriever = { search: jest.fn().mockResolvedValue([chunk]) };
    service = new ChatbotService(repository, retriever, model, { enabled: true, timeoutMs: 1000,
      embeddingDigest: 'a'.repeat(64), baseUrl: 'http://localhost:11434', chatModel: 'chat', embedModel: 'embed' });
  });
  afterEach(() => { jest.restoreAllMocks(); jest.useRealTimers(); });
  it('returns verified citations and a server request ID', async () => {
    const answer = await service.ask('Cách tạo hóa đơn?', scope);
    expect(answer.status).toBe('answered');
    expect(answer.requestId).toMatch(/^[a-f0-9-]{36}$/);
    expect(answer.sources).toEqual([{ id: 'c1', documentId: 'd1', contentHash: 'hash', title: 'Hóa đơn', heading: 'Tạo hóa đơn' }]);
    expect(repository.assertScope).toHaveBeenCalledWith(scope);
  });
  it('does not generate when retrieval has no evidence', async () => {
    retriever.search.mockResolvedValue([]);
    expect((await service.ask('Cách tạo hóa đơn?', scope)).status).toBe('insufficient_evidence');
    expect(model.answer).not.toHaveBeenCalled();
  });
  it('never invents a current balance or multi-turn context', async () => {
    for (const question of ['Phòng 101 hiện còn nợ bao nhiêu?', 'Còn cái đó thì sao?']) {
      expect((await service.ask(question, scope)).status).toBe('insufficient_evidence');
    }
    expect(model.answer).not.toHaveBeenCalled();
  });
  it.each([[], ['invented'], ['c1', 'c1']])('rejects invalid citation IDs: %j', async (...ids) => {
    model.answer.mockResolvedValue({ answer: 'X', sourceIds: ids.flat(), insufficientEvidence: false });
    await expect(service.ask('Cách tạo hóa đơn?', scope)).rejects.toThrow('AI_INVALID_RESPONSE');
  });
  it('discards the answer when a supplied source changes while generating', async () => {
    repository.isSourceActive.mockResolvedValue(false);
    const answer = await service.ask('Cách tạo hóa đơn?', scope);
    expect(answer.status).toBe('insufficient_evidence');
    expect(answer.sources).toEqual([]);
    expect(answer.answer).not.toBe('Mở Hóa đơn.');
  });
  it('rechecks every supplied source even when the model cites only one', async () => {
    retriever.search.mockResolvedValue([chunk, { ...chunk, id: 'c2' }]);
    repository.isSourceActive.mockImplementation(async (id: string) => id === 'c1');
    const answer = await service.ask('Cách tạo hóa đơn?', scope);
    expect(answer.status).toBe('insufficient_evidence');
    expect(answer.sources).toEqual([]);
  });
  it('ignores model prose when the model admits missing evidence', async () => {
    model.answer.mockResolvedValue({ answer: 'UNSUPPORTED POLICY', sourceIds: [], insufficientEvidence: true });
    const answer = await service.ask('Cách tạo hóa đơn?', scope);
    expect(answer.status).toBe('insufficient_evidence');
    expect(answer.answer).not.toContain('UNSUPPORTED POLICY');
  });
  it('does not downgrade incompatible indexes to missing evidence', async () => {
    retriever.search.mockRejectedValue(new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE'));
    await expect(service.ask('Cách tạo hóa đơn?', scope)).rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
  });
  it('bounds the entire pipeline and releases the slot after timeout', async () => {
    jest.useFakeTimers();
    retriever.search.mockImplementationOnce(() => new Promise(() => {}));
    const pending = service.ask('Cách tạo hóa đơn?', scope);
    const assertion = expect(pending).rejects.toThrow('AI_TIMEOUT');
    await jest.advanceTimersByTimeAsync(1001);
    await assertion;
    expect((await service.ask('Cách tạo hóa đơn?', scope)).status).toBe('answered');
    jest.useRealTimers();
  });
  it('rejects a second concurrent inference without a queue', async () => {
    let finish!: (value: RetrievedChunk[]) => void;
    retriever.search.mockImplementationOnce(() => new Promise((resolve) => { finish = resolve; }));
    const first = service.ask('Cách tạo hóa đơn?', scope);
    await new Promise((resolve) => setImmediate(resolve));
    await expect(service.ask('Cách tạo hợp đồng?', scope)).rejects.toThrow('AI_BUSY');
    finish([chunk]);
    await first;
  });
  it('retries context overflow only once with fewer sources', async () => {
    retriever.search.mockResolvedValue([chunk, { ...chunk, id: 'c2' }]);
    model.answer.mockRejectedValueOnce(new ChatbotError('AI_CONTEXT_LIMIT'));
    await service.ask('Cách tạo hóa đơn?', scope);
    expect(model.answer).toHaveBeenCalledTimes(2);
    expect(model.answer.mock.calls[1][1]).toHaveLength(1);
  });
  it('does not retry other model failures', async () => {
    model.answer.mockRejectedValue(new ChatbotError('AI_UNAVAILABLE'));
    await expect(service.ask('Cách tạo hóa đơn?', scope)).rejects.toThrow('AI_UNAVAILABLE');
    expect(model.answer).toHaveBeenCalledTimes(1);
  });
});
