import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { AdminReasonDto } from '../admin/admin-console.dto';

export class ModerationPolicyDto extends AdminReasonDto {
  @IsIn(['LISTING', 'REPORT', 'REVIEW', 'REPLY']) kind!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(3) @MaxLength(160) title!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value) @IsString() @MinLength(20) @MaxLength(20000) body!: string;
}
