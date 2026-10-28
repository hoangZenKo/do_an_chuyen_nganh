import { IsIn, IsOptional, IsUUID } from 'class-validator';

export class ListMaintenanceQueryDto {
  @IsOptional()
  @IsUUID()
  propertyId?: string;

  @IsOptional()
  @IsUUID()
  roomId?: string;

  @IsOptional()
  @IsIn([
    'open',
    'in_progress',
    'done',
    'cancelled',
    'OPEN',
    'IN_PROGRESS',
    'DONE',
    'CANCELLED',
  ])
  status?: string;

  @IsOptional()
  @IsIn(['low', 'medium', 'urgent', 'LOW', 'MEDIUM', 'URGENT'])
  priority?: string;
}
