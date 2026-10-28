import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { AdminPageQuery } from '../admin-console.dto';

export type LandlordStatusFilter = 'all' | 'active' | 'inactive';

export class ListLandlordsQueryDto extends AdminPageQuery {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsIn(['all', 'active', 'inactive'])
  status?: LandlordStatusFilter;
}
