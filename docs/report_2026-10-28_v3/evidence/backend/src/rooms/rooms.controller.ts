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
import { CreateRoomAssetDto } from './dto/create-room-asset.dto';
import { CreateRoomInspectionDto } from './dto/create-room-inspection.dto';
import { CreateRoomServiceFeeDto } from './dto/create-room-service-fee.dto';
import { CreateRoomDto } from './dto/create-room.dto';
import { ListRoomsQueryDto } from './dto/list-rooms-query.dto';
import { UpdateRoomAssetDto } from './dto/update-room-asset.dto';
import { UpdateRoomInspectionDto } from './dto/update-room-inspection.dto';
import { UpdateRoomServiceFeeDto } from './dto/update-room-service-fee.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { UpdateRoomStatusDto } from './dto/update-room-status.dto';
import { RoomsService } from './rooms.service';

/** Rooms nested under a property: list and create. */
@Controller('properties/:propertyId/rooms')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class PropertyRoomsController {
  constructor(
    private readonly rooms: RoomsService,
    private readonly audit: AuditService,
  ) {}

  @Get()
  @RequirePermissions('room.view')
  list(
    @CurrentUser() user: AuthUser,
    @Param('propertyId') propertyId: string,
    @Query() query: ListRoomsQueryDto,
  ) {
    return this.rooms.listByProperty(landlordScopeId(user), propertyId, query);
  }

  @Post()
  @RequirePermissions('room.manage')
  async create(
    @CurrentUser() user: AuthUser,
    @Param('propertyId') propertyId: string,
    @Body() input: CreateRoomDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.create(landlordId, propertyId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room.create',
      resourceType: 'room',
      resourceId: result.data.id,
      summary: `Tạo phòng ${result.data.name}`,
      metadata: { propertyId, name: result.data.name },
    });
    return result;
  }
}

