import { Type, Transform } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsISO8601, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { AdminReasonDto } from '../admin/admin-console.dto';

export class TeamCreateDto extends AdminReasonDto { @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(2) @MaxLength(100) name!: string; @IsOptional() @IsString() @MaxLength(1000) description = ''; }
export class TeamMemberDto extends AdminReasonDto { @IsUUID() userId!: string; @IsIn(['LEAD', 'MEMBER']) role!: string; }
export class TeamUpdateDto extends TeamCreateDto { @IsBoolean() isActive!: boolean; @IsInt() @Min(1) version!: number; }
export class PermissionSimulationDto { @IsIn(['super_admin', 'support', 'moderator', 'analyst']) preset!: string; @IsOptional() @IsString() action?: string; @IsOptional() @IsString() route?: string; }
export class FinanceQueryDto {
  @IsISO8601() from!: string;
  @IsISO8601() to!: string;
  @IsOptional() @IsUUID() propertyId?: string;
}
export class ReportScheduleCreateDto extends AdminReasonDto {
  @IsOptional() @IsString() @MaxLength(80) timezone = 'UTC';
  @IsString() @MinLength(2) @MaxLength(100) name!: string;
  @IsIn(['MONTHLY_FINANCE', 'MODERATION', 'SUPPORT_SLA']) kind!: string;
  @IsIn(['DAILY', 'WEEKLY', 'MONTHLY']) cadence!: string;
  @Type(() => Number) @IsInt() @Min(0) @Max(23) hourUtc!: number;
}
export class ReportScheduleUpdateDto extends ReportScheduleCreateDto { @IsInt() @Min(1) version!: number; @IsOptional() @IsBoolean() enabled?: boolean; }
