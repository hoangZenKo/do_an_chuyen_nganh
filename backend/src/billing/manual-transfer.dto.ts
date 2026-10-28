import { Transform } from 'class-transformer';
import { IsBoolean, IsInt, IsString, Matches, MaxLength, Min, MinLength, ValidateIf } from 'class-validator';

const trim = ({ value }: { value: unknown }) => typeof value === 'string' ? value.trim() : value;

export class SaveTransferAccountDto {
  @IsInt() @Min(0) version!: number;
  @IsBoolean() enabled!: boolean;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(120) bankName!: string;
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(120) accountName!: string;
  @Transform(trim) @IsString() @Matches(/^[0-9]{4,34}$/) accountNumber!: string;
  @ValidateIf((_object, value) => value !== undefined && value !== null)
  @IsString() @MaxLength(200) @Matches(/^\/uploads\/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp|heic|heif)$/i)
  qrImagePath?: string | null;
}
