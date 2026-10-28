import { IsIn } from 'class-validator';

export class UpdateMaintenanceStatusDto {
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
  status!: string;
}
