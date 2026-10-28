import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateLandlordDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  phone?: string;
}
