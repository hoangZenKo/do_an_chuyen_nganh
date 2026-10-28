import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsDateString, IsEnum, IsIn, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';
import { AnnouncementAudience, OperationFrequency, OperationTaskStatus, TurnoverStage } from '@prisma/client';

export class OperationsQuery {
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @IsUUID() roomId?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 30;
}

export class TaskQuery extends OperationsQuery {
  @IsOptional() @IsEnum(OperationTaskStatus) status?: OperationTaskStatus;
}

export class CreateTurnoverDto {
  @IsUUID() roomId!: string;
  @IsOptional() @IsString() @MaxLength(1000) note?: string;
}

export class AdvanceTurnoverDto {
  @IsInt() @Min(1) version!: number;
  @IsEnum(TurnoverStage) stage!: TurnoverStage;
  @IsString() @Matches(/\S/) @MaxLength(1000) note!: string;
}

export class CreateRecurringDto {
  @IsUUID() propertyId!: string;
  @IsOptional() @IsUUID() roomId?: string;
  @IsString() @Matches(/\S/) @MaxLength(160) title!: string;
  @IsIn(['meter_reading', 'inspection', 'collection', 'cleaning', 'renewal']) kind!: string;
  @IsEnum(OperationFrequency) frequency!: OperationFrequency;
  @IsOptional() @IsInt() @Min(1) @Max(12) interval = 1;
  @IsDateString() nextRunAt!: string;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(20) @IsString({ each: true }) @Matches(/\S/, { each: true }) @MaxLength(200, { each: true }) checklist!: string[];
}

export class ToggleRecurringDto {
  @IsBoolean() isEnabled!: boolean;
}

export class CheckTaskDto {
  @IsInt() @Min(1) version!: number;
  @IsInt() @Min(0) @Max(19) index!: number;
  @IsBoolean() done!: boolean;
}

export class CreateTenantGroupDto {
  @IsString() @Matches(/\S/) @MaxLength(120) name!: string;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(500) @ArrayUnique() @IsUUID('all', { each: true }) tenantIds!: string[];
}

export class CreateAnnouncementTemplateDto {
  @IsString() @Matches(/\S/) @MaxLength(120) name!: string;
  @IsString() @Matches(/\S/) @MaxLength(160) title!: string;
  @IsString() @Matches(/\S/) @MaxLength(5000) body!: string;
}

export class CreateAnnouncementDto {
  @IsEnum(AnnouncementAudience) audience!: AnnouncementAudience;
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @IsUUID() roomId?: string;
  @IsOptional() @IsUUID() groupId?: string;
  @IsOptional() @IsArray() @ArrayMinSize(1) @ArrayMaxSize(500) @ArrayUnique() @IsUUID('all', { each: true }) tenantIds?: string[];
  @IsString() @Matches(/\S/) @MinLength(1) @MaxLength(160) title!: string;
  @IsString() @Matches(/\S/) @MinLength(1) @MaxLength(5000) body!: string;
  @IsOptional() @IsDateString() sendAt?: string;
}
