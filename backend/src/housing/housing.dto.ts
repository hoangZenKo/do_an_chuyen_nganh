import { Transform, Type } from 'class-transformer';
import { ArrayMaxSize, ArrayUnique, IsArray, IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';

const trim = ({ value }: { value: unknown }) => typeof value === 'string' ? value.trim() : value;

export class HousingPageQuery {
  @Type(() => Number) @IsInt() @Min(1) @Max(100000)
  page = 1;
}

export class CreateViewingDto {
  @IsOptional() @IsUUID()
  slotId?: string;
  @IsUUID()
  listingId!: string;

  @IsDateString({ strict: true })
  @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/)
  scheduledAt!: string;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(1000)
  note?: string;
}

export class ViewingSlotDto {
  @IsDateString({ strict: true }) @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/)
  startsAt!: string;

  @IsDateString({ strict: true }) @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/)
  endsAt!: string;
}

export class RescheduleViewingDto extends CreateViewingDto {
  @IsInt() @Min(1)
  version!: number;
}

export class HandoverDto {
  @IsInt() @Min(0)
  version!: number;

  @IsInt() @Min(0) @Max(2147483647)
  electricity!: number;

  @IsInt() @Min(0) @Max(2147483647)
  water!: number;

  @Transform(trim) @IsString() @MinLength(10) @MaxLength(5000)
  condition!: string;

  @IsArray() @ArrayMaxSize(12) @ArrayUnique() @IsString({ each: true })
  @MaxLength(500, { each: true }) @Matches(/^\/uploads\/[a-zA-Z0-9_.-]+$/, { each: true })
  imageUrls!: string[];
}

export class AcceptHandoverDto {
  @IsInt() @Min(1)
  version!: number;
}

export class UpdateViewingDto {
  @IsInt() @Min(1)
  version!: number;

  @IsIn(['CONFIRMED', 'CANCELLED', 'COMPLETED'])
  status!: 'CONFIRMED' | 'CANCELLED' | 'COMPLETED';

  @IsOptional() @Transform(trim) @IsString() @MaxLength(1000)
  note?: string;
}

export class PilotFeedbackDto {
  @IsIn(['discovery', 'viewing', 'rental'])
  stage!: string;

  @Transform(trim) @IsString() @MinLength(2) @MaxLength(160)
  area!: string;

  @IsInt() @Min(1) @Max(5)
  rating!: number;

  @Transform(trim) @IsString() @MinLength(10) @MaxLength(2000)
  detail!: string;
}

export class ViewingLeaseDto {
  @IsInt() @Min(1)
  version!: number;

  @IsDateString({ strict: true })
  startDate!: string;

  @IsInt() @Min(1) @Max(2147483647)
  monthlyRent!: number;

  @IsInt() @Min(0) @Max(2147483647)
  deposit!: number;
}
