import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { HandoverDto } from './housing.dto';

@Injectable()
export class HandoverService {
  constructor(private readonly prisma: PrismaService) {}

  private async lease(client: Prisma.TransactionClient, user: AuthUser, id: string) {
    const lease = await client.lease.findFirst({ where: { id,
      ...(user.role === AuthRole.LANDLORD ? { room: { property: { landlordId: user.userId } } }
        : { tenant: { userId: user.userId } }),
    }, include: { handover: true, depositTransactions: true, tenant: true,
      room: { include: { property: true } } } });
    if (!lease) throw new NotFoundException('Không tìm thấy hợp đồng.');
    return lease;
  }

  async get(user: AuthUser, leaseId: string) {
    const lease = await this.lease(this.prisma, user, leaseId);
    const sum = (type: string) => lease.depositTransactions.filter((item) => item.type === type)
      .reduce((total, item) => total + item.amount, 0);
    const collected = sum('COLLECTED'), refunded = sum('REFUNDED'), deducted = sum('DEDUCTED'), adjustment = sum('ADJUSTMENT');
    return { data: { leaseId: lease.id, roomName: lease.room.name, propertyName: lease.room.property.name,
      status: lease.status, startDate: lease.startDate, handover: lease.handover,
      deposit: { agreed: lease.deposit, collected, refunded, deducted, adjustment,
        balance: collected + adjustment - refunded - deducted },
    } };
  }

  async save(user: AuthUser, leaseId: string, input: HandoverDto) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${leaseId} FOR UPDATE`;
      const lease = await this.lease(tx, user, leaseId);
      if (lease.status !== 'ACTIVE') throw new ConflictException('Chỉ lập bàn giao cho hợp đồng đang hiệu lực.');
      if (lease.handover?.acceptedAt) throw new ConflictException('Biên bản đã được người thuê xác nhận, không thể sửa.');
      if ((lease.handover?.version ?? 0) !== input.version) throw new ConflictException('Biên bản đã thay đổi. Hãy tải lại.');
      const filenames = input.imageUrls.map((url) => url.slice('/uploads/'.length));
      const images = await tx.uploadedFile.count({ where: { filename: { in: filenames }, ownerId: user.userId,
        purpose: 'PRIVATE', mimeType: { startsWith: 'image/' } } });
      if (images !== filenames.length) throw new BadRequestException('Chỉ dùng ảnh riêng tư do bạn tải lên cho bàn giao.');
      const data = await tx.leaseHandover.upsert({ where: { leaseId },
        create: { leaseId, electricity: input.electricity, water: input.water, condition: input.condition, imageUrls: input.imageUrls },
        update: { electricity: input.electricity, water: input.water, condition: input.condition,
          imageUrls: input.imageUrls, version: { increment: 1 } },
      });
      await tx.auditLog.create({ data: { landlordId: user.userId, actorId: user.userId, actorRole: 'LANDLORD',
        action: 'handover.save', resourceType: 'lease', resourceId: leaseId, summary: 'Lập/cập nhật biên bản bàn giao',
        metadata: { version: data.version, electricity: data.electricity, water: data.water, photoCount: data.imageUrls.length } } });
      await this.notify(tx, leaseId, lease.tenant.userId, 'Biên bản bàn giao đã sẵn sàng. Kiểm tra hiện trạng và chỉ xác nhận khi thực sự nhận phòng.');
      return { data };
    });
  }

  async accept(user: AuthUser, leaseId: string, version: number) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${leaseId} FOR UPDATE`;
      const lease = await this.lease(tx, user, leaseId);
      if (lease.status !== 'ACTIVE' || lease.startDate > new Date()) throw new ConflictException('Hợp đồng chưa đến ngày nhận phòng hoặc đã kết thúc.');
      const handover = lease.handover;
      if (!handover) throw new ConflictException('Chủ trọ chưa lập biên bản bàn giao.');
      if (handover.acceptedAt || handover.version !== version) throw new ConflictException('Biên bản đã thay đổi hoặc đã xác nhận. Hãy tải lại.');
      const data = await tx.leaseHandover.update({ where: { leaseId },
        data: { acceptedAt: new Date(), version: { increment: 1 } } });
      await tx.auditLog.create({ data: { landlordId: lease.room.property.landlordId, actorId: user.userId, actorRole: 'TENANT',
        action: 'handover.accept', resourceType: 'lease', resourceId: leaseId, summary: 'Người thuê xác nhận nhận phòng',
        metadata: { version: data.version } } });
      await this.notify(tx, leaseId, lease.room.property.landlordId, 'Người thuê đã xác nhận nhận phòng và biên bản bàn giao.');
      return { data };
    });
  }

  private async notify(tx: Prisma.TransactionClient, leaseId: string, userId: string | null, message: string) {
    if (!userId) return;
    const viewing = await tx.roomViewing.findUnique({ where: { leaseId } });
    if (viewing) await tx.housingNotification.create({ data: { userId, viewingId: viewing.id, message } });
  }
}
