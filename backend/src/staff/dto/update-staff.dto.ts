import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

import { STAFF_PERMISSIONS, StaffPermission } from '../../common/permissions.constants';
import { STAFF_PRESETS, StaffPreset } from '../staff-presets';

export class UpdateStaffDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;

  @IsOptional()
  @IsIn(STAFF_PRESETS)
  preset?: StaffPreset;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsIn(STAFF_PERMISSIONS, { each: true })
  permissions?: StaffPermission[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  propertyIds?: string[];

}
