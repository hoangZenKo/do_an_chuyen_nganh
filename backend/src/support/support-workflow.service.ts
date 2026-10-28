import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { slaClockTransition } from './business-calendar';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { PlatformNotificationService } from './platform-notification.service';
import { SupportAutoAssignDto, SupportSkillDto, SupportViewDto } from './support-workflow.dto';

@Injectable()
export class SupportWorkflowService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: PlatformNotificationService) {}

  async views(actor: AuthUser) {
    return { data: await this.prisma.supportSavedView.findMany({ where: { ownerId: actor.userId }, orderBy: { name: 'asc' }, take: 50 }) };
  }

  async saveView(actor: AuthUser, input: SupportViewDto, id?: string) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${actor.userId} FOR UPDATE`;
      const filters = JSON.parse(JSON.stringify(input.filters)) as Prisma.InputJsonValue;
      if (id) {
        const current = await tx.supportSavedView.findFirst({ where: { id, ownerId: actor.userId } });
        if (!current) throw new NotFoundException();
        if (!input.version || current.version !== input.version) throw new ConflictException('View changed; reload before saving.');
      } else if (await tx.supportSavedView.count({ where: { ownerId: actor.userId } }) >= 50) {
        throw new ConflictException('Maximum 50 saved views.');
      }
      const duplicate = await tx.supportSavedView.findFirst({ where: { ownerId: actor.userId, name: input.name, ...(id ? { id: { not: id } } : {}) } });
      if (duplicate) throw new ConflictException('View name already exists.');
      const data = id ? await tx.supportSavedView.update({ where: { id }, data: { name: input.name, filters, version: { increment: 1 } } })
        : await tx.supportSavedView.create({ data: { ownerId: actor.userId, name: input.name, filters } });
      return { data };
    });
  }

  async deleteView(actor: AuthUser, id: string, version: number) {
    const result = await this.prisma.supportSavedView.deleteMany({ where: { id, ownerId: actor.userId, version } });
    if (!result.count) throw new ConflictException('View missing or changed.');
    return { data: { deleted: true } };
  }

  async skills() {
    return { data: await this.prisma.supportAgentSkill.findMany({ include: { user: { select: { id: true, fullName: true } } }, orderBy: [{ userId: 'asc' }, { category: 'asc' }], take: 700 }) };
  }

  async setSkills(actor: AuthUser, userId: string, input: SupportSkillDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102601)::text`;
      const user = await tx.user.findFirst({ where: { id: userId, role: 'ADMIN', isActive: true,
        adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage'] } } } });
      if (!user) throw new NotFoundException('Active support agent required.');
      await tx.supportAgentSkill.deleteMany({ where: { userId } });
      await tx.supportAgentSkill.createMany({ data: input.categories.map(category => ({ userId, category, maxOpen: input.maxOpen })) });
      await platformAudit(tx, actor, 'support.skills_updated', 'user', userId, input.reason, { categories: input.categories, maxOpen: input.maxOpen });
      return { data: { userId, categories: input.categories, maxOpen: input.maxOpen } };
    });
  }

  async autoAssign(actor: AuthUser, id: string, input: SupportAutoAssignDto) {
    if (!actor.permissions?.includes('admin.admins.manage')) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      const data = await this.assignAvailable(tx, actor, id, input.version, input.teamId, input.reason);
      if (!data) throw new ConflictException('No eligible agent has remaining capacity.');
      return { data };
    });
  }

  async assignAvailable(tx: Prisma.TransactionClient, actor: AuthUser, id: string, version: number, teamId?: string, reason = 'Automatic skill and workload assignment') {
    await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102601)::text`;
    await tx.$queryRaw`SELECT id FROM "SupportTicket" WHERE id = ${id} FOR UPDATE`;
    const ticket = await tx.supportTicket.findUnique({ where: { id } });
    if (!ticket) throw new NotFoundException();
    if (ticket.version !== version || ticket.assigneeId || ticket.mergedIntoId || ['RESOLVED', 'CLOSED'].includes(ticket.status)) throw new ConflictException('Ticket changed or already assigned.');
    const selectedTeam = teamId ?? ticket.teamId;
    if (selectedTeam && !await tx.adminTeam.findFirst({ where: { id: selectedTeam, isActive: true } })) throw new ConflictException('Team is inactive.');
    const skills = await tx.supportAgentSkill.findMany({ where: { category: ticket.category,
      user: { role: 'ADMIN', isActive: true, adminProfile: { permissions: { hasEvery: ['admin.support.read', 'admin.support.manage'] } },
        ...(selectedTeam ? { adminTeamMemberships: { some: { teamId: selectedTeam } } } : {}) } }, orderBy: { userId: 'asc' } });
    const workloads = await tx.supportTicket.groupBy({ by: ['assigneeId'], where: { assigneeId: { in: skills.map(skill => skill.userId) }, status: { notIn: ['RESOLVED', 'CLOSED'] } }, _count: true });
    const counts = new Map(workloads.map(row => [row.assigneeId, row._count]));
    const candidate = skills.filter(skill => (counts.get(skill.userId) ?? 0) < skill.maxOpen)
      .sort((left, right) => (counts.get(left.userId) ?? 0) - (counts.get(right.userId) ?? 0) || left.userId.localeCompare(right.userId))[0];
    if (!candidate) return null;
    const data = await tx.supportTicket.update({ where: { id }, data: { assigneeId: candidate.userId, teamId: selectedTeam, status: 'IN_PROGRESS', ...slaClockTransition(ticket, 'IN_PROGRESS'), version: { increment: 1 } } });
    await this.notifications.create(tx, { userId: candidate.userId, eventKey: `support-assigned:${id}:${data.version}`, kind: 'SUPPORT_ASSIGNMENT', title: 'Ticket assigned', body: 'Open Support Center to review.', actionPath: `/admin/tickets?ticketId=${id}` });
    await platformAudit(tx, actor, 'support.auto_assigned', 'support_ticket', id, reason, { assigneeId: candidate.userId, workload: counts.get(candidate.userId) ?? 0 });
    return data;
  }
}
