import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { platformAudit } from './platform-audit';
import { ModerationPolicyDto } from './moderation-policy.dto';
import { ModerationQualityQuery, qualityWindow } from './moderation-quality.dto';

@Injectable()
export class ModerationPolicyService {
  constructor(private readonly prisma: PrismaService) {}

  async list() {
    return { data: await this.prisma.moderationPolicy.findMany({ orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], take: 100 }) };
  }

  async create(actor: AuthUser, input: ModerationPolicyDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102571)::text`;
      const latest = await tx.moderationPolicy.findFirst({ where: { kind: input.kind }, orderBy: { version: 'desc' } });
      const data = await tx.moderationPolicy.create({ data: { kind: input.kind, title: input.title, body: input.body,
        version: (latest?.version ?? 0) + 1, createdById: actor.userId } });
      await platformAudit(tx, actor, 'moderation.policy_created', 'moderation_policy', data.id, input.reason, { kind: data.kind, version: data.version });
      return { data };
    });
  }

  async activate(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102571)::text`;
      const policy = await tx.moderationPolicy.findUnique({ where: { id } });
      if (!policy) throw new NotFoundException();
      if (policy.status !== 'DRAFT') throw new ConflictException('Chỉ kích hoạt policy đang ở trạng thái nháp.');
      await tx.moderationPolicy.updateMany({ where: { kind: policy.kind, status: 'ACTIVE' }, data: { status: 'RETIRED' } });
      const data = await tx.moderationPolicy.update({ where: { id }, data: { status: 'ACTIVE', activatedById: actor.userId, activatedAt: new Date() } });
      await platformAudit(tx, actor, 'moderation.policy_activated', 'moderation_policy', id, reason, { kind: data.kind, version: data.version });
      return { data };
    });
  }

  async quality(actor: AuthUser, query: ModerationQualityQuery = new ModerationQualityQuery()) {
    if (actor.role !== 'admin' || !actor.permissions?.includes('admin.moderation.reports')) throw new ForbiddenException();
    let window: ReturnType<typeof qualityWindow>;
    try { window = qualityWindow(query); } catch { throw new BadRequestException('Invalid date window or IANA timezone (maximum 93 days).'); }
    const range = { gte: window.from, lt: window.to };
    const [decisions, appeals, feedback, reviews] = await this.prisma.$transaction(async tx => Promise.all([
      tx.moderationDecision.groupBy({ by: ['actorId', 'kind'], where: { createdAt: range }, _count: true }),
      tx.moderationAppeal.groupBy({ by: ['status'], where: { resolvedAt: range }, _count: true }),
      actor.permissions?.includes('admin.support.read')
        ? tx.supportTicket.aggregate({ where: { feedbackAt: range }, _avg: { feedbackRating: true }, _count: { feedbackRating: true } })
        : Promise.resolve(null),
      tx.moderationQualityReview.groupBy({ by: ['outcome'], where: { createdAt: range }, _count: true }),
    ]));
    const upheld = appeals.find(row => row.status === 'UPHELD')?._count ?? 0;
    const reopened = appeals.find(row => row.status === 'REOPENED')?._count ?? 0;
    const assessed = reviews.reduce((total, row) => total + row._count, 0);
    const disagreed = reviews.find(row => row.outcome === 'DISAGREE')?._count ?? 0;
    return { data: { from: window.from.toISOString(), to: window.to.toISOString(), timezone: window.timezone,
      displayFrom: window.displayFrom, displayTo: window.displayTo, generatedAt: window.generatedAt,
      decisions: decisions.map(row => ({ actorId: row.actorId, kind: row.kind, total: row._count })),
      appeals: appeals.map(row => ({ status: row.status, total: row._count })),
      supportFeedback: feedback ? { responses: feedback._count.feedbackRating, average: feedback._avg.feedbackRating } : null,
      qa: { reviews: reviews.map(row => ({ outcome: row.outcome, total: row._count })), total: assessed, disagreementRate: assessed ? disagreed / assessed : null },
      appealReopenRate: upheld + reopened ? reopened / (upheld + reopened) : null,
      appealOverturnRate: null,
      definitions: { interval: '[from,to), explicit instants; timezone is presentation context', decisions: 'Decision createdAt in range',
        appeals: 'Appeal resolvedAt in range', appealReopenRate: 'REOPENED / (UPHELD + REOPENED); SUPERSEDED excluded',
        appealOverturnRate: 'Not tracked: reopening is not a final merits reversal',
        qa: 'QA review createdAt in range; DISAGREE / all QA outcomes, including NEEDS_DISCUSSION', csat: 'feedbackAt in range, visible only with support.read' },
      automaticSanctions: false } };
  }
}
