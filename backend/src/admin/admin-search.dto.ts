import { Transform, Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AdminSearchQuery {
  @ApiProperty({ minLength: 2, maxLength: 100 })
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MinLength(2) @MaxLength(100)
  search!: string;

  @ApiPropertyOptional({ enum: ['ACCOUNT', 'PROPERTY', 'ROOM', 'SUPPORT_TICKET', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'] })
  @IsOptional() @IsIn(['ACCOUNT', 'PROPERTY', 'ROOM', 'SUPPORT_TICKET', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'])
  kind?: AdminSearchKind;

  @Type(() => Number) @IsInt() @Min(1) @Max(100) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(50) limit = 10;
}

export type AdminSearchKind = 'ACCOUNT' | 'PROPERTY' | 'ROOM' | 'SUPPORT_TICKET' | 'TENANT' | 'LEASE' | 'INVOICE' | 'PAYMENT';

export class AdminResourceQuery {
  @ApiPropertyOptional({ enum: ['ROOM', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'] })
  @IsIn(['ROOM', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'])
  kind = 'ROOM';

  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(50) limit = 20;
  @IsOptional() @IsUUID() landlordId?: string;
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MaxLength(100) search?: string;
}
