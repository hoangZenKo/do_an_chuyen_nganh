import { IsString, MaxLength, MinLength } from 'class-validator';

export class ReversePaymentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  note!: string;
}
