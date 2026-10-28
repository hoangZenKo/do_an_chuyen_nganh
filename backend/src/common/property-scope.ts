import { CallHandler, ExecutionContext, ForbiddenException, Injectable, NestInterceptor } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AsyncLocalStorage } from 'node:async_hooks';
import { Observable } from 'rxjs';
import { AuthRole } from './auth-role';
import { AuthUser } from './current-user.decorator';

export const propertyScopeContext = new AsyncLocalStorage<AuthUser>();

export function scopedPropertyIds() {
  const actor = propertyScopeContext.getStore();
  return actor?.role === AuthRole.STAFF ? actor.propertyIds ?? [] : undefined;
}

export function propertyWhere(landlordId: string): Prisma.PropertyWhereInput {
  const ids = scopedPropertyIds();
  return { landlordId, ...(ids ? { AND: [{ id: { in: ids } }] } : {}) };
}

export function propertyIdScope() {
  const ids = scopedPropertyIds();
  return ids ? { AND: [{ propertyId: { in: ids } }] } : {};
}

export function tenantScope(): Prisma.TenantWhereInput {
  const ids = scopedPropertyIds();
  if (!ids) return {};
  const room = { propertyId: { in: ids } };
  return { AND: [
    { leases: { some: { room } } },
    { leases: { every: { room } } },
    { invoices: { every: { room } } },
  ] };
}

const scopedControllers = new Set([
  'PropertiesController', 'PropertyRoomsController', 'RoomsController',
  'TenantsController', 'LeasesController', 'RoomLeasesController', 'TenantLeasesController',
  'BillingController', 'ExpensesController', 'MaintenanceController',
  'ReportsController', 'DashboardController', 'TenantLifecycleController',
]);

@Injectable()
export class PropertyScopeInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<{ user?: AuthUser; body?: Record<string, unknown>; query?: Record<string, unknown> }>();
    const actor = request.user;
    if (actor?.role !== AuthRole.STAFF) return next.handle();
    const controller = context.getClass().name;
    const handler = context.getHandler().name;
    const denied = () => { throw new ForbiddenException({ error: { code: 'STAFF_PROPERTY_SCOPE_REQUIRED', message: 'This action requires landlord access or a property-scoped workflow.' } }); };
    if (controller === 'AuthController') return next.handle();
    if (controller === 'StaffController') {
      if (!['list', 'presets'].includes(handler)) denied();
    } else if (!scopedControllers.has(controller)) denied();
    if (controller === 'PropertiesController' && handler === 'create') denied();
    if (controller === 'MaintenanceController' && handler === 'escalate') denied();
    if (controller === 'BillingController') {
      if (['outboxEvents', 'retryOutbox'].includes(handler)) denied();
      if (['runReminders', 'enqueueReminders', 'reminderPolicy', 'updateReminderPolicy'].includes(handler)) {
        const id = request.body?.propertyId ?? request.query?.propertyId;
        if (typeof id !== 'string' || !actor.propertyIds?.includes(id)) denied();
      }
    }
    return new Observable((subscriber) => propertyScopeContext.run(actor, () => next.handle().subscribe(subscriber)));
  }
}
