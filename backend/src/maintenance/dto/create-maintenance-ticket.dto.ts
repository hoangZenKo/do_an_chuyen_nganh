import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsArray,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { IsAttachmentUrl } from '../../common/attachment-url.validator';

export class CreateMaintenanceTicketDto {
  @IsUUID()
  propertyId!: string;

  @IsUUID()
  roomId!: string;

  @IsOptional()
  @IsIn(['low', 'medium', 'urgent', 'LOW', 'MEDIUM', 'URGENT'])
  priority?: string;

  @IsString()
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;

  @IsOptional()
  @IsDateString()
  reportedAt?: string;

  @IsOptional()
  @IsUUID()
  assigneeStaffProfileId?: string;

  @IsOptional()
  @IsDateString()
  dueAt?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  estimatedCost?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsArray()
  @IsAttachmentUrl({ each: true })
  @MaxLength(1000, { each: true })
  imageUrls?: string[];
}
