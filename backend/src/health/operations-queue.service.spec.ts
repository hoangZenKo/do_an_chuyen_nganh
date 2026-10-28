import { OperationsQueueService } from './operations-queue.service';
import { OperationsQueueQuery } from './operations-queue.controller';

describe('Operations delivery queue projection', () => {
  it('bounds the query, filters state, selects no payload and never permits unsafe manual replay', async () => {
    const prisma = { deliveryJob: { count: jest.fn().mockResolvedValue(3), findMany: jest.fn().mockResolvedValue([
      { id: 'first', lastError: 'HTTP_503' }, { id: 'second', lastError: 'secret provider response' }, { id: 'third', lastError: null },
    ]) }, $transaction: jest.fn((queries: Promise<unknown>[]) => Promise.all(queries)) };
    const result = await new OperationsQueueService(prisma as never).list(Object.assign(new OperationsQueueQuery(), { page: 2, limit: 10 }));
    const query = prisma.deliveryJob.findMany.mock.calls[0][0];
    expect(query).toMatchObject({ where: { status: 'DEAD' }, take: 10, skip: 10 });
    expect(query.select).not.toHaveProperty('payload');
    expect(query.select).not.toHaveProperty('token');
    expect(result.data.map(row => row.lastError)).toEqual(['HTTP_503', 'REDACTED', null]);
    expect(result.data.every(row => row.retryable === false)).toBe(true);
    expect(JSON.stringify(result)).not.toContain('secret provider response');
  });
});
