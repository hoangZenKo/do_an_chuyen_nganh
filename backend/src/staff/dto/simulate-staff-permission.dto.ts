import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { STAFF_PERMISSIONS, StaffPermission } from '../../common/permissions.constants';

export class SimulateStaffPermissionDto {
  @IsString() @MinLength(1) @MaxLength(100)
  propertyId!: string;

  @IsIn(STAFF_PERMISSIONS)
  permission!: StaffPermission;
}
