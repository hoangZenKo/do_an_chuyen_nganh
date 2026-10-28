import { Controller, Get, Query } from '@nestjs/common';

import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { DashboardService } from './dashboard.service';
import { DashboardMetricsQueryDto } from './dto/dashboard-metrics-query.dto';

@Controller('dashboard')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Get('metrics')
  @RequirePermissions('report.view')
  metrics(
    @CurrentUser() user: AuthUser,
    @Query() query: DashboardMetricsQueryDto,
  ) {
    return this.dashboard.metrics(landlordScopeId(user), query);
  }
}
