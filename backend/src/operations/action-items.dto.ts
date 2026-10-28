import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsUUID, Max, Min } from 'class-validator';

export const actionCategories = ['viewing', 'payment', 'invoice', 'maintenance', 'lease', 'inspection'] as const;
export type ActionCategory = typeof actionCategories[number];

export class ActionItemsQuery {
  @Type(() => Number) @IsInt() @Min(1) @Max(10000)
  page = 1;

  @Type(() => Number) @IsInt() @Min(1) @Max(50)
  limit = 20;

  @IsIn(['all', ...actionCategories])
  category: 'all' | ActionCategory = 'all';

  @IsOptional() @IsUUID()
  propertyId?: string;
}
