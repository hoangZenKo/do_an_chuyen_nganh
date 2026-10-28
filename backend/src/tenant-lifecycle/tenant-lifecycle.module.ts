import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { TenantLifecycleController, TenantLifecyclePortalController } from './tenant-lifecycle.controller';
import { TenantLifecycleService } from './tenant-lifecycle.service';
import { LeasesModule } from '../leases/leases.module';

@Module({ imports: [PrismaModule, LeasesModule], controllers: [TenantLifecycleController, TenantLifecyclePortalController], providers: [TenantLifecycleService] })
export class TenantLifecycleModule {}
