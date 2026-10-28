import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { AcceptStaffInviteDto } from './dto/accept-staff-invite.dto';
import { CreateStaffInviteDto } from './dto/create-staff-invite.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { StaffService } from './staff.service';
import { SimulateStaffPermissionDto } from './dto/simulate-staff-permission.dto';

@Controller('staff')
export class StaffController {
  constructor(
    private readonly staff: StaffService,
    private readonly audit: AuditService,
  ) {}

  @Get('presets')
  @Roles(AuthRole.LANDLORD, AuthRole.STAFF)
  @RequirePermissions('staff.view')
  presets() {
    return this.staff.presets();
  }

  @Get()
  @Roles(AuthRole.LANDLORD, AuthRole.STAFF)
  @RequirePermissions('staff.view')
  list(@CurrentUser() user: AuthUser) {
    return this.staff.list(landlordScopeId(user));
  }

  @Post('invites')
  @Roles(AuthRole.LANDLORD, AuthRole.STAFF)
  @RequirePermissions('staff.manage')
  async createInvite(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateStaffInviteDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.staff.createInvite(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'staff.invite_create',
      resourceType: 'staff_invite',
      resourceId: result.data.id,
      summary: `Tạo lời mời nhân viên ${result.data.fullName}`,
      metadata: {
        email: result.data.email,
        preset: result.data.preset,
        permissions: result.data.permissions,
      },
    });
    return result;
  }

  @Patch(':id')
  @Roles(AuthRole.LANDLORD, AuthRole.STAFF)
  @RequirePermissions('staff.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateStaffDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.staff.update(landlordId, id, input, user);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'staff.update',
      resourceType: 'staff_profile',
      resourceId: id,
      summary: `Cập nhật nhân viên ${result.data.fullName}`,
      metadata: {
        changedFields: Object.keys(input),
        isActive: result.data.isActive,
        preset: result.data.preset,
      },
    });
    return result;
  }

  @Post(':id/simulate')
  @Roles(AuthRole.LANDLORD)
  simulate(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: SimulateStaffPermissionDto) {
    return this.staff.simulate(landlordScopeId(user), id, input);
  }

  @Post('invites/accept')
  accept(@Body() input: AcceptStaffInviteDto) {
    return this.staff.accept(input);
  }
}
