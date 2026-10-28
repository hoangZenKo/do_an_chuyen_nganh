import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';

import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { CreateAdminPropertyDto } from './dto/create-admin-property.dto';
import { CreateLandlordDto } from './dto/create-landlord.dto';
import { ListAdminPropertiesQueryDto } from './dto/list-admin-properties-query.dto';
import { ListAdminRoomsQueryDto } from './dto/list-admin-rooms-query.dto';
import { ListLandlordsQueryDto } from './dto/list-landlords-query.dto';
import { UpdateAdminPropertyDto } from './dto/update-admin-property.dto';
import { UpdateLandlordDto } from './dto/update-landlord.dto';
import { UpdateLandlordStatusDto } from './dto/update-landlord-status.dto';
import { AdminService } from './admin.service';

@Controller('admin')
@Roles(AuthRole.ADMIN)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('overview')
  @AdminPermissions('admin.dashboard.view')
  overview(@CurrentUser() actor: AuthUser) {
    return this.admin.overview(actor);
  }

  @Get('landlords')
  @AdminPermissions('admin.accounts.manage')
  listLandlords(@Query() query: ListLandlordsQueryDto) {
    return this.admin.listLandlords(query);
  }

  @Post('landlords')
  @AdminPermissions('admin.accounts.manage')
  createLandlord(@CurrentUser() user: AuthUser, @Body() input: CreateLandlordDto) {
    return this.admin.createLandlord(input, user);
  }

  @Get('landlords/:id')
  @AdminPermissions('admin.accounts.manage')
  getLandlord(@Param('id') id: string) {
    return this.admin.getLandlord(id);
  }

  @Patch('landlords/:id')
  @AdminPermissions('admin.accounts.manage')
  updateLandlord(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: UpdateLandlordDto) {
    return this.admin.updateLandlord(id, input, user);
  }

  @Patch('landlords/:id/status')
  @AdminPermissions('admin.accounts.suspend')
  updateLandlordStatus(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateLandlordStatusDto,
  ) {
    return this.admin.updateLandlordStatus(user.userId, id, input, user);
  }

  @Get('properties')
  @Header('Cache-Control', 'private, no-store')
  @AdminPermissions('admin.properties.view')
  listProperties(@Query() query: ListAdminPropertiesQueryDto) {
    return this.admin.listProperties(query);
  }

  @Post('properties')
  @AdminPermissions('admin.properties.manage')
  createProperty(@CurrentUser() user: AuthUser, @Body() input: CreateAdminPropertyDto) {
    return this.admin.createProperty(input, user);
  }

  @Get('properties/:id')
  @Header('Cache-Control', 'private, no-store')
  @AdminPermissions('admin.properties.view')
  getProperty(@Param('id', ParseUUIDPipe) id: string) {
    return this.admin.getProperty(id);
  }

  @Get('rooms')
  @Header('Cache-Control', 'private, no-store')
  @AdminPermissions('admin.properties.view')
  rooms(@Query() query: ListAdminRoomsQueryDto) {
    return this.admin.rooms(query);
  }

  @Patch('properties/:id')
  @AdminPermissions('admin.properties.manage')
  updateProperty(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() input: UpdateAdminPropertyDto,
  ) {
    return this.admin.updateProperty(id, input, user);
  }
}
