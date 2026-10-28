import { ForbiddenException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from './current-user.decorator';

export async function assertModerationAssignment(tx: Prisma.TransactionClient, actor: AuthUser, kind: string, targetId: string) {
  await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${`${kind}:${targetId}`}))::text`;
  const work = await tx.moderationWorkItem.findUnique({ where: { kind_targetId: { kind, targetId } } });
  if (work?.assigneeId && work.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) {
    throw new ForbiddenException('Nội dung đang được admin khác xử lý.');
  }
}
