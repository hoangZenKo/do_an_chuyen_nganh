import { Controller, Get, Query } from '@nestjs/common';

import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { AuditService } from './audit.service';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';

@Controller('audit-logs')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class AuditController {
  constructor(private readonly audit: AuditService) {}

  @Get()
  @RequirePermissions('audit.view')
  list(@CurrentUser() user: AuthUser, @Query() query: ListAuditLogsQueryDto) {
    return this.audit.list(landlordScopeId(user), query);
  }
}
