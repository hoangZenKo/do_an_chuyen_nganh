import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { ActionCategory, ActionItemsQuery, actionCategories } from './action-items.dto';

interface ActionRow {
  id: string;
  kind: string;
  category: ActionCategory;
  severity: string;
  title: string;
  body: string;
  resourceType: string;
  resourceId: string;
  actionRoute: string;
  dueAt: Date | null;
  createdAt: Date;
  propertyId: string;
  propertyName: string;
  amount: number | null;
  isRead: boolean;
}

interface ActionCount { kind: string; category: ActionCategory; count: number; unread: number }

@Injectable()
export class OperationsService {
  constructor(private readonly prisma: PrismaService) {}

  async markRead(user: AuthUser, id: string) {
    const now = new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const feed = this.feed(landlordScopeId(user), now, today,
      new Date(today.getTime() + 7 * 86400000), new Date(today.getTime() + 30 * 86400000));
    const categories = this.allowedCategories(user);
    const rows = await this.prisma.$queryRaw<{ id: string }[]>(Prisma.sql`
      WITH source AS (${feed}) SELECT id FROM source WHERE id = ${id}
      AND category IN (${Prisma.join(categories.length ? categories : ['none'])}) LIMIT 1`);
    if (!rows.length) throw new NotFoundException('Không tìm thấy công việc.');
    await this.prisma.notificationRead.upsert({
      where: { userId_notificationId: { userId: user.userId, notificationId: id } },
      create: { userId: user.userId, notificationId: id },
      update: { readAt: now },
    });
    return { data: { notificationId: id, isRead: true } };
  }

