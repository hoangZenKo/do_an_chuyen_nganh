import { propertyWhere, scopedPropertyIds } from '../common/property-scope';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { AuthRole } from '../common/auth-role';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { businessDay } from '../billing/billing-rules';
import { createHash } from 'node:crypto';
import { LeasesService } from '../leases/leases.service';
import {
  CreateLifecycleRequestDto, ExecuteLifecycleDto, LifecycleDecisionDto, LifecycleListQueryDto, LifecycleVersionDto,
  TenantNotificationPreferenceDto, TenantOccupantDto, TransferRoomsQueryDto,
} from './dto/tenant-lifecycle.dto';

const defaultPreference = { enabled: true, channels: ['APP'] };

@Injectable()
export class TenantLifecycleService {
  constructor(private readonly prisma: PrismaService, private readonly leases: LeasesService) {}

  private async tenant(tx: Prisma.TransactionClient, userId: string) {
    const tenant = await tx.tenant.findFirst({ where: { userId, isActive: true, landlord: { isActive: true } } });
    if (!tenant) throw new NotFoundException('Active tenant profile not found.');
    return tenant;
  }

  private reason(value: string) {
    const result = value.trim();
    if (!result) throw new BadRequestException('A non-blank reason is required.');
    return result;
  }

  private audit(tx: Prisma.TransactionClient, actor: AuthUser, landlordId: string, action: string, resourceType: string, resourceId: string, metadata: Prisma.InputJsonObject) {
    return tx.auditLog.create({ data: { actorId: actor.userId, actorRole: actor.role.toUpperCase() as UserRole, landlordId, action, resourceType, resourceId, summary: action, metadata } });
  }

  async requests(actor: AuthUser, query: LifecycleListQueryDto) {
    return this.prisma.$transaction(async (tx) => {
      const tenant = actor.role === AuthRole.TENANT ? await this.tenant(tx, actor.userId) : null;
      const where: Prisma.TenantLifecycleRequestWhereInput = {
        landlordId: tenant?.landlordId ?? landlordScopeId(actor),
        ...(tenant ? { tenantId: tenant.id } : query.tenantId ? { tenantId: query.tenantId } : {}),
        ...(query.status ? { status: query.status } : {}),
        ...(query.leaseId ? { leaseId: query.leaseId } : {}),
        ...(query.propertyId ? { lease: { room: { propertyId: query.propertyId } } } : {}),
        ...(scopedPropertyIds() ? { AND: [{ lease: { room: { property: propertyWhere(landlordScopeId(actor)) } } }, { OR: [{ requestedRoomId: null }, { requestedRoom: { property: propertyWhere(landlordScopeId(actor)) } }] }] } : {}),
      };
      if (query.cursor) {
        const cursor = await tx.tenantLifecycleRequest.findFirst({ where: { ...where, id: query.cursor }, select: { id: true } });
        if (!cursor) throw new BadRequestException('Invalid request cursor.');
      }
      const rows = await tx.tenantLifecycleRequest.findMany({
        where, orderBy: { id: 'desc' }, take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
        include: { execution: { select: { id: true, resultLeaseId: true, createdAt: true } }, tenant: { select: { fullName: true } }, lease: { select: { id: true, roomId: true, status: true, endDate: true, updatedAt: true, room: { select: { name: true, propertyId: true } } } }, requestedRoom: { select: { id: true, name: true, propertyId: true } } },
      });
      return { data: rows.slice(0, query.limit), nextCursor: rows.length > query.limit ? rows[query.limit - 1].id : null };
    });
  }

