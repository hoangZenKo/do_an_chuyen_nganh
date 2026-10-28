import { IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class CreateMeterReadingDto {
  @IsUUID()
  roomId!: string;

  @IsIn(['electricity', 'water', 'ELECTRICITY', 'WATER'])
  utilityType!: string;

  /** ISO date string. The API stores it normalized to the first day of month. */
  @IsDateString()
  billingMonth!: string;

  @IsInt()
  @Min(0)
  previousReading!: number;

  @IsInt()
  @Min(0)
  currentReading!: number;

  @IsInt()
  @Min(1)
  unitPrice!: number;

  @IsOptional()
  @IsString()
  note?: string;
}
