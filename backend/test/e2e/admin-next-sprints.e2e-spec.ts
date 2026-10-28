import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { login, registerLandlord, resetDatabase } from './e2e-fixtures';

describe('Admin next sprints E2E', () => {
  let harness: E2eHarness;

  beforeAll(async () => { harness = await createE2eHarness(); });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });

  it('keeps a stable session across refresh and revokes access and refresh together', async () => {
    const first = await registerLandlord(harness.baseUrl, 'session-owner');
    const second = await login(harness.baseUrl, first.email);
    const other = await registerLandlord(harness.baseUrl, 'session-other');
    const list = await requestJson(harness.baseUrl, '/api/v1/auth/sessions', { token: first.accessToken });
    expect(list.status).toBe(200);
    expect(list.json.data).toHaveLength(2);
    const secondId = list.json.data.find((item: any) => !item.current).id;
    expect(list.text).not.toContain('tokenHash');

    const refreshed = await requestJson(harness.baseUrl, '/api/v1/auth/refresh', {
      method: 'POST', body: { refreshToken: second.refreshToken },
    });
    expect(refreshed.status).toBe(201);
    const forbidden = await requestJson(harness.baseUrl, `/api/v1/auth/sessions/${secondId}/revoke`, {
      method: 'POST', token: other.accessToken,
    });
    expect(forbidden.status).toBe(404);

    const revoked = await requestJson(harness.baseUrl, `/api/v1/auth/sessions/${secondId}/revoke`, {
      method: 'POST', token: first.accessToken,
    });
    expect(revoked.status).toBe(201);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: refreshed.json.data.accessToken })).status).toBe(401);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: second.accessToken })).status).toBe(401);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: first.accessToken })).status).toBe(200);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/refresh', {
      method: 'POST', body: { refreshToken: refreshed.json.data.refreshToken },
    })).status).toBe(401);
  });

  it('revokes other devices while retaining the current session', async () => {
    const first = await registerLandlord(harness.baseUrl, 'session-all');
    const second = await login(harness.baseUrl, first.email);
    const result = await requestJson(harness.baseUrl, '/api/v1/auth/sessions/revoke-all', {
      method: 'POST', token: first.accessToken,
    });
    expect(result.json.data.revoked).toBe(1);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: first.accessToken })).status).toBe(200);
    expect((await requestJson(harness.baseUrl, '/api/v1/auth/me', { token: second.accessToken })).status).toBe(401);
    expect(await harness.prisma.auditLog.count({ where: { action: 'auth.other_sessions_revoked' } })).toBe(1);
  });

  it('normalizes errors and publishes the development OpenAPI contract', async () => {
    const result = await requestJson(harness.baseUrl, '/api/v1/auth/login', {
      method: 'POST', headers: { 'x-request-id': 'sprint5-validation' }, body: { email: 'invalid' },
    });
    expect(result.status).toBe(400);
    expect(result.json).toMatchObject({ error: { code: 'VALIDATION_ERROR' }, requestId: 'sprint5-validation' });
    expect(result.json.error.details).toEqual(expect.any(Array));
    const unauthorized = await requestJson(harness.baseUrl, '/api/v1/auth/sessions');
    expect(unauthorized.json.error.code).toBe('UNAUTHORIZED');
    const document = await requestJson(harness.baseUrl, '/docs-json');
    expect(document.status).toBe(200);
    expect(document.json.paths['/api/v1/auth/sessions']).toBeDefined();
  });
});
