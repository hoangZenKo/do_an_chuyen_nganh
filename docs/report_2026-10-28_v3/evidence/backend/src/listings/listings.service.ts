import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ListingStatus, Prisma, RoomStatus, UserRole } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { assertModerationAssignment } from '../common/moderation-assignment';
import { recordModerationDecision } from '../common/moderation-decision';
import {
  CreateListingDto, ListingVersionDto, ManageListingsQuery, PublicListingsQuery,
  ReviewListingDto, UpdateListingDto, CreateListingReportDto, ReviewListingReportDto, SchoolCampusDto, ListingVerificationDto,
} from './listings.dto';

const publicSelect = {
  id: true, title: true, description: true, imageUrls: true, city: true,
  district: true, publicAddress: true, monthlyRent: true, deposit: true,
  electricityPrice: true, waterPrice: true, serviceFee: true, areaSqm: true,
  amenities: true, publishedAt: true, parkingFee: true,
  availabilityConfirmedAt: true, landlordVerifiedAt: true, inspectedAt: true,
  room: { select: { property: { select: { name: true } } } },
} satisfies Prisma.RoomListingSelect;

const managementInclude = {
  room: { select: { name: true, property: { select: { name: true, landlordId: true } } } },
} satisfies Prisma.RoomListingInclude;

@Injectable()
export class ListingsService {
  constructor(private readonly prisma: PrismaService) {}

