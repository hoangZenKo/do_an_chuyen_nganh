import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma, RoomStatus, ViewingStatus } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { LeasesService } from '../leases/leases.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateViewingDto, PilotFeedbackDto, RescheduleViewingDto, UpdateViewingDto, ViewingLeaseDto, ViewingSlotDto } from './housing.dto';

const pageSize = 20;
const available: Prisma.RoomListingWhereInput = {
  status: 'PUBLISHED',
  NOT: { description: { contains: '[explore-preview]' } },
  room: { isActive: true, status: RoomStatus.VACANT,
    property: { isArchived: false, landlord: { isActive: true } },
    leases: { none: { status: 'ACTIVE' } } },
};
const viewingInclude = {
  listing: { select: { id: true, title: true, monthlyRent: true, deposit: true,
    publicAddress: true, city: true, district: true,
    room: { select: { property: { select: { name: true } } } } } },
  student: { select: { fullName: true } },
  landlord: { select: { fullName: true } },
} satisfies Prisma.RoomViewingInclude;

@Injectable()
export class HousingService {
  constructor(private readonly prisma: PrismaService, private readonly leases: LeasesService,
    private readonly config: ConfigService) {}

  async favorites(userId: string, page: number) {
    const where = { userId };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.savedListing.count({ where }),
      this.prisma.savedListing.findMany({ where, orderBy: [{ createdAt: 'desc' }, { listingId: 'asc' }],
        skip: (page - 1) * pageSize, take: pageSize,
        select: { listingId: true, listing: { select: { title: true, monthlyRent: true, city: true,
          district: true, publicAddress: true, imageUrls: true } } } }),
    ]);
    const visible = await this.prisma.roomListing.findMany({
      where: { ...available, id: { in: rows.map((row) => row.listingId) } }, select: { id: true },
    });
    const visibleIds = new Set(visible.map((row) => row.id));
    return { data: rows.map((row) => ({ ...row.listing, id: row.listingId,
      available: visibleIds.has(row.listingId) })), meta: { total, page, limit: pageSize } };
  }

  async favorite(userId: string, listingId: string) {
    return { data: { saved: !!await this.prisma.savedListing.findUnique({
      where: { userId_listingId: { userId, listingId } }, select: { userId: true },
    }) } };
  }

  async saveFavorite(userId: string, listingId: string) {
    const listing = await this.prisma.roomListing.findFirst({ where: { id: listingId, ...available }, select: { id: true } });
    if (!listing) throw new NotFoundException('Tin đăng không còn nhận yêu cầu.');
    await this.prisma.savedListing.upsert({ where: { userId_listingId: { userId, listingId } },
      create: { userId, listingId }, update: {} });
    return { data: { saved: true } };
  }

  async removeFavorite(userId: string, listingId: string) {
    await this.prisma.savedListing.deleteMany({ where: { userId, listingId } });
    return { data: { saved: false } };
  }

  async viewings(user: AuthUser, page: number) {
    const where = this.scope(user);
    const [total, data] = await this.prisma.$transaction([
      this.prisma.roomViewing.count({ where }),
      this.prisma.roomViewing.findMany({ where, include: viewingInclude,
        orderBy: [{ scheduledAt: 'desc' }, { id: 'asc' }], skip: (page - 1) * pageSize, take: pageSize }),
    ]);
    return { data, meta: { total, page, limit: pageSize } };
  }

  async viewing(user: AuthUser, id: string) {
    const data = await this.prisma.roomViewing.findFirst({ where: { id, ...this.scope(user) }, include: viewingInclude });
    if (!data) throw new NotFoundException('Không tìm thấy lịch xem.');
    return { data };
  }

  async book(user: AuthUser, input: CreateViewingDto) {
    const scheduledAt = new Date(input.scheduledAt);
    this.checkTime(scheduledAt);
    return this.atomic(async (tx) => {
      const listing = await tx.roomListing.findFirst({ where: { id: input.listingId, ...available },
        include: { room: { select: { property: { select: { landlordId: true } } } } } });
      if (!listing) throw new NotFoundException('Tin đăng không còn nhận yêu cầu.');
      const landlordId = listing.room.property.landlordId;
      const endsAt = await this.reserveTime(tx, user.userId, landlordId, listing.id,
        listing.viewingSlotsRequired, scheduledAt, input.slotId);
      const created = await tx.roomViewing.create({ data: {
        listingId: listing.id, studentId: user.userId, landlordId, scheduledAt, endsAt, slotId: input.slotId,
        activeKey: `${user.userId}:${listing.id}`, note: input.note ?? '',
      }, include: viewingInclude });
      await this.notify(tx, landlordId, created.id, `Có yêu cầu xem phòng: ${listing.title}`);
      return { data: created };
    });
  }

  async slots(user: AuthUser, listingId: string) {
    const listing = await this.prisma.roomListing.findFirst({ where: {
      id: listingId, OR: [available, { room: { property: { landlordId: user.userId } } }],
    }, select: { viewingSlotsRequired: true, room: { select: { property: { select: { landlordId: true } } } } } });
    if (!listing) throw new NotFoundException('Tin đăng không còn nhận yêu cầu.');
    const now = new Date();
    const data = await this.prisma.viewingSlot.findMany({ where: { listingId, startsAt: {
      gte: new Date(now.getTime() + 15 * 60_000), lte: new Date(now.getTime() + 90 * 86400_000),
    } }, orderBy: { startsAt: 'asc' }, take: 200 });
    const busy = await this.prisma.roomViewing.findMany({ where: {
      status: { in: ['REQUESTED', 'CONFIRMED'] }, endsAt: { gt: now },
      OR: [{ landlordId: listing.room.property.landlordId }, { studentId: user.userId }],
    }, select: { scheduledAt: true, endsAt: true } });
    return { required: listing.viewingSlotsRequired, data: data.map((slot) => ({ ...slot,
      available: !busy.some((viewing) => viewing.scheduledAt < slot.endsAt && viewing.endsAt > slot.startsAt),
    })) };
  }

  async addSlot(user: AuthUser, listingId: string, input: ViewingSlotDto) {
    const startsAt = new Date(input.startsAt), endsAt = new Date(input.endsAt);
    this.checkTime(startsAt);
    const duration = endsAt.getTime() - startsAt.getTime();
    if (!Number.isFinite(duration) || duration < 15 * 60_000 || duration > 120 * 60_000) {
      throw new BadRequestException('Khung giờ phải dài từ 15 đến 120 phút.');
    }
    return this.atomic(async (tx) => {
      const listing = await tx.roomListing.findFirst({ where: { id: listingId,
        room: { property: { landlordId: user.userId } } } });
      if (!listing) throw new NotFoundException('Không tìm thấy tin đăng của bạn.');
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.userId} FOR UPDATE`;
      if (await tx.viewingSlot.count({ where: { listingId, startsAt: { gt: new Date() } } }) >= 200) {
        throw new ConflictException('Mỗi tin tối đa 200 khung giờ sắp tới.');
      }
      if (await tx.viewingSlot.findFirst({ where: { listing: { room: { property: { landlordId: user.userId } } },
        startsAt: { lt: endsAt }, endsAt: { gt: startsAt } } })) {
        throw new ConflictException('Khung giờ trùng với lịch mở xem khác của bạn.');
      }
      const data = await tx.viewingSlot.create({ data: { listingId, startsAt, endsAt } });
      await tx.roomListing.update({ where: { id: listingId }, data: { viewingSlotsRequired: true } });
      return { data };
    });
  }

  async removeSlot(user: AuthUser, id: string) {
    return this.atomic(async (tx) => {
      const slot = await tx.viewingSlot.findFirst({ where: { id, listing: { room: { property: { landlordId: user.userId } } } } });
      if (!slot) throw new NotFoundException('Không tìm thấy khung giờ.');
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${user.userId} FOR UPDATE`;
      if (await tx.roomViewing.count({ where: { slotId: id, status: { in: ['REQUESTED', 'CONFIRMED'] } } })) {
        throw new ConflictException('Khung giờ đã có người đặt. Hãy xử lý lịch hẹn trước.');
      }
      await tx.viewingSlot.delete({ where: { id } });
      return { data: { deleted: true } };
    });
  }

  async reschedule(user: AuthUser, id: string, input: RescheduleViewingDto) {
    const scheduledAt = new Date(input.scheduledAt);
    this.checkTime(scheduledAt);
    return this.atomic(async (tx) => {
      const viewing = await this.lockViewing(tx, user, id, input.version);
      if (viewing.studentId !== user.userId || !['REQUESTED', 'CONFIRMED'].includes(viewing.status)) {
        throw new ConflictException('Chỉ người đặt được đổi lịch đang chờ hoặc đã xác nhận.');
      }
      if (viewing.listingId !== input.listingId) throw new BadRequestException('Không thể đổi sang phòng khác.');
      const listing = await tx.roomListing.findFirst({ where: { id: viewing.listingId, ...available } });
      if (!listing) throw new ConflictException('Phòng không còn nhận lịch xem.');
      const endsAt = await this.reserveTime(tx, viewing.studentId, viewing.landlordId, listing.id,
        listing.viewingSlotsRequired, scheduledAt, input.slotId, id);
      if (scheduledAt.getTime() === viewing.scheduledAt.getTime() && endsAt.getTime() === viewing.endsAt.getTime()) {
        throw new BadRequestException('Chọn một khung giờ khác với lịch hiện tại.');
      }
      const data = await tx.roomViewing.update({ where: { id }, data: { scheduledAt, endsAt, slotId: input.slotId ?? null,
        status: 'REQUESTED', note: input.note ?? viewing.note, responseNote: '', reminderSentAt: null,
        version: { increment: 1 } }, include: viewingInclude });
      await this.notify(tx, viewing.landlordId, id, `Người xem đã đổi giờ ${data.listing.title}. Vui lòng xác nhận lại.`);
      await this.notify(tx, viewing.studentId, id, 'Đã gửi giờ hẹn mới. Chờ chủ trọ xác nhận lại trước khi tới.');
      return { data };
    });
  }

  private checkTime(date: Date) {
    const delta = date.getTime() - Date.now();
    if (!Number.isFinite(delta) || delta < 15 * 60_000 || delta > 90 * 86400_000) {
      throw new BadRequestException('Chọn lịch cách hiện tại ít nhất 15 phút, trong 90 ngày tới.');
    }
  }

  private async reserveTime(tx: Prisma.TransactionClient, studentId: string, landlordId: string,
    listingId: string, required: boolean, startsAt: Date, slotId?: string, excludeId?: string) {
    await tx.$queryRaw`SELECT id FROM "User" WHERE id IN (${studentId}, ${landlordId}) ORDER BY id FOR UPDATE`;
    let endsAt = new Date(startsAt.getTime() + 30 * 60_000);
    if (slotId) {
      const slot = await tx.viewingSlot.findFirst({ where: { id: slotId, listingId } });
      if (!slot || slot.startsAt.getTime() !== startsAt.getTime()) throw new ConflictException('Khung giờ không còn hợp lệ. Hãy tải lại.');
      endsAt = slot.endsAt;
    } else if (required) {
      throw new ConflictException('Chọn khung giờ do chủ trọ mở. Nếu hết chỗ, hãy chờ lịch mới.');
    }
    if (await tx.roomViewing.findFirst({ where: { id: excludeId ? { not: excludeId } : undefined,
      status: { in: ['REQUESTED', 'CONFIRMED'] }, scheduledAt: { lt: endsAt }, endsAt: { gt: startsAt },
      OR: [{ landlordId }, { studentId }],
    } })) throw new ConflictException('Bạn hoặc chủ trọ đã có lịch trùng giờ. Hãy chọn khung khác.');
    return endsAt;
  }

  async update(user: AuthUser, id: string, input: UpdateViewingDto) {
    return this.atomic(async (tx) => {
      const viewing = await this.lockViewing(tx, user, id, input.version);
      const landlord = user.role === AuthRole.LANDLORD;
      const valid = input.status === 'CANCELLED'
        ? ['REQUESTED', 'CONFIRMED'].includes(viewing.status)
        : landlord && ((input.status === 'CONFIRMED' && viewing.status === 'REQUESTED') ||
          (input.status === 'COMPLETED' && viewing.status === 'CONFIRMED'));
      if (!valid) throw new ConflictException('Không thể chuyển trạng thái lịch xem này.');
      if (input.status === 'CONFIRMED') {
        if (viewing.scheduledAt <= new Date()) throw new ConflictException('Lịch đã quá giờ. Hãy hủy và đặt lịch mới.');
        const listing = await tx.roomListing.findFirst({ where: { id: viewing.listingId, ...available } });
        if (!listing) throw new ConflictException('Phòng không còn nhận lịch xem.');
        await this.reserveTime(tx, viewing.studentId, viewing.landlordId, viewing.listingId,
          false, viewing.scheduledAt, viewing.slotId ?? undefined, id);
      }
      const updated = await tx.roomViewing.update({ where: { id }, data: {
        status: input.status, version: { increment: 1 }, responseNote: input.note ?? '',
        ...(input.status === 'CANCELLED' ? { cancellationReason: input.note?.trim() ||
          (landlord ? 'Chủ trọ đã hủy lịch.' : 'Người xem đã hủy lịch.') } : {}),
        ...(input.status === 'CANCELLED' || input.status === 'COMPLETED' ? { activeKey: null } : {}),
      }, include: viewingInclude });
      const labels = { CONFIRMED: 'được xác nhận', CANCELLED: 'được hủy', COMPLETED: 'hoàn tất' };
      await this.notify(tx, landlord ? viewing.studentId : viewing.landlordId, id,
        `Lịch xem ${updated.listing.title} đã ${labels[input.status]}.${input.status === 'CANCELLED' ? ` Lý do: ${updated.cancellationReason}` : ''}`);
      return { data: updated };
    });
  }

  async createLease(user: AuthUser, id: string, input: ViewingLeaseDto) {
    return this.atomic(async (tx) => {
      const viewing = await this.lockViewing(tx, user, id, input.version);
      if (viewing.status !== 'COMPLETED') throw new ConflictException('Chỉ tạo hợp đồng sau khi đã xem phòng.');
      const listing = await tx.roomListing.findFirst({ where: { id: viewing.listingId, ...available } });
      if (!listing) throw new ConflictException('Phòng không còn trống hoặc tin đã ngừng nhận khách.');
      const student = await tx.user.findUniqueOrThrow({ where: { id: viewing.studentId } });
      if (!student.isActive) throw new ConflictException('Tài khoản người thuê đã ngừng hoạt động.');
      const existing = await tx.tenant.findUnique({ where: { userId: student.id } });
      if (existing && (existing.landlordId !== user.userId || !existing.isActive)) {
        throw new ConflictException('Tài khoản đang liên kết hồ sơ khác. Cần xử lý hồ sơ trước khi tạo hợp đồng.');
      }
      const tenant = existing ?? await tx.tenant.create({ data: {
        userId: student.id, landlordId: user.userId, fullName: student.fullName, phone: student.phone,
      } });
      const lease = await this.leases.createWithinTransaction(tx, user.userId, {
        roomId: listing.roomId, tenantId: tenant.id, startDate: input.startDate,
        monthlyRent: input.monthlyRent, deposit: input.deposit,
      }, false);
      await tx.roomViewing.update({ where: { id }, data: {
        status: 'LEASED', leaseId: lease.id, version: { increment: 1 }, activeKey: null,
      } });
      await tx.roomListing.update({ where: { id: listing.id }, data: { status: 'HIDDEN', version: { increment: 1 } } });
      const others = await tx.roomViewing.findMany({ where: {
        listingId: listing.id, id: { not: id }, status: { in: ['REQUESTED', 'CONFIRMED'] },
      }, select: { id: true, studentId: true } });
      await tx.roomViewing.updateMany({ where: { id: { in: others.map((other) => other.id) } },
        data: { status: 'CANCELLED', activeKey: null, version: { increment: 1 }, responseNote: 'Phòng đã có người thuê.', cancellationReason: 'Phòng đã có người thuê.' } });
      for (const other of others) {
        await this.notify(tx, other.studentId, other.id, `Lịch xem ${listing.title} đã hủy vì phòng đã có người thuê.`);
      }
      await this.notify(tx, student.id, id, `Hợp đồng ${listing.title} đã được tạo. Xem tại Phòng đang thuê.`);
      await tx.auditLog.create({ data: { landlordId: user.userId, actorId: user.userId, actorRole: 'LANDLORD',
        action: 'lease.create', resourceType: 'lease', resourceId: lease.id,
        summary: 'Tạo hợp đồng từ lịch xem phòng', metadata: { viewingId: id, roomId: listing.roomId, tenantId: tenant.id } } });
      return { data: { leaseId: lease.id, tenantId: tenant.id } };
    });
  }

  async notifications(userId: string, page: number) {
    await this.sendViewingReminders(new Date(), userId);
    const where = { userId };
    const [total, unreadCount, data] = await this.prisma.$transaction([
      this.prisma.housingNotification.count({ where }),
      this.prisma.housingNotification.count({ where: { userId, readAt: null } }),
      this.prisma.housingNotification.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * pageSize, take: pageSize }),
    ]);
    return { data, unreadCount, meta: { total, page, limit: pageSize } };
  }

  async sendViewingReminders(now = new Date(), userId?: string) {
    const due = await this.prisma.roomViewing.findMany({ where: { status: 'CONFIRMED', reminderSentAt: null,
      scheduledAt: { gt: now, lte: new Date(now.getTime() + 24 * 3600_000) },
      ...(userId ? { OR: [{ studentId: userId }, { landlordId: userId }] } : {}),
    }, orderBy: { scheduledAt: 'asc' }, take: 200, select: { id: true } });
    for (const row of due) {
      await this.atomic(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "RoomViewing" WHERE id = ${row.id} FOR UPDATE`;
        const viewing = await tx.roomViewing.findUnique({ where: { id: row.id }, include: { listing: true } });
        if (!viewing || viewing.status !== 'CONFIRMED' || viewing.reminderSentAt || viewing.scheduledAt <= now ||
          viewing.scheduledAt.getTime() > now.getTime() + 24 * 3600_000) return;
        const time = viewing.scheduledAt.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
        for (const recipient of [viewing.studentId, viewing.landlordId]) {
          await this.notify(tx, recipient, viewing.id, `Nhắc lịch: ${viewing.listing.title}, ${time} (giờ Việt Nam). Xem chi tiết để đổi hoặc hủy nếu cần.`);
        }
        await tx.roomViewing.update({ where: { id: viewing.id }, data: { reminderSentAt: now } });
      });
    }
  }

  async readNotification(userId: string, id: string) {
    const result = await this.prisma.housingNotification.updateMany({ where: { id, userId, readAt: null }, data: { readAt: new Date() } });
    return { data: { updated: result.count > 0 } };
  }

  pilot() {
    const area = this.config.get<string>('RENTAL_PILOT_AREA')?.trim() ?? '';
    return { data: { enabled: area.length > 0, area } };
  }

  async feedback(userId: string, input: PilotFeedbackDto) {
    const pilot = this.pilot().data;
    if (!pilot.enabled || input.area !== pilot.area) throw new BadRequestException('Khu vực thử nghiệm chưa được mở hoặc đã thay đổi.');
    return { data: await this.prisma.pilotFeedback.create({ data: { userId, ...input } }) };
  }

  async feedbackList(page: number) {
    const [total, data, summary] = await this.prisma.$transaction([
      this.prisma.pilotFeedback.count(),
      this.prisma.pilotFeedback.findMany({ orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], skip: (page - 1) * pageSize, take: pageSize }),
      this.prisma.pilotFeedback.groupBy({ by: ['area', 'stage'], orderBy: [{ area: 'asc' }, { stage: 'asc' }], _count: true, _avg: { rating: true } }),
    ]);
    return { data, summary, meta: { total, page, limit: pageSize } };
  }

  private scope(user: AuthUser) {
    return user.role === AuthRole.LANDLORD ? { landlordId: user.userId } : { studentId: user.userId };
  }

  private async lockViewing(tx: Prisma.TransactionClient, user: AuthUser, id: string, version: number) {
    const viewing = await tx.roomViewing.findFirst({ where: { id, ...this.scope(user) } });
    if (!viewing) throw new NotFoundException('Không tìm thấy lịch xem.');
    await tx.$queryRaw`SELECT id FROM "RoomViewing" WHERE id = ${id} FOR UPDATE`;
    const current = await tx.roomViewing.findUniqueOrThrow({ where: { id } });
    if (current.version !== version) throw new ConflictException('Lịch đã thay đổi. Hãy tải lại.');
    return current;
  }

  private notify(tx: Prisma.TransactionClient, userId: string, viewingId: string, message: string) {
    return tx.housingNotification.create({ data: { userId, viewingId, message } });
  }

  private async atomic<T>(action: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.prisma.$transaction(action, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError) {
          const serialization = error.code === 'P2034' ||
            (error.code === 'P2010' && ['40001', '40P01'].includes(String(error.meta?.code)));
          if (serialization && attempt < 2) continue;
          if (error.code === 'P2002') throw new ConflictException('Đã có lịch đang chờ hoặc phòng vừa được đặt. Hãy tải lại danh sách.');
          if (serialization) throw new ConflictException('Dữ liệu vừa thay đổi. Hãy tải lại và thử lại.');
        }
        throw error;
      }
    }
  }
}
