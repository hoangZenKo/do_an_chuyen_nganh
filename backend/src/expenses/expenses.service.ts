import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Expense, ExpenseCategory } from '@prisma/client';

import { propertyWhere, propertyIdScope } from '../common/property-scope';
import { PrismaService } from '../prisma/prisma.service';
import { CreateExpenseDto } from './dto/create-expense.dto';
import { ListExpensesQueryDto } from './dto/list-expenses-query.dto';
import { UpdateExpenseDto } from './dto/update-expense.dto';

type ExpenseWithRelations = Expense & {
  property?: { id: string; name: string } | null;
  room?: { id: string; name: string } | null;
};

const expenseNotFound = () =>
  new NotFoundException({
    error: { code: 'EXPENSE_NOT_FOUND', message: 'Expense not found.' },
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
export class ExpensesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(landlordId: string, query: ListExpensesQueryDto = {}) {
    if (query.propertyId) {
      await this.assertOwnedProperty(landlordId, query.propertyId);
    }
    if (query.roomId) {
      await this.assertOwnedRoom(landlordId, query.roomId, query.propertyId);
    }
    const month = query.month ? this.monthRange(query.month) : null;
    const expenses = await this.prisma.expense.findMany({
      where: {
        landlordId,
        ...propertyIdScope(),
        ...(query.propertyId ? { propertyId: query.propertyId } : {}),
        ...(query.roomId ? { roomId: query.roomId } : {}),
        ...(query.category ? { category: this.category(query.category) } : {}),
        ...(month
          ? {
              expenseDate: {
                gte: month.start,
                lt: month.end,
              },
            }
          : {}),
      },
      orderBy: [{ expenseDate: 'desc' }, { createdAt: 'desc' }],
      include: this.expenseInclude,
    });

    const totalAmount = expenses.reduce((sum, expense) => sum + expense.amount, 0);
    return {
      data: expenses.map((expense) => this.serialize(expense)),
      summary: {
        totalAmount,
        count: expenses.length,
      },
    };
  }

  async getById(landlordId: string, id: string) {
    const expense = await this.findOwned(landlordId, id);
    return { data: this.serialize(expense) };
  }

  async create(landlordId: string, input: CreateExpenseDto) {
    await this.assertOwnedProperty(landlordId, input.propertyId);
    if (input.roomId) {
      await this.assertOwnedRoom(landlordId, input.roomId, input.propertyId);
    }
    const expense = await this.prisma.expense.create({
      data: {
        landlordId,
        propertyId: input.propertyId,
        roomId: input.roomId,
        category: this.category(input.category),
        amount: input.amount,
        expenseDate: this.parseDate(input.expenseDate),
        title: input.title.trim(),
        note: input.note?.trim(),
        receiptUrl: input.receiptUrl?.trim(),
      },
      include: this.expenseInclude,
    });
    return { data: this.serialize(expense) };
  }

  async update(landlordId: string, id: string, input: UpdateExpenseDto) {
    const existing = await this.findOwned(landlordId, id);
    const propertyId = input.propertyId ?? existing.propertyId;
    await this.assertOwnedProperty(landlordId, propertyId);
    if (input.roomId) {
      await this.assertOwnedRoom(landlordId, input.roomId, propertyId);
    }

    const expense = await this.prisma.expense.update({
      where: { id: existing.id },
      data: {
        ...(input.propertyId !== undefined ? { propertyId } : {}),
        ...(input.roomId !== undefined ? { roomId: input.roomId } : {}),
        ...(input.category !== undefined
          ? { category: this.category(input.category) }
          : {}),
        ...(input.amount !== undefined ? { amount: input.amount } : {}),
        ...(input.expenseDate !== undefined
          ? { expenseDate: this.parseDate(input.expenseDate) }
          : {}),
        ...(input.title !== undefined ? { title: input.title.trim() } : {}),
        ...(input.note !== undefined ? { note: input.note.trim() } : {}),
        ...(input.receiptUrl !== undefined
          ? { receiptUrl: input.receiptUrl.trim() }
          : {}),
      },
      include: this.expenseInclude,
    });
    return { data: this.serialize(expense) };
  }

  async remove(landlordId: string, id: string): Promise<void> {
    const expense = await this.findOwned(landlordId, id);
    await this.prisma.expense.delete({ where: { id: expense.id } });
  }

  private readonly expenseInclude = {
    property: { select: { id: true, name: true } },
    room: { select: { id: true, name: true } },
  };

  private async findOwned(landlordId: string, id: string) {
    const expense = await this.prisma.expense.findFirst({
      where: { id, landlordId, ...propertyIdScope() },
      include: this.expenseInclude,
    });
    if (!expense) throw expenseNotFound();
    return expense;
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

  private category(value: string) {
    const normalized = value.toUpperCase();
    if (normalized in ExpenseCategory) {
      return ExpenseCategory[normalized as keyof typeof ExpenseCategory];
    }
    throw new BadRequestException({
      error: { code: 'INVALID_EXPENSE_CATEGORY', message: 'Invalid category.' },
    });
  }

  private parseDate(value: string) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException({
        error: { code: 'INVALID_EXPENSE_DATE', message: 'Invalid expense date.' },
      });
    }
    return date;
  }

  private monthRange(value: string) {
    const start = new Date(value);
    if (Number.isNaN(start.getTime())) {
      throw new BadRequestException({
        error: { code: 'INVALID_EXPENSE_MONTH', message: 'Invalid month.' },
      });
    }
    const normalizedStart = new Date(
      Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), 1),
    );
    const end = new Date(
      Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 1),
    );
    return { start: normalizedStart, end };
  }

  private serialize(expense: ExpenseWithRelations) {
    return {
      id: expense.id,
      propertyId: expense.propertyId,
      propertyName: expense.property?.name ?? null,
      roomId: expense.roomId,
      roomName: expense.room?.name ?? null,
      category: expense.category.toLowerCase(),
      amount: expense.amount,
      expenseDate: expense.expenseDate.toISOString(),
      title: expense.title,
      note: expense.note,
      receiptUrl: expense.receiptUrl,
      createdAt: expense.createdAt.toISOString(),
      updatedAt: expense.updatedAt.toISOString(),
    };
  }
}
