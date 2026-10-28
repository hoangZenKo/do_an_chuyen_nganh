import { ConfigService } from '@nestjs/config';
import { BackupTelemetryService } from '../src/health/backup-telemetry.service';

export async function adminReleasePreflight(env: Record<string, string | undefined> = process.env) {
  const configured = (names: string[]) => names.every(name => !!env[name]?.trim());
  const checks = [
    { check: 'MFA', configured: env.ADMIN_MFA_REQUIRED === 'true' && Buffer.from(env.ADMIN_MFA_ENCRYPTION_KEY ?? '', 'base64').length === 32 },
    { check: 'STEP_UP', configured: env.ADMIN_STEP_UP_REQUIRED === 'true' },
    { check: 'ACCOUNT_DELIVERY', configured: configured(['AUTH_PUBLIC_APP_URL', 'AUTH_DELIVERY_WEBHOOK_URL', 'AUTH_DELIVERY_WEBHOOK_SECRET', 'DELIVERY_ENCRYPTION_KEY']) },
    { check: 'SCANNER', configured: configured(['SUPPORT_SCAN_WEBHOOK_URL', 'SUPPORT_SCAN_WEBHOOK_SECRET']) },
    { check: 'REPORT_STORAGE', configured: configured(['REPORT_STORAGE_URL', 'REPORT_STORAGE_SECRET']) },
    { check: 'ALERT_RECEIVER', configured: configured(['OPERATIONS_ALERT_WEBHOOK_URL', 'OPERATIONS_ALERT_WEBHOOK_SECRET']) },
    { check: 'BACKUP_RESTORE_TOOLCHAIN', configured: configured(['BACKUP_ENCRYPTION_KEY', 'BACKUP_OFFSITE_URL', 'BACKUP_OFFSITE_SECRET']) },
  ].map(check => ({ ...check, status: check.configured ? 'CONFIGURED_NOT_VERIFIED' : 'MISSING_CONFIGURATION' }));
  const backup = await new BackupTelemetryService(new ConfigService(env)).inspect();
  return { checkedAt: new Date().toISOString(), scope: 'read-only-configuration-and-signed-backup',
    status: checks.every(check => check.configured) && backup.status === 'OK' ? 'MANUAL_ACCEPTANCE_REQUIRED' : 'BLOCKED',
    productionAccepted: false, databaseAccessed: false, checks, backup,
    requiredEvidence: ['STAGING_SCHEMA_REHEARSAL', 'RESTORE_DRILL', 'REAL_MFA_REVOCATION', 'DELIVERY_SCANNER_REPORT_ROUNDTRIP', 'WORKER_RECOVERY_ALERT_RECEIPT', 'DEVICE_QA'],
    runbook: 'docs/admin-release-gate-runbook.md' };
}

if (require.main === module) {
  adminReleasePreflight().then(result => { console.log(JSON.stringify(result, null, 2)); process.exitCode = result.status === 'BLOCKED' ? 1 : 2; })
    .catch(() => { console.error('Admin preflight unavailable. No credentials or raw provider errors are logged.'); process.exitCode = 1; });
}
