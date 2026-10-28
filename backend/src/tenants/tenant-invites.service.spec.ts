import { ConflictException, NotFoundException } from '@nestjs/common';

import { TenantInvitesService } from './tenant-invites.service';

describe('TenantInvitesService', () => {
  const prisma = {
    $queryRaw: jest.fn(),
    user: {
      findUnique: jest.fn(),
    },
    tenant: {
      findFirst: jest.fn(),
    },
    tenantInvite: {
      create: jest.fn(),
      findFirst: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
  } as any;
  prisma.$transaction = (operation: (tx: any) => unknown) => operation(prisma);
  const auth = {
    issueSession: jest.fn(),
  } as any;

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.tenantInvite.findFirst.mockResolvedValue(null);
    prisma.tenantInvite.count.mockResolvedValue(0);
  });

  it('creates a hashed activation invite for an active tenant', async () => {
    const expiresAt = new Date(Date.now() + 86_400_000);
    prisma.tenant.findFirst.mockResolvedValue({ id: 'tenant-1', userId: null });
    prisma.user.findUnique.mockResolvedValue(null);
    prisma.tenantInvite.create.mockResolvedValue({
      id: 'invite-1',
      email: 'tenant@example.com',
      expiresAt,
    });

    const service = new TenantInvitesService(prisma, auth);
    const result = await service.create('landlord-1', 'tenant-1', {
      email: ' TENANT@EXAMPLE.COM ',
    });

    expect(prisma.tenant.findFirst).toHaveBeenCalledWith({
      where: { id: 'tenant-1', landlordId: 'landlord-1', isActive: true },
      select: { id: true, userId: true },
    });
    expect(prisma.tenantInvite.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        landlordId: 'landlord-1',
        tenantId: 'tenant-1',
        email: 'tenant@example.com',
        tokenHash: expect.stringMatching(/^[a-f0-9]{64}$/),
        expiresAt: expect.any(Date),
      }),
    });
    expect(result.data.activationPath).toBe(
      `/tenant/activate?code=${result.data.inviteCode}`,
    );
  });

  it('rejects invite creation when the tenant is missing', async () => {
    prisma.tenant.findFirst.mockResolvedValue(null);

    const service = new TenantInvitesService(prisma, auth);
    await expect(
      service.create('landlord-1', 'tenant-1', { email: 'tenant@example.com' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('rejects invite creation when tenant already has an account', async () => {
    prisma.tenant.findFirst.mockResolvedValue({ id: 'tenant-1', userId: 'user-1' });

    const service = new TenantInvitesService(prisma, auth);
    await expect(
      service.create('landlord-1', 'tenant-1', { email: 'tenant@example.com' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects invite creation when the email is already registered', async () => {
    prisma.tenant.findFirst.mockResolvedValue({ id: 'tenant-1', userId: null });
    prisma.user.findUnique.mockResolvedValue({ id: 'user-1' });

    const service = new TenantInvitesService(prisma, auth);
    await expect(
      service.create('landlord-1', 'tenant-1', { email: 'tenant@example.com' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});
