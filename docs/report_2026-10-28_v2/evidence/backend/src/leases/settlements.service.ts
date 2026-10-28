import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DepositTransactionType, Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { requestContext } from '../common/request-context';
import { PrismaService } from '../prisma/prisma.service';
import { beginTurnover } from '../operations/turnover.workflow';
import { ConfirmLeaseSettlementDto, LeaseSettlementDto, RecordSettlementRefundDto } from './dto/lease-settlement.dto';

const include = { depositTransactions: true, handover: true, settlement: { include: { lines: { orderBy: { createdAt: 'asc' as const } } } } } as const;
type SettlementLease = Prisma.LeaseGetPayload<{ include: typeof include }>;
type Settlement = NonNullable<SettlementLease['settlement']>;

export function settlementMoney(value: number) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 2147483647) throw new BadRequestException('Số tiền vượt giới hạn hợp lệ.');
  return value;
}

export function proratedSettlementRent(monthlyRent: number, startDate: Date, moveOutDate: Date) {
  const monthStart = new Date(Date.UTC(moveOutDate.getUTCFullYear(), moveOutDate.getUTCMonth(), 1));
  const daysInMonth = new Date(Date.UTC(moveOutDate.getUTCFullYear(), moveOutDate.getUTCMonth() + 1, 0)).getUTCDate();
  const occupiedStart = startDate > monthStart ? new Date(startDate.toISOString().slice(0, 10)) : monthStart;
  const occupiedDays = Math.floor((moveOutDate.getTime() - occupiedStart.getTime()) / 86400000) + 1;
  if (occupiedDays < 1 || occupiedDays > daysInMonth) throw new BadRequestException('Khoảng ngày thuê không hợp lệ.');
  const amount = Number((BigInt(settlementMoney(monthlyRent)) * BigInt(occupiedDays) + BigInt(Math.floor(daysInMonth / 2))) / BigInt(daysInMonth));
  return { amount: settlementMoney(amount), occupiedDays, daysInMonth };
}

@Injectable()
export class LeaseSettlementsService {
  constructor(private readonly prisma: PrismaService) {}

  private owner(actor: AuthUser) {
    if (actor.role !== AuthRole.LANDLORD) throw new ForbiddenException('Chỉ chủ trọ được quyết toán và ghi nhận hoàn cọc.');
    return actor.userId;
  }

  async get(actor: AuthUser, leaseId: string) {
    const lease = await this.findOwned(this.owner(actor), leaseId, this.prisma);
    return { data: lease.settlement ? this.serialize(lease.settlement) : null };
  }

  async getForTenant(userId: string, leaseId: string) {
    const lease = await this.prisma.lease.findFirst({
      where: { id: leaseId, tenant: { userId, isActive: true, landlord: { isActive: true } } },
      include,
    });
    if (!lease) throw new NotFoundException('Không tìm thấy hợp đồng.');
    return { data: lease.settlement ? this.serialize(lease.settlement) : null };
  }

