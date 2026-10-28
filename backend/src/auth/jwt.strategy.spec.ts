import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { UserRole } from '@prisma/client';

import { AuthRole } from '../common/auth-role';
import { JwtStrategy } from './jwt.strategy';

describe('JwtStrategy', () => {
  const prisma = {
    user: {
      findUnique: jest.fn(),
    },
  } as any;
  const config = {
    getOrThrow: jest.fn(() => 'secret'),
  } as any as ConfigService;

  beforeEach(() => jest.clearAllMocks());

  it('maps an active landlord to a typed auth user', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u1',
      email: 'test@example.com',
      role: UserRole.LANDLORD,
      isActive: true,
    });
    const strategy = new JwtStrategy(config, prisma);

    await expect(strategy.validate({ sub: 'u1', typ: 'access' })).resolves.toEqual({
      userId: 'u1',
      email: 'test@example.com',
      role: AuthRole.LANDLORD,
    });
  });

  it('maps an active admin to a typed auth user', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'u2',
      email: 'admin@example.com',
      role: UserRole.ADMIN,
      isActive: true,
    });
    const strategy = new JwtStrategy(config, prisma);

    await expect(strategy.validate({ sub: 'u2', typ: 'access' })).resolves.toEqual({
      userId: 'u2',
      email: 'admin@example.com',
      role: AuthRole.ADMIN,
      permissions: [],
      adminMfaRequired: false,
      adminMfaVerified: false,
    });
  });

  it('rejects non-access tokens', async () => {
    const strategy = new JwtStrategy(config, prisma);
    await expect(strategy.validate({ sub: 'u1', typ: 'refresh' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });

  it('rejects missing or inactive users', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    const strategy = new JwtStrategy(config, prisma);
    await expect(strategy.validate({ sub: 'u1', typ: 'access' })).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
