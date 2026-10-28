import { IsDateString, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class RenewLeaseDto {
  @IsDateString()
  endDate!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  monthlyRent?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  deposit?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
