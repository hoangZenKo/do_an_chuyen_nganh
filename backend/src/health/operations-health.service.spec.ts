import { OperationsHealthService } from './operations-health.service';

describe('Operations readiness projection', () => {
  function setup() {
    const prisma = {
      operationsMetric: { aggregate: jest.fn().mockResolvedValue({ _sum: {} }) },
      workerHeartbeat: { findMany: jest.fn().mockResolvedValue([]) },
      operationsIncident: { findMany: jest.fn().mockResolvedValue([]) },
      deliveryJob: { groupBy: jest.fn().mockResolvedValue([]) },
      platformNotificationDelivery: { groupBy: jest.fn().mockResolvedValue([{ status: 'DEAD', _count: 2 }]) },
      adminReportRun: { groupBy: jest.fn().mockResolvedValue([{ status: 'FAILED', _count: 1 }]) },
      $queryRaw: jest.fn().mockResolvedValueOnce([{ total: 0n }]).mockResolvedValueOnce([]),
    };
    const config = { get: jest.fn() };
    const delivery = { configured: jest.fn().mockReturnValue(false) };
    const metrics = { flush: jest.fn(), snapshot: jest.fn().mockReturnValue({}) };
    const schema = { inspect: jest.fn().mockResolvedValue({ ready: false, missing: ['pending'], drifted: [] }) };
    const backups = { inspect: jest.fn().mockResolvedValue({ available: false, ageMinutes: null, source: null, status: 'UNKNOWN' }) };
    return { service: new OperationsHealthService(prisma as never, config as never, delivery as never, {} as never, metrics as never, schema as never, backups as never), schema, backups, config };
  }

  it('does not confuse database reachability with schema readiness, or invent backup age', async () => {
    const { service } = setup();
    const { data } = await service.summary();
    expect(data.database).toBe('ok');
    expect(data.readiness).toMatchObject({ status: 'NOT_READY', ready: false, missing: ['pending'] });
    expect(data.backup).toMatchObject({ available: false, ageMinutes: null, source: null, status: 'UNKNOWN' });
    expect(data.workers.every(worker => worker.status === 'NOT_REPORTED')).toBe(true);
    expect(data.queues).toEqual({ notifications: [{ status: 'DEAD', total: 2 }], reports: [{ status: 'FAILED', total: 1 }] });
    expect(data.releaseGate).toMatchObject({ status: 'BLOCKED', productionAccepted: false });
  });

  it('redacts readiness inspection errors and distinguishes unavailable from a passing check', async () => {
    const { service, schema } = setup();
    schema.inspect.mockRejectedValue(new Error('postgres://secret@database'));
    const response = await service.summary();
    expect(response.data.readiness).toMatchObject({ ready: false, status: 'UNAVAILABLE' });
    expect(JSON.stringify(response)).not.toContain('postgres://');
  });
});
