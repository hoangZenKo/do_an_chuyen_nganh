import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { adminPermissionForWork } from '../common/admin-permissions';
import { pendingModerationSql } from '../common/moderation-queue.sql';
import { PrismaService } from '../prisma/prisma.service';
import { AdminWorkspaceQuery } from './admin-workspace.dto';
import { supportSlaWhere } from '../support/support-inbox';

interface WorkspaceSource {
  key: string;
  label: string;
  route: string;
  actionPath?: string;
  permission: string;
  priority: number;
  read: () => Promise<number>;
}

@Injectable()
export class AdminWorkspaceService {
  private readonly logger = new Logger(AdminWorkspaceService.name);
  constructor(private readonly prisma: PrismaService) {}

  async summary(actor: AuthUser) {
    const now = new Date();
    const has = (permission: string) => actor.permissions?.includes(permission) === true;
    const reportKinds = [
      ...(has('admin.finance.read') ? ['MONTHLY_FINANCE'] : []),
      ...(has('admin.support.read') ? ['SUPPORT_SLA'] : []),
      ...(has('admin.moderation.reports') ? ['MODERATION'] : []),
    ];
    const sources: WorkspaceSource[] = [
      { key: 'incidents', label: 'Sự cố chưa tiếp nhận', route: '/admin/operations', permission: 'admin.operations.view', priority: 0,
        read: () => this.prisma.operationsIncident.count({ where: { status: 'OPEN' } }) },
      { key: 'support_overdue', label: 'Ticket quá SLA', route: '/admin/support-center', permission: 'admin.support.read', priority: 1,
        read: () => this.prisma.supportTicket.count({ where: supportSlaWhere('overdue', now) }) },
      { key: 'support_due_soon', label: 'Ticket đến hạn trong 1 giờ', route: '/admin/support-center', permission: 'admin.support.read', priority: 2,
        read: () => this.prisma.supportTicket.count({ where: supportSlaWhere('due_soon', now) }) },
      { key: 'moderation', label: 'Kiểm duyệt quá hạn', route: '/admin/moderation', permission: 'admin.dashboard.view', priority: 1,
        read: async () => {
          const kinds = ['LISTING', 'REPORT', 'REVIEW', 'REPLY'].filter(kind => has(adminPermissionForWork(kind)));
          if (!kinds.length) return 0;
          const rows = await this.prisma.$queryRaw<{ total: bigint }[]>`WITH q AS (${pendingModerationSql})
            SELECT COUNT(*) AS total FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id
            WHERE q.kind IN (${Prisma.join(kinds)}) AND COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') < ${now}`;
          return Number(rows[0]?.total ?? 0);
        } },
      { key: 'notification_delivery', label: 'Thông báo gửi thất bại', route: '/admin/operations', permission: 'admin.operations.view', priority: 2,
        read: () => this.prisma.platformNotificationDelivery.count({ where: { status: 'DEAD' } }) },
      { key: 'reports', label: 'Báo cáo của bạn bị lỗi', route: '/admin/report-schedules', permission: 'admin.reports.manage', priority: 3,
        read: () => this.prisma.adminReportRun.count({ where: {
          status: 'FAILED', expiresAt: { gt: now }, kind: { in: reportKinds }, schedule: { ownerId: actor.userId },
        } }) },
      { key: 'finance', label: 'Giao dịch cần đối soát', route: '/admin/finance-reconciliation', permission: 'admin.finance.read', priority: 3,
        read: () => this.prisma.financeStatementLine.count({ where: { status: { in: ['UNMATCHED', 'NEEDS_REVIEW'] } } }) },
      { key: 'notifications', label: 'Thông báo chưa đọc', route: '/admin/notifications', permission: 'admin.notifications.view', priority: 4,
        read: () => this.prisma.platformNotification.count({ where: { userId: actor.userId, readAt: null } }) },
    ].filter(source => has(source.permission) && (source.key !== 'moderation' || ['admin.listings.moderate', 'admin.reviews.moderate'].some(has)));
    const items = await Promise.all(sources.map(async source => {
      const { read, ...metadata } = source;
      const filters: Record<string, string> = {
        incidents: '?status=OPEN', support_overdue: '?sla=overdue', support_due_soon: '?sla=due_soon',
      };
      if (filters[source.key]) metadata.actionPath = `${source.route}${filters[source.key]}`;
      try {
        return { ...metadata, pendingCount: await read(), status: 'OK' as const, lastUpdatedAt: new Date().toISOString() };
      } catch {
        this.logger.warn(`Workspace source unavailable: ${source.key}`);
        return { ...metadata, pendingCount: null, status: 'UNAVAILABLE' as const, lastUpdatedAt: null };
      }
    }));
    return { data: {
      lastUpdatedAt: new Date().toISOString(), dataFreshness: items.some(item => item.status !== 'OK') ? 'PARTIAL' : 'LIVE',
      pendingCount: items.filter(item => item.key !== 'notifications').reduce((total, item) => total + (item.pendingCount ?? 0), 0),
      unreadNotificationCount: items.find(item => item.key === 'notifications')?.pendingCount ?? null,
      items, permissions: actor.permissions ?? [],
    } };
  }

  async actionItems(actor: AuthUser, query: AdminWorkspaceQuery) {
    const { data } = await this.summary(actor);
    const items = data.items.filter(item => item.key !== 'notifications' &&
      (!query.group || item.key === query.group) &&
      (query.view !== 'attention' || item.pendingCount === null || item.pendingCount > 0));
    items.sort((left, right) => query.sort === 'count'
      ? (right.pendingCount ?? -1) - (left.pendingCount ?? -1) || left.key.localeCompare(right.key)
      : left.priority - right.priority || left.key.localeCompare(right.key));
    const start = query.cursor ? items.findIndex(item => item.key === query.cursor) + 1 : 0;
    if (query.cursor && !start) throw new BadRequestException('Cursor không còn hợp lệ. Hãy tải lại danh sách.');
    const page = items.slice(start, start + query.limit);
    return { data: page, meta: {
      lastUpdatedAt: data.lastUpdatedAt, dataFreshness: data.dataFreshness, total: items.length,
      limit: query.limit, nextCursor: start + page.length < items.length ? page[page.length - 1]?.key ?? null : null,
    } };
  }
}
