import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { AdvanceTurnoverDto, CreateTurnoverDto, OperationsQuery } from './p1.dto';
import { beginTurnover, turnoverStages } from './turnover.workflow';

const include = { room: { select: { id: true, name: true } }, property: { select: { id: true, name: true } }, steps: true };

@Injectable()
export class TurnoversService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser, query: OperationsQuery) {
    const where = { landlordId: landlordScopeId(user), ...(query.propertyId ? { propertyId: query.propertyId } : {}), ...(query.roomId ? { roomId: query.roomId } : {}) };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.roomTurnover.findMany({ where, include, orderBy: [{ status: 'asc' }, { createdAt: 'desc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
      this.prisma.roomTurnover.count({ where }),
    ]);
    return { data, total, page: query.page, limit: query.limit };
  }

  async create(user: AuthUser, input: CreateTurnoverDto) {
    const landlordId = landlordScopeId(user);
    const data = await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${input.roomId} FOR UPDATE`;
      const room = await tx.room.findFirst({ where: { id: input.roomId, isActive: true, property: { landlordId, isArchived: false } } });
      if (!room) throw new NotFoundException('Không tìm thấy phòng đang hoạt động.');
      if (await tx.lease.count({ where: { roomId: room.id, status: 'ACTIVE' } })) throw new ConflictException('Kết thúc hợp đồng trước khi bắt đầu trả phòng.');
      const created = await beginTurnover(tx, landlordId, room.id, undefined, input.note?.trim());
      return tx.roomTurnover.findUniqueOrThrow({ where: { id: created.id }, include });
    });
    return { data };
  }

  async advance(user: AuthUser, id: string, input: AdvanceTurnoverDto) {
    return this.prisma.$transaction(async tx => {
      const owned = await tx.roomTurnover.findFirst({ where: { id, landlordId: landlordScopeId(user) } });
      if (!owned) throw new NotFoundException('Không tìm thấy quy trình trả phòng.');
      await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${owned.roomId} FOR UPDATE`;
      const current = await tx.roomTurnover.findUniqueOrThrow({ where: { id } });
      if (current.status !== 'ACTIVE' || current.version !== input.version || current.stage !== input.stage) throw new ConflictException('Quy trình đã thay đổi. Hãy tải lại.');
      if (await tx.lease.count({ where: { roomId: current.roomId, status: 'ACTIVE' } })) throw new ConflictException('Phòng đã có hợp đồng đang thuê.');
      const nextStage = turnoverStages[turnoverStages.indexOf(current.stage) + 1];
      if (!nextStage) throw new ConflictException('Quy trình đã hoàn tất.');
      const now = new Date();
      await tx.turnoverStep.update({ where: { turnoverId_stage: { turnoverId: id, stage: current.stage } }, data: { completedAt: now, completedBy: user.userId, note: input.note.trim() } });
      const complete = nextStage === 'READY';
      if (complete || current.stage === 'REPAIR') {
        const pendingRepairs = await tx.maintenanceTicket.count({ where: { roomId: current.roomId, status: { in: ['OPEN', 'IN_PROGRESS'] } } });
        if (pendingRepairs) throw new ConflictException('Còn phiếu sửa chữa chưa xử lý. Hoàn tất sửa chữa trước khi cho thuê lại.');
      }
      const data = await tx.roomTurnover.update({ where: { id }, data: { stage: nextStage, version: { increment: 1 }, ...(complete ? { status: 'COMPLETED', completedAt: now } : {}) }, include });
      if (complete) await tx.room.update({ where: { id: current.roomId }, data: { status: 'VACANT', tenantName: null } });
      return { data };
    });
  }
}
