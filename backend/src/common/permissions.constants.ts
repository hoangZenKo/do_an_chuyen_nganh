export const PERMISSIONS_KEY = 'permissions';

export const STAFF_PERMISSIONS = [
  'property.view',
  'property.manage',
  'room.view',
  'room.manage',
  'tenant.view',
  'tenant.manage',
  'lease.view',
  'lease.manage',
  'billing.view',
  'billing.create',
  'billing.record_payment',
  'billing.cancel',
  'billing.reverse_payment',
  'billing.approve_payment_proof',
  'billing.adjust',
  'billing.refund',
  'billing.policy',
  'billing.tariff_approve',
  'expense.view',
  'expense.manage',
  'maintenance.view',
  'maintenance.manage',
  'maintenance.complete',
  'report.view',
  'report.export',
  'staff.view',
  'staff.manage',
  'audit.view',
  'notification.view',
  'notification.manage',
  'operation.view',
  'operation.manage',
] as const;

export type StaffPermission = (typeof STAFF_PERMISSIONS)[number];

export const STAFF_PERMISSION_SET = new Set<string>(STAFF_PERMISSIONS);
