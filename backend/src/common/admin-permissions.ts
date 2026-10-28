import { SetMetadata } from '@nestjs/common';

export const ADMIN_PERMISSIONS_KEY = 'admin:permissions';
export const ADMIN_PERMISSIONS = [
  'admin.dashboard.view', 'admin.accounts.view', 'admin.accounts.manage',
  'admin.accounts.suspend', 'admin.sessions.revoke', 'admin.properties.view',
  'admin.properties.manage', 'admin.support.read', 'admin.pii.reveal',
  'admin.listings.moderate', 'admin.reviews.moderate', 'admin.audit.view',
  'admin.campuses.manage', 'admin.admins.manage', 'admin.operations.view', 'admin.operations.manage', 'admin.audit.export',
  'admin.support.manage', 'admin.notifications.view', 'admin.moderation.appeals',
  'admin.moderation.bulk', 'admin.moderation.reports', 'admin.flags.manage',
  'admin.teams.manage', 'admin.permissions.simulate', 'admin.finance.read', 'admin.finance.reconcile', 'admin.reports.manage',
  'admin.verifications.view', 'admin.verifications.manage', 'admin.plans.view', 'admin.plans.manage',
] as const;
export type AdminPermission = typeof ADMIN_PERMISSIONS[number];
export const ADMIN_PRESETS: Record<string, readonly AdminPermission[]> = {
  super_admin: ADMIN_PERMISSIONS,
  support: ['admin.dashboard.view', 'admin.accounts.view', 'admin.properties.view', 'admin.support.read', 'admin.support.manage', 'admin.notifications.view'],
  moderator: ['admin.dashboard.view', 'admin.listings.moderate', 'admin.reviews.moderate', 'admin.campuses.manage', 'admin.moderation.appeals', 'admin.moderation.bulk', 'admin.moderation.reports', 'admin.notifications.view'],
  analyst: ['admin.dashboard.view', 'admin.moderation.reports', 'admin.finance.read', 'admin.reports.manage', 'admin.notifications.view'],
};
export const AdminPermissions = (...permissions: AdminPermission[]) =>
  SetMetadata(ADMIN_PERMISSIONS_KEY, permissions);

export function adminPermissionForWork(kind: string): AdminPermission {
  return kind === 'REVIEW' || kind === 'REPLY' ? 'admin.reviews.moderate' : 'admin.listings.moderate';
}
