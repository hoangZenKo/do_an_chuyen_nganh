import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

export async function assertInventoryGrowth(tx: Prisma.TransactionClient, landlordId: string,
  kind: 'property' | 'room', amount = 1) {
  await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${landlordId} FOR UPDATE`;
  const subscription = await tx.landlordSubscription.findUnique({ where: { landlordId }, select: { planSnapshot: true, endsAt: true } });
  if (!subscription) return;
  if (subscription.endsAt && subscription.endsAt <= new Date()) {
    throw new ConflictException({ error: { code: 'SUBSCRIPTION_EXPIRED', message: 'Gói đã hết hạn. Gia hạn trước khi tăng số khu trọ/phòng; dữ liệu hiện có được giữ nguyên.' } });
  }
  const terms = subscription.planSnapshot as Record<string, unknown>;
  const limit = terms[kind === 'property' ? 'maxProperties' : 'maxRooms'];
  const count = kind === 'property'
    ? await tx.property.count({ where: { landlordId, isArchived: false } })
    : await tx.room.count({ where: { isActive: true, property: { landlordId, isArchived: false } } });
  if (typeof limit !== 'number' || !Number.isSafeInteger(limit) || limit < 1 || count + amount > limit) {
    throw new ConflictException({ error: { code: 'SUBSCRIPTION_LIMIT_REACHED', message: 'Vượt giới hạn gói đang được cấp. Đổi gói trước khi tăng số khu trọ/phòng.' } });
  }
}
