import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateExpenseDto {
  @IsUUID()
  propertyId!: string;

  @IsOptional()
  @IsUUID()
  roomId?: string;

  @IsIn([
    'repair',
    'utilities',
    'internet',
    'cleaning',
    'furniture',
    'salary',
    'tax',
    'other',
    'REPAIR',
    'UTILITIES',
    'INTERNET',
    'CLEANING',
    'FURNITURE',
    'SALARY',
    'TAX',
    'OTHER',
  ])
  category!: string;

  @IsInt()
  @Min(1)
  amount!: number;

  @IsDateString()
  expenseDate!: string;

  @IsString()
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  receiptUrl?: string;
}
