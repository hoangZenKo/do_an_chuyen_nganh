import { ConflictException } from '@nestjs/common';
import { Prisma, TurnoverStage } from '@prisma/client';

export const turnoverStages = [TurnoverStage.RETURNED, TurnoverStage.INSPECTION, TurnoverStage.REPAIR, TurnoverStage.CLEANING, TurnoverStage.READY];
export const turnoverTitles = ['Xác nhận trả phòng, nhận lại chìa khóa', 'Kiểm tra tài sản, chốt điện nước và tiền cọc', 'Xử lý hư hỏng hoặc xác nhận không cần sửa', 'Vệ sinh phòng và kiểm tra lần cuối', 'Sẵn sàng cho thuê'];

export async function beginTurnover(tx: Prisma.TransactionClient, landlordId: string, roomId: string, leaseId?: string, note?: string) {
  await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${roomId} FOR UPDATE`;
  const active = await tx.roomTurnover.findFirst({ where: { roomId, status: 'ACTIVE' } });
  if (active) throw new ConflictException('Phòng đang có quy trình bàn giao chưa hoàn tất.');
  const room = await tx.room.findUniqueOrThrow({ where: { id: roomId } });
  const turnover = await tx.roomTurnover.create({ data: {
    landlordId, propertyId: room.propertyId, roomId, leaseId, note,
    steps: { create: turnoverStages.slice(0, -1).map((stage, index) => ({ stage, title: turnoverTitles[index] })) },
  } });
  await tx.room.update({ where: { id: roomId }, data: { status: 'MAINTENANCE', tenantName: null } });
  await tx.roomListing.updateMany({ where: { roomId, status: 'PUBLISHED' }, data: { status: 'HIDDEN' } });
  return turnover;
}
