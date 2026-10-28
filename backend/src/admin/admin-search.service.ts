import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { AdminResourceQuery, AdminSearchKind, AdminSearchQuery } from './admin-search.dto';
import { adminAudit, maskedEmail, maskedPhone } from './admin-audit';

const identity = { id: true, name: true } as const;
const roomSelect = { id: true, name: true, status: true, isActive: true, basePrice: true,
  property: { select: { ...identity, landlordId: true } } } as const;
const tenantSelect = { id: true, fullName: true, isActive: true, landlordId: true } as const;
const leaseSelect = { id: true, status: true, startDate: true, endDate: true, room: { select: roomSelect }, tenantId: true } as const;
const invoiceSelect = { id: true, status: true, billingMonth: true, totalAmount: true, paidAmount: true, isDemo: true,
  room: { select: roomSelect } } as const;
const paymentSelect = { id: true, invoiceId: true, amount: true, type: true, method: true, paidAt: true } as const;
const searchKinds: readonly AdminSearchKind[] = ['ACCOUNT', 'PROPERTY', 'ROOM', 'SUPPORT_TICKET', 'TENANT', 'LEASE', 'INVOICE', 'PAYMENT'];
const resourcePermissions: Record<string, string> = {
  ROOM: 'admin.properties.view', TENANT: 'admin.support.read', LEASE: 'admin.support.read',
  INVOICE: 'admin.finance.read', PAYMENT: 'admin.finance.read',
};

@Injectable()
export class AdminSearchService {
  constructor(private readonly prisma: PrismaService) {}

  private allowedKinds(actor: AuthUser): AdminSearchKind[] {
    return searchKinds.filter(kind => {
      if (kind === 'ACCOUNT') return actor.permissions?.includes('admin.accounts.view');
      if (kind === 'PROPERTY' || kind === 'ROOM') return actor.permissions?.includes('admin.properties.view');
      if (kind === 'SUPPORT_TICKET' || kind === 'TENANT' || kind === 'LEASE') return actor.permissions?.includes('admin.support.read');
      return actor.permissions?.includes('admin.finance.read') ?? false;
    });
  }

  async search(actor: AuthUser, query: AdminSearchQuery) {
    if (actor.role !== 'admin') throw new ForbiddenException();
    const allowed = this.allowedKinds(actor);
    const kinds = query.kind ? allowed.filter(kind => kind === query.kind) : allowed;
    if (query.kind && !kinds.length) throw new ForbiddenException();
    const contains = { contains: query.search, mode: 'insensitive' as const };
    const page = query.page ?? 1, limit = query.limit ?? 10;
    const groups = await this.prisma.$transaction(async tx => {
      const result = await Promise.all(kinds.map(kind => this.searchGroup(tx, kind, contains, page, limit)));
      const sensitive = result.filter(group => ['TENANT', 'LEASE', 'INVOICE', 'PAYMENT'].includes(group.kind));
      if (sensitive.length) await adminAudit(tx, actor, 'admin.search_sensitive_access', 'admin_search', 'global', 'Read-only permission-scoped search',
        { page, limit, groups: sensitive.map(group => ({ kind: group.kind, returned: group.items.length })), readOnly: true });
      return result;
    }, { isolationLevel: 'RepeatableRead' });
    return {
      data: groups,
      meta: { page, limit, readOnly: true, kinds: kinds.length, perKindPagination: true, perKindLimit: limit },
    };
  }

