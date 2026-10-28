import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';
import { Roles } from '../common/roles.decorator';
import { FeatureFlagDto, FeatureFlagsService } from './feature-flags.service';
import { FinanceQueryDto, PermissionSimulationDto, ReportScheduleCreateDto, ReportScheduleUpdateDto, TeamCreateDto, TeamMemberDto, TeamUpdateDto } from './governance.dto';
import { GovernanceService } from './governance.service';
import { AdminReportWorkerService } from './admin-report-worker.service';

@Controller('admin')
@Roles(AuthRole.ADMIN)
export class GovernanceController {
  constructor(private readonly governance: GovernanceService, private readonly reports: AdminReportWorkerService) {}
  @Get('team') @AdminPermissions('admin.teams.manage') team() { return this.governance.team(); }
  @Get('teams') @AdminPermissions('admin.teams.manage') teams() { return this.governance.teams(); }
  @Post('teams') @AdminPermissions('admin.teams.manage') createTeam(@CurrentUser() actor: AuthUser, @Body() input: TeamCreateDto) { return this.governance.createTeam(actor, input); }
  @Post('teams/:id/members') @AdminPermissions('admin.teams.manage') addMember(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: TeamMemberDto) { return this.governance.addMember(actor, id, input); }
  @Patch('teams/:id') @AdminPermissions('admin.teams.manage') updateTeam(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: TeamUpdateDto) { return this.governance.updateTeam(actor, id, input); }
  @Post('teams/:id/members/:userId/remove') @AdminPermissions('admin.teams.manage') removeMember(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('userId', ParseUUIDPipe) userId: string, @Body() input: AdminReasonDto) { return this.governance.removeMember(actor, id, userId, input.reason); }
  @Post('permissions/simulate') @AdminPermissions('admin.permissions.simulate') simulate(@CurrentUser() actor: AuthUser, @Body() input: PermissionSimulationDto) { return this.governance.simulate(actor, input); }
  @Get('feature-flags') @AdminPermissions('admin.flags.manage') flagsList(@CurrentUser() actor: AuthUser) { return this.governance.flagsList(actor); }
  @Get('feature-flags/effective') @AdminPermissions('admin.dashboard.view') effective(@CurrentUser() actor: AuthUser) { return this.governance.flagsEffective(actor); }
  @Patch('feature-flags/:key') @AdminPermissions('admin.flags.manage') flagsUpdate(@CurrentUser() actor: AuthUser, @Param('key') key: string, @Body() input: FeatureFlagDto) { return this.governance.flagsUpdate(actor, key, input); }
  @Get('finance/reconciliation') @AdminPermissions('admin.finance.read') finance(@CurrentUser() actor: AuthUser, @Query() query: FinanceQueryDto) { return this.governance.finance(actor, query); }
  @Get('report-schedules') @AdminPermissions('admin.reports.manage') schedules(@CurrentUser() actor: AuthUser) { return this.governance.schedules(actor); }
  @Post('report-schedules') @AdminPermissions('admin.reports.manage') createSchedule(@CurrentUser() actor: AuthUser, @Body() input: ReportScheduleCreateDto) { return this.governance.createSchedule(actor, input); }
  @Patch('report-schedules/:id') @AdminPermissions('admin.reports.manage') updateSchedule(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReportScheduleUpdateDto) { return this.governance.updateSchedule(actor, id, input); }
  @Post('report-schedules/:id/run') @AdminPermissions('admin.reports.manage') runSchedule(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.governance.runSchedule(actor, id); }
  @Get('report-schedules/:id/runs') @AdminPermissions('admin.reports.manage') runs(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.reports.runs(actor, id); }
  @Post('report-runs/:id/retry') @AdminPermissions('admin.reports.manage') retry(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.reports.retry(actor, id, input.reason); }
  @Post('report-runs/:id/download-link') @AdminPermissions('admin.reports.manage') link(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.reports.downloadLink(actor, id); }
  @Get('report-runs/:id/download') @AdminPermissions('admin.reports.manage') async download(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Query('expires') expires: string | undefined, @Query('signature') signature: string | undefined, @Res() response: Response) {
    this.reports.verifyLink(actor, id, expires, signature);
    const csv = await this.reports.download(actor, id);
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('Content-Disposition', `attachment; filename="admin-report-${id}.csv"`);
    response.type('text/csv; charset=utf-8').send(csv);
  }
}
