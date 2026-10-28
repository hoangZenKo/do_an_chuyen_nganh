import { Transform, Type } from 'class-transformer';
import { IsEnum, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';
import { RoomStatus } from '@prisma/client';

export class ListAdminRoomsQueryDto {
  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
  @IsOptional() @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MaxLength(120) search?: string;
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @IsUUID() landlordId?: string;
  @IsOptional() @IsEnum(RoomStatus) status?: RoomStatus;
  @IsOptional() @IsIn(['all', 'active', 'inactive']) activity?: string;
  @IsOptional() @IsIn(['NONE', 'DRAFT', 'PENDING', 'PUBLISHED', 'REJECTED', 'HIDDEN']) listingStatus?: 'NONE' | 'DRAFT' | 'PENDING' | 'PUBLISHED' | 'REJECTED' | 'HIDDEN';
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(2147483647) minPrice?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(2147483647) maxPrice?: number;
}
