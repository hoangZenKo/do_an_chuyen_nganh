import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsInt, IsISO8601, IsOptional, IsString, IsUUID, IsIn, Max, MaxLength, Min, MinLength, ValidateNested } from 'class-validator';
import { AdminReasonDto } from '../admin/admin-console.dto';

export class FinanceStatementLineDto {
  @IsString() @MinLength(1) @MaxLength(120) externalId!: string;
  @IsInt() @Min(1) @Max(2147483647) amount!: number;
  @IsISO8601() occurredAt!: string;
  @IsString() @MaxLength(500) reference = '';
}

export class FinanceStatementImportDto extends AdminReasonDto {
  @IsUUID() propertyId!: string;
  @IsString() @MinLength(1) @MaxLength(160) accountKey!: string;
  @IsString() @MinLength(1) @MaxLength(160) importKey!: string;
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(1000) @ValidateNested({ each: true }) @Type(() => FinanceStatementLineDto)
  lines!: FinanceStatementLineDto[];
}

export class FinanceProposalDto extends AdminReasonDto {
  @IsInt() @Min(1) lineVersion!: number;
  @IsIn(['MATCH_PAYMENT', 'MATCH_RECEIPT', 'MARK_REVIEWED', 'UNMATCH']) action!: string;
  @IsOptional() @IsUUID() paymentId?: string;
  @IsOptional() @IsUUID() receiptId?: string;
}

export class FinanceProposalReviewDto extends AdminReasonDto {
  @IsInt() @Min(1) version!: number;
}

export class FinanceLinesQueryDto {
  @IsOptional() @IsIn(['UNMATCHED', 'MATCHED', 'NEEDS_REVIEW']) status?: string;
  @IsOptional() @IsUUID() propertyId?: string;
  @Type(() => Number) @IsInt() @Min(1) @Max(100) limit = 50;
}
