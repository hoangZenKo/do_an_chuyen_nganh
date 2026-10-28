import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { AdminAuditExportDto, AdminAuditQuery } from './admin-console.dto';
import { adminAudit } from './admin-audit';

export function auditWhere(query: AdminAuditQuery): Prisma.AuditLogWhereInput {
  if (query.from && query.to && new Date(query.from) > new Date(query.to)) throw new BadRequestException('Khoảng thời gian không hợp lệ.');
  return {
    ...(query.actorId ? { actorId: query.actorId } : {}), ...(query.action ? { action: query.action } : {}),
    ...(query.resourceId ? { resourceId: query.resourceId } : {}), ...(query.resourceType ? { resourceType: query.resourceType } : {}),
    ...(query.landlordId ? { landlordId: query.landlordId } : {}), ...(query.requestId ? { requestId: query.requestId } : {}),
    ...(query.search ? { OR: [{ summary: { contains: query.search, mode: 'insensitive' } }, { action: { contains: query.search, mode: 'insensitive' } }] } : {}),
    ...(query.from || query.to ? { createdAt: { ...(query.from ? { gte: new Date(query.from) } : {}), ...(query.to ? { lte: new Date(query.to) } : {}) } } : {}),
  };
}

export function auditMetadata(value: unknown, depth = 0): unknown {
  if (depth > 6) return '[truncated]';
  if (Array.isArray(value)) return value.slice(0, 50).map(item => auditMetadata(item, depth + 1));
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).slice(0, 100)
    .map(([key, item]) => [key, /password|secret|token|email|phone|document|attachment|authorization|cookie|url/i.test(key) ? '[redacted]' : auditMetadata(item, depth + 1)]));
  return typeof value === 'string' ? value.slice(0, 2000) : value;
}

export function csvCell(value: unknown) {
  const raw = value instanceof Date ? value.toISOString() : String(value ?? '');
  const safe = /^[\s]*[=+\-@]|^[\t\r\n]/.test(raw) ? `'${raw}` : raw;
  return `"${safe.replace(/"/g, '""')}"`;
}

@Injectable()
export class AdminAuditQueryService {
  constructor(private readonly prisma: PrismaService) {}

  async detail(actor: AuthUser, id: string) {
    return this.prisma.$transaction(async tx => {
      const row = await tx.auditLog.findUnique({ where: { id } });
      if (!row) throw new NotFoundException();
      await adminAudit(tx, actor, 'admin.audit_detail_read', 'audit', id, 'Viewed redacted audit detail');
      return { data: { id: row.id, actorId: row.actorId, actorRole: row.actorRole, landlordId: row.landlordId,
        action: row.action, resourceType: row.resourceType, resourceId: row.resourceId, summary: row.summary,
        requestId: row.requestId, metadata: auditMetadata(row.metadata), createdAt: row.createdAt } };
    });
  }

  async export(actor: AuthUser, input: AdminAuditExportDto) {
    if (!input.from || !input.to || new Date(input.to).getTime() - new Date(input.from).getTime() > 31 * 86400000) {
      throw new BadRequestException('Chọn khoảng thời gian xuất tối đa 31 ngày.');
    }
    const where = auditWhere(input);
    return this.prisma.$transaction(async tx => {
      const rows = await tx.auditLog.findMany({ where, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }], take: 5001,
        select: { id: true, createdAt: true, actorId: true, actorRole: true, action: true, resourceType: true, resourceId: true, summary: true, requestId: true } });
      if (rows.length > 5000) throw new BadRequestException('Có hơn 5.000 bản ghi. Thu hẹp bộ lọc để xuất đủ dữ liệu.');
      await adminAudit(tx, actor, 'admin.audit_export', 'audit', actor.userId, input.reason,
        { from: input.from!, to: input.to!, rows: rows.length });
      const columns = ['id', 'createdAt', 'actorId', 'actorRole', 'action', 'resourceType', 'resourceId', 'summary', 'requestId'] as const;
      return '\uFEFF' + [columns.map(csvCell).join(','), ...rows.map(row => columns.map(column => csvCell(row[column])).join(','))].join('\r\n');
    }, { isolationLevel: 'RepeatableRead' });
  }
}
