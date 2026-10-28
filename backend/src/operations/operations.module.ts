import { Module } from '@nestjs/common';

import { OperationsController } from './operations.controller';
import { OperationsService } from './operations.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { P1OperationsController } from './p1.controller';
import { TurnoversService } from './turnovers.service';
import { RecurringService } from './recurring.service';
import { OperationsScheduler } from './operations.scheduler';

@Module({
  imports: [NotificationsModule],
  controllers: [OperationsController, P1OperationsController],
  providers: [OperationsService, TurnoversService, RecurringService, OperationsScheduler],
})
export class OperationsModule {}
