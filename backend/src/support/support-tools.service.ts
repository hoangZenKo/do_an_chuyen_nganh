import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SupportTicket } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { SupportFeedbackDto, SupportLabelsDto, SupportMergeDto, SupportTemplateDto } from './support-tools.dto';

@Injectable()
export class SupportToolsService {
  constructor(private readonly prisma: PrismaService) {}

  private manage(actor: AuthUser, ticket: SupportTicket) {
    if (actor.role !== AuthRole.ADMIN || !actor.permissions?.includes('admin.support.manage') || !actor.permissions.includes('admin.support.read')) throw new ForbiddenException();
    if (ticket.assigneeId && ticket.assigneeId !== actor.userId && !actor.permissions.includes('admin.admins.manage')) throw new ForbiddenException();
  }

  private async ticket(tx: Prisma.TransactionClient, id: string, version: number) {
    await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
    const ticket = await tx.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException();
    if (ticket.version !== version) throw new ConflictException('Ticket đã thay đổi. Hãy tải lại.');
    return ticket;
  }

  async labels(actor: AuthUser, id: string, input: SupportLabelsDto) {
    return this.prisma.$transaction(async tx => {
      const ticket = await this.ticket(tx, id, input.version);
      this.manage(actor, ticket);
      if (ticket.mergedIntoId) throw new ConflictException('Ticket đã được gộp.');
      const data = await tx.supportTicket.update({ where: { id }, data: { labels: input.labels, version: { increment: 1 } } });
      await platformAudit(tx, actor, 'support.labels_updated', 'support_ticket', id, input.reason, { before: ticket.labels, after: input.labels });
      return { data };
    });
  }

  async feedback(actor: AuthUser, id: string, input: SupportFeedbackDto) {
    return this.prisma.$transaction(async tx => {
      const ticket = await this.ticket(tx, id, input.version);
      if (ticket.requesterId !== actor.userId) throw new NotFoundException();
      if (!['RESOLVED', 'CLOSED'].includes(ticket.status) || ticket.mergedIntoId || ticket.feedbackAt) throw new ConflictException('Chỉ đánh giá một lần sau khi ticket được giải quyết.');
      const data = await tx.supportTicket.update({ where: { id }, data: {
        feedbackRating: input.rating, feedbackComment: input.comment, feedbackAt: new Date(), version: { increment: 1 },
      }, select: { id: true, feedbackRating: true, feedbackAt: true, version: true } });
      await platformAudit(tx, actor, 'support.feedback_submitted', 'support_ticket', id, 'Requester submitted support feedback', { rating: input.rating });
      return { data };
    });
  }

  async merge(actor: AuthUser, id: string, input: SupportMergeDto) {
    if (id === input.targetId) throw new BadRequestException('Không thể gộp ticket vào chính nó.');
    return this.prisma.$transaction(async tx => {
      const ids = [id, input.targetId].sort();
      await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id IN (${Prisma.join(ids)}) ORDER BY id FOR UPDATE`;
      const source = await tx.supportTicket.findUnique({ where: { id } });
      const target = await tx.supportTicket.findUnique({ where: { id: input.targetId } });
      if (!source || !target) throw new NotFoundException();
      this.manage(actor, source); this.manage(actor, target);
      if (source.requesterId !== target.requesterId) throw new ConflictException('Chỉ gộp ticket cùng người yêu cầu.');
      if (source.version !== input.version || target.version !== input.targetVersion || source.mergedIntoId || target.mergedIntoId ||
        ['RESOLVED', 'CLOSED'].includes(source.status) || ['RESOLVED', 'CLOSED'].includes(target.status)) throw new ConflictException('Ticket đã đổi hoặc đã đóng.');
      await tx.supportMessage.updateMany({ where: { ticketId: id }, data: { ticketId: target.id } });
      await tx.supportAttachment.updateMany({ where: { ticketId: id }, data: { ticketId: target.id } });
      await tx.supportTicket.update({ where: { id }, data: { status: 'CLOSED', resolvedAt: new Date(), mergedIntoId: target.id, version: { increment: 1 } } });
      const data = await tx.supportTicket.update({ where: { id: target.id }, data: { version: { increment: 1 } } });
      await platformAudit(tx, actor, 'support.tickets_merged', 'support_ticket', id, input.reason, { targetId: target.id });
      return { data: { id, mergedIntoId: target.id, targetVersion: data.version } };
    });
  }

  async templates() {
    return { data: await this.prisma.supportTemplate.findMany({ orderBy: { title: 'asc' }, take: 100 }) };
  }

  async saveTemplate(actor: AuthUser, input: SupportTemplateDto, id?: string) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102570)::text`;
      if (id) {
        const current = await tx.supportTemplate.findUnique({ where: { id } });
        if (!current) throw new NotFoundException();
        if (current.version !== input.version) throw new ConflictException('Mẫu đã thay đổi.');
      }
      if (await tx.supportTemplate.findFirst({ where: { title: input.title, ...(id ? { id: { not: id } } : {}) } })) throw new ConflictException('Tên mẫu đã tồn tại.');
      const fields = { title: input.title, body: input.body, isActive: input.isActive, updatedById: actor.userId };
      const data = id
        ? await tx.supportTemplate.update({ where: { id }, data: { ...fields, version: { increment: 1 } } })
        : await tx.supportTemplate.create({ data: fields });
      await platformAudit(tx, actor, 'support.template_saved', 'support_template', data.id, input.reason, { version: data.version, isActive: data.isActive });
      return { data };
    });
  }
}
