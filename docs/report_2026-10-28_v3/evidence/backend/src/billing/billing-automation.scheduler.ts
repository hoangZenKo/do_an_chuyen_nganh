import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

import { NotificationsService } from "../notifications/notifications.service";
import { BillingService } from "./billing.service";
import { PrismaService } from '../prisma/prisma.service';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { BillingRemindersService } from './billing-reminders.service';

@Injectable()
export class BillingAutomationScheduler implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(BillingAutomationScheduler.name);
  private initialTimer?: NodeJS.Timeout;
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(
    private readonly billing: BillingService,
    private readonly config: ConfigService,
    private readonly notifications: NotificationsService,
    private readonly prisma: PrismaService,
    private readonly reminders: BillingRemindersService,
  ) {}

  onModuleInit() {
    const workerSetting = this.config.get<string>(
      "BILLING_AUTOMATION_WORKER_ENABLED",
    );
    const isTest = this.config.get<string>("NODE_ENV") === "test";
    if (workerSetting === "false" || (isTest && workerSetting !== "true")) {
      this.logger.log("Billing automation worker is disabled.");
      return;
    }

    const intervalMs = this.positiveInt(
      this.config.get<string>("BILLING_AUTOMATION_INTERVAL_MS"),
      60 * 60 * 1000,
    );
    const initialDelayMs = this.positiveInt(
      this.config.get<string>("BILLING_AUTOMATION_INITIAL_DELAY_MS"),
      10_000,
    );

    this.initialTimer = setTimeout(() => void this.runOnce(), initialDelayMs);
    this.timer = setInterval(() => void this.runOnce(), intervalMs);
  }

  onModuleDestroy() {
    if (this.initialTimer) clearTimeout(this.initialTimer);
    if (this.timer) clearInterval(this.timer);
  }

  async runOnce(now = new Date()) {
    if (this.running) return;
    this.running = true;
    try {
      const result = await this.billing.runDueBillingAutomations(now);
      const {
        checkedCount,
        createdCount,
        existingCount,
        skippedCount,
        failedCount,
      } = result.data;
      if (checkedCount > 0) {
        this.logger.log(
          `Billing automation checked ${checkedCount}: created=${createdCount}, existing=${existingCount}, skipped=${skippedCount}, failed=${failedCount}.`,
        );
      }
      if (this.shouldSendReminders()) {
        await this.sendRemindersForCreatedRuns(result.data.results);
      }
      await workerHeartbeat(this.prisma, 'billing', failedCount === 0);
    } catch (error) {
      this.logger.error("Billing automation worker failed.", error as Error);
      await workerHeartbeat(this.prisma, 'billing', false).catch(() => undefined);
    } finally {
      this.running = false;
    }
  }

  private async sendRemindersForCreatedRuns(
    results: Array<{
      landlordId: string;
      propertyId: string;
      status: string;
      createdCount?: number;
    }>,
  ) {
    const dueSoonDays = this.config.get<string>(
      "BILLING_AUTOMATION_REMINDER_DUE_SOON_DAYS",
    ) ?? "60";
    for (const item of results) {
      if (item.status !== "created" || !item.createdCount) continue;
      await this.reminders.enqueue(new Date(), item.landlordId, item.propertyId);
    }
  }

  private shouldSendReminders() {
    return (
      this.config.get<string>("BILLING_AUTOMATION_SEND_REMINDERS") === "true"
    );
  }

  private positiveInt(raw: string | undefined, fallback: number) {
    const value = Number.parseInt(raw ?? "", 10);
    return Number.isFinite(value) && value > 0 ? value : fallback;
  }
}
