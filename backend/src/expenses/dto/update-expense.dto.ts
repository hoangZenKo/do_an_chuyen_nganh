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

export class UpdateExpenseDto {
  @IsOptional()
  @IsUUID()
  propertyId?: string;

  @IsOptional()
  @IsUUID()
  roomId?: string;

  @IsOptional()
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
  category?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  amount?: number;

  @IsOptional()
  @IsDateString()
  expenseDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  receiptUrl?: string;
}
