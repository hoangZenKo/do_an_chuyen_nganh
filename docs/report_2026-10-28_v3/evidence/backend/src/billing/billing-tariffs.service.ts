import { propertyWhere, scopedPropertyIds } from '../common/property-scope';
import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { businessMonth, tariffMonth } from '../rooms/service-tariff';
import { BillingCommandsService } from './billing-commands.service';
import { billingEvent } from './billing-events';
import { billingError, requiredReason } from './billing-rules';
import { InvoicePreviewDto, LockBillingPeriodDto, ProposeTariffDto, ReviewTariffDto } from './dto/billing-tariffs.dto';
import { pricedInvoiceLines } from './priced-invoice-lines';
import { validateTiers } from './utility-pricing';
import { serviceKey } from './tariff-key';

@Injectable()
export class BillingTariffsService {
  constructor(private readonly prisma: PrismaService, private readonly commands: BillingCommandsService) {}

  async list(user: AuthUser, propertyId: string) {
    if (typeof propertyId !== 'string' || !propertyId.trim()) billingError('TARIFF_PROPERTY_REQUIRED', 'Choose a property before listing tariffs.');
    await this.property(this.prisma, landlordScopeId(user), propertyId);
    return { data: await this.prisma.billingTariffVersion.findMany({ where: { propertyId, landlordId: landlordScopeId(user) }, orderBy: [{ effectiveFrom: 'desc' }, { version: 'desc' }] }) };
  }

  propose(user: AuthUser, input: ProposeTariffDto) {
    const landlordId = landlordScopeId(user);
    const effectiveFrom = tariffMonth(input.effectiveFrom, businessMonth());
    if (effectiveFrom < businessMonth()) billingError('TARIFF_BACKDATED', 'Tariffs cannot be backdated.');
    validateTiers(input.tiers);
    if (input.kind === 'SERVICE' && input.tiers.length) billingError('SERVICE_TIERS_UNSUPPORTED', 'Fixed service charges cannot have usage tiers.');
    const key = input.kind === 'SERVICE' ? serviceKey(input.serviceKey) : input.kind.toLowerCase();
    if (!key || !input.name.trim() || !input.unit.trim()) billingError('INVALID_TARIFF', 'Tariff key, name and unit are required.');
    const scopeKey = input.roomId ? `room:${input.roomId}` : `property:${input.propertyId}`;
    return this.commands.execute(user, 'billing.tariff.propose', scopeKey, input, async (tx) => {
      await this.lockProperty(tx, landlordId, input.propertyId);
      if (input.roomId && !(await tx.room.findFirst({ where: { id: input.roomId, propertyId: input.propertyId, isActive: true }, select: { id: true } }))) throw new NotFoundException('Room not found.');
      const previous = await tx.billingTariffVersion.aggregate({ where: { scopeKey, serviceKey: key }, _max: { version: true } });
      const tariff = await tx.billingTariffVersion.create({ data: { landlordId, propertyId: input.propertyId, roomId: input.roomId ?? null, scopeKey, serviceKey: key, name: input.name.trim(), kind: input.kind, unit: input.unit.trim(), amount: input.amount, tiers: input.tiers.map((tier) => ({ upTo: tier.upTo ?? null, unitPrice: tier.unitPrice })), effectiveFrom, version: (previous._max.version ?? 0) + 1, makerId: user.userId, isActive: input.isActive, reason: requiredReason(input.reason) } });
      await billingEvent(tx, landlordId, 'tariff.proposed', tariff.id, `tariff.proposed:${tariff.id}`, { propertyId: tariff.propertyId, version: tariff.version });
      return { data: tariff };
    });
  }

  async impact(user: AuthUser, id: string) {
    const ids = scopedPropertyIds();
    const tariff = await this.prisma.billingTariffVersion.findFirst({ where: { id, landlordId: landlordScopeId(user), ...(ids ? { propertyId: { in: ids } } : {}) } });
    if (!tariff) throw new NotFoundException('Tariff not found.');
    const [rooms, previous, issuedInvoices, lockedPeriods, latest, overrides] = await Promise.all([
      this.prisma.room.findMany({ where: { propertyId: tariff.propertyId, ...(tariff.roomId ? { id: tariff.roomId } : {}), isActive: true }, select: { id: true, name: true } }),
      this.prisma.billingTariffVersion.findFirst({ where: { id: { not: tariff.id }, scopeKey: tariff.scopeKey, serviceKey: tariff.serviceKey, state: 'APPROVED', effectiveFrom: { lte: tariff.effectiveFrom } }, orderBy: [{ effectiveFrom: 'desc' }, { version: 'desc' }] }),
      this.prisma.invoice.count({ where: { isDemo: false, billingMonth: { gte: tariff.effectiveFrom }, room: { propertyId: tariff.propertyId, ...(tariff.roomId ? { id: tariff.roomId } : {}) } } }),
      this.prisma.billingPeriodLock.count({ where: { propertyId: tariff.propertyId, month: { gte: tariff.effectiveFrom } } }),
      this.prisma.billingTariffVersion.findFirst({ where: { scopeKey: tariff.scopeKey, serviceKey: tariff.serviceKey, state: 'APPROVED' }, orderBy: [{ effectiveFrom: 'desc' }, { version: 'desc' }] }),
      tariff.roomId ? Promise.resolve([]) : this.prisma.billingTariffVersion.findMany({ where: { propertyId: tariff.propertyId, roomId: { not: null }, serviceKey: tariff.serviceKey, state: 'APPROVED', effectiveFrom: { lte: tariff.effectiveFrom } }, select: { roomId: true } }),
    ]);
    const overrideIds = new Set(overrides.map((row) => row.roomId));
    const blockingReasons = [
      ...(issuedInvoices ? ['ISSUED_INVOICES'] : []),
      ...(lockedPeriods ? ['LOCKED_PERIODS'] : []),
      ...(tariff.state !== 'PROPOSED' ? ['ALREADY_REVIEWED'] : []),
      ...(tariff.effectiveFrom < businessMonth() ? ['BACKDATED'] : []),
      ...(latest && latest.effectiveFrom >= tariff.effectiveFrom ? ['EFFECTIVE_ORDER'] : []),
    ];
    return { data: { proposed: tariff, previous, rooms: rooms.filter((room) => !overrideIds.has(room.id)), overriddenRooms: rooms.filter((room) => overrideIds.has(room.id)), issuedInvoices, lockedPeriods, blockingReasons, canApprove: !blockingReasons.length } };
  }

