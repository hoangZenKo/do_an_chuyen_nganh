import { ConflictException, Injectable, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { requestContext } from '../common/request-context';

const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
export function base32(bytes: Buffer) {
  let bits = 0, accumulator = 0, output = '';
  for (const byte of bytes) {
    accumulator = (accumulator << 8) | byte; bits += 8;
    while (bits >= 5) { bits -= 5; output += alphabet[(accumulator >>> bits) & 31]; }
  }
  if (bits) output += alphabet[(accumulator << (5 - bits)) & 31];
  return output;
}
export function totp(secret: Buffer, counter: bigint, digits = 6) {
  const message = Buffer.alloc(8); message.writeBigUInt64BE(counter);
  const digest = createHmac('sha1', secret).update(message).digest();
  const offset = digest[digest.length - 1] & 15;
  return ((digest.readUInt32BE(offset) & 0x7fffffff) % (10 ** digits)).toString().padStart(digits, '0');
}
export const tokenHash = (raw: string) => createHash('sha256').update(raw).digest('hex');

@Injectable()
export class AdminMfaService {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  required(enabled: boolean) {
    return enabled || this.config.get<string>('ADMIN_MFA_REQUIRED', this.config.get('NODE_ENV') === 'production' ? 'true' : 'false') === 'true';
  }

  private key() {
    const key = Buffer.from(this.config.get<string>('ADMIN_MFA_ENCRYPTION_KEY', ''), 'base64');
    if (key.length !== 32) throw new ServiceUnavailableException('Admin MFA encryption key is not configured.');
    return key;
  }

  private encrypt(secret: Buffer) {
    const nonce = randomBytes(12); const cipher = createCipheriv('aes-256-gcm', this.key(), nonce);
    const encrypted = Buffer.concat([cipher.update(secret), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), encrypted]).toString('base64');
  }

  private decrypt(value: string) {
    const payload = Buffer.from(value, 'base64');
    const cipher = createDecipheriv('aes-256-gcm', this.key(), payload.subarray(0, 12));
    cipher.setAuthTag(payload.subarray(12, 28));
    return Buffer.concat([cipher.update(payload.subarray(28)), cipher.final()]);
  }

  async enroll(userId: string) {
    const secret = randomBytes(20);
    const requestId = requestContext.getStore()?.requestId;
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
      const profile = await tx.adminProfile.findUnique({ where: { userId }, include: { user: true } });
      if (!profile?.user.isActive) throw new UnauthorizedException();
      if (profile.mfaEnabled) throw new ConflictException('MFA is already enabled.');
      await tx.adminProfile.update({ where: { userId }, data: { mfaSecret: this.encrypt(secret), mfaLastCounter: -1 } });
      await tx.auditLog.create({ data: { actorId: userId, actorRole: 'ADMIN', action: 'admin.mfa_enroll', resourceType: 'admin', resourceId: userId, summary: 'Begin MFA enrollment', requestId } });
    });
    return { data: { secret: base32(secret), uri: `otpauth://totp/RentalRoom:${encodeURIComponent(userId)}?secret=${base32(secret)}&issuer=RentalRoom&algorithm=SHA1&digits=6&period=30` } };
  }

  async verify(userId: string, code: string, activate = false) {
    const requestId = requestContext.getStore()?.requestId;
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
      const profile = await tx.adminProfile.findUnique({ where: { userId }, include: { user: true } });
      if (!profile?.user.isActive || !profile.mfaSecret || (activate && profile.mfaEnabled) || (!activate && !profile.mfaEnabled)) throw new UnauthorizedException('Invalid MFA state.');
      const counter = BigInt(Math.floor(Date.now() / 30000));
      let accepted: bigint | null = null;
      if (/^\d{6}$/.test(code)) for (const candidate of [counter - 1n, counter, counter + 1n]) {
        if (candidate > profile.mfaLastCounter && timingSafeEqual(Buffer.from(totp(this.decrypt(profile.mfaSecret), candidate)), Buffer.from(code))) accepted = candidate;
      }
      const recovery = !activate && profile.recoveryHashes.includes(tokenHash(code));
      if (accepted === null && !recovery) throw new UnauthorizedException({ error: { code: 'INVALID_MFA_CODE', message: 'Mã xác thực không hợp lệ hoặc đã sử dụng.' } });
      const recoveryCodes = activate ? Array.from({ length: 8 }, () => randomBytes(12).toString('hex')) : [];
      await tx.adminProfile.update({ where: { userId }, data: {
        ...(accepted !== null ? { mfaLastCounter: accepted } : {}),
        ...(activate ? { mfaEnabled: true, recoveryHashes: recoveryCodes.map(tokenHash) } : recovery ? { recoveryHashes: profile.recoveryHashes.filter(hash => hash !== tokenHash(code)) } : {}),
      } });
      if (activate) {
        await tx.user.update({ where: { id: userId }, data: { sessionVersion: { increment: 1 } } });
        await tx.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: new Date() } });
      }
      await tx.auditLog.create({ data: { actorId: userId, actorRole: 'ADMIN', action: activate ? 'admin.mfa_enabled' : recovery ? 'admin.mfa_recovery_used' : 'admin.mfa_verified', resourceType: 'admin', resourceId: userId, summary: activate ? 'MFA enabled; sessions revoked' : 'MFA verified', requestId } });
      return recoveryCodes;
    });
  }
}
