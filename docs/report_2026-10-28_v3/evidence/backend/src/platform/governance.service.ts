import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DepositTransactionType, Prisma } from '@prisma/client';
import { ADMIN_PERMISSIONS, ADMIN_PRESETS, AdminPermission } from '../common/admin-permissions';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { adminAudit, maskedEmail } from '../admin/admin-audit';
import { platformAudit } from './platform-audit';
import { FeatureFlagsService, FeatureFlagDto } from './feature-flags.service';
import { FinanceQueryDto, PermissionSimulationDto, ReportScheduleCreateDto, ReportScheduleUpdateDto, TeamCreateDto, TeamMemberDto, TeamUpdateDto } from './governance.dto';
import { nextReportAt } from './report-schedule';

@Injectable()
export class GovernanceService {
  constructor(private readonly prisma: PrismaService, private readonly flags: FeatureFlagsService) {}
  private require(actor: AuthUser, permission: string) { if (actor.role !== 'admin' || !actor.permissions?.includes(permission)) throw new ForbiddenException(); }
  async team() {
    const rows = await this.prisma.user.findMany({ where: { role: 'ADMIN' }, include: { adminProfile: true, adminTeamMemberships: { include: { team: true } } }, orderBy: { fullName: 'asc' } });
    return { data: rows.map(row => ({ id: row.id, fullName: row.fullName, email: maskedEmail(row.email), isActive: row.isActive, profile: row.adminProfile ? { preset: row.adminProfile.preset, permissions: row.adminProfile.permissions, mfaEnabled: row.adminProfile.mfaEnabled } : null, teams: row.adminTeamMemberships.map(member => ({ id: member.team.id, name: member.team.name, role: member.role })) })) };
  }
  async teams() {
    const teams = await this.prisma.adminTeam.findMany({ include: { members: { include: { user: { select: { id: true, fullName: true, email: true } } } }, _count: { select: { tickets: true } } }, orderBy: { name: 'asc' } });
    return { data: teams.map(team => ({ ...team, members: team.members.map(member => ({ ...member, user: { ...member.user, email: maskedEmail(member.user.email) } })) })) };
  }
  async createTeam(actor: AuthUser, input: TeamCreateDto) {
    this.require(actor, 'admin.teams.manage');
    return this.prisma.$transaction(async tx => { const data = await tx.adminTeam.create({ data: { name: input.name, description: input.description } }); await adminAudit(tx, actor, 'admin.team_created', 'admin_team', data.id, input.reason); return { data }; });
  }
  async addMember(actor: AuthUser, teamId: string, input: TeamMemberDto) {
    this.require(actor, 'admin.teams.manage');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "userId" FROM "AdminProfile" WHERE "userId" = ${input.userId} FOR UPDATE`;
      const user = await tx.user.findFirst({ where: { id: input.userId, role: 'ADMIN', isActive: true } }); if (!user) throw new NotFoundException();
      const team = await tx.adminTeam.findFirst({ where: { id: teamId, isActive: true } }); if (!team) throw new NotFoundException();
      const before = await tx.adminTeamMember.findUnique({ where: { teamId_userId: { teamId, userId: input.userId } } });
      const data = await tx.adminTeamMember.upsert({ where: { teamId_userId: { teamId, userId: input.userId } }, create: { teamId, userId: input.userId, role: input.role }, update: { role: input.role } });
      await tx.adminProfile.updateMany({ where: { userId: input.userId }, data: { reviewVersion: { increment: 1 }, accessReviewedAt: null, accessReviewedBy: null, nextAccessReviewAt: null } });
      await adminAudit(tx, actor, 'admin.team_member_changed', 'admin_team', teamId, input.reason, { userId: input.userId, before: { role: before?.role ?? null }, after: { role: input.role } }); return { data };
    });
  }
  async updateTeam(actor: AuthUser, id: string, input: TeamUpdateDto) {
    this.require(actor, 'admin.teams.manage');
    return this.prisma.$transaction(async tx => {
      const changed = await tx.adminTeam.updateMany({ where: { id, version: input.version }, data: { name: input.name, description: input.description, isActive: input.isActive, version: { increment: 1 } } });
      if (!changed.count) throw new ConflictException('Nhóm đã thay đổi. Hãy tải lại.');
      await adminAudit(tx, actor, 'admin.team_updated', 'admin_team', id, input.reason);
      return { data: await tx.adminTeam.findUniqueOrThrow({ where: { id } }) };
    });
  }
  async removeMember(actor: AuthUser, teamId: string, userId: string, reason: string) {
    this.require(actor, 'admin.teams.manage');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "userId" FROM "AdminProfile" WHERE "userId" = ${userId} FOR UPDATE`;
      const before = await tx.adminTeamMember.findUnique({ where: { teamId_userId: { teamId, userId } } });
      if (!before) throw new NotFoundException();
      if (await tx.supportTicket.count({ where: { teamId, assigneeId: userId, status: { notIn: ['RESOLVED', 'CLOSED'] } } })) throw new ConflictException('Cần chuyển các ticket đang xử lý trước khi xóa thành viên.');
      await tx.adminTeamMember.deleteMany({ where: { teamId, userId } });
      await tx.adminProfile.updateMany({ where: { userId }, data: { reviewVersion: { increment: 1 }, accessReviewedAt: null, accessReviewedBy: null, nextAccessReviewAt: null } });
      await adminAudit(tx, actor, 'admin.team_member_removed', 'admin_team', teamId, reason, { userId, before: { role: before.role }, after: { role: null } });
      return { data: { removed: true } };
    });
  }
  simulate(actor: AuthUser, input: PermissionSimulationDto) {
    this.require(actor, 'admin.permissions.simulate');
    const permissions = [...(ADMIN_PRESETS[input.preset] ?? [])];
    const routePermissions: Record<string, AdminPermission> = { '/admin/operations': 'admin.operations.view', '/admin/support': 'admin.support.read', '/admin/support-center': 'admin.support.read', '/admin/tickets': 'admin.support.read', '/admin/notifications': 'admin.notifications.view', '/admin/moderation-v2': 'admin.moderation.reports', '/admin/governance': 'admin.flags.manage', '/admin/teams': 'admin.teams.manage', '/admin/permission-simulator': 'admin.permissions.simulate', '/admin/finance-reconciliation': 'admin.finance.read', '/admin/reports': 'admin.reports.manage', '/admin/report-schedules': 'admin.reports.manage' };
    const requestedAction = input.action as AdminPermission | undefined;
    const required = input.route ? routePermissions[input.route] : requestedAction && ADMIN_PERMISSIONS.includes(requestedAction) ? requestedAction : undefined;
    return { data: { preset: input.preset, permissions, checked: required ?? null, allowed: required ? permissions.includes(required) : false, note: 'Mô phỏng RBAC; MFA, trạng thái tài khoản và phạm vi tài nguyên vẫn được kiểm tra khi gọi API.' } };
  }
  flagsList(actor: AuthUser) { this.require(actor, 'admin.flags.manage'); return this.flags.list(); }
  flagsEffective(actor: AuthUser) { return this.flags.effective(actor); }
  flagsUpdate(actor: AuthUser, key: string, input: FeatureFlagDto) { this.require(actor, 'admin.flags.manage'); return this.flags.update(actor, key, input); }
  async finance(actor: AuthUser, query: FinanceQueryDto) {
    this.require(actor, 'admin.finance.read');
    const from = new Date(query.from), to = new Date(query.to); if (!Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) || from >= to || to.getTime() - from.getTime() > 366 * 86400000) throw new BadRequestException('Khoảng đối soát tối đa 366 ngày.');
    const scope = query.propertyId ? { propertyId: query.propertyId } : {};
    const [invoices, payments, deposits, expenses, ledger] = await this.prisma.$transaction([
      this.prisma.invoice.findMany({ where: { isDemo: false, issuedAt: { gte: from, lt: to }, room: scope }, select: { id: true, totalAmount: true, paidAmount: true, status: true, roomId: true }, take: 5001 }),
      this.prisma.payment.findMany({ where: { paidAt: { gte: from, lt: to }, invoice: { isDemo: false, room: scope } }, select: { id: true, invoiceId: true, amount: true, type: true, method: true, paidAt: true }, take: 5001 }),
      this.prisma.depositTransaction.findMany({ where: { occurredAt: { gte: from, lt: to }, lease: { room: scope } }, select: { id: true, leaseId: true, type: true, amount: true, occurredAt: true }, take: 5001 }),
      this.prisma.expense.findMany({ where: { expenseDate: { gte: from, lt: to }, ...(query.propertyId ? { propertyId: query.propertyId } : {}) }, select: { id: true, propertyId: true, amount: true, category: true, expenseDate: true }, take: 5001 }),
      this.prisma.payment.groupBy({ by: ['invoiceId'], where: { invoice: { isDemo: false, issuedAt: { gte: from, lt: to }, room: scope } }, _sum: { amount: true }, orderBy: { invoiceId: 'asc' }, take: 5001 }),
    ], { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });
    if ([invoices, payments, deposits, expenses].some(rows => rows.length > 5000)) throw new BadRequestException('Dữ liệu vượt 5.000 dòng. Chọn khoảng ngày hoặc khu trọ nhỏ hơn.');
    const signedPayments = payments.reduce((sum, payment) => sum + payment.amount, 0);
    const collected = deposits.filter(item => item.type === DepositTransactionType.COLLECTED).reduce((sum, item) => sum + item.amount, 0);
    const returned = deposits.filter(item => item.type === DepositTransactionType.REFUNDED).reduce((sum, item) => sum + item.amount, 0);
    const ledgerTotals = new Map(ledger.map(row => [row.invoiceId, row._sum?.amount ?? 0]));
    const reconciled = invoices.map(invoice => ({ invoiceId: invoice.id, invoicePaid: invoice.paidAmount, paymentEvents: ledgerTotals.get(invoice.id) ?? 0 }));
    return { data: { readOnly: true, from, to, counts: { invoices: invoices.length, payments: payments.length, deposits: deposits.length, expenses: expenses.length }, totals: { billed: invoices.reduce((sum, row) => sum + row.totalAmount, 0), invoicePaidSnapshot: invoices.reduce((sum, row) => sum + row.paidAmount, 0), paymentEvents: signedPayments, outstandingSnapshot: invoices.reduce((sum, row) => sum + Math.max(row.totalAmount - row.paidAmount, 0), 0), depositsCollected: collected, depositsReturned: returned, depositsDeducted: deposits.filter(item => item.type === DepositTransactionType.DEDUCTED).reduce((sum, item) => sum + item.amount, 0), expenses: expenses.reduce((sum, row) => sum + row.amount, 0) }, mismatches: reconciled.filter(row => row.invoicePaid !== row.paymentEvents), transactions: { invoices, payments, deposits, expenses } } };
  }
  async schedules(actor: AuthUser) { this.require(actor, 'admin.reports.manage'); return { data: await this.prisma.adminReportSchedule.findMany({ where: { ownerId: actor.userId }, include: { _count: { select: { runs: true } } }, orderBy: { nextRunAt: 'asc' } }) }; }
  async createSchedule(actor: AuthUser, input: ReportScheduleCreateDto) { this.require(actor, 'admin.reports.manage'); this.reportPermission(actor, input.kind); await this.flags.require('reports.scheduled', actor); const next = nextReportAt(new Date(), input.cadence, input.hourUtc, true, input.timezone); return this.prisma.$transaction(async tx => { const data = await tx.adminReportSchedule.create({ data: { ownerId: actor.userId, name: input.name, kind: input.kind, cadence: input.cadence, hourUtc: input.hourUtc, timezone: input.timezone, nextRunAt: next } }); await adminAudit(tx, actor, 'admin.report_schedule_created', 'admin_report_schedule', data.id, input.reason); return { data }; }); }
  async updateSchedule(actor: AuthUser, id: string, input: ReportScheduleUpdateDto) { this.require(actor, 'admin.reports.manage'); this.reportPermission(actor, input.kind); return this.prisma.$transaction(async tx => { const current = await tx.adminReportSchedule.findFirst({ where: { id, ownerId: actor.userId } }); if (!current) throw new NotFoundException(); const changed = await tx.adminReportSchedule.updateMany({ where: { id, version: input.version }, data: { name: input.name, kind: input.kind, cadence: input.cadence, hourUtc: input.hourUtc, timezone: input.timezone, nextRunAt: nextReportAt(new Date(), input.cadence, input.hourUtc, true, input.timezone), ...(input.enabled === undefined ? {} : { isEnabled: input.enabled }), version: { increment: 1 } } }); if (!changed.count) throw new ConflictException('Lịch báo cáo đã thay đổi.'); await adminAudit(tx, actor, 'admin.report_schedule_updated', 'admin_report_schedule', id, input.reason); return { data: await tx.adminReportSchedule.findUniqueOrThrow({ where: { id } }) }; }); }
  async runSchedule(actor: AuthUser, id: string) { this.require(actor, 'admin.reports.manage'); await this.flags.require('reports.scheduled', actor); return this.prisma.$transaction(async tx => { const schedule = await tx.adminReportSchedule.findFirst({ where: { id, ownerId: actor.userId, isEnabled: true } }); if (!schedule) throw new NotFoundException(); this.reportPermission(actor, schedule.kind); const scheduledFor = schedule.nextRunAt; const data = await tx.adminReportRun.upsert({ where: { scheduleId_scheduledFor: { scheduleId: id, scheduledFor } }, create: { scheduleId: id, scheduledFor, requestKey: `${id}:${scheduledFor.toISOString()}`, kind: schedule.kind, scheduleVersion: schedule.version, expiresAt: new Date(Date.now() + 7 * 86400000) }, update: {} }); await adminAudit(tx, actor, 'admin.report_run_queued', 'admin_report_schedule', id, 'Queued report export'); return { data: { id: data.id, status: data.status, scheduledFor: data.scheduledFor } }; }); }
  reportPermission(actor: AuthUser, kind: string) { this.require(actor, kind === 'MONTHLY_FINANCE' ? 'admin.finance.read' : kind === 'MODERATION' ? 'admin.moderation.reports' : 'admin.support.read'); }
}
