import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { Roles } from '../common/roles.decorator';
import { PlatformNotificationService } from './platform-notification.service';
import { NotificationPreferencesDto } from './support-workflow.dto';

@Controller('notification-center')
@Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT)
@AdminPermissions('admin.notifications.view')
export class NotificationCenterController {
  constructor(private readonly notifications: PlatformNotificationService) {}
  @Get() list(@CurrentUser() actor: AuthUser, @Query('unread') unread?: string) { return this.notifications.list(actor.userId, unread === 'true'); }
  @Get('preferences') preferences(@CurrentUser() actor: AuthUser) { return this.notifications.preferences(actor.userId); }
  @Patch('preferences') updatePreferences(@CurrentUser() actor: AuthUser, @Body() input: NotificationPreferencesDto) { return this.notifications.updatePreferences(actor.userId, input); }
  @Post(':id/read') @AdminPermissions('admin.notifications.view') markRead(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.notifications.markRead(actor.userId, id); }
  @Post('read-all') @AdminPermissions('admin.notifications.view') markAllRead(@CurrentUser() actor: AuthUser) { return this.notifications.markAllRead(actor.userId); }
}
