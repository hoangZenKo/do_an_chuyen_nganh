import { propertyWhere } from '../common/property-scope';
import { assertInventoryGrowth } from '../common/subscription-entitlements';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import {
  LeaseStatus,
  Room,
  RoomAsset,
  RoomInspection,
  RoomStatus,
  Prisma,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { PropertiesService } from '../properties/properties.service';
import { CreateRoomAssetDto } from './dto/create-room-asset.dto';
import { CreateRoomInspectionDto } from './dto/create-room-inspection.dto';
import { CreateRoomServiceFeeDto } from './dto/create-room-service-fee.dto';
import { CreateRoomDto, RoomStatusWire } from './dto/create-room.dto';
import { ListRoomsQueryDto } from './dto/list-rooms-query.dto';
import { UpdateRoomAssetDto } from './dto/update-room-asset.dto';
import { UpdateRoomInspectionDto } from './dto/update-room-inspection.dto';
import { UpdateRoomServiceFeeDto } from './dto/update-room-service-fee.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { UpdateRoomStatusDto } from './dto/update-room-status.dto';
import { businessMonth, effectiveFee, tariffMonth, tariffVersionsInclude, VersionedServiceFee } from './service-tariff';

const roomNotFound = () =>
  new NotFoundException({
    error: { code: 'ROOM_NOT_FOUND', message: 'Room not found.' },
  });

const roomHasActiveLease = () =>
  new ConflictException({
    error: {
      code: 'ROOM_HAS_ACTIVE_LEASE',
      message: 'End the active lease before deactivating or deleting this room.',
    },
  });

const roomHasHistory = () =>
  new ConflictException({
    error: {
      code: 'ROOM_HAS_HISTORY',
      message: 'Only rooms without leases, meter readings, or invoices can be deleted.',
    },
  });

const roomInactive = () =>
  new ConflictException({
    error: {
      code: 'ROOM_INACTIVE',
      message: 'Inactive rooms cannot be updated for occupancy operations.',
    },
  });

const roomAssetNotFound = () =>
  new NotFoundException({
    error: { code: 'ROOM_ASSET_NOT_FOUND', message: 'Room asset not found.' },
  });

const roomInspectionNotFound = () =>
  new NotFoundException({
    error: {
      code: 'ROOM_INSPECTION_NOT_FOUND',
      message: 'Room inspection not found.',
    },
  });

const roomServiceFeeNotFound = () =>
  new NotFoundException({
    error: {
      code: 'ROOM_SERVICE_FEE_NOT_FOUND',
      message: 'Room service fee not found.',
    },
  });

const roomStatusConflictsWithLease = () =>
  new ConflictException({
    error: {
      code: 'ROOM_STATUS_CONFLICTS_WITH_LEASE',
      message: 'Room occupancy status must match its active lease state.',
    },
  });

@Injectable()
export class RoomsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly properties: PropertiesService,
  ) {}

  async listByProperty(
    landlordId: string,
    propertyId: string,
    query: ListRoomsQueryDto = {},
  ) {
    await this.properties.findOwned(landlordId, propertyId);
    const lifecycle = query.lifecycle ?? 'active';
    const rooms = await this.prisma.room.findMany({
      where: {
        propertyId,
        ...(lifecycle === 'active' ? { isActive: true } : {}),
        ...(lifecycle === 'inactive' ? { isActive: false } : {}),
      },
      orderBy: { name: 'asc' },
    });
    return { data: rooms.map((r) => this.serialize(r)) };
  }

  async getById(landlordId: string, id: string) {
    const room = await this.findOwned(landlordId, id);
    return { data: this.serialize(room) };
  }

  async create(landlordId: string, propertyId: string, input: CreateRoomDto) {
    return this.prisma.$transaction(async tx => {
    await assertInventoryGrowth(tx, landlordId, 'room');
    const property = await tx.property.findFirst({ where: { id: propertyId, ...propertyWhere(landlordId) } });
    if (!property) throw roomNotFound();
    if (property.isArchived) throw roomInactive();
    const status = this.toEnum(input.status);
    if (status === RoomStatus.OCCUPIED) throw roomStatusConflictsWithLease();
    const room = await tx.room.create({
      data: {
        propertyId,
        name: input.name.trim(),
        status,
        floor: input.floor ?? null,
        areaSqm: input.areaSqm ?? null,
        basePrice: input.basePrice,
        capacity: input.capacity ?? null,
        amenities: input.amenities ?? [],
        imageUrl: input.imageUrl?.trim() || null,
        note: input.note?.trim() || null,
      },
    });
    return { data: this.serialize(room) };
    });
  }

  async update(landlordId: string, id: string, input: UpdateRoomDto) {
    const current = await this.findOwned(landlordId, id);
    if (!current.isActive) throw roomInactive();
    if (input.status !== undefined) {
      await this.assertStatusAllowed(id, this.toEnum(input.status));
    }
    const room = await this.prisma.room.update({
      where: { id },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.status !== undefined ? { status: this.toEnum(input.status) } : {}),
        ...(input.floor !== undefined ? { floor: input.floor } : {}),
        ...(input.areaSqm !== undefined ? { areaSqm: input.areaSqm } : {}),
        ...(input.basePrice !== undefined ? { basePrice: input.basePrice } : {}),
        ...(input.capacity !== undefined ? { capacity: input.capacity } : {}),
        ...(input.amenities !== undefined ? { amenities: input.amenities } : {}),
        ...(input.imageUrl !== undefined
          ? { imageUrl: input.imageUrl.trim() || null }
          : {}),
        ...(input.note !== undefined ? { note: input.note.trim() || null } : {}),
      },
    });
    return { data: this.serialize(room) };
  }

  async updateStatus(
    landlordId: string,
    id: string,
    input: UpdateRoomStatusDto,
  ) {
    return this.prisma.$transaction(async tx => {
    await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${landlordId} FOR UPDATE`;
    const current = await tx.room.findFirst({ where: { id, property: propertyWhere(landlordId) }, include: { property: { select: { isArchived: true } } } });
    if (!current) throw roomNotFound();
    if (!input.isActive) {
      const lease = await tx.lease.findFirst({ where: { roomId: id, status: LeaseStatus.ACTIVE }, select: { id: true } });
      if (lease) throw roomHasActiveLease();
    } else if (!current.isActive) {
      if (current.property.isArchived) throw roomInactive();
      await assertInventoryGrowth(tx, landlordId, 'room');
    }
    const room = await tx.room.update({
      where: { id },
      data: { isActive: input.isActive },
    });
    return { data: this.serialize(room) };
    });
  }

  async remove(landlordId: string, id: string): Promise<void> {
    await this.findOwned(landlordId, id);
    await this.assertNoActiveLease(id);
    const [leases, meterReadings, invoices, viewings] = await this.prisma.$transaction([
      this.prisma.lease.count({ where: { roomId: id } }),
      this.prisma.meterReading.count({ where: { roomId: id } }),
      this.prisma.invoice.count({ where: { roomId: id } }),
      this.prisma.roomViewing.count({ where: { listing: { roomId: id } } }),
    ]);
    if (leases > 0 || meterReadings > 0 || invoices > 0 || viewings > 0 || await this.prisma.roomTurnover.count({ where: { roomId: id } }) > 0) throw roomHasHistory();
    await this.prisma.room.delete({ where: { id } });
  }

  async assets(landlordId: string, roomId: string) {
    await this.findOwned(landlordId, roomId);
    const assets = await this.prisma.roomAsset.findMany({
      where: { roomId },
      orderBy: [{ createdAt: 'desc' }, { name: 'asc' }],
    });
    return { data: assets.map((asset) => this.serializeAsset(asset)) };
  }

  async createAsset(
    landlordId: string,
    roomId: string,
    input: CreateRoomAssetDto,
  ) {
    await this.findOwned(landlordId, roomId);
    const asset = await this.prisma.roomAsset.create({
      data: {
        roomId,
        name: input.name.trim(),
        quantity: input.quantity ?? 1,
        condition: input.condition?.trim() || 'good',
        value: input.value ?? null,
        purchasedAt: input.purchasedAt ? new Date(input.purchasedAt) : null,
        note: input.note?.trim() || null,
        imageUrl: input.imageUrl?.trim() || null,
      },
    });
    return { data: this.serializeAsset(asset) };
  }

  async updateAsset(
    landlordId: string,
    roomId: string,
    assetId: string,
    input: UpdateRoomAssetDto,
  ) {
    await this.findOwned(landlordId, roomId);
    await this.findOwnedAsset(roomId, assetId);
    const asset = await this.prisma.roomAsset.update({
      where: { id: assetId },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.quantity !== undefined ? { quantity: input.quantity } : {}),
        ...(input.condition !== undefined
          ? { condition: input.condition.trim() || 'good' }
          : {}),
        ...(input.value !== undefined ? { value: input.value } : {}),
        ...(input.purchasedAt !== undefined
          ? { purchasedAt: new Date(input.purchasedAt) }
          : {}),
        ...(input.note !== undefined ? { note: input.note.trim() || null } : {}),
        ...(input.imageUrl !== undefined
          ? { imageUrl: input.imageUrl.trim() || null }
          : {}),
      },
    });
    return { data: this.serializeAsset(asset) };
  }

  async removeAsset(landlordId: string, roomId: string, assetId: string) {
    await this.findOwned(landlordId, roomId);
    await this.findOwnedAsset(roomId, assetId);
    await this.prisma.roomAsset.delete({ where: { id: assetId } });
  }

  async inspections(landlordId: string, roomId: string) {
    await this.findOwned(landlordId, roomId);
    const inspections = await this.prisma.roomInspection.findMany({
      where: { roomId },
      orderBy: [{ completedAt: 'asc' }, { dueAt: 'asc' }],
    });
    return { data: inspections.map((item) => this.serializeInspection(item)) };
  }

  async createInspection(
    landlordId: string,
    roomId: string,
    input: CreateRoomInspectionDto,
  ) {
    await this.findOwned(landlordId, roomId);
    const inspection = await this.prisma.roomInspection.create({
      data: {
        roomId,
        title: input.title.trim(),
        dueAt: new Date(input.dueAt),
        note: input.note?.trim() || null,
      },
    });
    return { data: this.serializeInspection(inspection) };
  }

  async updateInspection(
    landlordId: string,
    roomId: string,
    inspectionId: string,
    input: UpdateRoomInspectionDto,
  ) {
    await this.findOwned(landlordId, roomId);
    await this.findOwnedInspection(roomId, inspectionId);
    const inspection = await this.prisma.roomInspection.update({
      where: { id: inspectionId },
      data: {
        ...(input.title !== undefined ? { title: input.title.trim() } : {}),
        ...(input.dueAt !== undefined ? { dueAt: new Date(input.dueAt) } : {}),
        ...(input.completedAt !== undefined
          ? { completedAt: new Date(input.completedAt) }
          : {}),
        ...(input.note !== undefined ? { note: input.note.trim() || null } : {}),
      },
    });
    return { data: this.serializeInspection(inspection) };
  }

  async completeInspection(
    landlordId: string,
    roomId: string,
    inspectionId: string,
  ) {
    await this.findOwned(landlordId, roomId);
    await this.findOwnedInspection(roomId, inspectionId);
    const inspection = await this.prisma.roomInspection.update({
      where: { id: inspectionId },
      data: { completedAt: new Date() },
    });
    return { data: this.serializeInspection(inspection) };
  }

  async removeInspection(
    landlordId: string,
    roomId: string,
    inspectionId: string,
  ) {
    await this.findOwned(landlordId, roomId);
    await this.findOwnedInspection(roomId, inspectionId);
    await this.prisma.roomInspection.delete({ where: { id: inspectionId } });
  }

  async serviceFees(landlordId: string, roomId: string) {
    await this.findOwned(landlordId, roomId);
    const fees = await this.prisma.roomServiceFee.findMany({
      where: { roomId },
      orderBy: [{ isActive: 'desc' }, { name: 'asc' }],
      include: tariffVersionsInclude,
    });
    return { data: fees.map((fee) => this.serializeServiceFee(fee)) };
  }

  async createServiceFee(
    landlordId: string,
    roomId: string,
    input: CreateRoomServiceFeeDto,
  ) {
    await this.findOwned(landlordId, roomId);
    const effectiveFrom = tariffMonth(input.effectiveFrom, businessMonth());
    const fee = await this.prisma.$transaction(async (tx) => {
      await this.lockTariffRoom(tx, landlordId, roomId);
      await this.assertTariffMonthAvailable(tx, roomId, effectiveFrom);
      const name = this.tariffLabel(input.name);
      const unit = this.tariffLabel(input.unit ?? 'thang');
      const note = input.note?.trim() || null;
      return tx.roomServiceFee.create({
        data: { roomId, name, amount: input.amount, note,
          versions: { create: { version: 1, name, unit, amount: input.amount, note, effectiveFrom } },
        },
        include: tariffVersionsInclude,
      });
    });
    return { data: this.serializeServiceFee(fee) };
  }

  async updateServiceFee(
    landlordId: string,
    roomId: string,
    feeId: string,
    input: UpdateRoomServiceFeeDto,
  ) {
    await this.findOwned(landlordId, roomId);
    const fee = await this.prisma.$transaction(async (tx) => {
      await this.lockTariffRoom(tx, landlordId, roomId);
      const current = await tx.roomServiceFee.findFirst({ where: { id: feeId, roomId }, include: tariffVersionsInclude });
      if (!current) throw roomServiceFeeNotFound();
      const latest = current.versions[0];
      const version = latest?.version ?? 0;
      if (input.expectedVersion !== undefined && input.expectedVersion !== version) {
        throw new ConflictException({ error: { code: 'TARIFF_VERSION_CHANGED', message: 'Tariff changed. Reload before submitting.' } });
      }
      if (input.isActive !== undefined && input.isActive === (latest?.isActive ?? current.isActive)
        && Object.keys(input).every((key) => ['isActive', 'expectedVersion'].includes(key))) return current;
      const month = businessMonth();
      const nextMonth = new Date(Date.UTC(month.getUTCFullYear(), month.getUTCMonth() + 1, 1));
      const defaultMonth = latest && latest.effectiveFrom >= nextMonth
        ? new Date(Date.UTC(latest.effectiveFrom.getUTCFullYear(), latest.effectiveFrom.getUTCMonth() + 1, 1))
        : nextMonth;
      const effectiveFrom = tariffMonth(input.effectiveFrom, defaultMonth);
      if (latest && effectiveFrom <= latest.effectiveFrom) {
        throw new ConflictException({ error: { code: 'TARIFF_DATE_CONFLICT', message: 'New versions must start after the latest version.' } });
      }
      await this.assertTariffMonthAvailable(tx, roomId, effectiveFrom);
      const name = this.tariffLabel(input.name ?? latest?.name ?? current.name);
      const amount = input.amount ?? latest?.amount ?? current.amount;
      const isActive = input.isActive ?? latest?.isActive ?? current.isActive;
      const note = input.note !== undefined ? input.note?.trim() || null : latest?.note ?? current.note;
      const unit = this.tariffLabel(input.unit ?? latest?.unit ?? 'thang');
      return tx.roomServiceFee.update({
        where: { id: feeId },
        data: { name, amount, isActive, note,
          versions: { create: { version: version + 1, name, unit, amount, isActive, note, effectiveFrom } },
        },
        include: tariffVersionsInclude,
      });
    });
    return { data: this.serializeServiceFee(fee) };
  }

  async removeServiceFee(landlordId: string, roomId: string, feeId: string) {
    await this.updateServiceFee(landlordId, roomId, feeId, { isActive: false });
  }

  async serviceFeeVersions(landlordId: string, roomId: string, feeId: string) {
    await this.findOwned(landlordId, roomId);
    const fee = await this.prisma.roomServiceFee.findFirst({
      where: { id: feeId, roomId }, include: tariffVersionsInclude,
    });
    if (!fee) throw roomServiceFeeNotFound();
    return { data: this.serializeServiceFee(fee).versions };
  }

  private tariffLabel(value: string) {
    const label = value.trim();
    if (!label) throw new BadRequestException({ error: { code: 'INVALID_TARIFF_LABEL', message: 'Tariff name and unit must not be blank.' } });
    return label;
  }

  private async lockTariffRoom(tx: Prisma.TransactionClient, landlordId: string, roomId: string) {
    const properties = await tx.$queryRaw<{ id: string }[]>`SELECT p.id FROM "Property" p
      JOIN "Room" r ON r."propertyId" = p.id
      WHERE r.id = ${roomId} AND p."landlordId" = ${landlordId} FOR UPDATE OF p`;
    if (!properties.length) throw roomNotFound();
    await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${roomId} FOR UPDATE`;
  }

  private async assertTariffMonthAvailable(tx: Prisma.TransactionClient, roomId: string, month: Date) {
    if (month < businessMonth()) {
      throw new BadRequestException({ error: { code: 'TARIFF_RETROACTIVE', message: 'Cannot schedule a tariff in a past billing month.' } });
    }
    const invoiced = await tx.invoice.findFirst({ where: { roomId, isDemo: false, billingMonth: { gte: month } }, select: { id: true } });
    if (invoiced) throw new ConflictException({ error: { code: 'TARIFF_PERIOD_INVOICED', message: 'Invoices already exist for this period. Choose a later month.' } });
    const room = await tx.room.findUniqueOrThrow({ where: { id: roomId }, select: { propertyId: true } });
    const locked = await tx.billingPeriodLock.findFirst({ where: { propertyId: room.propertyId, month: { gte: month } }, select: { id: true } });
    if (locked) throw new ConflictException({ error: { code: 'TARIFF_PERIOD_CLOSED', message: 'The tariff affects a locked billing period. Choose a later month.' } });
  }

  /** Throws unless the room exists and its property belongs to this landlord. */
  private async findOwned(landlordId: string, id: string) {
    const room = await this.prisma.room.findFirst({
      where: { id, property: propertyWhere(landlordId) },
    });
    if (!room) throw roomNotFound();
    return room;
  }

  private async findOwnedAsset(roomId: string, assetId: string) {
    const asset = await this.prisma.roomAsset.findFirst({
      where: { id: assetId, roomId },
      select: { id: true },
    });
    if (!asset) throw roomAssetNotFound();
  }

  private async findOwnedInspection(roomId: string, inspectionId: string) {
    const inspection = await this.prisma.roomInspection.findFirst({
      where: { id: inspectionId, roomId },
      select: { id: true },
    });
    if (!inspection) throw roomInspectionNotFound();
  }

  private async findOwnedServiceFee(roomId: string, feeId: string) {
    const fee = await this.prisma.roomServiceFee.findFirst({
      where: { id: feeId, roomId },
      select: { id: true },
    });
    if (!fee) throw roomServiceFeeNotFound();
  }

  private async assertNoActiveLease(roomId: string) {
    const activeLease = await this.prisma.lease.findFirst({
      where: { roomId, status: LeaseStatus.ACTIVE },
      select: { id: true },
    });
    if (activeLease) throw roomHasActiveLease();
  }

  private async assertStatusAllowed(roomId: string, nextStatus: RoomStatus) {
    if (nextStatus !== RoomStatus.MAINTENANCE && await this.prisma.roomTurnover.count({ where: { roomId, status: 'ACTIVE' } })) {
      throw new ConflictException('Phòng đang trong quy trình trả phòng. Hãy hoàn tất pipeline trước khi cho thuê lại.');
    }
    const activeLease = await this.prisma.lease.findFirst({
      where: { roomId, status: LeaseStatus.ACTIVE },
      select: { id: true },
    });
    if (activeLease && nextStatus !== RoomStatus.OCCUPIED) {
      throw roomStatusConflictsWithLease();
    }
    if (!activeLease && nextStatus === RoomStatus.OCCUPIED) {
      throw roomStatusConflictsWithLease();
    }
  }

  private toEnum(status: RoomStatusWire): RoomStatus {
    return status.toUpperCase() as RoomStatus;
  }

  serialize(room: Room) {
    return {
      id: room.id,
      propertyId: room.propertyId,
      name: room.name,
      floor: room.floor,
      areaSqm: room.areaSqm,
      basePrice: room.basePrice,
      status: room.status.toLowerCase(),
      isActive: room.isActive,
      capacity: room.capacity,
      amenities: room.amenities,
      imageUrl: room.imageUrl,
      tenantName: room.tenantName,
      note: room.note,
    };
  }

  serializeAsset(asset: RoomAsset) {
    return {
      id: asset.id,
      roomId: asset.roomId,
      name: asset.name,
      quantity: asset.quantity,
      condition: asset.condition,
      value: asset.value,
      purchasedAt: asset.purchasedAt?.toISOString() ?? null,
      note: asset.note,
      imageUrl: asset.imageUrl,
      createdAt: asset.createdAt.toISOString(),
      updatedAt: asset.updatedAt.toISOString(),
    };
  }

  serializeInspection(inspection: RoomInspection) {
    return {
      id: inspection.id,
      roomId: inspection.roomId,
      title: inspection.title,
      dueAt: inspection.dueAt.toISOString(),
      completedAt: inspection.completedAt?.toISOString() ?? null,
      note: inspection.note,
      createdAt: inspection.createdAt.toISOString(),
      updatedAt: inspection.updatedAt.toISOString(),
    };
  }

  serializeServiceFee(fee: VersionedServiceFee) {
    const current = effectiveFee(fee, businessMonth());
    const versions = fee.versions ?? [];
    const latest = versions[0];
    return {
      id: fee.id,
      roomId: fee.roomId,
      name: current?.name ?? fee.name,
      amount: current?.amount ?? fee.amount,
      isActive: current !== null,
      unit: current?.unit ?? latest?.unit ?? 'thang',
      version: latest?.version ?? 0,
      effectiveFrom: latest?.effectiveFrom.toISOString() ?? null,
      versions: versions.map((version, index) => ({
        ...version,
        effectiveFrom: version.effectiveFrom.toISOString(),
        effectiveTo: index === 0 ? null : versions[index - 1].effectiveFrom.toISOString(),
        createdAt: version.createdAt.toISOString(),
      })),
      note: fee.note,
      createdAt: fee.createdAt.toISOString(),
      updatedAt: fee.updatedAt.toISOString(),
    };
  }
}
