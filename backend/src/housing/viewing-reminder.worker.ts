import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HousingService } from './housing.service';
import { PrismaService } from '../prisma/prisma.service';
import { workerHeartbeat } from '../common/worker-heartbeat';

@Injectable()
export class ViewingReminderWorker implements OnModuleInit, OnModuleDestroy {
  private timer?: ReturnType<typeof setInterval>;
  private running = false;
  private readonly logger = new Logger(ViewingReminderWorker.name);
  constructor(private readonly housing: HousingService, private readonly config: ConfigService, private readonly prisma: PrismaService) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('VIEWING_REMINDER_WORKER_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.run(), 60_000);
    this.timer.unref();
  }

  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  private async run() {
    if (this.running) return;
    this.running = true;
    try { await this.housing.sendViewingReminders(); await workerHeartbeat(this.prisma, 'viewing-reminder', true); }
    catch (error) {
      this.logger.error('Không thể gửi nhắc lịch xem phòng', error instanceof Error ? error.stack : undefined);
      await workerHeartbeat(this.prisma, 'viewing-reminder', false).catch(() => undefined);
    }
    finally { this.running = false; }
  }
}
