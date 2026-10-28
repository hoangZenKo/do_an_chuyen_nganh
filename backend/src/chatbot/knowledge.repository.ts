import { Injectable } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';
import { ChatbotError, IndexedChunk, KnowledgeDocumentMetadata, KnowledgeScope, RetrievedChunk, validVector } from './chatbot.types';

type StoredChunk = Omit<RetrievedChunk, 'score'> & { embedding: number[] };

@Injectable()
export class KnowledgeRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async validateScope(input: Pick<KnowledgeDocumentMetadata, 'scope' | 'landlordId' | 'propertyId'>): Promise<void> {
    const { scope, landlordId, propertyId } = input;
    if (scope === 'GLOBAL' && (landlordId || propertyId)) throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    if (scope === 'LANDLORD' && (!landlordId || propertyId)) throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    if (scope === 'PROPERTY' && (!landlordId || !propertyId)) throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    if (landlordId) {
      const owner = await this.prisma.user.findUnique({ where: { id: landlordId }, select: { id: true, role: true } });
      if (!owner || owner.role !== 'LANDLORD') throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    }
    if (propertyId) {
      const property = await this.prisma.property.findFirst({ where: { id: propertyId, landlordId }, select: { id: true } });
      if (!property) throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    }
  }

  async isCurrent(input: Omit<KnowledgeDocumentMetadata, 'embeddingDimensions'> & { embeddingDimensions?: number }): Promise<boolean> {
    const current = await this.prisma.knowledgeDocument.findUnique({
      where: { stableKey: input.stableKey }, select: {
        title: true, scope: true, landlordId: true, propertyId: true, contentHash: true,
        approvedBy: true, approvedAt: true, active: true, embeddingModelDigest: true, embeddingDimensions: true,
      },
    });
    return !!current && current.active && current.title === input.title && current.scope === input.scope &&
      current.landlordId === (input.landlordId ?? null) && current.propertyId === (input.propertyId ?? null) &&
      current.contentHash === input.contentHash && current.approvedBy === input.approvedBy &&
      current.approvedAt.getTime() === input.approvedAt.getTime() &&
      current.embeddingModelDigest === input.embeddingModelDigest &&
      (input.embeddingDimensions === undefined || current.embeddingDimensions === input.embeddingDimensions);
  }

  async replaceDocument(input: KnowledgeDocumentMetadata, chunks: IndexedChunk[]): Promise<void> {
    await this.validateScope(input);
    if (!/^[a-f0-9]{64}$/.test(input.contentHash) || !/^[a-f0-9]{64}$/.test(input.embeddingModelDigest) ||
        !Number.isInteger(input.embeddingDimensions) || input.embeddingDimensions < 1 || input.embeddingDimensions > 8192 ||
        !chunks.length || chunks.length > 1000 || chunks.some((chunk, index) =>
          chunk.ordinal !== index || !chunk.text.trim() || chunk.text.length > 1200 || !validVector(chunk.embedding, input.embeddingDimensions))) {
      throw new ChatbotError('AI_INVALID_EMBEDDING');
    }
    await this.prisma.$transaction(async (transaction) => {
      await this.upsertDocument(transaction, input);
      const document = await transaction.knowledgeDocument.findUniqueOrThrow({
        where: { stableKey: input.stableKey }, select: { id: true },
      });
      await transaction.knowledgeChunk.deleteMany({ where: { documentId: document.id } });
      await transaction.knowledgeChunk.createMany({ data: chunks.map((chunk) => ({ ...chunk, documentId: document.id })) });
    });
  }

  async revoke(stableKey: string): Promise<void> {
    const result = await this.prisma.knowledgeDocument.updateMany({ where: { stableKey, active: true }, data: { active: false } });
    if (result.count !== 1) throw new ChatbotError('KNOWLEDGE_NOT_FOUND');
  }

  async listActiveChunks(scope: KnowledgeScope, embeddingModelDigest: string): Promise<StoredChunk[]> {
    await this.validateQueryScope(scope);
    if (!/^[a-f0-9]{64}$/.test(embeddingModelDigest)) throw new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE');
    const filters = this.scopeFilters(scope);
    const stale = await this.prisma.knowledgeDocument.count({
      where: { active: true, OR: filters, NOT: { embeddingModelDigest } },
    });
    if (stale) throw new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE');
    const chunkCount = await this.prisma.knowledgeChunk.count({
      where: { document: { active: true, embeddingModelDigest, OR: filters } },
    });
    if (chunkCount > 1000) throw new ChatbotError('KNOWLEDGE_CAPACITY_EXCEEDED');
    const documents = await this.prisma.knowledgeDocument.findMany({
      where: { active: true, embeddingModelDigest, OR: filters },
      select: { id: true, title: true, contentHash: true, embeddingDimensions: true, chunks: {
        orderBy: { ordinal: 'asc' }, select: { id: true, ordinal: true, heading: true, text: true, embedding: true },
      } },
    });
    const chunks = documents.flatMap((document) => document.chunks.map((chunk) => ({
      id: chunk.id, documentId: document.id, contentHash: document.contentHash,
      title: document.title, heading: chunk.heading, text: chunk.text,
      embedding: chunk.embedding, ordinal: chunk.ordinal, dimensions: document.embeddingDimensions,
    })));
    if (chunks.length !== chunkCount) throw new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE');
    if (chunks.some(({ embedding, dimensions }) => !validVector(embedding, dimensions))) {
      throw new ChatbotError('KNOWLEDGE_INDEX_INCOMPATIBLE');
    }
    return chunks.map(({ dimensions: _dimensions, ...chunk }) => chunk);
  }

  async isSourceActive(id: string, contentHash: string, scope: KnowledgeScope): Promise<boolean> {
    await this.validateQueryScope(scope);
    const chunk = await this.prisma.knowledgeChunk.findFirst({
      where: { id, document: { active: true, contentHash, OR: this.scopeFilters(scope) } },
      select: { id: true },
    });
    return chunk !== null;
  }

  async getSource(id: string, scope: KnowledgeScope) {
    await this.validateQueryScope(scope);
    const chunk = await this.prisma.knowledgeChunk.findFirst({
      where: { id, document: { active: true, OR: this.scopeFilters(scope) } },
      select: { id: true, heading: true, text: true, document: {
        select: { id: true, title: true, contentHash: true },
      } },
    });
    if (!chunk) throw new ChatbotError('KNOWLEDGE_NOT_FOUND');
    return {
      id: chunk.id, documentId: chunk.document.id, contentHash: chunk.document.contentHash,
      title: chunk.document.title, heading: chunk.heading, text: chunk.text,
    };
  }

  async assertScope(scope: KnowledgeScope): Promise<void> {
    return this.validateQueryScope(scope);
  }

  private async validateQueryScope(scope: KnowledgeScope): Promise<void> {
    if (!scope.landlordId) throw new ChatbotError('KNOWLEDGE_INVALID_SCOPE');
    if (scope.propertyId) {
      const property = await this.prisma.property.findFirst({ where: {
        id: scope.propertyId, landlordId: scope.landlordId,
      }, select: { id: true } });
      if (!property) throw new ChatbotError('KNOWLEDGE_SCOPE_NOT_FOUND');
    }
  }

  private scopeFilters(scope: KnowledgeScope): Prisma.KnowledgeDocumentWhereInput[] {
    const filters: Prisma.KnowledgeDocumentWhereInput[] = [
      { scope: 'GLOBAL', landlordId: null, propertyId: null },
      { scope: 'LANDLORD', landlordId: scope.landlordId, propertyId: null },
    ];
    if (scope.propertyId) filters.push({
      scope: 'PROPERTY', landlordId: scope.landlordId, propertyId: scope.propertyId,
    });
    return filters;
  }

  private async upsertDocument(client: Prisma.TransactionClient, input: KnowledgeDocumentMetadata): Promise<void> {
    const data = {
      title: input.title, scope: input.scope, landlordId: input.landlordId ?? null,
      propertyId: input.propertyId ?? null, contentHash: input.contentHash,
      approvedBy: input.approvedBy, approvedAt: input.approvedAt, active: true,
      embeddingModelDigest: input.embeddingModelDigest, embeddingDimensions: input.embeddingDimensions,
    };
    await client.knowledgeDocument.upsert({
      where: { stableKey: input.stableKey },
      create: { stableKey: input.stableKey, ...data },
      update: { ...data, updatedAt: new Date() },
    });
  }
}
