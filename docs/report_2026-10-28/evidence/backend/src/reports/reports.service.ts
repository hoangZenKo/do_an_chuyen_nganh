import { propertyWhere, propertyIdScope } from '../common/property-scope';
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  DepositTransactionType,
  ExpenseCategory,
  InvoiceStatus,
  PaymentType,
  Prisma,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { billingAnalytics } from './billing-analytics';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async monthly(landlordId: string, month?: string, propertyId?: string) {
    if (month && !Number.isFinite(new Date(month).getTime())) throw new BadRequestException('Tháng báo cáo không hợp lệ.');
    const monthStart = this.monthStart(month ? new Date(month) : new Date());
    const nextMonth = this.addMonths(monthStart, 1);
    if (propertyId) {
      const property = await this.prisma.property.findFirst({
        where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false },
        select: { id: true },
      });
      if (!property) {
        throw new NotFoundException({
          error: { code: 'PROPERTY_NOT_FOUND', message: 'Property not found.' },
        });
      }
    }
    const roomScope = {
      property: { ...propertyWhere(landlordId), ...(propertyId ? { id: propertyId } : {}) },
    };

    const [invoices, payments, expenses, deposits, activeLeases] =
      await this.prisma.$transaction([
        this.prisma.invoice.findMany({
          where: {
            isDemo: false,
            billingMonth: monthStart,
            status: { not: InvoiceStatus.CANCELLED },
            room: roomScope,
          },
          include: {
            room: { select: { id: true, name: true, propertyId: true } },
            tenant: { select: { id: true, fullName: true } },
          },
        }),
        this.prisma.payment.findMany({
          where: {
            paidAt: { gte: monthStart, lt: nextMonth },
            invoice: { isDemo: false, room: roomScope, status: { not: InvoiceStatus.CANCELLED } },
            type: { in: [PaymentType.PAYMENT, PaymentType.REVERSAL] },
          },
        }),
        this.prisma.expense.findMany({
          where: {
            expenseDate: { gte: monthStart, lt: nextMonth },
            landlordId,
            ...propertyIdScope(),
            ...(propertyId ? { propertyId } : {}),
          },
        }),
        this.prisma.depositTransaction.findMany({
          where: {
            occurredAt: { gte: monthStart, lt: nextMonth },
            landlordId,
            lease: propertyId
              ? { room: { propertyId, property: propertyWhere(landlordId) } }
              : { room: { property: propertyWhere(landlordId) } },
          },
        }),
        this.prisma.lease.count({
          where: {
            status: 'ACTIVE',
            room: propertyId
              ? { propertyId, property: propertyWhere(landlordId) }
              : { property: propertyWhere(landlordId) },
          },
        }),
      ]);

    const billedAmount = invoices.reduce((sum, invoice) => sum + invoice.totalAmount, 0);
    const receivedAmount = payments.reduce((sum, payment) => sum + payment.amount, 0);
    const expenseAmount = expenses.reduce((sum, expense) => sum + expense.amount, 0);
    const outstandingAmount = invoices.reduce(
      (sum, invoice) => sum + Math.max(invoice.totalAmount - invoice.paidAmount, 0),
      0,
    );
    const depositCollected = deposits
      .filter((item) => item.type === DepositTransactionType.COLLECTED)
      .reduce((sum, item) => sum + item.amount, 0);
    const depositReturned = deposits
      .filter(
        (item) =>
          item.type === DepositTransactionType.REFUNDED ||
          item.type === DepositTransactionType.DEDUCTED,
      )
      .reduce((sum, item) => sum + item.amount, 0);

    return {
      data: {
        propertyId: propertyId ?? null,
        month: monthStart.toISOString(),
        summary: {
          activeLeases,
          invoiceCount: invoices.length,
          billedAmount,
          receivedAmount,
          outstandingAmount,
          expenseAmount,
          estimatedProfit: receivedAmount - expenseAmount,
          depositCollected,
          depositReturned,
        },
        invoiceStatus: {
          unpaid: invoices.filter((invoice) => invoice.status === InvoiceStatus.UNPAID).length,
          partial: invoices.filter((invoice) => invoice.status === InvoiceStatus.PARTIAL).length,
          paid: invoices.filter((invoice) => invoice.status === InvoiceStatus.PAID).length,
        },
        expenseByCategory: this.expenseByCategory(expenses),
        revenueByMethod: this.revenueByMethod(payments),
        invoices: invoices.map((invoice) => ({
          id: invoice.id,
          roomId: invoice.roomId,
          roomName: invoice.room?.name ?? null,
          tenantId: invoice.tenantId,
          tenantName: invoice.tenant?.fullName ?? null,
          totalAmount: invoice.totalAmount,
          paidAmount: invoice.paidAmount,
          remainingAmount: Math.max(invoice.totalAmount - invoice.paidAmount, 0),
          status: invoice.status.toLowerCase(),
          dueDate: invoice.dueDate?.toISOString() ?? null,
        })),
      },
    };
  }

  async monthlyExport(landlordId: string, month?: string, propertyId?: string) {
    const report = await this.monthly(landlordId, month, propertyId);
    const data = report.data;
    const rows = [
      ['Metric', 'Value'],
      ['Month', data.month],
      ['Active leases', data.summary.activeLeases],
      ['Invoice count', data.summary.invoiceCount],
      ['Billed amount', data.summary.billedAmount],
      ['Received amount', data.summary.receivedAmount],
      ['Outstanding amount', data.summary.outstandingAmount],
      ['Expense amount', data.summary.expenseAmount],
      ['Estimated profit', data.summary.estimatedProfit],
      ['Deposit collected', data.summary.depositCollected],
      ['Deposit returned', data.summary.depositReturned],
      [],
      ['Invoice ID', 'Room', 'Tenant', 'Total', 'Paid', 'Remaining', 'Status', 'Due date'],
      ...data.invoices.map((invoice) => [
        invoice.id,
        invoice.roomName ?? '',
        invoice.tenantName ?? '',
        invoice.totalAmount,
        invoice.paidAmount,
        invoice.remainingAmount,
        invoice.status,
        invoice.dueDate ?? '',
      ]),
    ];
    const content = rows.map((row) => row.map((cell) => this.csvCell(cell)).join(',')).join('\n');
    const fileMonth = data.month.slice(0, 7);
    return {
      data: {
        filename: `monthly-report-${fileMonth}.csv`,
        mimeType: 'text/csv; charset=utf-8',
        content,
      },
    };
  }

  async analytics(landlordId: string, month?: string, propertyId?: string) {
    if (month && !Number.isFinite(new Date(month).getTime())) throw new BadRequestException('Tháng báo cáo không hợp lệ.');
    const monthStart = this.monthStart(month ? new Date(month) : new Date());
    const now = new Date();
    const roomScope = { property: { ...propertyWhere(landlordId), isArchived: false, ...(propertyId ? { id: propertyId } : {}) } };
    if (propertyId && !(await this.prisma.property.findFirst({ where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false }, select: { id: true } }))) throw new NotFoundException('Property not found.');
    const [leases, rooms, invoices, outstanding] = await this.prisma.$transaction([
      this.prisma.lease.findMany({ where: { status: 'ACTIVE', startDate: { lte: now }, OR: [{ endDate: null }, { endDate: { gte: now } }], room: { isActive: true, ...roomScope } }, select: { monthlyRent: true, roomId: true } }),
      this.prisma.room.findMany({ where: { isActive: true, ...roomScope }, select: { id: true } }),
      this.prisma.invoice.findMany({ where: { isDemo: false, billingMonth: monthStart, status: { not: InvoiceStatus.CANCELLED }, room: roomScope }, select: { totalAmount: true, paidAmount: true, dueDate: true } }),
      this.prisma.invoice.findMany({ where: { isDemo: false, status: { in: ['UNPAID', 'PARTIAL'] }, dueDate: { not: null }, room: roomScope }, select: { totalAmount: true, paidAmount: true, dueDate: true } }),
    ], { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
    return { data: { month: monthStart.toISOString(), propertyId: propertyId ?? null, ...billingAnalytics(leases, rooms, leases, invoices, outstanding, now) } };
  }

  private expenseByCategory(expenses: { category: ExpenseCategory; amount: number }[]) {
    return Object.values(ExpenseCategory).map((category) => ({
      category: category.toLowerCase(),
      amount: expenses
        .filter((expense) => expense.category === category)
        .reduce((sum, expense) => sum + expense.amount, 0),
    }));
  }

  private revenueByMethod(payments: { method: string; type: PaymentType; amount: number }[]) {
    const methods = ['CASH', 'BANK_TRANSFER', 'OTHER'];
    return methods.map((method) => ({
      method: method.toLowerCase(),
      amount: payments
        .filter((payment) => payment.method === method)
        .reduce((sum, payment) => sum + payment.amount, 0),
    }));
  }

  private monthStart(date: Date) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
  }

  private addMonths(date: Date, months: number) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1));
  }

  private csvCell(value: unknown) {
    const text = String(value ?? '');
    if (!/[",\n]/.test(text)) return text;
    return `"${text.replace(/"/g, '""')}"`;
  }
}
