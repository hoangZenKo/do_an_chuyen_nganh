import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AuthRole } from './auth-role';
import { ROLES_KEY } from './roles.constants';
import { RolesGuard } from './roles.guard';
import { ADMIN_PERMISSIONS_KEY } from './admin-permissions';

describe('RolesGuard', () => {
  const reflector = {
    getAllAndOverride: jest.fn(),
  } as unknown as Reflector;
  const guard = new RolesGuard(reflector);

  const handler = () => undefined;
  class Controller {}

  const context = (user?: { role?: AuthRole; permissions?: string[]; adminMfaRequired?: boolean; adminMfaVerified?: boolean }) =>
    ({
      getHandler: () => handler,
      getClass: () => Controller,
      switchToHttp: () => ({ getRequest: () => ({ user }) }),
    }) as any;

  beforeEach(() => jest.clearAllMocks());

  it('allows access when no roles metadata is present', () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue(undefined);
    expect(guard.canActivate(context())).toBe(true);
  });

  it('allows landlord users on landlord-only routes', () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue([AuthRole.LANDLORD]);
    expect(guard.canActivate(context({ role: AuthRole.LANDLORD }))).toBe(true);
  });

  it('rejects admin users on landlord-only routes', () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue([AuthRole.LANDLORD]);
    expect(() => guard.canActivate(context({ role: AuthRole.ADMIN }))).toThrow(
      ForbiddenException,
    );
  });

  it('rejects missing authenticated users', () => {
    (reflector.getAllAndOverride as jest.Mock).mockReturnValue([AuthRole.LANDLORD]);
    expect(() => guard.canActivate(context())).toThrow(UnauthorizedException);
  });

  it('passes handler and class targets to metadata lookup', () => {
    (reflector.getAllAndOverride as jest.Mock).mockImplementation((key) => key === ROLES_KEY ? [AuthRole.ADMIN] : key === ADMIN_PERMISSIONS_KEY ? ['admin.dashboard.view'] : undefined);

    expect(guard.canActivate(context({ role: AuthRole.ADMIN, permissions: ['admin.dashboard.view'] }))).toBe(true);
    expect(reflector.getAllAndOverride).toHaveBeenCalledWith(ROLES_KEY, [
      handler,
      Controller,
    ]);
  });

  it('denies admin without capability metadata or explicit permission', () => {
    (reflector.getAllAndOverride as jest.Mock).mockImplementation(key => key === ROLES_KEY ? [AuthRole.ADMIN] : undefined);
    expect(() => guard.canActivate(context({ role: AuthRole.ADMIN, permissions: ['admin.dashboard.view'] }))).toThrow(ForbiddenException);
    (reflector.getAllAndOverride as jest.Mock).mockImplementation(key => key === ROLES_KEY ? [AuthRole.ADMIN] : ['admin.audit.view']);
    expect(() => guard.canActivate(context({ role: AuthRole.ADMIN, permissions: ['admin.dashboard.view'] }))).toThrow(ForbiddenException);
  });

  it('requires an MFA-verified session when MFA is required', () => {
    (reflector.getAllAndOverride as jest.Mock).mockImplementation(key => key === ROLES_KEY ? [AuthRole.ADMIN] : ['admin.dashboard.view']);
    expect(() => guard.canActivate(context({ role: AuthRole.ADMIN, permissions: ['admin.dashboard.view'], adminMfaRequired: true, adminMfaVerified: false }))).toThrow(ForbiddenException);
  });
});
