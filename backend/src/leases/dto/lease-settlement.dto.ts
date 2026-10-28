import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

export class SettlementLineDto {
  @IsIn(['DAMAGE', 'CLEANING', 'OTHER'])
  kind!: string;

  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  description!: string;

  @IsInt()
  @Min(0)
  @Max(2147483647)
  amount!: number;
}

export class LeaseSettlementDto {
  @IsDateString({ strict: true })
  moveOutDate!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  finalElectricity?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  finalWater?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  electricityUnitPrice?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  waterUnitPrice?: number;

  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => SettlementLineDto)
  lines: SettlementLineDto[] = [];

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  note?: string;
}

export class ConfirmLeaseSettlementDto extends LeaseSettlementDto {
  @IsString()
  @Matches(/^[a-f0-9]{64}$/)
  previewFingerprint!: string;

  @IsUUID()
  idempotencyKey!: string;
}

export class RecordSettlementRefundDto {
  @IsInt() @Min(1)
  version!: number;

  @IsUUID()
  idempotencyKey!: string;

  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(3) @MaxLength(120)
  reference!: string;

  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(10) @MaxLength(1000)
  reason!: string;
}
