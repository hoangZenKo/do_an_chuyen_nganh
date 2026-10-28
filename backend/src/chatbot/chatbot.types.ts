export interface KnowledgeScope {
  landlordId: string;
  propertyId?: string;
}

export interface RetrievedChunk {
  id: string;
  documentId: string;
  contentHash: string;
  title: string;
  heading: string;
  text: string;
  score: number;
}

export interface ModelAnswer {
  answer: string;
  sourceIds: string[];
  insufficientEvidence: boolean;
}

export interface ChatSource {
  id: string;
  documentId: string;
  contentHash: string;
  title: string;
  heading: string;
}

export interface ChatAnswer {
  requestId: string;
  status: 'answered' | 'insufficient_evidence';
  answer: string;
  sources: ChatSource[];
}

export interface ApprovedDocumentInput {
  stableKey: string;
  title: string;
  scope: 'GLOBAL' | 'LANDLORD' | 'PROPERTY';
  landlordId?: string;
  propertyId?: string;
  contentHash: string;
  approvedBy: string;
  approvedAt: Date;
  embeddingModelDigest: string;
  embeddingDimensions: number;
}

export interface IndexedChunk {
  ordinal: number;
  heading: string;
  text: string;
  embedding: number[];
}

export interface KnowledgeDocumentMetadata {
  stableKey: string;
  title: string;
  scope: 'GLOBAL' | 'LANDLORD' | 'PROPERTY';
  landlordId?: string;
  propertyId?: string;
  contentHash: string;
  approvedBy: string;
  approvedAt: Date;
  embeddingModelDigest: string;
  embeddingDimensions: number;
}

export class ChatbotError extends Error {
  constructor(readonly code: string) {
    super(code);
    this.name = 'ChatbotError';
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function validVector(value: unknown, dimension?: number): value is number[] {
  return Array.isArray(value) && value.length > 0 && value.length <= 8192 &&
    (dimension === undefined || value.length === dimension) &&
    value.every((entry) => typeof entry === 'number' && Number.isFinite(entry)) &&
    value.every((entry) => Math.abs(entry) < 1e100) &&
    value.reduce((norm, entry) => norm + entry * entry, 0) > 0;
}
