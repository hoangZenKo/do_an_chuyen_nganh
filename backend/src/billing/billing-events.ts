import { Prisma } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { requestContext } from '../common/request-context';

export async function billingEvent(tx: Prisma.TransactionClient, landlordId: string, type: string, resourceId: string, eventKey: string, payload: Prisma.InputJsonValue) {
  return tx.billingOutboxEvent.create({ data: { landlordId, type, resourceId, eventKey, payload } });
}

export async function billingAudit(tx: Prisma.TransactionClient, user: AuthUser, action: string, resourceType: string, resourceId: string, metadata: Prisma.InputJsonValue) {
  await tx.auditLog.create({ data: {
    landlordId: landlordScopeId(user), actorId: user.userId,
    actorRole: user.role === 'staff' ? 'STAFF' : user.role === 'admin' ? 'ADMIN' : 'LANDLORD',
    action, resourceType, resourceId, summary: action, metadata,
    requestId: requestContext.getStore()?.requestId,
  } });
}
