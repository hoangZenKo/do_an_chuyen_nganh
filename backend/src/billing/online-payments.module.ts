import { Module } from '@nestjs/common';
import { DemoCardGateway } from './demo-card.gateway';
import { OnlinePaymentsService } from './online-payments.service';
import { ManualTransferService } from './manual-transfer.service';
import { TransferAccountController, TransferInstructionsController } from './manual-transfer.controller';
import { DemoCardPaymentController, LandlordOnlinePaymentsController, TenantOnlinePaymentsController } from './online-payments.controller';

@Module({ controllers: [LandlordOnlinePaymentsController, TenantOnlinePaymentsController, DemoCardPaymentController, TransferAccountController, TransferInstructionsController], providers: [OnlinePaymentsService, DemoCardGateway, ManualTransferService] })
export class OnlinePaymentsModule {}
