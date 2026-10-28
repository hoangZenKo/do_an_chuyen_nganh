import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';

export class CreateDepositTransactionDto {
  @IsIn([
    'collected',
    'refunded',
    'deducted',
    'adjustment',
    'COLLECTED',
    'REFUNDED',
    'DEDUCTED',
    'ADJUSTMENT',
  ])
  type!: string;

  @IsInt()
  @Min(1)
  @Max(2147483647)
  amount!: number;

  @IsOptional()
  @IsDateString()
  occurredAt?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
