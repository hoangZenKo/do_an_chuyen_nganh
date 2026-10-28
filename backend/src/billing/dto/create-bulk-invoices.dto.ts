import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsOptional,
  IsUUID,
  ValidateNested,
} from 'class-validator';

import { InvoiceMeterReadingDto } from './create-invoice.dto';

export class BulkInvoicePreflightDto {
  @IsUUID()
  propertyId!: string;

  @IsDateString()
  billingMonth!: string;
}

export class BulkInvoiceReadingDto {
  @IsUUID()
  leaseId!: string;

  @IsArray()
  @ArrayMaxSize(2)
  @ValidateNested({ each: true })
  @Type(() => InvoiceMeterReadingDto)
  meterReadings!: InvoiceMeterReadingDto[];
}

export class CreateBulkInvoicesDto {
  @IsUUID()
  propertyId!: string;

  @IsDateString()
  billingMonth!: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => BulkInvoiceReadingDto)
  readings?: BulkInvoiceReadingDto[];
}
