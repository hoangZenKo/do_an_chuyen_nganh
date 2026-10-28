import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { AdminPageQuery } from '../admin-console.dto';
import { IsIn } from 'class-validator';

export class ListAdminPropertiesQueryDto extends AdminPageQuery {
  @IsOptional() @IsIn(['all', 'active', 'archived']) archived?: string;
  @IsOptional() @IsIn(['all', 'active', 'inactive']) ownerStatus?: string;
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsUUID()
  landlordId?: string;
}
