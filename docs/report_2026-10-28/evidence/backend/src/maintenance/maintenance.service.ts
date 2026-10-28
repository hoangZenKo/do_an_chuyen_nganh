import { propertyWhere, propertyIdScope, scopedPropertyIds } from '../common/property-scope';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import {
  ExpenseCategory,
  UserRole,
  MaintenancePriority,
  MaintenanceStatus,
  MaintenanceComment,
  MaintenanceTicket,
} from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { CompleteMaintenanceTicketDto } from './dto/complete-maintenance-ticket.dto';
import { CreateMaintenanceCommentDto } from './dto/create-maintenance-comment.dto';
import { CreateMaintenanceTicketDto } from './dto/create-maintenance-ticket.dto';
import { ListMaintenanceQueryDto } from './dto/list-maintenance-query.dto';
import { UpdateMaintenanceStatusDto } from './dto/update-maintenance-status.dto';
import { UpdateMaintenanceTicketDto } from './dto/update-maintenance-ticket.dto';

type TicketWithRelations = MaintenanceTicket & {
  property?: { id: string; name: string } | null;
  room?: { id: string; name: string } | null;
  expense?: { id: string; amount: number; expenseDate: Date; title: string } | null;
  assignee?: { id: string; fullName: string } | null;
  comments?: CommentWithAuthor[];
};

type CommentWithAuthor = MaintenanceComment & {
  author?: { id: string; fullName: string; role: UserRole } | null;
};

const ticketNotFound = () =>
  new NotFoundException({
    error: {
      code: 'MAINTENANCE_TICKET_NOT_FOUND',
      message: 'Maintenance ticket not found.',
    },
  });

const propertyNotFound = () =>
  new NotFoundException({
    error: { code: 'PROPERTY_NOT_FOUND', message: 'Property not found.' },
  });

const roomNotFound = () =>
  new NotFoundException({
    error: { code: 'ROOM_NOT_FOUND', message: 'Room not found.' },
  });

@Injectable()
export class MaintenanceService {
  constructor(private readonly prisma: PrismaService) {}

  async assignees(landlordId: string, propertyId?: string) {
    if (propertyId) await this.assertOwnedProperty(landlordId, propertyId);
    const ids = scopedPropertyIds();
    return { data: await this.prisma.staffProfile.findMany({ where: { landlordId, isActive: true, user: { isActive: true }, permissions: { hasSome: ['maintenance.manage', 'maintenance.complete'] }, ...(propertyId || ids ? { propertyScopes: { some: { propertyId: propertyId ?? { in: ids } } } } : {}) }, select: { id: true, fullName: true }, orderBy: { fullName: 'asc' } }) };
  }

  async list(landlordId: string, query: ListMaintenanceQueryDto = {}) {
    if (query.propertyId) {
      await this.assertOwnedProperty(landlordId, query.propertyId);
    }
    if (query.roomId) {
      await this.assertOwnedRoom(landlordId, query.roomId, query.propertyId);
    }

    const tickets = await this.prisma.maintenanceTicket.findMany({
      where: {
        landlordId,
        ...propertyIdScope(),
        ...(query.propertyId ? { propertyId: query.propertyId } : {}),
        ...(query.roomId ? { roomId: query.roomId } : {}),
        ...(query.status ? { status: this.status(query.status) } : {}),
        ...(query.priority ? { priority: this.priority(query.priority) } : {}),
      },
      orderBy: [{ reportedAt: 'desc' }, { createdAt: 'desc' }],
      include: this.ticketInclude,
    });

    const openCount = tickets.filter(
      (ticket) =>
        ticket.status === MaintenanceStatus.OPEN ||
        ticket.status === MaintenanceStatus.IN_PROGRESS,
    ).length;
    const doneCount = tickets.filter(
      (ticket) => ticket.status === MaintenanceStatus.DONE,
    ).length;
    const estimatedCost = tickets.reduce(
      (sum, ticket) => sum + (ticket.estimatedCost ?? 0),
      0,
    );
    const actualCost = tickets.reduce(
      (sum, ticket) => sum + (ticket.actualCost ?? 0),
      0,
    );

    return {
      data: tickets.map((ticket) => this.serialize(ticket)),
      summary: {
        count: tickets.length,
        openCount,
        doneCount,
        estimatedCost,
        actualCost,
        overdueCount: tickets.filter((ticket) => ticket.dueAt && ticket.dueAt < new Date() && ['OPEN', 'IN_PROGRESS'].includes(ticket.status)).length,
      },
    };
  }

