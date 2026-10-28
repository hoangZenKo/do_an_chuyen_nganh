import { Logger } from '@nestjs/common';
import { randomUUID } from 'node:crypto';

import { ChatbotConfig } from './chatbot.config';
import { ChatAnswer, ChatbotError, KnowledgeScope, ModelAnswer, RetrievedChunk } from './chatbot.types';
import { KnowledgeRepository } from './knowledge.repository';
import { KnowledgeRetriever } from './knowledge-retriever';
import { OllamaClient } from './ollama.client';

const missingEvidence = 'Tài liệu đã duyệt hiện chưa đủ căn cứ để trả lời. Hãy hỏi đầy đủ về cách sử dụng ứng dụng hoặc liên hệ người quản lý.';
const liveDataUnsupported = 'Trợ lý chỉ hỏi đáp tài liệu hướng dẫn, chưa tra cứu dữ liệu trực tiếp. Hãy mở mục Hóa đơn hoặc Báo cáo để kiểm tra công nợ, số dư và số liệu hiện tại.';

export class ChatbotService {
  private busy = false;
  private readonly logger = new Logger(ChatbotService.name);

  constructor(
    private readonly repository: KnowledgeRepository,
    private readonly retriever: KnowledgeRetriever,
    private readonly model: OllamaClient,
    private readonly config: ChatbotConfig,
  ) {}

  async ask(question: string, scope: KnowledgeScope): Promise<ChatAnswer> {
    if (!this.config.enabled) throw new ChatbotError('AI_DISABLED');
    if (typeof question !== 'string' || !question.trim() || question.length > 1000) {
      throw new ChatbotError('AI_INVALID_INPUT');
    }
    let ownsSlot = false;
    const requestId = randomUUID();
    const started = Date.now();
    const controller = new AbortController();
    let timer: NodeJS.Timeout | undefined;
    let code = 'OK';
    const metrics = { chunks: 0 };
    try {
      const deadline = new Promise<never>((_, reject) => {
        timer = setTimeout(() => {
          controller.abort();
          reject(new ChatbotError('AI_TIMEOUT'));
        }, this.config.timeoutMs);
      });
      const pipeline = (async () => {
        await this.repository.assertScope(scope);
        if (controller.signal.aborted) throw new ChatbotError('AI_TIMEOUT');
        if (this.busy) throw new ChatbotError('AI_BUSY');
        this.busy = true;
        ownsSlot = true;
        return this.answer(question.trim(), scope, requestId, controller.signal, metrics);
      })();
      return await Promise.race([pipeline, deadline]);
    } catch (error) {
      code = error instanceof ChatbotError ? error.code : 'AI_INTERNAL_ERROR';
      throw error;
    } finally {
      clearTimeout(timer);
      controller.abort();
      if (ownsSlot) this.busy = false;
      this.logger.log(JSON.stringify({ requestId, embeddingDigest: this.config.embeddingDigest,
        latencyMs: Date.now() - started, chunkCount: metrics.chunks, code }));
    }
  }

  async getSource(id: string, scope: KnowledgeScope) {
    if (!this.config.enabled) throw new ChatbotError('AI_DISABLED');
    return this.repository.getSource(id, scope);
  }

  private async answer(question: string, scope: KnowledgeScope, requestId: string, signal: AbortSignal, metrics: { chunks: number }): Promise<ChatAnswer> {
    const ensureActive = () => {
      if (signal.aborted) throw new ChatbotError('AI_TIMEOUT');
    };
    const fallback = (answer = missingEvidence): ChatAnswer => ({
      requestId, status: 'insufficient_evidence', answer, sources: [],
    });
    const normalized = question.normalize('NFD').replace(/\p{Diacritic}/gu, '').replace(/đ/gi, 'd').toLowerCase();
    if (/^(con )?(cai do|no|vay|the)( thi)? sao\??$/.test(normalized)) {
      return fallback('Mỗi câu hỏi được xử lý độc lập. Bạn hãy nêu đầy đủ chức năng và thao tác cần hướng dẫn.');
    }
    if (/(con no|dang no|so du|cong no|doanh thu|phong trong|bao nhieu phong)/.test(normalized) &&
        /(hien tai|bay gio|hom nay|thang nay|bao nhieu|dang|con no)/.test(normalized) &&
        !/(cach |huong dan|o dau|muc nao)/.test(normalized)) {
      return fallback(liveDataUnsupported);
    }
    let chunks = await this.retriever.search(question, scope, signal);
    metrics.chunks = chunks.length;
    ensureActive();
    if (!chunks.length) return fallback();
    if (chunks.length > 3 || chunks.reduce((length, chunk) => length + chunk.text.length, 0) > 3600) {
      throw new ChatbotError('AI_INVALID_RESPONSE');
    }
    let generated: ModelAnswer;
    try {
      generated = await this.model.answer(question, chunks, signal);
    } catch (error) {
      if (!(error instanceof ChatbotError) || error.code !== 'AI_CONTEXT_LIMIT' || chunks.length < 2) throw error;
      ensureActive();
      chunks = chunks.slice(0, 1);
      generated = await this.model.answer(question, chunks, signal);
    }
    ensureActive();
    this.validateAnswer(generated, chunks);
    if (generated.insufficientEvidence) return fallback();
    const active = await Promise.all(chunks.map((chunk) =>
      this.repository.isSourceActive(chunk.id, chunk.contentHash, scope)));
    ensureActive();
    if (active.some((value) => !value)) {
      return fallback('Nguồn hướng dẫn vừa được cập nhật hoặc thu hồi. Vui lòng hỏi lại để sử dụng tài liệu hiện hành.');
    }
    return { requestId, status: 'answered', answer: generated.answer.trim(),
      sources: generated.sourceIds.map((id) => {
        const { documentId, contentHash, title, heading } = chunks.find((chunk) => chunk.id === id)!;
        return { id, documentId, contentHash, title, heading };
      }) };
  }

  private validateAnswer(answer: ModelAnswer, chunks: RetrievedChunk[]): void {
    if (!answer || typeof answer.answer !== 'string' || !answer.answer.trim() || answer.answer.length > 8000 ||
        typeof answer.insufficientEvidence !== 'boolean' || !Array.isArray(answer.sourceIds) ||
        new Set(answer.sourceIds).size !== answer.sourceIds.length ||
        answer.sourceIds.some((id) => typeof id !== 'string' || !chunks.some((chunk) => chunk.id === id)) ||
        (answer.insufficientEvidence ? answer.sourceIds.length !== 0 : answer.sourceIds.length === 0)) {
      throw new ChatbotError('AI_INVALID_RESPONSE');
    }
  }
}
