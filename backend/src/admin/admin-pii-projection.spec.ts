import { AdminService } from './admin.service';
import { GovernanceService } from '../platform/governance.service';

describe('Legacy admin contact projection', () => {
  it('masks contacts on landlord and property list/detail instead of bypassing PII reveal', async () => {
    const user = { id: 'owner', fullName: 'Owner', email: 'private@example.test', phone: '0901234567', isActive: true, sessionVersion: 0, _count: { properties: 1, tenants: 1 } };
    const property = { id: 'property', name: 'Property', address: 'Address', landlord: user, _count: { rooms: 1 }, rooms: [] };
    const prisma = { user: { count: jest.fn().mockResolvedValue(1), findMany: jest.fn().mockResolvedValue([user]), findFirst: jest.fn().mockResolvedValue(user) },
      property: { count: jest.fn().mockResolvedValue(1), findMany: jest.fn().mockResolvedValue([property]), findUnique: jest.fn().mockResolvedValue(property) },
      room: { count: jest.fn().mockResolvedValue(1), groupBy: jest.fn().mockResolvedValue([]) }, lease: { count: jest.fn().mockResolvedValue(0) },
      $queryRaw: jest.fn().mockResolvedValue([]), $transaction: jest.fn(),
    };
    prisma.$transaction.mockImplementation((work: (client: typeof prisma) => unknown) => work(prisma));
    const service = new AdminService(prisma as never, {} as never);
    const responses = await Promise.all([service.listLandlords({ page: 1, limit: 20 }), service.getLandlord('owner'), service.listProperties({ page: 1, limit: 20 }), service.getProperty('property')]);
    for (const response of responses) {
      expect(JSON.stringify(response)).not.toContain(user.email);
      expect(JSON.stringify(response)).not.toContain(user.phone);
      expect(JSON.stringify(response)).toContain('p***@example.test');
      expect(JSON.stringify(response)).toContain('***567');
    }
  });

  it('masks team/member emails and emits no MFA secret material', async () => {
    const member = { userId: 'admin', user: { id: 'admin', fullName: 'Admin', email: 'private@example.test' } };
    const prisma = { user: { findMany: jest.fn().mockResolvedValue([{ id: 'admin', fullName: 'Admin', email: member.user.email, isActive: true, adminProfile: { preset: 'support', permissions: [], mfaEnabled: true, mfaSecret: 'must-not-leak' }, adminTeamMemberships: [] }]) },
      adminTeam: { findMany: jest.fn().mockResolvedValue([{ id: 'team', members: [member] }]) } };
    const service = new GovernanceService(prisma as never, {} as never);
    for (const response of await Promise.all([service.team(), service.teams()])) {
      expect(JSON.stringify(response)).not.toContain(member.user.email);
      expect(JSON.stringify(response)).not.toContain('must-not-leak');
      expect(JSON.stringify(response)).toContain('p***@example.test');
    }
  });
});
