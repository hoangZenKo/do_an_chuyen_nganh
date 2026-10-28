import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Roles } from '../common/roles.decorator';
import { AdminPermissions } from '../common/admin-permissions';
import { ModerateRoomReviewDto, ReviewContentDto, ReviewPageQuery, ReviewQueueQuery, ReviewReplyDto, ReviewVersionDto, UpdateRoomReviewDto } from './reviews.dto';
import { ReviewsService } from './reviews.service';

@Controller('public/listings')
export class PublicRoomReviewsController {
  constructor(private readonly reviews: ReviewsService) {}
  @Get(':id/reviews')
  list(@Param('id', ParseUUIDPipe) id: string, @Query() query: ReviewPageQuery) { return this.reviews.publicReviews(id, query); }
}

@Controller('reviews')
export class RoomReviewsController {
  constructor(private readonly reviews: ReviewsService) {}

  @Get('leases/:id') @Roles(AuthRole.TENANT)
  context(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) { return this.reviews.context(user, id); }

  @Post('leases/:id') @Roles(AuthRole.TENANT)
  create(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewContentDto) {
    return this.reviews.create(user, id, input);
  }

  @Patch(':id') @Roles(AuthRole.TENANT)
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: UpdateRoomReviewDto) {
    return this.reviews.update(user, id, input);
  }

  @Delete(':id') @Roles(AuthRole.TENANT)
  withdraw(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewVersionDto) {
    return this.reviews.withdraw(user, id, input.version);
  }

  @Get('landlord') @Roles(AuthRole.LANDLORD)
  landlord(@CurrentUser() user: AuthUser, @Query() query: ReviewPageQuery) { return this.reviews.landlord(user, query); }

  @Post(':id/reply') @Roles(AuthRole.LANDLORD)
  reply(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ReviewReplyDto) {
    return this.reviews.reply(user, id, input);
  }
}

@Controller('admin/room-reviews')
@Roles(AuthRole.ADMIN)
@AdminPermissions('admin.reviews.moderate')
export class AdminRoomReviewsController {
  constructor(private readonly reviews: ReviewsService) {}
  @Get()
  queue(@Query() query: ReviewQueueQuery) { return this.reviews.queue(query); }

  @Post(':id/moderate')
  moderate(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ModerateRoomReviewDto) {
    return this.reviews.moderate(user, id, input, false);
  }

  @Post(':id/reply/moderate')
  reply(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() input: ModerateRoomReviewDto) {
    return this.reviews.moderate(user, id, input, true);
  }
}
