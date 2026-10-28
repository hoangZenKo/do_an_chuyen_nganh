import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { PrismaClient } from '@prisma/client';
import { loadChatbotConfig } from '../src/chatbot/chatbot.config';
import { KnowledgeRepository } from '../src/chatbot/knowledge.repository';
import { KnowledgeRetriever } from '../src/chatbot/knowledge-retriever';
import { OllamaClient } from '../src/chatbot/ollama.client';

interface EvaluationCase {
  question: string;
  expectedDocumentKey?: string;
}

async function main() {
  if (!process.env.KNOWLEDGE_EVAL_LANDLORD_ID) {
    throw new Error('Set KNOWLEDGE_EVAL_LANDLORD_ID to an isolated test landlord.');
  }
  const config = loadChatbotConfig({ ...process.env, CHATBOT_ENABLED: 'false' });
  if (!config.embeddingDigest) throw new Error('Set OLLAMA_EMBED_DIGEST to the approved embedding-model digest.');
  const input = JSON.parse(await readFile('test/evals/chatbot-mvp-vi.json', 'utf8')) as {
    questions: EvaluationCase[];
    negativeQuestions?: EvaluationCase[];
  };
  if (!Array.isArray(input.questions) || !input.questions.length) throw new Error('Evaluation set is empty.');
  const prisma = new PrismaClient();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), config.timeoutMs);
  try {
    const retriever = new KnowledgeRetriever(
      new KnowledgeRepository(prisma), new OllamaClient(config), {
        embeddingModelDigest: config.embeddingDigest,
        minScore: Number(process.env.KNOWLEDGE_EVAL_MIN_SCORE ?? -1),
      },
    );
    let top3Hits = 0;
    const positiveScores: number[] = [];
    const negativeTopScores: number[] = [];
    for (const testCase of [...input.questions, ...(input.negativeQuestions ?? [])]) {
      const matches = await retriever.search(testCase.question, {
        landlordId: process.env.KNOWLEDGE_EVAL_LANDLORD_ID,
      }, controller.signal);
      const documents = await prisma.knowledgeDocument.findMany({
        where: { id: { in: matches.map((match) => match.documentId) } },
        select: { id: true, stableKey: true },
      });
      const top3 = matches.map((match) => ({
        stableKey: documents.find((document) => document.id === match.documentId)?.stableKey,
        heading: match.heading,
        score: Number(match.score.toFixed(4)),
      }));
      const hit = top3.some((source) => source.stableKey === testCase.expectedDocumentKey);
      if (testCase.expectedDocumentKey) {
        if (hit) top3Hits++;
        const expected = top3.find((source) => source.stableKey === testCase.expectedDocumentKey);
        if (expected) positiveScores.push(expected.score);
      } else if (top3.length) negativeTopScores.push(top3[0].score);
      console.log(JSON.stringify({ question: testCase.question, expected: testCase.expectedDocumentKey, hit, top3 }));
    }
    const summary = { evaluated: input.questions.length, top3Hits,
      top3Recall: Number((top3Hits / input.questions.length).toFixed(4)),
      positiveScores: positiveScores.sort((left, right) => left - right),
      negativeTopScores: negativeTopScores.sort((left, right) => left - right),
      scoreInterpretation: 'Hybrid ranking scores, not probabilities. Compare positive and negative distributions before choosing RAG_MIN_SCORE.' };
    console.log(JSON.stringify({ summary }, null, 2));
    if (top3Hits < Math.ceil(input.questions.length * 0.9)) process.exitCode = 1;
  } finally {
    clearTimeout(timeout);
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  const code = error instanceof Error && /^[A-Z_]{3,}$/.test(error.message)
    ? error.message : 'KNOWLEDGE_EVALUATION_FAILED';
  console.error(code);
  process.exitCode = 1;
});
