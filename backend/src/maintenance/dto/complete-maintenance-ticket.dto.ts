import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';

export class CompleteMaintenanceTicketDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  actualCost?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsBoolean()
  createExpense?: boolean;

  @IsOptional()
  @IsDateString()
  completedAt?: string;
}
