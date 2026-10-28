import { IsIn, IsOptional } from 'class-validator';

export const TENANT_LIFECYCLE_FILTER = ['active', 'inactive', 'all'] as const;
export type TenantLifecycleFilter = (typeof TENANT_LIFECYCLE_FILTER)[number];

export class ListTenantsQueryDto {
  @IsOptional()
  @IsIn(TENANT_LIFECYCLE_FILTER)
  lifecycle?: TenantLifecycleFilter;
}