  async getById(landlordId: string, id: string) {
    const ticket = await this.findOwned(landlordId, id);
    return { data: this.serialize(ticket) };
  }

  async create(landlordId: string, input: CreateMaintenanceTicketDto) {
    await this.assertOwnedProperty(landlordId, input.propertyId);
    await this.assertOwnedRoom(landlordId, input.roomId, input.propertyId);

    const ticket = await this.prisma.maintenanceTicket.create({
      data: {
        landlordId,
        propertyId: input.propertyId,
        roomId: input.roomId,
        priority: input.priority ? this.priority(input.priority) : undefined,
        title: input.title.trim(),
        description: input.description?.trim(),
        reportedAt: input.reportedAt ? this.parseDate(input.reportedAt) : undefined,
        estimatedCost: input.estimatedCost,
        assigneeStaffProfileId: input.assigneeStaffProfileId
          ? await this.assertStaff(landlordId, input.assigneeStaffProfileId, input.propertyId)
          : undefined,
        dueAt: input.dueAt ? this.parseDate(input.dueAt) : undefined,
        note: input.note?.trim(),
        imageUrls: this.imageUrls(input.imageUrls),
      },
      include: this.ticketInclude,
    });
    return { data: this.serialize(ticket) };
  }

  async update(
    landlordId: string,
    id: string,
    input: UpdateMaintenanceTicketDto,
  ) {
    const existing = await this.findOwned(landlordId, id);
    const propertyId = input.propertyId ?? existing.propertyId;
    const roomId = input.roomId ?? existing.roomId;
    if (existing.expenseId && (propertyId !== existing.propertyId || roomId !== existing.roomId || (input.actualCost !== undefined && input.actualCost !== existing.actualCost))) {
      throw new ConflictException('Reconcile the linked expense before changing its room or actual cost.');
    }

    await this.assertOwnedProperty(landlordId, propertyId);
    await this.assertOwnedRoom(landlordId, roomId, propertyId);

    if (existing.assigneeStaffProfileId && input.assigneeStaffProfileId === undefined && input.propertyId !== undefined) {
      await this.assertStaff(landlordId, existing.assigneeStaffProfileId, propertyId);
    }

    const status = input.status ? this.status(input.status) : undefined;
    const ticket = await this.prisma.maintenanceTicket.update({
      where: { id: existing.id },
      data: {
        ...(input.propertyId !== undefined ? { propertyId } : {}),
        ...(input.roomId !== undefined ? { roomId } : {}),
        ...(status !== undefined ? { status } : {}),
        ...(input.priority !== undefined
          ? { priority: this.priority(input.priority) }
          : {}),
        ...(input.title !== undefined ? { title: input.title.trim() } : {}),
        ...(input.description !== undefined
          ? { description: input.description.trim() }
          : {}),
        ...(input.reportedAt !== undefined
          ? { reportedAt: this.parseDate(input.reportedAt) }
          : {}),
        ...(input.startedAt !== undefined
          ? { startedAt: this.parseDate(input.startedAt) }
          : {}),
        ...(input.completedAt !== undefined
          ? { completedAt: this.parseDate(input.completedAt) }
          : {}),
        ...(input.assigneeStaffProfileId !== undefined
          ? { assigneeStaffProfileId: input.assigneeStaffProfileId ? await this.assertStaff(landlordId, input.assigneeStaffProfileId, propertyId) : null }
          : {}),
        ...(input.dueAt !== undefined ? { dueAt: input.dueAt ? this.parseDate(input.dueAt) : null } : {}),
        ...(input.priority !== undefined && this.priority(input.priority) !== existing.priority && input.dueAt === undefined ? { dueAt: null } : {}),
        ...(input.estimatedCost !== undefined
          ? { estimatedCost: input.estimatedCost }
          : {}),
        ...(input.actualCost !== undefined ? { actualCost: input.actualCost } : {}),
        ...(input.note !== undefined ? { note: input.note.trim() } : {}),
        ...(input.imageUrls !== undefined
          ? { imageUrls: this.imageUrls(input.imageUrls) }
          : {}),
      },
      include: this.ticketInclude,
    });
    return { data: this.serialize(ticket) };
  }

