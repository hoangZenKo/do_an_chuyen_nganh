import { SetMetadata, UseGuards, applyDecorators } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

import { AuthRole } from './auth-role';
import { ROLES_KEY } from './roles.constants';
import { RolesGuard } from './roles.guard';

export const Roles = (...roles: AuthRole[]) =>
  applyDecorators(SetMetadata(ROLES_KEY, roles), UseGuards(AuthGuard('jwt'), RolesGuard));
