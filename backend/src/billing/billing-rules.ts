import { BadRequestException, ConflictException } from '@nestjs/common';
import { createHash } from 'node:crypto';

export const MAX_MONEY = 2147483647;

export function billingError(code: string, message: string, conflict = false): never {
  const error = { error: { code, message } };
  throw conflict ? new ConflictException(error) : new BadRequestException(error);
}

export function money(value: number, allowZero = false) {
  if (!Number.isSafeInteger(value) || value < (allowZero ? 0 : 1) || value > MAX_MONEY) {
    billingError('INVALID_BILLING_AMOUNT', 'Amount must be an integer within the supported range.');
  }
  return value;
}

export function requiredReason(value: string) {
  if (!value?.trim()) billingError('BILLING_REASON_REQUIRED', 'A reason is required.');
  return value.trim();
}

export function businessDay(now = new Date()) {
  return new Date(now.getTime() + 7 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

export function dueDays(dueDate: Date, now = new Date()) {
  const due = dueDate.toISOString().slice(0, 10);
  return Math.round((Date.parse(businessDay(now)) - Date.parse(due)) / 86400000);
}

export function agingBucket(dueDate: Date | null, now = new Date()) {
  if (!dueDate) return 'undated' as const;
  const days = dueDays(dueDate, now);
  if (days <= 0) return 'notDue' as const;
  if (days <= 7) return 'overdue1To7' as const;
  if (days <= 30) return 'overdue8To30' as const;
  return 'overdueOver30' as const;
}

export function balanceStatus(paid: number, total: number) {
  if (paid >= total) return 'PAID' as const;
  return paid > 0 ? 'PARTIAL' as const : 'UNPAID' as const;
}

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== undefined).sort(([left], [right]) => left.localeCompare(right)).map(([key, entry]) => [key, canonical(entry)]));
  }
  return value;
}

export function commandHash(value: unknown) {
  return createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}
