import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { AuthRole } from './auth-role';
import { PERMISSIONS_KEY, StaffPermission } from './permissions.constants';
import { ROLES_KEY } from './roles.constants';
import { ADMIN_PERMISSIONS_KEY } from './admin-permissions';
import { adminAccess } from './admin-access';
import { AdminStepUpService } from '../auth/admin-step-up.service';
import { AuthUser } from './current-user.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector, @Optional() private readonly stepUp?: AdminStepUpService) {}

  canActivate(context: ExecutionContext): boolean | Promise<boolean> {
    const allowedRoles = this.reflector.getAllAndOverride<AuthRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!allowedRoles || allowedRoles.length === 0) return true;

    const request = context.switchToHttp().getRequest<{
      user?: AuthUser; method?: string; originalUrl?: string; body?: unknown; headers?: Record<string, string>;
    }>();
    if (!request.user?.role) throw new UnauthorizedException();
    if (!allowedRoles.includes(request.user.role)) {
      throw new ForbiddenException();
    }
    if (request.user.role === AuthRole.ADMIN) {
      if (request.user.adminMfaRequired && !request.user.adminMfaVerified) {
        throw new ForbiddenException({ error: { code: 'ADMIN_MFA_REQUIRED', message: 'Complete admin MFA before continuing.' } });
      }
      const required = this.reflector.getAllAndOverride<string[]>(ADMIN_PERMISSIONS_KEY, [context.getHandler(), context.getClass()]);
      if (!adminAccess(request.user.permissions ?? [], required ?? [], false, false).allowed) throw new ForbiddenException();
      if (this.stepUp?.required(request.method ?? '', request.originalUrl ?? '')) {
        return this.stepUp.consume(request.user, request.method!, request.originalUrl!, request.body, request.headers?.['x-admin-step-up']);
      }
    }
    const requiredPermissions = this.reflector.getAllAndOverride<StaffPermission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (
      request.user.role === AuthRole.STAFF &&
      requiredPermissions?.length
    ) {
      const granted = new Set(request.user.permissions ?? []);
      if (!requiredPermissions.some((permission) => granted.has(permission))) {
        throw new ForbiddenException();
      }
    }
    return true;
  }
}
