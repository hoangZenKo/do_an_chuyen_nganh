import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, login, resetDatabase } from './e2e-fixtures';

describe('Moderation policy E2E', () => {
  let harness: E2eHarness;
  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });

  it('versions policies, activates one policy per kind and exposes quality metrics', async () => {
    const created = await createAdmin(harness.prisma, 'policy-admin');
    const session = await login(harness.baseUrl, created.email);
    const create = (body: unknown) => requestJson<any>(harness.baseUrl, '/api/v1/admin/moderation-policies', { method: 'POST', token: session.accessToken, body });
    const first = await create({ kind: 'LISTING', title: 'Listing v1', body: 'Policy nội dung listing bản đầu tiên đủ dài để kiểm thử.', reason: 'Thiết lập policy moderation' });
    expect(first.status).toBe(201);
    const activate = await requestJson<any>(harness.baseUrl, `/api/v1/admin/moderation-policies/${first.json!.data.id}/activate`, { method: 'POST', token: session.accessToken, body: { reason: 'Kích hoạt policy listing đầu tiên' } });
    expect(activate.status).toBe(201);
    const second = await create({ kind: 'LISTING', title: 'Listing v2', body: 'Policy nội dung listing phiên bản hai đủ dài để kiểm thử.', reason: 'Cập nhật policy moderation' });
    expect(second.json!.data.version).toBe(2);
    const policies = await requestJson<any>(harness.baseUrl, '/api/v1/admin/moderation-policies', { token: session.accessToken });
    expect(policies.json!.data.map((row: any) => row.status)).toEqual(expect.arrayContaining(['ACTIVE', 'DRAFT']));
    const quality = await requestJson<any>(harness.baseUrl, '/api/v1/admin/moderation-policies/quality', { token: session.accessToken });
    expect(quality.status).toBe(200);
    expect(quality.json!.data.automaticSanctions).toBe(false);
  });
});
