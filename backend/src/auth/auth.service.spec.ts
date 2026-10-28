import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as argon2 from 'argon2';

import { AuthService } from './auth.service';

describe('AuthService', () => {
  const user = {
    id: 'user-1',
    fullName: 'Test User',
    email: 'test@example.com',
    phone: '+84901234567',
    passwordHash: 'hash',
    role: UserRole.LANDLORD,
    isActive: true,
    sessionVersion: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const prisma = {
    user: {
      create: jest.fn(),
      findUnique: jest.fn(),
      findUniqueOrThrow: jest.fn(),
      update: jest.fn(),
    },
    refreshToken: {
      create: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn(),
      update: jest.fn(),
    },
    authSession: { create: jest.fn() },
    $transaction: jest.fn(),
    $queryRaw: jest.fn(),
  } as any;
  const jwt = {
    signAsync: jest.fn().mockResolvedValue('access-token'),
    decode: jest.fn().mockReturnValue({ exp: Math.floor(Date.now() / 1000) + 900 }),
  } as any;
  const config = {
    get: jest.fn((key: string, fallback: string) =>
      key === 'REFRESH_TOKEN_TTL_DAYS' ? '30' : fallback,
    ),
  } as any;

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation((action: (tx: unknown) => unknown) => action(prisma));
    prisma.user.findUniqueOrThrow.mockImplementation(() => prisma.user.findUnique());
    prisma.user.findUnique.mockResolvedValue(user);
    prisma.$queryRaw.mockResolvedValue([{ id: user.id }]);
    prisma.authSession.create.mockResolvedValue({ id: 'session-1', expiresAt: new Date(Date.now() + 86_400_000) });
  });

  it('registers as a landlord and normalizes the email', async () => {
    prisma.user.create.mockResolvedValue(user);
    prisma.refreshToken.create.mockResolvedValue({
      id: 'refresh-1',
      expiresAt: new Date(Date.now() + 86_400_000),
    });

    const service = new AuthService(prisma, jwt, config);
    await service.register({
      fullName: ' Test User ',
      email: ' TEST@EXAMPLE.COM ',
      phone: ' +84901234567 ',
      password: 'StrongPassword!123',
    });

    expect(prisma.user.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '+84901234567',
        role: UserRole.LANDLORD,
      }),
    });
  });

  it('maps concurrent duplicate email errors to conflict', async () => {
    prisma.user.create.mockRejectedValue({
      name: 'PrismaClientKnownRequestError',
      code: 'P2002',
    });
    const service = new AuthService(prisma, jwt, config);
    await expect(
      service.register({
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '+84901234567',
        password: 'StrongPassword!123',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects inactive users at login', async () => {
    prisma.user.findUnique.mockResolvedValue({ ...user, isActive: false });
    const service = new AuthService(prisma, jwt, config);
    await expect(
      service.login({ email: 'test@example.com', password: 'StrongPassword!123' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('changes password after verifying the current password', async () => {
    const currentHash = await argon2.hash('CurrentPassword!123');
    prisma.user.findUnique.mockResolvedValue({ ...user, passwordHash: currentHash });
    prisma.user.update.mockResolvedValue(user);

    const service = new AuthService(prisma, jwt, config);
    await service.changePassword('user-1', {
      currentPassword: 'CurrentPassword!123',
      newPassword: 'NewPassword!123',
    });

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'user-1' },
      data: { passwordHash: expect.any(String), sessionVersion: { increment: 1 } },
    });
    expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith({ where: { userId: 'user-1', revokedAt: null }, data: { revokedAt: expect.any(Date) } });
  });
});
