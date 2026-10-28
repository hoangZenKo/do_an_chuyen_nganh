import { createParamDecorator, ExecutionContext } from '@nestjs/common';

import { AuthRole } from './auth-role';

export interface AuthUser {
  userId: string;
  email: string;
  role: AuthRole;
  sessionId?: string;
  landlordId?: string;
  permissions?: string[];
  propertyIds?: string[];
  adminMfaVerified?: boolean;
  adminMfaRequired?: boolean;
}

export function landlordScopeId(user: AuthUser) {
  return user.landlordId ?? user.userId;
}

export function propertyScopeIds(user: AuthUser): string[] | undefined {
  return user.role === AuthRole.STAFF ? user.propertyIds ?? [] : undefined;
}

/**
 * Extracts the authenticated user populated by JwtStrategy.validate().
 * Only available on routes protected by AuthGuard('jwt').
 */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser => {
    const request = ctx.switchToHttp().getRequest<{ user: AuthUser }>();
    return request.user;
  },
);
