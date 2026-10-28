import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { NotificationDeliveryService } from './notification-delivery.service';

@Controller('admin/operations/notification-delivery')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.operations.view')
export class NotificationDeliveryController {
  constructor(private readonly delivery: NotificationDeliveryService) {}
  @Get() @Header('Cache-Control', 'no-store') queue() { return this.delivery.queue(); }
  @Post(':id/retry') @AdminPermissions('admin.operations.view', 'admin.operations.manage') retry(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.delivery.retry(actor, id, input.reason); }
}
