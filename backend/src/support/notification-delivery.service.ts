import { ConflictException, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { adminAudit } from '../admin/admin-audit';
import { httpsEndpoint } from '../delivery/delivery.service';

@Injectable()
export class NotificationDeliveryService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationDeliveryService.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}
  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('NOTIFICATION_DELIVERY_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.tick(), 15000); this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  async enqueue() {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102603)::text`;
      const missing = await tx.$queryRaw<{ id: string; channel: string }[]>`
        SELECT n.id, channel.name AS channel FROM "PlatformNotification" n
        JOIN "PlatformNotificationPreference" p ON p."userId" = n."userId"
        CROSS JOIN (VALUES ('EMAIL'), ('PUSH')) AS channel(name)
        WHERE ((channel.name = 'EMAIL' AND p.email) OR (channel.name = 'PUSH' AND p.push))
          AND n."createdAt" >= NOW() - INTERVAL '7 days'
          AND NOT EXISTS (SELECT 1 FROM "PlatformNotificationDelivery" d WHERE d."notificationId" = n.id AND d.channel = channel.name)
        ORDER BY n."createdAt", n.id, channel.name LIMIT 500`;
      if (missing.length) await tx.platformNotificationDelivery.createMany({ data: missing.map(row => ({ notificationId: row.id, channel: row.channel })), skipDuplicates: true });
      return missing.length;
    });
  }

  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      await this.enqueue();
      const jobs = await this.prisma.platformNotificationDelivery.findMany({ where: { OR: [{ status: 'PENDING', availableAt: { lte: new Date() } }, { status: 'PROCESSING', leaseUntil: { lte: new Date() } }] }, orderBy: { availableAt: 'asc' }, take: 25, select: { id: true } });
      for (const job of jobs) await this.deliver(job.id);
      await workerHeartbeat(this.prisma, 'notification-delivery', true);
    } catch {
      this.logger.error('Notification delivery worker unavailable; payloads are not logged.');
      await workerHeartbeat(this.prisma, 'notification-delivery', false).catch(() => undefined);
    } finally { this.running = false; }
  }

  async deliver(id: string) {
    const leaseOwner = randomUUID(), now = new Date();
    const claimed = await this.prisma.platformNotificationDelivery.updateMany({ where: { id, OR: [{ status: 'PENDING', availableAt: { lte: now } }, { status: 'PROCESSING', leaseUntil: { lte: now } }] }, data: { status: 'PROCESSING', leaseOwner, leaseUntil: new Date(Date.now() + 60000), attempts: { increment: 1 } } });
    if (!claimed.count) return;
    const job = await this.prisma.platformNotificationDelivery.findUniqueOrThrow({ where: { id }, include: { notification: { include: { user: { include: { notificationPreference: true, adminProfile: true } } } } } });
    const finish = (data: object) => this.prisma.platformNotificationDelivery.updateMany({ where: { id, status: 'PROCESSING', leaseOwner }, data: { ...data, leaseOwner: null, leaseUntil: null } });
    const user = job.notification.user;
    const enabled = job.channel === 'EMAIL' ? user.notificationPreference?.email : user.notificationPreference?.push;
    if (!user.isActive || !enabled || job.notification.createdAt.getTime() < Date.now() - 7 * 86400000 || (user.role === 'ADMIN' && !user.adminProfile?.permissions.includes('admin.notifications.view'))) {
      await finish({ status: 'CANCELLED', lastError: 'RECIPIENT_DISABLED_OR_EXPIRED' }); return;
    }
    let failure = 'PROVIDER_NOT_CONFIGURED', retryable = true;
    try {
      const prefix = job.channel === 'EMAIL' ? 'NOTIFICATION_EMAIL' : 'NOTIFICATION_PUSH';
      const url = httpsEndpoint(this.config.get<string>(`${prefix}_WEBHOOK_URL`));
      const secret = this.config.get<string>(`${prefix}_WEBHOOK_SECRET`)?.trim();
      if (!url || !secret) throw new Error();
      failure = 'NETWORK_ERROR';
      const response = await fetch(url, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: { 'content-type': 'application/json', authorization: `Bearer ${secret}`, 'idempotency-key': id },
        body: JSON.stringify({ deliveryId: id, channel: job.channel, userId: user.id, ...(job.channel === 'EMAIL' ? { email: user.email } : {}), notificationId: job.notificationId, kind: job.notification.kind,
          title: 'Rental Room: new notification', actionPath: job.notification.actionPath }) });
      await response.body?.cancel();
      if (!response.ok) { failure = `HTTP_${response.status}`; retryable = response.status === 408 || response.status === 429 || response.status >= 500; throw new Error(); }
      await finish({ status: 'SENT', deliveredAt: new Date(), lastError: null });
    } catch {
      await finish({ status: !retryable || job.attempts >= 6 ? 'DEAD' : 'PENDING', lastError: failure,
        availableAt: new Date(Date.now() + Math.min(3600000, 30000 * 2 ** Math.min(job.attempts - 1, 7)) + Math.floor(Math.random() * 5000)) });
    }
  }

  async queue() {
    const counts = await this.prisma.platformNotificationDelivery.groupBy({ by: ['channel', 'status'], _count: true });
    const dead = await this.prisma.platformNotificationDelivery.findMany({ where: { status: 'DEAD' }, select: { id: true, channel: true, attempts: true, lastError: true, createdAt: true }, orderBy: { createdAt: 'desc' }, take: 100 });
    return { data: { counts, dead } };
  }

  async retry(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      const result = await tx.platformNotificationDelivery.updateMany({ where: { id, status: 'DEAD', notification: { createdAt: { gt: new Date(Date.now() - 7 * 86400000) } } }, data: { status: 'PENDING', attempts: 0, lastError: null, availableAt: new Date(), leaseOwner: null, leaseUntil: null } });
      if (!result.count) throw new ConflictException('Only unexpired dead letters can be retried.');
      await adminAudit(tx, actor, 'admin.notification_delivery_retried', 'notification_delivery', id, reason);
      return { data: { id, queued: true } };
    });
  }
}
