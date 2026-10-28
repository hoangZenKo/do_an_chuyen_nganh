import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { PrismaService } from '../prisma/prisma.service';
import { loadChatbotConfig } from './chatbot.config';
import { ChatbotController } from './chatbot.controller';
import { ChatbotRateLimitGuard } from './chatbot-rate-limit.guard';
import { ChatbotService } from './chatbot.service';
import { KnowledgeRetriever } from './knowledge-retriever';
import { KnowledgeRepository } from './knowledge.repository';
import { OllamaClient } from './ollama.client';

export const CHATBOT_CONFIG = Symbol('CHATBOT_CONFIG');

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [ChatbotController],
  providers: [
    ChatbotRateLimitGuard,
    { provide: CHATBOT_CONFIG, useFactory: () => loadChatbotConfig() },
    { provide: KnowledgeRepository, inject: [PrismaService], useFactory: (prisma: PrismaService) => new KnowledgeRepository(prisma) },
    { provide: OllamaClient, inject: [CHATBOT_CONFIG], useFactory: (config) => new OllamaClient(config) },
    { provide: KnowledgeRetriever, inject: [KnowledgeRepository, OllamaClient, CHATBOT_CONFIG],
      useFactory: (repository, model, config) => new KnowledgeRetriever(repository, model, {
        embeddingModelDigest: config.embeddingDigest, minScore: config.minScore,
      }) },
    { provide: ChatbotService, inject: [KnowledgeRepository, KnowledgeRetriever, OllamaClient, CHATBOT_CONFIG],
      useFactory: (repository, retriever, model, config) => new ChatbotService(repository, retriever, model, config) },
  ],
})
export class ChatbotModule {}
