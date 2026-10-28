import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { httpsEndpoint } from '../delivery/delivery.service';
import { PrismaService } from '../prisma/prisma.service';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { BillingCommandsService } from './billing-commands.service';
import { BillingRemindersService, reminderMatches } from './billing-reminders.service';
import { businessDay } from './billing-rules';
import { BillingReasonDto } from './dto/billing-ledger.dto';
import { tenantAllowsReminder } from '../tenant-lifecycle/notification-channels';

export function retryDelay(attempts: number) {
  return Math.min(3600000, 15000 * 2 ** Math.max(0, attempts - 1));
}

@Injectable()
export class BillingOutboxService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(BillingOutboxService.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  private stopping = false;

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService, private readonly reminders: BillingRemindersService, private readonly commands: BillingCommandsService) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('BILLING_OUTBOX_WORKER_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.runOnce(), 30000);
    this.timer.unref();
  }

  onModuleDestroy() { this.stopping = true; if (this.timer) clearInterval(this.timer); }

  async runOnce(now = new Date()) {
    if (this.running || this.stopping) return;
    this.running = true;
    try {
      await this.reminders.enqueue(now);
      const jobs = await this.prisma.billingOutboxEvent.findMany({ where: { OR: [{ status: 'PENDING', availableAt: { lte: now } }, { status: 'PROCESSING', leaseUntil: { lte: now } }] }, orderBy: { availableAt: 'asc' }, take: 100, select: { id: true } });
      for (const job of jobs) { if (!this.stopping) await this.deliver(job.id); }
      await workerHeartbeat(this.prisma, 'billing-outbox', true);
    } catch {
      this.logger.error('Billing outbox iteration failed. No provider payload logged.');
      await workerHeartbeat(this.prisma, 'billing-outbox', false).catch(() => undefined);
    } finally { this.running = false; }
  }

  async deliver(id: string, now = new Date()) {
    const owner = randomUUID();
    const claim = await this.prisma.billingOutboxEvent.updateMany({ where: { id, OR: [{ status: 'PENDING', availableAt: { lte: now } }, { status: 'PROCESSING', leaseUntil: { lte: now } }] }, data: { status: 'PROCESSING', leaseOwner: owner, leaseUntil: new Date(now.getTime() + 60000), attempts: { increment: 1 } } });
    if (!claim.count) return;
    const job = await this.prisma.billingOutboxEvent.findUniqueOrThrow({ where: { id } });
    const finish = (data: Prisma.BillingOutboxEventUpdateManyMutationInput) => this.prisma.billingOutboxEvent.updateMany({ where: { id, status: 'PROCESSING', leaseOwner: owner }, data: { ...data, leaseOwner: null, leaseUntil: null } });
    try {
      if (job.type === 'invoice.reminder') {
        const payload = job.payload as { channel: string; policyId: string; policyVersion: number; scheduledDay: string };
        const invoice = await this.reminderInvoice(job.resourceId, job.landlordId);
        const policies = invoice ? await this.prisma.billingReminderPolicy.findMany({ where: { landlordId: job.landlordId, scopeKey: { in: [`property:${invoice.room.propertyId}`, `landlord:${job.landlordId}`] } } }) : [];
        const policy = policies.find((row) => row.propertyId === invoice?.room.propertyId) ?? policies.find((row) => !row.propertyId);
        if (invoice && !tenantAllowsReminder(invoice.tenant.notificationPreference, payload.channel)) {
          await finish({ status: 'SKIPPED', completedAt: now, lastError: 'TENANT_CHANNEL_DISABLED' }); return;
        }
        if (!invoice || !invoice.tenant.isActive || invoice.status === 'CANCELLED' || invoice.paidAmount >= invoice.totalAmount || !invoice.dueDate || !policy || policy.id !== payload.policyId || policy.version !== payload.policyVersion || !policy.channels.includes(payload.channel) || !reminderMatches(policy, invoice.dueDate, now) || payload.scheduledDay !== businessDay(now)) {
          await finish({ status: 'SKIPPED', completedAt: now, lastError: 'NO_LONGER_ELIGIBLE' }); return;
        }
        const remainingAmount = invoice.totalAmount - invoice.paidAmount;
        const title = 'Nhắc thanh toán hóa đơn';
        const body = `Phòng ${invoice.room.name}: còn ${remainingAmount.toLocaleString('vi-VN')} đ, hạn ${invoice.dueDate.toISOString().slice(0, 10)}.`;
        if (payload.channel === 'APP') {
          await this.prisma.billingNotification.upsert({ where: { eventKey: job.eventKey }, create: { tenantId: invoice.tenantId, invoiceId: invoice.id, eventKey: job.eventKey, title, body }, update: {} });
        } else {
          const recipient = payload.channel === 'EMAIL' ? invoice.tenant.user?.email : invoice.tenant.phone;
          if (!recipient) { await finish({ status: 'SKIPPED', completedAt: now, lastError: 'RECIPIENT_MISSING' }); return; }
          await this.post(`BILLING_${payload.channel}`, job.eventKey, { eventId: job.id, type: job.type, channel: payload.channel, recipient, invoiceId: invoice.id, tenantId: invoice.tenantId, remainingAmount, title, body });
        }
      } else {
        const url = this.config.get<string>('BILLING_EVENT_WEBHOOK_URL');
        if (!url) { await finish({ status: 'STORED', completedAt: now }); return; }
        await this.post('BILLING_EVENT', job.eventKey, { eventId: job.id, eventKey: job.eventKey, type: job.type, resourceId: job.resourceId, createdAt: job.createdAt, payload: job.payload });
      }
      await finish({ status: 'COMPLETED', completedAt: now, lastError: null });
    } catch {
      const dead = job.attempts >= 8;
      await finish({ status: dead ? 'DEAD' : 'PENDING', availableAt: new Date(now.getTime() + retryDelay(job.attempts)), lastError: 'DELIVERY_FAILED' });
    }
  }

  async list(user: AuthUser) {
    const rows = await this.prisma.billingOutboxEvent.findMany({ where: { landlordId: landlordScopeId(user) }, orderBy: { createdAt: 'desc' }, take: 200 });
    return { data: rows };
  }

  private reminderInvoice(id: string, landlordId: string) {
    return this.prisma.invoice.findFirst({ where: { id, isDemo: false, room: { property: { landlordId, isArchived: false, landlord: { isActive: true } } } }, include: { room: true, tenant: { include: { user: true, notificationPreference: true } } } });
  }

  retry(user: AuthUser, id: string, input: BillingReasonDto) {
    return this.commands.execute(user, 'billing.outbox.retry', id, input, async (tx) => {
      const result = await tx.billingOutboxEvent.updateMany({ where: { id, landlordId: landlordScopeId(user), status: { in: ['DEAD', 'STORED'] } }, data: { status: 'PENDING', attempts: 0, availableAt: new Date(), lastError: null, completedAt: null } });
      return { data: { retried: result.count === 1 } };
    });
  }

  private async post(prefix: string, idempotencyKey: string, body: unknown) {
    const url = httpsEndpoint(this.config.get<string>(`${prefix}_WEBHOOK_URL`));
    const secret = this.config.get<string>(`${prefix}_WEBHOOK_SECRET`)?.trim();
    if (!url || !secret) throw new Error('PROVIDER_NOT_CONFIGURED');
    const response = await fetch(url, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000), headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${secret}`, 'Idempotency-Key': idempotencyKey }, body: JSON.stringify(body) });
    if (!response.ok) throw new Error('PROVIDER_REJECTED');
  }
}
