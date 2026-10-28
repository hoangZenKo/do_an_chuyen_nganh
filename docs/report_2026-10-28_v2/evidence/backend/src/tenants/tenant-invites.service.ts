import {
  ConflictException,
  HttpException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import * as argon2 from 'argon2';

import { AuthService } from '../auth/auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AcceptTenantInviteDto } from './dto/accept-tenant-invite.dto';
import { CreateTenantInviteDto } from './dto/create-tenant-invite.dto';
import { tenantScope } from '../common/property-scope';

const tenantNotFound = () =>
  new NotFoundException({
    error: { code: 'TENANT_NOT_FOUND', message: 'Tenant not found.' },
  });

const tenantAccountExists = () =>
  new ConflictException({
    error: {
      code: 'TENANT_ACCOUNT_EXISTS',
      message: 'This tenant already has a login account.',
    },
  });

const emailAlreadyRegistered = () =>
  new ConflictException({
    error: {
      code: 'EMAIL_ALREADY_REGISTERED',
      message: 'Email is already registered.',
    },
  });

const invalidInvite = () =>
  new UnauthorizedException({
    error: {
      code: 'INVALID_TENANT_INVITE',
      message: 'Tenant invite is invalid or expired.',
    },
  });

@Injectable()
export class TenantInvitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async create(landlordId: string, tenantId: string, input: CreateTenantInviteDto) {
    return this.prisma.$transaction(async tx => {
    await tx.$queryRaw`SELECT "id" FROM "Tenant" WHERE "id" = ${tenantId} FOR UPDATE`;
    const tenant = await tx.tenant.findFirst({
      where: { id: tenantId, landlordId, isActive: true, ...tenantScope() },
      select: { id: true, userId: true },
    });
    if (!tenant) throw tenantNotFound();
    if (tenant.userId) throw tenantAccountExists();

    const email = input.email.trim().toLowerCase();
    const existingUser = await tx.user.findUnique({ where: { email } });
    if (existingUser) throw emailAlreadyRegistered();
    const now = new Date();
    const latest = await tx.tenantInvite.findFirst({ where: { tenantId }, orderBy: { createdAt: 'desc' } });
    const count = await tx.tenantInvite.count({ where: { tenantId, createdAt: { gte: new Date(now.getTime() - 3_600_000) } } });
    if ((latest && latest.createdAt.getTime() > now.getTime() - 60_000) || count >= 5) throw new HttpException('Chờ ít nhất 60 giây giữa các lời mời, tối đa 5 lần mỗi giờ.', 429);
    await tx.tenantInvite.updateMany({ where: { tenantId, acceptedAt: null, expiresAt: { gt: now } }, data: { expiresAt: now } });

    const inviteCode = randomBytes(32).toString('base64url');
    const invite = await tx.tenantInvite.create({
      data: {
        landlordId,
        tenantId,
        email,
        tokenHash: this.hashInvite(inviteCode),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return {
      data: {
        id: invite.id,
        tenantId,
        email: invite.email,
        inviteCode,
        activationPath: `/tenant/activate?code=${inviteCode}`,
        expiresAt: invite.expiresAt.toISOString(),
      },
    };
    });
  }

  async accept(input: AcceptTenantInviteDto) {
    const now = new Date();
    const tokenHash = this.hashInvite(input.inviteCode);
    try {
      const user = await this.prisma.$transaction(async (tx) => {
        let invite = await tx.tenantInvite.findUnique({
          where: { tokenHash },
          include: { tenant: true },
        });
        if (invite) {
          await tx.$queryRaw`SELECT "id" FROM "Tenant" WHERE "id" = ${invite.tenantId} FOR UPDATE`;
          invite = await tx.tenantInvite.findUnique({ where: { tokenHash }, include: { tenant: true } });
        }
        if (
          !invite ||
          invite.acceptedAt !== null ||
          invite.expiresAt <= now ||
          invite.tenant.userId || !invite.tenant.isActive ||
          !await tx.user.findFirst({ where: { id: invite.landlordId, isActive: true }, select: { id: true } })
        ) {
          throw invalidInvite();
        }

        const created = await tx.user.create({
          data: {
            fullName: invite.tenant.fullName,
            email: invite.email,
            phone: invite.tenant.phone,
            passwordHash: await argon2.hash(input.password),
            role: UserRole.TENANT,
          },
        });
        await tx.tenant.update({
          where: { id: invite.tenantId },
          data: { userId: created.id },
        });
        await tx.tenantInvite.update({
          where: { id: invite.id },
          data: { acceptedAt: now },
        });
        return created;
      });
      return this.auth.issueSession(user);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw emailAlreadyRegistered();
      }
      throw error;
    }
  }

  private hashInvite(value: string) {
    return createHash('sha256').update(value).digest('hex');
  }
}
