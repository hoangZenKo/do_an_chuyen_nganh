import { ConflictException, Injectable, Logger, NotFoundException, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { DeliveryCryptoService } from '../delivery/delivery-crypto.service';
import { AuthUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { adminAudit } from '../admin/admin-audit';
import { flagEnabled } from './feature-flags.service';
import { GovernanceService } from './governance.service';
import { nextReportAt } from './report-schedule';
import { ReportObjectStorageService } from './report-object-storage.service';
import { createHmac, timingSafeEqual } from 'node:crypto';

const runSelect = { id: true, scheduleId: true, kind: true, scheduledFor: true, status: true, attempts: true, lastError: true, completedAt: true, expiresAt: true, createdAt: true } as const;

export function reportCsv(rows: Record<string, unknown>[]) {
  const keys = [...new Set(rows.flatMap(row => Object.keys(row)))];
  const escape = (value: unknown) => {
    let text = String(value ?? '');
    if (/^[\s]*[=+\-@\t\r]/.test(text)) text = `'${text}`;
    return `"${text.replace(/"/g, '""')}"`;
  };
  return '\ufeff' + [keys.map(escape).join(','), ...rows.map(row => keys.map(key => escape(row[key])).join(','))].join('\r\n');
}

@Injectable()
export class AdminReportWorkerService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AdminReportWorkerService.name);
  private timer?: NodeJS.Timeout;
  private running = false;

  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService,
    private readonly crypto: DeliveryCryptoService,
    private readonly governance: GovernanceService, private readonly storage: ReportObjectStorageService) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('ADMIN_REPORT_WORKER_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.tick(), 60000);
    this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  async runs(actor: AuthUser, scheduleId: string) {
    const schedule = await this.prisma.adminReportSchedule.findFirst({ where: { id: scheduleId, ownerId: actor.userId } });
    if (!schedule) throw new NotFoundException();
    this.governance.reportPermission(actor, schedule.kind);
    return { data: await this.prisma.adminReportRun.findMany({ where: { scheduleId }, select: runSelect, orderBy: { createdAt: 'desc' }, take: 50 }) };
  }

  async download(actor: AuthUser, id: string) {
    const run = await this.prisma.adminReportRun.findFirst({ where: { id, schedule: { ownerId: actor.userId } } });
    if (!run) throw new NotFoundException();
    this.governance.reportPermission(actor, run.kind);
    if (run.status !== 'COMPLETED' || (!run.payload && !run.objectKey) || run.expiresAt <= new Date()) throw new ConflictException('Bản xuất chưa sẵn sàng hoặc đã hết hạn.');
    await this.prisma.$transaction(tx => adminAudit(tx, actor, 'admin.report_downloaded', 'admin_report_run', id, 'Downloaded own report export'));
    const encrypted = run.objectKey ? await this.storage.get(run.objectKey) : run.payload!;
    return reportCsv(JSON.parse(this.crypto.decrypt(encrypted)) as Record<string, unknown>[]);
  }

  async downloadLink(actor: AuthUser, id: string) {
    const run = await this.prisma.adminReportRun.findFirst({ where: { id, schedule: { ownerId: actor.userId }, status: 'COMPLETED', expiresAt: { gt: new Date() } } });
    if (!run) throw new NotFoundException();
    this.governance.reportPermission(actor, run.kind);
    const expires = Math.min(Date.now() + 5 * 60000, run.expiresAt.getTime());
    const body = `${actor.userId}:${id}:${expires}`;
    const signature = createHmac('sha256', this.config.getOrThrow<string>('JWT_ACCESS_SECRET')).update(`report-download:${body}`).digest('base64url');
    return { data: { path: `/admin/report-runs/${id}/download?expires=${expires}&signature=${signature}`, expiresAt: new Date(expires), requiresAuthentication: true } };
  }

  verifyLink(actor: AuthUser, id: string, expires?: string, signature?: string) {
    if (!expires && !signature) return;
    const expiry = Number(expires);
    if (!signature || !Number.isSafeInteger(expiry) || expiry <= Date.now() || expiry > Date.now() + 5 * 60000) throw new NotFoundException();
    const expected = createHmac('sha256', this.config.getOrThrow<string>('JWT_ACCESS_SECRET')).update(`report-download:${actor.userId}:${id}:${expiry}`).digest('base64url');
    if (signature.length !== expected.length || !timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) throw new NotFoundException();
  }

  async retry(actor: AuthUser, id: string, reason: string) {
    return this.prisma.$transaction(async tx => {
      const run = await tx.adminReportRun.findFirst({ where: { id, schedule: { ownerId: actor.userId, isEnabled: true }, status: 'FAILED', expiresAt: { gt: new Date() } } });
      if (!run) throw new ConflictException('Only unexpired failed reports can be retried.');
      this.governance.reportPermission(actor, run.kind);
      const updated = await tx.adminReportRun.updateMany({ where: { id, status: 'FAILED' }, data: { status: 'PENDING', attempts: 0, availableAt: new Date(), lastError: null } });
      if (!updated.count) throw new ConflictException('Report changed.');
      await adminAudit(tx, actor, 'admin.report_retried', 'admin_report_run', id, reason);
      return { data: { id, status: 'PENDING' } };
    });
  }

  async tick() {
    if (this.running) return;
    this.running = true;
    try {
      await this.enqueueDue();
      const pending = await this.prisma.adminReportRun.findMany({ where: { status: 'PENDING', availableAt: { lte: new Date() } }, select: { id: true }, orderBy: { createdAt: 'asc' }, take: 25 });
      for (const run of pending) await this.process(run.id);
      await this.prisma.adminReportRun.updateMany({ where: { expiresAt: { lte: new Date() }, status: { not: 'EXPIRED' } }, data: { payload: null, status: 'EXPIRED' } });
      await workerHeartbeat(this.prisma, 'admin-reports', true);
    } catch {
      this.logger.error('Admin report worker unavailable. Check database and encryption configuration.');
      await workerHeartbeat(this.prisma, 'admin-reports', false).catch(() => undefined);
    } finally { this.running = false; }
  }

  async enqueueDue() {
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102518)::text`;
      await tx.$queryRaw`SELECT id FROM "AdminReportSchedule" WHERE "isEnabled" = true AND "nextRunAt" <= NOW() ORDER BY "nextRunAt", id LIMIT 100 FOR UPDATE`;
      const schedules = await tx.adminReportSchedule.findMany({ where: { isEnabled: true, nextRunAt: { lte: new Date() } }, include: { owner: { include: { adminProfile: true } } }, take: 100 });
      const flag = await tx.featureFlag.findUnique({ where: { key: 'reports.scheduled' } });
      for (const schedule of schedules) {
        if (flag && !flagEnabled(flag, flag.key, schedule.ownerId, 'admin')) continue;
        const actor: AuthUser = { userId: schedule.ownerId, email: schedule.owner.email, role: AuthRole.ADMIN, permissions: schedule.owner.adminProfile?.permissions ?? [] };
        try {
          if (!schedule.owner.isActive || schedule.owner.role !== 'ADMIN' || !actor.permissions?.includes('admin.reports.manage')) continue;
          this.governance.reportPermission(actor, schedule.kind);
        } catch { continue; }
        await tx.adminReportRun.upsert({ where: { scheduleId_scheduledFor: { scheduleId: schedule.id, scheduledFor: schedule.nextRunAt } },
          create: { scheduleId: schedule.id, kind: schedule.kind, scheduleVersion: schedule.version, scheduledFor: schedule.nextRunAt,
            requestKey: `${schedule.id}:${schedule.nextRunAt.toISOString()}`, expiresAt: new Date(Date.now() + 7 * 86400000) }, update: {} });
        let next = nextReportAt(schedule.nextRunAt, schedule.cadence, schedule.hourUtc, false, schedule.timezone);
        while (next <= new Date()) next = nextReportAt(next, schedule.cadence, schedule.hourUtc, false, schedule.timezone);
        await tx.adminReportSchedule.update({ where: { id: schedule.id }, data: { nextRunAt: next, version: { increment: 1 } } });
      }
    });
  }

  async process(id: string) {
    try { await this.prisma.$transaction(async tx => {
      const [lock] = await tx.$queryRaw<{ acquired: boolean }[]>`SELECT pg_try_advisory_xact_lock(hashtext(${`report:${id}`})) AS acquired`;
      if (!lock.acquired) return;
      const run = await tx.adminReportRun.findUnique({ where: { id }, include: { schedule: { include: { owner: { include: { adminProfile: true } } } } } });
      if (!run || run.status !== 'PENDING' || run.availableAt > new Date()) return;
      const owner = run.schedule.owner;
      const actor: AuthUser = { userId: owner.id, email: owner.email, role: AuthRole.ADMIN, permissions: owner.adminProfile?.permissions ?? [] };
      try {
        if (!owner.isActive || owner.role !== 'ADMIN' || !run.schedule.isEnabled || !actor.permissions?.includes('admin.reports.manage')) throw new ConflictException();
        this.governance.reportPermission(actor, run.kind);
      } catch {
        await tx.adminReportRun.update({ where: { id }, data: { status: 'CANCELLED', payload: null, lastError: 'OWNER_PERMISSION_OR_SCHEDULE_CHANGED' } });
        return;
      }
      if (run.expiresAt <= new Date()) {
        await tx.adminReportRun.update({ where: { id }, data: { status: 'EXPIRED', payload: null } });
        return;
      }
      const flag = await tx.featureFlag.findUnique({ where: { key: 'reports.scheduled' } });
      if (flag && !flagEnabled(flag, flag.key, actor.userId, actor.role)) return;
      try {
        const rows = await this.snapshot(tx, run.kind);
        const payload = this.crypto.encrypt(rows);
        const objectKey = this.storage.ready() ? `admin-reports/${id}` : null;
        if (this.storage.required() && !objectKey) throw new Error('STORAGE_REQUIRED');
        if (objectKey) await this.storage.put(objectKey, payload, run.expiresAt);
        await tx.adminReportRun.update({ where: { id }, data: { status: 'COMPLETED', objectKey, payload: objectKey ? null : payload, completedAt: new Date(), attempts: { increment: 1 }, lastError: null } });
        await tx.platformNotification.upsert({ where: { userId_eventKey: { userId: owner.id, eventKey: `report:${id}` } },
          create: { userId: owner.id, eventKey: `report:${id}`, kind: 'REPORT_READY', title: 'Báo cáo đã sẵn sàng', body: 'Bản xuất có hiệu lực 7 ngày, chỉ chủ lịch được tải.', actionPath: '/admin/reports' }, update: {} });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError || error instanceof Prisma.PrismaClientUnknownRequestError) throw error;
        await tx.adminReportRun.update({ where: { id }, data: { status: run.attempts >= 2 ? 'FAILED' : 'PENDING', attempts: { increment: 1 }, availableAt: new Date(Date.now() + 60000 * 2 ** run.attempts), lastError: 'REPORT_GENERATION_FAILED', payload: null } });
      }
    }, { timeout: 20000 }); } catch {
      const run = await this.prisma.adminReportRun.findUnique({ where: { id }, select: { attempts: true, status: true } });
      if (run?.status === 'PENDING') await this.prisma.adminReportRun.updateMany({ where: { id, status: 'PENDING', attempts: run.attempts }, data: {
        status: run.attempts >= 2 ? 'FAILED' : 'PENDING', attempts: { increment: 1 }, availableAt: new Date(Date.now() + 60000 * 2 ** Math.min(run.attempts, 6)), lastError: 'REPORT_GENERATION_FAILED', payload: null,
      } });
    }
  }

  private async snapshot(tx: Prisma.TransactionClient, kind: string): Promise<Record<string, unknown>[]> {
    const to = new Date(), from = new Date(Date.now() - 30 * 86400000);
    if (kind === 'MODERATION') {
      const rows = await tx.moderationDecision.groupBy({ by: ['kind', 'toStatus', 'source'], where: { createdAt: { gte: from, lt: to } }, _count: true });
      return [{ report: kind, from: from.toISOString(), to: to.toISOString() }, ...rows.map(row => ({ kind: row.kind, status: row.toStatus, source: row.source, total: row._count }))];
    }
    if (kind === 'SUPPORT_SLA') {
      const statuses = await tx.supportTicket.groupBy({ by: ['status', 'priority'], _count: true });
      const overdue = await tx.supportTicket.count({ where: { status: { notIn: ['RESOLVED', 'CLOSED'] }, OR: [{ resolutionDueAt: { lt: to } }, { firstRespondedAt: null, firstResponseDueAt: { lt: to } }] } });
      return [{ report: kind, generatedAt: to.toISOString(), overdue }, ...statuses.map(row => ({ status: row.status, priority: row.priority, total: row._count }))];
    }
    const invoices = await tx.invoice.aggregate({ where: { isDemo: false, issuedAt: { gte: from, lt: to } }, _sum: { totalAmount: true, paidAmount: true }, _count: true });
    const payments = await tx.payment.aggregate({ where: { invoice: { isDemo: false }, paidAt: { gte: from, lt: to } }, _sum: { amount: true }, _count: true });
    const expenses = await tx.expense.aggregate({ where: { expenseDate: { gte: from, lt: to } }, _sum: { amount: true } });
    return [{ report: kind, from: from.toISOString(), to: to.toISOString(), invoices: invoices._count, billed: invoices._sum.totalAmount ?? 0, invoicePaidSnapshot: invoices._sum.paidAmount ?? 0, paymentEvents: payments._sum.amount ?? 0, expenses: expenses._sum.amount ?? 0, readOnly: true }];
  }
}
