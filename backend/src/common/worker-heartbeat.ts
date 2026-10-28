import { PrismaService } from '../prisma/prisma.service';

export async function workerHeartbeat(prisma: PrismaService, name: string, success: boolean) {
  const now = new Date();
  await prisma.workerHeartbeat.upsert({ where: { name },
    create: { name, status: success ? 'OK' : 'FAILED', lastRunAt: now, lastSuccessAt: success ? now : null },
    update: { status: success ? 'OK' : 'FAILED', lastRunAt: now, ...(success ? { lastSuccessAt: now } : {}) },
  });
}
