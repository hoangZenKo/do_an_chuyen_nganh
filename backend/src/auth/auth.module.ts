import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { AdminMfaService } from './admin-mfa.service';
import { AdminSecurityController } from './admin-security.controller';
import { AccountAccessController } from './account-access.controller';
import { AccountAccessService } from './account-access.service';
import { AdminStepUpService } from './admin-step-up.service';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
        signOptions: {
          expiresIn: config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'),
        },
      }),
    }),
  ],
  controllers: [AuthController, AdminSecurityController, AccountAccessController],
  providers: [AuthService, JwtStrategy, AdminMfaService, AccountAccessService, AdminStepUpService],
  exports: [AuthService, AdminMfaService, AccountAccessService, AdminStepUpService],
})
export class AuthModule {}
