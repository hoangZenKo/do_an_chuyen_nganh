import { Prisma, UserRole } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { requestContext } from '../common/request-context';

export function platformAudit(tx: Prisma.TransactionClient, actor: AuthUser, action: string, resourceType: string,
  resourceId: string, summary: string, metadata?: Prisma.InputJsonValue) {
  return tx.auditLog.create({ data: { actorId: actor.userId, actorRole: actor.role.toUpperCase() as UserRole,
    action, resourceType, resourceId, summary, metadata, requestId: requestContext.getStore()?.requestId } });
}
