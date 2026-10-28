import { ArrayMaxSize, ArrayUnique, IsArray, IsBoolean, IsInt, IsOptional, IsString, IsUUID, Matches, Max, MaxLength, Min, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { AdminReasonDto } from '../admin/admin-console.dto';

export class SupportLabelsDto extends AdminReasonDto {
  @IsInt() @Min(1) version!: number;
  @IsArray() @ArrayMaxSize(10) @ArrayUnique() @IsString({ each: true })
  @Matches(/^[a-z0-9_-]{1,32}$/, { each: true }) labels!: string[];
}

export class SupportFeedbackDto {
  @IsInt() @Min(1) @Max(5) rating!: number;
  @IsOptional() @IsString() @MaxLength(2000) comment = '';
  @IsInt() @Min(1) version!: number;
}

export class SupportMergeDto extends AdminReasonDto {
  @IsUUID() targetId!: string;
  @IsInt() @Min(1) version!: number;
  @IsInt() @Min(1) targetVersion!: number;
}

export class SupportTemplateDto extends AdminReasonDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(2) @MaxLength(120) title!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(1) @MaxLength(5000) body!: string;
  @IsBoolean() isActive = true;
  @IsOptional() @IsInt() @Min(1) version?: number;
}
