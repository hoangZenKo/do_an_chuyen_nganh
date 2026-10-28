import { Module } from '@nestjs/common';
import { AdminRoomReviewsController, PublicRoomReviewsController, RoomReviewsController } from './reviews.controller';
import { ReviewsService } from './reviews.service';

@Module({ controllers: [PublicRoomReviewsController, RoomReviewsController, AdminRoomReviewsController], providers: [ReviewsService], exports: [ReviewsService] })
export class ReviewsModule {}
