import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsInt, IsObject, IsString, Matches, Max, MaxLength, Min, ValidateNested } from 'class-validator';
import { AdminStatusDto } from '../admin/admin-console.dto';

class SlaTargetsDto {
  @IsInt() @Min(1) @Max(7200) LOW!: number;
  @IsInt() @Min(1) @Max(7200) NORMAL!: number;
  @IsInt() @Min(1) @Max(7200) HIGH!: number;
  @IsInt() @Min(1) @Max(7200) URGENT!: number;
}
export class SupportSlaPolicyDto extends AdminStatusDto {
  @IsBoolean() enabled!: boolean;
  @IsString() @MaxLength(80) timezone!: string;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(7) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true }) @Max(7, { each: true }) weekdays!: number[];
  @IsInt() @Min(0) @Max(1379) startMinute!: number;
  @IsInt() @Min(60) @Max(1440) endMinute!: number;
  @IsArray() @ArrayMaxSize(366) @ArrayUnique() @Matches(/^\d{4}-\d{2}-\d{2}$/, { each: true }) holidays!: string[];
  @IsBoolean() pauseWaiting!: boolean;
  @IsObject() @ValidateNested() @Type(() => SlaTargetsDto) responseMinutes!: SlaTargetsDto;
  @IsObject() @ValidateNested() @Type(() => SlaTargetsDto) resolutionMinutes!: SlaTargetsDto;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(3) @ArrayUnique() @IsInt({ each: true }) @Min(0, { each: true }) @Max(7200, { each: true }) escalationMinutes!: number[];
}
