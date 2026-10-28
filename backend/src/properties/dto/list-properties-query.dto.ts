import { IsIn, IsOptional } from 'class-validator';

export const PROPERTY_LIFECYCLE_FILTER = ['active', 'archived', 'all'] as const;
export type PropertyLifecycleFilter = (typeof PROPERTY_LIFECYCLE_FILTER)[number];

export class ListPropertiesQueryDto {
  @IsOptional()
  @IsIn(PROPERTY_LIFECYCLE_FILTER)
  lifecycle?: PropertyLifecycleFilter;
}
