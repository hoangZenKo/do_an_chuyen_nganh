import { ConflictException, Injectable, Logger, NotFoundException, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { DeliveryService } from '../delivery/delivery.service';
import { DeliveryCryptoService } from '../delivery/delivery-crypto.service';
import { RuntimeMetricsService } from './runtime-metrics.service';
import { workerHeartbeat } from '../common/worker-heartbeat';
import { AuthUser } from '../common/current-user.decorator';
import { adminAudit } from '../admin/admin-audit';
import { pendingModerationSql } from '../common/moderation-queue.sql';
import { adminPermissionForWork } from '../common/admin-permissions';
import { SchemaReadinessService } from './schema-readiness.service';
import { BackupTelemetryService } from './backup-telemetry.service';

@Injectable()
export class OperationsHealthService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OperationsHealthService.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService,
    private readonly delivery: DeliveryService, private readonly crypto: DeliveryCryptoService,
    private readonly metrics: RuntimeMetricsService, private readonly schema: SchemaReadinessService,
    private readonly backups: BackupTelemetryService) {}

  onModuleInit() {
    if (this.config.get('NODE_ENV') === 'test' || this.config.get('OPERATIONS_MONITOR_ENABLED') === 'false') return;
    this.timer = setInterval(() => void this.evaluate(), 60000);
    this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }

  async summary() {
    await this.metrics.flush();
    const since = new Date(Date.now() - 15 * 60000);
    const [counts, workers, incidents, deliveries, overdue, migrations, notifications, reports, readiness, backup] = await Promise.all([
      this.prisma.operationsMetric.aggregate({ where: { minute: { gte: since } }, _sum: { requests: true, errors: true, durationMs: true, loginFailures: true, mfaFailures: true } }),
      this.prisma.workerHeartbeat.findMany({ orderBy: { name: 'asc' } }),
      this.prisma.operationsIncident.findMany({ orderBy: { lastSeenAt: 'desc' }, take: 50 }),
      this.prisma.deliveryJob.groupBy({ by: ['status'], _count: true }),
      this.prisma.$queryRaw<{ total: bigint }[]>`WITH q AS (${pendingModerationSql}) SELECT COUNT(*) AS total FROM q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id WHERE COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') < NOW()`,
      this.prisma.$queryRaw<{ migration_name: string; finished_at: Date | null; rolled_back_at: Date | null }[]>`SELECT migration_name, finished_at, rolled_back_at FROM "_prisma_migrations" ORDER BY started_at DESC LIMIT 5`,
      this.prisma.platformNotificationDelivery.groupBy({ by: ['status'], _count: true }),
      this.prisma.adminReportRun.groupBy({ by: ['status'], where: { expiresAt: { gt: new Date() } }, _count: true }),
      this.schema.inspect().then(result => ({ ...result, status: result.ready ? 'READY' : 'NOT_READY' }))
        .catch(() => ({ status: 'UNAVAILABLE', ready: false, authSchemaReady: false, billingSchemaReady: false, missing: [], drifted: [], failed: [], unexpected: [], catalogSize: 0, checkedAt: new Date().toISOString() })),
      this.backups.inspect(),
    ]);
    const requests = counts._sum.requests ?? 0;
    const errors = counts._sum.errors ?? 0;
    const expected = this.expectedWorkers();
    const heartbeat = expected.map(worker => {
      const current = workers.find(row => row.name === worker.name);
      return { name: worker.name, status: !current ? 'NOT_REPORTED' : Date.now() - current.lastRunAt.getTime() > worker.interval ? 'STALE' : current.status, lastRunAt: current?.lastRunAt ?? null, lastSuccessAt: current?.lastSuccessAt ?? null };
    });
    const blockers = [
      ...(!readiness.ready ? ['SCHEMA_NOT_READY'] : []),
      ...(backup.status !== 'OK' ? ['BACKUP_UNVERIFIED_OR_STALE'] : []),
      ...(!this.delivery.configured() ? ['ACCOUNT_DELIVERY_NOT_CONFIGURED'] : []),
      ...(!this.delivery.configured('INCIDENT_ALERT') ? ['ALERT_DELIVERY_NOT_CONFIGURED'] : []),
      ...(!this.config.get('SUPPORT_SCAN_WEBHOOK_URL') || !this.config.get('SUPPORT_SCAN_WEBHOOK_SECRET') ? ['SCANNER_NOT_CONFIGURED'] : []),
      ...(!this.config.get('REPORT_STORAGE_URL') || !this.config.get('REPORT_STORAGE_SECRET') ? ['REPORT_STORAGE_NOT_CONFIGURED'] : []),
      ...(heartbeat.some(worker => worker.status !== 'OK') ? ['WORKER_HEARTBEAT_NOT_HEALTHY'] : []),
    ];
    return { data: { generatedAt: new Date().toISOString(), database: 'ok', windowMinutes: 15,
      metrics: { requests, errors, errorRate: requests ? errors / requests : 0, averageDurationMs: requests ? Math.round((counts._sum.durationMs ?? 0) / requests) : 0,
        loginFailures: counts._sum.loginFailures ?? 0, mfaFailures: counts._sum.mfaFailures ?? 0 },
      instance: { uptimeSeconds: Math.floor(process.uptime()), ...this.metrics.snapshot() },
      workers: heartbeat, incidents, deliveries: deliveries.map(row => ({ status: row.status, total: row._count })),
      queues: { notifications: notifications.map(row => ({ status: row.status, total: row._count })), reports: reports.map(row => ({ status: row.status, total: row._count })) },
      moderationOverdue: Number(overdue[0].total), migrations: migrations.map(row => ({ name: row.migration_name, applied: !!row.finished_at, rolledBack: !!row.rolled_back_at })),
      accountDeliveryConfigured: this.delivery.configured(), alertDeliveryConfigured: this.delivery.configured('INCIDENT_ALERT'),
      readiness, backup,
      releaseGate: { status: blockers.length ? 'BLOCKED' : 'MANUAL_ACCEPTANCE_REQUIRED', blockers, productionAccepted: false,
        manualChecks: ['STAGING_MIGRATION_REHEARSAL', 'BACKUP_RESTORE', 'REAL_MFA_AND_REVOCATION', 'PROVIDER_BUSINESS_DELIVERY', 'WORKER_RECOVERY_AND_ALERT_RECEIVER', 'DEVICE_QA'],
        runbook: 'docs/admin-release-gate-runbook.md' },
      auditRetention: { automaticDeletion: false, policy: 'Archive encrypted backups before any approved retention change.' },
    } };
  }

  private expectedWorkers() {
    const billingInterval = Number(this.config.get('BILLING_AUTOMATION_INTERVAL_MS') ?? 3600000);
    return [
      { name: 'delivery', enabled: this.config.get('DELIVERY_WORKER_ENABLED') !== 'false', interval: 120000 },
      { name: 'billing', enabled: this.config.get('BILLING_AUTOMATION_WORKER_ENABLED') !== 'false', interval: (Number.isFinite(billingInterval) ? billingInterval : 3600000) * 2 + 120000 },
      { name: 'operations', enabled: this.config.get('OPERATIONS_SCHEDULER_ENABLED') !== 'false', interval: 180000 },
      { name: 'viewing-reminder', enabled: this.config.get('VIEWING_REMINDER_WORKER_ENABLED') !== 'false', interval: 180000 },
      { name: 'admin-reports', enabled: this.config.get('ADMIN_REPORT_WORKER_ENABLED') !== 'false', interval: 180000 },
      { name: 'notification-delivery', enabled: this.config.get('NOTIFICATION_DELIVERY_ENABLED') !== 'false', interval: 120000 },
      { name: 'support-sla', enabled: this.config.get('SUPPORT_SLA_WORKER_ENABLED') !== 'false', interval: 180000 },
    ].filter(worker => worker.enabled);
  }

  async evaluate() {
    if (this.running) return;
    this.running = true;
    try {
      await this.escalateModerationSla();
      const { data } = await this.summary();
      const since = new Date(Date.now() - 15 * 60000);
      const [pii, deadRecent, pendingTooOld] = await Promise.all([
        this.prisma.auditLog.count({ where: { action: 'admin.pii_reveal', createdAt: { gte: since } } }),
        this.prisma.deliveryJob.count({ where: { status: 'DEAD', updatedAt: { gte: since } } }),
        this.prisma.deliveryJob.count({ where: { status: 'PENDING', availableAt: { lte: new Date(Date.now() - 5 * 60000) } } }),
      ]);
      const rules = [
        { key: 'API_ERROR_RATE', active: data.metrics.errors >= 5 && data.metrics.errorRate >= 0.05, title: 'API lỗi trên 5% trong 15 phút', severity: 'CRITICAL' },
        { key: 'LOGIN_FAILURES', active: data.metrics.loginFailures >= 20, title: 'Đăng nhập thất bại bất thường', severity: 'WARNING' },
        { key: 'MFA_FAILURES', active: data.metrics.mfaFailures >= 10, title: 'Nhiều lần xác thực MFA thất bại', severity: 'CRITICAL' },
        { key: 'PII_REVEALS', active: pii >= 20, title: 'Tần suất mở thông tin cá nhân cao', severity: 'WARNING' },
        { key: 'DELIVERY_FAILURES', active: deadRecent > 0 || pendingTooOld > 0, title: 'Có job gửi email/cảnh báo bị lỗi hoặc chậm', severity: 'WARNING' },
        { key: 'NOTIFICATION_DEAD_LETTERS', active: data.queues.notifications.some(row => row.status === 'DEAD' && row.total > 0), title: 'Notification delivery has dead letters', severity: 'WARNING' },
        { key: 'REPORT_FAILURES', active: data.queues.reports.some(row => row.status === 'FAILED' && row.total > 0), title: 'Scheduled reports need retry', severity: 'WARNING' },
        { key: 'MODERATION_OVERDUE', active: data.moderationOverdue > 0, title: 'Hàng đợi kiểm duyệt quá hạn', severity: 'WARNING' },
        ...data.workers.map(worker => ({ key: `WORKER_${worker.name}`, active: worker.status === 'FAILED' || worker.status === 'STALE' || (worker.status === 'NOT_REPORTED' && process.uptime() * 1000 > (this.expectedWorkers().find(item => item.name === worker.name)?.interval ?? 180000)), title: `Worker ${worker.name} không hoạt động bình thường`, severity: 'CRITICAL' })),
      ];
      await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102516)::text`;
        for (const rule of rules) {
          await tx.$queryRaw`SELECT id FROM "OperationsIncident" WHERE key = ${rule.key} FOR UPDATE`;
          const previous = await tx.operationsIncident.findUnique({ where: { key: rule.key } });
          if (!rule.active) {
            if (previous?.conditionActive) {
              await tx.operationsIncident.update({ where: { id: previous.id }, data: { conditionActive: false, status: 'RESOLVED', resolvedAt: new Date(), snoozedUntil: null, resolvedBy: 'SYSTEM', resolutionNote: 'Điều kiện lỗi đã phục hồi theo kiểm tra tự động.', version: { increment: 1 } } });
              await tx.auditLog.create({ data: { actorRole: 'ADMIN', action: 'system.incident_recovered', resourceType: 'incident', resourceId: previous.id, summary: 'Monitored condition recovered' } });
            }
            continue;
          }
          const newOccurrence = !previous || previous.status === 'RESOLVED';
          const wake = previous?.status === 'SNOOZED' && (!previous.snoozedUntil || previous.snoozedUntil <= new Date());
          const changed = newOccurrence || wake || previous?.conditionActive === false || previous?.severity !== rule.severity;
          const incident = await tx.operationsIncident.upsert({ where: { key: rule.key },
            create: { key: rule.key, title: rule.title, severity: rule.severity },
            update: { lastSeenAt: new Date(), occurrences: { increment: 1 }, conditionActive: true, severity: rule.severity, ...(changed ? { version: { increment: 1 } } : {}), ...(newOccurrence ? { status: 'OPEN', acknowledgedBy: null, resolvedAt: null, resolvedBy: null, resolutionNote: null, snoozedUntil: null } : wake ? { status: previous?.acknowledgedBy ? 'ACKNOWLEDGED' : 'OPEN', snoozedUntil: null } : {}) } });
          if (newOccurrence || wake) await tx.auditLog.create({ data: { actorRole: 'ADMIN', action: wake ? 'system.incident_snooze_expired' : 'system.incident_opened', resourceType: 'incident', resourceId: incident.id, summary: rule.title } });
          if (newOccurrence && this.delivery.configured('INCIDENT_ALERT')) {
            await tx.deliveryJob.create({ data: { kind: 'INCIDENT_ALERT', expiresAt: new Date(Date.now() + 24 * 3600000), payload: this.crypto.encrypt({ incidentId: incident.id, key: rule.key, severity: rule.severity, title: rule.title, occurredAt: incident.lastSeenAt.toISOString() }) } });
          }
        }
      });
      await workerHeartbeat(this.prisma, 'monitor', true);
    } catch {
      this.logger.error('Operations monitor unavailable. Check database and external readiness monitoring.');
      await workerHeartbeat(this.prisma, 'monitor', false).catch(() => undefined);
    } finally { this.running = false; }
  }

  private async escalateModerationSla() {
    const now = new Date();
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(62102517)::text`;
      const overdue = await tx.$queryRaw<{ kind: string; targetId: string; assigneeId: string | null; dueAt: Date; domainKind: string; originalActorId: string | null }[]>`
        WITH candidates AS (
          SELECT q.kind, q.id AS "targetId", w."assigneeId", COALESCE(w."dueAt", q."createdAt" + INTERVAL '48 hours') AS "dueAt", q.kind AS "domainKind", NULL::text AS "originalActorId"
          FROM (${pendingModerationSql}) q LEFT JOIN "ModerationWorkItem" w ON w.kind = q.kind AND w."targetId" = q.id
          UNION ALL SELECT 'APPEAL', a.id, a."assigneeId", a."dueAt", d.kind, d."actorId" FROM "ModerationAppeal" a JOIN "ModerationDecision" d ON d.id = a."decisionId" WHERE a.status = 'OPEN'
          UNION ALL SELECT 'SUPPORT_RESPONSE', id, "assigneeId", "firstResponseDueAt", 'SUPPORT', NULL::text FROM "SupportTicket" WHERE "firstRespondedAt" IS NULL AND "slaSnapshot" IS NULL AND status NOT IN ('RESOLVED', 'CLOSED')
          UNION ALL SELECT 'SUPPORT_RESOLUTION', id, "assigneeId", "resolutionDueAt", 'SUPPORT', NULL::text FROM "SupportTicket" WHERE "slaSnapshot" IS NULL AND "slaPausedAt" IS NULL AND status NOT IN ('RESOLVED', 'CLOSED')
        ) SELECT c.* FROM candidates c LEFT JOIN "SlaEscalation" e ON e.kind = c.kind AND e."targetId" = c."targetId" AND e."dueAt" = c."dueAt"
        WHERE c."dueAt" < ${now} AND e.id IS NULL ORDER BY c."dueAt", c."targetId" LIMIT 500`;
      for (const item of overdue) {
        await tx.slaEscalation.create({ data: { kind: item.kind, targetId: item.targetId, dueAt: item.dueAt } });
        await tx.moderationWorkItem.updateMany({ where: { kind: item.kind, targetId: item.targetId }, data: { escalatedAt: now } });
        const permissions = item.domainKind === 'SUPPORT' ? ['admin.support.read', 'admin.support.manage'] : [adminPermissionForWork(item.domainKind), ...(item.kind === 'APPEAL' ? ['admin.moderation.appeals'] : [])];
        const recipients = await tx.user.findMany({ where: { role: 'ADMIN', isActive: true,
          ...(item.originalActorId ? { id: { not: item.originalActorId } } : {}),
          adminProfile: { permissions: { hasEvery: [...permissions, 'admin.notifications.view'] } },
          ...(item.assigneeId ? { OR: [{ id: item.assigneeId }, { adminProfile: { permissions: { has: 'admin.operations.manage' } } }] } : {}),
        }, select: { id: true }, take: 100 });
        for (const recipient of recipients) {
          await tx.platformNotification.upsert({
            where: { userId_eventKey: { userId: recipient.id, eventKey: `sla:${item.kind}:${item.targetId}:${item.dueAt.toISOString()}` } },
            create: { userId: recipient.id, eventKey: `sla:${item.kind}:${item.targetId}:${item.dueAt.toISOString()}`, kind: item.domainKind === 'SUPPORT' ? 'SUPPORT_SLA' : 'MODERATION_SLA', title: 'Công việc đã quá hạn SLA', body: 'Cần xem xét và phân công xử lý ngay.', actionPath: item.domainKind === 'SUPPORT' ? `/admin/tickets?ticketId=${item.targetId}` : '/admin/moderation-v2' },
            update: {},
          });
        }
        await tx.auditLog.create({ data: { actorRole: 'ADMIN', action: 'system.sla_escalated', resourceType: item.kind, resourceId: item.targetId, summary: 'SLA deadline exceeded', metadata: { dueAt: item.dueAt.toISOString(), recipients: recipients.length } } });
      }
    }, { timeout: 20000 });
  }

  async acknowledge(actor: AuthUser, id: string, version: number, reason: string) {
    return this.prisma.$transaction(async tx => {
      const incident = await tx.operationsIncident.findUnique({ where: { id } });
      if (!incident) throw new NotFoundException();
      const changed = await tx.operationsIncident.updateMany({ where: { id, version, status: 'OPEN' }, data: { status: 'ACKNOWLEDGED', acknowledgedBy: actor.userId, version: { increment: 1 } } });
      if (!changed.count) throw new ConflictException('Sự cố đã thay đổi. Hãy tải lại.');
      await adminAudit(tx, actor, 'admin.incident_acknowledge', 'incident', id, reason);
      return { data: { acknowledged: true } };
    });
  }
}
