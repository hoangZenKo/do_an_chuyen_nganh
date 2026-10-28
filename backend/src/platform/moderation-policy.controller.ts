import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { ModerationPolicyDto } from './moderation-policy.dto';
import { ModerationPolicyService } from './moderation-policy.service';
import { ModerationQualityQuery, ModerationQualityReviewDto, ModerationSampleQuery } from './moderation-quality.dto';
import { ModerationQualityService } from './moderation-quality.service';

@ApiTags('Moderation')
@ApiBearerAuth()
@Controller('admin/moderation-policies')
@Roles(AuthRole.ADMIN)
export class ModerationPolicyController {
  constructor(private readonly policies: ModerationPolicyService, private readonly qa: ModerationQualityService) {}
  @Get() @AdminPermissions('admin.moderation.reports') list() { return this.policies.list(); }
  @Get('quality') @AdminPermissions('admin.moderation.reports') quality(@CurrentUser() actor: AuthUser, @Query() query: ModerationQualityQuery) { return this.policies.quality(actor, query); }
  @Get('quality/samples') @AdminPermissions('admin.moderation.reports') samples(@CurrentUser() actor: AuthUser, @Query() query: ModerationSampleQuery) { return this.qa.samples(actor, query); }
  @Get('quality/samples/:id') @AdminPermissions('admin.moderation.reports') sample(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.qa.detail(actor, id); }
  @Post('quality/samples/:id/review') @AdminPermissions('admin.moderation.reports') review(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ModerationQualityReviewDto) { return this.qa.review(actor, id, input); }
  @Post() @AdminPermissions('admin.admins.manage') create(@CurrentUser() actor: AuthUser, @Body() input: ModerationPolicyDto) { return this.policies.create(actor, input); }
  @Post(':id/activate') @AdminPermissions('admin.admins.manage') activate(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) {
    return this.policies.activate(actor, id, input.reason);
  }
}
