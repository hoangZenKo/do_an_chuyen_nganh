import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { AuthRole } from '../common/auth-role';
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from '../common/current-user.decorator';
import { RequirePermissions } from '../common/permissions.decorator';
import { Roles } from '../common/roles.decorator';
import { CompleteMaintenanceTicketDto } from './dto/complete-maintenance-ticket.dto';
import { CreateMaintenanceCommentDto } from './dto/create-maintenance-comment.dto';
import { CreateMaintenanceTicketDto } from './dto/create-maintenance-ticket.dto';
import { ListMaintenanceQueryDto } from './dto/list-maintenance-query.dto';
import { UpdateMaintenanceStatusDto } from './dto/update-maintenance-status.dto';
import { UpdateMaintenanceTicketDto } from './dto/update-maintenance-ticket.dto';
import { MaintenanceService } from './maintenance.service';
import { MaintenanceSlaService } from './maintenance-sla.service';

@Controller('maintenance')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class MaintenanceController {
  constructor(
    private readonly maintenance: MaintenanceService,
    private readonly audit: AuditService,
    private readonly sla: MaintenanceSlaService,
  ) {}

  @Get()
  @RequirePermissions('maintenance.view')
  list(@CurrentUser() user: AuthUser, @Query() query: ListMaintenanceQueryDto) {
    return this.maintenance.list(landlordScopeId(user), query);
  }

  @Post()
  @RequirePermissions('maintenance.manage')
  async create(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateMaintenanceTicketDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.maintenance.create(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.create',
      resourceType: 'maintenance_ticket',
      resourceId: result.data.id,
      summary: `Tạo phiếu bảo trì ${result.data.title}`,
      metadata: { priority: result.data.priority, roomId: result.data.roomId },
    });
    return result;
  }

  @Get('assignees')
  @RequirePermissions('maintenance.manage')
  assignees(@CurrentUser() user: AuthUser, @Query('propertyId') propertyId?: string) {
    return this.maintenance.assignees(landlordScopeId(user), propertyId);
  }

  @Get(':id')
  @RequirePermissions('maintenance.view')
  getById(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.maintenance.getById(landlordScopeId(user), id);
  }

  @Post('sla/escalate')
  @RequirePermissions('maintenance.manage')
  escalate(@CurrentUser() user: AuthUser) {
    return this.sla.escalate(landlordScopeId(user));
  }

  @Patch(':id')
  @RequirePermissions('maintenance.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateMaintenanceTicketDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.maintenance.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.update',
      resourceType: 'maintenance_ticket',
      resourceId: id,
      summary: `Cập nhật phiếu bảo trì ${result.data.title}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Post(':id/status')
  @RequirePermissions('maintenance.manage')
  async updateStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateMaintenanceStatusDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.maintenance.updateStatus(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.status_update',
      resourceType: 'maintenance_ticket',
      resourceId: id,
      summary: `Đổi trạng thái bảo trì ${result.data.title}`,
      metadata: { status: result.data.status },
    });
    return result;
  }

  @Post(':id/complete')
  @RequirePermissions('maintenance.complete')
  async complete(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CompleteMaintenanceTicketDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.maintenance.complete(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.complete',
      resourceType: 'maintenance_ticket',
      resourceId: id,
      summary: `Hoàn tất bảo trì ${result.data.title}`,
      metadata: { expenseId: result.data.expenseId },
    });
    return result;
  }

  @Post(':id/comments')
  @RequirePermissions('maintenance.manage')
  async addComment(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CreateMaintenanceCommentDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.maintenance.addComment(
      landlordId,
      id,
      user.userId,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.comment_create',
      resourceType: 'maintenance_ticket',
      resourceId: id,
      summary: 'Thêm bình luận bảo trì',
    });
    return result;
  }

  @Delete(':id')
  @RequirePermissions('maintenance.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.maintenance.remove(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'maintenance.delete',
      resourceType: 'maintenance_ticket',
      resourceId: id,
      summary: 'Xóa phiếu bảo trì',
    });
  }
}
