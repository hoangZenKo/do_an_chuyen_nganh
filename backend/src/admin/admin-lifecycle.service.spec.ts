import { ConflictException, ForbiddenException, NotFoundException, ServiceUnavailableException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AdminLifecycleService } from './admin-lifecycle.service';

describe('Admin lifecycle safety', () => {
  const actor = { userId: 'reviewer', email: 'masked@example.test', role: AuthRole.ADMIN };
  const reason = 'Security review with recorded evidence';
  function setup() {
    const target = { id: 'target', isActive: true, sessionVersion: 4 };
    let invitation = { createdAt: new Date(Date.now() - 120000), expiresAt: new Date(Date.now() - 60000), consumedAt: null as Date | null };
    const tx = {
      $queryRaw: jest.fn().mockResolvedValue([]),
      user: { findFirst: jest.fn().mockImplementation(async () => ({ ...target })), update: jest.fn().mockImplementation(async () => { target.sessionVersion++; return target; }) },
      authSession: { count: jest.fn().mockResolvedValue(2), findFirst: jest.fn().mockResolvedValue({ lastSeenAt: new Date() }), updateMany: jest.fn().mockResolvedValue({ count: 2 }) },
      refreshToken: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      accountAccessToken: { findFirst: jest.fn().mockImplementation(async () => invitation) },
      auditLog: { findFirst: jest.fn(), findMany: jest.fn().mockResolvedValue([]), create: jest.fn().mockResolvedValue({}) },
    };
    const access = { ready: jest.fn().mockReturnValue(true), enqueue: jest.fn().mockImplementation(async () => {
      invitation = { createdAt: new Date(), expiresAt: new Date(Date.now() + 1800000), consumedAt: null };
      return { queued: true, deliveryId: 'not-returned' };
    }) };
    const prisma = { $transaction: jest.fn(async (work: (client: typeof tx) => unknown) => work(tx)) };
    return { service: new AdminLifecycleService(prisma as never, access as never), tx, access, target, invitation };
  }

  it('resends an expired admin invite using the existing one-time token queue with before/after audit', async () => {
    const { service, tx, access } = setup();
    const response = await service.resend(actor, 'target', { version: 4, reason });
    expect(access.enqueue).toHaveBeenCalledWith(tx, 'target', 'INVITE');
    expect(response.data).toMatchObject({ queued: true, version: 5, invitation: { status: 'PENDING' } });
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ actorId: 'reviewer', action: 'admin.admin_invite_resent', summary: reason,
      metadata: { before: expect.objectContaining({ status: 'EXPIRED', version: 4 }), after: expect.objectContaining({ status: 'PENDING', version: 5 }) } }) });
    expect(JSON.stringify(response)).not.toMatch(/tokenHash|deliveryId|actionUrl|passwordHash/);
    await expect(service.resend(actor, 'target', { version: 4, reason })).rejects.toThrow(ConflictException);
    expect(access.enqueue).toHaveBeenCalledTimes(1);
  });

  it('applies a database-state cooldown, not only a per-process throttle', async () => {
    const { service, invitation, access } = setup();
    invitation.createdAt = new Date();
    await expect(service.resend(actor, 'target', { version: 4, reason })).rejects.toThrow(ConflictException);
    expect(access.enqueue).not.toHaveBeenCalled();
  });

  it('never mistakes invalidation for activation and blocks resends after actual redemption', async () => {
    const { service, invitation, tx, access } = setup();
    invitation.consumedAt = new Date();
    expect((await service.detail('target')).data.invitation.status).toBe('INVALIDATED');
    tx.auditLog.findFirst.mockResolvedValue({ createdAt: new Date() });
    expect((await service.detail('target')).data.invitation.status).toBe('ACTIVATED');
    await expect(service.resend(actor, 'target', { version: 4, reason })).rejects.toThrow(ConflictException);
    expect(access.enqueue).not.toHaveBeenCalled();
  });

  it('blocks self action, non-admin IDOR, inactive targets, and missing provider configuration', async () => {
    const { service, tx, target, access } = setup();
    await expect(service.revoke(actor, actor.userId, { version: 4, reason })).rejects.toThrow(ForbiddenException);
    expect(tx.$queryRaw).not.toHaveBeenCalled();
    tx.user.findFirst.mockResolvedValueOnce(null);
    await expect(service.detail('landlord-id')).rejects.toThrow(NotFoundException);
    expect(tx.user.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'landlord-id', role: 'ADMIN' } }));
    target.isActive = false;
    await expect(service.resend(actor, 'target', { version: 4, reason })).rejects.toThrow(ConflictException);
    access.ready.mockReturnValue(false);
    await expect(service.resend(actor, 'target', { version: 4, reason })).rejects.toThrow(ServiceUnavailableException);
  });

  it('revokes sessions and refresh tokens atomically with a versioned audit; rejects duplicate submit', async () => {
    const { service, tx } = setup();
    await expect(service.revoke(actor, 'target', { version: 4, reason })).resolves.toEqual({ data: { revoked: true, version: 5 } });
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({ where: { userId: 'target', revokedAt: null }, data: { revokedAt: expect.any(Date) } });
    expect(tx.refreshToken.updateMany).toHaveBeenCalled();
    expect(tx.auditLog.create).toHaveBeenCalledWith({ data: expect.objectContaining({ metadata: { before: { version: 4 }, after: { version: 5, activeSessions: 0 }, revokedSessions: 2 } }) });
    await expect(service.revoke(actor, 'target', { version: 4, reason })).rejects.toThrow(ConflictException);
    expect(tx.authSession.updateMany).toHaveBeenCalledTimes(1);
  });

  it('counts only active sessions for the current userVersion and keeps history bounded', async () => {
    const { service, tx, target } = setup();
    const response = await service.detail('target');
    expect(response.data.activeSessions).toBe(2);
    expect(tx.authSession.count).toHaveBeenCalledWith({ where: { userId: 'target', userVersion: 4, revokedAt: null, expiresAt: { gt: expect.any(Date) } } });
    expect(tx.auditLog.findMany).toHaveBeenCalledWith(expect.objectContaining({ take: 30 }));
    target.isActive = false;
    expect((await service.detail('target')).data.activeSessions).toBe(0);
  });

  it('fails the transaction when audit persistence fails instead of acknowledging a sensitive change', async () => {
    const { service, tx } = setup();
    tx.auditLog.create.mockRejectedValueOnce(new Error('audit unavailable'));
    await expect(service.revoke(actor, 'target', { version: 4, reason })).rejects.toThrow('audit unavailable');
  });
});
