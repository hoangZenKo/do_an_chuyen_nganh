import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { PlatformNotificationService } from './platform-notification.service';
import { CreateSupportTicketDto, SupportAssignmentDto, SupportNoteDto, SupportPageDto, SupportReplyDto, SupportStatusDto } from './support.dto';
import { SupportService } from './support.service';

@Controller('support')
@Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT)
@AdminPermissions('admin.support.read')
export class SupportController {
  constructor(private readonly support: SupportService, private readonly notifications: PlatformNotificationService) {}
  @Post('tickets') @AdminPermissions('admin.dashboard.view') create(@CurrentUser() actor: AuthUser, @Body() input: CreateSupportTicketDto) { return this.support.create(actor, input); }
  @Get('tickets') list(@CurrentUser() actor: AuthUser, @Query() query: SupportPageDto) { return this.support.list(actor, query); }
  @Get('tickets/assignees') @Roles(AuthRole.ADMIN) @AdminPermissions('admin.support.manage') assignees() { return this.support.assignees(); }
  @Get('tickets/teams') @Roles(AuthRole.ADMIN) @AdminPermissions('admin.support.manage') teams() { return this.support.teams(); }
  @Get('tickets/:id') detail(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Query() query: SupportPageDto) { return this.support.detail(actor, id, query.page); }
  @Post('tickets/:id/replies') reply(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportReplyDto) { return this.support.reply(actor, id, input); }
  @Post('tickets/:id/notes') note(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportNoteDto) { return this.support.note(actor, id, input); }
  @Patch('tickets/:id/assignment') assign(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportAssignmentDto) { return this.support.assign(actor, id, input); }
  @Patch('tickets/:id/status') status(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportStatusDto) { return this.support.status(actor, id, input); }

  @Get('notifications') @AdminPermissions('admin.notifications.view') listNotifications(@CurrentUser() actor: AuthUser, @Query('unread') unread?: string) { return this.notifications.list(actor.userId, unread === 'true'); }
  @Post('notifications/:id/read') @AdminPermissions('admin.notifications.view') markNotification(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.notifications.markRead(actor.userId, id); }
  @Post('notifications/read-all') @AdminPermissions('admin.notifications.view') markAllNotifications(@CurrentUser() actor: AuthUser) { return this.notifications.markAllRead(actor.userId); }
}
