import { Body, Controller, ForbiddenException, Get, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Throttle } from '@nestjs/throttler';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { AuthUser, CurrentUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';
import { AdminMfaService } from './admin-mfa.service';
import { PrismaService } from '../prisma/prisma.service';

class MfaCodeDto {
  @IsString() @MinLength(6) @MaxLength(64) code!: string;
}

@Controller('admin/me/security')
@UseGuards(AuthGuard('jwt'))
@Throttle({ default: { limit: 10, ttl: 60_000 } })
export class AdminSecurityController {
  constructor(private readonly mfa: AdminMfaService, private readonly prisma: PrismaService) {}
  private async profile(user: AuthUser) {
    if (user.role !== AuthRole.ADMIN) throw new ForbiddenException();
    const profile = await this.prisma.adminProfile.findUnique({ where: { userId: user.userId } });
    if (!profile) throw new ForbiddenException('Admin profile must be provisioned by bootstrap.');
    return profile;
  }
  @Get()
  async status(@CurrentUser() user: AuthUser) {
    const profile = await this.profile(user);
    return { data: { mfaEnabled: profile.mfaEnabled, mfaRequired: this.mfa.required(profile.mfaEnabled), verified: user.adminMfaVerified === true } };
  }
  @Post('enroll')
  async enroll(@CurrentUser() user: AuthUser) { await this.profile(user); return this.mfa.enroll(user.userId); }
  @Post('confirm')
  async confirm(@CurrentUser() user: AuthUser, @Body() input: MfaCodeDto) {
    await this.profile(user);
    return { data: { recoveryCodes: await this.mfa.verify(user.userId, input.code, true), signInAgain: true } };
  }
}
