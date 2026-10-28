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
import { CreatePropertyDto } from './dto/create-property.dto';
import { ListPropertiesQueryDto } from './dto/list-properties-query.dto';
import { UpdatePropertyDto } from './dto/update-property.dto';
import { UpdatePropertyStatusDto } from './dto/update-property-status.dto';
import { PropertiesService } from './properties.service';

@Controller('properties')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class PropertiesController {
  constructor(
    private readonly properties: PropertiesService,
    private readonly audit: AuditService,
  ) {}

  @Get()
  @RequirePermissions('property.view')
  list(@CurrentUser() user: AuthUser, @Query() query: ListPropertiesQueryDto) {
    return this.properties.list(landlordScopeId(user), query);
  }

  @Post()
  @RequirePermissions('property.manage')
  async create(@CurrentUser() user: AuthUser, @Body() input: CreatePropertyDto) {
    const landlordId = landlordScopeId(user);
    const result = await this.properties.create(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'property.create',
      resourceType: 'property',
      resourceId: result.data.id,
      summary: `Tạo khu trọ ${result.data.name}`,
      metadata: { name: result.data.name },
    });
    return result;
  }

  @Get(':id')
  @RequirePermissions('property.view')
  getById(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.properties.getById(landlordScopeId(user), id);
  }

  @Patch(':id')
  @RequirePermissions('property.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdatePropertyDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.properties.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'property.update',
      resourceType: 'property',
      resourceId: id,
      summary: `Cập nhật khu trọ ${result.data.name}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Patch(':id/status')
  @RequirePermissions('property.manage')
  async updateStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdatePropertyStatusDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.properties.updateStatus(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'property.status_update',
      resourceType: 'property',
      resourceId: id,
      summary: `${result.data.isArchived ? 'Lưu trữ' : 'Mở lại'} khu trọ ${result.data.name}`,
      metadata: { isArchived: result.data.isArchived },
    });
    return result;
  }

  @Delete(':id')
  @RequirePermissions('property.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.properties.remove(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'property.delete',
      resourceType: 'property',
      resourceId: id,
      summary: 'Xóa khu trọ',
    });
  }
}
