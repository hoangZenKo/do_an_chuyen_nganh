import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Patch, Post, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { Throttle } from '@nestjs/throttler';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { AdminAnalyticsQuery, AdminAuditQuery, AdminAuditExportDto, AdminContextQuery, AdminInviteDto, AdminPageQuery, AdminProfileDto, AdminQueueQuery, AdminReasonDto, AdminStatusDto, AdminWorkDto } from './admin-console.dto';
import { AdminConsoleService } from './admin-console.service';
import { OperationsHealthService } from '../health/operations-health.service';
import { AdminAuditQueryService } from './admin-audit-query.service';

@Controller('admin')
@Roles(AuthRole.ADMIN)
export class AdminConsoleController {
  constructor(private readonly console: AdminConsoleService, private readonly health: OperationsHealthService, private readonly auditQuery: AdminAuditQueryService) {}
  @Get('me/capabilities') @AdminPermissions('admin.dashboard.view')
  capabilities(@CurrentUser() user: AuthUser) { return { data: { permissions: user.permissions } }; }
  @Get('accounts') @AdminPermissions('admin.accounts.view')
  @Header('Cache-Control', 'private, no-store')
  accounts(@Query() query: AdminPageQuery) { return this.console.accounts(query); }
  @Get('accounts/:id') @AdminPermissions('admin.accounts.view')
  @Header('Cache-Control', 'private, no-store')
  account(@Param('id', ParseUUIDPipe) id: string) { return this.console.account(id); }
  @Post('accounts/:id/suspend') @AdminPermissions('admin.accounts.suspend')
  suspend(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminStatusDto) { return this.console.status(actor, id, input, false); }
  @Post('accounts/:id/restore') @AdminPermissions('admin.accounts.suspend')
  restore(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminStatusDto) { return this.console.status(actor, id, input, true); }
  @Post('accounts/:id/revoke-sessions') @AdminPermissions('admin.sessions.revoke')
  revoke(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.console.revoke(actor, id, input.reason); }
  @Post('accounts/:id/reveal') @AdminPermissions('admin.pii.reveal')
  @Header('Cache-Control', 'no-store')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  reveal(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.console.reveal(actor, id, input.reason); }
  @Post('accounts/:id/reset-password') @AdminPermissions('admin.accounts.manage')
  reset(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.console.reset(actor, id, input.reason); }
  @Post('account-invites') @AdminPermissions('admin.dashboard.view')
  invite(@CurrentUser() actor: AuthUser, @Body() input: AdminInviteDto) { return this.console.invite(actor, input); }
  @Get('admins') @AdminPermissions('admin.admins.manage')
  admins(@Query() query: AdminPageQuery) { return this.console.accounts(query, true); }
  @Patch('admins/:id') @AdminPermissions('admin.admins.manage')
  @Throttle({ default: { limit: 5, ttl: 60000 } })
  profile(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminProfileDto) { return this.console.updateAdmin(actor, id, input); }
  @Get('audit-logs') @AdminPermissions('admin.audit.view')
  audit(@Query() query: AdminAuditQuery) { return this.console.audit(query); }
  @Get('audit-logs/:id') @AdminPermissions('admin.audit.view')
  auditDetail(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.auditQuery.detail(actor, id); }
  @Post('audit-logs/export') @AdminPermissions('admin.audit.view', 'admin.audit.export')
  @Throttle({ default: { limit: 3, ttl: 60000 } })
  async auditExport(@CurrentUser() actor: AuthUser, @Body() input: AdminAuditExportDto, @Res() response: Response) {
    const csv = await this.auditQuery.export(actor, input);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('Content-Disposition', 'attachment; filename="audit-export.csv"');
    response.type('text/csv; charset=utf-8').send(csv);
  }
  @Post('support-context') @AdminPermissions('admin.support.read')
  @Header('Cache-Control', 'no-store')
  context(@CurrentUser() actor: AuthUser, @Body() input: AdminContextQuery) { return this.console.context(actor, input); }
  @Get('moderation/queue') @AdminPermissions('admin.dashboard.view')
  queue(@CurrentUser() actor: AuthUser, @Query() query: AdminQueueQuery) { return this.console.queue(actor, query); }
  @Post('moderation/work') @AdminPermissions('admin.dashboard.view')
  work(@CurrentUser() actor: AuthUser, @Body() input: AdminWorkDto) { return this.console.work(actor, input); }
  @Get('moderation/items/:kind/:id') @AdminPermissions('admin.dashboard.view')
  item(@CurrentUser() actor: AuthUser, @Param('kind') kind: string, @Param('id', ParseUUIDPipe) id: string) { return this.console.moderationItem(actor, kind, id); }
  @Get('analytics/summary') @AdminPermissions('admin.dashboard.view')
  analytics(@CurrentUser() actor: AuthUser, @Query() query: AdminAnalyticsQuery) { return this.console.analytics(actor, query); }
  @Get('operations/health') @AdminPermissions('admin.operations.view')
  @Header('Cache-Control', 'no-store')
  operationsHealth() { return this.health.summary(); }
  @Post('operations/incidents/:id/acknowledge') @AdminPermissions('admin.operations.manage')
  acknowledgeIncident(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminStatusDto) {
    return this.health.acknowledge(actor, id, input.version, input.reason);
  }
}
