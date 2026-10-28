import { Type } from 'class-transformer';
import {
  ArrayMaxSize, ArrayUnique, IsArray, IsBoolean, IsDateString, IsEnum,
  IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { TenantLifecycleRequestStatus, TenantLifecycleRequestType } from '@prisma/client';

export class CreateLifecycleRequestDto {
  @IsEnum(TenantLifecycleRequestType)
  type!: TenantLifecycleRequestType;

  @IsString() @MinLength(1) @MaxLength(100)
  leaseId!: string;

  @IsOptional() @IsString() @MinLength(1) @MaxLength(100)
  requestedRoomId?: string;

  @IsOptional() @IsDateString()
  requestedStart?: string;

  @IsOptional() @IsDateString()
  requestedEnd?: string;

  @IsString() @MinLength(1) @MaxLength(1000)
  note!: string;
}

export class LifecycleVersionDto {
  @IsOptional() @IsDateString()
  expectedUpdatedAt?: string;

  @IsOptional() @IsDateString()
  expectedLeaseUpdatedAt?: string;
}

export class LifecycleDecisionDto extends LifecycleVersionDto {
  @IsIn(['APPROVED', 'REJECTED'])
  status!: 'APPROVED' | 'REJECTED';

  @IsString() @MinLength(1) @MaxLength(1000)
  reason!: string;
}

export class ExecuteLifecycleDto extends LifecycleVersionDto {
  @IsUUID()
  requestKey!: string;

  @IsOptional() @IsInt() @Min(0) @Max(2147483647)
  monthlyRent?: number;
}

export class LifecycleListQueryDto {
  @IsOptional() @IsString() @MaxLength(100)
  leaseId?: string;

  @IsOptional() @IsString() @MaxLength(100)
  tenantId?: string;

  @IsOptional() @IsString() @MaxLength(100)
  propertyId?: string;

  @IsOptional() @IsEnum(TenantLifecycleRequestStatus)
  status?: TenantLifecycleRequestStatus;

  @IsOptional() @IsString() @MaxLength(100)
  cursor?: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit: number = 50;
}

export class TransferRoomsQueryDto {
  @IsString() @MinLength(1) @MaxLength(100)
  leaseId!: string;

  @IsOptional() @IsString() @MaxLength(100)
  search?: string;

  @IsOptional() @IsString() @MaxLength(100)
  cursor?: string;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  limit: number = 25;
}

export class TenantOccupantDto {
  @IsString() @MinLength(1) @MaxLength(120)
  fullName!: string;

  @IsOptional() @IsString() @MaxLength(30)
  phone?: string;

  @IsOptional() @IsString() @MaxLength(50)
  idNumber?: string;

  @IsOptional() @IsString() @MaxLength(100)
  relationship?: string;
}

export class TenantNotificationPreferenceDto {
  @IsBoolean()
  enabled!: boolean;

  @IsArray() @ArrayMaxSize(3) @ArrayUnique() @IsIn(['APP', 'EMAIL', 'ZALO'], { each: true })
  channels!: string[];
}
