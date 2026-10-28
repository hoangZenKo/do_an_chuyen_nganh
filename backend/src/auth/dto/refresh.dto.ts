import { IsString, MinLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RefreshDto {
  @ApiProperty({ minLength: 32 }) @IsString()
  @MinLength(32)
  refreshToken!: string;
}