  async createRequest(actor: AuthUser, input: CreateLifecycleRequestDto, now = new Date()) {
    const note = this.reason(input.note);
    return this.prisma.$transaction(async (tx) => {
      const tenant = await this.tenant(tx, actor.userId);
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`tenant-lifecycle:${tenant.id}`}, 0))::text`;
      const lease = await tx.lease.findFirst({ where: { id: input.leaseId, tenantId: tenant.id, status: 'ACTIVE', room: { isActive: true, property: { landlordId: tenant.landlordId, isArchived: false } } }, include: { room: true } });
      if (!lease) throw new NotFoundException('Active lease not found.');
      const duplicate = await tx.tenantLifecycleRequest.findFirst({ where: { tenantId: tenant.id, leaseId: lease.id, type: input.type, status: 'PENDING' } });
      if (duplicate) throw new ConflictException('A pending request of this type already exists for the lease.');
      const start = input.requestedStart ? new Date(input.requestedStart) : null;
      const end = input.requestedEnd ? new Date(input.requestedEnd) : null;
      if ((start && !Number.isFinite(start.getTime())) || (end && !Number.isFinite(end.getTime()))) throw new BadRequestException('Invalid requested date.');
      const today = new Date(businessDay(now) + 'T00:00:00+07:00');
      if (input.type === 'RENEWAL') {
        if (!end || end <= (lease.endDate ?? now) || end <= now) throw new BadRequestException('Renewal must extend the current lease end date.');
        if (start || input.requestedRoomId) throw new BadRequestException('Renewal only accepts a requested end date.');
      } else {
        if (!start || start < today || start < lease.startDate) throw new BadRequestException('A valid future effective date is required.');
        if (end) throw new BadRequestException('Checkout/transfer does not accept an end date.');
        if (input.type === 'TRANSFER_ROOM') {
          if (!input.requestedRoomId || input.requestedRoomId === lease.roomId) throw new BadRequestException('Select a different target room.');
          const room = await tx.room.findFirst({ where: { id: input.requestedRoomId, isActive: true, status: 'VACANT', leases: { none: { status: 'ACTIVE' } }, property: { landlordId: tenant.landlordId, isArchived: false } }, select: { id: true } });
          if (!room) throw new NotFoundException('Available target room not found.');
        } else if (input.requestedRoomId) throw new BadRequestException('Checkout does not accept a target room.');
      }
      const request = await tx.tenantLifecycleRequest.create({ data: { landlordId: tenant.landlordId, tenantId: tenant.id, leaseId: lease.id, type: input.type, requestedRoomId: input.requestedRoomId, requestedStart: start, requestedEnd: end, note } });
      await this.audit(tx, actor, tenant.landlordId, 'tenant.lifecycle.request', 'tenant_lifecycle_request', request.id, { type: request.type, leaseId: lease.id });
      return { data: request };
    });
  }

  async cancelRequest(actor: AuthUser, id: string, input: LifecycleVersionDto = {}) {
    return this.prisma.$transaction(async (tx) => {
      const tenant = await this.tenant(tx, actor.userId);
      const updated = await tx.tenantLifecycleRequest.updateMany({ where: { id, tenantId: tenant.id, landlordId: tenant.landlordId, status: 'PENDING', ...(input.expectedUpdatedAt ? { updatedAt: new Date(input.expectedUpdatedAt) } : {}) }, data: { status: 'CANCELLED' } });
      if (!updated.count) throw new ConflictException('Pending request not found.');
      await this.audit(tx, actor, tenant.landlordId, 'tenant.lifecycle.cancel', 'tenant_lifecycle_request', id, {});
      return { data: await tx.tenantLifecycleRequest.findUniqueOrThrow({ where: { id } }) };
    });
  }

  async decideRequest(actor: AuthUser, id: string, input: LifecycleDecisionDto) {
    const reason = this.reason(input.reason);
    const landlordId = landlordScopeId(actor);
    return this.prisma.$transaction(async (tx) => {
      const request = await tx.tenantLifecycleRequest.findFirst({ where: { id, landlordId, status: 'PENDING', ...(scopedPropertyIds() ? { lease: { room: { property: propertyWhere(landlordId) } }, OR: [{ requestedRoomId: null }, { requestedRoom: { property: propertyWhere(landlordId) } }] } : {}) }, include: { lease: true } });
      if (!request) throw new ConflictException('Pending request not found.');
      if (request.lease) {
        await tx.$queryRaw`SELECT "id" FROM "Room" WHERE "id" = ${request.lease.roomId} FOR UPDATE`;
        await tx.$queryRaw`SELECT "id" FROM "Lease" WHERE "id" = ${request.lease.id} FOR UPDATE`;
      }
      const lease = request.lease ? await tx.lease.findUnique({ where: { id: request.lease.id } }) : null;
      if (input.expectedLeaseUpdatedAt && lease?.updatedAt.getTime() !== new Date(input.expectedLeaseUpdatedAt).getTime()) {
        throw new ConflictException('Hợp đồng đã thay đổi. Tải lại trước khi xử lý.');
      }
      if (input.status === 'APPROVED') {
        if (!lease || lease.status !== 'ACTIVE') throw new ConflictException('The lease is no longer active.');
        if (request.type === 'RENEWAL' && (!request.requestedEnd || request.requestedEnd <= (lease.endDate ?? new Date()))) throw new ConflictException('Ngày gia hạn không còn phù hợp với hợp đồng hiện tại.');
        if (request.type === 'TRANSFER_ROOM') {
          const room = await tx.room.findFirst({ where: { id: request.requestedRoomId ?? '', isActive: true, status: 'VACANT', leases: { none: { status: 'ACTIVE' } }, property: { ...propertyWhere(landlordId), isArchived: false } }, select: { id: true } });
          if (!room) throw new ConflictException('The target room is no longer available.');
        }
      }
      const updated = await tx.tenantLifecycleRequest.updateMany({ where: { id, landlordId, status: 'PENDING', ...(input.expectedUpdatedAt ? { updatedAt: new Date(input.expectedUpdatedAt) } : {}) }, data: { status: input.status, decisionNote: reason, reviewedById: actor.userId, reviewedAt: new Date() } });
      if (!updated.count) throw new ConflictException('The request has already been reviewed or cancelled.');
      await this.audit(tx, actor, landlordId, 'tenant.lifecycle.review', 'tenant_lifecycle_request', id, { status: input.status, reason });
      return { data: await tx.tenantLifecycleRequest.findUniqueOrThrow({ where: { id } }), requiresLeaseAction: input.status === 'APPROVED' };
    });
  }

  async transferRooms(actor: AuthUser, query: TransferRoomsQueryDto) {
    return this.prisma.$transaction(async tx => {
      const tenant = await this.tenant(tx, actor.userId);
      const lease = await tx.lease.findFirst({ where: { id: query.leaseId, tenantId: tenant.id, status: 'ACTIVE' } });
      if (!lease) throw new NotFoundException('Active lease not found.');
      const where: Prisma.RoomWhereInput = { id: { not: lease.roomId }, isActive: true, status: 'VACANT',
        leases: { none: { status: 'ACTIVE' } }, turnovers: { none: { status: 'ACTIVE' } },
        property: { landlordId: tenant.landlordId, isArchived: false },
        ...(query.search?.trim() ? { name: { contains: query.search.trim(), mode: 'insensitive' } } : {}) };
      if (query.cursor && !await tx.room.findFirst({ where: { AND: [where, { id: query.cursor }] }, select: { id: true } })) throw new BadRequestException('Invalid room cursor.');
      const rows = await tx.room.findMany({ where, orderBy: { id: 'asc' }, take: query.limit + 1,
        ...(query.cursor ? { cursor: { id: query.cursor }, skip: 1 } : {}),
        select: { id: true, name: true, basePrice: true, capacity: true, property: { select: { id: true, name: true } } } });
      return { data: rows.slice(0, query.limit), nextCursor: rows.length > query.limit ? rows[query.limit - 1].id : null };
    });
  }

  async executeRequest(actor: AuthUser, id: string, input: ExecuteLifecycleDto, now = new Date()) {
    const landlordId = landlordScopeId(actor);
    const hash = createHash('sha256').update(JSON.stringify({ id, monthlyRent: input.monthlyRent ?? null })).digest('hex');
    try {
      return await this.prisma.$transaction(async tx => {
        const request = await tx.tenantLifecycleRequest.findFirst({ where: { id, landlordId,
          lease: { room: { property: propertyWhere(landlordId) } },
          OR: [{ requestedRoomId: null }, { requestedRoom: { property: propertyWhere(landlordId) } }] } });
        if (!request?.leaseId) throw new NotFoundException('Request not found.');
        await tx.$queryRaw`SELECT "id" FROM "TenantLifecycleRequest" WHERE "id" = ${id} FOR UPDATE`;
        const completed = await tx.tenantLifecycleExecution.findUnique({ where: { requestId: id } });
        if (completed) {
          if (completed.requestKey !== input.requestKey || completed.requestHash !== hash) throw new ConflictException('Yêu cầu đã được thực hiện.');
          return { data: { id: completed.id, resultLeaseId: completed.resultLeaseId, createdAt: completed.createdAt }, idempotent: true };
        }
        if (request.status !== 'APPROVED') throw new ConflictException('Chỉ thực hiện yêu cầu đã duyệt.');
        if (input.expectedUpdatedAt && request.updatedAt.getTime() !== new Date(input.expectedUpdatedAt).getTime()) throw new ConflictException('Yêu cầu đã thay đổi.');
        const before = await tx.lease.findUniqueOrThrow({ where: { id: request.leaseId } });
        const roomIds = [before.roomId, ...(request.requestedRoomId ? [request.requestedRoomId] : [])].sort();
        for (const roomId of roomIds) await tx.$queryRaw`SELECT "id" FROM "Room" WHERE "id" = ${roomId} FOR UPDATE`;
        await tx.$queryRaw`SELECT "id" FROM "Lease" WHERE "id" = ${request.leaseId} FOR UPDATE`;
        const lease = await tx.lease.findUniqueOrThrow({ where: { id: request.leaseId }, include: { occupants: true, settlement: true } });
        if (input.expectedLeaseUpdatedAt && lease.updatedAt.getTime() !== new Date(input.expectedLeaseUpdatedAt).getTime()) throw new ConflictException('Hợp đồng đã thay đổi. Tải lại trước khi thực hiện.');
        let resultLeaseId = lease.id;
        if (request.type === 'RENEWAL') {
          if (!request.requestedEnd) throw new ConflictException('Thiếu ngày gia hạn.');
          await this.leases.renewWithinTransaction(tx, landlordId, lease.id, {
            endDate: request.requestedEnd.toISOString(), note: `Tenant request ${id}`,
          });
        } else {
          if (lease.status !== 'ENDED' || !lease.settlement) throw new ConflictException('Phải xác nhận quyết toán hiện có trước khi hoàn tất trả/chuyển phòng.');
          if (request.type === 'TRANSFER_ROOM') {
            if (!request.requestedRoomId || !request.requestedStart) throw new ConflictException('Thiếu phòng hoặc ngày chuyển.');
            if (businessDay(request.requestedStart) > businessDay(now)) throw new ConflictException('Chưa đến ngày chuyển phòng.');
            if (request.requestedStart < lease.settlement.moveOutDate) throw new ConflictException('Ngày chuyển phải từ ngày quyết toán trở đi.');
            if (input.monthlyRent === undefined) throw new BadRequestException('Xác nhận giá thuê phòng mới.');
            const room = await tx.room.findFirst({ where: { id: request.requestedRoomId, property: propertyWhere(landlordId), isActive: true }, select: { capacity: true } });
            if (!room || lease.occupants.length + 1 > (room.capacity ?? 100)) throw new ConflictException('Phòng đến không đủ sức chứa.');
            const created = await this.leases.createWithinTransaction(tx, landlordId, { roomId: request.requestedRoomId,
              tenantId: lease.tenantId, monthlyRent: input.monthlyRent, deposit: 0, startDate: request.requestedStart.toISOString() });
            resultLeaseId = created.id;
            for (const occupant of lease.occupants) await tx.tenantOccupant.create({ data: { tenantId: lease.tenantId,
              leaseId: created.id, fullName: occupant.fullName, phone: occupant.phone, idNumber: occupant.idNumber, relationship: occupant.relationship } });
          }
        }
        const execution = await tx.tenantLifecycleExecution.create({ data: { requestId: id, requestKey: input.requestKey,
          requestHash: hash, resultLeaseId, actorId: actor.userId } });
        await this.audit(tx, actor, landlordId, 'tenant.lifecycle.execute', 'tenant_lifecycle_request', id,
          { type: request.type, leaseId: lease.id, resultLeaseId, executionId: execution.id });
        return { data: { id: execution.id, resultLeaseId, createdAt: execution.createdAt }, idempotent: false };
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && ['P2002', 'P2034', 'P2010'].includes(error.code)) throw new ConflictException('Dữ liệu đang thay đổi. Tải lại trạng thái trước khi thực hiện tiếp.');
      throw error;
    }
  }

  async occupants(actor: AuthUser, leaseId?: string) {
    return this.prisma.$transaction(async (tx) => {
      const tenant = actor.role === AuthRole.TENANT ? await this.tenant(tx, actor.userId) : null;
      const leaseWhere: Prisma.LeaseWhereInput = { ...(leaseId ? { id: leaseId } : {}), ...(tenant ? { tenantId: tenant.id } : {}), room: { property: propertyWhere(tenant?.landlordId ?? landlordScopeId(actor)) } };
      if (leaseId && !await tx.lease.findFirst({ where: leaseWhere, select: { id: true } })) throw new NotFoundException('Lease not found.');
      const rows = await tx.tenantOccupant.findMany({ where: { lease: leaseWhere }, orderBy: { createdAt: 'asc' }, select: { id: true, tenantId: true, leaseId: true, fullName: true, phone: true, relationship: true, createdAt: true } });
      return { data: rows };
    });
  }

  async addOccupant(actor: AuthUser, leaseId: string, input: TenantOccupantDto) {
    const fullName = this.reason(input.fullName);
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "Lease" WHERE "id" = ${leaseId} FOR UPDATE`;
      const lease = await tx.lease.findFirst({ where: { id: leaseId, status: 'ACTIVE', tenant: { isActive: true }, room: { property: { ...propertyWhere(landlordScopeId(actor)), isArchived: false } } }, include: { room: true, _count: { select: { occupants: true } } } });
      if (!lease) throw new NotFoundException('Active lease not found.');
      if (lease._count.occupants + 1 >= (lease.room.capacity ?? 100)) throw new ConflictException('The room occupant capacity is reached.');
      const occupant = await tx.tenantOccupant.create({ data: { tenantId: lease.tenantId, leaseId, fullName, phone: input.phone?.trim() || null, idNumber: input.idNumber?.trim() || null, relationship: input.relationship?.trim() || null } });
      await this.audit(tx, actor, landlordScopeId(actor), 'tenant.occupant.add', 'tenant_occupant', occupant.id, { leaseId, tenantId: lease.tenantId });
      const { idNumber: omitted, ...data } = occupant;
      return { data };
    });
  }

  async removeOccupant(actor: AuthUser, leaseId: string, id: string) {
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT "id" FROM "Lease" WHERE "id" = ${leaseId} FOR UPDATE`;
      const occupant = await tx.tenantOccupant.findFirst({ where: { id, leaseId, lease: { status: 'ACTIVE', room: { property: propertyWhere(landlordScopeId(actor)) } } } });
      if (!occupant) throw new NotFoundException('Active lease occupant not found.');
      await tx.tenantOccupant.delete({ where: { id } });
      await this.audit(tx, actor, landlordScopeId(actor), 'tenant.occupant.remove', 'tenant_occupant', id, { leaseId, tenantId: occupant.tenantId });
      return { data: { removed: true } };
    });
  }

  async preference(actor: AuthUser) {
    const tenant = await this.tenant(this.prisma, actor.userId);
    return { data: await this.prisma.tenantNotificationPreference.findUnique({ where: { tenantId: tenant.id } }) ?? defaultPreference };
  }

  async savePreference(actor: AuthUser, input: TenantNotificationPreferenceDto) {
    if (input.enabled && !input.channels.length) throw new BadRequestException('Select at least one notification channel.');
    return this.prisma.$transaction(async (tx) => {
      const tenant = await this.tenant(tx, actor.userId);
      const data = await tx.tenantNotificationPreference.upsert({ where: { tenantId: tenant.id }, create: { tenantId: tenant.id, enabled: input.enabled, channels: input.channels }, update: { enabled: input.enabled, channels: input.channels } });
      await this.audit(tx, actor, tenant.landlordId, 'tenant.notification_preference.update', 'tenant', tenant.id, { enabled: data.enabled, channels: data.channels });
      return { data };
    });
  }
}
