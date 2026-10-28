import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { createAdmin, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin search E2E', () => {
  let harness: E2eHarness;
  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });

  it('returns permission-scoped groups without exposing private account data', async () => {
    const landlord = await registerLandlord(harness.baseUrl, 'search-landlord');
    const admin = await createAdmin(harness.prisma, 'search-admin');
    const session = await requestJson<any>(harness.baseUrl, '/api/v1/auth/login', { method: 'POST', body: { email: admin.email, password: 'StrongPassword!123' } });
    const result = await requestJson<any>(harness.baseUrl, '/api/v1/admin/search?search=search-landlord', { token: session.json!.data.accessToken });
    expect(result.status).toBe(200);
    const account = result.json.data.find((group: any) => group.kind === 'ACCOUNT').items.find((item: any) => item.id === landlord.user.id);
    expect(account.email).not.toBe(landlord.email);
    expect(account.email).toContain('***@');
  });

  it('rejects short queries and anonymous access with the stable error envelope', async () => {
    const invalid = await requestJson<any>(harness.baseUrl, '/api/v1/admin/search?search=x');
    expect(invalid.status).toBe(401);
    const admin = await createAdmin(harness.prisma, 'search-validation');
    const session = await requestJson<any>(harness.baseUrl, '/api/v1/auth/login', { method: 'POST', body: { email: admin.email, password: 'StrongPassword!123' } });
    const short = await requestJson<any>(harness.baseUrl, '/api/v1/admin/search?search=x', { token: session.json!.data.accessToken });
    expect(short.status).toBe(400);
    expect(short.json.error.code).toBe('VALIDATION_ERROR');
  });
});
