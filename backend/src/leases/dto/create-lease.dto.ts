import {
  IsInt,
  IsOptional,
  IsDateString,
  Max,
  IsUUID,
  Min,
} from 'class-validator';

export class CreateLeaseDto {
  @IsUUID()
  roomId!: string;

  @IsUUID()
  tenantId!: string;

  /** ISO date string; defaults to now if omitted. */
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  @IsInt()
  @Min(0)
  @Max(2147483647)
  monthlyRent!: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  deposit?: number;
}
