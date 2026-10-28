import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { AnnouncementsService } from '../notifications/announcements.service';
import { RecurringService } from './recurring.service';
import { PrismaService } from '../prisma/prisma.service';
import { workerHeartbeat } from '../common/worker-heartbeat';

@Injectable()
export class OperationsScheduler implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  private running = false;
  private readonly logger = new Logger(OperationsScheduler.name);
  constructor(private readonly recurring: RecurringService, private readonly announcements: AnnouncementsService, private readonly prisma: PrismaService) {}
  onModuleInit() {
    if (process.env.NODE_ENV === 'test' || process.env.OPERATIONS_SCHEDULER_ENABLED === 'false') return;
    this.timer = setInterval(() => void this.tick(), 60000);
    this.timer.unref();
    void this.tick();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }
  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      const results = await Promise.allSettled([this.recurring.generateDue(), this.announcements.sendDue()]);
      results.forEach((result, index) => { if (result.status === 'rejected') this.logger.error(`${index === 0 ? 'Recurring' : 'Announcement'} scheduler failed; pending work will retry on the next tick.`); });
      await workerHeartbeat(this.prisma, 'operations', results.every(result => result.status === 'fulfilled')).catch(() => undefined);
    }
    finally { this.running = false; }
  }
}
