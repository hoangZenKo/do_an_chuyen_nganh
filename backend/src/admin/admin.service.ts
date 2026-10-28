import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { LeaseStatus, Prisma, RoomStatus, User, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';

import { PrismaService } from '../prisma/prisma.service';
import { CreateAdminPropertyDto } from './dto/create-admin-property.dto';
import { CreateLandlordDto } from './dto/create-landlord.dto';
import { ListAdminPropertiesQueryDto } from './dto/list-admin-properties-query.dto';
import { ListAdminRoomsQueryDto } from './dto/list-admin-rooms-query.dto';
import { ListLandlordsQueryDto } from './dto/list-landlords-query.dto';
import { UpdateAdminPropertyDto } from './dto/update-admin-property.dto';
import { UpdateLandlordDto } from './dto/update-landlord.dto';
import { UpdateLandlordStatusDto } from './dto/update-landlord-status.dto';
import { adminAudit, maskedEmail, maskedPhone } from './admin-audit';
import { assertInventoryGrowth } from '../common/subscription-entitlements';
import { propertyApprovalSelect, propertyApprovalState } from './property-review-state';
import { AdminConsoleService } from './admin-console.service';
import { AuthUser } from '../common/current-user.decorator';

type LandlordWithRelations = User & {
  properties: { rooms: { status: RoomStatus }[] }[];
  tenants: { id: string }[];
};

const ownerSelect = { id: true, fullName: true, email: true, phone: true, isActive: true } as const;
const inventoryRoomSelect = { id: true, name: true, status: true, floor: true, areaSqm: true,
  basePrice: true, isActive: true, listing: { select: { id: true, title: true, status: true, version: true, monthlyRent: true } } } as const;

type PropertySummaryInput = {
  id: string;
  name: string;
  address: string;
  landlord: {
    id: string;
    fullName: string;
    email: string;
    phone: string | null;
    isActive: boolean;
  } | null;
  rooms: { status: RoomStatus }[];
  isArchived?: boolean;
};

const landlordNotFound = () =>
  new NotFoundException({
    error: { code: 'LANDLORD_NOT_FOUND', message: 'Landlord not found.' },
  });

const propertyNotFound = () =>
  new NotFoundException({
    error: { code: 'PROPERTY_NOT_FOUND', message: 'Property not found.' },
  });

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService, private readonly console: AdminConsoleService) {}

  async overview(actor: AuthUser) {
    const [total, active, properties, rooms, tenants, leases, recentLandlords, recentProperties] = await Promise.all([
      this.prisma.user.count({ where: { role: 'LANDLORD' } }), this.prisma.user.count({ where: { role: 'LANDLORD', isActive: true } }),
      this.prisma.property.count(), this.prisma.room.count(), this.prisma.tenant.count(), this.prisma.lease.count({ where: { status: 'ACTIVE' } }),
      this.listLandlords({ page: 1, limit: 5 }), this.listProperties({ page: 1, limit: 5 }),
    ]);
    return { data: { generatedAt: new Date().toISOString(), landlords: { total, active, inactive: total - active },
      properties: { total: properties }, rooms: { total: rooms }, tenants: { total: tenants }, leases: { active: leases },
      recentLandlords: actor.permissions?.includes('admin.accounts.manage') ? recentLandlords.data : [], recentProperties: actor.permissions?.includes('admin.properties.manage') ? recentProperties.data : [] } };
  }

  async listLandlords(query: ListLandlordsQueryDto) {
    const where = this.landlordWhere(query);
    return this.prisma.$transaction(async tx => {
      const total = await tx.user.count({ where });
      const users = await tx.user.findMany({ where, select: { id: true, fullName: true, email: true, phone: true, isActive: true, sessionVersion: true, _count: { select: { properties: true, tenants: true } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit });
      const ids = users.map(user => user.id);
      const counts = ids.length ? await tx.$queryRaw<{ landlordId: string; rooms: number; occupied: number }[]>(Prisma.sql`SELECT p."landlordId", COUNT(r.id)::int AS rooms, COUNT(r.id) FILTER (WHERE r.status = 'OCCUPIED')::int AS occupied
        FROM "Property" p LEFT JOIN "Room" r ON r."propertyId" = p.id WHERE p."landlordId" IN (${Prisma.join(ids)}) GROUP BY p."landlordId"`) : [];
      const data = users.map(user => { const count = counts.find(item => item.landlordId === user.id); return { ...this.serializeLandlordRecord(user), version: user.sessionVersion,
        propertyCount: user._count.properties, tenantCount: user._count.tenants, roomCount: count?.rooms ?? 0, occupiedCount: count?.occupied ?? 0 }; });
      return { data, meta: { total, page: query.page, limit: query.limit, pages: Math.ceil(total / query.limit) } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async createLandlord(input: CreateLandlordDto, actor: AuthUser) {
    if (process.env.NODE_ENV === 'production') throw new ForbiddenException('Use account invitations in production.');
    const passwordHash = await argon2.hash(input.password);
    try {
      return await this.prisma.$transaction(async tx => {
        const landlord = await tx.user.create({ data: { fullName: input.fullName.trim(), email: this.normalizeEmail(input.email), phone: input.phone?.trim() || null, passwordHash, role: 'LANDLORD' } });
        await adminAudit(tx, actor, 'admin.landlord_create', 'user', landlord.id, 'Created landlord through local account setup');
        return { data: this.serializeLandlordRecord(landlord) };
      });
    } catch (error) { if (this.isUniqueViolation(error)) throw new ConflictException({ error: { code: 'LANDLORD_EMAIL_ALREADY_REGISTERED', message: 'Email is already registered.' } }); throw error; }
  }

  async getLandlord(id: string) {
    const query = { page: 1, limit: 1 };
    const user = await this.prisma.user.findFirst({ where: { id, role: 'LANDLORD' }, select: { id: true, fullName: true, email: true, phone: true, isActive: true, sessionVersion: true, _count: { select: { properties: true, tenants: true } } } });
    if (!user) throw landlordNotFound();
    const [activeLeaseCount, properties, roomCount, occupiedCount] = await Promise.all([
      this.prisma.lease.count({ where: { status: 'ACTIVE', room: { property: { landlordId: id } } } }), this.listProperties({ ...query, limit: 8, landlordId: id }),
      this.prisma.room.count({ where: { property: { landlordId: id } } }), this.prisma.room.count({ where: { property: { landlordId: id }, status: 'OCCUPIED' } }),
    ]);
    return { data: { ...this.serializeLandlordRecord(user), version: user.sessionVersion, propertyCount: user._count.properties, tenantCount: user._count.tenants,
      roomCount, occupiedCount, activeLeaseCount, recentProperties: properties.data } };
  }

  async updateLandlord(id: string, input: UpdateLandlordDto, actor: AuthUser) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id} FOR UPDATE`;
      const before = await tx.user.findFirst({ where: { id, role: 'LANDLORD' }, select: { fullName: true, phone: true } });
      if (!before) throw landlordNotFound();
      const landlord = await tx.user.update({ where: { id }, data: { ...(input.fullName !== undefined ? { fullName: input.fullName.trim() } : {}), ...(input.phone !== undefined ? { phone: input.phone.trim() || null } : {}) } });
      await adminAudit(tx, actor, 'admin.landlord_update', 'user', id, 'Updated landlord profile', { changedFields: Object.keys(input) });
      return { data: this.serializeLandlordRecord(landlord) };
    });
  }

  async updateLandlordStatus(currentUserId: string, id: string, input: UpdateLandlordStatusDto, actor: AuthUser) {
    if (currentUserId === id) throw new ForbiddenException('Cannot modify your own status.');
    const target = await this.prisma.user.findFirst({ where: { id, role: 'LANDLORD' } });
    if (!target) throw landlordNotFound();
    await this.console.status(actor, id, { reason: input.reason ?? 'Admin status change', version: input.version ?? target.sessionVersion }, input.isActive);
    return { data: this.serializeLandlordRecord(await this.prisma.user.findUniqueOrThrow({ where: { id } })) };
  }

  async listProperties(query: ListAdminPropertiesQueryDto) {
    const where = this.propertyWhere(query);
    return this.prisma.$transaction(async tx => {
      const total = await tx.property.count({ where });
      const rows = await tx.property.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit,
        select: { id: true, name: true, address: true, isArchived: true, landlordId: true, approvalReview: { select: propertyApprovalSelect }, landlord: { select: { id: true, fullName: true, email: true, phone: true, isActive: true } }, _count: { select: { rooms: true } } } });
      const counts = rows.length ? await tx.room.groupBy({ by: ['propertyId', 'status'], where: { propertyId: { in: rows.map(row => row.id) } }, _count: { _all: true } }) : [];
      const data = rows.map(row => ({ id: row.id, name: row.name, address: row.address, approval: propertyApprovalState(row, row.approvalReview), landlord: row.landlord ? { ...row.landlord, email: maskedEmail(row.landlord.email), phone: maskedPhone(row.landlord.phone) } : null, isArchived: row.isArchived, roomCount: row._count.rooms,
        occupiedCount: counts.find(item => item.propertyId === row.id && item.status === 'OCCUPIED')?._count._all ?? 0,
        vacantCount: counts.find(item => item.propertyId === row.id && item.status === 'VACANT')?._count._all ?? 0 }));
      return { data, meta: { total, page: query.page, limit: query.limit, pages: Math.ceil(total / query.limit) } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async createProperty(input: CreateAdminPropertyDto, actor: AuthUser) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${input.landlordId} FOR UPDATE`;
      if (!await tx.user.findFirst({ where: { id: input.landlordId, role: 'LANDLORD', isActive: true } })) throw landlordNotFound();
      await assertInventoryGrowth(tx, input.landlordId, 'property');
      const property = await tx.property.create({ data: { landlordId: input.landlordId, name: input.name.trim(), address: input.address?.trim() ?? '' }, include: { landlord: { select: { id: true, fullName: true, email: true, phone: true, isActive: true } }, rooms: { select: { status: true } } } });
      await adminAudit(tx, actor, 'admin.property_create', 'property', property.id, 'Created property');
      return { data: this.serializePropertySummary(property) };
    });
  }

  async getProperty(id: string) {
    return this.prisma.$transaction(async tx => ({ data: await this.propertyDetail(tx, id) }), { isolationLevel: 'RepeatableRead' });
  }

  async rooms(query: ListAdminRoomsQueryDto) {
    if (query.minPrice !== undefined && query.maxPrice !== undefined && query.minPrice > query.maxPrice) {
      throw new BadRequestException('Giá tối thiểu phải nhỏ hơn hoặc bằng giá tối đa.');
    }
    const search = query.search?.trim();
    const where: Prisma.RoomWhereInput = {
      ...(query.propertyId ? { propertyId: query.propertyId } : {}),
      ...(query.landlordId ? { property: { landlordId: query.landlordId } } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.activity && query.activity !== 'all' ? { isActive: query.activity === 'active' } : {}),
      ...(query.minPrice !== undefined || query.maxPrice !== undefined ? { basePrice: { gte: query.minPrice, lte: query.maxPrice } } : {}),
      ...(query.listingStatus ? { listing: query.listingStatus === 'NONE' ? { is: null } : { is: { status: query.listingStatus } } } : {}),
      ...(search ? { OR: [{ name: { contains: search, mode: 'insensitive' } },
        { property: { name: { contains: search, mode: 'insensitive' } } },
        { property: { landlord: { fullName: { contains: search, mode: 'insensitive' } } } }] } : {}),
    };
    return this.prisma.$transaction(async tx => {
      const total = await tx.room.count({ where });
      const rows = await tx.room.findMany({ where, select: { ...inventoryRoomSelect,
        property: { select: { id: true, name: true, address: true, isArchived: true, landlord: { select: ownerSelect } } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit });
      return { data: rows.map(room => ({ ...room, property: { ...room.property,
        landlord: this.maskedOwner(room.property.landlord) } })),
        meta: { total, page: query.page, limit: query.limit, pages: Math.ceil(total / query.limit) } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async updateProperty(id: string, input: UpdateAdminPropertyDto, actor: AuthUser) {
    return this.prisma.$transaction(async tx => {
      const before = await tx.property.findUnique({ where: { id } }); if (!before) throw propertyNotFound();
      await tx.property.update({ where: { id }, data: { ...(input.name !== undefined ? { name: input.name.trim() } : {}), ...(input.address !== undefined ? { address: input.address.trim() } : {}) } });
      await adminAudit(tx, actor, 'admin.property_update', 'property', id, 'Updated property', { changedFields: Object.keys(input) });
      return { data: await this.propertyDetail(tx, id) };
    });
  }

  private landlordWhere(query: ListLandlordsQueryDto): Prisma.UserWhereInput {
    const search = query.search?.trim();
    const status = query.status ?? 'all';
    return {
      role: UserRole.LANDLORD,
      ...(status === 'active' ? { isActive: true } : {}),
      ...(status === 'inactive' ? { isActive: false } : {}),
      ...(search
        ? {
            OR: [
              { fullName: { contains: search, mode: 'insensitive' } },
              { email: { contains: search, mode: 'insensitive' } },
              { phone: { contains: search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
  }

  private propertyWhere(query: ListAdminPropertiesQueryDto): Prisma.PropertyWhereInput {
    const search = query.search?.trim();
    return {
      ...(query.landlordId ? { landlordId: query.landlordId } : {}),
      ...(query.archived && query.archived !== 'all' ? { isArchived: query.archived === 'archived' } : {}),
      ...(query.ownerStatus && query.ownerStatus !== 'all' ? { landlord: { isActive: query.ownerStatus === 'active' } } : {}),
      ...(search
        ? {
            OR: [
              { name: { contains: search, mode: 'insensitive' } },
              { address: { contains: search, mode: 'insensitive' } },
              { landlord: { is: { fullName: { contains: search, mode: 'insensitive' } } } },
              { landlord: { is: { email: { contains: search, mode: 'insensitive' } } } },
            ],
          }
        : {}),
    };
  }

  private async findLandlord(id: string): Promise<LandlordWithRelations> {
    const landlord = await this.prisma.user.findFirst({
      where: { id, role: UserRole.LANDLORD },
      include: {
        _count: { select: { properties: true, tenants: true } },
        properties: {
          orderBy: { createdAt: 'desc' },
          include: { rooms: { select: { status: true } } },
        },
        tenants: { select: { id: true } },
      },
    });
    if (!landlord) throw landlordNotFound();
    return landlord as LandlordWithRelations;
  }

  private async propertyDetail(tx: Prisma.TransactionClient, id: string) {
    const property = await tx.property.findUnique({
      where: { id },
      select: { id: true, name: true, address: true, isArchived: true, landlordId: true, approvalReview: { select: propertyApprovalSelect }, landlord: { select: ownerSelect },
        _count: { select: { rooms: true } },
        rooms: { select: inventoryRoomSelect, take: 20, orderBy: [{ name: 'asc' }, { id: 'asc' }] } },
    });
    if (!property) throw propertyNotFound();
    const counts = await tx.room.groupBy({ by: ['status'], where: { propertyId: id }, _count: { _all: true } });
    return { id: property.id, name: property.name, address: property.address, isArchived: property.isArchived,
      approval: propertyApprovalState(property, property.approvalReview),
      landlord: this.maskedOwner(property.landlord), roomCount: property._count.rooms,
      occupiedCount: counts.find(item => item.status === 'OCCUPIED')?._count._all ?? 0,
      vacantCount: counts.find(item => item.status === 'VACANT')?._count._all ?? 0,
      rooms: property.rooms.map(room => ({ ...room, status: room.status.toLowerCase() })) };
  }

  private maskedOwner(owner: { id: string; fullName: string; email: string; phone: string | null; isActive: boolean }) {
    return { ...owner, email: maskedEmail(owner.email), phone: maskedPhone(owner.phone) };
  }

  private async requireLandlord(landlordId: string) {
    const landlord = await this.prisma.user.findFirst({
      where: { id: landlordId, role: UserRole.LANDLORD, isActive: true },
      select: { id: true, isActive: true },
    });
    if (!landlord) throw landlordNotFound();
    return landlord;
  }

  private serializeLandlordRecord(landlord: {
    id: string;
    fullName: string;
    email: string;
    phone: string | null;
    isActive: boolean;
  }) {
    return {
      id: landlord.id,
      fullName: landlord.fullName,
      email: maskedEmail(landlord.email),
      phone: maskedPhone(landlord.phone),
      role: 'landlord',
      isActive: landlord.isActive,
    };
  }

  private serializeLandlordSummary(landlord: {
    id: string;
    fullName: string;
    email: string;
    phone: string | null;
    isActive: boolean;
    properties?: { rooms?: { status: RoomStatus }[] }[];
    _count?: { properties: number; tenants: number };
  }) {
    const properties = landlord.properties ?? [];
    const roomCount = properties.reduce((sum, property) => sum + (property.rooms?.length ?? 0), 0);
    const occupiedCount = properties.reduce(
      (sum, property) =>
        sum + (property.rooms?.filter((room) => room.status === RoomStatus.OCCUPIED).length ?? 0),
      0,
    );
    return {
      id: landlord.id,
      fullName: landlord.fullName,
      email: maskedEmail(landlord.email),
      phone: maskedPhone(landlord.phone),
      isActive: landlord.isActive,
      propertyCount: landlord._count?.properties ?? properties.length,
      roomCount,
      occupiedCount,
      tenantCount: landlord._count?.tenants ?? 0,
    };
  }

  private serializePropertySummary(property: PropertySummaryInput) {
    const rooms = property.rooms ?? [];
    const roomCount = rooms.length;
    const occupiedCount = rooms.filter((room) => room.status === RoomStatus.OCCUPIED).length;
    return {
      id: property.id,
      name: property.name,
      address: property.address,
      isArchived: property.isArchived ?? false,
      landlord: property.landlord ? {
        id: property.landlord.id,
        fullName: property.landlord.fullName,
        email: maskedEmail(property.landlord.email),
        phone: maskedPhone(property.landlord.phone),
        isActive: property.landlord.isActive,
      } : null,
      roomCount,
      occupiedCount,
      vacantCount: rooms.filter(room => room.status === RoomStatus.VACANT).length,
    };
  }

  private normalizeEmail(value: string) {
    return value.trim().toLowerCase();
  }

  private isUniqueViolation(error: unknown) {
    return (
      (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') ||
      (typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as { code?: unknown }).code === 'P2002')
    );
  }
}
