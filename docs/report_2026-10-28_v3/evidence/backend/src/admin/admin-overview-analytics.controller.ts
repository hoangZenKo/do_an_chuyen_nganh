import { Controller, Get, Header, Query } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminOverviewAnalyticsService, AdminOverviewQuery } from './admin-overview-analytics.service';

@Controller('admin/analytics')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.dashboard.view')
export class AdminOverviewAnalyticsController {
  constructor(private readonly analytics: AdminOverviewAnalyticsService) {}

  @Get('overview')
  @Header('Cache-Control', 'private, no-store')
  overview(@CurrentUser() actor: AuthUser, @Query() query: AdminOverviewQuery) {
    return this.analytics.overview(actor, query);
  }
}
