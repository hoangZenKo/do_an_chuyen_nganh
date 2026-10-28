import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize, ArrayMinSize, ArrayUnique, IsArray, IsEnum, IsIn, IsInt,
  IsNumber, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min,
  MinLength, IsBoolean, IsLatitude, IsLongitude, ValidateIf, IsUrl, ValidateNested, IsDefined, IsObject,
} from 'class-validator';
import { ListingStatus } from '@prisma/client';

const trim = ({ value }: { value: unknown }) => typeof value === 'string' ? value.trim() : value;

export class PublicListingsQuery {
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(2147483647)
  maxBudget?: number;

  @Type(() => Number) @IsInt() @Min(0) @Max(10000)
  electricityKwh = 50;

  @Type(() => Number) @IsInt() @Min(0) @Max(10000)
  waterM3 = 3;

  @IsOptional() @Transform(({ value }) => value === 'true' ? true : value === 'false' ? false : value) @IsBoolean()
  freshOnly?: boolean;
  @IsOptional() @IsUUID()
  campusId?: string;

  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.1) @Max(50)
  radiusKm?: number;
  @IsOptional() @Transform(trim) @IsString() @MaxLength(120)
  search?: string;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(100)
  city?: string;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(100)
  district?: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(2147483647)
  minPrice?: number;

  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(2147483647)
  maxPrice?: number;

  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) @Max(100000)
  minArea?: number;

  @IsOptional() @Transform(trim) @IsString() @MaxLength(80)
  amenity?: string;

  @IsOptional() @IsIn(['newest', 'price_asc', 'price_desc'])
  sort: string = 'newest';

  @Type(() => Number) @IsInt() @Min(1) @Max(10000)
  page: number = 1;

  @Type(() => Number) @IsInt() @Min(1) @Max(50)
  limit: number = 12;
}

export class ManageListingsQuery extends PublicListingsQuery {
  @IsOptional() @IsEnum(ListingStatus)
  status?: ListingStatus;
}

export class ListingContentDto {
  @IsOptional() @IsNumber() @IsLatitude()
  latitude?: number;

  @IsOptional() @IsNumber() @IsLongitude()
  longitude?: number;

  @ValidateIf((_object, value) => value !== undefined) @IsInt() @Min(0) @Max(2147483647)
  parkingFee?: number;
  @Transform(trim) @IsString() @MinLength(5) @MaxLength(160)
  title!: string;

  @Transform(trim) @IsString() @MinLength(20) @MaxLength(10000)
  description!: string;

  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(12) @ArrayUnique()
  @IsString({ each: true }) @MaxLength(2048, { each: true })
  @Matches(/^(https?:\/\/[^\s]+|\/uploads\/[a-zA-Z0-9_-]+\.(?:jpe?g|png|webp|heic|heif))$/i, { each: true })
  imageUrls!: string[];

  @Transform(trim) @IsString() @MinLength(1) @MaxLength(100)
  city!: string;

  @Transform(trim) @IsString() @MinLength(1) @MaxLength(100)
  district!: string;

  @Transform(trim) @IsString() @MinLength(1) @MaxLength(250)
  publicAddress!: string;

  @IsInt() @Min(1) @Max(2147483647)
  monthlyRent!: number;

  @IsInt() @Min(0) @Max(2147483647)
  deposit!: number;

  @IsInt() @Min(0) @Max(2147483647)
  electricityPrice!: number;

  @IsInt() @Min(0) @Max(2147483647)
  waterPrice!: number;

  @IsInt() @Min(0) @Max(2147483647)
  serviceFee!: number;

  @IsNumber() @Min(1) @Max(100000)
  areaSqm!: number;

  @IsArray() @ArrayMaxSize(30) @ArrayUnique()
  @IsString({ each: true }) @MinLength(1, { each: true }) @MaxLength(80, { each: true })
  amenities!: string[];
}

export class CreateListingDto extends ListingContentDto {
  @IsUUID()
  roomId!: string;
}

export class ListingVersionDto {
  @IsInt() @Min(1)
  version!: number;
}

export class UpdateListingDto extends ListingContentDto {
  @IsInt() @Min(1)
  version!: number;
}

export class ReviewListingDto extends ListingVersionDto {
  @IsOptional() @IsBoolean()
  landlordVerified?: boolean;

  @IsOptional() @IsBoolean()
  roomInspected?: boolean;
  @IsIn(['PUBLISH', 'REJECT', 'HIDE'])
  decision!: 'PUBLISH' | 'REJECT' | 'HIDE';

  @IsOptional() @Transform(trim) @IsString() @MaxLength(1000)
  note?: string;
}

export class SchoolCampusDto {
  @IsOptional() @IsUrl({ protocols: ['https'], require_protocol: true }) @MaxLength(1000)
  sourceUrl?: string;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(160)
  name!: string;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(160)
  campus!: string;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(100)
  city!: string;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(250)
  address!: string;
  @IsNumber() @IsLatitude()
  latitude!: number;
  @IsNumber() @IsLongitude()
  longitude!: number;
}

export class UpdateSchoolCampusDto extends SchoolCampusDto {
  @IsBoolean()
  isActive!: boolean;
}

export class SavedSearchDto {
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(100)
  name!: string;
  @IsDefined() @IsObject() @ValidateNested() @Type(() => PublicListingsQuery)
  filters!: PublicListingsQuery;
}

export class SavedSearchStatusDto {
  @IsBoolean()
  enabled!: boolean;
}

export class CreateListingReportDto {
  @IsIn(['wrong_price', 'wrong_photos', 'unavailable', 'suspected_scam', 'other'])
  reason!: string;
  @Transform(trim) @IsString() @MinLength(10) @MaxLength(2000)
  detail!: string;
}

export class ReviewListingReportDto {
  @IsOptional() @IsInt() @Min(1) version?: number;
  @IsIn(['RESOLVED', 'DISMISSED'])
  status!: string;
  @Transform(trim) @IsString() @MinLength(5) @MaxLength(1000)
  note!: string;
}

export class ListingVerificationDto extends ListingVersionDto {
  @IsBoolean()
  landlordVerified!: boolean;
  @IsBoolean()
  roomInspected!: boolean;
  @Transform(trim) @IsString() @MinLength(10) @MaxLength(1000)
  note!: string;
}
