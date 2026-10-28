import { BadRequestException, Body, Controller, Get, Param, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { UploadsService } from './uploads.service';

@Controller('uploads')
@Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF, AuthRole.ADMIN)
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}
  @Post()
  @Roles(AuthRole.LANDLORD, AuthRole.TENANT, AuthRole.STAFF)
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 1 } }))
  upload(@CurrentUser() user: AuthUser, @UploadedFile() file?: { buffer: Buffer }, @Body('purpose') purpose = 'PRIVATE') {
    if (!file || !['PRIVATE', 'PUBLIC_LISTING'].includes(purpose)) throw new BadRequestException('Cần chọn file và mục đích hợp lệ.');
    return this.uploads.save(user, file.buffer, purpose as 'PRIVATE' | 'PUBLIC_LISTING');
  }
  @Get(':filename/access')
  @AdminPermissions('admin.support.read')
  access(@CurrentUser() user: AuthUser, @Param('filename') filename: string) { return this.uploads.access(user, filename); }
}
