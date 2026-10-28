import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from '../admin/admin-audit';
import type { IncidentQuery } from './incident-workflow.controller';
import { Prisma } from '@prisma/client';

export type IncidentAction = 'ACKNOWLEDGE' | 'ASSIGN' | 'SNOOZE' | 'RESOLVE' | 'REOPEN';

@Injectable()
export class IncidentWorkflowService {
  constructor(private readonly prisma: PrismaService) {}

  async assignees() {
    return { data: await this.prisma.user.findMany({ where: { role: 'ADMIN', isActive: true, adminProfile: { permissions: { hasEvery: ['admin.operations.view', 'admin.operations.manage'] } } }, select: { id: true, fullName: true }, orderBy: [{ fullName: 'asc' }, { id: 'asc' }], take: 100 }) };
  }

  async list(actor: AuthUser, query: IncidentQuery) {
    const windowMs = { '24h': 86400000, '7d': 7 * 86400000, '30d': 30 * 86400000 }[query.window ?? ''] ?? null;
    const where: Prisma.OperationsIncidentWhereInput = { AND: [
      ...(query.status ? [{ status: query.status }] : []),
      ...(query.ownerId ? [{ ownerId: query.ownerId }] : []),
      ...(query.severity ? [{ severity: query.severity }] : []),
      ...(query.assignment === 'mine' ? [{ ownerId: actor.userId }] : []),
      ...(query.assignment === 'unassigned' ? [{ ownerId: null }] : []),
      ...(windowMs ? [{ lastSeenAt: { gte: new Date(Date.now() - windowMs) } }] : []),
      ...(query.search?.trim() ? [{ OR: [{ title: { contains: query.search.trim(), mode: 'insensitive' as const } }, { key: { contains: query.search.trim(), mode: 'insensitive' as const } }] }] : []),
    ] };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.operationsIncident.count({ where }),
      this.prisma.operationsIncident.findMany({ where, orderBy: [{ lastSeenAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data, meta: { total, page: query.page, limit: query.limit } };
  }

  async detail(id: string) {
    const incident = await this.prisma.operationsIncident.findUnique({ where: { id } });
    if (!incident) throw new NotFoundException();
    const history = await this.prisma.auditLog.findMany({ where: { resourceType: 'incident', resourceId: id }, select: { id: true, action: true, actorId: true, summary: true, createdAt: true }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 50 });
    const runbook = incident.key.startsWith('WORKER_') ? 'Kiểm tra heartbeat và log worker; khôi phục cấu hình trước khi retry job idempotent.'
      : incident.key.includes('DELIVERY') || incident.key.includes('NOTIFICATION') ? 'Kiểm tra provider và preference; sửa nguyên nhân rồi retry từng job, không replay hàng loạt.'
      : incident.key.includes('SLA') || incident.key.includes('OVERDUE') ? 'Mở hàng đợi quá hạn, kiểm tra scope và phân công cho người còn quyền xử lý.'
      : 'Tra cứu requestId và metric; không chép token, secret hoặc dữ liệu cá nhân vào hồ sơ sự cố.';
    return { data: { ...incident, history, runbook, runbookPath: 'docs/admin-release-gate-runbook.md#incident-and-job-recovery' } };
  }

  async transition(actor: AuthUser, id: string, input: { action: IncidentAction; version: number; reason: string; ownerId?: string; snoozedUntil?: string }) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "OperationsIncident" WHERE id = ${id} FOR UPDATE`;
      const current = await tx.operationsIncident.findUnique({ where: { id } });
      if (!current) throw new NotFoundException();
      if (current.version !== input.version) throw new ConflictException('Sự cố đã thay đổi. Hãy tải lại.');
      const values: { status?: string; ownerId?: string; acknowledgedBy?: string | null; snoozedUntil?: Date | null; resolvedAt?: Date | null; resolutionNote?: string | null; resolvedBy?: string | null } = {};
      if (input.action === 'REOPEN') {
        if (current.status !== 'RESOLVED') throw new ConflictException('Chỉ mở lại sự cố đã đóng.');
        Object.assign(values, { status: 'OPEN', resolvedAt: null, resolvedBy: null, resolutionNote: null, acknowledgedBy: null, snoozedUntil: null });
      } else {
        if (current.status === 'RESOLVED') throw new ConflictException('Sự cố đã đóng. Mở lại trước khi xử lý.');
        if (input.action === 'ACKNOWLEDGE') {
          if (current.status !== 'OPEN') throw new ConflictException('Sự cố đã được tiếp nhận.');
          Object.assign(values, { status: 'ACKNOWLEDGED', acknowledgedBy: actor.userId });
        } else if (input.action === 'ASSIGN') {
          if (!input.ownerId) throw new BadRequestException('Chọn người phụ trách.');
          const eligible = await tx.user.findFirst({ where: { id: input.ownerId, isActive: true, role: 'ADMIN', adminProfile: { permissions: { hasEvery: ['admin.operations.view', 'admin.operations.manage'] } } }, select: { id: true } });
          if (!eligible) throw new BadRequestException('Người phụ trách không còn quyền vận hành.');
          Object.assign(values, { ownerId: input.ownerId });
        } else if (input.action === 'SNOOZE') {
          const until = new Date(input.snoozedUntil ?? '');
          if (!Number.isFinite(until.getTime()) || until.getTime() <= Date.now() || until.getTime() > Date.now() + 24 * 3600000) throw new BadRequestException('Chỉ tạm hoãn tối đa 24 giờ.');
          Object.assign(values, { status: 'SNOOZED', snoozedUntil: until });
        } else if (input.action === 'RESOLVE') {
          if (current.conditionActive) throw new ConflictException('Điều kiện lỗi vẫn còn. Không thể đóng sự cố bằng tay.');
          Object.assign(values, { status: 'RESOLVED', resolvedAt: new Date(), resolvedBy: actor.userId, resolutionNote: input.reason, snoozedUntil: null });
        }
      }
      const data = await tx.operationsIncident.update({ where: { id }, data: { ...values, version: { increment: 1 } } });
      await adminAudit(tx, actor, `admin.incident_${input.action.toLowerCase()}`, 'incident', id, input.reason, { before: { status: current.status, ownerId: current.ownerId }, after: { status: data.status, ownerId: data.ownerId, snoozedUntil: data.snoozedUntil?.toISOString() ?? null }, version: data.version });
      return { data };
    });
  }
}
