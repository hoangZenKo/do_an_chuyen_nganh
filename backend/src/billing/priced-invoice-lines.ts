import { MeterReading, Prisma } from '@prisma/client';
import { effectiveFeesByRoom } from '../rooms/service-tariff';
import { buildInvoiceLines } from './invoice-lines';
import { money } from './billing-rules';
import { UtilityTier, utilityCharges } from './utility-pricing';

export async function pricedInvoiceLines(tx: Prisma.TransactionClient, lease: { id: string; roomId: string; monthlyRent: number }, readings: MeterReading[], month: Date, otherAmount = 0) {
  const fees = await effectiveFeesByRoom(tx, [lease.roomId], month);
  const base = buildInvoiceLines(lease, readings, fees.get(lease.roomId) ?? [], otherAmount);
  if (!tx.billingTariffVersion) return base;
  const room = await tx.room.findUniqueOrThrow({ where: { id: lease.roomId }, select: { propertyId: true } });
  const tariffs = await tx.billingTariffVersion.findMany({ where: { propertyId: room.propertyId, kind: { in: ['ELECTRICITY', 'WATER'] }, state: 'APPROVED', effectiveFrom: { lte: month }, OR: [{ roomId: lease.roomId }, { roomId: null }] }, orderBy: [{ effectiveFrom: 'desc' }, { version: 'desc' }] });
  const lines = base.lines.filter((line) => !['ELECTRICITY', 'WATER'].includes(line.kind));
  for (const reading of [...readings].sort((left, right) => left.utilityType.localeCompare(right.utilityType))) {
    const tariff = tariffs.find((row) => row.kind === reading.utilityType && row.roomId === lease.roomId) ?? tariffs.find((row) => row.kind === reading.utilityType && !row.roomId);
    if (!tariff || !tariff.isActive) {
      lines.push(...base.lines.filter((line) => line.kind === reading.utilityType)); continue;
    }
    const charges = utilityCharges(reading.usage, tariff.amount, tariff.tiers as unknown as UtilityTier[]);
    for (const [index, part] of charges.entries()) lines.push({
      ...part, position: 0, kind: reading.utilityType,
      description: `${tariff.name}${charges.length > 1 ? ` - bac ${index + 1}` : ''}`,
      unit: tariff.unit, source: tariff.roomId ? 'ROOM_UTILITY_TARIFF' : 'PROPERTY_UTILITY_TARIFF',
      sourceId: tariff.id, tariffVersion: tariff.version, tariffVersionId: null,
    });
  }
  const totalFor = (kinds: string[]) => lines.filter((line) => kinds.includes(line.kind)).reduce((sum, line) => sum + line.amount, 0);
  return { lines: lines.map((line, position) => ({ ...line, position })), rentAmount: totalFor(['RENT']), electricityAmount: totalFor(['ELECTRICITY']), waterAmount: totalFor(['WATER']), otherAmount: totalFor(['SERVICE', 'OTHER']), totalAmount: money(lines.reduce((sum, line) => sum + line.amount, 0), true) };
}
