import { Body, Controller, Delete, Get, Param, ParseIntPipe, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { SupportAutoAssignDto, SupportSkillDto, SupportViewDto } from './support-workflow.dto';
import { SupportWorkflowService } from './support-workflow.service';

@Controller('support')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.support.read', 'admin.support.manage')
export class SupportWorkflowController {
  constructor(private readonly workflow: SupportWorkflowService) {}
  @Get('views') views(@CurrentUser() actor: AuthUser) { return this.workflow.views(actor); }
  @Post('views') createView(@CurrentUser() actor: AuthUser, @Body() input: SupportViewDto) { return this.workflow.saveView(actor, input); }
  @Patch('views/:id') updateView(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportViewDto) { return this.workflow.saveView(actor, input, id); }
  @Delete('views/:id') deleteView(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Query('version', ParseIntPipe) version: number) { return this.workflow.deleteView(actor, id, version); }
  @Get('skills') @AdminPermissions('admin.support.read', 'admin.support.manage', 'admin.admins.manage') skills() { return this.workflow.skills(); }
  @Patch('skills/:id') @AdminPermissions('admin.support.read', 'admin.support.manage', 'admin.admins.manage') setSkills(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportSkillDto) { return this.workflow.setSkills(actor, id, input); }
  @Post('tickets/:id/auto-assign') @AdminPermissions('admin.support.read', 'admin.support.manage', 'admin.admins.manage') autoAssign(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportAutoAssignDto) { return this.workflow.autoAssign(actor, id, input); }
}
