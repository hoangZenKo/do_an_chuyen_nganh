import { propertyWhere } from '../common/property-scope';
import { Injectable, NotFoundException } from '@nestjs/common';
import { InvoiceStatus, RoomStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { DashboardMetricsQueryDto } from './dto/dashboard-metrics-query.dto';

const propertyNotFound = () =>
  new NotFoundException({
    error: { code: 'PROPERTY_NOT_FOUND', message: 'Property not found.' },
  });

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async metrics(landlordId: string, query: DashboardMetricsQueryDto = {}) {
    const months = query.months ?? 12;
    const propertyId = query.propertyId;

    if (propertyId) {
      const property = await this.prisma.property.findFirst({
        where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false },
        select: { id: true },
      });
      if (!property) throw propertyNotFound();
    }

    const generatedAt = new Date();
    const todayStart = this.dayStart(generatedAt);
    const dueSoonEnd = this.addDays(todayStart, 7);
    const currentMonthStart = this.monthStart(generatedAt);
    const nextMonthStart = this.addMonths(currentMonthStart, 1);
    const rangeStart = this.addMonths(currentMonthStart, -(months - 1));
    const roomScope = this.roomScope(landlordId, propertyId);

    const [
      roomGroups,
      activeLeases,
      currentMonthInvoices,
      revenuePayments,
      overdueInvoices,
      dueSoonInvoices,
      maintenanceRooms,
      recentInvoices,
    ] = await this.prisma.$transaction([
      this.prisma.room.groupBy({
        by: ['status'],
        where: roomScope,
        orderBy: { status: 'asc' },
        _count: { _all: true },
      }),
      this.prisma.lease.count({
        where: { status: 'ACTIVE', room: roomScope },
      }),
      this.prisma.invoice.findMany({
        where: {
          isDemo: false,
          room: roomScope,
          billingMonth: currentMonthStart,
          status: { not: InvoiceStatus.CANCELLED },
        },
        select: { totalAmount: true, paidAmount: true },
      }),
      this.prisma.payment.findMany({
        where: {
          paidAt: { gte: rangeStart, lt: nextMonthStart },
          invoice: { isDemo: false, room: roomScope, status: { not: InvoiceStatus.CANCELLED } },
        },
        select: { amount: true, paidAt: true },
      }),
      this.prisma.invoice.findMany({
        where: {
          isDemo: false,
          room: roomScope,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
          dueDate: { lt: todayStart },
        },
        orderBy: [{ dueDate: 'asc' }, { issuedAt: 'desc' }],
        take: 4,
        select: {
          id: true,
          roomId: true,
          tenantId: true,
          totalAmount: true,
          paidAmount: true,
          dueDate: true,
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
      }),
      this.prisma.invoice.findMany({
        where: {
          isDemo: false,
          room: roomScope,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
          dueDate: { gte: todayStart, lte: dueSoonEnd },
        },
        orderBy: [{ dueDate: 'asc' }, { issuedAt: 'desc' }],
        take: 4,
        select: {
          id: true,
          roomId: true,
          tenantId: true,
          totalAmount: true,
          paidAmount: true,
          dueDate: true,
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
      }),
      this.prisma.room.findMany({
        where: { ...roomScope, status: RoomStatus.MAINTENANCE },
        orderBy: { updatedAt: 'desc' },
        take: 4,
        select: {
          id: true,
          name: true,
          propertyId: true,
          updatedAt: true,
          property: { select: { name: true } },
        },
      }),
      this.prisma.invoice.findMany({
        where: { room: roomScope, isDemo: false },
        orderBy: { issuedAt: 'desc' },
        take: 5,
        select: {
          id: true,
          roomId: true,
          tenantId: true,
          billingMonth: true,
          totalAmount: true,
          paidAmount: true,
          status: true,
          dueDate: true,
          issuedAt: true,
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
      }),
    ]);

    const roomStats = this.roomStats(roomGroups);
    const currentMonth = this.currentMonthStats(
      currentMonthInvoices,
      revenuePayments,
      currentMonthStart,
      nextMonthStart,
    );

    return {
      data: {
        propertyId: propertyId ?? null,
        generatedAt: generatedAt.toISOString(),
        roomStats,
        leaseStats: { active: activeLeases },
        currentMonth,
        revenueTrend: this.revenueTrend(revenuePayments, rangeStart, months),
        attentionItems: [
          ...overdueInvoices.map((invoice) => ({
            kind: 'overdue_invoice' as const,
            roomId: invoice.roomId,
            roomName: invoice.room?.name ?? 'Phòng',
            tenantId: invoice.tenantId,
            tenantName: invoice.tenant?.fullName ?? null,
            invoiceId: invoice.id,
            remainingAmount: Math.max(invoice.totalAmount - invoice.paidAmount, 0),
            dueDate: invoice.dueDate?.toISOString() ?? null,
          })),
          ...dueSoonInvoices.map((invoice) => ({
            kind: 'due_soon_invoice' as const,
            roomId: invoice.roomId,
            roomName: invoice.room?.name ?? 'Phòng',
            tenantId: invoice.tenantId,
            tenantName: invoice.tenant?.fullName ?? null,
            invoiceId: invoice.id,
            remainingAmount: Math.max(invoice.totalAmount - invoice.paidAmount, 0),
            dueDate: invoice.dueDate?.toISOString() ?? null,
          })),
          ...maintenanceRooms.map((room) => ({
            kind: 'maintenance_room' as const,
            roomId: room.id,
            roomName: room.name,
            tenantId: null,
            tenantName: null,
            propertyId: room.propertyId,
            propertyName: room.property?.name ?? null,
            updatedAt: room.updatedAt.toISOString(),
          })),
        ].slice(0, 6),
        recentInvoices: recentInvoices.map((invoice) => ({
          id: invoice.id,
          roomId: invoice.roomId,
          roomName: invoice.room?.name ?? 'Phòng',
          tenantId: invoice.tenantId,
          tenantName: invoice.tenant?.fullName ?? null,
          billingMonth: invoice.billingMonth.toISOString(),
          totalAmount: invoice.totalAmount,
          paidAmount: invoice.paidAmount,
          remainingAmount: Math.max(invoice.totalAmount - invoice.paidAmount, 0),
          status: invoice.status.toLowerCase(),
          dueDate: invoice.dueDate?.toISOString() ?? null,
          issuedAt: invoice.issuedAt.toISOString(),
        })),
      },
    };
  }

  private roomScope(landlordId: string, propertyId?: string) {
    return {
      ...(propertyId ? { propertyId } : {}),
      isActive: true,
      property: { ...propertyWhere(landlordId), isArchived: false },
    };
  }

  private roomStats(
    groups: { status: RoomStatus; _count?: { _all?: number } | true }[],
  ) {
    const count = (status: RoomStatus) => {
      const aggregate = groups.find((group) => group.status === status)?._count;
      return typeof aggregate === 'object' ? aggregate._all ?? 0 : 0;
    };
    const occupied = count(RoomStatus.OCCUPIED);
    const vacant = count(RoomStatus.VACANT);
    const maintenance = count(RoomStatus.MAINTENANCE);
    const total = occupied + vacant + maintenance;
    return {
      total,
      occupied,
      vacant,
      maintenance,
      occupancyRate: total === 0 ? 0 : Math.round((occupied / total) * 100),
    };
  }

  private currentMonthStats(
    invoices: { totalAmount: number; paidAmount: number }[],
    payments: { amount: number; paidAt: Date }[],
    currentMonthStart: Date,
    nextMonthStart: Date,
  ) {
    const outstandingInvoices = invoices.filter(
      (invoice) => invoice.totalAmount > invoice.paidAmount,
    );
    return {
      invoiceCount: invoices.length,
      billedAmount: invoices.reduce((sum, invoice) => sum + invoice.totalAmount, 0),
      receivedAmount: payments
        .filter(
          (payment) =>
            payment.paidAt >= currentMonthStart && payment.paidAt < nextMonthStart,
        )
        .reduce((sum, payment) => sum + payment.amount, 0),
      outstandingInvoiceCount: outstandingInvoices.length,
      outstandingAmount: outstandingInvoices.reduce(
        (sum, invoice) => sum + Math.max(invoice.totalAmount - invoice.paidAmount, 0),
        0,
      ),
    };
  }

  private revenueTrend(
    payments: { amount: number; paidAt: Date }[],
    rangeStart: Date,
    months: number,
  ) {
    const buckets = new Map<string, number>();
    for (const payment of payments) {
      const key = this.monthStart(payment.paidAt).toISOString();
      buckets.set(key, (buckets.get(key) ?? 0) + payment.amount);
    }

    return Array.from({ length: months }, (_, index) => {
      const month = this.addMonths(rangeStart, index);
      const key = month.toISOString();
      return { month: key, amount: buckets.get(key) ?? 0 };
    });
  }

  private monthStart(date: Date) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
  }

  private dayStart(date: Date) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  }

  private addDays(date: Date, days: number) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + days));
  }

  private addMonths(date: Date, months: number) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
  }
}
