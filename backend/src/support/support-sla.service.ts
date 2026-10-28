import { BadRequestException, ConflictException, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from '../admin/admin-audit';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { addWorkingMilliseconds, calendarFormatter, SupportSlaSnapshot } from './business-calendar';
import { SupportSlaPolicyDto } from './support-sla.dto';
import { PlatformNotificationService } from './platform-notification.service';

@Injectable()
export class SupportSlaService implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  private running = false;
  private readonly logger = new Logger(SupportSlaService.name);
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService, private readonly notifications: PlatformNotificationService) {}
  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('SUPPORT_SLA_WORKER_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.run().catch(() => this.logger.error('Support SLA worker unavailable.')), 60000);
    this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  async policy() {
    return { data: await this.prisma.supportSlaPolicy.findUnique({ where: { id: 'platform' } }) ?? {
      version: 0, enabled: false, timezone: 'Asia/Ho_Chi_Minh', weekdays: [1, 2, 3, 4, 5], startMinute: 540, endMinute: 1020,
      holidays: [], pauseWaiting: false, responseMinutes: { LOW: 2880, NORMAL: 1440, HIGH: 240, URGENT: 60 }, resolutionMinutes: { LOW: 7200, NORMAL: 4320, HIGH: 1440, URGENT: 720 }, escalationMinutes: [0, 240, 1440],
    } };
  }
  async snapshot(): Promise<SupportSlaSnapshot | null> {
    const { data } = await this.policy();
    if (!data.enabled) return null;
    return { version: data.version, timezone: data.timezone, weekdays: data.weekdays, startMinute: data.startMinute, endMinute: data.endMinute, holidays: data.holidays, pauseWaiting: data.pauseWaiting, responseMinutes: data.responseMinutes as Record<string, number>, resolutionMinutes: data.resolutionMinutes as Record<string, number>, escalationMinutes: data.escalationMinutes };
  }
  async update(actor: AuthUser, input: SupportSlaPolicyDto) {
    calendarFormatter(input.timezone);
    if (input.endMinute - input.startMinute < 60) throw new BadRequestException('Business window must be at least 60 minutes and cannot cross midnight.');
    if (input.holidays.some(day => !Number.isFinite(Date.parse(day)) || new Date(day).toISOString().slice(0, 10) !== day)) throw new BadRequestException('Invalid holiday date.');
    if (input.escalationMinutes[0] !== 0 || input.escalationMinutes.some((value, index) => index > 0 && value <= input.escalationMinutes[index - 1])) throw new BadRequestException('Escalation levels must start at zero and increase.');
    for (const priority of ['LOW', 'NORMAL', 'HIGH', 'URGENT'] as const) if (input.resolutionMinutes[priority] < input.responseMinutes[priority]) throw new BadRequestException('Resolution SLA cannot be shorter than response SLA.');
    const { reason, version, ...values } = input;
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102611)::text`;
      const previous = await tx.supportSlaPolicy.findUnique({ where: { id: 'platform' } });
      if ((previous?.version ?? 0) !== version) throw new ConflictException('SLA policy changed. Reload first.');
      const data = await tx.supportSlaPolicy.upsert({ where: { id: 'platform' }, create: { ...values, updatedById: actor.userId, responseMinutes: { ...values.responseMinutes }, resolutionMinutes: { ...values.resolutionMinutes } }, update: { ...values, updatedById: actor.userId, responseMinutes: { ...values.responseMinutes }, resolutionMinutes: { ...values.resolutionMinutes }, version: { increment: 1 } } });
      await adminAudit(tx, actor, 'admin.support_sla_policy_updated', 'support_sla_policy', data.id, reason, { version: data.version, newTicketsOnly: true });
      return { data, newTicketsOnly: true };
    });
  }

  async run(now = new Date()) {
    if (this.running) return { processed: 0 };
    this.running = true;
    try {
      const processed = await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102612)::text`;
        const ids = await tx.supportTicket.findMany({ where: { slaSnapshot: { not: Prisma.DbNull }, mergedIntoId: null, status: { notIn: ['RESOLVED', 'CLOSED'] }, OR: [{ firstRespondedAt: null, firstResponseDueAt: { lt: now } }, { slaPausedAt: null, resolutionDueAt: { lt: now } }] }, select: { id: true }, orderBy: [{ slaCheckedAt: { sort: 'asc', nulls: 'first' } }, { id: 'asc' }], take: 100 });
        let total = 0;
        for (const { id } of ids) {
          await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
          const ticket = await tx.supportTicket.findUniqueOrThrow({ where: { id } });
          if (ticket.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(ticket.status)) continue;
          const snapshot = ticket.slaSnapshot as unknown as SupportSlaSnapshot;
          const deadlines = [{ kind: 'RESPONSE', deadline: ticket.firstResponseDueAt, active: !ticket.firstRespondedAt }, { kind: 'RESOLUTION', deadline: ticket.resolutionDueAt, active: !ticket.slaPausedAt }];
          for (const item of deadlines.filter(item => item.active && item.deadline < now)) {
            for (let level = 0; level < snapshot.escalationMinutes.length; level++) {
              if (addWorkingMilliseconds(item.deadline, snapshot.escalationMinutes[level] * 60000, snapshot) > now) continue;
              const key = { ticketId: id, kind: item.kind, deadlineAt: item.deadline, level: level + 1 };
              if (await tx.supportEscalation.findUnique({ where: { ticketId_kind_deadlineAt_level: key } })) continue;
              const recipients = await tx.user.findMany({ where: { role: 'ADMIN', isActive: true,
                adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage', 'admin.notifications.view'] } },
                OR: [
                  ...(level === 0 && ticket.assigneeId ? [{ id: ticket.assigneeId }] : []),
                  ...(level < 2 && ticket.teamId ? [{ adminTeamMemberships: { some: { teamId: ticket.teamId, role: 'LEAD', team: { isActive: true } } } }] : []),
                  { adminProfile: { preset: 'super_admin' } },
                ],
              }, select: { id: true }, orderBy: { id: 'asc' }, take: 100 });
              if (!recipients.length) continue;
              const escalation = await tx.supportEscalation.create({ data: key });
              for (const recipient of recipients) await this.notifications.create(tx, { userId: recipient.id, eventKey: `support-escalation:${escalation.id}`, kind: 'SUPPORT_SLA', title: `Ticket quá SLA · cấp ${level + 1}`, body: 'Mở hồ sơ để kiểm tra và xử lý.', actionPath: `/admin/tickets?ticketId=${id}` });
              await tx.auditLog.create({ data: { actorRole: 'ADMIN', action: 'system.support_sla_escalated', resourceType: 'support_ticket', resourceId: id, summary: `Support ${item.kind} SLA escalated to level ${level + 1}`, metadata: { deadlineAt: item.deadline.toISOString(), policyVersion: snapshot.version, recipients: recipients.length } } });
              total++;
            }
          }
          await tx.supportTicket.update({ where: { id }, data: { slaCheckedAt: now, updatedAt: ticket.updatedAt } });
        }
        return total;
      }, { timeout: 30000 });
      await workerHeartbeat(this.prisma, 'support-sla', true);
      return { processed };
    } catch (error) { await workerHeartbeat(this.prisma, 'support-sla', false).catch(() => undefined); throw error; }
    finally { this.running = false; }
  }
}
