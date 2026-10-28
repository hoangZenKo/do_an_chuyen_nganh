import { Body, Controller, Param, Post } from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { AcceptTenantInviteDto } from './dto/accept-tenant-invite.dto';
import { CreateTenantInviteDto } from './dto/create-tenant-invite.dto';
import { TenantInvitesService } from './tenant-invites.service';

@Controller()
export class TenantInvitesController {
  constructor(
    private readonly invites: TenantInvitesService,
    private readonly audit: AuditService,
  ) {}

  @Post('tenants/:id/invite')
  @Roles(AuthRole.LANDLORD, AuthRole.STAFF)
  @RequirePermissions('tenant.manage')
  async create(
    @CurrentUser() user: AuthUser,
    @Param('id') tenantId: string,
    @Body() input: CreateTenantInviteDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.invites.create(landlordId, tenantId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'tenant.invite_create',
      resourceType: 'tenant',
      resourceId: tenantId,
      summary: 'Tạo lời mời tenant',
      metadata: { email: input.email.trim().toLowerCase() },
    });
    return result;
  }

  @Post('tenant-invites/accept')
  accept(@Body() input: AcceptTenantInviteDto) {
    return this.invites.accept(input);
  }
}
