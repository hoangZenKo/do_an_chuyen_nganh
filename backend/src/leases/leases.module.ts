import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';

import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import {
  LeasesController,
  RoomLeasesController,
  TenantLeasesController,
} from './leases.controller';
import { LeasesService } from './leases.service';
import { LeaseSettlementsService } from './settlements.service';

@Module({
  imports: [PassportModule, AuthModule, AuditModule],
  controllers: [
    LeasesController,
    RoomLeasesController,
    TenantLeasesController,
  ],
  providers: [LeasesService, LeaseSettlementsService],
  exports: [LeasesService, LeaseSettlementsService],
})
export class LeasesModule {}
