import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit } from '../admin/admin-audit';
import { FinanceLinesQueryDto, FinanceProposalDto, FinanceProposalReviewDto, FinanceStatementImportDto } from './finance-reconciliation.dto';

const RECONCILE = 'admin.finance.reconcile';

@Injectable()
export class FinanceReconciliationService {
  constructor(private readonly prisma: PrismaService) {}
  private require(actor: AuthUser) {
    if (actor.role !== 'admin' || !actor.permissions?.includes(RECONCILE)) throw new ForbiddenException();
  }

  async importStatement(actor: AuthUser, input: FinanceStatementImportDto) {
    this.require(actor);
    const dates = input.lines.map(line => new Date(line.occurredAt));
    if (dates.some(date => !Number.isFinite(date.getTime()))) throw new ConflictException('Invalid statement date.');
    if (new Set(input.lines.map(line => line.externalId)).size !== input.lines.length) throw new ConflictException('Duplicate external transaction IDs.');
    const canonical = JSON.stringify([input.propertyId, input.accountKey, input.lines.map(line => [line.externalId, line.amount, new Date(line.occurredAt).toISOString(), line.reference])]);
    const contentHash = createHash('sha256').update(canonical).digest('hex');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102602)::text`;
      const property = await tx.property.findUnique({ where: { id: input.propertyId }, select: { id: true } });
      if (!property) throw new NotFoundException('Property not found.');
      const existing = await tx.financeStatement.findUnique({ where: { importKey: input.importKey } });
      if (existing) {
        if (existing.contentHash !== contentHash) throw new ConflictException('Import key already used with different content.');
        return { data: { id: existing.id, duplicate: true, matched: await tx.financeStatementLine.count({ where: { statementId: existing.id, status: 'MATCHED' } }) } };
      }
      if (await tx.financeStatement.findFirst({ where: { accountKey: input.accountKey, propertyId: { not: input.propertyId } } })) throw new ConflictException('Account alias belongs to another property.');
      if (await tx.financeStatementLine.count({ where: { accountKey: input.accountKey, externalId: { in: input.lines.map(line => line.externalId) } } })) throw new ConflictException('Statement contains previously imported transactions.');
      const statement = await tx.financeStatement.create({ data: { propertyId: input.propertyId, accountKey: input.accountKey, importKey: input.importKey, contentHash, importedBy: actor.userId } });
      let matched = 0;
      for (const [index, line] of input.lines.entries()) {
        const candidate = await this.findCandidate(tx, input.propertyId, line.amount, dates[index], line.reference);
        const saved = await tx.financeStatementLine.create({ data: { statementId: statement.id, propertyId: input.propertyId, accountKey: input.accountKey, externalId: line.externalId, amount: line.amount, occurredAt: dates[index], reference: line.reference, ...(candidate ? { status: 'MATCHED', ...candidate } : {}) } });
        if (candidate) {
          matched++;
          await adminAudit(tx, actor, 'admin.finance.auto_matched', 'finance_statement_line', saved.id, input.reason, candidate);
        }
      }
      await adminAudit(tx, actor, 'admin.finance.statement_imported', 'finance_statement', statement.id, input.reason, { lines: input.lines.length, matched, contentHash });
      return { data: { id: statement.id, duplicate: false, lines: input.lines.length, matched, unmatched: input.lines.length - matched } };
    }, { timeout: 30000 });
  }

  private async findCandidate(tx: Prisma.TransactionClient, propertyId: string, amount: number, occurredAt: Date, reference: string) {
    const tokens = reference.split(/[^a-zA-Z0-9_-]+/).filter(Boolean);
    if (!tokens.length) return null;
    const paidAt = { gte: new Date(occurredAt.getTime() - 72 * 3600000), lte: new Date(occurredAt.getTime() + 72 * 3600000) };
    const receipts = await tx.billingReceipt.findMany({ where: { ...this.receiptScope(propertyId, amount), id: { in: tokens }, paidAt }, take: 2 });
    const candidates = await tx.payment.findMany({ where: { amount, method: 'BANK_TRANSFER', type: 'PAYMENT', reversalPayment: null, statementLine: null, allocation: null,
      OR: [{ id: { in: tokens } }, { invoiceId: { in: tokens } }],
      paidAt, invoice: { isDemo: false, room: { propertyId } } }, take: 2 });
    if (receipts.length + candidates.length !== 1) return null;
    return receipts.length ? { receiptId: receipts[0].id } : { paymentId: candidates[0].id };
  }

  private receiptScope(propertyId: string, amount: number): Prisma.BillingReceiptWhereInput {
    return {
      amount, method: 'BANK_TRANSFER', statementLine: null,
      landlord: { properties: { some: { id: propertyId } } },
      tenant: { leases: { some: { room: { propertyId } } } },
      allocations: { none: { OR: [
        { payment: { statementLine: { isNot: null } } },
        { releasedAt: null, payment: { invoice: { OR: [{ isDemo: true }, { room: { propertyId: { not: propertyId } } }] } } },
      ] } },
    };
  }

  private async validateReceipt(tx: Prisma.TransactionClient, receiptId: string, propertyId: string, amount: number) {
    await tx.$queryRaw`SELECT id FROM "BillingReceipt" WHERE id = ${receiptId} FOR UPDATE`;
    const receipt = await tx.billingReceipt.findFirst({ where: { id: receiptId, ...this.receiptScope(propertyId, amount) } });
    if (!receipt) throw new ConflictException('Receipt changed, is outside this property, or is already matched.');
  }

  async candidates(actor: AuthUser, id: string) {
    this.require(actor);
    const line = await this.prisma.financeStatementLine.findUnique({ where: { id } });
    if (!line) throw new NotFoundException('Statement line not found.');
    const [receipts, payments] = await Promise.all([
      this.prisma.billingReceipt.findMany({ where: this.receiptScope(line.propertyId, line.amount), include: { tenant: { select: { fullName: true } } }, orderBy: { paidAt: 'desc' }, take: 50 }),
      this.prisma.payment.findMany({ where: { amount: line.amount, method: 'BANK_TRANSFER', type: 'PAYMENT', reversalPayment: null, statementLine: null, allocation: null, invoice: { isDemo: false, room: { propertyId: line.propertyId } } }, orderBy: { paidAt: 'desc' }, take: 50 }),
    ]);
    return { data: [
      ...receipts.map(receipt => ({ kind: 'RECEIPT', id: receipt.id, amount: receipt.amount, paidAt: receipt.paidAt, reference: receipt.reference, tenantName: receipt.tenant.fullName, availableAmount: receipt.availableAmount })),
      ...payments.map(payment => ({ kind: 'PAYMENT', id: payment.id, amount: payment.amount, paidAt: payment.paidAt, reference: payment.note, invoiceId: payment.invoiceId })),
    ] };
  }

  async lines(actor: AuthUser, query: FinanceLinesQueryDto) {
    if (actor.role !== 'admin' || !actor.permissions?.includes('admin.finance.read')) throw new ForbiddenException();
    return { data: await this.prisma.financeStatementLine.findMany({ where: { ...(query.status ? { status: query.status } : {}), ...(query.propertyId ? { propertyId: query.propertyId } : {}) }, include: { receipt: { select: { id: true, tenantId: true, amount: true, availableAmount: true, refundedAmount: true } }, statement: { select: { importKey: true, accountKey: true } }, proposals: { orderBy: { createdAt: 'desc' }, take: 3 } }, orderBy: { occurredAt: 'desc' }, take: query.limit }) };
  }

  async propose(actor: AuthUser, id: string, input: FinanceProposalDto) {
    this.require(actor);
    if (!['MATCH_PAYMENT', 'MATCH_RECEIPT', 'MARK_REVIEWED', 'UNMATCH'].includes(input.action)) throw new ConflictException('Unsupported reconciliation action.');
    if (input.action === 'MATCH_PAYMENT' && !input.paymentId) throw new ConflictException('Payment is required.');
    if (input.action === 'MATCH_RECEIPT' && !input.receiptId) throw new ConflictException('Receipt is required.');
    if ((input.paymentId && input.action !== 'MATCH_PAYMENT') || (input.receiptId && input.action !== 'MATCH_RECEIPT')) throw new ConflictException('Reconciliation must have exactly one matching target.');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102602)::text`;
      const line = await tx.financeStatementLine.findUnique({ where: { id } });
      if (!line || line.version !== input.lineVersion) throw new ConflictException('Statement line changed.');
      if (line.status === 'MATCHED' && input.action !== 'UNMATCH') throw new ConflictException('Line already matched.');
      if (input.action === 'UNMATCH' && line.status !== 'MATCHED') throw new ConflictException('Only matched lines can be unmatched.');
      if (await tx.financeReconciliationProposal.findFirst({ where: { lineId: id, status: 'PENDING' } })) throw new ConflictException('Line already has a pending proposal.');
      if (input.paymentId) {
        const payment = await tx.payment.findFirst({ where: { id: input.paymentId, method: 'BANK_TRANSFER', type: 'PAYMENT', reversalPayment: null, allocation: null, invoice: { room: { propertyId: line.propertyId }, isDemo: false } } });
        if (!payment) throw new NotFoundException('Payment not found in property.');
        if (payment.amount !== line.amount) throw new ConflictException('Payment amount does not match statement.');
        if (await tx.financeStatementLine.findFirst({ where: { paymentId: input.paymentId, id: { not: id } } })) throw new ConflictException('Payment already matched.');
      }
      if (input.receiptId) await this.validateReceipt(tx, input.receiptId, line.propertyId, line.amount);
      const proposal = await tx.financeReconciliationProposal.create({ data: { lineId: id, paymentId: input.paymentId, receiptId: input.receiptId, action: input.action, lineVersion: line.version, reason: input.reason, makerId: actor.userId } });
      await adminAudit(tx, actor, 'admin.finance.reconciliation_proposed', 'finance_statement_line', id, input.reason, { proposalId: proposal.id, action: input.action });
      return { data: proposal };
    });
  }

  async proposals(actor: AuthUser) {
    this.require(actor);
    return { data: await this.prisma.financeReconciliationProposal.findMany({ where: { status: 'PENDING' }, include: { line: { select: { id: true, amount: true, reference: true, status: true, version: true, propertyId: true } } }, orderBy: { createdAt: 'asc' }, take: 200 }) };
  }

  async review(actor: AuthUser, id: string, input: FinanceProposalReviewDto, approve: boolean) {
    this.require(actor);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102602)::text`;
      const proposal = await tx.financeReconciliationProposal.findUnique({ where: { id }, include: { line: true } });
      if (!proposal || proposal.status !== 'PENDING') throw new ConflictException('Proposal already reviewed.');
      if (proposal.makerId === actor.userId) throw new ForbiddenException('Maker cannot approve own proposal.');
      if (input.version !== proposal.line.version || input.version !== proposal.lineVersion) throw new ConflictException('Statement line changed.');
      if (approve && proposal.action === 'MATCH_PAYMENT') {
        const payment = await tx.payment.findFirst({ where: { id: proposal.paymentId!, amount: proposal.line.amount, method: 'BANK_TRANSFER', type: 'PAYMENT', reversalPayment: null, statementLine: null, allocation: null, invoice: { isDemo: false, room: { propertyId: proposal.line.propertyId } } } });
        if (!payment) throw new ConflictException('Payment changed, reversed or already matched.');
      }
      if (approve && proposal.action === 'MATCH_RECEIPT') await this.validateReceipt(tx, proposal.receiptId!, proposal.line.propertyId, proposal.line.amount);
      if (!approve) {
        const rejected = await tx.financeReconciliationProposal.update({ where: { id }, data: { status: 'REJECTED', checkerId: actor.userId, reviewReason: input.reason, reviewedAt: new Date() } });
        await adminAudit(tx, actor, 'admin.finance.reconciliation_rejected', 'finance_reconciliation_proposal', id, input.reason);
        return { data: rejected };
      }
      const nextStatus = ['MATCH_PAYMENT', 'MATCH_RECEIPT'].includes(proposal.action) ? 'MATCHED' : proposal.action === 'UNMATCH' ? 'UNMATCHED' : 'NEEDS_REVIEW';
      const line = await tx.financeStatementLine.update({ where: { id: proposal.lineId }, data: { status: nextStatus, paymentId: proposal.action === 'MATCH_PAYMENT' ? proposal.paymentId : null, receiptId: proposal.action === 'MATCH_RECEIPT' ? proposal.receiptId : null, version: { increment: 1 } } });
      const approved = await tx.financeReconciliationProposal.update({ where: { id }, data: { status: 'APPROVED', checkerId: actor.userId, reviewReason: input.reason, reviewedAt: new Date() } });
      await adminAudit(tx, actor, 'admin.finance.reconciliation_approved', 'finance_reconciliation_proposal', id, input.reason, { lineId: line.id, status: line.status });
      return { data: { proposal: approved, line } };
    });
  }
}
