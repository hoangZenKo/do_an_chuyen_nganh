import {
  IsArray,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { IsAttachmentUrl } from '../../common/attachment-url.validator';
import { Transform } from 'class-transformer';

export class CreateTenantMaintenanceDto {
  @IsString()
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @MinLength(1)
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsIn(['low', 'medium', 'urgent', 'LOW', 'MEDIUM', 'URGENT'])
  priority?: string;

  @IsOptional()
  @IsArray()
  @IsAttachmentUrl({ each: true })
  @MaxLength(1000, { each: true })
  imageUrls?: string[];
}
