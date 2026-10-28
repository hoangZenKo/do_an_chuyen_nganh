import { Module } from '@nestjs/common';

import { AuditModule } from '../audit/audit.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import { BillingAutomationScheduler } from './billing-automation.scheduler';
import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { BillingCommandsService } from './billing-commands.service';
import { BillingLedgerService } from './billing-ledger.service';
import { BillingRemindersService } from './billing-reminders.service';
import { BillingOutboxService } from './billing-outbox.service';
import { BillingTariffsService } from './billing-tariffs.service';

@Module({
  imports: [PrismaModule, AuditModule, NotificationsModule],
  controllers: [BillingController],
  providers: [BillingService, BillingCommandsService, BillingLedgerService, BillingRemindersService, BillingOutboxService, BillingTariffsService, BillingAutomationScheduler],
})
export class BillingModule {}
