import { Prisma } from '@prisma/client';
import { AuthUser } from './current-user.decorator';
import { requestContext } from './request-context';

export async function recordModerationDecision(tx: Prisma.TransactionClient, actor: AuthUser, input: {
  kind: string; targetId: string; ownerId: string; fromStatus: string; toStatus: string; version: number; reason: string; source?: string;
}) {
  const policy = await tx.moderationPolicy.findFirst({ where: { kind: input.kind, status: 'ACTIVE' }, orderBy: { version: 'desc' }, select: { id: true } });
  let content: Prisma.InputJsonValue = {};
  if (input.kind === 'LISTING') {
    const target = await tx.roomListing.findUnique({ where: { id: input.targetId }, select: { title: true, description: true, imageUrls: true, monthlyRent: true, version: true } });
    if (target) content = target;
  } else if (input.kind === 'REPORT') {
    const target = await tx.listingReport.findUnique({ where: { id: input.targetId }, select: { reason: true, detail: true, listingId: true, version: true } });
    if (target) content = target;
  } else {
    const target = await tx.roomReview.findUnique({ where: { id: input.targetId }, select: { body: true, replyBody: true, roomId: true, version: true } });
    if (target) content = input.kind === 'REPLY' ? { body: target.replyBody ?? '', roomId: target.roomId, version: target.version } : { body: target.body, roomId: target.roomId, version: target.version };
  }
  const decision = await tx.moderationDecision.create({ data: { ...input, evidence: { schemaVersion: 1, capturedAt: new Date().toISOString(), content }, policyId: policy?.id,
    source: input.source ?? requestContext.getStore()?.moderationSource ?? 'REVIEW', actorId: actor.userId, requestId: requestContext.getStore()?.requestId } });
  await tx.moderationWorkItem.deleteMany({ where: { kind: input.kind, targetId: input.targetId } });
  await tx.platformNotification.create({ data: { userId: input.ownerId, eventKey: `moderation:${decision.id}`, kind: 'MODERATION_DECISION',
    title: 'Có kết quả kiểm duyệt mới', body: `Trạng thái: ${input.toStatus}. Mở trung tâm để xem quyết định.`,
    actionPath: '/support-center?tab=appeals' } });
  return decision;
}
