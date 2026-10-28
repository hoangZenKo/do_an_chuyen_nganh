import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { billingAudit } from './billing-events';
import { billingError, commandHash } from './billing-rules';
import { AuthRole } from '../common/auth-role';

@Injectable()
export class BillingCommandsService {
  constructor(private readonly prisma: PrismaService) {}

  execute<Result>(user: AuthUser, action: string, resourceId: string, input: { requestKey: string }, perform: (tx: Prisma.TransactionClient) => Promise<Result>) {
    const landlordId = landlordScopeId(user);
    const requestHash = commandHash({ action, resourceId, input, ...(user.role === AuthRole.STAFF ? { staffId: user.userId, propertyIds: [...(user.propertyIds ?? [])].sort() } : {}) });
    return this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`billing:${landlordId}:${input.requestKey}`}, 0))::text`;
      const previous = await tx.billingCommand.findUnique({ where: { landlordId_requestKey: { landlordId, requestKey: input.requestKey } } });
      if (previous) {
        if (previous.requestHash !== requestHash) billingError('IDEMPOTENCY_KEY_REUSED', 'Request key was already used for a different command.', true);
        return previous.response as Result;
      }
      const result = await perform(tx);
      const response = JSON.parse(JSON.stringify(result)) as Prisma.InputJsonValue;
      await billingAudit(tx, user, action, 'billing', resourceId, JSON.parse(JSON.stringify(input)) as Prisma.InputJsonValue);
      await tx.billingCommand.create({ data: { landlordId, requestKey: input.requestKey, requestHash, response } });
      return result;
    }, { timeout: 20000 });
  }
}
