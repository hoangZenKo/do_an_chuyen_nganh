import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AnnouncementAudience, AnnouncementStatus, Prisma } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAnnouncementDto, CreateAnnouncementTemplateDto, CreateTenantGroupDto } from '../operations/p1.dto';

@Injectable()
export class AnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  async createGroup(user: AuthUser, input: CreateTenantGroupDto) {
    const landlordId = landlordScopeId(user);
    const valid = await this.prisma.tenant.count({ where: { id: { in: input.tenantIds }, landlordId, isActive: true } });
    if (valid !== input.tenantIds.length) throw new BadRequestException('Danh sách người thuê không hợp lệ.');
    return { data: await this.prisma.tenantGroup.create({ data: { landlordId, name: input.name.trim(), tenantIds: input.tenantIds } }) };
  }

  async createTemplate(user: AuthUser, input: CreateAnnouncementTemplateDto) {
    return { data: await this.prisma.announcementTemplate.create({ data: { landlordId: landlordScopeId(user), name: input.name.trim(), title: input.title.trim(), body: input.body.trim() } }) };
  }

  async create(user: AuthUser, input: CreateAnnouncementDto) {
    const landlordId = landlordScopeId(user);
    const sendAt = input.sendAt ? new Date(input.sendAt) : new Date();
    if (sendAt.getTime() < Date.now() - 60000) throw new BadRequestException('Thời gian gửi không được ở quá khứ.');
    if (input.audience === AnnouncementAudience.PROPERTY && !input.propertyId) throw new BadRequestException('Thiếu khu trọ.');
    if (input.audience === AnnouncementAudience.ROOM && (!input.propertyId || !input.roomId)) throw new BadRequestException('Thiếu khu trọ hoặc phòng.');
    if (input.audience === AnnouncementAudience.GROUP && !input.groupId) throw new BadRequestException('Thiếu nhóm người thuê.');
    if (input.audience === AnnouncementAudience.TENANTS && !input.tenantIds?.length) throw new BadRequestException('Thiếu người nhận.');
    const allowed = input.audience === 'ROOM' ? ['propertyId', 'roomId'] : input.audience === 'PROPERTY' ? ['propertyId'] : input.audience === 'GROUP' ? ['groupId'] : input.audience === 'TENANTS' ? ['tenantIds'] : [];
    for (const key of ['propertyId', 'roomId', 'groupId', 'tenantIds'] as const) {
      if (input[key] !== undefined && !allowed.includes(key)) throw new BadRequestException('Phạm vi người nhận không khớp.');
    }
    if (input.propertyId && !await this.prisma.property.findFirst({ where: { id: input.propertyId, landlordId, isArchived: false } })) throw new NotFoundException('Không tìm thấy khu trọ.');
    if (input.roomId && !await this.prisma.room.findFirst({ where: { id: input.roomId, propertyId: input.propertyId, property: { landlordId }, isActive: true } })) throw new NotFoundException('Không tìm thấy phòng.');
    const tenantIds = await this.resolveRecipients(landlordId, input);
    if (!tenantIds.length) throw new BadRequestException('Phạm vi này không có người thuê đang hoạt động.');
    const data = await this.prisma.$transaction(async tx => {
      if (input.propertyId && !await tx.property.findFirst({ where: { id: input.propertyId, landlordId, isArchived: false } })) throw new NotFoundException('Không tìm thấy khu trọ.');
      const announcement = await tx.announcement.create({ data: { landlordId, propertyId: input.propertyId, roomId: input.roomId, groupId: input.groupId, tenantIds, audience: input.audience, title: input.title.trim(), body: input.body.trim(), sendAt, status: sendAt.getTime() <= Date.now() ? AnnouncementStatus.SENT : AnnouncementStatus.SCHEDULED, sentAt: sendAt.getTime() <= Date.now() ? new Date() : null, recipients: tenantIds.length ? { createMany: { data: tenantIds.map(tenantId => ({ tenantId })) } } : undefined }, include: { recipients: true } });
      return announcement;
    });
    return { data };
  }

  async list(user: AuthUser) {
    return { data: await this.prisma.announcement.findMany({ where: { landlordId: landlordScopeId(user) }, include: { property: { select: { id: true, name: true } }, room: { select: { id: true, name: true } }, recipients: { select: { tenantId: true, readAt: true } } }, orderBy: [{ status: 'asc' }, { sendAt: 'desc' }], take: 100 }) };
  }

  async templates(user: AuthUser) { return { data: await this.prisma.announcementTemplate.findMany({ where: { landlordId: landlordScopeId(user) }, orderBy: { createdAt: 'desc' } }) }; }
  async groups(user: AuthUser) { return { data: await this.prisma.tenantGroup.findMany({ where: { landlordId: landlordScopeId(user) }, orderBy: { name: 'asc' } }) }; }

  async tenantAnnouncements(user: AuthUser) {
    const tenant = await this.prisma.tenant.findFirst({ where: { userId: user.userId } });
    if (!tenant) throw new NotFoundException('Không tìm thấy hồ sơ người thuê.');
    return { data: await this.prisma.announcement.findMany({ where: { status: AnnouncementStatus.SENT, recipients: { some: { tenantId: tenant.id } } }, select: { id: true, title: true, body: true, status: true, sendAt: true, sentAt: true, recipients: { where: { tenantId: tenant.id }, select: { readAt: true } } }, orderBy: { sentAt: 'desc' }, take: 100 }) };
  }

  async markRead(user: AuthUser, id: string) {
    const tenant = await this.prisma.tenant.findFirst({ where: { userId: user.userId } });
    if (!tenant) throw new NotFoundException('Không tìm thấy hồ sơ người thuê.');
    const owned = await this.prisma.announcementRecipient.findFirst({ where: { announcementId: id, tenantId: tenant.id, announcement: { status: 'SENT' } } });
    if (!owned) throw new NotFoundException('Không tìm thấy thông báo.');
    const readAt = owned.readAt ?? new Date();
    await this.prisma.announcementRecipient.updateMany({ where: { announcementId: id, tenantId: tenant.id, readAt: null }, data: { readAt } });
    return { data: { id, readAt } };
  }

  async receipts(user: AuthUser, id: string) {
    if (!await this.prisma.announcement.findFirst({ where: { id, landlordId: landlordScopeId(user) } })) throw new NotFoundException('Không tìm thấy thông báo.');
    return { data: await this.prisma.announcementRecipient.findMany({ where: { announcementId: id }, include: { tenant: { select: { id: true, fullName: true } } }, orderBy: { tenantId: 'asc' } }) };
  }

  async cancel(user: AuthUser, id: string) {
    if (!await this.prisma.announcement.findFirst({ where: { id, landlordId: landlordScopeId(user) } })) throw new NotFoundException('Không tìm thấy thông báo.');
    const result = await this.prisma.announcement.updateMany({ where: { id, landlordId: landlordScopeId(user), status: 'SCHEDULED' }, data: { status: 'CANCELLED' } });
    if (!result.count) throw new ConflictException('Chỉ có thể hủy thông báo chưa gửi.');
    return { data: { id, status: 'CANCELLED' } };
  }

  async sendDue(now = new Date()) {
    return this.prisma.$transaction(async tx => {
      const due = await tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        SELECT announcement.id FROM "Announcement" announcement
        JOIN "User" landlord ON landlord.id = announcement."landlordId"
        WHERE announcement.status = 'SCHEDULED' AND announcement."sendAt" <= ${now} AND landlord."isActive" = true
        ORDER BY announcement."sendAt" LIMIT 100 FOR UPDATE OF announcement SKIP LOCKED`);
      const result = await tx.announcement.updateMany({ where: { id: { in: due.map(item => item.id) }, status: 'SCHEDULED' }, data: { status: 'SENT', sentAt: now } });
      return { sent: result.count };
    });
  }

  private async resolveRecipients(landlordId: string, input: CreateAnnouncementDto) {
    if (input.audience === AnnouncementAudience.ALL_TENANTS) return (await this.prisma.tenant.findMany({ where: { landlordId, isActive: true }, select: { id: true } })).map(item => item.id);
    if (input.audience === AnnouncementAudience.PROPERTY) return (await this.prisma.tenant.findMany({ where: { landlordId, isActive: true, leases: { some: { status: 'ACTIVE', room: { propertyId: input.propertyId } } } }, select: { id: true } })).map(item => item.id);
    if (input.audience === AnnouncementAudience.ROOM) return (await this.prisma.tenant.findMany({ where: { landlordId, isActive: true, leases: { some: { status: 'ACTIVE', roomId: input.roomId } } }, select: { id: true } })).map(item => item.id);
    if (input.audience === AnnouncementAudience.GROUP) {
      const group = await this.prisma.tenantGroup.findFirst({ where: { id: input.groupId, landlordId } });
      if (!group) throw new NotFoundException('Không tìm thấy nhóm người thuê.');
      return (await this.prisma.tenant.findMany({ where: { id: { in: group.tenantIds }, landlordId, isActive: true }, select: { id: true } })).map(item => item.id);
    }
    const ids = input.tenantIds ?? [];
    if (await this.prisma.tenant.count({ where: { id: { in: ids }, landlordId, isActive: true } }) !== ids.length) throw new BadRequestException('Danh sách người nhận không hợp lệ.');
    return ids;
  }
}
