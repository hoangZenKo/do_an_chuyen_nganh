import { propertyWhere, tenantScope } from '../common/property-scope';
import {
  ConflictException,
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  DepositTransaction,
  DepositTransactionType,
  Lease,
  LeaseChange,
  LeaseStatus,
  Prisma,
  RoomStatus,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CreateDepositTransactionDto } from './dto/create-deposit-transaction.dto';
import { CreateLeaseDto } from './dto/create-lease.dto';
import { RenewLeaseDto } from './dto/renew-lease.dto';
import { UpdateLeaseDto } from './dto/update-lease.dto';
import { beginTurnover } from '../operations/turnover.workflow';

type LeaseWithRelations = Lease & {
  room?: { id: string; name: string } | null;
  tenant?: { id: string; fullName: string } | null;
  depositTransactions?: DepositTransaction[];
  changes?: LeaseChange[];
};

const leaseNotFound = () =>
  new NotFoundException({
    error: { code: 'LEASE_NOT_FOUND', message: 'Lease not found.' },
  });

const roomNotFound = () =>
  new NotFoundException({
    error: { code: 'ROOM_NOT_FOUND', message: 'Room not found.' },
  });

const tenantNotFound = () =>
  new NotFoundException({
    error: { code: 'TENANT_NOT_FOUND', message: 'Tenant not found.' },
  });

const propertyArchived = () =>
  new ConflictException({
    error: {
      code: 'PROPERTY_ARCHIVED',
      message: 'Archived properties cannot receive new leases.',
    },
  });

const roomInactive = () =>
  new ConflictException({
    error: {
      code: 'ROOM_INACTIVE',
      message: 'Inactive rooms cannot receive new leases.',
    },
  });

const tenantInactive = () =>
  new ConflictException({
    error: {
      code: 'TENANT_INACTIVE',
      message: 'Inactive tenants cannot receive new leases.',
    },
  });

const roomOccupied = () =>
  new ConflictException({
    error: {
      code: 'ROOM_ALREADY_LEASED',
      message: 'Room already has an active lease.',
    },
  });

