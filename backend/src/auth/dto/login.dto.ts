import { IsEmail, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class LoginDto {
  @ApiPropertyOptional({ minLength: 6, maxLength: 64 })
  @IsOptional() @IsString() @MinLength(6) @MaxLength(64)
  mfaCode?: string;
  @ApiProperty({ format: 'email' }) @IsEmail()
  email!: string;

  @ApiProperty({ format: 'password', maxLength: 128 }) @IsString()
  @MinLength(1)
  @MaxLength(128)
  password!: string;
}
