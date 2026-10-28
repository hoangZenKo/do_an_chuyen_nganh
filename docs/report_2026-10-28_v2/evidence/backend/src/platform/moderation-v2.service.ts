import { BadRequestException, ConflictException, ForbiddenException, HttpException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';
import { adminPermissionForWork } from '../common/admin-permissions';
import { recordModerationDecision } from '../common/moderation-decision';
import { pendingModerationSql } from '../common/moderation-queue.sql';
import { requestContext } from '../common/request-context';
import { randomUUID } from 'node:crypto';
import { ListingsService } from '../listings/listings.service';
import { ReviewsService } from '../reviews/reviews.service';
import { FeatureFlagsService } from './feature-flags.service';
import { platformAudit } from './platform-audit';
import { AppealAssignDto, AppealCreateDto, AppealQueryDto, AppealResolveDto, ModerationBulkDto } from './moderation-v2.dto';

export const moderationKinds = (actor: AuthUser) => ['LISTING', 'REPORT', 'REVIEW', 'REPLY'].filter(kind => actor.permissions?.includes(adminPermissionForWork(kind)));

@Injectable()
export class ModerationV2Service {
  constructor(private readonly prisma: PrismaService, private readonly flags: FeatureFlagsService,
    private readonly listings: ListingsService, private readonly reviews: ReviewsService) {}

  private permission(actor: AuthUser, kind: string) {
    if (actor.role !== AuthRole.ADMIN || !moderationKinds(actor).includes(kind)) throw new ForbiddenException();
  }
  async decisions(actor: AuthUser, query: AppealQueryDto, admin = false) {
    const where: Prisma.ModerationDecisionWhereInput = admin ? { kind: { in: moderationKinds(actor) } } : { ownerId: actor.userId };
    const [total, rows] = await this.prisma.$transaction([
      this.prisma.moderationDecision.count({ where }),
      this.prisma.moderationDecision.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (query.page - 1) * query.limit, take: query.limit,
        select: { id: true, kind: true, targetId: true, fromStatus: true, toStatus: true, version: true, reason: true, source: true, createdAt: true,
          ...(admin ? { actorId: true, requestId: true } : {}) } }),
    ]);
    return { data: rows, meta: { page: query.page, limit: query.limit, total } };
  }
  async history(actor: AuthUser, kind: string, targetId: string) {
    this.permission(actor, kind);
    return { data: await this.prisma.moderationDecision.findMany({ where: { kind, targetId }, include: { policy: { select: { id: true, title: true, version: true, status: true } } }, orderBy: { version: 'desc' }, take: 100 }) };
  }
  async appeal(actor: AuthUser, input: AppealCreateDto) {
    await this.flags.require('moderation.appeals', actor);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${`appeal:${input.decisionId}:${actor.userId}`}))::text`;
      const decision = await tx.moderationDecision.findFirst({ where: { id: input.decisionId, ownerId: actor.userId } });
      if (!decision) throw new NotFoundException();
      if (!['REJECTED', 'HIDDEN', 'DISMISSED'].includes(decision.toStatus) || Date.now() - decision.createdAt.getTime() > 14 * 86400000) throw new ConflictException('Chỉ khiếu nại quyết định bất lợi trong 14 ngày.');
      const later = await tx.moderationDecision.findFirst({ where: { kind: decision.kind, targetId: decision.targetId, version: { gt: decision.version } } });
      if (later || await tx.moderationAppeal.findUnique({ where: { decisionId_requesterId: { decisionId: decision.id, requesterId: actor.userId } } })) throw new ConflictException('Quyết định đã có khiếu nại hoặc được thay thế.');
      const data = await tx.moderationAppeal.create({ data: { decisionId: decision.id, requesterId: actor.userId, reason: input.reason, dueAt: new Date(Date.now() + 72 * 3600000) } });
      await platformAudit(tx, actor, 'moderation.appeal_created', 'moderation_appeal', data.id, 'Requested independent moderation review', { decisionId: decision.id });
      const reviewers = await tx.user.findMany({ where: { role: 'ADMIN', isActive: true, id: { not: decision.actorId },
        adminProfile: { permissions: { hasEvery: ['admin.moderation.appeals', adminPermissionForWork(decision.kind), 'admin.notifications.view'] } } }, select: { id: true }, take: 100 });
      await tx.platformNotification.createMany({ data: reviewers.map(user => ({ userId: user.id, eventKey: `appeal:${data.id}`, kind: 'MODERATION_APPEAL', title: 'Có khiếu nại kiểm duyệt mới', body: 'Cần người đánh giá độc lập.', actionPath: '/admin/moderation-v2' })), skipDuplicates: true });
      return { data };
    });
  }
  async appeals(actor: AuthUser, query: AppealQueryDto, admin = false) {
    const where: Prisma.ModerationAppealWhereInput = { ...(admin ? { decision: { kind: { in: moderationKinds(actor) } } } : { requesterId: actor.userId }),
      ...(query.appealStatus ? { status: query.appealStatus } : {}),
      ...(admin && query.assignment === 'mine' ? { assigneeId: actor.userId } : {}),
      ...(admin && query.assignment === 'unassigned' ? { assigneeId: null } : {}),
      ...(query.assignment === 'overdue' ? { status: 'OPEN', dueAt: { lt: new Date() } } : {}) };
    const [total, data] = await this.prisma.$transaction([
      this.prisma.moderationAppeal.count({ where }),
      this.prisma.moderationAppeal.findMany({ where, include: { decision: { select: { id: true, kind: true, targetId: true,
        fromStatus: true, toStatus: true, reason: true, version: true, createdAt: true, ...(admin ? { actorId: true } : {}) } } },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
    ]);
    return { data, meta: { page: query.page, limit: query.limit, total } };
  }
  async assign(actor: AuthUser, id: string, input: AppealAssignDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "ModerationAppeal" WHERE id = ${id} FOR UPDATE`;
      const appeal = await tx.moderationAppeal.findUnique({ where: { id }, include: { decision: true } });
      if (!appeal) throw new NotFoundException();
      this.permission(actor, appeal.decision.kind);
      if (appeal.status !== 'OPEN' || appeal.version !== input.version) throw new ConflictException('Khiếu nại đã thay đổi.');
      if (!actor.permissions?.includes('admin.admins.manage') && (appeal.assigneeId && appeal.assigneeId !== actor.userId || input.assigneeId !== actor.userId)) throw new ForbiddenException('Chỉ được nhận khiếu nại cho chính mình.');
      if (input.assigneeId === appeal.decision.actorId) throw new ForbiddenException('Người quyết định gốc không tự xét khiếu nại.');
      if (input.assigneeId && !await tx.user.findFirst({ where: { id: input.assigneeId, role: 'ADMIN', isActive: true,
        adminProfile: { permissions: { hasEvery: ['admin.moderation.appeals', adminPermissionForWork(appeal.decision.kind)] } } } })) throw new ConflictException('Người nhận phải có quyền xét khiếu nại.');
      const data = await tx.moderationAppeal.update({ where: { id }, data: { assigneeId: input.assigneeId ?? null, version: { increment: 1 } } });
      await platformAudit(tx, actor, 'admin.appeal_assignment', 'moderation_appeal', id, input.reason, { assigneeId: input.assigneeId ?? null });
      return { data };
    });
  }
  async resolve(actor: AuthUser, id: string, input: AppealResolveDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "ModerationAppeal" WHERE id = ${id} FOR UPDATE`;
      const appeal = await tx.moderationAppeal.findUnique({ where: { id }, include: { decision: true } });
      if (!appeal) throw new NotFoundException();
      const decision = appeal.decision;
      this.permission(actor, decision.kind);
      if (actor.userId === decision.actorId || appeal.assigneeId && appeal.assigneeId !== actor.userId) throw new ForbiddenException('Cần admin độc lập được giao xử lý.');
      if (appeal.status !== 'OPEN' || appeal.version !== input.version) throw new ConflictException('Khiếu nại đã thay đổi.');
      if (input.outcome === 'REOPENED') {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${`${decision.kind}:${decision.targetId}`}))::text`;
        let changed = 0;
        if (decision.kind === 'LISTING') {
          changed = (await tx.roomListing.updateMany({ where: { id: decision.targetId, version: decision.version, status: { in: ['HIDDEN', 'REJECTED'] } },
            data: { status: 'PENDING', reviewNote: null, publishedAt: null, version: { increment: 1 } } })).count;
        } else if (decision.kind === 'REPORT') {
          changed = (await tx.listingReport.updateMany({ where: { id: decision.targetId, version: decision.version, status: 'DISMISSED' },
            data: { status: 'OPEN', reviewNote: null, reviewedAt: null, version: { increment: 1 } } })).count;
        } else {
          changed = (await tx.roomReview.updateMany({ where: { id: decision.targetId, version: decision.version, withdrawnAt: null,
            ...(decision.kind === 'REPLY' ? { replyStatus: { in: ['HIDDEN', 'REJECTED'] }, status: 'APPROVED' } : { status: { in: ['HIDDEN', 'REJECTED'] } }) },
            data: { ...(decision.kind === 'REPLY' ? { replyStatus: 'PENDING', replyModerationNote: null } : { status: 'PENDING', moderationNote: null }), version: { increment: 1 } } })).count;
        }
        if (!changed) throw new ConflictException('Nội dung đã đổi hoặc đã được gỡ. Không ghi đè nội dung mới.');
        await recordModerationDecision(tx, actor, { kind: decision.kind, targetId: decision.targetId, ownerId: decision.ownerId,
          fromStatus: decision.toStatus, toStatus: decision.kind === 'REPORT' ? 'OPEN' : 'PENDING', version: decision.version + 1, reason: input.reason, source: 'APPEAL' });
      }
      const data = await tx.moderationAppeal.update({ where: { id }, data: { status: input.outcome, resolution: input.reason,
        resolvedById: actor.userId, resolvedAt: new Date(), version: { increment: 1 } } });
      await tx.platformNotification.create({ data: { userId: appeal.requesterId, eventKey: `appeal-resolved:${id}`, kind: 'APPEAL_RESOLVED',
        title: 'Khiếu nại đã có kết quả', body: input.outcome, actionPath: '/support-center?tab=appeals' } });
      await platformAudit(tx, actor, 'admin.appeal_resolved', 'moderation_appeal', id, input.reason, { outcome: input.outcome, decisionId: decision.id });
      return { data };
    });
  }
  async bulk(actor: AuthUser, input: ModerationBulkDto) {
    await this.flags.require('moderation.bulk', actor);
    if (new Set(input.items.map(item => `${item.kind}:${item.id}`)).size !== input.items.length) throw new BadRequestException('Không lặp cùng đối tượng trong một batch.');
    const results = [];
    for (const item of input.items) {
      try {
        this.permission(actor, item.kind);
        const context = requestContext.getStore();
        await requestContext.run({ requestId: context?.requestId ?? randomUUID(), moderationSource: 'BULK' }, async () => {
          if (item.kind === 'LISTING' && ['PUBLISH', 'REJECT', 'HIDE'].includes(item.decision)) await this.listings.review(actor, item.id, { version: item.version, decision: item.decision as 'PUBLISH' | 'REJECT' | 'HIDE', note: input.reason });
          else if (item.kind === 'REPORT' && ['RESOLVED', 'DISMISSED'].includes(item.decision)) await this.listings.reviewReport(actor, item.id, { version: item.version, status: item.decision, note: input.reason });
          else if (['REVIEW', 'REPLY'].includes(item.kind) && ['APPROVED', 'REJECTED', 'HIDDEN'].includes(item.decision)) await this.reviews.moderate(actor, item.id, { version: item.version, status: item.decision as 'APPROVED' | 'REJECTED' | 'HIDDEN', note: input.reason }, item.kind === 'REPLY');
          else throw new BadRequestException('Quyết định không khớp loại nội dung.');
        });
        results.push({ kind: item.kind, id: item.id, success: true });
      } catch (error) {
        results.push({ kind: item.kind, id: item.id, success: false, status: error instanceof HttpException ? error.getStatus() : 500, message: error instanceof HttpException ? error.message : 'Không xử lý được mục này. Tải lại trước khi thử lại.' });
      }
    }
    return { data: results, summary: { succeeded: results.filter(row => row.success).length, failed: results.filter(row => !row.success).length } };
  }
  async preview(actor: AuthUser, input: ModerationBulkDto) {
    await this.flags.require('moderation.bulk', actor);
    if (new Set(input.items.map(item => `${item.kind}:${item.id}`)).size !== input.items.length) throw new BadRequestException('Không lặp cùng đối tượng trong một batch.');
    const rows = await this.prisma.$transaction(async tx => Promise.all(input.items.map(async item => {
      try {
        this.permission(actor, item.kind);
        const work = await tx.moderationWorkItem.findUnique({ where: { kind_targetId: { kind: item.kind, targetId: item.id } }, select: { assigneeId: true } });
        if (work?.assigneeId && work.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) throw new ForbiddenException('Nội dung đang được admin khác xử lý.');
        const current: { id: string; version: number; status: string; replyStatus?: string | null; replyBody?: string | null; withdrawnAt?: Date | null } | null = item.kind === 'LISTING'
          ? await tx.roomListing.findUnique({ where: { id: item.id }, select: { id: true, version: true, status: true } })
          : item.kind === 'REPORT'
              ? await tx.listingReport.findUnique({ where: { id: item.id }, select: { id: true, version: true, status: true } })
              : await tx.roomReview.findUnique({ where: { id: item.id }, select: { id: true, version: true, status: true, replyStatus: true, replyBody: true, withdrawnAt: true } });
        if (!current) return { ...item, ready: false, reason: 'Không tìm thấy nội dung.' };
        const review = ['REVIEW', 'REPLY'].includes(item.kind) ? current : null;
        const status = item.kind === 'REPLY' ? review?.replyStatus : current.status;
        const allowed = item.kind === 'LISTING'
          ? ((item.decision === 'PUBLISH' || item.decision === 'REJECT') && status === 'PENDING') || (item.decision === 'HIDE' && status === 'PUBLISHED')
          : item.kind === 'REPORT'
              ? (item.decision === 'RESOLVED' || item.decision === 'DISMISSED') && status === 'OPEN'
              : !!review && !review.withdrawnAt && ['APPROVED', 'REJECTED', 'HIDDEN'].includes(item.decision) && status !== item.decision &&
                  (item.kind !== 'REPLY' || (!!review.replyBody && review.status === 'APPROVED'));
        if (item.kind === 'LISTING' && item.decision === 'PUBLISH' && allowed && current.version === item.version) {
          const available = await tx.roomListing.findFirst({ where: { id: item.id, room: { isActive: true, status: 'VACANT', property: { isArchived: false, landlord: { isActive: true } } } }, select: { id: true } });
          if (!available) return { ...item, ready: false, reason: 'Phòng không còn trống hoặc chủ trọ/khu trọ ngừng hoạt động.' };
        }
        return { ...item, ready: allowed && current.version === item.version, currentVersion: current.version, currentStatus: status,
          reason: allowed ? (current.version === item.version ? null : 'Phiên bản đã thay đổi.') : 'Trạng thái hiện tại không còn phù hợp.' };
      } catch (error) {
        if (!(error instanceof HttpException)) throw error;
        return { ...item, ready: false, reason: error.message };
      }
    })), { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
    return { data: rows, summary: { total: rows.length, ready: rows.filter(row => row.ready).length, blocked: rows.filter(row => !row.ready).length } };
  }
  async reports(actor: AuthUser, days = 30) {
    const kinds = actor.permissions?.includes('admin.moderation.reports') ? ['LISTING', 'REPORT', 'REVIEW', 'REPLY'] : moderationKinds(actor);
    const since = new Date(Date.now() - days * 86400000);
    const [decisions, appeals, escalations, queue] = await this.prisma.$transaction(async tx => Promise.all([
      tx.moderationDecision.groupBy({ by: ['kind', 'toStatus', 'source'], where: { kind: { in: kinds }, createdAt: { gte: since } }, _count: true }),
      tx.moderationAppeal.groupBy({ by: ['status'], where: { decision: { kind: { in: kinds } }, createdAt: { gte: since } }, _count: true }),
      tx.slaEscalation.count({ where: { kind: { in: kinds }, createdAt: { gte: since } } }),
      kinds.length ? tx.$queryRaw<{ kind: string; total: bigint; overdue: bigint }[]>`WITH q AS (${pendingModerationSql}) SELECT q.kind, COUNT(*) AS total,
        COUNT(*) FILTER (WHERE COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') < NOW()) AS overdue
        FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id WHERE q.kind IN (${Prisma.join(kinds)}) GROUP BY q.kind` : Promise.resolve([]),
    ]));
    return { data: { from: since.toISOString(), generatedAt: new Date().toISOString(), days, decisions: decisions.map(row => ({ kind: row.kind, status: row.toStatus, source: row.source, total: row._count })),
      appeals: appeals.map(row => ({ status: row.status, total: row._count })), escalations,
      queue: queue.map(row => ({ kind: row.kind, total: Number(row.total), overdue: Number(row.overdue) })) } };
  }
}
