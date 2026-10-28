import { AuthRole } from '../common/auth-role';
import { IncidentWorkflowService } from './incident-workflow.service';
import { IncidentQuery } from './incident-workflow.controller';

describe('Incident inbox filters', () => {
  it('intersects actor assignment, explicit owner, status, severity, time window and search', async () => {
    const prisma = { operationsIncident: { count: jest.fn().mockResolvedValue(1), findMany: jest.fn().mockResolvedValue([{ id: 'incident' }]) }, $transaction: (queries: Promise<unknown>[]) => Promise.all(queries) };
    const actor = { userId: 'actor', email: 'admin@example.test', role: AuthRole.ADMIN };
    const query = Object.assign(new IncidentQuery(), { page: 2, limit: 10, status: 'OPEN', severity: 'CRITICAL', ownerId: 'other', assignment: 'mine', window: '24h', search: ' delivery ' });
    const result = await new IncidentWorkflowService(prisma as never).list(actor, query);
    expect(prisma.operationsIncident.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 10, take: 10, where: { AND: [
      { status: 'OPEN' }, { ownerId: 'other' }, { severity: 'CRITICAL' }, { ownerId: 'actor' },
      { lastSeenAt: { gte: expect.any(Date) } },
      { OR: [{ title: { contains: 'delivery', mode: 'insensitive' } }, { key: { contains: 'delivery', mode: 'insensitive' } }] },
    ] } }));
    expect(prisma.operationsIncident.count.mock.calls[0][0].where).toEqual(prisma.operationsIncident.findMany.mock.calls[0][0].where);
    expect(result.meta).toEqual({ page: 2, limit: 10, total: 1 });
  });

  it('supports unassigned items without converting an empty result into an error', async () => {
    const prisma = { operationsIncident: { count: jest.fn().mockResolvedValue(0), findMany: jest.fn().mockResolvedValue([]) }, $transaction: (queries: Promise<unknown>[]) => Promise.all(queries) };
    const actor = { userId: 'actor', email: 'admin@example.test', role: AuthRole.ADMIN };
    await expect(new IncidentWorkflowService(prisma as never).list(actor, Object.assign(new IncidentQuery(), { assignment: 'unassigned' }))).resolves.toMatchObject({ data: [], meta: { total: 0 } });
    expect(prisma.operationsIncident.count).toHaveBeenCalledWith({ where: { AND: [{ ownerId: null }] } });
  });
});
