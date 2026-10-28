import { Body, Controller, Delete, Get, Param, Post, Put, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { TenantLifecycleService } from './tenant-lifecycle.service';
import { CreateLifecycleRequestDto, ExecuteLifecycleDto, LifecycleDecisionDto, LifecycleListQueryDto, LifecycleVersionDto, TenantNotificationPreferenceDto, TenantOccupantDto, TransferRoomsQueryDto } from './dto/tenant-lifecycle.dto';
import { LeaseSettlementsService } from '../leases/settlements.service';

@Controller('tenant')
@Roles(AuthRole.TENANT)
export class TenantLifecyclePortalController {
  constructor(private readonly lifecycle: TenantLifecycleService, private readonly settlements: LeaseSettlementsService) {}

  @Get('lifecycle-requests')
  requests(@CurrentUser() actor: AuthUser, @Query() query: LifecycleListQueryDto) { return this.lifecycle.requests(actor, query); }

  @Post('lifecycle-requests')
  create(@CurrentUser() actor: AuthUser, @Body() input: CreateLifecycleRequestDto) { return this.lifecycle.createRequest(actor, input); }

  @Post('lifecycle-requests/:id/cancel')
  cancel(@CurrentUser() actor: AuthUser, @Param('id') id: string, @Body() input: LifecycleVersionDto) { return this.lifecycle.cancelRequest(actor, id, input); }

  @Get('transfer-rooms')
  transferRooms(@CurrentUser() actor: AuthUser, @Query() query: TransferRoomsQueryDto) { return this.lifecycle.transferRooms(actor, query); }

  @Get('leases/:leaseId/settlement')
  settlement(@CurrentUser() actor: AuthUser, @Param('leaseId') leaseId: string) { return this.settlements.getForTenant(actor.userId, leaseId); }

  @Get('occupants')
  occupants(@CurrentUser() actor: AuthUser, @Query('leaseId') leaseId?: string) { return this.lifecycle.occupants(actor, leaseId); }

  @Get('notification-preferences')
  preference(@CurrentUser() actor: AuthUser) { return this.lifecycle.preference(actor); }

  @Put('notification-preferences')
  savePreference(@CurrentUser() actor: AuthUser, @Body() input: TenantNotificationPreferenceDto) { return this.lifecycle.savePreference(actor, input); }
}

@Controller('tenant-lifecycle')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class TenantLifecycleController {
  constructor(private readonly lifecycle: TenantLifecycleService) {}

  @Get('requests') @RequirePermissions('lease.view')
  requests(@CurrentUser() actor: AuthUser, @Query() query: LifecycleListQueryDto) { return this.lifecycle.requests(actor, query); }

  @Post('requests/:id/review') @RequirePermissions('lease.manage')
  review(@CurrentUser() actor: AuthUser, @Param('id') id: string, @Body() input: LifecycleDecisionDto) { return this.lifecycle.decideRequest(actor, id, input); }

  @Post('requests/:id/execute') @RequirePermissions('lease.manage')
  execute(@CurrentUser() actor: AuthUser, @Param('id') id: string, @Body() input: ExecuteLifecycleDto) { return this.lifecycle.executeRequest(actor, id, input); }

  @Get('leases/:leaseId/occupants') @RequirePermissions('lease.view')
  occupants(@CurrentUser() actor: AuthUser, @Param('leaseId') leaseId: string) { return this.lifecycle.occupants(actor, leaseId); }

  @Post('leases/:leaseId/occupants') @RequirePermissions('lease.manage')
  addOccupant(@CurrentUser() actor: AuthUser, @Param('leaseId') leaseId: string, @Body() input: TenantOccupantDto) { return this.lifecycle.addOccupant(actor, leaseId, input); }

  @Delete('leases/:leaseId/occupants/:id') @RequirePermissions('lease.manage')
  removeOccupant(@CurrentUser() actor: AuthUser, @Param('leaseId') leaseId: string, @Param('id') id: string) { return this.lifecycle.removeOccupant(actor, leaseId, id); }
}
