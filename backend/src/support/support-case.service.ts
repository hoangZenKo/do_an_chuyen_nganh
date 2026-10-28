import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from '../admin/admin-audit';

export type CaseResourceKind = 'PROPERTY' | 'ROOM' | 'LEASE' | 'INVOICE' | 'INCIDENT';

@Injectable()
export class SupportCaseService {
  constructor(private readonly prisma: PrismaService) {}

  private permission(actor: AuthUser, kind: CaseResourceKind) {
    const required = kind === 'INVOICE' ? 'admin.finance.read' : kind === 'INCIDENT' ? 'admin.operations.view'
      : ['PROPERTY', 'ROOM'].includes(kind) ? 'admin.properties.view' : 'admin.support.read';
    return actor.permissions?.includes(required) === true;
  }

  private async resource(tx: Prisma.TransactionClient, actor: AuthUser, requesterId: string, kind: CaseResourceKind, id: string) {
    if (!this.permission(actor, kind)) return null;
    if (kind === 'INCIDENT') return tx.operationsIncident.findUnique({ where: { id }, select: { id: true, title: true, status: true, severity: true } });
    const requester = await tx.user.findUnique({ where: { id: requesterId }, select: { id: true, role: true, staffProfile: { select: { landlordId: true } }, tenantProfile: { select: { id: true } } } });
    const ownerId = requester?.role === 'LANDLORD' ? requester.id : requester?.role === 'STAFF' ? requester.staffProfile?.landlordId : undefined;
    const tenantId = requester?.tenantProfile?.id;
    if (!ownerId && !tenantId) return null;
    const propertyScope: Prisma.PropertyWhereInput = ownerId ? { landlordId: ownerId } : { rooms: { some: { leases: { some: { tenantId } } } } };
    if (kind === 'PROPERTY') return tx.property.findFirst({ where: { id, ...propertyScope }, select: { id: true, name: true, isArchived: true } });
    if (kind === 'ROOM') return tx.room.findFirst({ where: { id, ...(ownerId ? { property: propertyScope } : { leases: { some: { tenantId } } }) }, select: { id: true, name: true, status: true, propertyId: true } });
    if (kind === 'LEASE') return tx.lease.findFirst({ where: { id, ...(ownerId ? { room: { property: propertyScope } } : { tenantId }) }, select: { id: true, status: true, roomId: true, startDate: true, endDate: true } });
    return tx.invoice.findFirst({ where: { id, ...(ownerId ? { room: { property: propertyScope } } : { tenantId }) }, select: { id: true, status: true, billingMonth: true, totalAmount: true, paidAmount: true } });
  }

  async timeline(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      const ticket = await tx.supportTicket.findUnique({ where: { id }, select: {
        id: true, requesterId: true, subject: true, status: true, version: true, firstResponseDueAt: true, resolutionDueAt: true, firstRespondedAt: true, slaPausedAt: true,
        requester: { select: { id: true, fullName: true, role: true, isActive: true } },
        caseLinks: { orderBy: { createdAt: 'asc' }, take: 50 },
        escalations: { orderBy: { createdAt: 'desc' }, take: 30, select: { id: true, kind: true, level: true, deadlineAt: true, createdAt: true } },
      } });
      if (!ticket) throw new NotFoundException();
      const links = [];
      for (const link of ticket.caseLinks) {
        const resource = await this.resource(tx, actor, ticket.requesterId, link.kind as CaseResourceKind, link.targetId);
        if (resource) links.push({ id: link.id, kind: link.kind, targetId: link.targetId, resource, createdAt: link.createdAt });
      }
      const [activity, relatedTickets] = await Promise.all([
        tx.auditLog.findMany({ where: { resourceType: 'support_ticket', resourceId: id, action: { not: 'admin.support_timeline_read' } }, select: { id: true, action: true, summary: true, actorId: true, createdAt: true }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 50 }),
        tx.supportTicket.findMany({ where: { requesterId: ticket.requesterId, id: { not: id } }, select: { id: true, subject: true, status: true, createdAt: true }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 10 }),
      ]);
      await adminAudit(tx, actor, 'admin.support_timeline_read', 'support_ticket', id, reason, { linkedResourcesReturned: links.length });
      const { caseLinks, ...safe } = ticket;
      return { data: { ...safe, links, activity, relatedTickets, activityLimit: 50, relatedTicketLimit: 10 } };
    }, { isolationLevel: 'RepeatableRead', timeout: 15000 });
  }

  async link(actor: AuthUser, id: string, input: { kind: CaseResourceKind; targetId: string; version: number; reason: string }) {
    if (!this.permission(actor, input.kind)) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
      const ticket = await tx.supportTicket.findUnique({ where: { id } });
      if (!ticket) throw new NotFoundException();
      if (ticket.version !== input.version || ticket.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(ticket.status)) throw new ConflictException('Hồ sơ đã thay đổi hoặc đã đóng.');
      if (ticket.assigneeId && ticket.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) throw new ForbiddenException();
      const resource = await this.resource(tx, actor, ticket.requesterId, input.kind, input.targetId);
      if (!resource) throw new NotFoundException('Resource không thuộc người gửi ticket hoặc không còn truy cập được.');
      const existing = await tx.supportCaseLink.findUnique({ where: { ticketId_kind_targetId: { ticketId: id, kind: input.kind, targetId: input.targetId } } });
      if (existing) return { data: existing, duplicate: true };
      if (await tx.supportCaseLink.count({ where: { ticketId: id } }) >= 50) throw new ConflictException('Tối đa 50 liên kết cho mỗi hồ sơ.');
      const data = await tx.supportCaseLink.create({ data: { ticketId: id, kind: input.kind, targetId: input.targetId, createdById: actor.userId } });
      await tx.supportTicket.update({ where: { id }, data: { version: { increment: 1 } } });
      await adminAudit(tx, actor, 'support.case_resource_linked', 'support_ticket', id, input.reason, { kind: input.kind, targetId: input.targetId });
      return { data };
    });
  }
}
