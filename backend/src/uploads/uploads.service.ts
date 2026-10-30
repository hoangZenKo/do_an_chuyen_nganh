import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import { mkdir, readFile, writeFile, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { AuthRole, toAuthRole } from '../common/auth-role';

export function detectFile(bytes: Buffer): { extension: string; mime: string } | null {
  if (bytes.subarray(0, 3).equals(Buffer.from([255, 216, 255]))) return { extension: 'jpg', mime: 'image/jpeg' };
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return { extension: 'png', mime: 'image/png' };
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') return { extension: 'webp', mime: 'image/webp' };
  if (bytes.toString('ascii', 0, 5) === '%PDF-') return { extension: 'pdf', mime: 'application/pdf' };
  if (bytes.toString('ascii', 4, 8) === 'ftyp' && /^(heic|heix|hevc|hevx|mif1|msf1)$/.test(bytes.toString('ascii', 8, 12))) return { extension: 'heic', mime: 'image/heic' };
  return null;
}

@Injectable()
export class UploadsService {
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}
  private readonly directory = this.config.get<string>('UPLOADS_DIR') || join(process.cwd(), 'uploads');
  async save(user: AuthUser, bytes: Buffer, purpose: 'PRIVATE' | 'PUBLIC_LISTING') {
    const type = detectFile(bytes);
    if (!type || (purpose === 'PUBLIC_LISTING' && !type.mime.startsWith('image/'))) throw new BadRequestException('Nội dung file không phải ảnh hoặc PDF được hỗ trợ.');
    if (purpose === 'PUBLIC_LISTING' && user.role !== AuthRole.LANDLORD) throw new BadRequestException('Chỉ chủ trọ được tải ảnh tin công khai.');
    const filename = `${randomUUID()}.${type.extension}`;
    await mkdir(this.directory, { recursive: true });
    await writeFile(join(this.directory, filename), bytes, { flag: 'wx' });
    try {
      await this.prisma.uploadedFile.create({ data: { filename, ownerId: user.userId, mimeType: type.mime, purpose } });
    } catch (error) {
      await unlink(join(this.directory, filename)).catch(() => undefined);
      throw error;
    }
    return { data: { url: `/uploads/${filename}`, fileName: filename, mimeType: type.mime, size: bytes.length } };
  }
  private validName(filename: string) {
    if (!/^[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp|heic|heif|pdf)$/i.test(filename)) throw new NotFoundException();
  }
  async publicFile(filename: string) {
    this.validName(filename);
    const asset = await this.prisma.uploadedFile.findUnique({ where: { filename } });
    if (asset) return asset.purpose === 'PUBLIC_LISTING';
    return false;
  }
  async canRead(user: AuthUser, filename: string) {
    this.validName(filename);
    const asset = await this.prisma.uploadedFile.findUnique({ where: { filename } });
    if (asset?.purpose === 'SUPPORT_CLEAN') {
      const staff = user.role === AuthRole.ADMIN && user.permissions?.includes('admin.support.read');
      return !!await this.prisma.supportAttachment.findFirst({ where: { filename,
        ...(!staff ? { internal: false, ticket: { requesterId: user.userId } } : {}) } });
    }
    if (asset?.ownerId === user.userId || await this.publicFile(filename)) return true;
    if (!asset) return false;
    if (user.role === AuthRole.TENANT && asset.purpose === 'PRIVATE' && asset.mimeType.startsWith('image/') &&
        await this.prisma.propertyPaymentAccount.count({ where: { qrImagePath: '/uploads/' + filename, enabled: true,
          property: { isArchived: false, landlordId: asset.ownerId,
            rooms: { some: { invoices: { some: { tenant: { userId: user.userId }, isDemo: false, status: { in: ['UNPAID', 'PARTIAL'] } } } } } } } })) return true;
    const suffix = '/uploads/' + filename;
    if (user.role === AuthRole.STAFF) {
      if (!user.permissions?.includes('maintenance.view')) return false;
      const allowed = await this.prisma.$queryRaw<{ allowed: boolean }[]>`
        SELECT EXISTS (
          SELECT 1 FROM "MaintenanceTicket" ticket
          WHERE ticket."landlordId" = ${landlordScopeId(user)}
          AND ticket."propertyId" = ANY(${user.propertyIds ?? []}::text[])
          AND (EXISTS (SELECT 1 FROM unnest(ticket."imageUrls") url WHERE right(url, ${suffix.length}::int) = ${suffix})
            OR EXISTS (SELECT 1 FROM "MaintenanceComment" c, unnest(c."imageUrls") url
              WHERE c."ticketId" = ticket.id AND right(url, ${suffix.length}::int) = ${suffix}))
        ) AS allowed`;
      return allowed[0]?.allowed === true;
    }
    const escapedFilename = filename.replace(/_/g, '\\_');
    const landlordId = landlordScopeId(user);
    const billing = user.role === AuthRole.LANDLORD;
    const maintenance = user.role === AuthRole.LANDLORD;
    const rows = await this.prisma.$queryRaw<{ allowed: boolean }[]>`
      SELECT EXISTS (
        SELECT 1 FROM "LeaseHandover" h JOIN "Lease" l ON l.id = h."leaseId"
        JOIN "Tenant" t ON t.id = l."tenantId"
        JOIN "Room" r ON r.id = l."roomId" JOIN "Property" p ON p.id = r."propertyId"
        WHERE (t."userId" = ${user.userId} OR (${user.role === AuthRole.LANDLORD} AND p."landlordId" = ${user.userId}))
        AND EXISTS (SELECT 1 FROM unnest(h."imageUrls") url WHERE right(url, ${suffix.length}::int) = ${suffix})
        UNION ALL
        SELECT 1 FROM "PaymentProof" proof JOIN "Tenant" t ON t.id = proof."tenantId"
        WHERE (t."userId" = ${user.userId} OR (${!!billing} AND t."landlordId" = ${landlordId}))
        AND EXISTS (SELECT 1 FROM unnest(proof."proofImageUrls") url WHERE right(url, ${suffix.length}::int) = ${suffix})
        UNION ALL
        SELECT 1 FROM "MaintenanceTicket" ticket
        WHERE (EXISTS (SELECT 1 FROM "Lease" lease JOIN "Tenant" t ON t.id = lease."tenantId"
          WHERE lease."roomId" = ticket."roomId" AND lease.status = 'ACTIVE'
          AND ticket."createdAt" >= lease."startDate" AND t."userId" = ${user.userId})
          OR (${!!maintenance} AND ticket."landlordId" = ${landlordId}))
        AND (EXISTS (SELECT 1 FROM unnest(ticket."imageUrls") url WHERE right(url, ${suffix.length}::int) = ${suffix})
          OR EXISTS (SELECT 1 FROM "MaintenanceComment" c, unnest(c."imageUrls") url WHERE c."ticketId" = ticket.id AND right(url, ${suffix.length}::int) = ${suffix}))
      ) AS allowed`;
    if (rows[0]?.allowed) return true;
    if (user.role === AuthRole.LANDLORD) {
      const roomAllowed = user.role === AuthRole.LANDLORD || user.permissions?.includes('room.view');
      if (roomAllowed && await this.prisma.room.count({ where: { property: { landlordId }, OR: [
        { imageUrl: { endsWith: `/uploads/${escapedFilename}` } }, { assets: { some: { imageUrl: { endsWith: `/uploads/${escapedFilename}` } } } },
      ] } })) return true;
      if ((user.role === AuthRole.LANDLORD || user.permissions?.includes('expense.view')) && await this.prisma.expense.count({ where: { landlordId, receiptUrl: { endsWith: `/uploads/${escapedFilename}` } } })) return true;
    }
    return false;
  }
  async access(user: AuthUser, filename: string) {
    if (!await this.canRead(user, filename)) throw new NotFoundException();
    const account = await this.prisma.user.findUniqueOrThrow({ where: { id: user.userId }, select: { sessionVersion: true } });
    const body = Buffer.from(JSON.stringify({ file: filename, uid: user.userId, sid: user.sessionId, ver: account.sessionVersion, exp: Date.now() + 300000 })).toString('base64url');
    return { data: { url: `/uploads/${filename}?access=${body}.${this.signature(body)}`, expiresInSeconds: 300 } };
  }
  private signature(body: string) {
    return createHmac('sha256', this.config.getOrThrow<string>('JWT_ACCESS_SECRET')).update('upload-access:' + body).digest('base64url');
  }
  async read(filename: string, token?: string) {
    if (!await this.publicFile(filename)) {
      try {
        const [body, signature] = (token ?? '').split('.');
        const expected = this.signature(body);
        if (signature?.length !== expected.length || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) throw new Error();
        const payload = JSON.parse(Buffer.from(body, 'base64url').toString());
        if (payload.file !== filename || payload.exp < Date.now()) throw new Error();
        const user = await this.prisma.user.findUniqueOrThrow({ where: { id: payload.uid }, include: { staffProfile: { include: { propertyScopes: true } }, adminProfile: true } });
        if (!user.isActive || user.sessionVersion !== payload.ver || (user.role === 'STAFF' && !user.staffProfile?.isActive)) throw new Error();
        if (payload.sid && !await this.prisma.authSession.findFirst({ where: { id: payload.sid, userId: user.id, userVersion: user.sessionVersion, revokedAt: null, expiresAt: { gt: new Date() } }, select: { id: true } })) throw new Error();
        if (!await this.canRead({ userId: user.id, email: user.email, role: toAuthRole(user.role), landlordId: user.staffProfile?.landlordId, propertyIds: user.staffProfile?.propertyScopes.map(scope => scope.propertyId), permissions: user.role === 'ADMIN' ? user.adminProfile?.permissions : user.staffProfile?.permissions }, filename)) throw new Error();
      } catch { throw new NotFoundException(); }
    }
    try {
      const bytes = await readFile(join(this.directory, filename));
      const type = detectFile(bytes);
      if (!type) throw new Error();
      return { bytes, mime: type.mime };
    } catch { throw new NotFoundException(); }
  }
}
