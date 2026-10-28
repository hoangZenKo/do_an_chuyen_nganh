import { createHash } from 'node:crypto';
import { AdminPermission } from '../common/admin-permissions';

export const SENSITIVE_ADMIN_ACTIONS: { action: string; method: string; path: RegExp; permissions: AdminPermission[] }[] = [
  { action: 'verification.review', method: 'POST', path: /^\/admin\/landlord-verifications\/[^/]+\/review$/, permissions: ['admin.verifications.manage', 'admin.support.read'] },
  { action: 'property.review', method: 'POST', path: /^\/admin\/property-reviews\/[^/]+\/review$/, permissions: ['admin.properties.manage'] },
  { action: 'plan.save', method: 'POST', path: /^\/admin\/service-plans$/, permissions: ['admin.plans.manage'] },
  { action: 'subscription.assign', method: 'POST', path: /^\/admin\/landlords\/[^/]+\/subscription$/, permissions: ['admin.plans.manage'] },
  { action: 'subscription.cancel', method: 'POST', path: /^\/admin\/subscriptions\/[^/]+\/cancel$/, permissions: ['admin.plans.manage'] },
  { action: 'pii.reveal', method: 'POST', path: /^\/admin\/accounts\/[^/]+\/reveal$/, permissions: ['admin.pii.reveal'] },
  { action: 'account.suspend', method: 'POST', path: /^\/admin\/accounts\/[^/]+\/suspend$/, permissions: ['admin.accounts.suspend'] },
  { action: 'landlord.status', method: 'PATCH', path: /^\/admin\/landlords\/[^/]+\/status$/, permissions: ['admin.accounts.suspend'] },
  { action: 'audit.export', method: 'POST', path: /^\/admin\/audit-logs\/export$/, permissions: ['admin.audit.view', 'admin.audit.export'] },
  { action: 'moderation.bulk', method: 'POST', path: /^\/admin\/moderation-v2\/bulk$/, permissions: ['admin.moderation.bulk'] },
  { action: 'access.review', method: 'POST', path: /^\/admin\/access-reviews\/[^/]+$/, permissions: ['admin.admins.manage'] },
  { action: 'admin.invite.resend', method: 'POST', path: /^\/admin\/admins\/[^/]+\/resend-invite$/, permissions: ['admin.admins.manage'] },
  { action: 'admin.sessions.revoke', method: 'POST', path: /^\/admin\/admins\/[^/]+\/revoke-sessions$/, permissions: ['admin.admins.manage', 'admin.sessions.revoke'] },
];

export function adminRequestPath(path: string) {
  let pathname = path.split('?')[0];
  try { pathname = decodeURIComponent(pathname); } catch { return ''; }
  return pathname.toLowerCase().replace(/^\/api\/v1(?=\/)/, '').replace(/\/$/, '');
}

export function sensitiveAdminAction(method: string, path: string) {
  return SENSITIVE_ADMIN_ACTIONS.find(rule => rule.method === method.toUpperCase() && rule.path.test(adminRequestPath(path)));
}

function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonicalJson((value as Record<string, unknown>)[key])}`).join(',')}}`;
  return JSON.stringify(value) ?? 'null';
}

export function adminRequestFingerprint(method: string, path: string, payload: unknown) {
  return createHash('sha256').update(`${method.toUpperCase()}\n${adminRequestPath(path)}\n${canonicalJson(payload ?? {})}`).digest('hex');
}
