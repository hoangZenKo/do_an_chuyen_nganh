import { BadRequestException } from '@nestjs/common';
import { Prisma, RoomServiceFee, ServiceTariffVersion } from '@prisma/client';
import { serviceKey } from '../billing/tariff-key';

export const tariffVersionsInclude = {
  versions: { orderBy: { effectiveFrom: 'desc' as const } },
};

export type VersionedServiceFee = RoomServiceFee & {
  versions?: ServiceTariffVersion[];
};

export function businessMonth(now = new Date()) {
  const local = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  return new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1));
}

export function tariffMonth(value: string | undefined, fallback: Date) {
  if (!value) return fallback;
  if (!/^\d{4}-\d{2}-01(?:T00:00:00(?:\.000)?Z)?$/.test(value)) {
    throw new BadRequestException({ error: { code: 'INVALID_TARIFF_MONTH', message: 'Choose the first day of a billing month (YYYY-MM-01).' } });
  }
  const date = new Date(value);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value.slice(0, 10)) {
    throw new BadRequestException({ error: { code: 'INVALID_TARIFF_MONTH', message: 'Invalid billing month.' } });
  }
  return date;
}

export interface EffectiveServiceFee {
  id: string;
  roomId: string;
  name: string;
  amount: number;
  unit: string;
  tariffVersionId: string | null;
  tariffVersion: number | null;
  source?: string;
}

export function effectiveFee(fee: VersionedServiceFee, month: Date): EffectiveServiceFee | null {
  const versions = fee.versions ?? [];
  const selected = versions.filter((version) => version.effectiveFrom <= month)
    .sort((left, right) => right.effectiveFrom.getTime() - left.effectiveFrom.getTime())[0];
  if (versions.length && !selected) return null;
  const isActive = selected ? selected.isActive : fee.isActive !== false;
  if (!isActive) return null;
  return {
    id: fee.id, roomId: fee.roomId,
    name: selected?.name ?? fee.name, amount: selected?.amount ?? fee.amount,
    unit: selected?.unit ?? 'thang',
    tariffVersionId: selected?.id ?? null, tariffVersion: selected?.version ?? null,
    source: selected && !selected.id.startsWith('baseline:') ? 'SERVICE_TARIFF' : 'LEGACY_FEE',
  };
}

export async function effectiveFeesByRoom(
  client: Pick<Prisma.TransactionClient, 'roomServiceFee'> & Partial<Pick<Prisma.TransactionClient, 'billingTariffVersion' | 'room'>>,
  roomIds: string[], month: Date,
) {
  const fees = roomIds.length ? await client.roomServiceFee.findMany({
    where: { roomId: { in: roomIds } },
    include: tariffVersionsInclude,
    orderBy: { name: 'asc' },
  }) : [];
  const grouped = new Map<string, NonNullable<ReturnType<typeof effectiveFee>>[]>();
  for (const fee of fees) {
    const selected = effectiveFee(fee, month);
    if (!selected) continue;
    const roomFees = grouped.get(fee.roomId) ?? [];
    roomFees.push(selected);
    grouped.set(fee.roomId, roomFees);
  }
  if (!roomIds.length || !client.billingTariffVersion || !client.room) return grouped;
  const rooms = await client.room.findMany({ where: { id: { in: roomIds } }, select: { id: true, propertyId: true } });
  const tariffs = await client.billingTariffVersion.findMany({ where: { propertyId: { in: [...new Set(rooms.map((room) => room.propertyId))] }, kind: 'SERVICE', state: 'APPROVED', effectiveFrom: { lte: month } }, orderBy: [{ effectiveFrom: 'desc' }, { version: 'desc' }] });
  for (const room of rooms) {
    const inherited = new Map<string, NonNullable<ReturnType<typeof effectiveFee>>>();
    const apply = (scopeKey: string) => {
      const seen = new Set<string>();
      for (const tariff of tariffs.filter((item) => item.scopeKey === scopeKey)) {
        if (seen.has(tariff.serviceKey)) continue;
        seen.add(tariff.serviceKey);
        if (!tariff.isActive) inherited.delete(tariff.serviceKey);
        else inherited.set(tariff.serviceKey, { id: tariff.id, roomId: room.id, name: tariff.name, amount: tariff.amount, unit: tariff.unit, tariffVersionId: null, tariffVersion: tariff.version, source: tariff.roomId ? 'ROOM_TARIFF' : 'PROPERTY_TARIFF' });
      }
    };
    apply(`property:${room.propertyId}`);
    for (const fee of fees.filter((item) => item.roomId === room.id)) {
      const selected = effectiveFee(fee, month);
      if (fee.versions?.some((version) => version.effectiveFrom <= month && !version.id.startsWith('baseline:'))) {
        if (selected) inherited.set(serviceKey(selected.name), selected);
        else inherited.delete(serviceKey(fee.versions.find((version) => version.effectiveFrom <= month)?.name ?? fee.name));
      } else if (selected && !inherited.has(serviceKey(selected.name))) inherited.set(serviceKey(selected.name), selected);
    }
    apply(`room:${room.id}`);
    grouped.set(room.id, [...inherited.values()].sort((left, right) => left.name.localeCompare(right.name)));
  }
  return grouped;
}
