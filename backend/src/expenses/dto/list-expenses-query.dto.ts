import { IsDateString, IsIn, IsOptional, IsUUID } from 'class-validator';

export class ListExpensesQueryDto {
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
  @IsDateString()
  month?: string;
}
