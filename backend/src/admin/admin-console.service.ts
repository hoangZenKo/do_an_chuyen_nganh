import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { isUUID } from 'class-validator';
import * as argon2 from 'argon2';
import { PrismaService } from '../prisma/prisma.service';
import { ADMIN_PERMISSIONS, ADMIN_PRESETS, adminPermissionForWork } from '../common/admin-permissions';
import { AuthUser } from '../common/current-user.decorator';
import { AccountAccessService } from '../auth/account-access.service';
import { AdminMfaService } from '../auth/admin-mfa.service';
import { AdminAnalyticsQuery, AdminAuditQuery, AdminContextQuery, AdminInviteDto, AdminPageQuery, AdminProfileDto, AdminQueueQuery, AdminStatusDto, AdminWorkDto } from './admin-console.dto';
import { adminAudit, maskedEmail, maskedPhone } from './admin-audit';
import { auditWhere } from './admin-audit-query.service';
import { pendingModerationSql } from '../common/moderation-queue.sql';

const accountSelect = { id: true, fullName: true, email: true, phone: true, role: true, isActive: true, sessionVersion: true, createdAt: true } as const;
const pageMeta = (query: AdminPageQuery, total: number) => ({ page: query.page, limit: query.limit, total, pages: Math.ceil(total / query.limit) });

@Injectable()
export class AdminConsoleService {
  constructor(private readonly prisma: PrismaService, private readonly access: AccountAccessService, private readonly mfa: AdminMfaService) {}

  private accountView(user: { id: string; fullName: string; email: string; phone: string | null; role: UserRole; isActive: boolean; sessionVersion: number; createdAt: Date }) {
    return { id: user.id, fullName: user.fullName, email: maskedEmail(user.email), phone: maskedPhone(user.phone), role: user.role,
      isActive: user.isActive, version: user.sessionVersion, createdAt: user.createdAt };
  }

