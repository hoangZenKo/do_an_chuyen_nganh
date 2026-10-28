import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { KnowledgeRepository } from '../src/chatbot/knowledge.repository';
import { parseRevokeArgs } from '../src/chatbot/knowledge-import.cli';

async function main() {
  const stableKey = parseRevokeArgs(process.argv.slice(2));
  const prisma = new PrismaClient();
  try {
    await new KnowledgeRepository(prisma).revoke(stableKey);
    console.log(`Revoked ${stableKey}`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  const code = error instanceof Error && /^[A-Z_]{3,}$/.test(error.message)
    ? error.message : 'KNOWLEDGE_REVOKE_FAILED';
  console.error(code);
  process.exitCode = 1;
});
