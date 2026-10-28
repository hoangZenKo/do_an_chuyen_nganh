import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type { OperationsQueueQuery } from './operations-queue.controller';

@Injectable()
export class OperationsQueueService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: OperationsQueueQuery) {
    const where = { status: query.jobStatus ?? 'DEAD' };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.deliveryJob.count({ where }),
      this.prisma.deliveryJob.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: query.limit, skip: (query.page - 1) * query.limit,
        select: { id: true, kind: true, status: true, attempts: true, availableAt: true, expiresAt: true, lastError: true, createdAt: true, updatedAt: true } }),
    ], { isolationLevel: 'RepeatableRead' });
    const safeError = (value: string | null) => !value ? null : /^(DELIVERY_NOT_CONFIGURED|PAYLOAD_DECRYPT_FAILED|NETWORK_ERROR|EXPIRED_OR_SUPERSEDED|HTTP_[1-5][0-9]{2})$/.test(value) ? value : 'REDACTED';
    return { data: rows.map(row => ({ ...row, lastError: safeError(row.lastError), retryable: false,
      retryReason: 'No manual replay: account-access dead letters discard their payload. Resend an unactivated admin invitation through its lifecycle workflow; verify provider idempotency before any other recovery.' })),
      meta: { total, page: query.page, limit: query.limit, generatedAt: new Date().toISOString() } };
  }
}
