import { OllamaClient } from './ollama.client';

const chunk = {
  id: 'source-1', documentId: 'doc-1', contentHash: 'hash',
  title: 'Invoice guide', heading: 'Create', text: 'Open Billing.', score: 1,
};

describe('OllamaClient', () => {
  let fetchMock: jest.SpyInstance;
  let client: OllamaClient;
  const signal = () => new AbortController().signal;
  const respond = (body: unknown, status = 200) =>
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify(body), { status }));

  beforeEach(() => {
    fetchMock = jest.spyOn(globalThis, 'fetch');
    client = new OllamaClient({
      baseUrl: 'http://127.0.0.1:11434', chatModel: 'test-chat', embedModel: 'test-embed',
    });
  });
  afterEach(() => fetchMock.mockRestore());

  it('embeds a batch without truncation and preserves the abort signal', async () => {
    respond({ embeddings: [[1, 0], [0, 1]] });
    const abortSignal = signal();
    expect(await client.embed(['one', 'two'], abortSignal)).toEqual([[1, 0], [0, 1]]);
    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe('http://127.0.0.1:11434/api/embed');
    expect(options.signal).toBe(abortSignal);
    expect(JSON.parse(options.body)).toMatchObject({
      model: 'test-embed', input: ['one', 'two'], truncate: false,
    });
  });

  it.each([
    [[]], [[0, 0]], [[null, 1]], [['1', 2]], [[1, 0], [0, 1]], [],
  ].map((embeddings) => ({ embeddings })))('rejects invalid embedding batch %j', async ({ embeddings }) => {
    respond({ embeddings });
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_INVALID_EMBEDDING');
  });

  it('rejects mixed vector dimensions and dimensions changing across calls', async () => {
    respond({ embeddings: [[1, 0], [1, 0, 0]] });
    await expect(client.embed(['one', 'two'], signal())).rejects.toThrow('AI_INVALID_EMBEDDING');
    respond({ embeddings: [[1, 0]] });
    await client.embed(['one'], signal());
    respond({ embeddings: [[1, 0, 0]] });
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_INVALID_EMBEDDING');
  });

  it('rejects input before making a request', async () => {
    await expect(client.embed([], signal())).rejects.toThrow('AI_INVALID_INPUT');
    await expect(client.embed([' '], signal())).rejects.toThrow('AI_INVALID_INPUT');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('checks the full embedding digest rather than trusting a mutable tag', async () => {
    respond({ models: [{ name: 'test-embed:latest', digest: 'a'.repeat(64) }] });
    await client.verifyEmbeddingModel('a'.repeat(64), signal());
    respond({ models: [{ name: 'test-embed:latest', digest: 'b'.repeat(64) }] });
    await expect(client.verifyEmbeddingModel('a'.repeat(64), signal()))
      .rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
  });

  it('sends sources as data and validates structured answers', async () => {
    respond({ done: true, message: { content: JSON.stringify({
      answer: 'Open Billing.', sourceIds: ['source-1'], insufficientEvidence: false,
    }) } });
    expect(await client.answer('How?', [chunk], signal())).toMatchObject({ sourceIds: ['source-1'] });
    const payload = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(payload.stream).toBe(false);
    expect(payload.format.type).toBe('object');
    expect(payload.tools).toBeUndefined();
    expect(payload.messages[0].role).toBe('system');
    expect(JSON.parse(payload.messages[1].content).sources[0].id).toBe('source-1');
  });

  it.each([
    { answer: 'invented', sourceIds: ['other'], insufficientEvidence: false },
    { answer: 'invented', sourceIds: [], insufficientEvidence: false },
    { answer: '', sourceIds: ['source-1'], insufficientEvidence: false },
    { answer: 'no', sourceIds: ['source-1'], insufficientEvidence: true },
    { answer: 'no', sourceIds: [], insufficientEvidence: 'true' },
  ])('rejects invalid answers %j', async (answer) => {
    respond({ done: true, message: { content: JSON.stringify(answer) } });
    await expect(client.answer('How?', [chunk], signal())).rejects.toThrow('AI_INVALID_RESPONSE');
  });

  it('accepts an explicit insufficient-evidence answer', async () => {
    respond({ done: true, message: { content: JSON.stringify({
      answer: 'No evidence.', sourceIds: [], insufficientEvidence: true,
    }) } });
    expect(await client.answer('How?', [chunk], signal())).toEqual({
      answer: 'Tài liệu đã duyệt hiện có chưa cung cấp đủ thông tin để trả lời câu hỏi này.',
      sourceIds: [], insufficientEvidence: true,
    });
  });

  it('rejects malformed JSON and incomplete generation', async () => {
    respond({ done: true, message: { content: 'not json' } });
    await expect(client.answer('How?', [chunk], signal())).rejects.toThrow('AI_INVALID_RESPONSE');
    respond({ done: false, message: { content: '{}' } });
    await expect(client.answer('How?', [chunk], signal())).rejects.toThrow('AI_INVALID_RESPONSE');
  });

  it('maps unavailable and HTTP errors without exposing response contents or retrying', async () => {
    fetchMock.mockRejectedValueOnce(new Error('private server path'));
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_UNAVAILABLE');
    respond({ error: 'private model path' }, 500);
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_UNAVAILABLE');
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('distinguishes context overflow from an offline model', async () => {
    respond({ error: 'input length exceeds maximum context length' }, 400);
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_CONTEXT_LIMIT');
  });

  it('maps abort to timeout, including when the caller is already aborted', async () => {
    const controller = new AbortController();
    controller.abort();
    await expect(client.embed(['one'], controller.signal)).rejects.toThrow('AI_TIMEOUT');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('does not forward sensitive diagnostic text from malformed model error bodies', async () => {
    fetchMock.mockResolvedValueOnce(new Response('api-key=secret-token', { status: 500 }));
    await expect(client.embed(['one'], signal())).rejects.toThrow('AI_UNAVAILABLE');
  });
});
