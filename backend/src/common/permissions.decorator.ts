import { SetMetadata } from '@nestjs/common';

import { PERMISSIONS_KEY, StaffPermission } from './permissions.constants';

export const RequirePermissions = (...permissions: StaffPermission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
