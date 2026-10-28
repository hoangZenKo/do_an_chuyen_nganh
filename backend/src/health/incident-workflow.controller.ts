import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { IsIn, IsISO8601, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { AdminPageQuery, AdminStatusDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { IncidentAction, IncidentWorkflowService } from './incident-workflow.service';

export class IncidentQuery extends AdminPageQuery {
  @IsOptional() @IsIn(['OPEN', 'ACKNOWLEDGED', 'SNOOZED', 'RESOLVED']) status?: string;
  @IsOptional() @IsUUID() ownerId?: string;
  @IsOptional() @IsIn(['WARNING', 'CRITICAL']) severity?: string;
  @IsOptional() @IsIn(['all', 'mine', 'unassigned']) assignment?: string;
  @IsOptional() @IsIn(['all', '24h', '7d', '30d']) window?: string;
  @IsOptional() @IsString() @MaxLength(100) search?: string;
}
class IncidentCommand extends AdminStatusDto {
  @IsIn(['ACKNOWLEDGE', 'ASSIGN', 'SNOOZE', 'RESOLVE', 'REOPEN']) action!: IncidentAction;
  @IsOptional() @IsUUID() ownerId?: string;
  @IsOptional() @IsISO8601() snoozedUntil?: string;
}

@Controller('admin/operations/incidents')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.operations.view')
export class IncidentWorkflowController {
  constructor(private readonly incidents: IncidentWorkflowService) {}
  @Get() list(@CurrentUser() actor: AuthUser, @Query() query: IncidentQuery) { return this.incidents.list(actor, query); }
  @Get('assignees') assignees() { return this.incidents.assignees(); }
  @Get(':id') detail(@Param('id', ParseUUIDPipe) id: string) { return this.incidents.detail(id); }
  @Post(':id/actions') @AdminPermissions('admin.operations.view', 'admin.operations.manage')
  action(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: IncidentCommand) { return this.incidents.transition(actor, id, input); }
}
