import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminResourceQuery, AdminSearchQuery } from './admin-search.dto';
import { AdminSearchService } from './admin-search.service';

@ApiTags('Admin Operations')
@ApiBearerAuth()
@Controller('admin')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.dashboard.view')
export class AdminSearchController {
  constructor(private readonly search: AdminSearchService) {}

  @Get('search')
  searchAll(@CurrentUser() actor: AuthUser, @Query() query: AdminSearchQuery) { return this.search.search(actor, query); }

  @Get('resources')
  resources(@CurrentUser() actor: AuthUser, @Query() query: AdminResourceQuery) { return this.search.resources(actor, query); }

  @Get('resources/:id')
  detail(@CurrentUser() actor: AuthUser, @Query() query: AdminResourceQuery, @Param('id', ParseUUIDPipe) id: string) {
    return this.search.resources(actor, query, id);
  }
}
