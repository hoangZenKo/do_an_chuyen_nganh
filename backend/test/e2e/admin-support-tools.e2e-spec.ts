import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, login, registerLandlord, resetDatabase } from './e2e-fixtures';
import { ADMIN_PRESETS } from '../../src/common/admin-permissions';

describe('Support tools E2E', () => {
  let harness: E2eHarness;
  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });

  async function admin() {
    const created = await createAdmin(harness.prisma, 'support-tools');
    const user = await harness.prisma.user.findUniqueOrThrow({ where: { email: created.email } });
    await harness.prisma.adminProfile.update({ where: { userId: user.id }, data: { preset: 'support', permissions: [...ADMIN_PRESETS.support] } });
    return { id: user.id, ...(await login(harness.baseUrl, created.email)) };
  }

  it('supports searchable labels, templates and requester feedback', async () => {
    const owner = await registerLandlord(harness.baseUrl, 'support-tools-owner');
    const support = await admin();
    const created = await requestJson<any>(harness.baseUrl, '/api/v1/support/tickets', { method: 'POST', token: owner.accessToken,
      body: { subject: 'Cần mẫu trả lời', body: 'Tôi cần hỗ trợ nội dung ticket này.', category: 'GENERAL' } });
    const ticket = created.json!.data;
    const labels = await requestJson<any>(harness.baseUrl, `/api/v1/support/tickets/${ticket.id}/labels`, { method: 'PATCH', token: support.accessToken,
      body: { labels: ['billing', 'urgent'], version: 1, reason: 'Gắn nhãn để theo dõi SLA' } });
    expect(labels.status).toBe(200);
    const filtered = await requestJson<any>(harness.baseUrl, '/api/v1/support/tickets?search=mẫu&label=billing', { token: support.accessToken });
    expect(filtered.status).toBe(200);
    expect(filtered.json!.data[0].labels).toEqual(['billing', 'urgent']);
    const template = await requestJson<any>(harness.baseUrl, '/api/v1/support/templates', { method: 'POST', token: support.accessToken,
      body: { title: 'Xác nhận tiếp nhận', body: 'Chúng tôi đã tiếp nhận yêu cầu của bạn.', reason: 'Chuẩn hóa phản hồi hỗ trợ' } });
    expect(template.status).toBe(201);
    expect((await requestJson<any>(harness.baseUrl, '/api/v1/support/templates', { token: support.accessToken })).json!.data).toHaveLength(1);
    await requestJson(harness.baseUrl, `/api/v1/support/tickets/${ticket.id}/status`, { method: 'PATCH', token: support.accessToken,
      body: { status: 'RESOLVED', version: 2, reason: 'Đã xử lý xong yêu cầu' } });
    const feedback = await requestJson<any>(harness.baseUrl, `/api/v1/support/tickets/${ticket.id}/feedback`, { method: 'POST', token: owner.accessToken,
      body: { rating: 5, comment: 'Phản hồi nhanh.', version: 3 } });
    expect(feedback.status).toBe(201);
    expect(feedback.json!.data.feedbackRating).toBe(5);
    expect((await requestJson(harness.baseUrl, `/api/v1/support/tickets/${ticket.id}/feedback`, { method: 'POST', token: owner.accessToken,
      body: { rating: 4, version: 4 } })).status).toBe(409);
  });
});
