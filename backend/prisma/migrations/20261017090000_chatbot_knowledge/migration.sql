CREATE TYPE "KnowledgeScope" AS ENUM ('GLOBAL', 'LANDLORD', 'PROPERTY');

ALTER TABLE "Property" ADD CONSTRAINT "Property_id_landlordId_key" UNIQUE ("id", "landlordId");

CREATE TABLE "KnowledgeDocument" (
    "id" TEXT NOT NULL,
    "stableKey" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "scope" "KnowledgeScope" NOT NULL,
    "landlordId" TEXT,
    "propertyId" TEXT,
    "contentHash" TEXT NOT NULL,
    "approvedBy" TEXT NOT NULL,
    "approvedAt" TIMESTAMP(3) NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "embeddingModelDigest" TEXT NOT NULL,
    "embeddingDimensions" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "KnowledgeDocument_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "KnowledgeDocument_scope_check" CHECK (
      ("scope" = 'GLOBAL' AND "landlordId" IS NULL AND "propertyId" IS NULL) OR
      ("scope" = 'LANDLORD' AND "landlordId" IS NOT NULL AND "propertyId" IS NULL) OR
      ("scope" = 'PROPERTY' AND "landlordId" IS NOT NULL AND "propertyId" IS NOT NULL)
    ),
    CONSTRAINT "KnowledgeDocument_embeddingDimensions_check" CHECK ("embeddingDimensions" > 0 AND "embeddingDimensions" <= 8192),
    CONSTRAINT "KnowledgeDocument_contentHash_check" CHECK ("contentHash" ~ '^[a-f0-9]{64}$'),
    CONSTRAINT "KnowledgeDocument_embeddingModelDigest_check" CHECK ("embeddingModelDigest" ~ '^[a-f0-9]{64}$')
);

CREATE TABLE "KnowledgeChunk" (
    "id" TEXT NOT NULL,
    "documentId" TEXT NOT NULL,
    "ordinal" INTEGER NOT NULL,
    "heading" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "embedding" DOUBLE PRECISION[] NOT NULL,
    CONSTRAINT "KnowledgeChunk_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "KnowledgeChunk_ordinal_check" CHECK ("ordinal" >= 0),
    CONSTRAINT "KnowledgeChunk_embedding_check" CHECK (
      cardinality("embedding") > 0 AND cardinality("embedding") <= 8192 AND
      array_position("embedding", NULL) IS NULL
    )
);

CREATE UNIQUE INDEX "KnowledgeDocument_stableKey_key" ON "KnowledgeDocument"("stableKey");
CREATE INDEX "KnowledgeDocument_active_scope_landlordId_propertyId_embeddingModelDigest_idx"
  ON "KnowledgeDocument"("active", "scope", "landlordId", "propertyId", "embeddingModelDigest");
CREATE UNIQUE INDEX "KnowledgeChunk_documentId_ordinal_key" ON "KnowledgeChunk"("documentId", "ordinal");
CREATE INDEX "KnowledgeChunk_documentId_idx" ON "KnowledgeChunk"("documentId");

ALTER TABLE "KnowledgeDocument"
  ADD CONSTRAINT "KnowledgeDocument_landlordId_fkey"
  FOREIGN KEY ("landlordId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "KnowledgeDocument"
  ADD CONSTRAINT "KnowledgeDocument_propertyId_landlordId_fkey"
  FOREIGN KEY ("propertyId", "landlordId") REFERENCES "Property"("id", "landlordId")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "KnowledgeChunk"
  ADD CONSTRAINT "KnowledgeChunk_documentId_fkey"
  FOREIGN KEY ("documentId") REFERENCES "KnowledgeDocument"("id") ON DELETE CASCADE ON UPDATE CASCADE;
