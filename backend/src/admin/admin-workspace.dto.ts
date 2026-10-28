import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

const groups = ['incidents', 'support_overdue', 'support_due_soon', 'moderation', 'notification_delivery', 'reports', 'finance'];

export class AdminWorkspaceQuery {
  @IsIn(['all', 'attention']) view = 'attention';
  @IsIn(['priority', 'count']) sort = 'priority';
  @IsOptional() @IsIn(groups) group?: string;
  @IsOptional() @IsIn(groups) cursor?: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(20) limit = 10;
}
