import { UserRole } from '@prisma/client';

export enum AuthRole {
  LANDLORD = 'landlord',
  ADMIN = 'admin',
  TENANT = 'tenant',
  STAFF = 'staff',
}

export function toAuthRole(role: UserRole): AuthRole {
  switch (role) {
    case UserRole.LANDLORD:
      return AuthRole.LANDLORD;
    case UserRole.ADMIN:
      return AuthRole.ADMIN;
    case UserRole.TENANT:
      return AuthRole.TENANT;
    case UserRole.STAFF:
      return AuthRole.STAFF;
    default:
      throw new Error(`Unsupported user role: ${role}`);
  }
}
