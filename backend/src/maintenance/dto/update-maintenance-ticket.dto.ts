import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsArray,
  IsString,
  IsNotEmpty,
  ValidateIf,
  IsUUID,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { IsAttachmentUrl } from '../../common/attachment-url.validator';
import { Transform } from 'class-transformer';

export class UpdateMaintenanceTicketDto {
  @ValidateIf((_, value) => value !== undefined)
  @IsUUID()
  propertyId?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsUUID()
  roomId?: string;

  @ValidateIf((_, value) => value !== undefined)
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

  @ValidateIf((_, value) => value !== undefined)
  @IsIn(['low', 'medium', 'urgent', 'LOW', 'MEDIUM', 'URGENT'])
  priority?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsNotEmpty()
  @MaxLength(120)
  title?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(1000)
  description?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsDateString()
  reportedAt?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsDateString()
  startedAt?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsDateString()
  completedAt?: string;

  @IsOptional()
  @IsUUID()
  assigneeStaffProfileId?: string;

  @IsOptional()
  @IsDateString()
  dueAt?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsInt()
  @Min(0)
  @Max(2147483647)
  estimatedCost?: number;

  @ValidateIf((_, value) => value !== undefined)
  @IsInt()
  @Min(0)
  @Max(2147483647)
  actualCost?: number;

  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @MaxLength(500)
  note?: string;

  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @IsAttachmentUrl({ each: true })
  @MaxLength(1000, { each: true })
  imageUrls?: string[];
}