  async actionItems(user: AuthUser, query: ActionItemsQuery) {
    const landlordId = landlordScopeId(user);
    const categories = this.allowedCategories(user);
    if (query.category !== 'all' && !categories.includes(query.category)) {
      throw new ForbiddenException('Bạn không có quyền xem nhóm công việc này.');
    }
    if (query.propertyId && !await this.prisma.property.findFirst({
      where: { id: query.propertyId, landlordId }, select: { id: true },
    })) throw new NotFoundException('Không tìm thấy khu trọ.');

    const now = new Date();
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    const sevenDays = new Date(today.getTime() + 7 * 86400000);
    const thirtyDays = new Date(today.getTime() + 30 * 86400000);
    const feed = this.feed(landlordId, now, today, sevenDays, thirtyDays);
    const scope = Prisma.sql`WITH source AS (${feed}), scoped AS (
      SELECT source.*, (read.id IS NOT NULL) AS "isRead" FROM source
      LEFT JOIN "NotificationRead" read ON read."notificationId" = source.id AND read."userId" = ${user.userId}
      WHERE source.category IN (${Prisma.join(categories.length ? categories : ['none'])})
      ${query.propertyId ? Prisma.sql`AND source."propertyId" = ${query.propertyId}` : Prisma.empty}
    )`;
    return this.prisma.$transaction(async (tx) => {
      const counts = await tx.$queryRaw<ActionCount[]>(Prisma.sql`${scope}
        SELECT kind, category, COUNT(*)::int AS count, COUNT(*) FILTER (WHERE NOT "isRead")::int AS unread
        FROM scoped GROUP BY kind, category`);
      const rows = await tx.$queryRaw<ActionRow[]>(Prisma.sql`${scope}
        SELECT * FROM scoped ${query.category === 'all' ? Prisma.empty : Prisma.sql`WHERE category = ${query.category}`}
        ORDER BY CASE severity WHEN 'danger' THEN 0 WHEN 'warning' THEN 1 ELSE 2 END,
          COALESCE("dueAt", "createdAt") ASC, id ASC
        LIMIT ${query.limit} OFFSET ${(query.page - 1) * query.limit}`);
      const count = (kind: string) => counts.find(value => value.kind === kind)?.count ?? 0;
      const total = counts.reduce((sum, value) => sum + value.count, 0);
      const filteredTotal = counts.filter(value => query.category === 'all' || value.category === query.category)
        .reduce((sum, value) => sum + value.count, 0);
      return { data: {
        summary: { total, unread: counts.reduce((sum, value) => sum + value.unread, 0),
          pendingViewings: count('viewing_pending'), overdueInvoices: count('invoice_overdue'),
          dueSoonInvoices: count('invoice_due_soon'), pendingPaymentProofs: count('payment_proof_pending'),
          urgentMaintenance: count('maintenance_urgent'), openMaintenance: count('maintenance_urgent') + count('maintenance_open'),
          expiringLeases: count('lease_expiring'), dueInspections: count('room_inspection_due') },
        items: rows.map(({ amount, ...row }) => ({ ...row,
          body: amount == null ? row.body : `${row.body} · ${amount.toLocaleString('vi-VN')} đ`,
          dueAt: row.dueAt?.toISOString() ?? null, createdAt: row.createdAt.toISOString() })),
        categories,
      }, meta: { total: filteredTotal, page: query.page, limit: query.limit } };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  private allowedCategories(user: AuthUser): ActionCategory[] {
    if (user.role === AuthRole.LANDLORD) return [...actionCategories];
    const permissions = new Set(user.permissions ?? []);
    return actionCategories.filter(category => {
      switch (category) {
        case 'viewing': return false;
        case 'payment': case 'invoice': return permissions.has('billing.view');
        case 'maintenance': return permissions.has('maintenance.view');
        case 'lease': return permissions.has('lease.view') && permissions.has('tenant.view');
        case 'inspection': return permissions.has('room.view');
      }
    });
  }

  private feed(landlordId: string, now: Date, today: Date, sevenDays: Date, thirtyDays: Date) {
    return Prisma.sql`
      SELECT 'viewing-pending-' || viewing.id AS id, 'viewing_pending' AS kind, 'viewing' AS category,
        CASE WHEN viewing."scheduledAt" < ${now} THEN 'danger' ELSE 'warning' END AS severity,
        'Lịch xem chờ xác nhận' AS title, student."fullName" || ' · ' || listing.title AS body,
        'room_viewing' AS "resourceType", viewing.id AS "resourceId",
        '/housing/viewings?viewingId=' || viewing.id AS "actionRoute",
        viewing."scheduledAt" AS "dueAt", viewing."createdAt" AS "createdAt",
        property.id AS "propertyId", property.name AS "propertyName", NULL::integer AS amount
      FROM "RoomViewing" viewing JOIN "RoomListing" listing ON listing.id = viewing."listingId"
        JOIN "Room" room ON room.id = listing."roomId" JOIN "Property" property ON property.id = room."propertyId"
        JOIN "User" student ON student.id = viewing."studentId"
      WHERE viewing."landlordId" = ${landlordId} AND property."landlordId" = ${landlordId} AND viewing.status = 'REQUESTED'
      UNION ALL
      SELECT 'payment-proof-pending-' || proof.id, 'payment_proof_pending', 'payment', 'warning',
        'Chứng từ chờ duyệt', tenant."fullName" || ' · ' || room.name, 'payment_proof', proof.id,
        '/billing/' || invoice.id || '?proofId=' || proof.id, NULL::timestamp, proof."submittedAt",
        property.id, property.name, proof.amount
      FROM "PaymentProof" proof JOIN "Invoice" invoice ON invoice.id = proof."invoiceId"
        JOIN "Room" room ON room.id = invoice."roomId" JOIN "Property" property ON property.id = room."propertyId"
        JOIN "Tenant" tenant ON tenant.id = proof."tenantId"
      WHERE property."landlordId" = ${landlordId} AND proof.status = 'PENDING'
        AND invoice.status IN ('UNPAID', 'PARTIAL') AND invoice."paidAmount" < invoice."totalAmount"
      UNION ALL
      SELECT CASE WHEN invoice."dueDate" < ${today} THEN 'invoice-overdue-' ELSE 'invoice-due-soon-' END || invoice.id,
        CASE WHEN invoice."dueDate" < ${today} THEN 'invoice_overdue' ELSE 'invoice_due_soon' END,
        'invoice', CASE WHEN invoice."dueDate" < ${today} THEN 'danger' ELSE 'warning' END,
        CASE WHEN invoice."dueDate" < ${today} THEN 'Hóa đơn quá hạn' ELSE 'Hóa đơn sắp đến hạn' END,
        tenant."fullName" || ' · ' || room.name, 'invoice', invoice.id, '/billing/' || invoice.id,
        invoice."dueDate", invoice."issuedAt", property.id, property.name, invoice."totalAmount" - invoice."paidAmount"
      FROM "Invoice" invoice JOIN "Room" room ON room.id = invoice."roomId"
        JOIN "Property" property ON property.id = room."propertyId" JOIN "Tenant" tenant ON tenant.id = invoice."tenantId"
      WHERE property."landlordId" = ${landlordId} AND invoice.status IN ('UNPAID', 'PARTIAL')
        AND invoice."paidAmount" < invoice."totalAmount" AND invoice."dueDate" <= ${sevenDays}
      UNION ALL
      SELECT CASE WHEN ticket.priority = 'URGENT' THEN 'maintenance-urgent-' ELSE 'maintenance-open-' END || ticket.id,
        CASE WHEN ticket.priority = 'URGENT' THEN 'maintenance_urgent' ELSE 'maintenance_open' END, 'maintenance',
        CASE WHEN ticket.priority = 'URGENT' THEN 'danger' ELSE 'info' END,
        CASE WHEN ticket.priority = 'URGENT' THEN 'Sửa chữa khẩn cấp' ELSE 'Yêu cầu sửa chữa' END,
        room.name || ' · ' || ticket.title, 'maintenance_ticket', ticket.id, '/maintenance?ticketId=' || ticket.id,
        NULL::timestamp, ticket."reportedAt", property.id, property.name, NULL::integer
      FROM "MaintenanceTicket" ticket JOIN "Room" room ON room.id = ticket."roomId"
        JOIN "Property" property ON property.id = room."propertyId"
      WHERE ticket."landlordId" = ${landlordId} AND property."landlordId" = ${landlordId}
        AND ticket.status IN ('OPEN', 'IN_PROGRESS')
      UNION ALL
      SELECT 'lease-expiring-' || lease.id, 'lease_expiring', 'lease',
        CASE WHEN lease."endDate" < ${today} THEN 'danger' ELSE 'warning' END,
        CASE WHEN lease."endDate" < ${today} THEN 'Hợp đồng đã đến hạn' ELSE 'Hợp đồng sắp hết hạn' END,
        tenant."fullName" || ' · ' || room.name, 'lease', lease.id,
        '/tenants/' || lease."tenantId", lease."endDate", lease."createdAt", property.id, property.name, NULL::integer
      FROM "Lease" lease JOIN "Room" room ON room.id = lease."roomId"
        JOIN "Property" property ON property.id = room."propertyId" JOIN "Tenant" tenant ON tenant.id = lease."tenantId"
      WHERE property."landlordId" = ${landlordId} AND lease.status = 'ACTIVE' AND lease."endDate" <= ${thirtyDays}
      UNION ALL
      SELECT 'room-inspection-due-' || inspection.id, 'room_inspection_due', 'inspection',
        CASE WHEN inspection."dueAt" < ${today} THEN 'danger' ELSE 'info' END, 'Lịch kiểm tra phòng',
        room.name || ' · ' || inspection.title, 'room_inspection', inspection.id,
        '/rooms/' || room.id || '?tab=inspections', inspection."dueAt", inspection."createdAt", property.id, property.name, NULL::integer
      FROM "RoomInspection" inspection JOIN "Room" room ON room.id = inspection."roomId"
        JOIN "Property" property ON property.id = room."propertyId"
      WHERE property."landlordId" = ${landlordId} AND inspection."completedAt" IS NULL AND inspection."dueAt" <= ${sevenDays}
    `;
  }
}
