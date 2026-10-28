import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayUnique, IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { SupportPageDto } from './support.dto';

export class SupportViewDto {
  @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @ValidateNested() @Type(() => SupportPageDto) filters!: SupportPageDto;
  @IsOptional() @IsInt() @Min(1) version?: number;
}

export class SupportSkillDto extends AdminReasonDto {
  @IsArray() @ArrayMaxSize(7) @ArrayUnique()
  @IsIn(['GENERAL', 'BILLING', 'LEASE', 'MAINTENANCE', 'ACCOUNT', 'SAFETY'], { each: true }) categories!: string[];
  @IsInt() @Min(1) @Max(100) maxOpen = 20;
}

export class SupportAutoAssignDto extends AdminReasonDto {
  @IsInt() @Min(1) version!: number;
  @IsOptional() @IsUUID() teamId?: string;
}

export class SupportAttachmentDto {
  @Type(() => Number) @IsInt() @Min(1) version!: number;
  @IsOptional() @IsIn(['true', 'false']) internal = 'false';
}

export class NotificationPreferencesDto {
  @IsBoolean() email!: boolean;
  @IsBoolean() push!: boolean;
}
