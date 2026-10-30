import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { readFile } from 'node:fs/promises';
import { AuthRole } from '../common/auth-role';
import { UploadsService } from './uploads.service';

jest.mock('node:fs/promises', () => ({ readFile: jest.fn() }));

describe('Support attachment release authorization', () => {
  const user = { userId: 'admin', email: 'masked@example.test', role: AuthRole.ADMIN, sessionId: 'session', permissions: ['admin.support.read'] };
  function setup() {
    const current = { id: 'admin', email: user.email, role: 'ADMIN', isActive: true, sessionVersion: 2, adminProfile: { permissions: ['admin.support.read'] } };
    const prisma = {
      uploadedFile: { findUnique: jest.fn().mockResolvedValue({ purpose: 'SUPPORT_CLEAN', ownerId: 'requester' }) },
      supportAttachment: { findFirst: jest.fn().mockImplementation(async (query: { where: { internal?: boolean } }) => query.where.internal === false ? null : { filename: 'case.pdf' }) },
      user: { findUniqueOrThrow: jest.fn().mockImplementation(async () => current) },
      authSession: { findFirst: jest.fn().mockResolvedValue({ id: 'session' }) },
    };
    (readFile as jest.Mock).mockResolvedValue(Buffer.from('%PDF-1.4 mock'));
    const config = { get: jest.fn(), getOrThrow: jest.fn().mockReturnValue('test-only-signing-secret') };
    return { service: new UploadsService(prisma as never, config as unknown as ConfigService), prisma, current };
  }

  it('requires support capability for internal notes, regardless of uploaded-file ownership', async () => {
    const { service, prisma } = setup();
    expect(await service.canRead(user, 'case.pdf')).toBe(true);
    expect(await service.canRead({ ...user, permissions: [] }, 'case.pdf')).toBe(false);
    expect(await service.canRead({ ...user, userId: 'requester', role: AuthRole.TENANT, permissions: [] }, 'case.pdf')).toBe(false);
    expect(prisma.supportAttachment.findFirst).toHaveBeenLastCalledWith({ where: { filename: 'case.pdf', internal: false, ticket: { requesterId: 'requester' } } });
  });

  it('checks requester ownership for non-internal attachments instead of trusting a filename', async () => {
    const { service, prisma } = setup();
    prisma.supportAttachment.findFirst.mockImplementation(async query => query.where.internal === false && (query.where as { ticket?: { requesterId: string } }).ticket?.requesterId === 'owner' ? { filename: 'case.pdf' } : null);
    expect(await service.canRead({ ...user, userId: 'owner', role: AuthRole.TENANT, permissions: [] }, 'case.pdf')).toBe(true);
    await expect(service.access({ ...user, userId: 'other', role: AuthRole.TENANT, permissions: [] }, 'case.pdf')).rejects.toThrow(NotFoundException);
  });

  it('binds new URLs to session and rechecks live permission and userVersion before reading bytes', async () => {
    const { service, prisma, current } = setup();
    const link = await service.access(user, 'case.pdf');
    const token = new URL(link.data.url, 'https://example.test').searchParams.get('access')!;
    await expect(service.read('case.pdf', token)).resolves.toMatchObject({ mime: 'application/pdf' });
    expect(prisma.authSession.findFirst).toHaveBeenCalledWith({ where: { id: 'session', userId: 'admin', userVersion: 2, revokedAt: null, expiresAt: { gt: expect.any(Date) } }, select: { id: true } });
    prisma.authSession.findFirst.mockResolvedValue(null);
    await expect(service.read('case.pdf', token)).rejects.toThrow(NotFoundException);
    prisma.authSession.findFirst.mockResolvedValue({ id: 'session' });
    current.adminProfile.permissions = [];
    await expect(service.read('case.pdf', token)).rejects.toThrow(NotFoundException);
    current.adminProfile.permissions = ['admin.support.read'];
    current.sessionVersion++;
    await expect(service.read('case.pdf', token)).rejects.toThrow(NotFoundException);
    await expect(service.read('different.pdf', token)).rejects.toThrow(NotFoundException);
    await expect(service.read('case.pdf', `${token}tamper`)).rejects.toThrow(NotFoundException);
  });
});