@Injectable()
export class LeasesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Creates an active lease and marks the room occupied — atomically, so the
   * room status can never drift from the lease.
   */
  async create(landlordId: string, input: CreateLeaseDto) {
    const lease = await this.prisma.$transaction((tx) =>
      this.createWithinTransaction(tx, landlordId, input));
    return { data: this.serialize(lease) };
  }

  async createWithinTransaction(
    tx: Prisma.TransactionClient,
    landlordId: string,
    input: CreateLeaseDto,
    recordDeposit = true,
  ) {
    await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${input.roomId} FOR UPDATE`;
    const room = await tx.room.findFirst({
      where: { id: input.roomId, property: propertyWhere(landlordId) },
      include: { property: { select: { isArchived: true } } },
    });
    if (!room) throw roomNotFound();
    if (room.property.isArchived) throw propertyArchived();
    if (!room.isActive) throw roomInactive();
    if (room.status === RoomStatus.MAINTENANCE || await tx.roomTurnover.count({ where: { roomId: room.id, status: 'ACTIVE' } })) {
      throw new ConflictException('Phòng chưa sẵn sàng cho thuê. Hãy hoàn tất quy trình trả phòng.');
    }

    const tenant = await tx.tenant.findFirst({
      where: { id: input.tenantId, landlordId, ...tenantScope() },
    });
    if (!tenant) throw tenantNotFound();
    if (!tenant.isActive) throw tenantInactive();

    const existingActive = await tx.lease.findFirst({
      where: { roomId: room.id, status: LeaseStatus.ACTIVE },
    });
    if (existingActive) throw roomOccupied();

    const created = await tx.lease.create({
      data: {
        roomId: room.id,
        tenantId: tenant.id,
          startDate: input.startDate ? this.parseDate(input.startDate) : new Date(),
        monthlyRent: input.monthlyRent,
        deposit: input.deposit ?? 0,
        status: LeaseStatus.ACTIVE,
      },
      include: {
        room: { select: { id: true, name: true } },
        tenant: { select: { id: true, fullName: true } },
      },
    });

    if (recordDeposit && (input.deposit ?? 0) > 0) {
      await tx.depositTransaction.create({
        data: {
          leaseId: created.id,
          landlordId,
          type: DepositTransactionType.COLLECTED,
          amount: input.deposit ?? 0,
          note: 'Thu cọc ban đầu khi tạo hợp đồng',
        },
      });
    }

    await tx.room.update({
      where: { id: room.id },
      data: { status: RoomStatus.OCCUPIED, tenantName: tenant.fullName },
    });

    return created;
  }

  /**
   * Ends an active lease and starts the room turnover pipeline atomically.
   */
  async end(landlordId: string, id: string) {
    const lease = await this.prisma.$transaction(async (tx) => {
      const found = await tx.lease.findFirst({
        where: { id, room: { property: propertyWhere(landlordId) } },
      });
      if (!found) throw leaseNotFound();

      await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${found.roomId} FOR UPDATE`;
      const latest = await tx.lease.findUniqueOrThrow({ where: { id } });
      if (latest.status === LeaseStatus.ENDED) return tx.lease.findUniqueOrThrow({ where: { id }, include: this.leaseInclude });

      const updated = await tx.lease.update({
        where: { id: found.id },
        data: { status: LeaseStatus.ENDED, endDate: new Date() },
        include: {
          room: { select: { id: true, name: true } },
          tenant: { select: { id: true, fullName: true } },
        },
      });

      // Keep the room unavailable until the turnover pipeline is complete.
      const stillActive = await tx.lease.findFirst({
        where: { roomId: found.roomId, status: LeaseStatus.ACTIVE },
      });
      if (!stillActive) {
        await tx.room.update({
          where: { id: found.roomId },
          data: { status: RoomStatus.MAINTENANCE, tenantName: null },
        });
        await beginTurnover(tx, landlordId, found.roomId, found.id);
      }

      return updated;
    });

    return { data: this.serialize(lease) };
  }

  async update(landlordId: string, id: string, input: UpdateLeaseDto) {
    const existing = await this.findOwned(landlordId, id);
    const next = {
      startDate: input.startDate ? this.parseDate(input.startDate) : existing.startDate,
      endDate:
        input.endDate !== undefined ? this.parseDate(input.endDate) : existing.endDate,
      monthlyRent: input.monthlyRent ?? existing.monthlyRent,
      deposit: input.deposit ?? existing.deposit,
    };
    this.assertLeaseDates(next.startDate, next.endDate);

    const lease = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${existing.roomId} FOR UPDATE`;
      await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${id} FOR UPDATE`;
      if (await tx.leaseSettlement.findUnique({ where: { leaseId: id } })) throw new ConflictException('Không sửa hợp đồng đã quyết toán.');
      const updated = await tx.lease.update({
        where: { id: existing.id },
        data: next,
        include: this.leaseInclude,
      });
      await this.recordLeaseChange(tx, landlordId, existing, updated, 'update', input.note);
      return updated;
    });
    return { data: this.serialize(lease) };
  }

  async renew(landlordId: string, id: string, input: RenewLeaseDto) {
    const lease = await this.prisma.$transaction(tx => this.renewWithinTransaction(tx, landlordId, id, input));
    return { data: this.serialize(lease) };
  }

  async renewWithinTransaction(tx: Prisma.TransactionClient, landlordId: string, id: string, input: RenewLeaseDto) {
    const found = await tx.lease.findFirst({ where: { id, room: { property: propertyWhere(landlordId) } } });
    if (!found) throw leaseNotFound();
    await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${found.roomId} FOR UPDATE`;
    await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${id} FOR UPDATE`;
    const existing = await tx.lease.findUniqueOrThrow({ where: { id } });
    if (existing.status !== LeaseStatus.ACTIVE) {
      throw new ConflictException({
        error: {
          code: 'LEASE_NOT_ACTIVE',
          message: 'Only active leases can be renewed.',
        },
      });
    }
    const endDate = this.parseDate(input.endDate);
    this.assertLeaseDates(existing.startDate, endDate);
      if (await tx.leaseSettlement.findUnique({ where: { leaseId: id } })) throw new ConflictException('Không gia hạn hợp đồng đã quyết toán.');
      if (endDate <= (existing.endDate ?? existing.startDate)) throw new ConflictException('Ngày gia hạn phải sau ngày kết thúc hiện tại.');
      const updated = await tx.lease.update({
        where: { id: existing.id },
        data: {
          endDate,
          ...(input.monthlyRent !== undefined
            ? { monthlyRent: input.monthlyRent }
            : {}),
          ...(input.deposit !== undefined ? { deposit: input.deposit } : {}),
        },
        include: this.leaseInclude,
      });
      await this.recordLeaseChange(tx, landlordId, existing, updated, 'renew', input.note);
      return updated;
  }

  async depositTransactions(landlordId: string, id: string) {
    const lease = await this.findOwned(landlordId, id);
    const transactions = await this.prisma.depositTransaction.findMany({
      where: { leaseId: lease.id },
      orderBy: [{ occurredAt: 'desc' }, { createdAt: 'desc' }],
    });
    return { data: transactions.map((item) => this.serializeDepositTransaction(item)) };
  }

  async expiring(landlordId: string, days = 30) {
    const today = this.dayStart(new Date());
    const until = this.addDays(today, Math.min(Math.max(days, 1), 180));
    const leases = await this.prisma.lease.findMany({
      where: {
        status: LeaseStatus.ACTIVE,
        endDate: { gte: today, lte: until },
        room: { property: propertyWhere(landlordId) },
      },
      include: {
        room: {
          select: {
            id: true,
            name: true,
            property: { select: { id: true, name: true } },
          },
        },
        tenant: { select: { id: true, fullName: true, phone: true } },
      },
      orderBy: { endDate: 'asc' },
    });

    return {
      data: leases.map((lease) => ({
        id: lease.id,
        roomId: lease.roomId,
        roomName: lease.room?.name ?? null,
        propertyId: lease.room?.property?.id ?? null,
        propertyName: lease.room?.property?.name ?? null,
        tenantId: lease.tenantId,
        tenantName: lease.tenant?.fullName ?? null,
        tenantPhone: lease.tenant?.phone ?? null,
        startDate: lease.startDate.toISOString(),
        endDate: lease.endDate?.toISOString() ?? null,
        monthlyRent: lease.monthlyRent,
        deposit: lease.deposit,
        daysUntilEnd: lease.endDate
          ? Math.ceil((lease.endDate.getTime() - today.getTime()) / 86_400_000)
          : null,
      })),
    };
  }

  async createDepositTransaction(
    landlordId: string,
    id: string,
    input: CreateDepositTransactionDto,
  ) {
    await this.findOwned(landlordId, id);
    const transaction = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${id} FOR UPDATE`;
      if (await tx.leaseSettlement.findUnique({ where: { leaseId: id } })) throw new ConflictException('Cọc đã được quyết toán. Dùng quy trình ghi nhận hoàn cọc của quyết toán.');
      const type = this.depositType(input.type);
      const entries = await tx.depositTransaction.findMany({ where: { leaseId: id } });
      const balance = this.depositBalance({ depositTransactions: entries } as LeaseWithRelations);
      if ((type === DepositTransactionType.REFUNDED || type === DepositTransactionType.DEDUCTED) && input.amount > balance) {
        throw new ConflictException('Số tiền hoàn hoặc khấu trừ vượt số dư cọc hiện có.');
      }
      return tx.depositTransaction.create({
        data: {
          leaseId: id,
          landlordId,
          type,
          amount: input.amount,
          occurredAt: input.occurredAt ? this.parseDate(input.occurredAt) : undefined,
          note: input.note?.trim(),
        },
      });
    });
    return { data: this.serializeDepositTransaction(transaction) };
  }

  async listByRoom(landlordId: string, roomId: string) {
    const room = await this.prisma.room.findFirst({
      where: { id: roomId, property: propertyWhere(landlordId) },
    });
    if (!room) throw roomNotFound();
    const leases = await this.prisma.lease.findMany({
      where: { roomId },
      orderBy: { startDate: 'desc' },
      include: {
        ...this.leaseInclude,
      },
    });
    return { data: leases.map((l) => this.serialize(l)) };
  }

  async listByTenant(landlordId: string, tenantId: string) {
    const tenant = await this.prisma.tenant.findFirst({
      where: { id: tenantId, landlordId, ...tenantScope() },
    });
    if (!tenant) throw tenantNotFound();
    const leases = await this.prisma.lease.findMany({
      where: { tenantId },
      orderBy: { startDate: 'desc' },
      include: {
        ...this.leaseInclude,
      },
    });
    return { data: leases.map((l) => this.serialize(l)) };
  }

  private readonly leaseInclude = {
    room: { select: { id: true, name: true } },
    tenant: { select: { id: true, fullName: true } },
    depositTransactions: { orderBy: { occurredAt: 'desc' as const } },
    changes: { orderBy: { createdAt: 'desc' as const }, take: 10 },
  };

  private async findOwned(landlordId: string, id: string) {
    const lease = await this.prisma.lease.findFirst({
      where: { id, room: { property: propertyWhere(landlordId) } },
      include: this.leaseInclude,
    });
    if (!lease) throw leaseNotFound();
    return lease;
  }

  private async recordLeaseChange(
    tx: Prisma.TransactionClient,
    landlordId: string,
    previous: Lease,
    next: Lease,
    changeType: string,
    note?: string,
  ) {
    const previousValues = {
      startDate: previous.startDate.toISOString(),
      endDate: previous.endDate?.toISOString() ?? null,
      monthlyRent: previous.monthlyRent,
      deposit: previous.deposit,
    };
    const newValues = {
      startDate: next.startDate.toISOString(),
      endDate: next.endDate?.toISOString() ?? null,
      monthlyRent: next.monthlyRent,
      deposit: next.deposit,
    };
    await tx.leaseChange.create({
      data: {
        leaseId: next.id,
        landlordId,
        changeType,
        previousValues,
        newValues,
        note: note?.trim(),
      },
    });
  }

  private parseDate(value: string) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException({
        error: { code: 'INVALID_LEASE_DATE', message: 'Lease date is invalid.' },
      });
    }
    return date;
  }

  private dayStart(date: Date) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  }

  private addDays(date: Date, days: number) {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + days));
  }

  private assertLeaseDates(startDate: Date, endDate?: Date | null) {
    if (endDate && endDate < startDate) {
      throw new BadRequestException({
        error: {
          code: 'INVALID_LEASE_PERIOD',
          message: 'Lease end date must be after the start date.',
        },
      });
    }
  }

  private depositType(value: string) {
    const normalized = value.toUpperCase();
    if (normalized in DepositTransactionType) {
      return DepositTransactionType[
        normalized as keyof typeof DepositTransactionType
      ];
    }
    throw new BadRequestException({
      error: { code: 'INVALID_DEPOSIT_TYPE', message: 'Invalid deposit type.' },
    });
  }

  serialize(lease: LeaseWithRelations) {
    return {
      id: lease.id,
      roomId: lease.roomId,
      roomName: lease.room?.name ?? null,
      tenantId: lease.tenantId,
      tenantName: lease.tenant?.fullName ?? null,
      startDate: lease.startDate.toISOString(),
      endDate: lease.endDate ? lease.endDate.toISOString() : null,
      monthlyRent: lease.monthlyRent,
      deposit: lease.deposit,
      depositBalance: this.depositBalance(lease),
      depositTransactions:
        lease.depositTransactions?.map((item) =>
          this.serializeDepositTransaction(item),
        ) ?? [],
      changes: lease.changes?.map((item) => ({
        id: item.id,
        leaseId: item.leaseId,
        changeType: item.changeType,
        previousValues: item.previousValues,
        newValues: item.newValues,
        note: item.note,
        createdAt: item.createdAt.toISOString(),
      })) ?? [],
      status: lease.status.toLowerCase(),
    };
  }

  private depositBalance(lease: LeaseWithRelations) {
    const transactions = lease.depositTransactions ?? [];
    return transactions.reduce((sum, item) => {
      if (
        item.type === DepositTransactionType.COLLECTED ||
        item.type === DepositTransactionType.ADJUSTMENT
      ) {
        return sum + item.amount;
      }
      return sum - item.amount;
    }, 0);
  }

  private serializeDepositTransaction(item: DepositTransaction) {
    return {
      id: item.id,
      leaseId: item.leaseId,
      type: item.type.toLowerCase(),
      amount: item.amount,
      occurredAt: item.occurredAt.toISOString(),
      note: item.note,
      createdAt: item.createdAt.toISOString(),
    };
  }
}
