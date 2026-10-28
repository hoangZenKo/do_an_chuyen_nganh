import 'reflect-metadata';

import { GUARDS_METADATA } from '@nestjs/common/constants';

import { AuthRole } from './auth-role';
import { ROLES_KEY } from './roles.constants';
import { RolesGuard } from './roles.guard';
import { BillingController } from '../billing/billing.controller';
import { DashboardController } from '../dashboard/dashboard.controller';
import {
  LeasesController,
  RoomLeasesController,
  TenantLeasesController,
} from '../leases/leases.controller';
import { PropertiesController } from '../properties/properties.controller';
import { PropertyRoomsController, RoomsController } from '../rooms/rooms.controller';
import { TenantsController } from '../tenants/tenants.controller';

describe('landlord resource authorization metadata', () => {
  const controllers = [
    DashboardController,
    PropertiesController,
    PropertyRoomsController,
    RoomsController,
    TenantsController,
    LeasesController,
    RoomLeasesController,
    TenantLeasesController,
    BillingController,
  ];

  for (const controller of controllers) {
    it(`${controller.name} declares landlord/staff roles`, () => {
      expect(Reflect.getMetadata(ROLES_KEY, controller)).toEqual([
        AuthRole.LANDLORD,
        AuthRole.STAFF,
      ]);
    });
  }

  it('Roles decorator composes JWT auth and role guard semantics', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, PropertiesController) as unknown[];

    expect(Reflect.getMetadata(ROLES_KEY, PropertiesController)).toEqual([
      AuthRole.LANDLORD,
      AuthRole.STAFF,
    ]);
    expect(guards).toEqual(expect.arrayContaining([expect.any(Function), RolesGuard]));
    expect(String(guards[0])).toContain('AuthGuard');
  });
});
