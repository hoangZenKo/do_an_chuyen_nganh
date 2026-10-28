import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsIn, IsInt, IsOptional, IsUUID, Min, ValidateNested } from 'class-validator';
import { AdminPageQuery, AdminReasonDto, AdminStatusDto } from '../admin/admin-console.dto';

export class AppealCreateDto extends AdminReasonDto { @IsUUID() decisionId!: string; }
export class AppealQueryDto extends AdminPageQuery {
  @IsOptional() @IsIn(['OPEN', 'UPHELD', 'REOPENED', 'SUPERSEDED']) appealStatus?: string;
  @IsOptional() @IsIn(['mine', 'unassigned', 'overdue', 'all']) assignment?: string;
}
export class AppealResolveDto extends AdminStatusDto {
  @IsIn(['UPHELD', 'REOPENED', 'SUPERSEDED']) outcome!: string;
}
export class AppealAssignDto extends AdminStatusDto { @IsOptional() @IsUUID() assigneeId?: string | null; }
export class ModerationBulkItemDto {
  @IsIn(['LISTING', 'REPORT', 'REVIEW', 'REPLY']) kind!: string;
  @IsUUID() id!: string;
  @IsInt() @Min(1) version!: number;
  @IsIn(['PUBLISH', 'REJECT', 'HIDE', 'APPROVED', 'REJECTED', 'HIDDEN', 'RESOLVED', 'DISMISSED']) decision!: string;
}
export class ModerationBulkDto extends AdminReasonDto {
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(25) @ValidateNested({ each: true }) @Type(() => ModerationBulkItemDto)
  items!: ModerationBulkItemDto[];
}
