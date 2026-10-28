import { loadChatbotConfig } from './chatbot.config';

describe('loadChatbotConfig', () => {
  it('defaults to a disabled feature and loopback inference', () => {
    expect(loadChatbotConfig({})).toMatchObject({
      enabled: false, baseUrl: 'http://127.0.0.1:11434', timeoutMs: 60000,
    });
  });
  it.each([
    { CHATBOT_ENABLED: 'maybe' },
    { CHATBOT_TIMEOUT_MS: 'NaN' },
    { CHATBOT_TIMEOUT_MS: '-1' },
    { OLLAMA_BASE_URL: 'file:///tmp/model' },
    { OLLAMA_BASE_URL: 'https://user:secret@example.org' },
    { OLLAMA_BASE_URL: 'https://example.org' },
    { OLLAMA_BASE_URL: 'http://192.168.1.10:11434' },
    { OLLAMA_EMBED_DIGEST: 'short' },
    { RAG_MIN_SCORE: '2' },
  ])('rejects invalid config %j', (env) => {
    expect(() => loadChatbotConfig(env)).toThrow('CHATBOT_INVALID_CONFIG');
  });
  it('requires pinned embedding and calibrated retrieval score before enabling chat', () => {
    expect(() => loadChatbotConfig({ CHATBOT_ENABLED: 'true' })).toThrow('CHATBOT_INVALID_CONFIG');
    expect(loadChatbotConfig({
      CHATBOT_ENABLED: 'true', OLLAMA_EMBED_DIGEST: 'a'.repeat(64), RAG_MIN_SCORE: '0.5',
    }).enabled).toBe(true);
  });
});
