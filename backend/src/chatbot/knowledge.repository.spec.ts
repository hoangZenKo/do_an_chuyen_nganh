import { PrismaClient } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { KnowledgeRepository } from './knowledge.repository';
import { ApprovedDocumentInput, IndexedChunk } from './chatbot.types';

const databaseUrl = process.env.KNOWLEDGE_TEST_DATABASE_URL;
const describeDatabase = databaseUrl ? describe : describe.skip;

describeDatabase('KnowledgeRepository (isolated PostgreSQL)', () => {
  let prisma: PrismaClient;
  let repository: KnowledgeRepository;
  const ownerId = randomUUID();
  const otherOwnerId = randomUUID();
  const propertyId = randomUUID();
  const prefix = `knowledge-test-${randomUUID()}`;
  const chunks: IndexedChunk[] = [{ ordinal: 0, heading: 'Guide', text: 'TEST FIXTURE', embedding: [1, 0] }];
  const input = (suffix: string, override: Partial<ApprovedDocumentInput> = {}): ApprovedDocumentInput => ({
    stableKey: `${prefix}-${suffix}`, title: 'Old title', scope: 'GLOBAL',
    contentHash: 'a'.repeat(64), approvedBy: 'TEST FIXTURE REVIEWER', approvedAt: new Date('2026-10-01'),
    embeddingModelDigest: 'b'.repeat(64), embeddingDimensions: 2, ...override,
  });

  beforeAll(async () => {
    const url = new URL(databaseUrl!);
    if (!['127.0.0.1', 'localhost'].includes(url.hostname) ||
        !/^\/rental_chatbot_test_[a-z0-9_]+$/.test(url.pathname)) {
      throw new Error('Knowledge integration tests require a dedicated local rental_chatbot_test_* database.');
    }
    prisma = new PrismaClient({ datasources: { db: { url: databaseUrl } } });
    await prisma.$connect();
    repository = new KnowledgeRepository(prisma);
    await prisma.user.createMany({ data: [ownerId, otherOwnerId].map((id) => ({
      id, email: `${id}@example.test`, fullName: 'TEST FIXTURE', passwordHash: 'not-a-real-password', role: 'LANDLORD',
    })) });
    await prisma.property.create({ data: { id: propertyId, landlordId: ownerId, name: 'TEST PROPERTY' } });
  });

  afterAll(async () => {
    if (!prisma) return;
    await prisma.knowledgeDocument.deleteMany({ where: { stableKey: { startsWith: prefix } } });
    await prisma.property.deleteMany({ where: { id: propertyId } });
    await prisma.user.deleteMany({ where: { id: { in: [ownerId, otherOwnerId] } } });
    await prisma.$disconnect();
  });

  it('stores vectors and recognizes unchanged metadata', async () => {
    const document = input('identity');
    await repository.replaceDocument(document, chunks);
    expect(await repository.isCurrent(document)).toBe(true);
    expect(await repository.isCurrent({ ...document, title: 'Updated title' })).toBe(false);
    expect(await repository.isCurrent({ ...document, scope: 'LANDLORD', landlordId: ownerId })).toBe(false);
    await repository.replaceDocument(document, chunks);
    expect(await prisma.knowledgeChunk.count({ where: { document: { stableKey: document.stableKey } } })).toBe(1);
  });

  it('rolls back both metadata and chunks if an insert fails', async () => {
    const document = input('rollback');
    await repository.replaceDocument(document, chunks);
    await prisma.$executeRawUnsafe('ALTER TABLE "KnowledgeChunk" ADD CONSTRAINT "knowledge_fixture_failure" CHECK ("text" <> \'REJECT FIXTURE\')');
    try {
      await expect(repository.replaceDocument({ ...document, title: 'New title' }, [
        { ...chunks[0], text: 'REJECT FIXTURE' },
      ])).rejects.toThrow();
      const stored = await prisma.knowledgeDocument.findUniqueOrThrow({
        where: { stableKey: document.stableKey }, include: { chunks: true },
      });
      expect(stored.title).toBe('Old title');
      expect(stored.chunks[0].text).toBe('TEST FIXTURE');
    } finally {
      await prisma.$executeRawUnsafe('ALTER TABLE "KnowledgeChunk" DROP CONSTRAINT "knowledge_fixture_failure"');
    }
  });

  it('checks landlord and property ownership on import and enforces the DB relation', async () => {
    const document = input('property', { scope: 'PROPERTY', landlordId: otherOwnerId, propertyId });
    await expect(repository.replaceDocument(document, chunks)).rejects.toThrow('KNOWLEDGE_INVALID_SCOPE');
    await repository.replaceDocument({ ...document, landlordId: ownerId }, chunks);
    await expect(prisma.knowledgeDocument.update({
      where: { stableKey: document.stableKey }, data: { landlordId: otherOwnerId },
    })).rejects.toThrow();
  });

  it('filters global, landlord, and property content before vector retrieval', async () => {
    const visibleKeys = [
      input('scope-global'),
      input('scope-owner-a', { scope: 'LANDLORD', landlordId: ownerId }),
      input('scope-property-a1', { scope: 'PROPERTY', landlordId: ownerId, propertyId }),
      input('scope-owner-b', { scope: 'LANDLORD', landlordId: otherOwnerId }),
    ];
    for (const document of visibleKeys) await repository.replaceDocument(document, chunks);
    const results = await repository.listActiveChunks({ landlordId: ownerId, propertyId }, 'b'.repeat(64));
    const visible = await Promise.all(visibleKeys.slice(0, 3).map(async (document) =>
      (await prisma.knowledgeDocument.findUniqueOrThrow({ where: { stableKey: document.stableKey } })).id));
    expect(results.map((chunk) => chunk.documentId)).toEqual(expect.arrayContaining(visible));
    const hidden = await prisma.knowledgeDocument.findUniqueOrThrow({ where: { stableKey: visibleKeys[3].stableKey } });
    expect(results.some((chunk) => chunk.documentId === hidden.id)).toBe(false);
    expect(results.length).toBeGreaterThanOrEqual(3);
    const ownerDocument = await prisma.knowledgeDocument.findUniqueOrThrow({
      where: { stableKey: visibleKeys[1].stableKey },
    });
    const ownerChunk = results.find((chunk) => chunk.documentId === ownerDocument.id)!;
    expect(await repository.isSourceActive(ownerChunk.id, ownerChunk.contentHash, { landlordId: ownerId, propertyId }))
      .toBe(true);
    expect(await repository.isSourceActive(ownerChunk.id, ownerChunk.contentHash, { landlordId: otherOwnerId }))
      .toBe(false);
    await repository.revoke(visibleKeys[0].stableKey);
    const globalDocument = await prisma.knowledgeDocument.findUniqueOrThrow({ where: { stableKey: visibleKeys[0].stableKey } });
    const globalChunk = results.find((chunk) => chunk.documentId === globalDocument.id)!;
    await expect(repository.getSource(globalChunk.id, { landlordId: ownerId }))
      .rejects.toThrow('KNOWLEDGE_NOT_FOUND');
  });

  it('revokes immediately, does not revive unchanged drafts, and rejects unknown keys', async () => {
    const document = input('revoke');
    await repository.replaceDocument(document, chunks);
    await repository.revoke(document.stableKey);
    expect(await repository.isCurrent(document)).toBe(false);
    expect(await prisma.knowledgeDocument.count({ where: { stableKey: document.stableKey, active: true } })).toBe(0);
    await expect(repository.revoke(`${prefix}-missing`)).rejects.toThrow('KNOWLEDGE_NOT_FOUND');
  });

  it('rejects malformed scope and vectors before writing', async () => {
    await expect(repository.replaceDocument(input('bad', { scope: 'GLOBAL', landlordId: ownerId }), chunks))
      .rejects.toThrow('KNOWLEDGE_INVALID_SCOPE');
    await expect(repository.replaceDocument(input('bad-vector'), [{ ...chunks[0], embedding: [0, 0] }]))
      .rejects.toThrow('AI_INVALID_EMBEDDING');
  });

  it('fails closed when any accessible active document has a different embedding model', async () => {
    const document = input('version-mismatch', {
      scope: 'LANDLORD', landlordId: ownerId, embeddingModelDigest: 'c'.repeat(64),
    });
    await repository.replaceDocument(document, chunks);
    await expect(repository.listActiveChunks({ landlordId: ownerId }, 'b'.repeat(64)))
      .rejects.toThrow('KNOWLEDGE_INDEX_INCOMPATIBLE');
  });
});
