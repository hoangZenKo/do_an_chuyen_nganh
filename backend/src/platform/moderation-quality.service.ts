import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { adminPermissionForWork } from '../common/admin-permissions';
import { adminAudit } from '../admin/admin-audit';
import { ModerationQualityReviewDto, ModerationSampleQuery, qualityWindow } from './moderation-quality.dto';

const kinds = ['LISTING', 'REPORT', 'REVIEW', 'REPLY'];

@Injectable()
export class ModerationQualityService {
  constructor(private readonly prisma: PrismaService) {}

  private permission(actor: AuthUser, kind?: string) {
    if (actor.role !== 'admin' || !actor.permissions?.includes('admin.moderation.reports') ||
        kind && (!kinds.includes(kind) || !actor.permissions.includes(adminPermissionForWork(kind)))) throw new ForbiddenException();
  }

  async samples(actor: AuthUser, query: ModerationSampleQuery) {
    this.permission(actor, query.kind);
    let window: ReturnType<typeof qualityWindow>;
    try { window = qualityWindow(query); } catch { throw new BadRequestException('Use a valid timezone and an explicit date range of at most 93 days, ending no later than now.'); }
    const allowed = kinds.filter(kind => actor.permissions?.includes(adminPermissionForWork(kind)) && (!query.kind || kind === query.kind));
    if (!allowed.length) return { data: [], meta: { ...window, hasMore: false, page: query.page, limit: query.limit } };
    const state = query.state === 'REVIEWED' ? Prisma.sql`AND r."decisionId" IS NOT NULL`
      : query.state === 'PENDING' ? Prisma.sql`AND r."decisionId" IS NULL` : Prisma.empty;
    const seed = `${window.from.toISOString()}:${window.to.toISOString()}`;
    const rows = await this.prisma.$queryRaw<Array<{
      id: string; kind: string; targetId: string; actorId: string; fromStatus: string; toStatus: string; version: number;
      createdAt: Date; outcome: string | null; reviewerId: string | null; reviewedAt: Date | null;
    }>>`SELECT d.id, d.kind, d."targetId", d."actorId", d."fromStatus", d."toStatus", d.version, d."createdAt",
       r.outcome, r."reviewerId", r."createdAt" AS "reviewedAt"
       FROM "ModerationDecision" d LEFT JOIN "ModerationQualityReview" r ON r."decisionId" = d.id
       WHERE d.kind IN (${Prisma.join(allowed)}) AND d."actorId" <> ${actor.userId}
       AND d."createdAt" >= ${window.from} AND d."createdAt" < ${window.to} ${state}
       ORDER BY md5(d.id || ${seed}), d.id LIMIT ${query.limit + 1} OFFSET ${(query.page - 1) * query.limit}`;
    return { data: rows.slice(0, query.limit), meta: { ...window, page: query.page, limit: query.limit,
      hasMore: rows.length > query.limit, sampling: 'deterministic-hash-order', independentReviewer: true, automaticSanctions: false } };
  }

  async detail(actor: AuthUser, id: string) {
    this.permission(actor);
    const allowed = kinds.filter(kind => actor.permissions?.includes(adminPermissionForWork(kind)));
    if (!allowed.length) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      const decision = await tx.moderationDecision.findFirst({ where: { id, kind: { in: allowed }, actorId: { not: actor.userId } }, select: {
        id: true, kind: true, actorId: true, targetId: true, fromStatus: true, toStatus: true, version: true,
        createdAt: true, reason: true, evidence: true, policy: { select: { id: true, version: true, title: true } },
        qualityReview: { select: { outcome: true, reason: true, reviewerId: true, createdAt: true } },
      } });
      if (!decision) throw new NotFoundException();
      this.permission(actor, decision.kind);
      if (decision.actorId === actor.userId) throw new ForbiddenException('An independent reviewer is required.');
      await adminAudit(tx, actor, 'admin.moderation_quality_evidence_accessed', 'moderation_decision', id, 'Independent QA evidence review', { kind: decision.kind, readOnly: true });
      return { data: decision, meta: { readOnly: true, enforcementUnchanged: true } };
    });
  }

  async review(actor: AuthUser, id: string, input: ModerationQualityReviewDto) {
    this.permission(actor);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "ModerationDecision" WHERE id = ${id} FOR UPDATE`;
      const decision = await tx.moderationDecision.findUnique({ where: { id }, select: { id: true, kind: true, actorId: true, version: true, qualityReview: true } });
      if (!decision) throw new NotFoundException();
      this.permission(actor, decision.kind);
      if (decision.actorId === actor.userId) throw new ForbiddenException('An independent reviewer is required.');
      if (decision.version !== input.version || decision.qualityReview) throw new ConflictException('Decision changed or QA review already completed.');
      const data = await tx.moderationQualityReview.create({ data: { decisionId: id, reviewerId: actor.userId, outcome: input.outcome, reason: input.reason } });
      await adminAudit(tx, actor, 'admin.moderation_quality_reviewed', 'moderation_decision', id, input.reason,
        { before: { reviewed: false, decisionVersion: decision.version }, after: { reviewed: true, outcome: data.outcome, reviewerId: actor.userId }, enforcementUnchanged: true });
      return { data, meta: { enforcementUnchanged: true, automaticSanctions: false } };
    });
  }
}
