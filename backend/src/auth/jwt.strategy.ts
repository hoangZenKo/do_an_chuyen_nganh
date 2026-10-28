import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { User, UserRole } from '@prisma/client';
import { ExtractJwt, Strategy } from 'passport-jwt';

import { AuthRole, toAuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { AdminMfaService } from './admin-mfa.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly mfa?: AdminMfaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
  }

  async validate(payload: { sub: string; typ?: string; ver?: number; mfa?: boolean; sid?: string }): Promise<AuthUser> {
    if (payload.typ !== 'access') throw new UnauthorizedException();
    const user:
      | (Pick<User, 'id' | 'email' | 'role' | 'isActive' | 'sessionVersion'> & {
          staffProfile?: {
            landlordId: string;
            permissions: string[];
            isActive: boolean;
            propertyScopes: { propertyId: string }[];
          } | null;
          adminProfile?: { permissions: string[]; mfaEnabled: boolean } | null;
        })
      | null =
      await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: {
          id: true,
          email: true,
          role: true,
          isActive: true,
          sessionVersion: true,
          adminProfile: { select: { permissions: true, mfaEnabled: true } },
          staffProfile: {
            select: {
              landlordId: true,
              permissions: true,
              isActive: true,
              propertyScopes: { select: { propertyId: true } },
            },
          },
        },
      });
    if (!user || !user.isActive) throw new UnauthorizedException();
    if ((payload.ver ?? 0) !== (user.sessionVersion ?? 0)) throw new UnauthorizedException();
    if (payload.sid) {
      const session = await this.prisma.authSession.findFirst({ where: {
        id: payload.sid, userId: user.id, userVersion: user.sessionVersion,
        revokedAt: null, expiresAt: { gt: new Date() },
      }, select: { id: true } });
      if (!session) throw new UnauthorizedException();
    }
    if (user.role === UserRole.ADMIN) {
      return { userId: user.id, email: user.email, role: AuthRole.ADMIN, sessionId: payload.sid,
        permissions: user.adminProfile?.permissions ?? [], adminMfaVerified: payload.mfa === true,
        adminMfaRequired: this.mfa?.required(user.adminProfile?.mfaEnabled ?? false) ?? false };
    }
    if (user.role === UserRole.STAFF) {
      if (!user.staffProfile?.isActive) throw new UnauthorizedException();
      const owner = await this.prisma.user.findUnique({ where: { id: user.staffProfile.landlordId }, select: { isActive: true } });
      if (!owner?.isActive) throw new UnauthorizedException();
      return {
        userId: user.id,
        email: user.email,
        role: toAuthRole(user.role),
        sessionId: payload.sid,
        landlordId: user.staffProfile.landlordId,
        permissions: user.staffProfile.permissions,
        propertyIds: user.staffProfile.propertyScopes.map((scope) => scope.propertyId),
      };
    }
    return { userId: user.id, email: user.email, role: toAuthRole(user.role), sessionId: payload.sid };
  }
}
