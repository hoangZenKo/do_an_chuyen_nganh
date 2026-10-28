import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { requestContext } from '../common/request-context';

export function adminAudit(tx: Prisma.TransactionClient, actor: AuthUser, action: string, resourceType: string,
  resourceId: string, summary: string, metadata?: Prisma.InputJsonValue) {
  return tx.auditLog.create({ data: { actorId: actor.userId, actorRole: 'ADMIN', action, resourceType, resourceId, summary, metadata, requestId: requestContext.getStore()?.requestId } });
}
export function maskedEmail(value: string) {
  const domain = value.split('@')[1];
  return domain ? `${value[0]}***@${domain}` : '***';
}
export function maskedPhone(value: string | null) { return value ? `***${value.slice(-3)}` : null; }
