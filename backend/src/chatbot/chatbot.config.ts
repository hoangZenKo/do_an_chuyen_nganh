import { ChatbotError } from './chatbot.types';

export interface OllamaOptions {
  baseUrl: string;
  chatModel: string;
  embedModel: string;
  embeddingDimensions?: number;
}

export interface ChatbotConfig extends OllamaOptions {
  enabled: boolean;
  timeoutMs: number;
  embeddingDigest?: string;
  minScore?: number;
}

export function loadChatbotConfig(env: NodeJS.ProcessEnv = process.env): ChatbotConfig {
  const invalid = () => { throw new ChatbotError('CHATBOT_INVALID_CONFIG'); };
  const enabledValue = env.CHATBOT_ENABLED ?? 'false';
  if (!['true', 'false'].includes(enabledValue)) invalid();
  const baseUrl = env.OLLAMA_BASE_URL ?? 'http://127.0.0.1:11434';
  let url: URL;
  try { url = new URL(baseUrl); } catch { return invalid(); }
  const isLoopback = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) ||
    /^127(?:\.\d{1,3}){3}$/.test(url.hostname);
  if (!isLoopback || !['http:', 'https:'].includes(url.protocol) || url.username || url.password ||
      url.search || url.hash || url.pathname !== '/') invalid();
  const timeoutMs = Number(env.CHATBOT_TIMEOUT_MS ?? 60000);
  if (!Number.isInteger(timeoutMs) || timeoutMs < 100 || timeoutMs > 300000) invalid();
  const embeddingDigest = env.OLLAMA_EMBED_DIGEST || undefined;
  if (embeddingDigest && !/^[a-f0-9]{64}$/.test(embeddingDigest)) invalid();
  const minScore = env.RAG_MIN_SCORE ? Number(env.RAG_MIN_SCORE) : undefined;
  if (minScore !== undefined && (!Number.isFinite(minScore) || minScore < -1 || minScore > 1)) invalid();
  const embeddingDimensions = env.OLLAMA_EMBED_DIMENSIONS ? Number(env.OLLAMA_EMBED_DIMENSIONS) : undefined;
  if (embeddingDimensions !== undefined &&
      (!Number.isInteger(embeddingDimensions) || embeddingDimensions < 1 || embeddingDimensions > 8192)) invalid();
  const chatModel = env.OLLAMA_CHAT_MODEL ?? 'qwen2.5:7b';
  const embedModel = env.OLLAMA_EMBED_MODEL ?? 'embeddinggemma:latest';
  if (![chatModel, embedModel].every((model) => /^[\w./:-]{1,200}$/.test(model))) invalid();
  const enabled = enabledValue === 'true';
  if (enabled && (!embeddingDigest || minScore === undefined)) invalid();
  return { enabled, baseUrl: url.origin, chatModel, embedModel, timeoutMs,
    embeddingDigest, minScore, embeddingDimensions };
}
