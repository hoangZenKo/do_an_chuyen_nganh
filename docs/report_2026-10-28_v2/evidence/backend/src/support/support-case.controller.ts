import { Body, Controller, Header, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { IsIn, IsUUID } from 'class-validator';
import { AdminReasonDto, AdminStatusDto } from '../admin/admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { CaseResourceKind, SupportCaseService } from './support-case.service';

class CaseLinkDto extends AdminStatusDto {
  @IsIn(['PROPERTY', 'ROOM', 'LEASE', 'INVOICE', 'INCIDENT']) kind!: CaseResourceKind;
  @IsUUID() targetId!: string;
}

@Controller('admin/support-cases')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.support.read')
export class SupportCaseController {
  constructor(private readonly cases: SupportCaseService) {}
  @Post(':id/timeline') @Header('Cache-Control', 'private, no-store')
  timeline(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AdminReasonDto) { return this.cases.timeline(actor, id, input.reason); }
  @Post(':id/links') @AdminPermissions('admin.support.read', 'admin.support.manage')
  link(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: CaseLinkDto) { return this.cases.link(actor, id, input); }
}
