import { Module } from '@nestjs/common';
import { LeasesModule } from '../leases/leases.module';
import { HousingController } from './housing.controller';
import { HousingService } from './housing.service';
import { HandoverService } from './handover.service';
import { ViewingReminderWorker } from './viewing-reminder.worker';

@Module({ imports: [LeasesModule], controllers: [HousingController], providers: [HousingService, HandoverService, ViewingReminderWorker] })
export class HousingModule {}
