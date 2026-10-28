import { Controller, Get, Query } from '@nestjs/common';

import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { ReportsService } from './reports.service';

@Controller('reports')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Get('monthly')
  @RequirePermissions('report.view')
  monthly(
    @CurrentUser() user: AuthUser,
    @Query('month') month?: string,
    @Query('propertyId') propertyId?: string,
  ) {
    return this.reports.monthly(landlordScopeId(user), month, propertyId);
  }

  @Get('monthly/export')
  @RequirePermissions('report.export')
  monthlyExport(
    @CurrentUser() user: AuthUser,
    @Query('month') month?: string,
    @Query('propertyId') propertyId?: string,
  ) {
    return this.reports.monthlyExport(landlordScopeId(user), month, propertyId);
  }

  @Get('analytics')
  @RequirePermissions('report.view')
  analytics(
    @CurrentUser() user: AuthUser,
    @Query('month') month?: string,
    @Query('propertyId') propertyId?: string,
  ) {
    return this.reports.analytics(landlordScopeId(user), month, propertyId);
  }
}
