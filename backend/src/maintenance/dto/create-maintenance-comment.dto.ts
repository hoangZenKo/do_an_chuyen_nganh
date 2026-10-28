import {
  IsArray,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { IsAttachmentUrl } from '../../common/attachment-url.validator';

export class CreateMaintenanceCommentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  body!: string;

  @IsOptional()
  @IsArray()
  @IsAttachmentUrl({ each: true })
  @MaxLength(1000, { each: true })
  imageUrls?: string[];
}
