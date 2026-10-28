import { IsDateString, IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class RecordPaymentDto {
  @IsInt()
  @Min(1)
  amount!: number;

  @IsOptional()
  @IsIn(['cash', 'bank_transfer', 'other', 'CASH', 'BANK_TRANSFER', 'OTHER'])
  method?: string;

  /** ISO date string. Defaults to now. */
  @IsOptional()
  @IsDateString()
  paidAt?: string;

  @IsOptional()
  @IsString()
  note?: string;
}
