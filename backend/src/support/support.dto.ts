import { Type, Transform } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import type { SupportSlaFilter } from './support-inbox';

export class CreateSupportTicketDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(3) @MaxLength(160) subject!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(10) @MaxLength(10000) body!: string;
  @IsOptional() @IsIn(['GENERAL', 'BILLING', 'LEASE', 'MAINTENANCE', 'ACCOUNT', 'SAFETY']) category = 'GENERAL';
  @IsOptional() @IsIn(['LOW', 'NORMAL', 'HIGH', 'URGENT']) priority = 'NORMAL';
}

export class SupportPageDto {
  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 20;
  @IsOptional() @IsIn(['OPEN', 'IN_PROGRESS', 'WAITING_FOR_USER', 'RESOLVED', 'CLOSED']) status?: string;
  @IsOptional() @IsIn(['mine', 'unassigned', 'overdue', 'all']) assignment = 'all';
  @IsOptional() @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MaxLength(100) search?: string;
  @IsOptional() @IsString() @MaxLength(32) label?: string;
  @IsOptional() @IsIn(['LOW', 'NORMAL', 'HIGH', 'URGENT']) priority?: string;
  @IsOptional() @IsUUID() teamId?: string;
  @IsOptional() @IsUUID() assigneeId?: string;
  @IsOptional() @IsIn(['all', 'overdue', 'due_soon', 'paused']) sla: SupportSlaFilter = 'all';
  @IsOptional() @IsIn(['GENERAL', 'BILLING', 'LEASE', 'MAINTENANCE', 'ACCOUNT', 'SAFETY']) category?: string;
  @IsOptional() @IsIn(['recent', 'oldest', 'resolution_due']) sort = 'recent';
}

export class SupportReplyDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(1) @MaxLength(10000) body!: string;
  @IsInt() @Min(1) version!: number;
}

export class SupportNoteDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(1) @MaxLength(5000) body!: string;
  @IsInt() @Min(1) version!: number;
}

export class SupportAssignmentDto {
  @IsOptional() @IsUUID() assigneeId?: string | null;
  @IsOptional() @IsUUID() teamId?: string | null;
  @IsIn(['LOW', 'NORMAL', 'HIGH', 'URGENT']) priority!: string;
  @IsString() @MinLength(10) @MaxLength(1000) reason!: string;
  @IsInt() @Min(1) version!: number;
}

export class SupportStatusDto {
  @IsIn(['OPEN', 'IN_PROGRESS', 'WAITING_FOR_USER', 'RESOLVED', 'CLOSED']) status!: string;
  @IsString() @MinLength(10) @MaxLength(1000) reason!: string;
  @IsInt() @Min(0) version!: number;
}
