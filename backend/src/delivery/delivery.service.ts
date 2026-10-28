import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { DeliveryCryptoService } from './delivery-crypto.service';
import { workerHeartbeat } from '../common/worker-heartbeat';

export function httpsEndpoint(raw: string | undefined) {
  try {
    const url = new URL(raw ?? '');
    return url.protocol === 'https:' && !url.username && !url.password && !url.hash ? url.toString() : null;
  } catch { return null; }
}

@Injectable()
export class DeliveryService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DeliveryService.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  private stopping = false;
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService,
    private readonly crypto: DeliveryCryptoService) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('DELIVERY_WORKER_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.runOnce(), 15000);
    this.timer.unref();
    void this.runOnce();
  }
  onModuleDestroy() { this.stopping = true; if (this.timer) clearInterval(this.timer); }

  configured(kind = 'ACCOUNT_ACCESS') {
    const prefix = kind === 'ACCOUNT_ACCESS' ? 'AUTH_DELIVERY' : 'OPERATIONS_ALERT';
    return this.crypto.ready() && !!httpsEndpoint(this.config.get<string>(`${prefix}_WEBHOOK_URL`)) &&
      (this.config.get('NODE_ENV') !== 'production' || !!this.config.get<string>(`${prefix}_WEBHOOK_SECRET`)?.trim());
  }

  async runOnce() {
    if (this.running || this.stopping) return;
    this.running = true;
    try {
      const now = new Date();
      const jobs = await this.prisma.deliveryJob.findMany({ where: { OR: [
        { status: 'PENDING', availableAt: { lte: now } },
        { status: 'PROCESSING', leaseUntil: { lte: now } },
      ] }, orderBy: { availableAt: 'asc' }, take: 25, select: { id: true } });
      for (const job of jobs) { if (!this.stopping) await this.deliver(job.id); }
      await workerHeartbeat(this.prisma, 'delivery', true);
    } catch {
      this.logger.error('Delivery worker failed; no payload or provider response logged.');
      await workerHeartbeat(this.prisma, 'delivery', false).catch(() => undefined);
    } finally { this.running = false; }
  }

  async deliver(id: string) {
    const now = new Date();
    const owner = randomUUID();
    const claimed = await this.prisma.deliveryJob.updateMany({ where: { id, OR: [
      { status: 'PENDING', availableAt: { lte: now } }, { status: 'PROCESSING', leaseUntil: { lte: now } },
    ] }, data: { status: 'PROCESSING', leaseOwner: owner, leaseUntil: new Date(now.getTime() + 60000), attempts: { increment: 1 } } });
    if (!claimed.count) return;
    const job = await this.prisma.deliveryJob.findUniqueOrThrow({ where: { id }, include: { token: { include: { user: { select: { isActive: true } } } } } });
    const finish = (data: object) => this.prisma.deliveryJob.updateMany({ where: { id, status: 'PROCESSING', leaseOwner: owner },
      data: { ...data, leaseOwner: null, leaseUntil: null } });
    if (job.expiresAt <= now || (job.kind === 'ACCOUNT_ACCESS' && (!job.token || job.token.consumedAt || !job.token.user.isActive || job.token.expiresAt <= now))) {
      await finish({ status: 'CANCELLED', payload: null, lastError: 'EXPIRED_OR_SUPERSEDED' });
      return;
    }
    let failure = 'DELIVERY_NOT_CONFIGURED';
    let retryable = true;
    try {
      if (!this.configured(job.kind)) throw new Error();
      const prefix = job.kind === 'ACCOUNT_ACCESS' ? 'AUTH_DELIVERY' : 'OPERATIONS_ALERT';
      const secret = this.config.get<string>(`${prefix}_WEBHOOK_SECRET`);
      let payload: string;
      try { payload = this.crypto.decrypt(job.payload ?? ''); }
      catch { failure = 'PAYLOAD_DECRYPT_FAILED'; throw new Error(); }
      failure = 'NETWORK_ERROR';
      const response = await fetch(httpsEndpoint(this.config.get<string>(`${prefix}_WEBHOOK_URL`))!, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: { 'content-type': 'application/json', 'idempotency-key': job.id, ...(secret ? { authorization: `Bearer ${secret}` } : {}) },
        body: payload,
      });
      await response.body?.cancel();
      if (!response.ok) {
        failure = `HTTP_${response.status}`;
        retryable = response.status === 408 || response.status === 429 || response.status >= 500;
        throw new Error();
      }
      await finish({ status: 'SENT', payload: null, deliveredAt: new Date(), lastError: null });
      return;
    } catch {
      const delay = Math.min(15 * 60 * 1000, 30000 * 2 ** Math.min(job.attempts - 1, 5));
      const next = new Date(Date.now() + delay + Math.floor(Math.random() * 5000));
      const dead = !retryable || job.attempts >= 6 || next >= job.expiresAt;
      await finish({ status: dead ? 'DEAD' : 'PENDING', lastError: failure, availableAt: next, ...(dead ? { payload: null } : {}) });
      if (dead && job.tokenId) await this.prisma.accountAccessToken.updateMany({ where: { id: job.tokenId, consumedAt: null }, data: { consumedAt: new Date() } });
    }
  }
}
