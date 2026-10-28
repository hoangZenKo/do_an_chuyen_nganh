import { Controller, Get, Param, Post, Query } from '@nestjs/common';

import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { OperationsService } from './operations.service';
import { ActionItemsQuery } from './action-items.dto';

@Controller('operations')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class OperationsController {
  constructor(private readonly operations: OperationsService) {}

  @Get('action-items')
  @RequirePermissions('operation.view')
  actionItems(@CurrentUser() user: AuthUser, @Query() query: ActionItemsQuery) {
    return this.operations.actionItems(user, query);
  }

  @Post('action-items/:id/read')
  @RequirePermissions('operation.view')
  markRead(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.operations.markRead(user, id);
  }
}
