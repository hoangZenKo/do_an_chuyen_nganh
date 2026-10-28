import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { IsISO8601 } from 'class-validator';
import { AdminPageQuery, AdminStatusDto } from './admin-console.dto';
import { AdminPermissions } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminAccessReviewService } from './admin-access-review.service';

class AccessReviewDto extends AdminStatusDto { @IsISO8601() nextReviewAt!: string; }

@Controller('admin')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.admins.manage')
export class AdminAccessReviewController {
  constructor(private readonly reviews: AdminAccessReviewService) {}
  @Get('permission-catalog') catalog() { return this.reviews.catalog(); }
  @Get('access-reviews') @Header('Cache-Control', 'private, no-store')
  list(@Query() query: AdminPageQuery) { return this.reviews.list(query.page, query.limit); }
  @Post('access-reviews/:id') review(@CurrentUser() actor: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: AccessReviewDto) { return this.reviews.review(actor, id, input); }
}
