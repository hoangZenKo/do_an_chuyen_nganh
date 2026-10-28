import { Body, Controller, Get, Param, Patch, Post, Query } from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { CreateDepositTransactionDto } from './dto/create-deposit-transaction.dto';
import { CreateLeaseDto } from './dto/create-lease.dto';
import { RenewLeaseDto } from './dto/renew-lease.dto';
import { UpdateLeaseDto } from './dto/update-lease.dto';
import { LeasesService } from './leases.service';
import { LeaseSettlementsService } from './settlements.service';
import { ConfirmLeaseSettlementDto, LeaseSettlementDto, RecordSettlementRefundDto } from './dto/lease-settlement.dto';

@Controller('leases')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class LeasesController {
  constructor(
    private readonly leases: LeasesService,
    private readonly audit: AuditService,
    private readonly settlements: LeaseSettlementsService,
  ) {}

  @Post()
  @RequirePermissions('lease.manage')
  async create(@CurrentUser() user: AuthUser, @Body() input: CreateLeaseDto) {
    const landlordId = landlordScopeId(user);
    const result = await this.leases.create(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'lease.create',
      resourceType: 'lease',
      resourceId: result.data.id,
      summary: `Tạo hợp đồng cho ${result.data.tenantName ?? 'tenant'}`,
      metadata: {
        roomId: result.data.roomId,
        tenantId: result.data.tenantId,
        monthlyRent: result.data.monthlyRent,
      },
    });
    return result;
  }

  @Get('expiring')
  @RequirePermissions('lease.view')
  expiring(@CurrentUser() user: AuthUser, @Query('days') days?: string) {
    return this.leases.expiring(
      landlordScopeId(user),
      Number.parseInt(days ?? '30', 10) || 30,
    );
  }

  @Post(':id/end')
  @RequirePermissions('lease.manage')
  async end(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const landlordId = landlordScopeId(user);
    const result = await this.leases.end(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'lease.end',
      resourceType: 'lease',
      resourceId: id,
      summary: `Kết thúc hợp đồng của ${result.data.tenantName ?? 'tenant'}`,
      metadata: { roomId: result.data.roomId, tenantId: result.data.tenantId },
    });
    return result;
  }

  @Get(':id/settlement')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('lease.view')
  settlement(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.settlements.get(user, id);
  }

  @Post(':id/settlement/preview')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('lease.manage')
  previewSettlement(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: LeaseSettlementDto) {
    return this.settlements.preview(user, id, input);
  }

  @Post(':id/settlement/confirm')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('lease.manage')
  async confirmSettlement(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: ConfirmLeaseSettlementDto) {
    return this.settlements.confirm(user, id, input);
  }

  @Post(':id/settlement/refund')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('lease.manage')
  async recordSettlementRefund(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: RecordSettlementRefundDto) {
    return this.settlements.recordRefund(user, id, input);
  }

  @Patch(':id')
  @RequirePermissions('lease.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateLeaseDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.leases.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'lease.update',
      resourceType: 'lease',
      resourceId: id,
      summary: `Cập nhật hợp đồng của ${result.data.tenantName ?? 'tenant'}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Post(':id/renew')
  @RequirePermissions('lease.manage')
  async renew(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: RenewLeaseDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.leases.renew(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'lease.renew',
      resourceType: 'lease',
      resourceId: id,
      summary: `Gia hạn hợp đồng của ${result.data.tenantName ?? 'tenant'}`,
      metadata: { endDate: result.data.endDate },
    });
    return result;
  }

  @Get(':id/deposits')
  @RequirePermissions('lease.view')
  deposits(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.leases.depositTransactions(landlordScopeId(user), id);
  }

  @Post(':id/deposits')
  @RequirePermissions('lease.manage')
  async createDeposit(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CreateDepositTransactionDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.leases.createDepositTransaction(
      landlordId,
      id,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'lease.deposit_create',
      resourceType: 'lease',
      resourceId: id,
      summary: `Ghi nhận giao dịch cọc ${result.data.amount}`,
      metadata: { type: result.data.type, amount: result.data.amount },
    });
    return result;
  }
}

/** Lease history nested under a room. */
@Controller('rooms/:roomId/leases')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class RoomLeasesController {
  constructor(private readonly leases: LeasesService) {}

  @Get()
  @RequirePermissions('lease.view')
  list(@CurrentUser() user: AuthUser, @Param('roomId') roomId: string) {
    return this.leases.listByRoom(landlordScopeId(user), roomId);
  }
}

/** Lease history nested under a tenant. */
@Controller('tenants/:tenantId/leases')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class TenantLeasesController {
  constructor(private readonly leases: LeasesService) {}

  @Get()
  @RequirePermissions('lease.view')
  list(@CurrentUser() user: AuthUser, @Param('tenantId') tenantId: string) {
    return this.leases.listByTenant(landlordScopeId(user), tenantId);
  }
}
