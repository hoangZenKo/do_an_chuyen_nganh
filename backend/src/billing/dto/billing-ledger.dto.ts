import { Transform, Type } from 'class-transformer';
import { ArrayMaxSize, ArrayUnique, IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';

export class BillingCommandDto {
  @IsUUID() requestKey!: string;
}

export class BillingReasonDto extends BillingCommandDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(1) @MaxLength(500) reason!: string;
}

export class AdjustmentDto extends BillingReasonDto {
  @IsIn(['CREDIT', 'DEBIT']) kind!: 'CREDIT' | 'DEBIT';
  @IsIn(['ADJUSTMENT', 'DISCOUNT', 'TENANT_WAIVER', 'LATE_FEE', 'SURCHARGE']) category!: string;
  @IsOptional() @IsInt() @Min(1) @Max(2147483647) amount?: number;
  @IsOptional() @IsInt() @Min(1) @Max(10000) basisPoints?: number;
}

export class ReplacementLineDto {
  @IsIn(['RENT', 'ELECTRICITY', 'WATER', 'SERVICE', 'OTHER', 'DISCOUNT', 'SURCHARGE']) kind!: string;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(1) @MaxLength(200) description!: string;
  @IsInt() @Min(1) @Max(2147483647) quantity!: number;
  @IsString() @MinLength(1) @MaxLength(30) unit!: string;
  @IsInt() @Min(-2147483647) @Max(2147483647) unitPrice!: number;
}

export class ReplaceInvoiceDto extends BillingReasonDto {
  @IsOptional() @IsDateString() dueDate?: string;
  @IsArray() @ArrayMaxSize(100) @ValidateNested({ each: true }) @Type(() => ReplacementLineDto)
  lines!: ReplacementLineDto[];
}

export class AllocationLineDto {
  @IsUUID() invoiceId!: string;
  @IsInt() @Min(1) @Max(2147483647) amount!: number;
}

export class AllocateReceiptDto extends BillingCommandDto {
  @IsArray() @ArrayMaxSize(100) @ValidateNested({ each: true }) @Type(() => AllocationLineDto)
  allocations!: AllocationLineDto[];
}

export class CreateReceiptDto extends AllocateReceiptDto {
  @IsUUID() tenantId!: string;
  @IsInt() @Min(1) @Max(2147483647) amount!: number;
  @Transform(({ value }) => typeof value === 'string' ? value.toUpperCase() : value)
  @IsIn(['CASH', 'BANK_TRANSFER', 'OTHER']) method!: 'CASH' | 'BANK_TRANSFER' | 'OTHER';
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(1) @MaxLength(200) reference!: string;
  @IsOptional() @IsDateString() paidAt?: string;
}

export class RefundReceiptDto extends BillingReasonDto {
  @IsInt() @Min(1) @Max(2147483647) amount!: number;
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(1) @MaxLength(200) reference!: string;
}

export class AgingQueryDto {
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @IsUUID() roomId?: string;
  @IsOptional() @IsUUID() tenantId?: string;
  @IsOptional() @IsIn(['tenant', 'property', 'room']) groupBy?: 'tenant' | 'property' | 'room';
}

export class ReminderPolicyDto extends BillingCommandDto {
  @IsOptional() @IsUUID() propertyId?: string;
  @IsInt() @Min(0) expectedVersion!: number;
  @IsBoolean() enabled!: boolean;
  @IsArray() @ArrayMaxSize(30) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true }) @Max(365, { each: true })
  beforeDays!: number[];
  @IsBoolean() onDueDate!: boolean;
  @IsArray() @ArrayMaxSize(30) @ArrayUnique() @IsInt({ each: true }) @Min(1, { each: true }) @Max(3650, { each: true })
  overdueDays!: number[];
  @IsArray() @ArrayMaxSize(3) @ArrayUnique() @IsIn(['APP', 'EMAIL', 'ZALO'], { each: true }) channels!: string[];
}
