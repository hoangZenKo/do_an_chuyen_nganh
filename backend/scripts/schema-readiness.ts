import 'dotenv/config';
import { PrismaService } from '../src/prisma/prisma.service';
import { SchemaReadinessService } from '../src/health/schema-readiness.service';

async function main() {
  const prisma = new PrismaService();
  try {
    const result = await new SchemaReadinessService(prisma).inspect();
    console.log(JSON.stringify(result));
    if (!result.ready) {
      console.error('API schema is not ready. Rehearse migrations and verify a backup before running ops:migrate. No database changes were made.');
      process.exitCode = 1;
    }
  } finally { await prisma.$disconnect(); }
}

main().catch(() => {
  console.error('Schema readiness check failed. Check database connectivity and migration catalog. Credentials and database errors are not logged.');
  process.exitCode = 1;
});
