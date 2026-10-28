import { Transform, Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsEmail, IsIn, IsInt, IsISO8601, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';
import { ADMIN_PERMISSIONS, AdminPermission } from '../common/admin-permissions';

export class AdminPageQuery {
  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
  @IsOptional() @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MaxLength(120) search?: string;
  @IsOptional() @IsIn(['LANDLORD', 'TENANT', 'STAFF', 'ADMIN']) role?: 'LANDLORD' | 'TENANT' | 'STAFF' | 'ADMIN';
  @IsOptional() @IsIn(['all', 'active', 'inactive']) status?: string;
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
}
export class AdminReasonDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(10) @MaxLength(1000) reason!: string;
}
export class AdminStatusDto extends AdminReasonDto {
  @IsInt() @Min(0) version!: number;
}
export class AdminProfileDto extends AdminReasonDto {
  @IsIn(['super_admin', 'support', 'moderator', 'analyst']) preset!: string;
  @ValidateIf((_object, value) => value !== undefined)
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(ADMIN_PERMISSIONS.length) @ArrayUnique()
  @IsIn(ADMIN_PERMISSIONS, { each: true }) permissions?: AdminPermission[];
  @IsBoolean() isActive!: boolean;
  @IsInt() @Min(0) version!: number;
  @IsString() @MinLength(6) @MaxLength(64) mfaCode!: string;
}
export class AdminInviteDto extends AdminReasonDto {
  @IsEmail() @MaxLength(254) email!: string;
  @IsString() @MinLength(2) @MaxLength(120) fullName!: string;
  @IsIn(['LANDLORD', 'ADMIN']) role!: 'LANDLORD' | 'ADMIN';
  @IsOptional() @IsIn(['support', 'moderator', 'analyst']) preset?: string;
  @IsOptional() @IsString() @MinLength(6) @MaxLength(64) mfaCode?: string;
}

export class AdminAuditQuery extends AdminPageQuery {
  @IsOptional() @IsUUID() actorId?: string;
  @IsOptional() @IsUUID() resourceId?: string;
  @IsOptional() @IsUUID() landlordId?: string;
  @IsOptional() @IsString() @MaxLength(100) action?: string;
  @IsOptional() @IsString() @MaxLength(100) resourceType?: string;
  @IsOptional() @IsString() @MinLength(8) @MaxLength(128) requestId?: string;
}
export class AdminAuditExportDto extends AdminAuditQuery {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(10) @MaxLength(1000) reason!: string;
}
export class AdminContextQuery extends AdminReasonDto {
  @IsIn(['account', 'property', 'room', 'tenant', 'lease', 'invoice']) kind!: string;
  @IsUUID() id!: string;
}
export class AdminQueueQuery extends AdminPageQuery {
  @IsIn(['LISTING', 'REPORT', 'REVIEW', 'REPLY']) kind = 'LISTING';
  @IsOptional() @IsIn(['mine', 'unassigned', 'all']) assignment?: string;
  @IsOptional() @IsIn(['NORMAL', 'HIGH', 'URGENT']) priority?: string;
  @IsOptional() @IsIn(['true', 'false']) overdue?: string;
}
export class AdminWorkDto extends AdminReasonDto {
  @IsIn(['LISTING', 'REPORT', 'REVIEW', 'REPLY']) kind!: string;
  @IsUUID() targetId!: string;
  @IsInt() @Min(0) version!: number;
  @IsOptional() @IsUUID() assigneeId?: string | null;
  @IsIn(['NORMAL', 'HIGH', 'URGENT']) priority!: string;
  @IsISO8601() dueAt!: string;
  @IsString() @MaxLength(2000) note!: string;
}
export class AdminAnalyticsQuery {
  @Type(() => Number) @IsIn([7, 30, 90]) days = 30;
}
