import { Injectable, Logger } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';

import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { ListAuditLogsQueryDto } from './dto/list-audit-logs-query.dto';
import { requestContext } from '../common/request-context';

export interface AuditRecordInput {
  landlordId?: string | null;
  actor: AuthUser;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  summary: string;
  metadata?: Prisma.InputJsonValue;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async list(landlordId: string, query: ListAuditLogsQueryDto) {
    const take = this.resolveTake(query.take);
    const logs = await this.prisma.auditLog.findMany({
      where: {
        landlordId,
        ...(query.action ? { action: query.action } : {}),
        ...(query.resourceType ? { resourceType: query.resourceType } : {}),
        ...(query.actorId ? { actorId: query.actorId } : {}),
      },
      include: {
        actor: {
          select: {
            id: true,
            fullName: true,
            email: true,
            role: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });

    return {
      data: logs.map((log) => ({
        id: log.id,
        landlordId: log.landlordId,
        actorId: log.actorId,
        actorRole: log.actorRole,
        actor: log.actor
          ? {
              id: log.actor.id,
              fullName: log.actor.fullName,
              email: log.actor.email,
              role: log.actor.role,
            }
          : null,
        action: log.action,
        resourceType: log.resourceType,
        resourceId: log.resourceId,
        summary: log.summary,
        metadata: log.metadata,
        createdAt: log.createdAt.toISOString(),
      })),
    };
  }

  async record(input: AuditRecordInput) {
    await this.prisma.auditLog.create({
      data: {
        landlordId: input.landlordId ?? null,
        actorId: input.actor.userId,
        actorRole: this.toUserRole(input.actor.role),
        action: input.action,
        resourceType: input.resourceType,
        resourceId: input.resourceId ?? null,
        summary: input.summary,
        metadata: input.metadata,
        requestId: requestContext.getStore()?.requestId,
      },
    });
  }

  async recordSafe(input: AuditRecordInput) {
    try {
      await this.record(input);
    } catch (error) {
      this.logger.warn(
        `Failed to record audit log ${input.action}:${input.resourceType}`,
      );
    }
  }

  private resolveTake(raw?: string) {
    const value = Number.parseInt(raw ?? '', 10);
    if (!Number.isFinite(value) || value <= 0) return 50;
    return Math.min(value, 200);
  }

  private toUserRole(role: AuthRole): UserRole {
    switch (role) {
      case AuthRole.ADMIN:
        return UserRole.ADMIN;
      case AuthRole.TENANT:
        return UserRole.TENANT;
      case AuthRole.STAFF:
        return UserRole.STAFF;
      case AuthRole.LANDLORD:
      default:
        return UserRole.LANDLORD;
    }
  }
}
