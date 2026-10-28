import { propertyWhere, tenantScope } from '../common/property-scope';
import { Injectable, NotFoundException } from '@nestjs/common';
import { BillingReceipt, Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { BillingCommandsService } from './billing-commands.service';
import { billingEvent } from './billing-events';
import { agingBucket, balanceStatus, billingError, businessDay, dueDays, money, requiredReason } from './billing-rules';
import { BillingService } from './billing.service';
import { AdjustmentDto, AgingQueryDto, AllocateReceiptDto, AllocationLineDto, BillingReasonDto, CreateReceiptDto, RefundReceiptDto, ReplaceInvoiceDto } from './dto/billing-ledger.dto';

const invoiceInclude = {
  room: { include: { property: true } }, tenant: true,
  lineItems: { orderBy: { position: 'asc' as const } },
  payments: { orderBy: { paidAt: 'desc' as const } },
  adjustments: { orderBy: { createdAt: 'asc' as const } },
  replacementInvoice: { select: { id: true } },
};

@Injectable()
export class BillingLedgerService {
  constructor(private readonly prisma: PrismaService, private readonly commands: BillingCommandsService, private readonly billing: BillingService) {}

  replace(user: AuthUser, invoiceId: string, input: ReplaceInvoiceDto) {
    const landlordId = landlordScopeId(user);
    requiredReason(input.reason);
    if (!input.lines.length) billingError('INVOICE_LINES_REQUIRED', 'Replacement must have invoice lines.');
    const lines = input.lines.map((line, position) => {
      if ((line.kind === 'DISCOUNT') !== (line.unitPrice < 0)) billingError('INVALID_REPLACEMENT_LINE', 'Only discount lines may have a negative unit price.');
      money(Math.abs(line.unitPrice), true);
      money(line.quantity);
      const amount = line.quantity * line.unitPrice;
      money(Math.abs(amount), true);
      return { ...line, position, amount, source: 'REPLACEMENT', sourceId: invoiceId };
    });
    const sumFor = (kinds: string[]) => lines.filter((line) => kinds.includes(line.kind)).reduce((sum, line) => sum + line.amount, 0);
    const totalAmount = money(lines.reduce((sum, line) => sum + line.amount, 0), true);
    return this.commands.execute(user, 'billing.invoice.replace', invoiceId, input, async (tx) => {
      const original = await this.lockInvoice(tx, landlordId, invoiceId);
      this.collectible(original);
      if (original.paidAmount !== 0 || original.payments.length) billingError('INVOICE_HAS_PAYMENTS', 'Use credit/debit notes for an invoice with payment history.', true);
      if (original.replacementInvoice) billingError('INVOICE_ALREADY_REPLACED', 'Invoice already has a replacement.', true);
      const latest = await tx.invoice.aggregate({ where: { leaseId: original.leaseId, billingMonth: original.billingMonth, isDemo: false }, _max: { revision: true } });
      await tx.invoice.update({ where: { id: invoiceId }, data: { status: 'CANCELLED', cancelledAt: new Date(), cancelledNote: input.reason.trim() } });
      await this.cancelLinks(tx, invoiceId);
      const replacement = await tx.invoice.create({ data: {
        leaseId: original.leaseId, tenantId: original.tenantId, roomId: original.roomId,
        billingMonth: original.billingMonth, revision: (latest._max.revision ?? 1) + 1, replacesInvoiceId: original.id,
        rentAmount: sumFor(['RENT']), electricityAmount: sumFor(['ELECTRICITY']), waterAmount: sumFor(['WATER']),
        otherAmount: sumFor(['SERVICE', 'OTHER', 'DISCOUNT', 'SURCHARGE']), totalAmount,
        status: balanceStatus(0, totalAmount), dueDate: input.dueDate ? new Date(input.dueDate) : original.dueDate,
        note: input.reason.trim(), lineItems: { create: lines },
      }, include: invoiceInclude });
      await billingEvent(tx, landlordId, 'invoice.replaced', replacement.id, `invoice.replaced:${replacement.id}`, { originalInvoiceId: invoiceId, replacementInvoiceId: replacement.id, reason: input.reason.trim() });
      return { data: this.billing.serializeInvoice(replacement) };
    });
  }

  adjust(user: AuthUser, invoiceId: string, input: AdjustmentDto) {
    const landlordId = landlordScopeId(user);
    requiredReason(input.reason);
    if ((input.amount === undefined) === (input.basisPoints === undefined)) billingError('INVALID_ADJUSTMENT', 'Choose a fixed amount or basis points, not both.');
    if (['DISCOUNT', 'TENANT_WAIVER'].includes(input.category) && input.kind !== 'CREDIT') billingError('INVALID_ADJUSTMENT', 'Discounts and waivers require a credit note.');
    if (['LATE_FEE', 'SURCHARGE'].includes(input.category) && input.kind !== 'DEBIT') billingError('INVALID_ADJUSTMENT', 'Surcharges require a debit note.');
    return this.commands.execute(user, 'billing.invoice.adjust', invoiceId, input, async (tx) => {
      const invoice = await this.lockInvoice(tx, landlordId, invoiceId);
      this.collectible(invoice);
      if (input.category === 'LATE_FEE' && (!invoice.dueDate || dueDays(invoice.dueDate) <= 0 || invoice.totalAmount <= invoice.paidAmount)) billingError('INVOICE_NOT_OVERDUE', 'Late fees require an overdue balance.');
      const amount = money(input.amount ?? Math.round(invoice.totalAmount * (input.basisPoints ?? 0) / 10000));
      const signedAmount = input.kind === 'CREDIT' ? -amount : amount;
      const totalAmount = money(invoice.totalAmount + signedAmount, true);
      if (totalAmount < invoice.paidAmount) billingError('CREDIT_EXCEEDS_OPEN_BALANCE', 'Release or reverse the excess allocation before issuing this credit.', true);
      const adjustment = await tx.invoiceAdjustment.create({ data: { invoiceId, kind: input.kind, category: input.category, amount, reason: input.reason.trim(), actorId: user.userId, lineId: randomUUID() } });
      const position = invoice.lineItems.reduce((highest, line) => Math.max(highest, line.position), -1) + 1;
      await tx.invoiceLineItem.create({ data: {
        id: adjustment.lineId, invoiceId, position, kind: input.kind === 'CREDIT' ? 'CREDIT_NOTE' : 'DEBIT_NOTE',
        description: `${input.category}: ${input.reason.trim()}`, quantity: 1, unit: 'lan', unitPrice: signedAmount,
        amount: signedAmount, source: 'ADJUSTMENT_NOTE', sourceId: adjustment.id,
      } });
      const updated = await tx.invoice.update({ where: { id: invoiceId }, data: { totalAmount, otherAmount: invoice.otherAmount + signedAmount, status: balanceStatus(invoice.paidAmount, totalAmount) }, include: invoiceInclude });
      await this.cancelLinks(tx, invoiceId);
      await billingEvent(tx, landlordId, input.kind === 'CREDIT' ? 'invoice.credit_note.created' : 'invoice.debit_note.created', invoiceId, `invoice.adjustment:${adjustment.id}`, { adjustmentId: adjustment.id, amount, reason: input.reason.trim() });
      return { data: this.billing.serializeInvoice(updated) };
    });
  }

  createReceipt(user: AuthUser, input: CreateReceiptDto) {
    const landlordId = landlordScopeId(user);
    money(input.amount);
    return this.commands.execute(user, 'billing.receipt.create', input.tenantId, input, async (tx) => {
      const tenant = await tx.tenant.findFirst({ where: { id: input.tenantId, landlordId, ...tenantScope() }, select: { id: true } });
      if (!tenant) throw new NotFoundException('Tenant not found.');
      const receipt = await tx.billingReceipt.create({ data: { landlordId, tenantId: input.tenantId, amount: input.amount, availableAmount: input.amount, method: input.method, reference: requiredReason(input.reference), paidAt: input.paidAt ? new Date(input.paidAt) : new Date(), actorId: user.userId } });
      await this.allocateLines(tx, receipt, input.allocations);
      await billingEvent(tx, landlordId, 'payment.receipt.created', receipt.id, `receipt.created:${receipt.id}`, { amount: receipt.amount, tenantId: receipt.tenantId });
      return { data: await this.receiptView(tx, receipt.id) };
    });
  }

  allocate(user: AuthUser, receiptId: string, input: AllocateReceiptDto) {
    const landlordId = landlordScopeId(user);
    return this.commands.execute(user, 'billing.receipt.allocate', receiptId, input, async (tx) => {
      const receipt = await this.lockReceipt(tx, landlordId, receiptId);
      await this.allocateLines(tx, receipt, input.allocations);
      await billingEvent(tx, landlordId, 'payment.allocated', receiptId, `receipt.allocated:${landlordId}:${input.requestKey}`, { receiptId, allocations: input.allocations.map((line) => ({ invoiceId: line.invoiceId, amount: line.amount })) });
      return { data: await this.receiptView(tx, receiptId) };
    });
  }

  release(user: AuthUser, receiptId: string, allocationId: string, input: BillingReasonDto) {
    const landlordId = landlordScopeId(user);
    requiredReason(input.reason);
    return this.commands.execute(user, 'billing.receipt.release', allocationId, input, async (tx) => {
      await this.lockReceipt(tx, landlordId, receiptId);
      const allocation = await tx.paymentAllocation.findFirst({ where: { id: allocationId, receiptId }, include: { payment: true } });
      if (!allocation) throw new NotFoundException('Allocation not found.');
      if (allocation.releasedAt) billingError('ALLOCATION_ALREADY_RELEASED', 'Allocation has already been released.', true);
      const invoice = await this.lockInvoice(tx, landlordId, allocation.payment.invoiceId);
      const paidAmount = invoice.paidAmount - allocation.amount;
      if (paidAmount < 0) billingError('PAYMENT_LEDGER_INCONSISTENT', 'Invoice payment ledger requires review.', true);
      await tx.payment.create({ data: { invoiceId: invoice.id, amount: -allocation.amount, method: allocation.payment.method, type: 'REVERSAL', reversalOfPaymentId: allocation.payment.id, note: input.reason.trim() } });
      await tx.paymentAllocation.update({ where: { id: allocationId }, data: { releasedAt: new Date(), releaseReason: input.reason.trim(), releasedBy: user.userId } });
      await tx.invoice.update({ where: { id: invoice.id }, data: { paidAmount, status: balanceStatus(paidAmount, invoice.totalAmount) } });
      await this.cancelLinks(tx, invoice.id);
      await tx.billingReceipt.update({ where: { id: receiptId }, data: { availableAmount: { increment: allocation.amount } } });
      await billingEvent(tx, landlordId, 'payment.allocation.released', receiptId, `allocation.released:${allocationId}`, { allocationId, invoiceId: invoice.id, amount: allocation.amount, reason: input.reason.trim() });
      return { data: await this.receiptView(tx, receiptId) };
    });
  }

  refund(user: AuthUser, receiptId: string, input: RefundReceiptDto) {
    const landlordId = landlordScopeId(user);
    money(input.amount); requiredReason(input.reason); requiredReason(input.reference);
    return this.commands.execute(user, 'billing.receipt.refund', receiptId, input, async (tx) => {
      const receipt = await this.lockReceipt(tx, landlordId, receiptId);
      if (input.amount > receipt.availableAmount) billingError('REFUND_EXCEEDS_AVAILABLE', 'Release the allocation first; only unallocated credit can be refunded.', true);
      const refund = await tx.billingRefund.create({ data: { receiptId, amount: input.amount, reason: input.reason.trim(), reference: input.reference.trim(), actorId: user.userId } });
      await tx.billingReceipt.update({ where: { id: receiptId }, data: { availableAmount: { decrement: input.amount }, refundedAmount: { increment: input.amount } } });
      await billingEvent(tx, landlordId, 'payment.refunded', receiptId, `refund.created:${refund.id}`, { refundId: refund.id, amount: input.amount, reference: input.reference.trim() });
      return { data: await this.receiptView(tx, receiptId) };
    });
  }

  async receipts(user: AuthUser, tenantId?: string) {
    const rows = await this.prisma.billingReceipt.findMany({ where: { landlordId: landlordScopeId(user), tenant: tenantScope(), ...(tenantId ? { tenantId } : {}) }, include: { allocations: { include: { payment: true }, orderBy: { createdAt: 'asc' } }, refunds: { orderBy: { createdAt: 'asc' } } }, orderBy: { paidAt: 'desc' }, take: 200 });
    return { data: rows };
  }

  async aging(user: AuthUser, query: AgingQueryDto, now = new Date()) {
    const landlordId = landlordScopeId(user);
    return this.prisma.$transaction(async (tx) => {
      const invoices = await tx.invoice.findMany({ where: { isDemo: false, status: { not: 'CANCELLED' }, ...(query.tenantId ? { tenantId: query.tenantId } : {}), ...(query.roomId ? { roomId: query.roomId } : {}), room: { ...(query.propertyId ? { propertyId: query.propertyId } : {}), property: propertyWhere(landlordId) } }, include: { room: { include: { property: true } }, tenant: true }, orderBy: [{ dueDate: 'asc' }, { id: 'asc' }] });
      const empty = () => ({ notDue: 0, overdue1To7: 0, overdue8To30: 0, overdueOver30: 0, undated: 0, total: 0, invoiceCount: 0 });
      const summary = empty();
      const groups = new Map<string, ReturnType<typeof empty> & { id: string; name: string }>();
      const items = [];
      for (const invoice of invoices) {
        const remaining = Math.max(invoice.totalAmount - invoice.paidAmount, 0);
        if (!remaining) continue;
        const bucket = agingBucket(invoice.dueDate, now);
        const groupBy = query.groupBy ?? 'tenant';
        const id = groupBy === 'property' ? invoice.room.propertyId : groupBy === 'room' ? invoice.roomId : invoice.tenantId;
        const name = groupBy === 'property' ? invoice.room.property.name : groupBy === 'room' ? invoice.room.name : invoice.tenant.fullName;
        const group = groups.get(id) ?? { id, name, ...empty() };
        summary[bucket] += remaining; summary.total += remaining; summary.invoiceCount++;
        group[bucket] += remaining; group.total += remaining; group.invoiceCount++; groups.set(id, group);
        items.push({ invoiceId: invoice.id, tenantId: invoice.tenantId, tenantName: invoice.tenant.fullName, roomId: invoice.roomId, roomName: invoice.room.name, propertyId: invoice.room.propertyId, propertyName: invoice.room.property.name, dueDate: invoice.dueDate, daysOverdue: invoice.dueDate ? Math.max(dueDays(invoice.dueDate, now), 0) : null, bucket, remainingAmount: remaining });
      }
      const credit = await tx.billingReceipt.aggregate({ where: { landlordId, tenant: tenantScope(), ...(query.tenantId ? { tenantId: query.tenantId } : {}) }, _sum: { availableAmount: true } });
      return { data: { asOf: businessDay(now), timezone: 'Asia/Ho_Chi_Minh', groupBy: query.groupBy ?? 'tenant', summary, groups: [...groups.values()].sort((left, right) => right.total - left.total), invoices: items, tenantUnallocatedCredit: query.propertyId || query.roomId ? null : credit._sum.availableAmount ?? 0 } };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  private async allocateLines(tx: Prisma.TransactionClient, receipt: BillingReceipt, lines: AllocationLineDto[]) {
    if (new Set(lines.map((line) => line.invoiceId)).size !== lines.length) billingError('DUPLICATE_ALLOCATION', 'Each invoice may appear only once.');
    const amount = lines.reduce((sum, line) => sum + money(line.amount), 0);
    if (amount > receipt.availableAmount) billingError('ALLOCATIONS_EXCEED_AVAILABLE', 'Allocations exceed unallocated receipt credit.', true);
    for (const line of [...lines].sort((left, right) => left.invoiceId.localeCompare(right.invoiceId))) {
      const invoice = await this.lockInvoice(tx, receipt.landlordId, line.invoiceId);
      this.collectible(invoice);
      if (invoice.tenantId !== receipt.tenantId) billingError('ALLOCATION_TENANT_MISMATCH', 'Payment and invoice must belong to the same tenant.');
      if (line.amount > invoice.totalAmount - invoice.paidAmount) billingError('PAYMENT_EXCEEDS_REMAINING', 'Allocation exceeds invoice balance.', true);
      const payment = await tx.payment.create({ data: { invoiceId: invoice.id, amount: line.amount, method: receipt.method, paidAt: receipt.paidAt, note: receipt.reference } });
      await tx.paymentAllocation.create({ data: { receiptId: receipt.id, paymentId: payment.id, amount: line.amount } });
      const paidAmount = invoice.paidAmount + line.amount;
      await tx.invoice.update({ where: { id: invoice.id }, data: { paidAmount, status: balanceStatus(paidAmount, invoice.totalAmount) } });
      await this.cancelLinks(tx, invoice.id);
    }
    if (amount) await tx.billingReceipt.update({ where: { id: receipt.id }, data: { availableAmount: { decrement: amount } } });
  }

  private async lockInvoice(tx: Prisma.TransactionClient, landlordId: string, invoiceId: string) {
    await tx.$queryRaw`SELECT i.id FROM "Invoice" i JOIN "Room" r ON r.id = i."roomId" JOIN "Property" p ON p.id = r."propertyId" WHERE i.id = ${invoiceId} AND p."landlordId" = ${landlordId} FOR UPDATE OF i`;
    const invoice = await tx.invoice.findFirst({ where: { id: invoiceId, room: { property: propertyWhere(landlordId) } }, include: invoiceInclude });
    if (!invoice) throw new NotFoundException('Invoice not found.');
    return invoice;
  }

  private async lockReceipt(tx: Prisma.TransactionClient, landlordId: string, receiptId: string) {
    await tx.$queryRaw`SELECT id FROM "BillingReceipt" WHERE id = ${receiptId} AND "landlordId" = ${landlordId} FOR UPDATE`;
    const receipt = await tx.billingReceipt.findFirst({ where: { id: receiptId, landlordId, tenant: tenantScope() } });
    if (!receipt) throw new NotFoundException('Receipt not found.');
    return receipt;
  }

  private receiptView(tx: Prisma.TransactionClient, id: string) {
    return tx.billingReceipt.findUniqueOrThrow({ where: { id }, include: { allocations: { include: { payment: true }, orderBy: { createdAt: 'asc' } }, refunds: { orderBy: { createdAt: 'asc' } } } });
  }

  private collectible(invoice: { isDemo: boolean; status: string }) {
    if (invoice.isDemo) billingError('DEMO_INVOICE', 'Demo invoices cannot use the production ledger.');
    if (invoice.status === 'CANCELLED') billingError('INVOICE_CANCELLED', 'Cancelled invoices cannot be changed.', true);
  }

  private async cancelLinks(tx: Prisma.TransactionClient, invoiceId: string) {
    await tx.paymentLink.updateMany({ where: { invoiceId, status: 'PENDING' }, data: { status: 'CANCELLED' } });
    await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
  }
}
