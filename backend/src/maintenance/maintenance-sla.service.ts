import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { workerHeartbeat } from '../common/worker-heartbeat';

@Injectable()
export class MaintenanceSlaService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MaintenanceSlaService.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  onModuleInit() {
    if (this.config.get('MAINTENANCE_SLA_WORKER_ENABLED') !== 'true') return;
    this.timer = setInterval(() => void this.tick(), 60000);
    this.timer.unref();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async escalate(landlordId?: string, now = new Date()) {
    return this.prisma.$transaction(async tx => {
      const tickets = await tx.maintenanceTicket.findMany({ where: {
        ...(landlordId ? { landlordId } : {}), status: { in: ['OPEN', 'IN_PROGRESS'] }, dueAt: { lt: now }, escalatedAt: null,
      }, orderBy: [{ dueAt: 'asc' }, { id: 'asc' }], take: 200 });
      let escalated = 0;
      for (const ticket of tickets) {
        const claimed = await tx.maintenanceTicket.updateMany({ where: { id: ticket.id, status: { in: ['OPEN', 'IN_PROGRESS'] }, dueAt: ticket.dueAt, escalatedAt: null }, data: { escalatedAt: now } });
        if (!claimed.count) continue;
        await tx.auditLog.create({ data: {
          landlordId: ticket.landlordId, actorRole: 'LANDLORD', action: 'maintenance.sla_escalated',
          resourceType: 'maintenance_ticket', resourceId: ticket.id, summary: 'Maintenance SLA overdue',
          metadata: { dueAt: ticket.dueAt!.toISOString(), assigneeStaffProfileId: ticket.assigneeStaffProfileId },
        } });
        escalated++;
      }
      return { data: { checked: tickets.length, escalated } };
    }, { timeout: 30000 });
  }

  private async tick() {
    if (this.running) return;
    this.running = true;
    try {
      await this.escalate();
      await workerHeartbeat(this.prisma, 'maintenance_sla', true);
    } catch (error) {
      this.logger.error('Maintenance SLA worker failed.', error);
      await workerHeartbeat(this.prisma, 'maintenance_sla', false).catch(() => undefined);
    } finally {
      this.running = false;
    }
  }
}
