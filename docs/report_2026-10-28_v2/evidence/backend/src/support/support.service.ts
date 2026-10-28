import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, SupportTicket } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { FeatureFlagsService } from '../platform/feature-flags.service';
import { PlatformNotificationService } from './platform-notification.service';
import { SupportWorkflowService } from './support-workflow.service';
import { slaClockTransition, slaDeadlines, SupportSlaSnapshot } from './business-calendar';
import { SupportSlaService } from './support-sla.service';
import { supportSlaWhere } from './support-inbox';
import { CreateSupportTicketDto, SupportAssignmentDto, SupportNoteDto, SupportPageDto, SupportReplyDto, SupportStatusDto } from './support.dto';

const isSupport = (actor: AuthUser) => actor.role === AuthRole.ADMIN && actor.permissions?.includes('admin.support.read') === true;
const supervisors = (actor: AuthUser) => actor.permissions?.includes('admin.admins.manage') === true;
const identity = { id: true, fullName: true } as const;
export function supportDeadlines(priority: string, now = Date.now()) {
  const [response, resolution] = ({ URGENT: [1, 12], HIGH: [4, 24], NORMAL: [24, 72], LOW: [48, 120] } as Record<string, number[]>)[priority] ?? [24, 72];
  return { firstResponseDueAt: new Date(now + response * 3600000), resolutionDueAt: new Date(now + resolution * 3600000) };
}

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: PlatformNotificationService,
    private readonly flags: FeatureFlagsService, private readonly workflow: SupportWorkflowService, private readonly sla: SupportSlaService) {}

  private manage(actor: AuthUser, ticket?: SupportTicket) {
    if (!isSupport(actor) || !actor.permissions?.includes('admin.support.manage')) throw new ForbiddenException();
    if (ticket?.assigneeId && ticket.assigneeId !== actor.userId && !supervisors(actor)) throw new ForbiddenException('Ticket đang do admin khác xử lý.');
  }
  private async locked(tx: Prisma.TransactionClient, id: string, version: number) {
    await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
    const ticket = await tx.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException();
    if (ticket.version !== version) throw new ConflictException('Ticket đã thay đổi. Hãy tải lại.');
    return ticket;
  }
  async assignees() {
    return { data: await this.prisma.user.findMany({ where: { role: 'ADMIN', isActive: true,
      adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage'] } } }, select: identity, take: 100, orderBy: { fullName: 'asc' } }) };
  }
  async teams() {
    return { data: await this.prisma.adminTeam.findMany({ where: { isActive: true }, select: { id: true, name: true }, orderBy: { name: 'asc' }, take: 100 }) };
  }
  async create(actor: AuthUser, input: CreateSupportTicketDto) {
    await this.flags.require('support.user_tickets', actor);
    const priority = isSupport(actor) && actor.permissions?.includes('admin.support.manage') ? input.priority : 'NORMAL';
    const snapshot = await this.sla.snapshot();
    return this.prisma.$transaction(async tx => {
      const ticket = await tx.supportTicket.create({ data: { requesterId: actor.userId, subject: input.subject,
        category: input.category, priority, ...slaDeadlines(priority, new Date(), snapshot), ...(snapshot ? { slaSnapshot: snapshot as unknown as Prisma.InputJsonValue } : {}),
        messages: { create: { authorId: actor.userId, authorRole: actor.role.toUpperCase(), body: input.body } } } });
      const recipients = await tx.user.findMany({ where: { role: 'ADMIN', isActive: true,
        adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage', 'admin.notifications.view'] } } }, select: { id: true }, take: 100 });
      for (const recipient of recipients) await this.notifications.create(tx, { userId: recipient.id, eventKey: `support-created:${ticket.id}`, kind: 'SUPPORT_NEW',
        title: 'Có yêu cầu hỗ trợ mới', body: 'Một ticket mới đang chờ phân công.', actionPath: `/admin/tickets?ticketId=${ticket.id}` });
      await platformAudit(tx, actor, 'support.ticket_created', 'support_ticket', ticket.id, 'Created support ticket', { category: input.category });
      const assigned = await this.workflow.assignAvailable(tx, actor, ticket.id, ticket.version);
      return { data: assigned ?? ticket };
    });
  }
  async list(actor: AuthUser, query: SupportPageDto) {
    const now = new Date();
    const where: Prisma.SupportTicketWhereInput = { ...(!isSupport(actor) ? { requesterId: actor.userId } : {}),
      AND: [
        { mergedIntoId: null },
        ...(query.search ? [{ OR: [{ subject: { contains: query.search, mode: 'insensitive' as const } },
          { messages: { some: { body: { contains: query.search, mode: 'insensitive' as const }, ...(!isSupport(actor) ? { internal: false } : {}) } } }] }] : []),
        ...(isSupport(actor) && query.label ? [{ labels: { has: query.label } }] : []),
        ...(isSupport(actor) && query.teamId ? [{ teamId: query.teamId }] : []),
        ...(isSupport(actor) && query.assigneeId ? [{ assigneeId: query.assigneeId }] : []),
        ...(isSupport(actor) && query.priority ? [{ priority: query.priority }] : []),
        ...(query.category ? [{ category: query.category }] : []),
        ...(query.assignment === 'overdue' ? [supportSlaWhere('overdue', now)] : []),
        supportSlaWhere(query.sla ?? 'all', now),
      ],
      ...(query.status ? { status: query.status } : {}),
      ...(isSupport(actor) && query.assignment === 'mine' ? { assigneeId: actor.userId } : {}),
      ...(isSupport(actor) && query.assignment === 'unassigned' ? { assigneeId: null } : {}),
    };
    const orderBy: Prisma.SupportTicketOrderByWithRelationInput[] = query.sort === 'oldest' ? [{ createdAt: 'asc' }, { id: 'asc' }]
      : query.sort === 'resolution_due' ? [{ resolutionDueAt: 'asc' }, { id: 'asc' }] : [{ updatedAt: 'desc' }, { id: 'asc' }];
    const [total, data] = await this.prisma.$transaction([
      this.prisma.supportTicket.count({ where }),
      this.prisma.supportTicket.findMany({ where, include: { requester: { select: identity }, assignee: { select: identity } },
        orderBy, skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data: data.map(ticket => isSupport(actor) ? ticket : { ...ticket, labels: [], teamId: null }), meta: { page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) } };
  }
  async detail(actor: AuthUser, id: string, page = 1) {
    const ticket = await this.prisma.supportTicket.findFirst({ where: { id, ...(!isSupport(actor) ? { requesterId: actor.userId } : {}) },
      include: { requester: { select: identity }, assignee: { select: identity }, attachments: { where: !isSupport(actor) ? { internal: false } : {},
        select: { id: true, filename: true, internal: true, size: true, createdAt: true, file: { select: { mimeType: true } } }, orderBy: { createdAt: 'asc' } } } });
    if (!ticket) throw new NotFoundException();
    const where = { ticketId: id, ...(!isSupport(actor) ? { internal: false } : {}) };
    const [total, messages] = await this.prisma.$transaction([
      this.prisma.supportMessage.count({ where }),
      this.prisma.supportMessage.findMany({ where, include: { author: { select: identity } },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * 50, take: 50 }),
    ]);
    return { data: { ...ticket, ...(!isSupport(actor) ? { teamId: null, labels: [] } : {}), messages: messages.reverse() }, messageMeta: { total, page, pages: Math.ceil(total / 50) } };
  }
  async reply(actor: AuthUser, id: string, input: SupportReplyDto, internal = false) {
    return this.prisma.$transaction(async tx => {
      const ticket = await this.locked(tx, id, input.version);
      const publicOwner = ticket.requesterId === actor.userId;
      if (!publicOwner && !isSupport(actor)) throw new NotFoundException();
      if (!publicOwner || internal) this.manage(actor, ticket);
      if (ticket.status === 'CLOSED') throw new ConflictException('Ticket đã đóng. Tạo ticket mới để tiếp tục.');
      const reopened = ticket.status === 'RESOLVED' && publicOwner && !internal;
      if (reopened && ticket.resolvedAt && Date.now() - ticket.resolvedAt.getTime() > 7 * 86400000) throw new ConflictException('Hết hạn mở lại 7 ngày. Tạo ticket mới để tiếp tục.');
      const status = internal ? ticket.status : publicOwner ? (ticket.assigneeId ? 'IN_PROGRESS' : 'OPEN') : 'WAITING_FOR_USER';
      const updated = await tx.supportTicket.update({ where: { id }, data: {
        status, ...(!internal ? slaClockTransition(ticket, status) : {}),
        firstRespondedAt: !internal && !publicOwner && !ticket.firstRespondedAt ? new Date() : ticket.firstRespondedAt,
        ...(reopened ? { resolvedAt: null } : {}), version: { increment: 1 },
        messages: { create: { authorId: actor.userId, authorRole: actor.role.toUpperCase(), body: input.body, internal } } } });
      const recipient = publicOwner ? ticket.assigneeId : ticket.requesterId;
      if (recipient && !internal) await this.notifications.create(tx, { userId: recipient, eventKey: `support-reply:${id}:${updated.version}`, kind: 'SUPPORT_REPLY', title: 'Có phản hồi hỗ trợ mới', body: 'Mở ticket để xem phản hồi.', actionPath: publicOwner ? `/admin/tickets?ticketId=${id}` : `/support-center?ticketId=${id}` });
      await platformAudit(tx, actor, internal ? 'support.internal_note_added' : 'support.reply_added', 'support_ticket', id, internal ? 'Added internal support note' : 'Added public support reply', { version: updated.version });
      return { data: updated };
    });
  }
  async assign(actor: AuthUser, id: string, input: SupportAssignmentDto) {
    this.manage(actor);
    return this.prisma.$transaction(async tx => {
      const ticket = await this.locked(tx, id, input.version);
      if (!supervisors(actor) && (ticket.assigneeId && ticket.assigneeId !== actor.userId || input.assigneeId !== actor.userId)) throw new ForbiddenException('Chỉ được nhận ticket cho chính mình.');
      if (['RESOLVED', 'CLOSED'].includes(ticket.status)) throw new ConflictException('Ticket đã kết thúc.');
      if (input.teamId && !await tx.adminTeam.findFirst({ where: { id: input.teamId, isActive: true } })) throw new NotFoundException('Nhóm không hoạt động.');
      if (input.assigneeId && !await tx.user.findFirst({ where: { id: input.assigneeId, role: 'ADMIN', isActive: true, adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage'] } }, ...(input.teamId ? { adminTeamMemberships: { some: { teamId: input.teamId } } } : {}) } })) throw new ConflictException('Admin phải có quyền hỗ trợ và thuộc nhóm được chọn.');
      const deadlines = slaDeadlines(input.priority, new Date(), ticket.slaSnapshot as unknown as SupportSlaSnapshot | null);
      const status = input.assigneeId ? 'IN_PROGRESS' : 'OPEN';
      const clock = slaClockTransition(ticket, status);
      const updated = await tx.supportTicket.update({ where: { id }, data: { assigneeId: input.assigneeId ?? null, teamId: input.teamId ?? null, priority: input.priority, status, ...clock, firstResponseDueAt: new Date(Math.min(ticket.firstResponseDueAt.getTime(), deadlines.firstResponseDueAt.getTime())), resolutionDueAt: new Date(Math.min(clock.resolutionDueAt.getTime(), deadlines.resolutionDueAt.getTime())), version: { increment: 1 } } });
      if (input.assigneeId) await this.notifications.create(tx, { userId: input.assigneeId, eventKey: `support-assigned:${id}:${updated.version}`, kind: 'SUPPORT_ASSIGNMENT', title: 'Ticket được giao cho bạn', body: 'Kiểm tra hạn phản hồi và xử lý.', actionPath: `/admin/tickets?ticketId=${id}` });
      await platformAudit(tx, actor, 'support.ticket_assigned', 'support_ticket', id, input.reason, { assigneeId: input.assigneeId ?? null, teamId: input.teamId ?? null, priority: input.priority, version: updated.version });
      return { data: updated };
    });
  }
  note(actor: AuthUser, id: string, input: SupportNoteDto) { return this.reply(actor, id, input, true); }
  async status(actor: AuthUser, id: string, input: SupportStatusDto) {
    return this.prisma.$transaction(async tx => {
      const ticket = await this.locked(tx, id, input.version);
      this.manage(actor, ticket);
      const allowed: Record<string, string[]> = { OPEN: ['IN_PROGRESS', 'RESOLVED'], IN_PROGRESS: ['WAITING_FOR_USER', 'RESOLVED'], WAITING_FOR_USER: ['IN_PROGRESS', 'RESOLVED'], RESOLVED: ['OPEN', 'CLOSED'], CLOSED: [] };
      if (!allowed[ticket.status].includes(input.status)) throw new ConflictException('Chuyển trạng thái không hợp lệ.');
      const data = await tx.supportTicket.update({ where: { id }, data: { status: input.status, ...slaClockTransition(ticket, input.status), resolvedAt: ['RESOLVED', 'CLOSED'].includes(input.status) ? new Date() : null, version: { increment: 1 }, messages: { create: { authorId: actor.userId, authorRole: actor.role.toUpperCase(), body: `${input.status}: ${input.reason}` } } } });
      await this.notifications.create(tx, { userId: ticket.requesterId, eventKey: `support-status:${id}:${data.version}`, kind: 'SUPPORT_STATUS', title: 'Ticket đã đổi trạng thái', body: input.status, actionPath: `/support-center?ticketId=${id}` });
      await platformAudit(tx, actor, 'support.ticket_status_changed', 'support_ticket', id, input.reason, { status: input.status, version: data.version });
      return { data };
    });
  }
}
