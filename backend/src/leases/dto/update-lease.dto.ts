import { IsDateString, IsInt, IsOptional, IsString, MaxLength, Min, Max } from 'class-validator';

export class UpdateLeaseDto {
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  monthlyRent?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2147483647)
  deposit?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
