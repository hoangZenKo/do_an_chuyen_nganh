import { UserRole } from '@prisma/client';

import { AuthRole, toAuthRole } from './auth-role';

describe('toAuthRole', () => {
  it('maps landlord to lowercase wire role', () => {
    expect(toAuthRole(UserRole.LANDLORD)).toBe(AuthRole.LANDLORD);
  });

  it('maps admin to lowercase wire role', () => {
    expect(toAuthRole(UserRole.ADMIN)).toBe(AuthRole.ADMIN);
  });
});
