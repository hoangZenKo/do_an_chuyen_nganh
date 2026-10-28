import { IsBoolean, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class UpdateLandlordStatusDto {
  @IsBoolean()
  isActive!: boolean;

  @IsOptional() @IsString() @MaxLength(1000)
  reason?: string;

  @IsOptional() @IsInt() @Min(0)
  version?: number;
}