  private async searchGroup(tx: Prisma.TransactionClient, kind: AdminSearchKind, contains: Prisma.StringFilter, page: number, limit: number) {
    const skip = (page - 1) * limit;
    let rows: unknown[];
    let total: number;
    if (kind === 'ACCOUNT') {
      const where: Prisma.UserWhereInput = { role: { not: 'ADMIN' }, OR: [{ fullName: contains }, { email: contains }, { id: contains }] };
      const [users, count] = await Promise.all([
        tx.user.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: { id: true, fullName: true, email: true, phone: true, role: true, isActive: true } }),
        tx.user.count({ where }),
      ]);
      rows = users.map(user => ({ ...user, email: maskedEmail(user.email), phone: maskedPhone(user.phone) }));
      total = count;
    } else if (kind === 'PROPERTY') {
      const where: Prisma.PropertyWhereInput = { OR: [{ name: contains }, { id: contains }] };
      [rows, total] = await Promise.all([
        tx.property.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: { ...identity, isArchived: true, landlordId: true } }),
        tx.property.count({ where }),
      ]);
    } else if (kind === 'ROOM') {
      const where: Prisma.RoomWhereInput = { OR: [{ name: contains }, { id: contains }] };
      [rows, total] = await Promise.all([
        tx.room.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: roomSelect }),
        tx.room.count({ where }),
      ]);
    } else if (kind === 'SUPPORT_TICKET') {
      const where: Prisma.SupportTicketWhereInput = { OR: [{ subject: contains }, { id: contains }] };
      [rows, total] = await Promise.all([
        tx.supportTicket.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: { id: true, subject: true, status: true, priority: true } }),
        tx.supportTicket.count({ where }),
      ]);
    } else if (kind === 'TENANT') {
      const where: Prisma.TenantWhereInput = { OR: [{ fullName: contains }, { id: contains }] };
      [rows, total] = await Promise.all([
        tx.tenant.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: tenantSelect }),
        tx.tenant.count({ where }),
      ]);
    } else if (kind === 'LEASE') {
      const where: Prisma.LeaseWhereInput = { OR: [{ id: contains }, { tenant: { fullName: contains } }] };
      [rows, total] = await Promise.all([
        tx.lease.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: leaseSelect }),
        tx.lease.count({ where }),
      ]);
    } else if (kind === 'INVOICE') {
      const where: Prisma.InvoiceWhereInput = { isDemo: false, OR: [{ id: contains }, { room: { name: contains } }] };
      [rows, total] = await Promise.all([
        tx.invoice.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: invoiceSelect }),
        tx.invoice.count({ where }),
      ]);
    } else {
      const where: Prisma.PaymentWhereInput = { invoice: { isDemo: false }, OR: [{ id: contains }, { invoiceId: contains }] };
      [rows, total] = await Promise.all([
        tx.payment.findMany({ where, take: limit, skip, orderBy: { id: 'asc' }, select: paymentSelect }),
        tx.payment.count({ where }),
      ]);
    }
    return { kind, items: rows, meta: { page, limit, total, hasMore: skip + rows.length < total } };
  }

  private permission(actor: AuthUser, kind: string) {
    const permission = resourcePermissions[kind];
    if (!permission) throw new BadRequestException('Unknown resource kind.');
    if (actor.role !== 'admin' || !actor.permissions?.includes(permission)) throw new ForbiddenException();
  }

  async resources(actor: AuthUser, input: AdminResourceQuery, id?: string) {
    this.permission(actor, input.kind);
    const contains = input.search ? { contains: input.search, mode: 'insensitive' as const } : undefined;
    const property = { ...(input.propertyId ? { id: input.propertyId } : {}), ...(input.landlordId ? { landlordId: input.landlordId } : {}) };
    const room = { property };
    const pagination = { take: id ? 1 : input.limit, skip: id ? 0 : (input.page - 1) * input.limit, orderBy: { id: 'asc' as const } };
    const result = await this.prisma.$transaction(async tx => {
      const read = async () => {
        if (input.kind === 'ROOM') {
          const where: Prisma.RoomWhereInput = { property, ...(id ? { id } : {}), ...(contains ? { OR: [{ id: contains }, { name: contains }] } : {}) };
          return { rows: await tx.room.findMany({ where, ...pagination, select: roomSelect }), total: await tx.room.count({ where }) };
        }
        if (input.kind === 'TENANT') {
          const where: Prisma.TenantWhereInput = { ...(id ? { id } : {}), ...(input.landlordId ? { landlordId: input.landlordId } : {}),
            ...(input.propertyId ? { leases: { some: { room } } } : {}), ...(contains ? { OR: [{ id: contains }, { fullName: contains }] } : {}) };
          return { rows: await tx.tenant.findMany({ where, ...pagination, select: tenantSelect }), total: await tx.tenant.count({ where }) };
        }
        if (input.kind === 'LEASE') {
          const where: Prisma.LeaseWhereInput = { room, ...(id ? { id } : {}), ...(contains ? { id: contains } : {}) };
          return { rows: await tx.lease.findMany({ where, ...pagination, select: leaseSelect }), total: await tx.lease.count({ where }) };
        }
        if (input.kind === 'INVOICE') {
          const where: Prisma.InvoiceWhereInput = { room, isDemo: false, ...(id ? { id } : {}), ...(contains ? { id: contains } : {}) };
          return { rows: await tx.invoice.findMany({ where, ...pagination, select: invoiceSelect }), total: await tx.invoice.count({ where }) };
        }
        const where: Prisma.PaymentWhereInput = { invoice: { room, isDemo: false }, ...(id ? { id } : {}), ...(contains ? { OR: [{ id: contains }, { invoiceId: contains }] } : {}) };
        return { rows: await tx.payment.findMany({ where, ...pagination, select: paymentSelect }), total: await tx.payment.count({ where }) };
      };
      const result = await read();
      if (['TENANT', 'LEASE', 'INVOICE', 'PAYMENT'].includes(input.kind)) await adminAudit(tx, actor, 'admin.resource_sensitive_access', 'admin_resource', id ?? input.kind,
        'Read-only permission-scoped resource lookup', { kind: input.kind, returned: result.rows.length, page: input.page, limit: input.limit, readOnly: true });
      return result;
    });
    if (id) {
      if (!result.rows.length) throw new NotFoundException();
      return { data: result.rows[0], meta: { readOnly: true } };
    }
    return { data: result.rows, meta: { total: result.total, page: input.page, limit: input.limit, hasMore: (input.page - 1) * input.limit + result.rows.length < result.total, readOnly: true } };
  }
}
