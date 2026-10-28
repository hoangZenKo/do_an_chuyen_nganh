import { Body, Controller, Param, ParseUUIDPipe, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { SupportAttachmentDto } from './support-workflow.dto';
import { SupportAttachmentService } from './support-attachment.service';

@Controller('support/tickets')
@Roles(AuthRole.ADMIN, AuthRole.LANDLORD, AuthRole.STAFF, AuthRole.TENANT)
@AdminPermissions('admin.support.read', 'admin.support.manage')
export class SupportAttachmentController {
  constructor(private readonly attachments: SupportAttachmentService) {}
  @Post(':id/attachments')
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 8 * 1024 * 1024, files: 1, fields: 2 } }))
  upload(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: SupportAttachmentDto, @UploadedFile() file?: { buffer: Buffer; mimetype: string }) {
    return this.attachments.upload(actor, id, input, file);
  }
}
