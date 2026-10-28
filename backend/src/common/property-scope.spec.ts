import { ForbiddenException } from '@nestjs/common';
import { firstValueFrom, of } from 'rxjs';
import { AuthRole } from './auth-role';
import { AuthUser } from './current-user.decorator';
import { PropertyScopeInterceptor, propertyIdScope, propertyScopeContext, propertyWhere, scopedPropertyIds, tenantScope } from './property-scope';

describe('Staff property authorization context', () => {
  const staff: AuthUser = { userId: 'staff', landlordId: 'owner', role: AuthRole.STAFF, email: 'staff@example.test', propertyIds: ['allowed'] };

  it('is fail-closed for missing staff scopes but does not limit landlord/worker queries', () => {
    expect(propertyWhere('owner')).toEqual({ landlordId: 'owner' });
    expect(tenantScope()).toEqual({});
    propertyScopeContext.run({ ...staff, propertyIds: undefined }, () => {
      expect(propertyWhere('owner')).toEqual({ landlordId: 'owner', AND: [{ id: { in: [] } }] });
      expect(propertyIdScope()).toEqual({ AND: [{ propertyId: { in: [] } }] });
    });
    expect(scopedPropertyIds()).toBeUndefined();
  });

  it('requires an assigned lease and denies tenants whose history spans unassigned properties', () => {
    propertyScopeContext.run(staff, () => expect(tenantScope()).toEqual({ AND: [
      { leases: { some: { room: { propertyId: { in: ['allowed'] } } } } },
      { leases: { every: { room: { propertyId: { in: ['allowed'] } } } } },
      { invoices: { every: { room: { propertyId: { in: ['allowed'] } } } } },
    ] }));
  });

  it('preserves scope through Observable subscription and asynchronous database calls without leaking across requests', async () => {
    class BillingController {}
    const interceptor = new PropertyScopeInterceptor();
    const context = { getClass: () => BillingController, getHandler: () => function invoices() {}, switchToHttp: () => ({ getRequest: () => ({ user: staff }) }) } as any;
    const source = interceptor.intercept(context, { handle: () => of(propertyWhere('owner')) });
    await expect(firstValueFrom(source)).resolves.toEqual({ landlordId: 'owner', AND: [{ id: { in: ['allowed'] } }] });
    const values = await Promise.all(['first', 'second'].map((propertyId) => propertyScopeContext.run({ ...staff, propertyIds: [propertyId] }, async () => { await Promise.resolve(); return scopedPropertyIds(); })));
    expect(values).toEqual([['first'], ['second']]);
    expect(scopedPropertyIds()).toBeUndefined();
  });

  it('denies unconverted modules, global reminder mutations, staff administration and property creation', () => {
    const interceptor = new PropertyScopeInterceptor();
    const context = (controllerName: string, handlerName: string, body = {}) => ({ getClass: () => ({ name: controllerName }), getHandler: () => ({ name: handlerName }), switchToHttp: () => ({ getRequest: () => ({ user: staff, body }) }) }) as any;
    for (const [controller, handler] of [['OperationsController', 'list'], ['StaffController', 'update'], ['BillingController', 'updateReminderPolicy'], ['BillingController', 'outboxEvents'], ['PropertiesController', 'create']]) {
      expect(() => interceptor.intercept(context(controller, handler), { handle: () => of(null) })).toThrow(ForbiddenException);
    }
    expect(() => interceptor.intercept(context('BillingController', 'updateReminderPolicy', { propertyId: 'allowed' }), { handle: () => of(null) })).not.toThrow();
  });
});
