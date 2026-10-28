import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { Roles } from '../common/roles.decorator';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { AdminAnalyticsQuery } from '../admin/admin-console.dto';
import { AppealAssignDto, AppealCreateDto, AppealQueryDto, AppealResolveDto, ModerationBulkDto } from './moderation-v2.dto';
import { ModerationV2Service } from './moderation-v2.service';
import { FeatureFlagsService } from './feature-flags.service';

@Controller('moderation')
@Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN)
@AdminPermissions('admin.dashboard.view')
export class MyModerationController {
  constructor(private readonly moderation: ModerationV2Service, private readonly flags: FeatureFlagsService) {}
  @Get('decisions') decisions(@CurrentUser() actor: AuthUser, @Query() query: AppealQueryDto) { return this.moderation.decisions(actor, query); }
  @Get('appeals') appeals(@CurrentUser() actor: AuthUser, @Query() query: AppealQueryDto) { return this.moderation.appeals(actor, query); }
  @Post('appeals') appeal(@CurrentUser() actor: AuthUser, @Body() input: AppealCreateDto) { return this.moderation.appeal(actor, input); }
  @Get('features') features(@CurrentUser() actor: AuthUser) { return this.flags.effective(actor); }
}

@Controller('admin/moderation-v2')
@Roles(AuthRole.ADMIN)
export class ModerationV2Controller {
  constructor(private readonly moderation: ModerationV2Service) {}
  @Get('decisions') @AdminPermissions('admin.moderation.reports') decisions(@CurrentUser() actor: AuthUser, @Query() query: AppealQueryDto) { return this.moderation.decisions(actor, query, true); }
  @Get('history/:kind/:id') @AdminPermissions('admin.dashboard.view') history(@CurrentUser() actor: AuthUser, @Param('kind') kind: string, @Param('id', ParseUUIDPipe) id: string) { return this.moderation.history(actor, kind, id); }
  @Get('appeals') @AdminPermissions('admin.moderation.appeals') appeals(@CurrentUser() actor: AuthUser, @Query() query: AppealQueryDto) { return this.moderation.appeals(actor, query, true); }
  @Post('appeals/:id/assign') @AdminPermissions('admin.moderation.appeals') assign(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AppealAssignDto) { return this.moderation.assign(actor, id, input); }
  @Post('appeals/:id/resolve') @AdminPermissions('admin.moderation.appeals') resolve(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AppealResolveDto) { return this.moderation.resolve(actor, id, input); }
  @Post('bulk') @AdminPermissions('admin.moderation.bulk') bulk(@CurrentUser() actor: AuthUser, @Body() input: ModerationBulkDto) { return this.moderation.bulk(actor, input); }
  @Post('bulk/preview') @AdminPermissions('admin.moderation.bulk') preview(@CurrentUser() actor: AuthUser, @Body() input: ModerationBulkDto) { return this.moderation.preview(actor, input); }
  @Get('reports') @AdminPermissions('admin.moderation.reports') reports(@CurrentUser() actor: AuthUser, @Query() query: AdminAnalyticsQuery) { return this.moderation.reports(actor, query.days); }
}
