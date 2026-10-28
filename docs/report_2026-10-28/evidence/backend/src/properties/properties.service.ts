import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { LeaseStatus, Property, RoomStatus } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { propertyWhere } from '../common/property-scope';
import { CreatePropertyDto } from './dto/create-property.dto';
import { ListPropertiesQueryDto } from './dto/list-properties-query.dto';
import { UpdatePropertyDto } from './dto/update-property.dto';
import { UpdatePropertyStatusDto } from './dto/update-property-status.dto';
import { assertInventoryGrowth } from '../common/subscription-entitlements';

type PropertyWithCounts = Property & {
  _count?: { rooms: number };
  rooms?: { status: RoomStatus }[];
};

const propertyNotFound = () =>
  new NotFoundException({
    error: { code: 'PROPERTY_NOT_FOUND', message: 'Property not found.' },
  });

const propertyHasActiveLease = () =>
  new ConflictException({
    error: {
      code: 'PROPERTY_HAS_ACTIVE_LEASE',
      message: 'End active leases before archiving or deleting this property.',
    },
  });

const propertyHasRelatedRooms = () =>
  new ConflictException({
    error: {
      code: 'PROPERTY_HAS_RELATED_ROOMS',
      message: 'Only properties without rooms can be permanently deleted.',
    },
  });

@Injectable()
export class PropertiesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(landlordId: string, query: ListPropertiesQueryDto = {}) {
    const lifecycle = query.lifecycle ?? 'active';
    const properties = await this.prisma.property.findMany({
      where: {
        ...propertyWhere(landlordId),
        ...(lifecycle === 'active' ? { isArchived: false } : {}),
        ...(lifecycle === 'archived' ? { isArchived: true } : {}),
      },
      orderBy: { createdAt: 'asc' },
      include: { rooms: { select: { status: true } } },
    });
    return { data: properties.map((p) => this.serialize(p)) };
  }

  async getById(landlordId: string, id: string) {
    const property = await this.findOwned(landlordId, id);
    return { data: this.serialize(property) };
  }

  async create(landlordId: string, input: CreatePropertyDto) {
    return this.prisma.$transaction(async tx => {
    await assertInventoryGrowth(tx, landlordId, 'property');
    const property = await tx.property.create({
      data: {
        landlordId,
        name: input.name.trim(),
        address: input.address?.trim() ?? '',
      },
      include: { rooms: { select: { status: true } } },
    });
    return { data: this.serialize(property) };
    });
  }

  async update(landlordId: string, id: string, input: UpdatePropertyDto) {
    await this.findOwned(landlordId, id);
    const property = await this.prisma.property.update({
      where: { id },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.address !== undefined ? { address: input.address.trim() } : {}),
      },
      include: { rooms: { select: { status: true } } },
    });
    return { data: this.serialize(property) };
  }

  async updateStatus(
    landlordId: string,
    id: string,
    input: UpdatePropertyStatusDto,
  ) {
    return this.prisma.$transaction(async tx => {
    await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${landlordId} FOR UPDATE`;
    const property = await tx.property.findFirst({ where: { id, ...propertyWhere(landlordId) } });
    if (!property) throw propertyNotFound();
    if (input.isArchived) {
      const lease = await tx.lease.findFirst({ where: { status: LeaseStatus.ACTIVE, room: { propertyId: id } }, select: { id: true } });
      if (lease) throw propertyHasActiveLease();
    }
    if (property.isArchived && !input.isArchived) {
      await assertInventoryGrowth(tx, landlordId, 'property');
      const roomCount = await tx.room.count({ where: { propertyId: id, isActive: true } });
      if (roomCount) await assertInventoryGrowth(tx, landlordId, 'room', roomCount);
    }
    const updated = await tx.property.update({
      where: { id: property.id },
      data: { isArchived: input.isArchived },
      include: { rooms: { select: { status: true } } },
    });
    return { data: this.serialize(updated) };
    });
  }

  async remove(landlordId: string, id: string): Promise<void> {
    await this.findOwned(landlordId, id);
    await this.assertNoActiveLeases(id);
    const rooms = await this.prisma.room.count({ where: { propertyId: id } });
    if (rooms > 0) throw propertyHasRelatedRooms();
    await this.prisma.property.delete({ where: { id } });
  }

  /** Throws unless the property exists and belongs to this landlord. */
  async findOwned(landlordId: string, id: string) {
    const property = await this.prisma.property.findFirst({
      where: { id, ...propertyWhere(landlordId) },
      include: { rooms: { select: { status: true } } },
    });
    if (!property) throw propertyNotFound();
    return property;
  }

  private async assertNoActiveLeases(propertyId: string) {
    const activeLease = await this.prisma.lease.findFirst({
      where: {
        status: LeaseStatus.ACTIVE,
        room: { propertyId },
      },
      select: { id: true },
    });
    if (activeLease) throw propertyHasActiveLease();
  }

  serialize(property: PropertyWithCounts) {
    const rooms = property.rooms ?? [];
    const roomCount = rooms.length;
    const occupiedCount = rooms.filter(
      (r) => r.status === RoomStatus.OCCUPIED,
    ).length;
    return {
      id: property.id,
      name: property.name,
      address: property.address,
      isArchived: property.isArchived,
      roomCount,
      occupiedCount,
    };
  }
}
