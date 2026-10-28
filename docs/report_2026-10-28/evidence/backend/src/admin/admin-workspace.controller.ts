import { Controller, Get, Header, Query } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminWorkspaceService } from './admin-workspace.service';
import { AdminWorkspaceQuery } from './admin-workspace.dto';

@Controller('admin/workspace')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.dashboard.view')
export class AdminWorkspaceController {
  constructor(private readonly workspace: AdminWorkspaceService) {}
  @Get('summary') @Header('Cache-Control', 'private, no-store')
  summary(@CurrentUser() actor: AuthUser) { return this.workspace.summary(actor); }
  @Get('action-items') @Header('Cache-Control', 'private, no-store')
  actionItems(@CurrentUser() actor: AuthUser, @Query() query: AdminWorkspaceQuery) { return this.workspace.actionItems(actor, query); }
}
