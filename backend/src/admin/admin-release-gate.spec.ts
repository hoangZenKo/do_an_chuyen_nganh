import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { resolve } from 'node:path';
import { ADMIN_PERMISSIONS, ADMIN_PERMISSIONS_KEY } from '../common/admin-permissions';
import { AuthRole } from '../common/auth-role';
import { ROLES_KEY } from '../common/roles.constants';
import { RolesGuard } from '../common/roles.guard';
import { adminRouteInventory } from './admin-route-inventory';
import { AdminSecurityController } from '../auth/admin-security.controller';

describe('discovered admin release permission matrix', () => {
  const routes = adminRouteInventory(resolve(__dirname, '..'));
  const guard = new RolesGuard(new Reflector());

  function context(route: typeof routes[number], role: AuthRole, permissions: string[]) {
    const controller = class {};
    const handler = () => undefined;
    Reflect.defineMetadata(ROLES_KEY, route.roles, controller);
    Reflect.defineMetadata(ADMIN_PERMISSIONS_KEY, route.permissions, handler);
    return { getClass: () => controller, getHandler: () => handler,
      switchToHttp: () => ({ getRequest: () => ({ user: { role, permissions } }) }) } as unknown as ExecutionContext;
  }

  it('discovers the lifecycle and operations surfaces rather than a fixed controller allowlist', () => {
    expect(routes.length).toBeGreaterThan(100);
    expect(routes.some(route => route.path === '/admin/admins/:id/resend-invite')).toBe(true);
    expect(routes.some(route => route.path === '/admin/operations/delivery-jobs')).toBe(true);
  });

  for (const route of routes) {
    if (route.controller === 'AdminSecurityController') {
      it(`${route.method} ${route.path} preserves the self-enrollment role/profile gate without an MFA circular dependency`, async () => {
        expect(['/admin/me/security', '/admin/me/security/enroll', '/admin/me/security/confirm']).toContain(route.path);
        const prisma = { adminProfile: { findUnique: jest.fn().mockResolvedValue({ mfaEnabled: false }) } };
        const mfa = { required: jest.fn().mockReturnValue(true), enroll: jest.fn(), verify: jest.fn() };
        const controller = new AdminSecurityController(mfa as never, prisma as never);
        const method = controller[route.handler as 'status' | 'enroll' | 'confirm'].bind(controller);
        for (const role of [AuthRole.STAFF, AuthRole.LANDLORD, AuthRole.TENANT]) {
          await expect(method({ userId: 'actor', email: 'masked@example.test', role }, { code: '123456' })).rejects.toThrow(ForbiddenException);
        }
        expect(prisma.adminProfile.findUnique).not.toHaveBeenCalled();
        await method({ userId: 'actor', email: 'masked@example.test', role: AuthRole.ADMIN }, { code: '123456' });
        expect(prisma.adminProfile.findUnique).toHaveBeenCalledWith({ where: { userId: 'actor' } });
        prisma.adminProfile.findUnique.mockResolvedValue(null);
        await expect(method({ userId: 'actor', email: 'masked@example.test', role: AuthRole.ADMIN }, { code: '123456' })).rejects.toThrow(ForbiddenException);
      });
      continue;
    }
    it(`${route.method} ${route.path} is fail-closed for admin capability revocation`, () => {
      expect(route.roles).toContain(AuthRole.ADMIN);
      expect(route.permissions.length).toBeGreaterThan(0);
      for (const permission of route.permissions) expect(ADMIN_PERMISSIONS).toContain(permission);
      expect(guard.canActivate(context(route, AuthRole.ADMIN, [...route.permissions]))).toBe(true);
      for (const revoked of route.permissions) {
        expect(() => guard.canActivate(context(route, AuthRole.ADMIN, route.permissions.filter(permission => permission !== revoked)))).toThrow(ForbiddenException);
      }
      for (const role of [AuthRole.STAFF, AuthRole.LANDLORD, AuthRole.TENANT]) {
        if (!route.roles.includes(role)) expect(() => guard.canActivate(context(route, role, [...ADMIN_PERMISSIONS]))).toThrow(ForbiddenException);
      }
    });
  }
});
