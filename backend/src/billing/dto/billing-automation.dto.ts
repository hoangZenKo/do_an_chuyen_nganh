import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
  ValidateNested,
} from "class-validator";

import { BulkInvoiceReadingDto } from "./create-bulk-invoices.dto";

export class BillingAutomationPropertyDto {
  @IsUUID()
  propertyId!: string;
}

export class UpdateBillingAutomationDto {
  @IsUUID()
  propertyId!: string;

  @IsBoolean()
  isEnabled!: boolean;

  @IsInt()
  @Min(1)
  @Max(28)
  invoiceDay!: number;

  @IsInt()
  @Min(1)
  @Max(28)
  dueDay!: number;
}

export class BillingAutomationRunDto {
  @IsUUID()
  propertyId!: string;

  @IsOptional()
  @IsDateString()
  billingMonth?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => BulkInvoiceReadingDto)
  readings?: BulkInvoiceReadingDto[];
}
