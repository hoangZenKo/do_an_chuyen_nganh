import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class PlatformNotificationService {
  constructor(private readonly prisma: PrismaService) {}

  async preferences(userId: string) {
    return { data: await this.prisma.platformNotificationPreference.findUnique({ where: { userId } }) ?? { userId, email: false, push: false } };
  }

  async updatePreferences(userId: string, input: { email: boolean; push: boolean }) {
    return { data: await this.prisma.platformNotificationPreference.upsert({ where: { userId }, create: { userId, ...input }, update: input }) };
  }

  create(tx: Prisma.TransactionClient, input: {
    userId: string; eventKey: string; kind: string; title: string; body: string; actionPath: string;
  }) {
    return tx.platformNotification.upsert({ where: { userId_eventKey: { userId: input.userId, eventKey: input.eventKey } },
      create: input, update: {} });
  }

  async list(userId: string, unreadOnly = false) {
    const rows = await this.prisma.platformNotification.findMany({ where: { userId, ...(unreadOnly ? { readAt: null } : {}) }, orderBy: { createdAt: 'desc' }, take: 100 });
    const unread = await this.prisma.platformNotification.count({ where: { userId, readAt: null } });
    return { data: rows, summary: { total: rows.length, unread, limit: 100 } };
  }

  async markRead(userId: string, id: string) {
    const changed = await this.prisma.platformNotification.updateMany({ where: { id, userId }, data: { readAt: new Date() } });
    if (!changed.count) throw new NotFoundException();
    return { data: { id, read: true } };
  }

  async markAllRead(userId: string) {
    const result = await this.prisma.platformNotification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } });
    return { data: { marked: result.count } };
  }
}