/** Single room by id: get, update, delete. */
@Controller('rooms')
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class RoomsController {
  constructor(
    private readonly rooms: RoomsService,
    private readonly audit: AuditService,
  ) {}

  @Get(':id')
  @RequirePermissions('room.view')
  getById(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rooms.getById(landlordScopeId(user), id);
  }

  @Patch(':id')
  @RequirePermissions('room.manage')
  async update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateRoomDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.update(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room.update',
      resourceType: 'room',
      resourceId: id,
      summary: `Cập nhật phòng ${result.data.name}`,
      metadata: { changedFields: Object.keys(input) },
    });
    return result;
  }

  @Patch(':id/status')
  @RequirePermissions('room.manage')
  async updateStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateRoomStatusDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.updateStatus(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room.status_update',
      resourceType: 'room',
      resourceId: id,
      summary: `Đổi trạng thái phòng ${result.data.name}`,
      metadata: { status: result.data.status },
    });
    return result;
  }

  @Delete(':id')
  @RequirePermissions('room.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.rooms.remove(landlordId, id);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room.delete',
      resourceType: 'room',
      resourceId: id,
      summary: 'Xóa phòng',
    });
  }

  @Get(':id/assets')
  @RequirePermissions('room.view')
  assets(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rooms.assets(landlordScopeId(user), id);
  }

  @Post(':id/assets')
  @RequirePermissions('room.manage')
  async createAsset(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CreateRoomAssetDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.createAsset(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_asset.create',
      resourceType: 'room_asset',
      resourceId: result.data.id,
      summary: `Thêm tài sản phòng ${result.data.name}`,
      metadata: { roomId: id, quantity: result.data.quantity },
    });
    return result;
  }

  @Patch(':id/assets/:assetId')
  @RequirePermissions('room.manage')
  async updateAsset(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('assetId') assetId: string,
    @Body() input: UpdateRoomAssetDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.updateAsset(landlordId, id, assetId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_asset.update',
      resourceType: 'room_asset',
      resourceId: assetId,
      summary: `Cập nhật tài sản phòng ${result.data.name}`,
      metadata: { roomId: id, changedFields: Object.keys(input) },
    });
    return result;
  }

  @Delete(':id/assets/:assetId')
  @RequirePermissions('room.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeAsset(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('assetId') assetId: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.rooms.removeAsset(landlordId, id, assetId);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_asset.delete',
      resourceType: 'room_asset',
      resourceId: assetId,
      summary: 'Xóa tài sản phòng',
      metadata: { roomId: id },
    });
  }

  @Get(':id/inspections')
  @RequirePermissions('room.view')
  inspections(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rooms.inspections(landlordScopeId(user), id);
  }

  @Post(':id/inspections')
  @RequirePermissions('room.manage')
  async createInspection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CreateRoomInspectionDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.createInspection(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_inspection.create',
      resourceType: 'room_inspection',
      resourceId: result.data.id,
      summary: `Lên lịch kiểm tra phòng ${result.data.title}`,
      metadata: { roomId: id, dueAt: result.data.dueAt },
    });
    return result;
  }

  @Patch(':id/inspections/:inspectionId')
  @RequirePermissions('room.manage')
  async updateInspection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('inspectionId') inspectionId: string,
    @Body() input: UpdateRoomInspectionDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.updateInspection(
      landlordId,
      id,
      inspectionId,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_inspection.update',
      resourceType: 'room_inspection',
      resourceId: inspectionId,
      summary: `Cập nhật lịch kiểm tra ${result.data.title}`,
      metadata: { roomId: id, changedFields: Object.keys(input) },
    });
    return result;
  }

  @Post(':id/inspections/:inspectionId/complete')
  @RequirePermissions('room.manage')
  async completeInspection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('inspectionId') inspectionId: string,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.completeInspection(
      landlordId,
      id,
      inspectionId,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_inspection.complete',
      resourceType: 'room_inspection',
      resourceId: inspectionId,
      summary: `Hoàn tất kiểm tra ${result.data.title}`,
      metadata: { roomId: id },
    });
    return result;
  }

  @Delete(':id/inspections/:inspectionId')
  @RequirePermissions('room.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeInspection(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('inspectionId') inspectionId: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.rooms.removeInspection(landlordId, id, inspectionId);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_inspection.delete',
      resourceType: 'room_inspection',
      resourceId: inspectionId,
      summary: 'Xóa lịch kiểm tra phòng',
      metadata: { roomId: id },
    });
  }

  @Get(':id/service-fees')
  @RequirePermissions('room.view')
  serviceFees(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.rooms.serviceFees(landlordScopeId(user), id);
  }

  @Post(':id/service-fees')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('room.manage')
  async createServiceFee(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: CreateRoomServiceFeeDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.createServiceFee(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_service_fee.create',
      resourceType: 'room_service_fee',
      resourceId: result.data.id,
      summary: `Thêm phí cố định ${result.data.name}`,
      metadata: { roomId: id, amount: result.data.amount },
    });
    return result;
  }

  @Patch(':id/service-fees/:feeId')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('room.manage')
  async updateServiceFee(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('feeId') feeId: string,
    @Body() input: UpdateRoomServiceFeeDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.rooms.updateServiceFee(landlordId, id, feeId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_service_fee.update',
      resourceType: 'room_service_fee',
      resourceId: feeId,
      summary: `Cập nhật phí cố định ${result.data.name}`,
      metadata: { roomId: id, changedFields: Object.keys(input) },
    });
    return result;
  }

  @Get(':id/service-fees/:feeId/versions')
  @RequirePermissions('room.view')
  tariffVersions(@CurrentUser() user: AuthUser, @Param('id') id: string, @Param('feeId') feeId: string) {
    return this.rooms.serviceFeeVersions(landlordScopeId(user), id, feeId);
  }

  @Delete(':id/service-fees/:feeId')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('room.manage')
  @HttpCode(HttpStatus.NO_CONTENT)
  async removeServiceFee(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Param('feeId') feeId: string,
  ): Promise<void> {
    const landlordId = landlordScopeId(user);
    await this.rooms.removeServiceFee(landlordId, id, feeId);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: 'room_service_fee.delete',
      resourceType: 'room_service_fee',
      resourceId: feeId,
      summary: 'Lên lịch ngừng thu phí cố định (giữ lịch sử)',
      metadata: { roomId: id },
    });
  }
}
