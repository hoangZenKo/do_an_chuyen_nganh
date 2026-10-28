import { Injectable, NotFoundException } from '@nestjs/common';
import { BillingReminderPolicy } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { tenantAllowsReminder } from '../tenant-lifecycle/notification-channels';
import { BillingCommandsService } from './billing-commands.service';
import { billingError, businessDay, dueDays } from './billing-rules';
import { ReminderPolicyDto } from './dto/billing-ledger.dto';

export function reminderMatches(policy: Pick<BillingReminderPolicy, 'enabled' | 'beforeDays' | 'onDueDate' | 'overdueDays'>, dueDate: Date, now: Date) {
  if (!policy.enabled) return false;
  const days = dueDays(dueDate, now);
  return days < 0 ? policy.beforeDays.includes(-days) : days === 0 ? policy.onDueDate : policy.overdueDays.includes(days);
}

@Injectable()
export class BillingRemindersService {
  constructor(private readonly prisma: PrismaService, private readonly commands: BillingCommandsService) {}

  async policy(user: AuthUser, propertyId?: string) {
    const landlordId = landlordScopeId(user);
    if (propertyId) await this.ownedProperty(landlordId, propertyId);
    const scopeKey = propertyId ? `property:${propertyId}` : `landlord:${landlordId}`;
    const [policy, inherited] = await Promise.all([
      this.prisma.billingReminderPolicy.findUnique({ where: { scopeKey } }),
      propertyId ? this.prisma.billingReminderPolicy.findUnique({ where: { scopeKey: `landlord:${landlordId}` } }) : null,
    ]);
    return { data: { policy: policy ?? { scopeKey, landlordId, propertyId: propertyId ?? null, enabled: false, beforeDays: [3, 1], onDueDate: true, overdueDays: [1, 7, 30], channels: ['APP'], version: 0 }, inherited: policy ? null : inherited } };
  }

  save(user: AuthUser, input: ReminderPolicyDto) {
    const landlordId = landlordScopeId(user);
    const scopeKey = input.propertyId ? `property:${input.propertyId}` : `landlord:${landlordId}`;
    if (input.enabled && !input.channels.length) billingError('REMINDER_CHANNEL_REQUIRED', 'An enabled policy must have a delivery channel.');
    return this.commands.execute(user, 'billing.reminder_policy.update', scopeKey, input, async (tx) => {
      if (input.propertyId) {
        const property = await tx.property.findFirst({ where: { id: input.propertyId, landlordId, isArchived: false }, select: { id: true } });
        if (!property) throw new NotFoundException('Property not found.');
      }
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`billing-policy:${scopeKey}`}, 0))::text`;
      const current = await tx.billingReminderPolicy.findUnique({ where: { scopeKey } });
      if ((current?.version ?? 0) !== input.expectedVersion) billingError('REMINDER_POLICY_CONFLICT', 'Policy changed. Reload before saving.', true);
      const values = { enabled: input.enabled, beforeDays: [...input.beforeDays].sort((left, right) => left - right), onDueDate: input.onDueDate, overdueDays: [...input.overdueDays].sort((left, right) => left - right), channels: input.channels };
      const policy = await tx.billingReminderPolicy.upsert({ where: { scopeKey }, create: { landlordId, scopeKey, propertyId: input.propertyId ?? null, ...values }, update: { ...values, version: { increment: 1 } } });
      return { data: policy };
    });
  }

  async enqueue(now = new Date(), landlordId?: string, propertyId?: string) {
    if (propertyId && landlordId) await this.ownedProperty(landlordId, propertyId);
    const policies = await this.prisma.billingReminderPolicy.findMany({ where: landlordId ? { landlordId } : {} });
    const byScope = new Map(policies.map((policy) => [policy.scopeKey, policy]));
    const owners = [...new Set(policies.map((policy) => policy.landlordId))];
    let cursor: string | undefined;
    let queued = 0;
    while (owners.length) {
      const invoices = await this.prisma.invoice.findMany({ where: { isDemo: false, status: { in: ['UNPAID', 'PARTIAL'] }, dueDate: { not: null }, room: { ...(propertyId ? { propertyId } : {}), property: { landlordId: { in: owners }, isArchived: false, landlord: { isActive: true } } } }, include: { room: { include: { property: true } }, tenant: { include: { notificationPreference: true } } }, orderBy: { id: 'asc' }, take: 250, ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) });
      for (const invoice of invoices) {
        const policy = byScope.get(`property:${invoice.room.propertyId}`) ?? byScope.get(`landlord:${invoice.room.property.landlordId}`);
        if (!policy || !invoice.dueDate || invoice.totalAmount <= invoice.paidAmount || !reminderMatches(policy, invoice.dueDate, now)) continue;
        for (const channel of policy.channels) {
          if (!invoice.tenant.isActive || !tenantAllowsReminder(invoice.tenant.notificationPreference, channel)) continue;
          const eventKey = `reminder:${invoice.id}:${invoice.dueDate.toISOString().slice(0, 10)}:${businessDay(now)}:${channel}`;
          const inserted = await this.prisma.billingOutboxEvent.createMany({ data: [{ landlordId: policy.landlordId, eventKey, type: 'invoice.reminder', resourceId: invoice.id, availableAt: now, payload: { invoiceId: invoice.id, channel, policyId: policy.id, policyVersion: policy.version, scheduledDay: businessDay(now) } }], skipDuplicates: true });
          queued += inserted.count;
        }
      }
      if (invoices.length < 250) break;
      cursor = invoices[invoices.length - 1].id;
    }
    return { data: { queued, businessDay: businessDay(now) } };
  }

  private async ownedProperty(landlordId: string, id: string) {
    const property = await this.prisma.property.findFirst({ where: { id, landlordId }, select: { id: true } });
    if (!property) throw new NotFoundException('Property not found.');
  }
}
