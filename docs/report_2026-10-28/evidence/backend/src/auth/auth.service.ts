import { ConflictException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma, User, UserRole } from '@prisma/client';

import { toAuthRole } from '../common/auth-role';
import { createHash, randomBytes } from 'node:crypto';
import * as argon2 from 'argon2';

import { PrismaService } from '../prisma/prisma.service';
import { parseDurationMs } from '../common/parse-duration';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { AdminMfaService } from './admin-mfa.service';
import { requestContext } from '../common/request-context';

const invalidRefreshToken = () =>
  new UnauthorizedException({
    error: { code: 'INVALID_REFRESH_TOKEN', message: 'Refresh token is invalid.' },
  });

const invalidCredentials = () =>
  new UnauthorizedException({
    error: { code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' },
  });

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly mfa?: AdminMfaService,
  ) {}

  async register(input: RegisterDto) {
    return this.registerAccount(input, UserRole.LANDLORD);
  }

  async registerSeeker(input: RegisterDto) {
    return this.registerAccount(input, UserRole.TENANT);
  }

  private async registerAccount(input: RegisterDto, role: UserRole) {
    const email = this.normalizeEmail(input.email);
    const fullName = input.fullName.trim();
    const phone = input.phone.trim();

    try {
      const user = await this.prisma.user.create({
        data: {
          fullName,
          email,
          phone,
          passwordHash: await argon2.hash(input.password),
          role,
        },
      });
      return this.issueSession(user);
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException({
          error: { code: 'EMAIL_ALREADY_REGISTERED', message: 'Email is already registered.' },
        });
      }
      throw error;
    }
  }

  async login(input: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: this.normalizeEmail(input.email) },
    });
    if (!user || !user.isActive || !(await argon2.verify(user.passwordHash, input.password))) {
      throw invalidCredentials();
    }
    let mfaVerified = false;
    if (user.role === UserRole.ADMIN) {
      const profile = await this.prisma.adminProfile.findUnique({ where: { userId: user.id } });
      if (profile?.mfaEnabled) {
        if (!input.mfaCode) throw new UnauthorizedException({ error: { code: 'MFA_REQUIRED', message: 'Nhập mã xác thực hoặc mã khôi phục admin.' } });
        if (!this.mfa) throw new UnauthorizedException({ error: { code: 'MFA_REQUIRED', message: 'Admin MFA is not available.' } });
        await this.mfa.verify(user.id, input.mfaCode);
        mfaVerified = true;
      }
    }
    return this.issueSession(user, undefined, mfaVerified);
  }

  async refresh(rawToken: string) {
    const tokenHash = this.hashRefreshToken(rawToken);
    const now = new Date();

    const result = await this.prisma.$transaction(async (tx) => {
      const candidate = await tx.refreshToken.findUnique({ where: { tokenHash }, select: { userId: true } });
      if (!candidate) throw invalidRefreshToken();
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${candidate.userId} FOR UPDATE`;
      const token = await tx.refreshToken.findUnique({
        where: { tokenHash },
        include: { user: true },
      });
      if (
        !token ||
        token.revokedAt !== null ||
        token.expiresAt <= now ||
        !token.user.isActive
      ) {
        throw invalidRefreshToken();
      }

      if (token.sessionId) {
        const session = await tx.authSession.findFirst({ where: {
          id: token.sessionId, userId: token.userId, revokedAt: null,
          expiresAt: { gt: now }, userVersion: token.user.sessionVersion,
        } });
        if (!session) throw invalidRefreshToken();
      }

      const consumed = await tx.refreshToken.updateMany({
        where: { id: token.id, revokedAt: null, expiresAt: { gt: now } },
        data: { revokedAt: now },
      });
      if (consumed.count !== 1) throw invalidRefreshToken();

      const replacement = await this.createRefreshToken(token.user.id, tx, token.mfaVerified, token.sessionId ?? undefined, token.user.sessionVersion);
      await tx.refreshToken.update({
        where: { id: token.id },
        data: { replacedByTokenId: replacement.record.id },
      });
      return { user: token.user, replacement, mfaVerified: token.mfaVerified };
    });

    return this.issueSession(result.user, result.replacement, result.mfaVerified);
  }

  async logout(rawToken: string): Promise<void> {
    const tokenHash = this.hashRefreshToken(rawToken);
    await this.prisma.$transaction(async tx => {
      const token = await tx.refreshToken.findUnique({ where: { tokenHash } });
      if (!token) return;
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${token.userId} FOR UPDATE`;
      const now = new Date();
      if (token.sessionId) {
        await tx.authSession.updateMany({ where: { id: token.sessionId, userId: token.userId, revokedAt: null }, data: { revokedAt: now } });
        await tx.refreshToken.updateMany({ where: { sessionId: token.sessionId, revokedAt: null }, data: { revokedAt: now } });
      } else {
        await tx.refreshToken.updateMany({ where: { tokenHash, revokedAt: null }, data: { revokedAt: now } });
      }
    });
  }

  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.isActive) throw invalidCredentials();
    return user;
  }

  async changePassword(userId: string, input: ChangePasswordDto): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (
      !user ||
      !user.isActive ||
      !(await argon2.verify(user.passwordHash, input.currentPassword))
    ) {
      throw invalidCredentials();
    }
    const passwordHash = await argon2.hash(input.newPassword);
    await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.id} FOR UPDATE`;
      const current = await tx.user.findUniqueOrThrow({ where: { id: user.id } });
      if (current.passwordHash !== user.passwordHash) throw invalidCredentials();
      await tx.user.update({ where: { id: user.id },
        data: { passwordHash, sessionVersion: { increment: 1 } } });
      await tx.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
    });
  }

  async issueSession(user: User, existing?: { raw: string; record: { sessionId: string | null; expiresAt: Date } }, mfaVerified = false) {
    const refresh = existing ?? await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.id} FOR UPDATE`;
      const current = await tx.user.findUniqueOrThrow({ where: { id: user.id } });
      if (!current.isActive || current.sessionVersion !== user.sessionVersion) throw invalidCredentials();
      return this.createRefreshToken(user.id, tx, mfaVerified, undefined, user.sessionVersion);
    });
    const serializedUser = await this.serializeUser(user);
    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      email: user.email,
      role: serializedUser.role,
      typ: 'access',
      sid: refresh.record.sessionId,
      ver: user.sessionVersion ?? 0,
      mfa: mfaVerified,
    });
    const accessPayload = this.jwt.decode(accessToken) as { exp?: number } | null;
    const accessExpiresAt = accessPayload?.exp
      ? new Date(accessPayload.exp * 1000)
      : new Date(Date.now() + this.accessTtlMs());

    return {
      data: {
        user: { ...serializedUser, adminMfaVerified: mfaVerified },
        accessToken,
        refreshToken: refresh.raw,
        accessTokenExpiresAt: accessExpiresAt.toISOString(),
        refreshTokenExpiresAt: refresh.record.expiresAt.toISOString(),
      },
    };
  }

  async sessions(userId: string, currentSessionId?: string) {
    const now = new Date();
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { sessionVersion: true } });
    const rows = await this.prisma.authSession.findMany({
      where: { userId, userVersion: user.sessionVersion, revokedAt: null, expiresAt: { gt: now } },
      select: { id: true, device: true, ip: true, createdAt: true, lastSeenAt: true, expiresAt: true },
      orderBy: { lastSeenAt: 'desc' }, take: 100,
    });
    return { data: rows.map(row => ({
      id: row.id,
      createdAt: row.createdAt.toISOString(),
      expiresAt: row.expiresAt.toISOString(),
      lastSeenAt: row.lastSeenAt.toISOString(),
      device: row.device,
      ip: row.ip,
      current: row.id === currentSessionId,
      active: true,
    })) };
  }

  async revokeSession(userId: string, sessionId: string) {
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
      const now = new Date();
      const result = await tx.authSession.updateMany({ where: { id: sessionId, userId, revokedAt: null }, data: { revokedAt: now } });
      if (result.count !== 1) throw new NotFoundException({ error: { code: 'SESSION_NOT_FOUND', message: 'Session not found.' } });
      await tx.refreshToken.updateMany({ where: { sessionId, userId, revokedAt: null }, data: { revokedAt: now } });
      await this.sessionAudit(tx, userId, 'auth.session_revoked', sessionId);
    });
    return { data: { revoked: true, sessionId } };
  }

  async revokeOtherSessions(userId: string, currentSessionId?: string) {
    if (!currentSessionId) throw new UnauthorizedException('Sign in again to manage sessions.');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
      const now = new Date();
      const result = await tx.authSession.updateMany({
        where: { userId, revokedAt: null, id: { not: currentSessionId } }, data: { revokedAt: now },
      });
      await tx.refreshToken.updateMany({
        where: { userId, revokedAt: null, OR: [{ sessionId: null }, { sessionId: { not: currentSessionId } }] }, data: { revokedAt: now },
      });
      await this.sessionAudit(tx, userId, 'auth.other_sessions_revoked', currentSessionId);
      return { data: { revoked: result.count } };
    });
  }

  private async sessionAudit(tx: Prisma.TransactionClient, userId: string, action: string, sessionId: string) {
    const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { role: true } });
    await tx.auditLog.create({ data: { actorId: userId, actorRole: user.role, action, resourceType: 'auth_session', resourceId: sessionId,
      summary: 'Session access revoked', requestId: requestContext.getStore()?.requestId } });
  }

  private async createRefreshToken(
    userId: string,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
    mfaVerified = false,
    sessionId?: string,
    userVersion = 0,
  ) {
    const raw = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + this.refreshTtlMs());
    const context = requestContext.getStore();
    const session = sessionId
      ? await client.authSession.update({ where: { id: sessionId }, data: { lastSeenAt: new Date() } })
      : await client.authSession.create({ data: {
          userId, userVersion, expiresAt,
          device: context?.device?.replace(/[\x00-\x1f\x7f]/g, '').slice(0, 256) || 'Unknown device',
          ip: context?.ip ? context.ip.replace(/\.\d+$/, '.0').replace(/(:[0-9a-f]+){2}$/i, '::') : null,
        } });
    const record = await client.refreshToken.create({
      data: { userId, sessionId: session.id, tokenHash: this.hashRefreshToken(raw), expiresAt: session.expiresAt < expiresAt ? session.expiresAt : expiresAt, mfaVerified },
    });
    return { raw, record };
  }

  private hashRefreshToken(raw: string) {
    return createHash('sha256').update(raw).digest('hex');
  }

  private accessTtlMs() {
    return parseDurationMs(this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'));
  }

  private refreshTtlMs() {
    const days = Number(this.config.get<string>('REFRESH_TOKEN_TTL_DAYS', '30'));
    return (Number.isFinite(days) && days > 0 ? days : 30) * 24 * 60 * 60 * 1000;
  }

  private normalizeEmail(value: string) {
    return value.trim().toLowerCase();
  }

  private isUniqueViolation(error: unknown) {
    return (
      (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') ||
      (typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: unknown }).code === 'P2002')
    );
  }

  async serializeUser(user: User) {
    if (user.role === UserRole.ADMIN) {
      const profile = await this.prisma.adminProfile.findUnique({ where: { userId: user.id } });
      return { id: user.id, fullName: user.fullName, email: user.email, phone: user.phone,
        role: 'admin', permissions: profile?.permissions ?? [], preset: profile?.preset ?? null,
        adminMfaEnabled: profile?.mfaEnabled ?? false, adminMfaRequired: this.mfa?.required(profile?.mfaEnabled ?? false) ?? false };
    }
    if (user.role === UserRole.STAFF) {
      const staffProfile = await this.prisma.staffProfile.findUnique({
        where: { userId: user.id },
        select: {
          landlordId: true,
          permissions: true,
          preset: true,
          isActive: true,
          propertyScopes: { select: { propertyId: true } },
        },
      });
      return {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: toAuthRole(user.role),
        landlordId: staffProfile?.landlordId ?? null,
        permissions: staffProfile?.permissions ?? [],
        preset: staffProfile?.preset ?? null,
        isStaffActive: staffProfile?.isActive ?? false,
        propertyIds: staffProfile?.propertyScopes.map((scope) => scope.propertyId) ?? [],
      };
    }
    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      role: toAuthRole(user.role),
    };
  }
}
