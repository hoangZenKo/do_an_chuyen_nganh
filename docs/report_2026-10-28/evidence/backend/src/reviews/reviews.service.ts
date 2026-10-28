import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, RoomReview } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { assertModerationAssignment } from '../common/moderation-assignment';
import { recordModerationDecision } from '../common/moderation-decision';
import { ModerateRoomReviewDto, ReviewContentDto, ReviewPageQuery, ReviewQueueQuery, ReviewReplyDto, UpdateRoomReviewDto } from './reviews.dto';

const leaseInclude = { handover: true, viewing: { select: { id: true } }, tenant: true,
  room: { include: { property: true } } } satisfies Prisma.LeaseInclude;
type ReviewLease = Prisma.LeaseGetPayload<{ include: typeof leaseInclude }>;
const managementInclude = { room: { select: { name: true, property: { select: { name: true, landlordId: true } } } } } satisfies Prisma.RoomReviewInclude;

@Injectable()
export class ReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  private verification(lease: ReviewLease) {
    const now = new Date();
    if (lease.startDate > now) return null;
    if (lease.handover?.acceptedAt && lease.handover.acceptedAt <= now) {
      return { verificationSource: 'HANDOVER', tenancyVerifiedAt: lease.handover.acceptedAt };
    }
    if (!lease.viewing && lease.status === 'ENDED' && lease.endDate && lease.endDate <= now &&
        lease.endDate.getTime() - lease.startDate.getTime() >= 86400_000) {
      return { verificationSource: 'COMPLETED_LEASE', tenancyVerifiedAt: lease.endDate };
    }
    return null;
  }

  private async ownedLease(tx: Prisma.TransactionClient, userId: string, leaseId: string) {
    const lease = await tx.lease.findFirst({ where: { id: leaseId, tenant: { userId } }, include: leaseInclude });
    if (!lease) throw new NotFoundException('Không tìm thấy hợp đồng của bạn.');
    return lease;
  }

  private key(lease: ReviewLease, authorId: string) {
    return { authorId, roomId: lease.roomId, landlordId: lease.tenant.landlordId };
  }

  async context(user: AuthUser, leaseId: string) {
    const lease = await this.ownedLease(this.prisma, user.userId, leaseId);
    const review = await this.prisma.roomReview.findUnique({ where: { authorId_roomId_landlordId: this.key(lease, user.userId) } });
    const verified = this.verification(lease);
    return { data: { leaseId, roomName: lease.room.name, propertyName: lease.room.property.name,
      eligible: !!verified || !!review,
      reason: verified || review ? null : 'Cần xác nhận nhận phòng trong biên bản bàn giao. Với hợp đồng cũ không qua lịch xem, hợp đồng phải đã kết thúc và có thời gian thuê ít nhất một ngày.',
      review: review ? this.privateView(review, true) : null } };
  }

  async create(user: AuthUser, leaseId: string, input: ReviewContentDto) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${leaseId} FOR UPDATE`;
        const lease = await this.ownedLease(tx, user.userId, leaseId);
        const verified = this.verification(lease);
        if (!verified) throw new ConflictException('Chưa đủ lịch sử thuê hoặc chưa xác nhận nhận phòng.');
        const data = await tx.roomReview.create({ data: { leaseId, ...this.key(lease, user.userId), ...verified,
          roomRating: input.roomRating, costRating: input.costRating, landlordRating: input.landlordRating,
          areaRating: input.areaRating, body: input.body } });
        await this.audit(tx, user, data, 'review.create', 'Gửi đánh giá sau khi thuê');
        return { data: this.privateView(data, true) };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Bạn đã đánh giá phòng này với chủ trọ này. Hãy tải lại và chỉnh sửa đánh giá đã có.');
      }
      throw error;
    }
  }

  async update(user: AuthUser, id: string, input: UpdateRoomReviewDto) {
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx, id, input.version, { authorId: user.userId });
      const data = await tx.roomReview.update({ where: { id }, data: {
        roomRating: input.roomRating, costRating: input.costRating, landlordRating: input.landlordRating,
        areaRating: input.areaRating, body: input.body, status: 'PENDING', withdrawnAt: null,
        moderationNote: null, reviewedAt: null, reviewedById: null, version: { increment: 1 },
        replyBody: null, replyStatus: null, replyModerationNote: null,
        replyReviewedAt: null, replyReviewedById: null,
      } });
      await this.audit(tx, user, data, 'review.update', 'Sửa đánh giá, chờ kiểm duyệt lại');
      return { data: this.privateView(data, true) };
    });
  }

  async withdraw(user: AuthUser, id: string, version: number) {
    return this.prisma.$transaction(async (tx) => {
      const current = await this.lock(tx, id, version, { authorId: user.userId });
      if (current.withdrawnAt) throw new ConflictException('Đánh giá đã được gỡ.');
      const data = await tx.roomReview.update({ where: { id }, data: {
        status: 'HIDDEN', withdrawnAt: new Date(), version: { increment: 1 },
      } });
      await this.audit(tx, user, data, 'review.withdraw', 'Người thuê gỡ đánh giá khỏi công khai');
      return { data: this.privateView(data, true) };
    });
  }

  async reply(user: AuthUser, id: string, input: ReviewReplyDto) {
    return this.prisma.$transaction(async (tx) => {
      const current = await this.lock(tx, id, input.version, { landlordId: user.userId,
        room: { property: { landlordId: user.userId } } });
      if (current.status !== 'APPROVED' || current.withdrawnAt) throw new ConflictException('Chỉ phản hồi đánh giá đang được công khai.');
      const data = await tx.roomReview.update({ where: { id }, data: { replyBody: input.body, replyStatus: 'PENDING',
        replyModerationNote: null, replyReviewedById: null, replyReviewedAt: null, version: { increment: 1 } } });
      await this.audit(tx, user, data, 'review.reply', 'Chủ trọ gửi phản hồi chờ kiểm duyệt');
      return { data: this.privateView(data) };
    });
  }

  async moderate(user: AuthUser, id: string, input: ModerateRoomReviewDto, reply: boolean) {
    return this.prisma.$transaction(async (tx) => {
      await assertModerationAssignment(tx, user, reply ? 'REPLY' : 'REVIEW', id);
      const current = await this.lock(tx, id, input.version, {});
      if (current.withdrawnAt) throw new ConflictException('Người thuê đã gỡ đánh giá, không thể công khai lại thay họ.');
      if (reply && (!current.replyBody || current.status !== 'APPROVED')) {
        throw new ConflictException('Phản hồi chỉ được duyệt khi đánh giá đang công khai.');
      }
      if ((reply ? current.replyStatus : current.status) === input.status) throw new ConflictException('Trạng thái đã thay đổi. Hãy tải lại.');
      const data = await tx.roomReview.update({ where: { id }, data: {
        ...(reply ? { replyStatus: input.status, replyModerationNote: input.note,
          replyReviewedById: user.userId, replyReviewedAt: new Date() }
          : { status: input.status, moderationNote: input.note, reviewedById: user.userId, reviewedAt: new Date() }),
        version: { increment: 1 },
      } });
      await this.audit(tx, user, data, reply ? 'review.moderate_reply' : 'review.moderate', input.note);
      await recordModerationDecision(tx, user, { kind: reply ? 'REPLY' : 'REVIEW', targetId: id,
        ownerId: reply ? data.landlordId : data.authorId, fromStatus: (reply ? current.replyStatus : current.status) ?? 'PENDING',
        toStatus: input.status, version: data.version, reason: input.note });
      return { data: this.privateView(data) };
    });
  }

  async landlord(user: AuthUser, query: ReviewPageQuery) {
    const where: Prisma.RoomReviewWhereInput = { landlordId: user.userId, status: 'APPROVED', withdrawnAt: null,
      room: { property: { landlordId: user.userId } } };
    return this.page(where, query);
  }

  async queue(query: ReviewQueueQuery) {
    const where: Prisma.RoomReviewWhereInput = query.target === 'reply'
      ? { replyStatus: query.status, replyBody: { not: null }, status: 'APPROVED', withdrawnAt: null }
      : { status: query.status, withdrawnAt: null };
    return this.page(where, query);
  }

  private async page(where: Prisma.RoomReviewWhereInput, query: ReviewPageQuery) {
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.roomReview.count({ where }),
      this.prisma.roomReview.findMany({ where, include: managementInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data: rows.map((row) => ({ ...this.privateView(row), roomName: row.room.name, propertyName: row.room.property.name })),
      meta: { total, page: query.page, limit: query.limit } };
  }

  async publicReviews(listingId: string, query: ReviewPageQuery) {
    const listing = await this.prisma.roomListing.findFirst({ where: { id: listingId, status: 'PUBLISHED',
      NOT: { description: { contains: '[explore-preview]' } },
      room: { isActive: true, status: 'VACANT', property: { isArchived: false, landlord: { isActive: true } } } },
      select: { roomId: true, room: { select: { property: { select: { landlordId: true } } } } } });
    if (!listing) throw new NotFoundException('Tin đăng không còn hiển thị hoặc là tin minh họa.');
    const where: Prisma.RoomReviewWhereInput = { roomId: listing.roomId, landlordId: listing.room.property.landlordId,
      status: 'APPROVED', withdrawnAt: null };
    return this.prisma.$transaction(async (tx) => {
      const stats = await tx.roomReview.aggregate({ where, _count: true, _avg: {
        roomRating: true, costRating: true, landlordRating: true, areaRating: true } });
      const rows = await tx.roomReview.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (query.page - 1) * query.limit, take: query.limit });
      const averages = stats._avg;
      const overall = stats._count ? ((averages.roomRating! + averages.costRating! + averages.landlordRating! + averages.areaRating!) / 4) : null;
      return { data: rows.map((row) => ({ id: row.id, authorLabel: 'Người thuê có lịch sử hợp đồng',
        roomRating: row.roomRating, costRating: row.costRating, landlordRating: row.landlordRating, areaRating: row.areaRating,
        body: row.body, createdAt: row.createdAt, updatedAt: row.updatedAt,
        reply: row.replyStatus === 'APPROVED' && row.replyBody ? { body: row.replyBody, publishedAt: row.replyReviewedAt } : null,
      })), summary: { count: stats._count, overall, ...averages },
        meta: { total: stats._count, page: query.page, limit: query.limit } };
    }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
  }

  private privateView(row: RoomReview, tenant = false) {
    return { id: row.id, leaseId: row.leaseId, version: row.version, status: row.status,
      roomRating: row.roomRating, costRating: row.costRating, landlordRating: row.landlordRating, areaRating: row.areaRating,
      body: row.body, verificationSource: row.verificationSource, moderationNote: row.moderationNote,
      withdrawnAt: row.withdrawnAt, replyBody: !tenant || row.replyStatus === 'APPROVED' ? row.replyBody : null, replyStatus: row.replyStatus,
      replyModerationNote: tenant ? null : row.replyModerationNote, createdAt: row.createdAt, updatedAt: row.updatedAt };
  }

  private async lock(tx: Prisma.TransactionClient, id: string, version: number, scope: Prisma.RoomReviewWhereInput) {
    const exists = await tx.roomReview.findFirst({ where: { id, ...scope }, select: { id: true } });
    if (!exists) throw new NotFoundException('Không tìm thấy đánh giá.');
    await tx.$queryRaw`SELECT id FROM "RoomReview" WHERE id = ${id} FOR UPDATE`;
    const current = await tx.roomReview.findFirst({ where: { id, ...scope } });
    if (!current) throw new NotFoundException('Không tìm thấy đánh giá.');
    if (current.version !== version) throw new ConflictException('Đánh giá vừa thay đổi. Hãy tải lại trước khi thao tác.');
    return current;
  }

  private audit(tx: Prisma.TransactionClient, user: AuthUser, review: RoomReview, action: string, summary: string) {
    return tx.auditLog.create({ data: { actorId: user.userId, actorRole: user.role.toUpperCase() as 'ADMIN' | 'TENANT' | 'LANDLORD',
      landlordId: review.landlordId, action, resourceType: 'room_review', resourceId: review.id, summary,
      metadata: { version: review.version, status: review.status, replyStatus: review.replyStatus } } });
  }
}