  review(user: AuthUser, id: string, input: ReviewTariffDto) {
    return this.commands.execute(user, 'billing.tariff.review', id, input, async (tx) => {
      const ids = scopedPropertyIds();
      const tariff = await tx.billingTariffVersion.findFirst({ where: { id, landlordId: landlordScopeId(user), ...(ids ? { propertyId: { in: ids } } : {}) } });
      if (!tariff) throw new NotFoundException('Tariff not found.');
      await this.lockProperty(tx, landlordScopeId(user), tariff.propertyId);
      const current = await tx.billingTariffVersion.findUniqueOrThrow({ where: { id } });
      if (current.state !== 'PROPOSED') billingError('TARIFF_ALREADY_REVIEWED', 'Tariff proposal has already been reviewed.', true);
      if (input.decision === 'APPROVED') {
        if (current.effectiveFrom < businessMonth()) billingError('TARIFF_BACKDATED', 'Tariff effective month is in the past.');
        const [issued, locked, latest] = await Promise.all([
          tx.invoice.count({ where: { isDemo: false, billingMonth: { gte: current.effectiveFrom }, room: { propertyId: current.propertyId, ...(current.roomId ? { id: current.roomId } : {}) } } }),
          tx.billingPeriodLock.count({ where: { propertyId: current.propertyId, month: { gte: current.effectiveFrom } } }),
          tx.billingTariffVersion.findFirst({ where: { scopeKey: current.scopeKey, serviceKey: current.serviceKey, state: 'APPROVED' }, orderBy: { effectiveFrom: 'desc' } }),
        ]);
        if (issued || locked) billingError('TARIFF_PERIOD_CLOSED', 'Tariff affects an invoiced or locked billing period.', true);
        if (latest && latest.effectiveFrom >= current.effectiveFrom) billingError('TARIFF_EFFECTIVE_ORDER', 'Approved versions require a later effective month.', true);
      }
      const reviewed = await tx.billingTariffVersion.update({ where: { id }, data: { state: input.decision, checkerId: user.userId, reviewReason: requiredReason(input.reason), reviewedAt: new Date() } });
      await billingEvent(tx, landlordScopeId(user), 'tariff.reviewed', id, `tariff.reviewed:${id}`, { state: input.decision, propertyId: tariff.propertyId });
      return { data: reviewed };
    });
  }

  lockPeriod(user: AuthUser, input: LockBillingPeriodDto) {
    const month = tariffMonth(input.month, businessMonth());
    return this.commands.execute(user, 'billing.period.lock', input.propertyId, input, async (tx) => {
      await this.lockProperty(tx, landlordScopeId(user), input.propertyId);
      const lock = await tx.billingPeriodLock.upsert({ where: { propertyId_month: { propertyId: input.propertyId, month } }, create: { propertyId: input.propertyId, month, reason: requiredReason(input.reason), actorId: user.userId }, update: {} });
      return { data: lock };
    });
  }

  async preview(user: AuthUser, input: InvoicePreviewDto) {
    const billingMonth = tariffMonth(input.billingMonth, businessMonth());
    return this.prisma.$transaction(async (tx) => {
      const lease = await tx.lease.findFirst({ where: { id: input.leaseId, room: { property: propertyWhere(landlordScopeId(user)) } } });
      if (!lease) throw new NotFoundException('Lease not found.');
      const readings = await tx.meterReading.findMany({ where: { roomId: lease.roomId, billingMonth } });
      const result = await pricedInvoiceLines(tx, lease, readings, billingMonth, input.otherAmount ?? 0);
      return { data: { ...result, leaseId: lease.id, billingMonth, preview: true, missingUtilities: ['ELECTRICITY', 'WATER'].filter((kind) => !readings.some((reading) => reading.utilityType === kind)) } };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  private async property(client: Pick<Prisma.TransactionClient, 'property'>, landlordId: string, id: string) {
    const property = await client.property.findFirst({ where: { id, ...propertyWhere(landlordId), isArchived: false }, select: { id: true } });
    if (!property) throw new NotFoundException('Property not found.');
    return property;
  }

  private async lockProperty(tx: Prisma.TransactionClient, landlordId: string, id: string) {
    await tx.$queryRaw`SELECT id FROM "Property" WHERE id = ${id} AND "landlordId" = ${landlordId} FOR UPDATE`;
    return this.property(tx, landlordId, id);
  }
}
