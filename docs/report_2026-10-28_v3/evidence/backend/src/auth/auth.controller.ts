import { Body, Controller, Get, HttpCode, HttpStatus, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AuthService } from './auth.service';
import { Throttle } from '@nestjs/throttler';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ChangePasswordDto } from './dto/change-password.dto';

@ApiTags('Identity')
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.CREATED)
  register(@Body() input: RegisterDto) {
    return this.auth.register(input);
  }

  @Post('register-seeker')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @HttpCode(HttpStatus.CREATED)
  registerSeeker(@Body() input: RegisterDto) {
    return this.auth.registerSeeker(input);
  }

  @Post('login')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  login(@Body() input: LoginDto) {
    return this.auth.login(input);
  }

  @Post('refresh')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  refresh(@Body() input: RefreshDto) {
    return this.auth.refresh(input.refreshToken);
  }

  @Post('logout')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body() input: RefreshDto): Promise<void> {
    await this.auth.logout(input.refreshToken);
  }

  @Get('/me')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  async me(@CurrentUser() user: AuthUser) {
    const current = await this.auth.me(user.userId);
    return { data: { ...await this.auth.serializeUser(current), adminMfaVerified: user.adminMfaVerified ?? false } };
  }

  @Get('sessions')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  sessions(@CurrentUser() user: AuthUser) {
    return this.auth.sessions(user.userId, user.sessionId);
  }

  @Post('sessions/:id/revoke')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  revokeSession(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.auth.revokeSession(user.userId, id);
  }

  @Post('sessions/revoke-all')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  revokeOtherSessions(@CurrentUser() user: AuthUser) {
    return this.auth.revokeOtherSessions(user.userId, user.sessionId);
  }

  @Post('change-password')
  @ApiBearerAuth()
  @UseGuards(AuthGuard('jwt'))
  @HttpCode(HttpStatus.NO_CONTENT)
  async changePassword(
    @CurrentUser() user: AuthUser,
    @Body() input: ChangePasswordDto,
  ): Promise<void> {
    await this.auth.changePassword(user.userId, input);
  }
}
