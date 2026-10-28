import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { AnnouncementsService } from './announcements.service';
import { CreateAnnouncementDto, CreateAnnouncementTemplateDto, CreateTenantGroupDto } from '../operations/p1.dto';

@Controller('announcements')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class AnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}
  @Get() @RequirePermissions('notification.view', 'notification.manage') list(@CurrentUser() user: AuthUser) { return this.announcements.list(user); }
  @Get('templates') @RequirePermissions('notification.view', 'notification.manage') templates(@CurrentUser() user: AuthUser) { return this.announcements.templates(user); }
  @Get('groups') @RequirePermissions('notification.view', 'notification.manage') groups(@CurrentUser() user: AuthUser) { return this.announcements.groups(user); }
  @Post('templates') @RequirePermissions('notification.manage') createTemplate(@CurrentUser() user: AuthUser, @Body() input: CreateAnnouncementTemplateDto) { return this.announcements.createTemplate(user, input); }
  @Post('groups') @RequirePermissions('notification.manage') createGroup(@CurrentUser() user: AuthUser, @Body() input: CreateTenantGroupDto) { return this.announcements.createGroup(user, input); }
  @Post() @RequirePermissions('notification.manage') create(@CurrentUser() user: AuthUser, @Body() input: CreateAnnouncementDto) { return this.announcements.create(user, input); }
  @Get(':id/receipts') @RequirePermissions('notification.view', 'notification.manage') receipts(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.announcements.receipts(user, id); }
  @Post(':id/cancel') @RequirePermissions('notification.manage') cancel(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.announcements.cancel(user, id); }
}

@Controller('tenant/announcements')
@Roles(AuthRole.TENANT)
export class TenantAnnouncementsController {
  constructor(private readonly announcements: AnnouncementsService) {}
  @Get() list(@CurrentUser() user: AuthUser) { return this.announcements.tenantAnnouncements(user); }
  @Post(':id/read') read(@CurrentUser() user: AuthUser, @Param('id') id: string) { return this.announcements.markRead(user, id); }
}