  async updateStatus(
    landlordId: string,
    id: string,
    input: UpdateMaintenanceStatusDto,
  ) {
    const existing = await this.findOwned(landlordId, id);
    const status = this.status(input.status);
    const now = new Date();
    const ticket = await this.prisma.maintenanceTicket.update({
      where: { id: existing.id },
      data: {
        status,
        ...(status === MaintenanceStatus.IN_PROGRESS && !existing.startedAt
          ? { startedAt: now }
          : {}),
        ...(status === MaintenanceStatus.DONE && !existing.completedAt
          ? { completedAt: now }
          : {}),
      },
      include: this.ticketInclude,
    });
    return { data: this.serialize(ticket) };
  }

  async complete(
    landlordId: string,
    id: string,
    input: CompleteMaintenanceTicketDto,
  ) {
    const completedAt = input.completedAt ? this.parseDate(input.completedAt) : new Date();
    const ticket = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "MaintenanceTicket" WHERE id = ${id} AND "landlordId" = ${landlordId} FOR UPDATE`;
      const existing = await tx.maintenanceTicket.findFirst({ where: { id, landlordId, ...propertyIdScope() } });
      if (!existing) throw ticketNotFound();
      if (existing.status === 'CANCELLED') throw new ConflictException('Cancelled maintenance cannot be completed.');
      const actualCost = input.actualCost ?? existing.actualCost ?? 0;
      if (existing.expenseId && actualCost !== existing.actualCost) throw new ConflictException('The actual cost is already linked to an expense.');
      const shouldCreateExpense = input.createExpense === true && actualCost > 0 && !existing.expenseId;
      const expense = shouldCreateExpense
        ? await tx.expense.create({
            data: {
              landlordId,
              propertyId: existing.propertyId,
              roomId: existing.roomId,
              category: ExpenseCategory.REPAIR,
              amount: actualCost,
              expenseDate: completedAt,
              title: `Sửa chữa: ${existing.title}`,
              note: input.note?.trim() ?? existing.note ?? undefined,
            },
          })
        : null;

      return tx.maintenanceTicket.update({
        where: { id: existing.id },
        data: {
          status: MaintenanceStatus.DONE,
          completedAt: existing.completedAt ?? completedAt,
          actualCost,
          ...(input.note !== undefined ? { note: input.note.trim() } : {}),
          ...(expense ? { expenseId: expense.id } : {}),
        },
        include: this.ticketInclude,
      });
    });

    return { data: this.serialize(ticket) };
  }

  async addComment(
    landlordId: string,
    id: string,
    authorId: string,
    input: CreateMaintenanceCommentDto,
  ) {
    const ticket = await this.findOwned(landlordId, id);
    const comment = await this.prisma.maintenanceComment.create({
      data: {
        ticketId: ticket.id,
        authorId,
        authorRole: UserRole.LANDLORD,
        body: input.body.trim(),
        imageUrls: this.imageUrls(input.imageUrls),
      },
      include: this.commentInclude,
    });
    return { data: this.serializeComment(comment) };
  }

  async remove(landlordId: string, id: string): Promise<void> {
    const ticket = await this.findOwned(landlordId, id);
    await this.prisma.maintenanceTicket.delete({ where: { id: ticket.id } });
  }

  private readonly ticketInclude = {
    property: { select: { id: true, name: true } },
    room: { select: { id: true, name: true } },
    expense: { select: { id: true, amount: true, expenseDate: true, title: true } },
    assignee: { select: { id: true, fullName: true } },
    comments: {
      orderBy: { createdAt: 'asc' as const },
      include: {
        author: { select: { id: true, fullName: true, role: true } },
      },
    },
  };

  private readonly commentInclude = {
    author: { select: { id: true, fullName: true, role: true } },
  };

  private async findOwned(landlordId: string, id: string) {
    const ticket = await this.prisma.maintenanceTicket.findFirst({
      where: { id, landlordId, ...propertyIdScope() },
      include: this.ticketInclude,
    });
    if (!ticket) throw ticketNotFound();
    return ticket;
  }

  private async assertOwnedProperty(landlordId: string, propertyId: string) {
    const property = await this.prisma.property.findFirst({
      where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false },
      select: { id: true },
    });
    if (!property) throw propertyNotFound();
  }

  private async assertOwnedRoom(
    landlordId: string,
    roomId: string,
    propertyId?: string,
  ) {
    const room = await this.prisma.room.findFirst({
      where: {
        id: roomId,
        ...(propertyId ? { propertyId } : {}),
        property: { ...propertyWhere(landlordId), isArchived: false },
      },
      select: { id: true },
    });
    if (!room) throw roomNotFound();
  }

  private status(value: string) {
    const normalized = value.toUpperCase();
    if (normalized in MaintenanceStatus) {
      return MaintenanceStatus[normalized as keyof typeof MaintenanceStatus];
    }
    throw new BadRequestException({
      error: { code: 'INVALID_MAINTENANCE_STATUS', message: 'Invalid status.' },
    });
  }

  private async assertStaff(landlordId: string, staffProfileId: string, propertyId: string) {
    const staff = await this.prisma.staffProfile.findFirst({ where: { id: staffProfileId, landlordId, isActive: true, user: { isActive: true }, permissions: { hasSome: ['maintenance.manage', 'maintenance.complete'] }, propertyScopes: { some: { propertyId } } }, select: { id: true } });
    if (!staff) throw new NotFoundException({ error: { code: 'STAFF_NOT_FOUND', message: 'Active staff member not found.' } });
    return staff.id;
  }

  private priority(value: string) {
    const normalized = value.toUpperCase();
    if (normalized in MaintenancePriority) {
      return MaintenancePriority[
        normalized as keyof typeof MaintenancePriority
      ];
    }
    throw new BadRequestException({
      error: {
        code: 'INVALID_MAINTENANCE_PRIORITY',
        message: 'Invalid priority.',
      },
    });
  }

  private parseDate(value: string) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException({
        error: { code: 'INVALID_MAINTENANCE_DATE', message: 'Invalid date.' },
      });
    }
    return date;
  }

  private serialize(ticket: TicketWithRelations) {
    return {
      id: ticket.id,
      propertyId: ticket.propertyId,
      propertyName: ticket.property?.name ?? null,
      roomId: ticket.roomId,
      roomName: ticket.room?.name ?? null,
      status: ticket.status.toLowerCase(),
      priority: ticket.priority.toLowerCase(),
      title: ticket.title,
      description: ticket.description,
      reportedAt: ticket.reportedAt.toISOString(),
      startedAt: ticket.startedAt?.toISOString() ?? null,
      completedAt: ticket.completedAt?.toISOString() ?? null,
      assigneeStaffProfileId: ticket.assigneeStaffProfileId,
      assigneeName: ticket.assignee?.fullName ?? null,
      dueAt: ticket.dueAt?.toISOString() ?? null,
      escalatedAt: ticket.escalatedAt?.toISOString() ?? null,
      slaOverdue: Boolean(ticket.dueAt && ticket.dueAt < new Date() && ['OPEN', 'IN_PROGRESS'].includes(ticket.status)),
      estimatedCost: ticket.estimatedCost,
      actualCost: ticket.actualCost,
      note: ticket.note,
      imageUrls: ticket.imageUrls,
      comments: ticket.comments?.map((comment) => this.serializeComment(comment)) ?? [],
      expenseId: ticket.expenseId,
      expenseAmount: ticket.expense?.amount ?? null,
      expenseDate: ticket.expense?.expenseDate.toISOString() ?? null,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
    };
  }

  private serializeComment(comment: CommentWithAuthor) {
    return {
      id: comment.id,
      ticketId: comment.ticketId,
      authorId: comment.authorId,
      authorName: comment.author?.fullName ?? null,
      authorRole: comment.authorRole.toLowerCase(),
      body: comment.body,
      imageUrls: comment.imageUrls,
      createdAt: comment.createdAt.toISOString(),
    };
  }

  private imageUrls(values?: string[]) {
    return values
      ?.map((value) => value.trim())
      .filter((value) => value.length > 0) ?? [];
  }
}
