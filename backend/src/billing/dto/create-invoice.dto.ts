import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';

export class InvoiceMeterReadingDto {
  @IsIn(['electricity', 'water', 'ELECTRICITY', 'WATER'])
  utilityType!: string;

  @IsInt()
  @Min(0)
  previousReading!: number;

  @IsInt()
  @Min(0)
  currentReading!: number;

  @IsInt()
  @Min(1)
  unitPrice!: number;
}

export class CreateInvoiceDto {
  @IsUUID()
  leaseId!: string;

  /** ISO date string. Defaults to current month. */
  @IsOptional()
  @IsDateString()
  billingMonth?: string;

  /** ISO date string. */
  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  otherAmount?: number;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(2)
  @ValidateNested({ each: true })
  @Type(() => InvoiceMeterReadingDto)
  meterReadings?: InvoiceMeterReadingDto[];
}
