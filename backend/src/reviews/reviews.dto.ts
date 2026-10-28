import { Transform, Type } from 'class-transformer';
import { RoomReviewStatus } from '@prisma/client';
import { IsEnum, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

const trim = ({ value }: { value: unknown }) => typeof value === 'string' ? value.trim() : value;

export class ReviewPageQuery {
  @Type(() => Number) @IsInt() @Min(1) @Max(10000)
  page = 1;

  @Type(() => Number) @IsInt() @Min(1) @Max(30)
  limit = 10;
}

export class ReviewQueueQuery extends ReviewPageQuery {
  @IsEnum(RoomReviewStatus)
  status: RoomReviewStatus = 'PENDING';

  @IsIn(['review', 'reply'])
  target: 'review' | 'reply' = 'review';
}

export class ReviewContentDto {
  @IsInt() @Min(1) @Max(5)
  roomRating!: number;

  @IsInt() @Min(1) @Max(5)
  costRating!: number;

  @IsInt() @Min(1) @Max(5)
  landlordRating!: number;

  @IsInt() @Min(1) @Max(5)
  areaRating!: number;

  @Transform(trim) @IsString() @MinLength(20) @MaxLength(3000)
  body!: string;
}

export class ReviewVersionDto {
  @IsInt() @Min(1)
  version!: number;
}

export class UpdateRoomReviewDto extends ReviewContentDto {
  @IsInt() @Min(1)
  version!: number;
}

export class ReviewReplyDto extends ReviewVersionDto {
  @Transform(trim) @IsString() @MinLength(5) @MaxLength(2000)
  body!: string;
}

export class ModerateRoomReviewDto extends ReviewVersionDto {
  @IsIn(['APPROVED', 'REJECTED', 'HIDDEN'])
  status!: 'APPROVED' | 'REJECTED' | 'HIDDEN';

  @Transform(trim) @IsString() @MinLength(5) @MaxLength(1000)
  note!: string;
}
