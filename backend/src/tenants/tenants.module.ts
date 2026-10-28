import { Module } from '@nestjs/common';
import { PassportModule } from '@nestjs/passport';

import { AuthModule } from '../auth/auth.module';
import { AuditModule } from '../audit/audit.module';
import { TenantInvitesController } from './tenant-invites.controller';
import { TenantInvitesService } from './tenant-invites.service';
import { TenantsController } from './tenants.controller';
import { TenantsService } from './tenants.service';

@Module({
  imports: [PassportModule, AuthModule, AuditModule],
  controllers: [TenantsController, TenantInvitesController],
  providers: [TenantsService, TenantInvitesService],
  exports: [TenantsService],
})
export class TenantsModule {}