  async preview(actor: AuthUser, leaseId: string, input: LeaseSettlementDto) {
    const ownerId = this.owner(actor);
    return this.prisma.$transaction(async tx => {
      const lease = await this.findOwned(ownerId, leaseId, tx);
      return { data: await this.calculate(lease, input, tx) };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  async confirm(actor: AuthUser, leaseId: string, input: ConfirmLeaseSettlementDto) {
    const ownerId = this.owner(actor);
    return this.write(async tx => {
      const lease = await this.locked(ownerId, leaseId, tx);
      if (lease.settlement) {
        if (lease.settlement.requestKey !== input.idempotencyKey || lease.settlement.requestHash !== this.requestHash(input) || lease.settlement.previewFingerprint !== input.previewFingerprint) {
          throw new ConflictException('Hợp đồng đã được quyết toán bằng request khác.');
        }
        return { data: this.serialize(lease.settlement), idempotent: true };
      }
      await tx.$queryRaw`SELECT id FROM "Invoice" WHERE "leaseId" = ${leaseId} FOR UPDATE`;
      const calculated = await this.calculate(lease, input, tx);
      if (calculated.previewFingerprint !== input.previewFingerprint) throw new ConflictException('Dữ liệu đã thay đổi. Hãy xem trước lại quyết toán.');
      if (await tx.leaseSettlement.findUnique({ where: { landlordId_requestKey: { landlordId: ownerId, requestKey: input.idempotencyKey } } })) {
        throw new ConflictException('Mã request đã được sử dụng cho hợp đồng khác.');
      }
      const settlement = await tx.leaseSettlement.create({ data: {
        leaseId, landlordId: ownerId, moveOutDate: new Date(calculated.moveOutDate), rentAmount: calculated.rentAmount,
        electricityAmount: calculated.electricityAmount, waterAmount: calculated.waterAmount, otherCharges: calculated.otherCharges,
        totalCharges: calculated.totalCharges, depositBalance: calculated.depositBalance, depositApplied: calculated.depositApplied,
        refundAmount: calculated.refundAmount, refundStatus: calculated.refundAmount > 0 ? 'PENDING' : 'NOT_DUE',
        balanceDue: calculated.balanceDue, outstandingInvoiceAmount: calculated.outstandingInvoiceAmount,
        requestKey: input.idempotencyKey, requestHash: this.requestHash(input), previewFingerprint: calculated.previewFingerprint,
        snapshot: calculated, note: input.note?.trim() || null, lines: { create: calculated.lines },
      }, include: { lines: { orderBy: { createdAt: 'asc' } } } });
      if (calculated.depositApplied > 0) await tx.depositTransaction.create({ data: {
        leaseId, landlordId: ownerId, type: 'DEDUCTED', amount: calculated.depositApplied,
        note: `Cấn trừ chi phí quyết toán ${settlement.id}; không cấn trừ hóa đơn cũ.`,
      } });
      await tx.lease.update({ where: { id: leaseId }, data: { status: 'ENDED', endDate: new Date(calculated.moveOutDate) } });
      if (await tx.lease.count({ where: { roomId: lease.roomId, status: 'ACTIVE' } })) throw new ConflictException('Phòng có hợp đồng đang hiệu lực khác.');
      await beginTurnover(tx, ownerId, lease.roomId, leaseId, 'Tạo từ quyết toán trả phòng.');
      await this.audit(tx, actor, leaseId, 'lease.settlement_confirm', 'Xác nhận quyết toán; chưa chuyển tiền hoàn cọc.', {
        settlementId: settlement.id, totalCharges: calculated.totalCharges, depositApplied: calculated.depositApplied,
        refundAmount: calculated.refundAmount, balanceDue: calculated.balanceDue,
      });
      return { data: this.serialize(settlement), idempotent: false };
    });
  }

  async recordRefund(actor: AuthUser, leaseId: string, input: RecordSettlementRefundDto) {
    const ownerId = this.owner(actor);
    return this.write(async tx => {
      const lease = await this.locked(ownerId, leaseId, tx);
      const settlement = lease.settlement;
      if (!settlement) throw new NotFoundException('Chưa có quyết toán cho hợp đồng.');
      if (settlement.refundStatus === 'PAID') {
        if (settlement.refundRequestKey === input.idempotencyKey && settlement.refundReference === input.reference.trim()) return { data: this.serialize(settlement), idempotent: true };
        throw new ConflictException('Khoản hoàn cọc đã được ghi nhận.');
      }
      if (settlement.version !== input.version || settlement.refundStatus !== 'PENDING') throw new ConflictException('Quyết toán đã thay đổi hoặc không có khoản cần hoàn.');
      if (this.depositBalance(lease) !== settlement.refundAmount) throw new ConflictException('Số dư cọc đã thay đổi. Không thể tự động ghi nhận hoàn.');
      await tx.depositTransaction.create({ data: { leaseId, landlordId: ownerId, type: 'REFUNDED', amount: settlement.refundAmount,
        note: `${input.reference.trim()} · ${input.reason.trim()}` } });
      const updated = await tx.leaseSettlement.update({ where: { id: settlement.id }, data: {
        refundStatus: 'PAID', refundReference: input.reference.trim(), refundPaidAt: new Date(), refundRequestKey: input.idempotencyKey, version: { increment: 1 },
      }, include: { lines: { orderBy: { createdAt: 'asc' } } } });
      await this.audit(tx, actor, leaseId, 'lease.settlement_refund_recorded', input.reason.trim(), {
        settlementId: settlement.id, amount: settlement.refundAmount, reference: input.reference.trim(),
      });
      return { data: this.serialize(updated), idempotent: false };
    });
  }

  private async findOwned(ownerId: string, leaseId: string, client: PrismaService | Prisma.TransactionClient) {
    const lease = await client.lease.findFirst({ where: { id: leaseId, room: { property: { landlordId: ownerId } } }, include });
    if (!lease) throw new NotFoundException('Không tìm thấy hợp đồng.');
    return lease;
  }

  private async locked(ownerId: string, leaseId: string, tx: Prisma.TransactionClient) {
    const owned = await this.findOwned(ownerId, leaseId, tx);
    await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${owned.roomId} FOR UPDATE`;
    await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${leaseId} FOR UPDATE`;
    return this.findOwned(ownerId, leaseId, tx);
  }

  private async calculate(lease: SettlementLease, input: LeaseSettlementDto, tx: Prisma.TransactionClient) {
    if (lease.status !== 'ACTIVE' || lease.settlement) throw new ConflictException('Chỉ xem trước hợp đồng chưa quyết toán và còn hiệu lực.');
    const moveOutDate = this.date(input.moveOutDate);
    const today = new Date(new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10));
    if (moveOutDate < this.date(lease.startDate.toISOString().slice(0, 10)) || moveOutDate > today) throw new BadRequestException('Ngày trả phải sau ngày bắt đầu và không ở tương lai.');
    const monthStart = new Date(Date.UTC(moveOutDate.getUTCFullYear(), moveOutDate.getUTCMonth(), 1));
    const invoices = await tx.invoice.findMany({ where: { leaseId: lease.id, isDemo: false, status: { not: 'CANCELLED' } },
      select: { id: true, billingMonth: true, totalAmount: true, paidAmount: true, status: true, updatedAt: true }, orderBy: { id: 'asc' } });
    if (invoices.some(invoice => invoice.billingMonth > monthStart)) throw new ConflictException('Còn hóa đơn sau tháng trả phòng. Xử lý hóa đơn trước khi quyết toán.');
    const monthAlreadyBilled = invoices.some(invoice => invoice.billingMonth.getTime() === monthStart.getTime());
    const rent = proratedSettlementRent(lease.monthlyRent, lease.startDate, moveOutDate);
    const utilities = await Promise.all([
      this.utility(tx, lease, 'ELECTRICITY', input.finalElectricity, input.electricityUnitPrice, monthStart),
      this.utility(tx, lease, 'WATER', input.finalWater, input.waterUnitPrice, monthStart),
    ]);
    const rentAmount = monthAlreadyBilled ? 0 : rent.amount;
    const electricityAmount = utilities[0].amount;
    const waterAmount = utilities[1].amount;
    const otherCharges = settlementMoney(input.lines.reduce((sum, line) => sum + settlementMoney(line.amount), 0));
    const totalCharges = settlementMoney(rentAmount + electricityAmount + waterAmount + otherCharges);
    const depositBalance = this.depositBalance(lease);
    const depositApplied = Math.min(depositBalance, totalCharges);
    const outstandingInvoiceAmount = settlementMoney(invoices.reduce((sum, invoice) => sum + Math.max(invoice.totalAmount - invoice.paidAmount, 0), 0));
    const balanceDue = totalCharges - depositApplied;
    const lines = [
      { kind: 'RENT', description: monthAlreadyBilled ? 'Tiền thuê tháng đã có hóa đơn: không thu lại' : `Tiền thuê ${rent.occupiedDays}/${rent.daysInMonth} ngày (gồm ngày trả)`, amount: rentAmount },
      { kind: 'ELECTRICITY', description: 'Điện phát sinh từ chỉ số gần nhất', amount: electricityAmount },
      { kind: 'WATER', description: 'Nước phát sinh từ chỉ số gần nhất', amount: waterAmount },
      ...input.lines.map(line => ({ kind: line.kind, description: line.description.trim(), amount: line.amount })),
    ];
    const snapshot = { moveOutDate: moveOutDate.toISOString(), occupiedDays: rent.occupiedDays, daysInMonth: rent.daysInMonth,
      monthAlreadyBilled, rentAmount, electricityAmount, waterAmount, otherCharges, totalCharges, depositBalance, depositApplied,
      refundAmount: depositBalance - depositApplied, balanceDue, outstandingInvoiceAmount,
      totalOutstanding: settlementMoney(balanceDue + outstandingInvoiceAmount), utilities, lines,
      warnings: ['Công nợ hóa đơn cũ hiển thị riêng, không tự cấn trừ cọc và không tự ghi thanh toán.',
        'Số dư phải thu của quyết toán được lưu riêng; không tự tạo hoặc sửa hóa đơn.',
        ...(monthAlreadyBilled ? ['Đã có hóa đơn tháng trả: tiền thuê không tính lại; không tự hoàn tiền thuê thừa.'] : [])],
    };
    const fingerprint = this.hash({ request: this.requestHash(input), lease: { id: lease.id, updatedAt: lease.updatedAt.toISOString() },
      ledger: lease.depositTransactions.map(entry => entry.id).sort(), invoices, snapshot });
    return { ...snapshot, previewFingerprint: fingerprint };
  }

  private async utility(tx: Prisma.TransactionClient, lease: SettlementLease, kind: 'ELECTRICITY' | 'WATER', finalReading: number | undefined, explicitPrice: number | undefined, monthStart: Date) {
    if (finalReading === undefined) return { kind, previousReading: null, finalReading: null, usage: 0, unitPrice: 0, amount: 0, baselineId: null };
    const previous = await tx.meterReading.findFirst({ where: { roomId: lease.roomId, utilityType: kind }, orderBy: [{ billingMonth: 'desc' }, { id: 'desc' }] });
    if (previous && previous.billingMonth > monthStart) throw new ConflictException('Đã ghi chỉ số sau tháng trả phòng. Hãy kiểm tra lại.');
    const previousReading = previous?.currentReading ?? (kind === 'ELECTRICITY' ? lease.handover?.electricity : lease.handover?.water);
    if (previousReading === undefined) throw new BadRequestException('Cần chỉ số bàn giao hoặc chỉ số đã ghi trước khi chốt điện nước.');
    if (finalReading < previousReading) throw new BadRequestException('Chỉ số cuối không được nhỏ hơn chỉ số gần nhất.');
    const usage = finalReading - previousReading;
    const unitPrice = explicitPrice ?? previous?.unitPrice;
    if (usage > 0 && (!unitPrice || unitPrice < 0)) throw new BadRequestException('Cần đơn giá điện/nước rõ ràng khi có phát sinh.');
    return { kind, previousReading, finalReading, usage, unitPrice: unitPrice ?? 0, amount: settlementMoney(usage * (unitPrice ?? 0)), baselineId: previous?.id ?? lease.handover?.id ?? null };
  }

  private depositBalance(lease: SettlementLease) {
    return settlementMoney(lease.depositTransactions.reduce((sum, entry) =>
      entry.type === DepositTransactionType.COLLECTED || entry.type === DepositTransactionType.ADJUSTMENT ? sum + entry.amount : sum - entry.amount, 0));
  }

  private date(value: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new BadRequestException('Ngày trả dùng định dạng YYYY-MM-DD.');
    const date = new Date(value);
    if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) throw new BadRequestException('Ngày trả không hợp lệ.');
    return date;
  }

  private serialize(settlement: Settlement) {
    const { requestKey, requestHash, refundRequestKey, ...data } = settlement;
    return data;
  }

  private requestHash(input: LeaseSettlementDto) {
    return this.hash({ moveOutDate: input.moveOutDate, finalElectricity: input.finalElectricity ?? null, finalWater: input.finalWater ?? null,
      electricityUnitPrice: input.electricityUnitPrice ?? null, waterUnitPrice: input.waterUnitPrice ?? null,
      lines: input.lines.map(line => ({ kind: line.kind, description: line.description.trim(), amount: line.amount })), note: input.note?.trim() || null });
  }

  private hash(value: unknown) { return createHash('sha256').update(JSON.stringify(value)).digest('hex'); }

  private async audit(tx: Prisma.TransactionClient, actor: AuthUser, leaseId: string, action: string, summary: string, metadata: Prisma.InputJsonValue) {
    await tx.auditLog.create({ data: { landlordId: actor.userId, actorId: actor.userId, actorRole: 'LANDLORD', action,
      resourceType: 'lease_settlement', resourceId: leaseId, summary, metadata, requestId: requestContext.getStore()?.requestId } });
  }

  private async write<T>(operation: (tx: Prisma.TransactionClient) => Promise<T>) {
    try { return await this.prisma.$transaction(operation, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }); }
    catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && ['P2034', 'P2002'].includes(error.code)) throw new ConflictException('Dữ liệu đang được thay đổi. Tải lại hoặc gửi lại cùng request.');
      throw error;
    }
  }
}
