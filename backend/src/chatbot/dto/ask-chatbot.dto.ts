import { Transform } from 'class-transformer';
import { IsString, Matches, MaxLength, MinLength, ValidateIf } from 'class-validator';

export class SourceQueryDto {
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  @Matches(/^[a-zA-Z0-9_-]{1,100}$/)
  propertyId?: string;
}

export class AskChatbotDto extends SourceQueryDto {
  @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString()
  @MinLength(1)
  @MaxLength(1000)
  message!: string;
}
