import { BadRequestException, Injectable } from '@nestjs/common';
import { Transform, Type } from 'class-transformer';
import { IsIn, IsInt, IsISO8601, IsOptional, IsString, IsUUID, Max, MaxLength, Min } from 'class-validator';
import { PaymentLinkStatus, PaymentType, Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';

export class AdminTransactionsQuery {
  @IsIn(['PAYMENT', 'LINK', 'EVENT']) kind: 'PAYMENT' | 'LINK' | 'EVENT' = 'LINK';
  @Type(() => Number) @IsInt() @Min(1) @Max(100000) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(50) limit = 20;
  @IsOptional() @IsUUID() propertyId?: string;
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
  @IsOptional() @IsIn(['PENDING', 'PAID', 'EXPIRED', 'CANCELLED', 'FAILED', 'PAYMENT', 'REFUND', 'RECONCILED']) status?: string;
  @IsOptional() @Transform(({ value }) => typeof value === 'string' ? value.trim() : value)
  @IsString() @MaxLength(100) search?: string;
}

@Injectable()
export class AdminTransactionsService {
  constructor(private readonly prisma: PrismaService) {}
  async list(actor: AuthUser, query: AdminTransactionsQuery) {
    const to = query.to ? new Date(query.to) : new Date();
    const from = query.from ? new Date(query.from) : new Date(to.getTime() - 30 * 86400000);
    if (!Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) || to < from || to.getTime() - from.getTime() > 93 * 86400000) {
      throw new BadRequestException('Select a time range no longer than 93 days.');
    }
    const statuses = query.kind === 'PAYMENT' ? ['PAYMENT', 'REFUND'] : query.kind === 'LINK' ? ['PENDING', 'PAID', 'EXPIRED', 'CANCELLED', 'FAILED'] : ['RECONCILED'];
    if (query.status && !statuses.includes(query.status)) throw new BadRequestException('Status does not belong to this transaction type.');
    return this.prisma.$transaction(async tx => {
      const contains = { contains: query.search, mode: 'insensitive' as const };
      const window = { gte: from, lte: to };
      const pagination = { take: query.limit, skip: (query.page - 1) * query.limit };
      let data: unknown[], total: number;
      if (query.kind === 'PAYMENT') {
        const where: Prisma.PaymentWhereInput = { paidAt: window, ...(query.status ? { type: query.status as PaymentType } : {}),
          ...(query.propertyId ? { invoice: { room: { propertyId: query.propertyId } } } : {}),
          ...(query.search ? { OR: [{ id: contains }, { invoiceId: contains }] } : {}) };
        [data, total] = await Promise.all([tx.payment.findMany({ where, ...pagination, orderBy: [{ paidAt: 'desc' }, { id: 'asc' }],
          select: { id: true, invoiceId: true, amount: true, method: true, type: true, paidAt: true, reversalOfPaymentId: true,
            invoice: { select: { isDemo: true, room: { select: { propertyId: true } } } } } }), tx.payment.count({ where })]);
      } else if (query.kind === 'LINK') {
        const orderCode = query.search && /^\d+$/.test(query.search) ? Number(query.search) : null;
        const where: Prisma.PaymentLinkWhereInput = { createdAt: window, ...(query.status ? { status: query.status as PaymentLinkStatus } : {}),
          ...(query.propertyId ? { propertyId: query.propertyId } : {}), ...(query.search ? { OR: [
            { id: contains }, { invoiceId: contains },
            ...(orderCode !== null && Number.isSafeInteger(orderCode) && orderCode <= 2147483647 ? [{ orderCode }] : []),
          ] } : {}) };
        [data, total] = await Promise.all([tx.paymentLink.findMany({ where, ...pagination, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
          select: { id: true, invoiceId: true, propertyId: true, orderCode: true, amount: true, provider: true, status: true, createdAt: true, expiresAt: true, paidAt: true,
            events: { orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], take: 3, select: { id: true, status: true, paymentId: true, createdAt: true } } } }), tx.paymentLink.count({ where })]);
      } else {
        const where: Prisma.PaymentWebhookEventWhereInput = { createdAt: window, ...(query.status ? { status: query.status } : {}),
          ...(query.propertyId ? { paymentLink: { propertyId: query.propertyId } } : {}),
          ...(query.search ? { OR: [{ id: contains }, { reference: contains }, { paymentLinkId: contains }] } : {}) };
        [data, total] = await Promise.all([tx.paymentWebhookEvent.findMany({ where, ...pagination, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
          select: { id: true, paymentLinkId: true, amount: true, status: true, paymentId: true, createdAt: true } }), tx.paymentWebhookEvent.count({ where })]);
      }
      await platformAudit(tx, actor, 'admin.transactions_read', 'admin_finance', 'transactions', 'Investigate payment state without modifying ledger',
        { kind: query.kind, from: from.toISOString(), to: to.toISOString(), page: query.page, limit: query.limit, returned: data.length });
      return { data, meta: { page: query.page, limit: query.limit, total, kind: query.kind, readOnly: true,
        from: from.toISOString(), to: to.toISOString(), platformRevenue: false } };
    }, { isolationLevel: 'RepeatableRead' });
  }
}
