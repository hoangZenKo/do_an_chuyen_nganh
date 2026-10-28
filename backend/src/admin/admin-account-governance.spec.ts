import { BadRequestException, ConflictException, ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { ADMIN_PRESETS, AdminPermission } from '../common/admin-permissions';
import { AdminConsoleService } from './admin-console.service';

describe('Existing administrator governance and customer recovery contracts', () => {
  const actor: AuthUser = { userId: 'operator', role: AuthRole.ADMIN, email: 'operator@example.test', permissions: [...ADMIN_PRESETS.super_admin] };
  const input = { preset: 'support', isActive: false, version: 7, mfaCode: '123456', reason: 'Verified access review request' };
  let tx: any;
  let access: { enqueue: jest.Mock; ready: jest.Mock };
  let mfa: { verify: jest.Mock };
  let service: AdminConsoleService;

  beforeEach(() => {
    tx = { $queryRaw: jest.fn().mockResolvedValue([]),
      user: { findFirst: jest.fn().mockResolvedValue({ id: 'target', role: 'ADMIN', isActive: true,
        sessionVersion: 7, adminProfile: { preset: 'super_admin', permissions: [...ADMIN_PRESETS.super_admin] } }),
        count: jest.fn().mockResolvedValue(1), update: jest.fn() },
      adminProfile: { update: jest.fn() }, refreshToken: { updateMany: jest.fn() },
      authSession: { updateMany: jest.fn() }, accountAccessToken: { updateMany: jest.fn() },
      deliveryJob: { updateMany: jest.fn() }, auditLog: { create: jest.fn() } };
    access = { ready: jest.fn().mockReturnValue(false), enqueue: jest.fn().mockResolvedValue({ queued: true }) };
    mfa = { verify: jest.fn().mockResolvedValue(undefined) };
    const prisma = { ...tx, $transaction: jest.fn(async operation => operation(tx)) };
    service = new AdminConsoleService(prisma as any, access as any, mfa as any);
  });

  it('blocks self role changes, stale versions and removing the last super admin', async () => {
    await expect(service.updateAdmin(actor, 'operator', input)).rejects.toThrow(ForbiddenException);
    await expect(service.updateAdmin(actor, 'target', { ...input, version: 6 })).rejects.toThrow(ConflictException);
    tx.user.count.mockResolvedValue(0);
    await expect(service.updateAdmin(actor, 'target', input)).rejects.toThrow(ConflictException);
    expect(tx.adminProfile.update).not.toHaveBeenCalled();
  });

  it('does not change permissions or sessions when MFA fails', async () => {
    mfa.verify.mockRejectedValue(new ForbiddenException());
    await expect(service.updateAdmin(actor, 'target', input)).rejects.toThrow(ForbiddenException);
    expect(tx.$queryRaw).not.toHaveBeenCalled();
    expect(tx.authSession.updateMany).not.toHaveBeenCalled();
  });

  it('deactivation revokes sessions, cancels pending deliveries and audits before/after', async () => {
    await expect(service.updateAdmin(actor, 'target', input)).resolves.toEqual({ data: { updated: true } });
    expect(mfa.verify).toHaveBeenCalledWith(actor.userId, '123456');
    expect(tx.authSession.updateMany).toHaveBeenCalledWith({ where: { userId: 'target', revokedAt: null }, data: { revokedAt: expect.any(Date) } });
    expect(tx.deliveryJob.updateMany).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'CANCELLED', payload: null }) }));
    expect(tx.auditLog.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ action: 'admin.profile_update',
      metadata: { before: { preset: 'super_admin', permissions: [...ADMIN_PRESETS.super_admin], isActive: true, version: 7 },
        after: { preset: 'support', permissions: [...ADMIN_PRESETS.support], isActive: false, version: 8 } } }) }));
  });

  it('password recovery only returns queue acceptance, never a password or token', async () => {
    await expect(service.reset(actor, 'customer', 'Verified support request')).resolves.toEqual({ data: { queued: true } });
    expect(access.enqueue).toHaveBeenCalledWith(tx, 'customer', 'PASSWORD_RESET');
    expect(tx.auditLog.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ action: 'admin.account_reset_requested' }) }));
  });

  it('a missing delivery provider cannot report a reset or invitation as queued', async () => {
    access.enqueue.mockRejectedValue(new ServiceUnavailableException());
    await expect(service.reset(actor, 'customer', 'Verified support request')).rejects.toThrow(ServiceUnavailableException);
    expect(tx.auditLog.create).not.toHaveBeenCalled();
    await expect(service.invite(actor, { fullName: 'New customer', email: 'new@example.test', role: 'LANDLORD', reason: 'Verified support request' })).rejects.toThrow(ServiceUnavailableException);
  });

  describe('explicit capability grants', () => {
    const root = { ...actor, permissions: [...ADMIN_PRESETS.super_admin] };
    const permissions: AdminPermission[] = [...ADMIN_PRESETS.support, 'admin.plans.view', 'admin.verifications.view'];
    const change = () => ({ ...input, isActive: true, permissions });

    beforeEach(() => {
      tx.adminProfile.findUnique = jest.fn().mockResolvedValue({ preset: 'super_admin',
        permissions: [...ADMIN_PRESETS.super_admin], user: { role: 'ADMIN', isActive: true } });
      tx.user.findFirst.mockResolvedValue({ id: 'target', role: 'ADMIN', isActive: true, sessionVersion: 7,
        adminProfile: { preset: 'support', permissions: [...ADMIN_PRESETS.support] } });
    });

    it('persists only explicitly chosen grants and revokes sessions in the audit transaction', async () => {
      await service.updateAdmin(root, 'target', change());
      expect(tx.adminProfile.update).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ permissions, accessReviewedAt: null, reviewVersion: { increment: 1 } }),
      }));
      expect(tx.authSession.updateMany).toHaveBeenCalled();
      expect(tx.refreshToken.updateMany).toHaveBeenCalled();
      expect(tx.auditLog.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({
        metadata: expect.objectContaining({ after: { preset: 'support', permissions, isActive: true, version: 8 } }),
      }) }));
    });

    it.each([
      [], ['admin.plans.view'], ['admin.dashboard.view', 'admin.unknown'],
      ['admin.dashboard.view', 'admin.dashboard.view'], null,
    ])('rejects malformed or dashboard-less grants: %j', async invalid => {
      await expect(service.updateAdmin(root, 'target', { ...change(), permissions: invalid } as any)).rejects.toThrow(BadRequestException);
      expect(tx.adminProfile.update).not.toHaveBeenCalled();
      expect(tx.authSession.updateMany).not.toHaveBeenCalled();
    });

    it('requires a live active super-admin profile and cannot delegate a missing permission', async () => {
      for (const profile of [null, { preset: 'support', user: { role: 'ADMIN', isActive: true } },
        { preset: 'super_admin', user: { role: 'ADMIN', isActive: false } }]) {
        tx.adminProfile.findUnique.mockResolvedValue(profile);
        await expect(service.updateAdmin(root, 'target', change())).rejects.toThrow(ForbiddenException);
      }
      tx.adminProfile.findUnique.mockResolvedValue({ preset: 'super_admin', permissions: [...ADMIN_PRESETS.support], user: { role: 'ADMIN', isActive: true } });
      await expect(service.updateAdmin(root, 'target', change())).rejects.toThrow(ForbiddenException);
      expect(tx.adminProfile.update).not.toHaveBeenCalled();
    });

    it('does not allow an incomplete super-admin preset even when another super admin exists', async () => {
      await expect(service.updateAdmin(root, 'target', { ...change(), preset: 'super_admin' })).rejects.toThrow(BadRequestException);
      expect(tx.adminProfile.update).not.toHaveBeenCalled();
    });

    it('cannot bypass delegation limits by omitting the explicit permission list', async () => {
      const limited = { ...actor, permissions: [...ADMIN_PRESETS.support, 'admin.admins.manage'] };
      await expect(service.updateAdmin(limited, 'target', { ...input, preset: 'super_admin' })).rejects.toThrow(ForbiddenException);
      expect(tx.adminProfile.update).not.toHaveBeenCalled();
    });

    it('cannot invite an administrator with permissions the operator does not hold', async () => {
      access.ready.mockReturnValue(true);
      const limited = { ...actor, permissions: [...ADMIN_PRESETS.support, 'admin.admins.manage'] };
      await expect(service.invite(limited, { fullName: 'New admin', email: 'new-admin@example.test',
        role: 'ADMIN', preset: 'moderator', mfaCode: '123456', reason: 'Verified access request' }))
        .rejects.toThrow(ForbiddenException);
      expect(mfa.verify).not.toHaveBeenCalled();
      expect(tx.auditLog.create).not.toHaveBeenCalled();
      expect(access.enqueue).not.toHaveBeenCalled();
    });

    it('shows assigned and preset permissions without returning PII or MFA secrets', async () => {
      const result = await service.adminAccess(root, 'target');
      expect(result.data).toMatchObject({ id: 'target', version: 7, preset: 'support',
        permissions: ADMIN_PRESETS.support, presetPermissions: ADMIN_PRESETS.support, canCustomizePermissions: true });
      expect(result.data).not.toHaveProperty('email');
      expect(result.data).not.toHaveProperty('mfaSecret');
    });

    it('does not offer editing for self or when the live operator has no grant authority', async () => {
      expect((await service.adminAccess(root, root.userId)).data.canCustomizePermissions).toBe(false);
      tx.adminProfile.findUnique.mockResolvedValue({ preset: 'support', permissions: [...ADMIN_PRESETS.support], user: { role: 'ADMIN', isActive: true } });
      expect((await service.adminAccess(root, 'target')).data.canCustomizePermissions).toBe(false);
    });
  });
});