  async accounts(query: AdminPageQuery, admins = false) {
    if (query.from && query.to && new Date(query.from) > new Date(query.to)) {
      throw new BadRequestException('Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.');
    }
    if (!admins && query.role === 'ADMIN') throw new ForbiddenException();
    const where: Prisma.UserWhereInput = { role: admins ? 'ADMIN' : query.role ?? { not: 'ADMIN' },
      ...(query.status && query.status !== 'all' ? { isActive: query.status === 'active' } : {}),
      ...(query.from || query.to ? { createdAt: { ...(query.from ? { gte: new Date(query.from) } : {}), ...(query.to ? { lte: new Date(query.to) } : {}) } } : {}),
      ...(query.search ? { OR: [ { fullName: { contains: query.search, mode: 'insensitive' } }, { email: { contains: query.search, mode: 'insensitive' } }, { phone: { contains: query.search, mode: 'insensitive' } } ] } : {}) };
    const [total, users] = await this.prisma.$transaction([
      this.prisma.user.count({ where }), this.prisma.user.findMany({ where, select: { ...accountSelect, ...(admins ? { adminProfile: { select: { preset: true } } } : {}) },
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
    ], { isolationLevel: 'RepeatableRead' });
    return { data: users.map(user => ({ ...this.accountView(user), ...('adminProfile' in user ? { preset: (user.adminProfile as { preset: string } | null)?.preset ?? null } : {}) })), meta: pageMeta(query, total) };
  }

  async account(id: string) {
    const user = await this.prisma.user.findFirst({ where: { id, role: { not: 'ADMIN' } }, select: {
      ...accountSelect, staffProfile: { select: { landlordId: true, isActive: true } },
      tenantProfile: { select: { id: true, landlordId: true } }, _count: { select: { properties: true, tenants: true } },
    } });
    if (!user) throw new NotFoundException();
    const history = await this.prisma.auditLog.findMany({ where: { resourceType: 'user', resourceId: id, action: { startsWith: 'admin.account_' } },
      select: { id: true, action: true, summary: true, createdAt: true }, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], take: 20 });
    return { data: { ...this.accountView(user), staffProfile: user.staffProfile, tenantProfile: user.tenantProfile,
      counts: user._count, history } };
  }

  async status(actor: AuthUser, id: string, input: AdminStatusDto, isActive: boolean) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id} FOR UPDATE`;
      const user = await tx.user.findFirst({ where: { id, role: { not: 'ADMIN' } }, select: accountSelect });
      if (!user) throw new NotFoundException();
      if (user.sessionVersion !== input.version || user.isActive === isActive) throw new ConflictException('Tài khoản đã thay đổi. Hãy tải lại.');
      const updated = await tx.user.update({ where: { id }, data: { isActive, sessionVersion: { increment: 1 } }, select: accountSelect });
      await tx.authSession.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.refreshToken.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.accountAccessToken.updateMany({ where: { userId: id, consumedAt: null }, data: { consumedAt: new Date() } });
      if (user.role === 'LANDLORD' && !isActive) {
        const staff = await tx.staffProfile.findMany({ where: { landlordId: id }, select: { userId: true } });
        const ids = staff.map(item => item.userId);
        await tx.user.updateMany({ where: { id: { in: ids } }, data: { sessionVersion: { increment: 1 } } });
        await tx.refreshToken.updateMany({ where: { userId: { in: ids }, revokedAt: null }, data: { revokedAt: new Date() } });
        await tx.authSession.updateMany({ where: { userId: { in: ids }, revokedAt: null }, data: { revokedAt: new Date() } });
      }
      await adminAudit(tx, actor, isActive ? 'admin.account_restore' : 'admin.account_suspend', 'user', id, input.reason,
        { before: { isActive: user.isActive, version: user.sessionVersion }, after: { isActive, version: updated.sessionVersion }, dependentPolicy: 'staff_access_blocked;tenant_read_preserved;public_supply_hidden;no_financial_deletion' });
      return { data: this.accountView(updated) };
    });
  }

  async revoke(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id} FOR UPDATE`;
      const target = await tx.user.findUnique({ where: { id }, select: { role: true, sessionVersion: true } });
      if (!target || target.role === 'ADMIN') throw new NotFoundException();
      await tx.user.update({ where: { id }, data: { sessionVersion: { increment: 1 } } });
      await tx.refreshToken.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      const sessions = await tx.authSession.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      await adminAudit(tx, actor, 'admin.account_revoke_sessions', 'user', id, reason,
        { before: { version: target.sessionVersion }, after: { version: target.sessionVersion + 1 }, revokedSessions: sessions.count });
      return { data: { revoked: true, revokedSessions: sessions.count } };
    });
  }

  async reveal(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findFirst({ where: { id, role: { not: 'ADMIN' } }, select: { id: true, email: true, phone: true } });
      if (!user) throw new NotFoundException();
      await adminAudit(tx, actor, 'admin.pii_reveal', 'user', id, reason);
      return { data: user };
    });
  }

  private async grantAuthority(tx: Prisma.TransactionClient, actor: AuthUser) {
    const profile = await tx.adminProfile.findUnique({ where: { userId: actor.userId },
      select: { preset: true, permissions: true, user: { select: { role: true, isActive: true } } } });
    return profile?.preset === 'super_admin' && profile.user.role === 'ADMIN' && profile.user.isActive &&
      profile.permissions.includes('admin.admins.manage') && actor.permissions?.includes('admin.admins.manage')
      ? profile.permissions.filter(permission => actor.permissions!.includes(permission)) : null;
  }

  async adminAccess(actor: AuthUser, id: string) {
    return this.prisma.$transaction(async tx => {
      const user = await tx.user.findFirst({ where: { id, role: 'ADMIN' },
        select: { id: true, isActive: true, sessionVersion: true, adminProfile: { select: { preset: true, permissions: true } } } });
      if (!user?.adminProfile) throw new NotFoundException();
      const delegable = await this.grantAuthority(tx, actor);
      return { data: { id: user.id, isActive: user.isActive, version: user.sessionVersion,
        preset: user.adminProfile.preset, permissions: user.adminProfile.permissions,
        presetPermissions: ADMIN_PRESETS[user.adminProfile.preset] ?? [],
        delegablePermissions: delegable ?? [], canCustomizePermissions: id !== actor.userId && delegable !== null } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async updateAdmin(actor: AuthUser, id: string, input: AdminProfileDto) {
    const explicit = input.permissions !== undefined;
    const permissions = input.permissions ?? [...(ADMIN_PRESETS[input.preset] ?? [])];
    if (explicit && (!Array.isArray(input.permissions) || !permissions.length ||
        new Set(permissions).size !== permissions.length || !permissions.includes('admin.dashboard.view') ||
        permissions.some(permission => !ADMIN_PERMISSIONS.includes(permission)) ||
        (input.preset === 'super_admin' && ADMIN_PERMISSIONS.some(permission => !permissions.includes(permission))))) {
      throw new BadRequestException('Quyền phải hợp lệ, không trùng và có quyền tổng quan. Super admin phải giữ toàn bộ quyền.');
    }
    if (permissions.some(permission => !actor.permissions?.includes(permission))) {
      throw new ForbiddenException('Không được cấp quyền mà tài khoản của bạn chưa có.');
    }
    await this.mfa.verify(actor.userId, input.mfaCode);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62104024)::text`;
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${id} FOR UPDATE`;
      await tx.$queryRaw`SELECT "userId" FROM "AdminProfile" WHERE "userId" = ${id} FOR UPDATE`;
      if (explicit) {
        const delegable = await this.grantAuthority(tx, actor);
        if (!delegable || permissions.some(permission => !delegable.includes(permission))) {
          throw new ForbiddenException('Chỉ super admin đang hoạt động được cấp các quyền hiện có của mình.');
        }
      }
      const user = await tx.user.findFirst({ where: { id, role: 'ADMIN' }, include: { adminProfile: true } });
      if (!user?.adminProfile) throw new NotFoundException();
      if (actor.userId === id) throw new ForbiddenException('Không tự thay đổi quyền hoặc trạng thái admin của mình.');
      if (user.sessionVersion !== input.version) throw new ConflictException('Admin đã thay đổi.');
      if (user.isActive && user.adminProfile.preset === 'super_admin' && (!input.isActive || input.preset !== 'super_admin')) {
        const remaining = await tx.user.count({ where: { id: { not: id }, role: 'ADMIN', isActive: true, adminProfile: { preset: 'super_admin' } } });
        if (!remaining) throw new ConflictException('Phải giữ ít nhất một super admin hoạt động.');
      }
      await tx.adminProfile.update({ where: { userId: id }, data: { preset: input.preset, permissions: [...permissions], reviewVersion: { increment: 1 }, accessReviewedAt: null, accessReviewedBy: null, nextAccessReviewAt: null } });
      await tx.user.update({ where: { id }, data: { isActive: input.isActive, sessionVersion: { increment: 1 } } });
      await tx.refreshToken.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.authSession.updateMany({ where: { userId: id, revokedAt: null }, data: { revokedAt: new Date() } });
      if (!input.isActive) {
        await tx.accountAccessToken.updateMany({ where: { userId: id, consumedAt: null }, data: { consumedAt: new Date() } });
        await tx.deliveryJob.updateMany({ where: { token: { userId: id }, status: { in: ['PENDING', 'PROCESSING'] } }, data: { status: 'CANCELLED', payload: null, leaseOwner: null, leaseUntil: null } });
      }
      await adminAudit(tx, actor, 'admin.profile_update', 'user', id, input.reason, {
        before: { preset: user.adminProfile.preset, permissions: user.adminProfile.permissions, isActive: user.isActive, version: user.sessionVersion },
        after: { preset: input.preset, permissions: [...permissions], isActive: input.isActive, version: user.sessionVersion + 1 },
      });
      return { data: { updated: true } };
    });
  }

  async invite(actor: AuthUser, input: AdminInviteDto) {
    if (!this.access.ready()) throw new ServiceUnavailableException('Chưa cấu hình kênh gửi lời mời.');
    if (input.role === 'ADMIN') {
      if (!actor.permissions?.includes('admin.admins.manage') || !input.mfaCode) throw new ForbiddenException();
      if (ADMIN_PRESETS[input.preset ?? 'support'].some(permission => !actor.permissions?.includes(permission))) {
        throw new ForbiddenException('Không được mời admin với quyền mà tài khoản của bạn chưa có.');
      }
      await this.mfa.verify(actor.userId, input.mfaCode);
    } else if (!actor.permissions?.includes('admin.accounts.manage')) throw new ForbiddenException();
    const email = input.email.trim().toLowerCase();
    const passwordHash = await argon2.hash(randomBytes(48).toString('base64url'));
    const user = await this.prisma.$transaction(async tx => {
      if (await tx.user.findUnique({ where: { email } })) throw new ConflictException('Email đã được đăng ký.');
      const created = await tx.user.create({ data: { email, fullName: input.fullName.trim(), role: input.role, passwordHash,
        ...(input.role === 'ADMIN' ? { adminProfile: { create: { preset: input.preset ?? 'support', permissions: [...ADMIN_PRESETS[input.preset ?? 'support']] } } } : {}) }, select: { id: true } });
      await adminAudit(tx, actor, 'admin.account_invite', 'user', created.id, input.reason);
      await this.access.enqueue(tx, created.id, 'INVITE');
      return created;
    });
    return { data: { id: user.id, queued: true } };
  }

  async reset(actor: AuthUser, id: string, reason: string) {
    const user = await this.prisma.user.findFirst({ where: { id, role: { not: 'ADMIN' }, isActive: true }, select: { id: true } });
    if (!user) throw new NotFoundException();
    await this.prisma.$transaction(async tx => {
      await this.access.enqueue(tx, id, 'PASSWORD_RESET');
      await adminAudit(tx, actor, 'admin.account_reset_requested', 'user', id, reason);
    });
    return { data: { queued: true } };
  }

  async audit(query: AdminAuditQuery) {
    const where = auditWhere(query);
    const [total, rows] = await this.prisma.$transaction([this.prisma.auditLog.count({ where }), this.prisma.auditLog.findMany({ where,
      select: { id: true, actorId: true, actorRole: true, action: true, resourceType: true, resourceId: true, summary: true, requestId: true, createdAt: true },
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], take: query.limit, skip: (query.page - 1) * query.limit })], { isolationLevel: 'RepeatableRead' });
    return { data: rows, meta: pageMeta(query, total) };
  }

  async context(actor: AuthUser, input: AdminContextQuery) {
    return this.prisma.$transaction(async tx => {
      let result: unknown;
      const id = input.id;
      if (input.kind === 'account') {
        const user = await tx.user.findFirst({ where: { id, role: { not: 'ADMIN' } }, select: accountSelect });
        if (user) result = this.accountView(user);
      } else if (input.kind === 'property') result = await tx.property.findUnique({ where: { id }, select: { id: true, name: true, landlordId: true, isArchived: true, _count: { select: { rooms: true } } } });
      else if (input.kind === 'room') result = await tx.room.findUnique({ where: { id }, select: { id: true, name: true, propertyId: true, status: true, isActive: true } });
      else if (input.kind === 'tenant') result = await tx.tenant.findUnique({ where: { id }, select: { id: true, fullName: true, landlordId: true, userId: true, isActive: true } });
      else if (input.kind === 'lease') result = await tx.lease.findUnique({ where: { id }, select: { id: true, tenantId: true, roomId: true, startDate: true, endDate: true, status: true, monthlyRent: true } });
      else if (input.kind === 'invoice') result = await tx.invoice.findUnique({ where: { id }, select: { id: true, leaseId: true, totalAmount: true, paidAmount: true, status: true, dueDate: true, billingMonth: true } });
      if (!result) throw new NotFoundException('Không tìm thấy dữ liệu hỗ trợ.');
      await adminAudit(tx, actor, 'admin.support_context_read', input.kind, id, input.reason);
      return { data: result };
    });
  }

  private queueWhere(actor: AuthUser, query: AdminQueueQuery) {
    if (!actor.permissions?.includes(adminPermissionForWork(query.kind))) throw new ForbiddenException();
    return Prisma.sql`q.kind = ${query.kind}
      ${query.search ? isUUID(query.search)
        ? Prisma.sql`AND q.id::text = ${query.search.toLowerCase()}`
        : Prisma.sql`AND q.title ILIKE ${`%${query.search}%`}` : Prisma.empty}
      ${query.assignment === 'mine' ? Prisma.sql`AND w."assigneeId" = ${actor.userId}` : query.assignment === 'unassigned' ? Prisma.sql`AND w."assigneeId" IS NULL` : Prisma.empty}
      ${query.priority ? Prisma.sql`AND COALESCE(w.priority, 'NORMAL') = ${query.priority}` : Prisma.empty}
      ${query.overdue === 'true' ? Prisma.sql`AND COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') < NOW()` : Prisma.empty}`;
  }
  async queue(actor: AuthUser, query: AdminQueueQuery) {
    const filter = this.queueWhere(actor, query);
    return this.prisma.$transaction(async tx => {
      const counts = await tx.$queryRaw<{ total: bigint }[]>`WITH q AS (${pendingModerationSql}) SELECT COUNT(*) AS total FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id WHERE ${filter}`;
      const data = await tx.$queryRaw`WITH q AS (${pendingModerationSql}) SELECT q.*, w.id AS "workId", w."assigneeId", COALESCE(w.version, 0) AS "workVersion", COALESCE(w.priority, 'NORMAL') AS priority,
        COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') AS "dueAt", COALESCE(w.note, '') AS note
        FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id WHERE ${filter}
        ORDER BY CASE COALESCE(w.priority, 'NORMAL') WHEN 'URGENT' THEN 0 WHEN 'HIGH' THEN 1 ELSE 2 END,
        COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours'), q.id LIMIT ${query.limit} OFFSET ${(query.page - 1) * query.limit}`;
      return { data, meta: pageMeta(query, Number(counts[0].total)) };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async work(actor: AuthUser, input: AdminWorkDto) {
    const permission = adminPermissionForWork(input.kind);
    if (!actor.permissions?.includes(permission)) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${`${input.kind}:${input.targetId}`}))::text`;
      const pending = await tx.$queryRaw<{ id: string }[]>`WITH q AS (${pendingModerationSql}) SELECT id FROM q WHERE kind = ${input.kind} AND id = ${input.targetId}`;
      if (!pending.length) throw new ConflictException('Nội dung không còn chờ xử lý.');
      if (input.assigneeId) {
        const assignee = await tx.adminProfile.findFirst({ where: { userId: input.assigneeId, permissions: { has: permission }, user: { isActive: true, role: 'ADMIN' } } });
        if (!assignee) throw new BadRequestException('Người phụ trách không có quyền xử lý nội dung.');
      }
      const existing = await tx.moderationWorkItem.findUnique({ where: { kind_targetId: { kind: input.kind, targetId: input.targetId } } });
      if ((existing?.version ?? 0) !== input.version) throw new ConflictException('Phân công đã thay đổi. Hãy tải lại.');
      if (existing?.assigneeId && existing.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) throw new ForbiddenException('Công việc thuộc admin khác.');
      if (input.assigneeId && input.assigneeId !== actor.userId && !actor.permissions?.includes('admin.admins.manage')) throw new ForbiddenException('Chỉ được nhận việc cho chính mình.');
      const values = { assigneeId: input.assigneeId ?? null, priority: input.priority, dueAt: new Date(input.dueAt), note: input.note };
      const data = existing ? await tx.moderationWorkItem.update({ where: { id: existing.id }, data: { ...values, version: { increment: 1 } } })
        : await tx.moderationWorkItem.create({ data: { kind: input.kind, targetId: input.targetId, ...values } });
      await adminAudit(tx, actor, 'admin.moderation_assignment', input.kind, input.targetId, input.reason, { assigneeId: values.assigneeId, priority: values.priority, version: data.version });
      return { data };
    });
  }

  async moderationItem(actor: AuthUser, kind: string, id: string) {
    if (!['LISTING', 'REPORT', 'REVIEW', 'REPLY'].includes(kind)) throw new BadRequestException();
    if (!actor.permissions?.includes(adminPermissionForWork(kind))) throw new ForbiddenException();
    let data: unknown;
    if (kind === 'LISTING') data = await this.prisma.roomListing.findUnique({ where: { id }, select: { id: true, title: true, description: true, city: true, district: true, publicAddress: true, monthlyRent: true, imageUrls: true, status: true, version: true, reviewNote: true } });
    else if (kind === 'REPORT') data = await this.prisma.listingReport.findUnique({ where: { id }, select: { id: true, listingId: true, reason: true, detail: true, status: true, reviewNote: true } });
    else data = await this.prisma.roomReview.findUnique({ where: { id }, select: { id: true, body: true, replyBody: true, roomRating: true, costRating: true, landlordRating: true, areaRating: true, status: true, replyStatus: true, withdrawnAt: true, version: true, moderationNote: true, replyModerationNote: true } });
    if (!data) throw new NotFoundException();
    const history = await this.prisma.auditLog.findMany({ where: { resourceId: id, action: { startsWith: kind === 'REPORT' || kind === 'LISTING' ? 'listing.' : 'review.' } }, select: { action: true, summary: true, createdAt: true, actorId: true }, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], take: 20 });
    return { data: { ...(data as object), history } };
  }

  async analytics(actor: AuthUser, query: AdminAnalyticsQuery) {
    const since = new Date(Date.now() - query.days * 86400000), previous = new Date(since.getTime() - query.days * 86400000);
    const kinds = ['LISTING', 'REPORT', 'REVIEW', 'REPLY'].filter(kind => actor.permissions?.includes(adminPermissionForWork(kind)));
    return this.prisma.$transaction(async tx => {
      const queue = kinds.length ? await tx.$queryRaw<{ kind: string; total: bigint; overdue: bigint }[]>`WITH q AS (${pendingModerationSql})
        SELECT q.kind, COUNT(*) AS total, COUNT(*) FILTER (WHERE COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') < NOW()) AS overdue
        FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id WHERE q.kind IN (${Prisma.join(kinds)}) GROUP BY q.kind` : [];
      const [users, priorUsers, listings, priorListings] = await Promise.all([
        tx.user.count({ where: { role: { not: 'ADMIN' }, createdAt: { gte: since } } }),
        tx.user.count({ where: { role: { not: 'ADMIN' }, createdAt: { gte: previous, lt: since } } }),
        tx.roomListing.count({ where: { createdAt: { gte: since } } }), tx.roomListing.count({ where: { createdAt: { gte: previous, lt: since } } }),
      ]);
      const trends = await tx.$queryRaw<{ day: string; users: bigint; listings: bigint }[]>`
        WITH days AS (SELECT generate_series((${since}::timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, (NOW() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date, '1 day')::date AS day)
        SELECT to_char(d.day, 'YYYY-MM-DD') AS day,
        (SELECT COUNT(*) FROM "User" u WHERE u.role <> 'ADMIN' AND (u."createdAt" AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = d.day AND u."createdAt" >= ${since}) AS users,
        (SELECT COUNT(*) FROM "RoomListing" l WHERE (l."createdAt" AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = d.day AND l."createdAt" >= ${since}) AS listings FROM days d ORDER BY d.day`;
      const business: Record<string, unknown> = {};
      if (actor.permissions?.includes('admin.properties.view')) {
        const rooms = await tx.room.groupBy({ by: ['status'], where: { isActive: true, property: { isArchived: false } }, _count: true });
        const total = rooms.reduce((sum, row) => sum + row._count, 0);
        const occupied = rooms.find(row => row.status === 'OCCUPIED')?._count ?? 0;
        business.rooms = { total, occupied, occupancyRate: total ? occupied / total : 0 };
      }
      if (actor.permissions?.includes('admin.finance.read')) {
        const collected = await tx.payment.aggregate({ where: { paidAt: { gte: since }, invoice: { isDemo: false } }, _sum: { amount: true } });
        const balances = await tx.invoice.aggregate({ where: { isDemo: false, status: { in: ['UNPAID', 'PARTIAL'] } }, _sum: { totalAmount: true, paidAmount: true } });
        const expenses = await tx.expense.aggregate({ where: { expenseDate: { gte: since } }, _sum: { amount: true } });
        business.finance = { paymentEvents: collected._sum.amount ?? 0, outstandingSnapshot: (balances._sum.totalAmount ?? 0) - (balances._sum.paidAmount ?? 0), expenses: expenses._sum.amount ?? 0, platformRevenue: false };
      }
      if (actor.permissions?.includes('admin.support.read')) {
        const open = await tx.supportTicket.count({ where: { status: { notIn: ['RESOLVED', 'CLOSED'] } } });
        const overdue = await tx.supportTicket.count({ where: { status: { notIn: ['RESOLVED', 'CLOSED'] }, OR: [{ resolutionDueAt: { lt: new Date() } }, { firstRespondedAt: null, firstResponseDueAt: { lt: new Date() } }] } });
        const feedback = await tx.supportTicket.aggregate({ where: { feedbackAt: { gte: since } }, _avg: { feedbackRating: true }, _count: { feedbackRating: true } });
        business.support = { open, overdue, csat: feedback._avg.feedbackRating, responses: feedback._count.feedbackRating };
      }
      return { data: { generatedAt: new Date().toISOString(), from: since, days: query.days, timezone: 'Asia/Ho_Chi_Minh',
        business,
        newAccounts: users, previousAccounts: priorUsers, newListings: listings, previousListings: priorListings,
        queue: queue.map(row => ({ ...row, total: Number(row.total), overdue: Number(row.overdue) })),
        trends: trends.map(row => ({ ...row, users: Number(row.users), listings: Number(row.listings) })), deliveryConfigured: this.access.ready() } };
    }, { isolationLevel: 'RepeatableRead' });
  }
}
