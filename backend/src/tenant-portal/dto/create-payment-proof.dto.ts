import {
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
  ArrayMaxSize,
  IsUUID,
} from 'class-validator';
import { IsAttachmentUrl } from '../../common/attachment-url.validator';

export class CreatePaymentProofDto {
  @IsOptional()
  @IsUUID()
  requestKey?: string;

  @IsInt()
  @Min(1)
  @Max(2147483647)
  amount!: number;

  @IsOptional()
  @IsIn(['cash', 'bank_transfer', 'other', 'CASH', 'BANK_TRANSFER', 'OTHER'])
  method?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(12)
  @IsAttachmentUrl({ each: true })
  @MaxLength(1000, { each: true })
  proofImageUrls?: string[];
}
