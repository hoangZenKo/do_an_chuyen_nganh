import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminStatusDto } from './admin-console.dto';
import { AdminLifecycleService } from './admin-lifecycle.service';

@Controller('admin/admins')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.admins.manage')
export class AdminLifecycleController {
  constructor(private readonly lifecycle: AdminLifecycleService) {}

  @Get(':id/lifecycle') @Header('Cache-Control', 'private, no-store')
  detail(@Param('id', ParseUUIDPipe) id: string) { return this.lifecycle.detail(id); }

  @Post(':id/resend-invite')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  resend(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminStatusDto) {
    return this.lifecycle.resend(actor, id, input);
  }

  @Post(':id/revoke-sessions') @AdminPermissions('admin.admins.manage', 'admin.sessions.revoke')
  revoke(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminStatusDto) {
    return this.lifecycle.revoke(actor, id, input);
  }
}
