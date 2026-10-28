import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { BillingReasonDto } from './billing-ledger.dto';

export class UtilityTierDto {
  @IsOptional() @IsInt() @Min(1) @Max(2147483647) upTo?: number | null;
  @IsInt() @Min(0) @Max(2147483647) unitPrice!: number;
}

export class ProposeTariffDto extends BillingReasonDto {
  @IsUUID() propertyId!: string;
  @IsOptional() @IsUUID() roomId?: string;
  @IsIn(['SERVICE', 'ELECTRICITY', 'WATER']) kind!: 'SERVICE' | 'ELECTRICITY' | 'WATER';
  @IsString() @MinLength(1) @MaxLength(100) serviceKey!: string;
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsString() @MinLength(1) @MaxLength(30) unit!: string;
  @IsInt() @Min(0) @Max(2147483647) amount!: number;
  @IsBoolean() isActive!: boolean;
  @IsDateString() effectiveFrom!: string;
  @IsArray() @ArrayMaxSize(30) @ValidateNested({ each: true }) @Type(() => UtilityTierDto) tiers!: UtilityTierDto[];
}

export class ReviewTariffDto extends BillingReasonDto {
  @IsIn(['APPROVED', 'REJECTED']) decision!: 'APPROVED' | 'REJECTED';
}

export class LockBillingPeriodDto extends BillingReasonDto {
  @IsUUID() propertyId!: string;
  @IsDateString() month!: string;
}

export class InvoicePreviewDto {
  @IsUUID() leaseId!: string;
  @IsDateString() billingMonth!: string;
  @IsOptional() @IsInt() @Min(0) @Max(2147483647) otherAmount?: number;
}
