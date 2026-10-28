import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { loadChatbotConfig } from '../src/chatbot/chatbot.config';
import { KnowledgeImporter } from '../src/chatbot/knowledge-importer';
import { KnowledgeRepository } from '../src/chatbot/knowledge.repository';
import { OllamaClient } from '../src/chatbot/ollama.client';
import { parseImportArgs } from '../src/chatbot/knowledge-import.cli';

async function main() {
  const config = loadChatbotConfig({ ...process.env, CHATBOT_ENABLED: 'false' });
  if (!config.embeddingDigest) throw new Error('Set OLLAMA_EMBED_DIGEST after reviewing the local model.');
  const root = process.env.KNOWLEDGE_ROOT
    ? process.env.KNOWLEDGE_ROOT
    : `${process.cwd()}/knowledge`;
  const { manifest } = parseImportArgs(process.argv.slice(2));
  const prisma = new PrismaClient();
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), config.timeoutMs);
  process.once('SIGINT', () => abort.abort());
  try {
    const importer = new KnowledgeImporter(
      new KnowledgeRepository(prisma),
      new OllamaClient(config),
      { root, embeddingModelDigest: config.embeddingDigest, embeddingDimensions: config.embeddingDimensions },
    );
    const result = await importer.importManifest(manifest, abort.signal);
    console.log(JSON.stringify(result, null, 2));
  } finally {
    clearTimeout(timeout);
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  const code = error instanceof Error && /^[A-Z_]{3,}$/.test(error.message)
    ? error.message : 'KNOWLEDGE_IMPORT_FAILED';
  console.error(code);
  process.exitCode = 1;
});
