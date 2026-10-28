import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { SupportFeedbackDto, SupportLabelsDto, SupportMergeDto, SupportTemplateDto } from './support-tools.dto';
import { SupportToolsService } from './support-tools.service';

@ApiTags('Support')
@ApiBearerAuth()
@Controller('support')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.support.read', 'admin.support.manage')
export class SupportToolsController {
  constructor(private readonly tools: SupportToolsService) {}

  @Get('templates') templates() { return this.tools.templates(); }
  @Post('templates') create(@CurrentUser() actor: AuthUser, @Body() input: SupportTemplateDto) { return this.tools.saveTemplate(actor, input); }
  @Patch('templates/:id') update(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportTemplateDto) { return this.tools.saveTemplate(actor, input, id); }
  @Patch('tickets/:id/labels') labels(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportLabelsDto) { return this.tools.labels(actor, id, input); }
  @Post('tickets/:id/merge') merge(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportMergeDto) { return this.tools.merge(actor, id, input); }
  @Post('tickets/:id/feedback')
  @Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT)
  @AdminPermissions('admin.dashboard.view')
  feedback(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportFeedbackDto) { return this.tools.feedback(actor, id, input); }
}
