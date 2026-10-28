import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { RegistryPageDto, ReviewRegistryDto, SubmitVerificationDto } from './admin-registry.dto';

const verificationSelect = { id: true, landlordId: true, ticketId: true, status: true, version: true,
  reviewNote: true, reviewerId: true, reviewedAt: true, submittedAt: true, updatedAt: true } as const;

@Injectable()
export class AdminVerificationService {
  constructor(private readonly prisma: PrismaService) {}

  async own(landlordId: string) {
    const data = await this.prisma.landlordVerification.findUnique({ where: { landlordId }, select: {
      status: true, version: true, ticketId: true, submittedAt: true, reviewedAt: true,
    } });
    return { data };
  }

  async list(query: RegistryPageDto) {
    const where = query.status ? { status: query.status } : {};
    return this.prisma.$transaction(async tx => {
      const [data, total] = await Promise.all([
        tx.landlordVerification.findMany({ where, select: verificationSelect, orderBy: [{ submittedAt: 'desc' }, { id: 'asc' }],
          skip: (query.page - 1) * query.limit, take: query.limit }),
        tx.landlordVerification.count({ where }),
      ]);
      return { data, meta: { page: query.page, limit: query.limit, total } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async submit(actor: AuthUser, input: SubmitVerificationDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${input.landlordId} FOR UPDATE`;
      const owner = await tx.user.findFirst({ where: { id: input.landlordId, role: 'LANDLORD', isActive: true }, select: { id: true } });
      if (!owner) throw new NotFoundException('Active landlord not found.');
      const ticket = await tx.supportTicket.findFirst({ where: { id: input.ticketId, requesterId: input.landlordId, mergedIntoId: null },
        select: { id: true, attachments: { where: { internal: false, file: { purpose: 'SUPPORT_CLEAN' } }, select: { id: true }, take: 1 } } });
      if (!ticket?.attachments.length) throw new BadRequestException('Use an owner support ticket with scanned private evidence.');
      const before = await tx.landlordVerification.findUnique({ where: { landlordId: input.landlordId } });
      if ((before?.version ?? 0) !== input.version || (before && !['NEEDS_INFO', 'REJECTED'].includes(before.status))) {
        throw new ConflictException('Request already submitted or changed. Reload before resubmitting.');
      }
      const data = before
        ? await tx.landlordVerification.update({ where: { id: before.id }, data: { ticketId: input.ticketId, status: 'PENDING',
          version: { increment: 1 }, reviewNote: '', reviewerId: null, reviewedAt: null, submittedAt: new Date() }, select: verificationSelect })
        : await tx.landlordVerification.create({ data: { landlordId: input.landlordId, ticketId: input.ticketId }, select: verificationSelect });
      await platformAudit(tx, actor, 'admin.verification_submit', 'landlord_verification', data.id, input.reason,
        { before: before ? { status: before.status, version: before.version } : null, after: { status: data.status, version: data.version, ticketId: input.ticketId } });
      return { data };
    });
  }

  async review(actor: AuthUser, id: string, input: ReviewRegistryDto) {
    return this.prisma.$transaction(async tx => {
      const identity = await tx.landlordVerification.findUnique({ where: { id }, select: { landlordId: true, ticketId: true } });
      if (!identity) throw new NotFoundException();
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${identity.landlordId} FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${identity.ticketId} FOR UPDATE`;
      await tx.$queryRaw`SELECT f.filename FROM "UploadedFile" f JOIN "SupportAttachment" a ON a.filename = f.filename
        WHERE a."ticketId" = ${identity.ticketId} FOR SHARE OF a, f`;
      const before = await tx.landlordVerification.findUnique({ where: { id }, include: {
        landlord: { select: { isActive: true } }, ticket: { select: { requesterId: true, mergedIntoId: true,
          attachments: { where: { internal: false }, select: { id: true, sha256: true, file: { select: { purpose: true } } } } } },
      } });
      if (!before) throw new NotFoundException();
      if (before.ticketId !== identity.ticketId) throw new ConflictException('Verification evidence changed. Reload.');
      if (before.landlordId === actor.userId) throw new ForbiddenException('Cannot review your own request.');
      if (before.version !== input.version || before.status !== 'PENDING') throw new ConflictException('Verification changed or is no longer pending.');
      if (input.status === 'APPROVED' && (!before.landlord.isActive || before.ticket.requesterId !== before.landlordId ||
        before.ticket.mergedIntoId || !before.ticket.attachments.length || before.ticket.attachments.some(file => file.file.purpose !== 'SUPPORT_CLEAN'))) {
        throw new BadRequestException('Active owner and scanned owner evidence are required for approval.');
      }
      const reviewedAt = new Date();
      const updated = await tx.landlordVerification.updateMany({ where: { id, version: input.version, status: 'PENDING' }, data: {
        status: input.status, version: { increment: 1 }, reviewerId: actor.userId, reviewedAt, reviewNote: input.reason,
      } });
      if (updated.count !== 1) throw new ConflictException('Verification changed. Reload.');
      await platformAudit(tx, actor, 'admin.verification_review', 'landlord_verification', id, input.reason, {
        before: { status: before.status, version: before.version }, after: { status: input.status, version: input.version + 1 },
        evidence: before.ticket.attachments.map(file => ({ id: file.id, sha256: file.sha256 })),
      } as Prisma.InputJsonValue);
      return { data: { id, landlordId: before.landlordId, ticketId: before.ticketId, status: input.status,
        version: input.version + 1, reviewerId: actor.userId, reviewedAt, reviewNote: input.reason } };
    });
  }
}
