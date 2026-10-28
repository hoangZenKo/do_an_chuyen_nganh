import { IsDateString, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateRoomInspectionDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title!: string;

  @IsDateString()
  dueAt!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}
