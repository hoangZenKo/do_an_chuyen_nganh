import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { OperationFrequency, Prisma } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { CheckTaskDto, CreateRecurringDto, OperationsQuery, TaskQuery } from './p1.dto';

export function nextOccurrence(date: Date, frequency: OperationFrequency, interval: number, anchorDay: number) {
  const offset = 7 * 3600000;
  const next = new Date(date.getTime() + offset);
  if (frequency === 'DAILY' || frequency === 'WEEKLY') next.setUTCDate(next.getUTCDate() + interval * (frequency === 'WEEKLY' ? 7 : 1));
  else {
    next.setUTCDate(1);
    next.setUTCMonth(next.getUTCMonth() + interval * (frequency === 'QUARTERLY' ? 3 : 1));
    const last = new Date(Date.UTC(next.getUTCFullYear(), next.getUTCMonth() + 1, 0)).getUTCDate();
    next.setUTCDate(Math.min(anchorDay, last));
  }
  return new Date(next.getTime() - offset);
}

const scopeInclude = { property: { select: { id: true, name: true } }, room: { select: { id: true, name: true } } };
type ChecklistItem = { title: string; done: boolean };

@Injectable()
export class RecurringService {
  constructor(private readonly prisma: PrismaService) {}

  async create(user: AuthUser, input: CreateRecurringDto) {
    const landlordId = landlordScopeId(user);
    if (!await this.prisma.property.findFirst({ where: { id: input.propertyId, landlordId, isArchived: false } })) throw new NotFoundException('Không tìm thấy khu trọ.');
    if (input.roomId && !await this.prisma.room.findFirst({ where: { id: input.roomId, propertyId: input.propertyId, isActive: true } })) throw new NotFoundException('Phòng không thuộc khu trọ.');
    const nextRunAt = new Date(input.nextRunAt);
    if (nextRunAt.getTime() < Date.now() - 86400000) throw new BadRequestException('Ngày bắt đầu không được lùi quá một ngày.');
    const data = await this.prisma.recurringOperation.create({ data: {
      landlordId, propertyId: input.propertyId, roomId: input.roomId, title: input.title.trim(), kind: input.kind, frequency: input.frequency,
      interval: input.interval, anchorDay: new Date(nextRunAt.getTime() + 7 * 3600000).getUTCDate(), nextRunAt, checklist: input.checklist.map(value => value.trim()),
    }, include: scopeInclude });
    await this.generateDue(new Date(), data.id);
    return { data };
  }

  async templates(user: AuthUser, query: OperationsQuery) {
    const where = { landlordId: landlordScopeId(user), ...(query.propertyId ? { propertyId: query.propertyId } : {}) };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.recurringOperation.findMany({ where, include: scopeInclude, orderBy: { createdAt: 'desc' }, skip: (query.page - 1) * query.limit, take: query.limit }),
      this.prisma.recurringOperation.count({ where }),
    ]);
    return { data, total, page: query.page, limit: query.limit };
  }

  async toggle(user: AuthUser, id: string, isEnabled: boolean) {
    const result = await this.prisma.recurringOperation.updateMany({ where: { id, landlordId: landlordScopeId(user) }, data: { isEnabled } });
    if (!result.count) throw new NotFoundException('Không tìm thấy lịch định kỳ.');
    return { data: { id, isEnabled } };
  }

  async tasks(user: AuthUser, query: TaskQuery) {
    const where = { landlordId: landlordScopeId(user), ...(query.propertyId ? { propertyId: query.propertyId } : {}), ...(query.status ? { status: query.status } : {}) };
    const [data, total] = await this.prisma.$transaction([
      this.prisma.operationTask.findMany({ where, include: scopeInclude, orderBy: [{ status: 'asc' }, { dueAt: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
      this.prisma.operationTask.count({ where }),
    ]);
    return { data, total, page: query.page, limit: query.limit };
  }

  async check(user: AuthUser, id: string, input: CheckTaskDto) {
    const task = await this.prisma.operationTask.findFirst({ where: { id, landlordId: landlordScopeId(user) } });
    if (!task) throw new NotFoundException('Không tìm thấy công việc.');
    const checklist = task.checklist as ChecklistItem[];
    if (!checklist[input.index]) throw new BadRequestException('Mục kiểm tra không hợp lệ.');
    checklist[input.index] = { ...checklist[input.index], done: input.done };
    const completed = checklist.every(item => item.done);
    const updated = await this.prisma.operationTask.updateMany({ where: { id, landlordId: landlordScopeId(user), version: input.version }, data: {
      checklist, version: { increment: 1 }, status: completed ? 'COMPLETED' : 'PENDING', completedAt: completed ? new Date() : null, completedBy: completed ? user.userId : null,
    } });
    if (!updated.count) throw new ConflictException('Công việc đã thay đổi. Hãy tải lại.');
    return { data: await this.prisma.operationTask.findUniqueOrThrow({ where: { id }, include: scopeInclude }) };
  }

  async generateDue(now = new Date(), templateId?: string) {
    return this.prisma.$transaction(async tx => {
      const ids = await tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        SELECT recurring.id FROM "RecurringOperation" recurring
        JOIN "Property" property ON property.id = recurring."propertyId"
        JOIN "User" landlord ON landlord.id = recurring."landlordId"
        WHERE recurring."isEnabled" = true AND recurring."nextRunAt" <= ${now}
          AND property."isArchived" = false AND landlord."isActive" = true
          AND (recurring."roomId" IS NULL OR EXISTS (SELECT 1 FROM "Room" room WHERE room.id = recurring."roomId" AND room."isActive" = true))
          ${templateId ? Prisma.sql`AND recurring.id = ${templateId}` : Prisma.empty}
        ORDER BY recurring."nextRunAt" LIMIT 100 FOR UPDATE OF recurring SKIP LOCKED`);
      let created = 0;
      for (const { id } of ids) {
        const template = await tx.recurringOperation.findUniqueOrThrow({ where: { id } });
        let dueAt = template.nextRunAt;
        for (let occurrence = 0; dueAt <= now && occurrence < 32; occurrence++) {
          const result = await tx.operationTask.createMany({ data: [{ landlordId: template.landlordId, propertyId: template.propertyId, roomId: template.roomId,
            recurringId: id, title: template.title, kind: template.kind, dueAt, checklist: template.checklist.map(title => ({ title, done: false })) }], skipDuplicates: true });
          created += result.count;
          dueAt = nextOccurrence(dueAt, template.frequency, template.interval, template.anchorDay);
        }
        await tx.recurringOperation.update({ where: { id }, data: { nextRunAt: dueAt } });
      }
      return { created };
    }, { timeout: 30000 });
  }
}
