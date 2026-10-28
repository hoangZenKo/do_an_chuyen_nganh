import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { loadChatbotConfig } from '../src/chatbot/chatbot.config';
import { automatedGate, EvaluationDataset, percentile } from '../src/chatbot/chatbot-evaluation';
import { ChatbotService } from '../src/chatbot/chatbot.service';
import { ChatbotError, isRecord } from '../src/chatbot/chatbot.types';
import { KnowledgeRepository } from '../src/chatbot/knowledge.repository';
import { KnowledgeRetriever } from '../src/chatbot/knowledge-retriever';
import { OllamaClient } from '../src/chatbot/ollama.client';

async function main() {
  const database = new URL(process.env.DATABASE_URL ?? 'http://invalid');
  if (!['localhost', '127.0.0.1'].includes(database.hostname) ||
      !/^\/rental_chatbot_test_[a-z0-9_]+$/.test(database.pathname)) {
    throw new Error('CHATBOT_EVAL_REQUIRES_ISOLATED_DATABASE');
  }
  const softwareOnly = process.argv.includes('--software-only');
  const benchmarkArg = process.argv.find((argument) => argument.startsWith('--benchmark='));
  const benchmarkRuns = Number(benchmarkArg?.split('=')[1] ?? 0);
  if (!Number.isInteger(benchmarkRuns) || benchmarkRuns < 0 || benchmarkRuns > 100) {
    throw new Error('CHATBOT_EVAL_INVALID_SAMPLE_COUNT');
  }
  const raw = await readFile('test/evals/chatbot-mvp-vi.json', 'utf8');
  const dataset = JSON.parse(raw) as EvaluationDataset;
  if (dataset.questions?.length !== 15 || dataset.negativeQuestions?.length !== 5 || dataset.integrationCases?.length !== 10) {
    throw new Error('CHATBOT_EVAL_INVALID_DATASET');
  }
  const results: Record<string, unknown>[] = [];
  const report: Record<string, unknown> = { reportId: randomUUID(), generatedAt: new Date().toISOString(),
    datasetVersion: dataset.version, datasetHash: createHash('sha256').update(raw).digest('hex'),
    softwareOnly, pilotReady: false, manualAnswerReview: 'required',
    benchmarkLayer: 'service_pipeline_without_http_or_flutter', results };
  let prisma: PrismaClient | undefined;
  let positiveHits = 0;
  let answeredPositives = 0;
  let negativeFallbacks = 0;
  let timeouts = 0;
  const warmLatencies: number[] = [];
  try {
    const unit = spawnSync('npm', ['test', '--', '--runInBand', 'src/chatbot'], {
      stdio: 'inherit', env: { ...process.env, KNOWLEDGE_TEST_DATABASE_URL: process.env.DATABASE_URL },
    });
    const endpoints = spawnSync('npm', ['run', 'test:e2e', '--', 'chatbot.e2e-spec.ts'], { stdio: 'inherit' });
    const softwarePassed = unit.status === 0 && endpoints.status === 0;
    report.softwarePassed = softwarePassed;
    for (const entry of dataset.integrationCases) {
      results.push({ ...entry, result: softwarePassed ? 'suite_passed' : 'suite_failed', model: 'mocked' });
    }
    if (!softwareOnly) {
      const landlordId = process.env.KNOWLEDGE_EVAL_LANDLORD_ID;
      if (!landlordId) throw new Error('KNOWLEDGE_EVAL_LANDLORD_REQUIRED');
      const config = loadChatbotConfig({ ...process.env, CHATBOT_ENABLED: 'true' });
      const manifest = JSON.parse(await readFile(resolve(process.env.KNOWLEDGE_ROOT ?? 'knowledge', 'manifest.json'), 'utf8')) as {
        documents: { stableKey: string; approved: boolean; approvedBy: string; approvedAt: string }[];
      };
      if (!dataset.questions.every((entry) => manifest.documents.some((document) =>
        document.stableKey === entry.expectedDocumentKey && document.approved === true && document.approvedBy && document.approvedAt))) {
        throw new Error('KNOWLEDGE_DOCUMENTS_NOT_APPROVED');
      }
      prisma = new PrismaClient();
      const repository = new KnowledgeRepository(prisma);
      const model = new OllamaClient(config);
      const retriever = new KnowledgeRetriever(repository, model, {
        embeddingModelDigest: config.embeddingDigest!, minScore: config.minScore!,
      });
      const diagnostic = new KnowledgeRetriever(repository, model, {
        embeddingModelDigest: config.embeddingDigest!, minScore: -1,
      });
      const service = new ChatbotService(repository, retriever, model, config);
      const scope = { landlordId, ...(process.env.KNOWLEDGE_EVAL_PROPERTY_ID ? {
        propertyId: process.env.KNOWLEDGE_EVAL_PROPERTY_ID,
      } : {}) };
      const corpus = await repository.listActiveChunks(scope, config.embeddingDigest!);
      const documents = await prisma.knowledgeDocument.findMany({
        where: { id: { in: corpus.map((chunk) => chunk.documentId) } },
        select: { id: true, stableKey: true, contentHash: true, embeddingModelDigest: true },
      });
      if (!dataset.questions.every((entry) => documents.some((document) => document.stableKey === entry.expectedDocumentKey))) {
        throw new Error('KNOWLEDGE_EVAL_CORPUS_INCOMPLETE');
      }
      const tags = await fetch(config.baseUrl + '/api/tags', { signal: AbortSignal.timeout(config.timeoutMs) }).then((response) => response.json());
      if (!isRecord(tags) || !Array.isArray(tags.models)) throw new Error('AI_INVALID_RESPONSE');
      report.models = tags.models.filter(isRecord).map(({ name, digest }) => ({ name, digest }));
      report.corpus = documents;
      report.config = { minScore: config.minScore, timeoutMs: config.timeoutMs,
        embeddingDigest: config.embeddingDigest, contextTokens: 4096, maxOutputTokens: 512 };
      for (const entry of [...dataset.questions, ...dataset.negativeQuestions]) {
        const item: Record<string, unknown> = { id: entry.id, expectedStatus: entry.expectedStatus, checklist: entry.checklist };
        try {
          const candidates = await diagnostic.search(entry.question, scope, AbortSignal.timeout(config.timeoutMs));
          item.scores = candidates.map((chunk) => ({ id: chunk.id,
            stableKey: documents.find((document) => document.id === chunk.documentId)?.stableKey, score: chunk.score }));
          const started = Date.now();
          const answer = await service.ask(entry.question, scope);
          item.latencyMs = Date.now() - started;
          item.status = answer.status;
          item.answer = answer.answer;
          item.sources = answer.sources;
          item.manualCorrect = null;
          const hit = candidates.some((chunk) => chunk.score >= config.minScore! &&
            documents.find((document) => document.id === chunk.documentId)?.stableKey === entry.expectedDocumentKey);
          item.retrievalHit = entry.expectedDocumentKey ? hit : undefined;
          if (entry.expectedStatus === 'answered') {
            if (hit) positiveHits++;
            if (hit && answer.status === 'answered' && answer.sources.some((source) =>
              documents.find((document) => document.id === source.documentId)?.stableKey === entry.expectedDocumentKey)) answeredPositives++;
          } else if (answer.status === 'insufficient_evidence') negativeFallbacks++;
        } catch (error) {
          item.error = error instanceof ChatbotError ? error.code : 'EVAL_REQUEST_FAILED';
          if (item.error === 'AI_TIMEOUT') timeouts++;
        }
        results.push(item);
      }
      if (benchmarkRuns) {
        const coldStarted = Date.now();
        try { await service.ask(dataset.questions[0].question, scope); }
        catch (error) { if (error instanceof ChatbotError && error.code === 'AI_TIMEOUT') timeouts++; }
        report.benchmarkPreparationMs = Date.now() - coldStarted;
        report.coldBenchmark = 'Not measured: restart/unload models explicitly and record a separate run.';
        for (let sample = 0; sample < benchmarkRuns; sample++) {
          const started = Date.now();
          try {
            const answer = await service.ask(dataset.questions[sample % 15].question, scope);
            if (answer.status === 'answered') warmLatencies.push(Date.now() - started);
            else results.push({ benchmarkSample: sample, error: 'BENCHMARK_NOT_ANSWERED' });
          } catch (error) {
            if (error instanceof ChatbotError && error.code === 'AI_TIMEOUT') timeouts++;
            results.push({ benchmarkSample: sample, error: error instanceof ChatbotError ? error.code : 'EVAL_REQUEST_FAILED' });
          }
        }
      }
    }
    report.summary = { positiveHits, answeredPositives, negativeFallbacks, timeouts,
      warmSamples: warmLatencies.length, warmP50Ms: percentile(warmLatencies, 0.5), warmP95Ms: percentile(warmLatencies, 0.95),
      automatedThresholdsPassed: !softwareOnly && automatedGate({ positiveHits, answeredPositives,
        negativeFallbacks, softwarePassed, warmLatencies, timeouts }) };
    report.nextGate = softwareOnly ? 'Run approved-corpus/model evaluation and benchmark; review answers manually.'
      : 'Human reviewer must score at least 13/15 answers against the checklists and confirm cold/RAM/swap measurements before enabling pilot.';
    if (!softwarePassed || (!softwareOnly && !(report.summary as { automatedThresholdsPassed: boolean }).automatedThresholdsPassed)) process.exitCode = 1;
  } catch (error) {
    report.error = error instanceof Error && /^[A-Z_]+$/.test(error.message) ? error.message : 'CHATBOT_EVALUATION_FAILED';
    process.exitCode = 1;
  } finally {
    for (const entry of [...dataset.questions, ...dataset.negativeQuestions]) {
      if (!results.some((result) => result.id === entry.id)) {
        results.push({ id: entry.id, expectedStatus: entry.expectedStatus, result: 'not_run' });
      }
    }
    await prisma?.$disconnect();
    const output = resolve(process.env.CHATBOT_EVAL_REPORT ?? 'docs/chatbot-eval-report.local.json');
    await writeFile(output, JSON.stringify(report, null, 2) + '\n', { mode: 0o600 });
    console.log(JSON.stringify({ report: output, pilotReady: false, error: report.error, summary: report.summary }));
  }
}

main().catch(() => { console.error('CHATBOT_EVALUATION_FAILED'); process.exitCode = 1; });
