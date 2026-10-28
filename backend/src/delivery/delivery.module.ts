import { Global, Module } from '@nestjs/common';
import { DeliveryCryptoService } from './delivery-crypto.service';
import { DeliveryService } from './delivery.service';

@Global()
@Module({ providers: [DeliveryCryptoService, DeliveryService], exports: [DeliveryCryptoService, DeliveryService] })
export class DeliveryModule {}