  async publicList(query: PublicListingsQuery, publishedAfter?: Date, publishedBefore?: Date) {
    const nearby = await this.nearbyCampus(query);
    const budgetIds = query.maxBudget === undefined ? null : await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT id FROM "RoomListing" WHERE "monthlyRent"::numeric + "serviceFee" + "parkingFee"
        + "electricityPrice"::numeric * ${query.electricityKwh ?? 50}
        + "waterPrice"::numeric * ${query.waterM3 ?? 3} <= ${query.maxBudget}`;
    const allowedIds = nearby ? nearby.map(item => item.id).filter(id => !budgetIds || budgetIds.some(item => item.id === id)) : budgetIds?.map(item => item.id);
    const where: Prisma.RoomListingWhereInput = { ...this.filters(query), ...this.visibleWhere(),
      ...(allowedIds ? { id: { in: allowedIds } } : {}),
      ...(publishedAfter ? { publishedAt: { gt: publishedAfter, ...(publishedBefore ? { lte: publishedBefore } : {}) } } : {}),
      ...(query.freshOnly ? { availabilityConfirmedAt: { gte: new Date(Date.now() - 14 * 86400000) } } : {}),
    };
    const orderBy: Prisma.RoomListingOrderByWithRelationInput[] = query.sort === 'price_asc'
      ? [{ monthlyRent: 'asc' }, { id: 'asc' }]
      : query.sort === 'price_desc'
        ? [{ monthlyRent: 'desc' }, { id: 'asc' }]
        : [{ publishedAt: 'desc' }, { id: 'asc' }];
    const [total, data] = await this.prisma.$transaction([
      this.prisma.roomListing.count({ where }),
      this.prisma.roomListing.findMany({ where, select: publicSelect, orderBy,
        skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    const distances = new Map(nearby?.map((item) => [item.id, item.distanceKm]));
    return { data: data.map(({ room, ...listing }) => ({ ...listing, propertyName: room.property.name,
      distanceKm: distances.get(listing.id) ?? null,
      estimatedMonthlyCost: listing.monthlyRent + listing.serviceFee + listing.parkingFee + listing.electricityPrice * (query.electricityKwh ?? 50) + listing.waterPrice * (query.waterM3 ?? 3),
      availabilityFresh: this.availabilityFresh(listing.availabilityConfirmedAt),
    })),
      meta: { total, page: query.page, limit: query.limit } };
  }

  async publicDetail(id: string) {
    const listing = await this.prisma.roomListing.findFirst({
      where: { id, ...this.visibleWhere() }, select: publicSelect,
    });
    if (!listing) throw new NotFoundException('Tin đăng không còn hiển thị.');
    const { room, ...data } = listing;
    return { data: { ...data, propertyName: room.property.name, availabilityFresh: this.availabilityFresh(data.availabilityConfirmedAt) } };
  }

  async manageList(query: ManageListingsQuery, landlordId?: string) {
    const where: Prisma.RoomListingWhereInput = {
      ...this.filters(query),
      ...(query.status ? { status: query.status } : {}),
      ...(landlordId ? { room: { property: { landlordId } } } : {}),
    };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.roomListing.count({ where }),
      this.prisma.roomListing.findMany({ where, include: managementInclude,
        orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }],
        skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data: data.map(item => ({ ...item, needsAvailabilityConfirmation: item.status === 'PUBLISHED' && !this.availabilityFresh(item.availabilityConfirmedAt) })), meta: { total, page: query.page, limit: query.limit } };
  }

  async create(actor: AuthUser, input: CreateListingDto) {
    this.validateCoordinates(input);
    try {
      return await this.prisma.$transaction(async (tx) => {
        const room = await tx.room.findFirst({ where: {
          id: input.roomId, property: { landlordId: actor.userId },
        } });
        if (!room) throw new NotFoundException('Không tìm thấy phòng.');
        const listing = await tx.roomListing.create({ data: input });
        await this.audit(tx, actor, actor.userId, listing.id, 'listing.create', listing.version);
        return { data: listing };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Phòng đã có tin đăng. Hãy chỉnh sửa tin hiện có.');
      }
      throw error;
    }
  }

  async update(actor: AuthUser, id: string, input: UpdateListingDto) {
    this.validateCoordinates(input);
    const { version, ...content } = input;
    return this.mutate(actor, id, version, 'listing.update', async () => ({
      ...content, status: ListingStatus.DRAFT, reviewNote: null, publishedAt: null,
      landlordVerifiedAt: null, inspectedAt: null, availabilityConfirmedAt: null,
    }));
  }

  async submit(actor: AuthUser, id: string, input: ListingVersionDto) {
    return this.mutate(actor, id, input.version, 'listing.submit', async (tx, listing) => {
      const submittable: ListingStatus[] = [ListingStatus.DRAFT, ListingStatus.REJECTED, ListingStatus.HIDDEN];
      if (!submittable.includes(listing.status)) {
        throw new ConflictException('Tin không ở trạng thái có thể gửi duyệt.');
      }
      await this.requireAvailableRoom(tx, listing.roomId);
      return { status: ListingStatus.PENDING, reviewNote: null, publishedAt: null, availabilityConfirmedAt: new Date() };
    });
  }

  async hide(actor: AuthUser, id: string, input: ListingVersionDto) {
    return this.mutate(actor, id, input.version, 'listing.hide', async () => ({
      status: ListingStatus.HIDDEN, publishedAt: null,
    }));
  }

  async review(actor: AuthUser, id: string, input: ReviewListingDto) {
    if ((input.landlordVerified || input.roomInspected) && (input.note?.trim().length ?? 0) < 10) {
      throw new BadRequestException('Cần ghi căn cứ xác minh ít nhất 10 ký tự.');
    }
    return this.mutate(actor, id, input.version, `listing.${input.decision.toLowerCase()}`,
      async (tx, listing) => {
        if (input.decision === 'HIDE') {
          if (listing.status !== ListingStatus.PUBLISHED) throw new ConflictException('Chỉ ẩn tin đã đăng.');
        } else if (listing.status !== ListingStatus.PENDING) {
          throw new ConflictException('Chỉ duyệt hoặc từ chối tin đang chờ duyệt.');
        }
        if (input.decision !== 'PUBLISH' && !input.note?.trim()) {
          throw new BadRequestException('Cần nhập lý do từ chối hoặc ẩn tin.');
        }
        if (input.decision === 'PUBLISH') await this.requireAvailableRoom(tx, listing.roomId);
        return {
          status: input.decision === 'PUBLISH' ? ListingStatus.PUBLISHED
            : input.decision === 'REJECT' ? ListingStatus.REJECTED : ListingStatus.HIDDEN,
          reviewNote: input.note ?? null,
          publishedAt: input.decision === 'PUBLISH' ? new Date() : null,
          ...(input.decision === 'PUBLISH' ? {
            landlordVerifiedAt: input.landlordVerified === true ? new Date() : null,
            inspectedAt: input.roomInspected === true ? new Date() : null,
          } : {}),
        };
      }, true);
  }

  private async mutate(
    actor: AuthUser, id: string, version: number, action: string,
    change: (tx: Prisma.TransactionClient, listing: { roomId: string; status: ListingStatus }) => Promise<Prisma.RoomListingUpdateManyMutationInput>,
    admin = false,
  ) {
    return this.prisma.$transaction(async (tx) => {
      if (admin) await assertModerationAssignment(tx, actor, 'LISTING', id);
      const scope = admin ? {} : { room: { property: { landlordId: actor.userId } } };
      const listing = await tx.roomListing.findFirst({ where: { id, ...scope }, include: managementInclude });
      if (!listing) throw new NotFoundException('Không tìm thấy tin đăng.');
      if (listing.version !== version) throw new ConflictException('Tin đã thay đổi. Hãy tải lại trước khi xử lý.');
      const data = await change(tx, listing);
      const updated = await tx.roomListing.updateMany({ where: { id, version }, data: { ...data, version: { increment: 1 } } });
      if (!updated.count) throw new ConflictException('Tin đã thay đổi. Hãy tải lại trước khi xử lý.');
      await this.audit(tx, actor, listing.room.property.landlordId, id, action, version + 1,
        typeof data.reviewNote === 'string' ? data.reviewNote : undefined);
      if (admin && typeof data.status === 'string' && data.status !== listing.status) {
        await recordModerationDecision(tx, actor, { kind: 'LISTING', targetId: id, ownerId: listing.room.property.landlordId,
          fromStatus: listing.status, toStatus: data.status, version: version + 1, reason: typeof data.reviewNote === 'string' ? data.reviewNote : 'Được duyệt theo chính sách kiểm duyệt.' });
      }
      return { data: await tx.roomListing.findUniqueOrThrow({ where: { id } }) };
    });
  }

  campuses(admin = false) {
    return this.prisma.schoolCampus.findMany({ where: admin ? {} : { isActive: true }, orderBy: [{ isDemo: 'asc' }, { city: 'asc' }, { name: 'asc' }, { campus: 'asc' }] })
      .then((data) => ({ data }));
  }

  verify(actor: AuthUser, id: string, input: ListingVerificationDto) {
    if ((input.note?.trim().length ?? 0) < 10) throw new BadRequestException('Cần ghi căn cứ xác minh ít nhất 10 ký tự.');
    return this.mutate(actor, id, input.version, 'listing.verify', async (_tx, listing) => {
      if (listing.status !== ListingStatus.PUBLISHED) throw new ConflictException('Chỉ xác minh tin đã xuất bản.');
      return { landlordVerifiedAt: input.landlordVerified ? new Date() : null,
        inspectedAt: input.roomInspected ? new Date() : null, reviewNote: input.note };
    }, true);
  }

  createCampus(input: SchoolCampusDto) {
    return this.prisma.schoolCampus.create({ data: input }).then((data) => ({ data }));
  }

  async updateCampus(id: string, input: SchoolCampusDto & { isActive: boolean }) {
    if (!await this.prisma.schoolCampus.findUnique({ where: { id } })) throw new NotFoundException('Không tìm thấy cơ sở trường.');
    return { data: await this.prisma.schoolCampus.update({ where: { id }, data: input }) };
  }

  private availabilityFresh(date: Date | null) {
    return date !== null && date.getTime() >= Date.now() - 14 * 86400000;
  }

  confirmAvailability(actor: AuthUser, id: string, input: ListingVersionDto) {
    return this.mutate(actor, id, input.version, 'listing.confirm_availability', async (tx, listing) => {
      if (listing.status !== ListingStatus.PUBLISHED) throw new ConflictException('Chỉ xác nhận tin đã xuất bản.');
      await this.requireAvailableRoom(tx, listing.roomId);
      return { availabilityConfirmedAt: new Date() };
    });
  }

  async report(actor: AuthUser, id: string, input: CreateListingReportDto) {
    await this.publicDetail(id);
    try {
      const data = await this.prisma.listingReport.create({ data: { listingId: id, reporterId: actor.userId, ...input } });
      return { data: { id: data.id, status: data.status } };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new ConflictException('Bạn đã báo cáo tin này. Quản trị viên sẽ kiểm tra.');
      }
      throw error;
    }
  }

  async reports(query: PublicListingsQuery) {
    const [total, data] = await this.prisma.$transaction([
      this.prisma.listingReport.count(),
      this.prisma.listingReport.findMany({ include: { listing: { select: { id: true, title: true, status: true } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data, meta: { total, page: query.page, limit: query.limit } };
  }

  async reviewReport(actor: AuthUser, id: string, input: ReviewListingReportDto) {
    return this.prisma.$transaction(async (tx) => {
      await assertModerationAssignment(tx, actor, 'REPORT', id);
      const report = await tx.listingReport.findUnique({ where: { id }, include: { listing: { include: managementInclude } } });
      if (!report) throw new NotFoundException('Không tìm thấy báo cáo.');
      const changed = await tx.listingReport.updateMany({ where: { id, status: 'OPEN', ...(input.version !== undefined ? { version: input.version } : {}) },
        data: { status: input.status, reviewNote: input.note, reviewedAt: new Date(), version: { increment: 1 } } });
      if (!changed.count) throw new ConflictException('Báo cáo đã được xử lý.');
      await this.audit(tx, actor, report.listing.room.property.landlordId, report.listingId,
        `listing.report.${input.status.toLowerCase()}`, report.listing.version, input.note);
      await recordModerationDecision(tx, actor, { kind: 'REPORT', targetId: id, ownerId: report.reporterId,
        fromStatus: report.status, toStatus: input.status, version: report.version + 1, reason: input.note });
      return { data: await tx.listingReport.findUniqueOrThrow({ where: { id } }) };
    });
  }

  private validateCoordinates(input: { latitude?: number; longitude?: number }) {
    if ((input.latitude != null) !== (input.longitude != null)) {
      throw new BadRequestException('Cần nhập cả vĩ độ và kinh độ hoặc bỏ trống cả hai.');
    }
  }

  private async nearbyCampus(query: PublicListingsQuery) {
    if (!query.campusId) {
      if (query.radiusKm !== undefined) throw new BadRequestException('Hãy chọn cơ sở trường trước khi lọc bán kính.');
      return null;
    }
    const campus = await this.prisma.schoolCampus.findUnique({ where: { id: query.campusId } });
    if (!campus || !campus.isActive) throw new NotFoundException('Cơ sở trường không tồn tại hoặc đã ngừng sử dụng.');
    const radius = query.radiusKm ?? 5;
    const latitudeDelta = radius / 110;
    return this.prisma.$queryRaw<{ id: string; distanceKm: number }[]>(Prisma.sql`
      SELECT * FROM (
        SELECT "id", 6371 * 2 * asin(sqrt(least(1.0, greatest(0.0,
          power(sin(radians("latitude" - ${campus.latitude}) / 2), 2) +
          cos(radians(${campus.latitude})) * cos(radians("latitude")) *
          power(sin(radians("longitude" - ${campus.longitude}) / 2), 2)
        )))) AS "distanceKm"
        FROM "RoomListing"
        WHERE "latitude" BETWEEN ${campus.latitude - latitudeDelta} AND ${campus.latitude + latitudeDelta}
          AND "longitude" IS NOT NULL
      ) nearby WHERE "distanceKm" <= ${radius}
    `);
  }

  private async requireAvailableRoom(tx: Prisma.TransactionClient, roomId: string) {
    const room = await tx.room.findFirst({ where: { id: roomId, isActive: true,
      status: RoomStatus.VACANT, property: { isArchived: false, landlord: { isActive: true } } } });
    if (!room) throw new ConflictException('Chỉ đăng phòng trống thuộc chủ trọ đang hoạt động.');
  }

  private visibleWhere(): Prisma.RoomListingWhereInput {
    return { status: ListingStatus.PUBLISHED, room: { isActive: true, status: RoomStatus.VACANT,
      property: { isArchived: false, landlord: { isActive: true } } } };
  }

  private filters(query: PublicListingsQuery): Prisma.RoomListingWhereInput {
    if (query.minPrice !== undefined && query.maxPrice !== undefined && query.minPrice > query.maxPrice) {
      throw new BadRequestException('Giá tối thiểu phải nhỏ hơn hoặc bằng giá tối đa.');
    }
    return {
      ...(query.search ? { OR: ['title', 'publicAddress', 'city', 'district'].map((field) => ({
        [field]: { contains: query.search, mode: 'insensitive' },
      })) } : {}),
      ...(query.city ? { city: { equals: query.city, mode: 'insensitive' } } : {}),
      ...(query.district ? { district: { equals: query.district, mode: 'insensitive' } } : {}),
      monthlyRent: { gte: query.minPrice, lte: query.maxPrice },
      ...(query.minArea !== undefined ? { areaSqm: { gte: query.minArea } } : {}),
      ...(query.amenity ? { amenities: { has: query.amenity } } : {}),
    };
  }

  private audit(tx: Prisma.TransactionClient, actor: AuthUser, landlordId: string, id: string, action: string, version: number, reviewNote?: string) {
    return tx.auditLog.create({ data: { landlordId, actorId: actor.userId,
      actorRole: actor.role === 'admin' ? UserRole.ADMIN : UserRole.LANDLORD,
      action, resourceType: 'room_listing', resourceId: id,
      summary: action, metadata: { version, ...(reviewNote ? { reviewNote } : {}) },
    } });
  }
}
