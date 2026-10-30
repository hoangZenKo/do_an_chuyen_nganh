import { ForbiddenException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AdminConsoleService } from './admin-console.service';
import { AdminQueueQuery } from './admin-console.dto';
import { AuthUser } from '../common/current-user.decorator';
import { AuthRole } from '../common/auth-role';

describe('Admin moderation queue search', () => {
  const actor: AuthUser = { userId: 'admin-1', email: 'admin@example.test', role: AuthRole.ADMIN,
    permissions: ['admin.listings.moderate', 'admin.reviews.moderate', 'admin.reports.manage'] };
  let service: AdminConsoleService;
  let tx: { $queryRaw: jest.Mock };
  let transaction: jest.Mock;
  beforeEach(() => {
    tx = { $queryRaw: jest.fn().mockResolvedValueOnce([{ total: 21n }]).mockResolvedValueOnce([]) };
    transaction = jest.fn(work => work(tx));
    service = new AdminConsoleService({ $transaction: transaction } as any, {} as any, {} as any);
  });
  function filter(search: string, kind = 'LISTING'): Prisma.Sql {
    return (service as any).queueWhere(actor, Object.assign(new AdminQueueQuery(), { search, kind }));
  }

  it('searches related room, property and landlord names without selecting private contacts', () => {
    const query = filter('A101');
    for (const field of ['q.title', 'r.name', 'r.id', 'p.name', 'landlord."fullName"']) expect(query.sql).toContain(field);
    for (const table of ['"RoomListing"', '"ListingReport"', '"RoomReview"']) expect(query.sql).toContain(table);
    expect(query.sql).not.toMatch(/email|phone|tenantName|passwordHash/);
    expect(query.values).toContain('%A101%');
  });

  it.each(['LISTING', 'REPORT', 'REVIEW', 'REPLY'])('supports related search for %s', kind => {
    const query = filter('Building', kind);
    expect(query.values[0]).toBe(kind);
    expect(query.sql).toContain('EXISTS');
  });

  it('treats SQL metacharacters literally and binds hostile input as values', () => {
    const input = "50%_\\' OR 1=1 --";
    const query = filter(input);
    expect(query.sql).not.toContain(input);
    expect(query.values).toContain("%50\\%\\_\\\\' OR 1=1 --%");
  });

  it('keeps UUID item targeting exact while also allowing an exact room UUID', () => {
    const id = 'E470064F-E484-4ED1-8C19-7A0C4128CE1B';
    const query = filter(id);
    expect(query.sql).toContain('q.id::text =');
    expect(query.sql).toContain('r.id::text =');
    expect(query.sql).not.toContain('ILIKE');
    expect(query.values).toContain(id.toLowerCase());
  });

  it('omits relational search when no keyword is provided', () => {
    expect(filter('').sql).not.toContain('EXISTS');
  });

  it('uses the same search and filters before counting and paginating', async () => {
    const result = await service.queue(actor, Object.assign(new AdminQueueQuery(), {
      search: 'A101', page: 2, assignment: 'mine', priority: 'HIGH', overdue: 'true',
    }));
    expect(result.meta).toEqual({ total: 21, page: 2, limit: 20, pages: 2 });
    const queries = tx.$queryRaw.mock.calls.map(([strings, ...values]) => Prisma.sql(strings, ...values));
    for (const query of queries) {
      expect(query.sql).toContain('EXISTS');
      expect(query.values).toEqual(expect.arrayContaining(['%A101%', actor.userId, 'HIGH']));
      expect(query.sql).toContain("INTERVAL '48 hours'");
    }
    expect(queries[1].values.slice(-2)).toEqual([20, 20]);
    expect(transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'RepeatableRead' });
  });

  it('rejects unauthorized kinds before accessing the database', async () => {
    await expect(service.queue({ ...actor, permissions: [] }, new AdminQueueQuery())).rejects.toThrow(ForbiddenException);
    expect(transaction).not.toHaveBeenCalled();
  });
});
