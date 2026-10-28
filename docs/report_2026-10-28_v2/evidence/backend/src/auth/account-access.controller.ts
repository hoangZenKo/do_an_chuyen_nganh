import { Body, Controller, Post } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { IsEmail, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import { ApiProperty, ApiTags } from '@nestjs/swagger';
import { AccountAccessService } from './account-access.service';

class ForgotDto { @ApiProperty({ format: 'email' }) @IsEmail() @MaxLength(254) email!: string; }
class RedeemDto {
  @ApiProperty({ minLength: 32, maxLength: 128 }) @IsString() @MinLength(32) @MaxLength(128) token!: string;
  @ApiProperty({ minLength: 12, maxLength: 128, format: 'password' })
  @IsString() @MinLength(12) @MaxLength(128)
  @Matches(/[A-Z]/) @Matches(/[a-z]/) @Matches(/[0-9]/) @Matches(/[^A-Za-z0-9]/) password!: string;
}
@ApiTags('Identity')
@Controller('auth/account-access')
@Throttle({ default: { limit: 5, ttl: 60000 } })
export class AccountAccessController {
  constructor(private readonly access: AccountAccessService) {}
  @Post('forgot') forgot(@Body() input: ForgotDto) { return this.access.forgot(input.email); }
  @Post('redeem') redeem(@Body() input: RedeemDto) { return this.access.redeem(input.token, input.password); }
}
