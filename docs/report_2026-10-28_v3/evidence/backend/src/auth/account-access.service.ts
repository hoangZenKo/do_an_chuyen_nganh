import { ConflictException, HttpException, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'node:crypto';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { tokenHash } from './admin-mfa.service';
import { Prisma } from '@prisma/client';
import { DeliveryService, httpsEndpoint } from '../delivery/delivery.service';
import { DeliveryCryptoService } from '../delivery/delivery-crypto.service';
import { requestContext } from '../common/request-context';

@Injectable()
export class AccountAccessService {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService,
    private readonly delivery: DeliveryService, private readonly crypto: DeliveryCryptoService) {}
  ready() {
    return this.delivery.configured() && !!httpsEndpoint(this.config.get<string>('AUTH_PUBLIC_APP_URL'));
  }
  async send(userId: string, purpose: string) {
    return this.prisma.$transaction(tx => this.enqueue(tx, userId, purpose));
  }

  async enqueue(tx: Prisma.TransactionClient, userId: string, purpose: string) {
    if (!this.ready()) throw new ServiceUnavailableException('Kênh gửi lời mời/khôi phục chưa được cấu hình.');
    const raw = randomBytes(32).toString('base64url');
    await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
    const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.isActive) throw new UnauthorizedException();
    if (user.role !== 'ADMIN') {
      const since = new Date(Date.now() - 3_600_000);
      const latest = await tx.accountAccessToken.findFirst({ where: { userId, purpose }, orderBy: { createdAt: 'desc' } });
      const count = await tx.accountAccessToken.count({ where: { userId, purpose, createdAt: { gte: since } } });
      if ((latest && latest.createdAt.getTime() > Date.now() - 60_000) || count >= 5) {
        throw new HttpException('Vui lòng chờ trước khi yêu cầu gửi lại.', 429);
      }
    }
    await tx.deliveryJob.updateMany({ where: { token: { userId, purpose }, status: { in: ['PENDING', 'PROCESSING'] } },
      data: { status: 'CANCELLED', payload: null, leaseOwner: null, leaseUntil: null } });
    await tx.accountAccessToken.updateMany({ where: { userId, purpose, consumedAt: null }, data: { consumedAt: new Date() } });
    const record = await tx.accountAccessToken.create({ data: { userId, purpose, tokenHash: tokenHash(raw), expiresAt: new Date(Date.now() + 30 * 60000) } });
    const url = new URL('/account/activate', this.config.getOrThrow<string>('AUTH_PUBLIC_APP_URL'));
    url.hash = `token=${raw}`;
    const job = await tx.deliveryJob.create({ data: { kind: 'ACCOUNT_ACCESS', tokenId: record.id,
      expiresAt: record.expiresAt, payload: this.crypto.encrypt({ email: user.email, purpose, actionUrl: url.toString(), expiresAt: record.expiresAt.toISOString() }) } });
    return { queued: true, deliveryId: job.id };
  }
  async forgot(email: string) {
    const user = await this.prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
    if (user?.isActive && this.ready()) {
      try { await this.send(user.id, 'PASSWORD_RESET'); } catch {}
    }
    return { data: { message: 'Nếu tài khoản hợp lệ và kênh gửi khả dụng, bạn sẽ nhận được hướng dẫn.' } };
  }
  async redeem(raw: string, password: string) {
    const passwordHash = await argon2.hash(password);
    await this.prisma.$transaction(async tx => {
      const token = await tx.accountAccessToken.findUnique({ where: { tokenHash: tokenHash(raw) } });
      if (!token) throw new UnauthorizedException('Link không hợp lệ hoặc đã hết hạn.');
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${token.userId} FOR UPDATE`;
      const current = await tx.accountAccessToken.findUniqueOrThrow({ where: { id: token.id } });
      const user = await tx.user.findUniqueOrThrow({ where: { id: token.userId } });
      if (current.consumedAt || current.expiresAt <= new Date() || !user.isActive) throw new UnauthorizedException('Link không hợp lệ hoặc đã hết hạn.');
      const consumed = await tx.accountAccessToken.updateMany({ where: { id: current.id, consumedAt: null }, data: { consumedAt: new Date() } });
      if (consumed.count !== 1) throw new ConflictException();
      await tx.user.update({ where: { id: user.id }, data: { passwordHash, sessionVersion: { increment: 1 } } });
      await tx.refreshToken.updateMany({ where: { userId: user.id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.accountAccessToken.updateMany({ where: { userId: user.id, consumedAt: null }, data: { consumedAt: new Date() } });
      await tx.deliveryJob.updateMany({ where: { token: { userId: user.id }, status: { in: ['PENDING', 'PROCESSING'] } }, data: { status: 'CANCELLED', payload: null, leaseOwner: null, leaseUntil: null } });
      await tx.auditLog.create({ data: { actorId: user.id, actorRole: user.role, action: 'auth.access_token_redeemed', resourceType: 'user', resourceId: user.id, summary: 'Password set using one-time account token', requestId: requestContext.getStore()?.requestId } });
    });
    return { data: { signInAgain: true } };
  }
}
