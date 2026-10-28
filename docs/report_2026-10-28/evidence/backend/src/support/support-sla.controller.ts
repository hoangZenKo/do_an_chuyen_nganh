import { Body, Controller, Get, Patch } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { SupportSlaPolicyDto } from './support-sla.dto';
import { SupportSlaService } from './support-sla.service';

@Controller('admin/support-sla-policy')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.support.read', 'admin.support.manage', 'admin.admins.manage')
export class SupportSlaController {
  constructor(private readonly sla: SupportSlaService) {}
  @Get() policy() { return this.sla.policy(); }
  @Patch() update(@CurrentUser() actor: AuthUser, @Body() input: SupportSlaPolicyDto) { return this.sla.update(actor, input); }
}
