import { createE2eHarness, closeE2eHarness, E2eHarness, requestJson } from './e2e-app';
import {
  createAdmin,
  login,
  registerLandlord,
  resetDatabase,
  testPassword,
} from './e2e-fixtures';

describe('Auth E2E', () => {
  let harness: E2eHarness;

  beforeAll(async () => {
    harness = await createE2eHarness();
  });

  afterAll(async () => {
    await closeE2eHarness(harness);
  });

  beforeEach(async () => {
    await resetDatabase(harness.prisma);
  });

  it('registers landlords, rejects duplicate emails, and rejects unknown fields', async () => {
    const registered = await registerLandlord(harness.baseUrl, 'auth-register');

    expect(registered.user.role).toBe('landlord');
    await expect(
      harness.prisma.user.findUnique({ where: { email: registered.email } }),
    ).resolves.toMatchObject({ role: 'LANDLORD' });

    const duplicate = await requestJson<any>(harness.baseUrl, '/api/v1/auth/register', {
      method: 'POST',
      body: {
        fullName: 'Duplicate User',
        email: registered.email,
        phone: '+84901234567',
        password: testPassword,
      },
    });
    expect(duplicate.status).toBe(409);
    expect(duplicate.json?.error.code).toBe('EMAIL_ALREADY_REGISTERED');

    const withRole = await requestJson(harness.baseUrl, '/api/v1/auth/register', {
      method: 'POST',
      body: {
        fullName: 'Role Injection',
        email: 'role-injection@example.com',
        phone: '+84901234567',
        password: testPassword,
        role: 'admin',
      },
    });
    expect(withRole.status).toBe(400);
  });

  it('logs in, serves /auth/me, rotates refresh tokens, and logs out', async () => {
    const registered = await registerLandlord(harness.baseUrl, 'auth-login');

    const badLogin = await requestJson(harness.baseUrl, '/api/v1/auth/login', {
      method: 'POST',
      body: { email: registered.email, password: 'WrongPassword!123' },
    });
    expect(badLogin.status).toBe(401);

    const session = await login(harness.baseUrl, registered.email);
    expect(session.accessToken).toEqual(expect.any(String));
    expect(session.refreshToken).toEqual(expect.any(String));

    const noToken = await requestJson(harness.baseUrl, '/api/v1/auth/me');
    expect(noToken.status).toBe(401);

    const invalidToken = await requestJson(harness.baseUrl, '/api/v1/auth/me', {
      token: 'invalid-token',
    });
    expect(invalidToken.status).toBe(401);

    const me = await requestJson<any>(harness.baseUrl, '/api/v1/auth/me', {
      token: session.accessToken,
    });
    expect(me.status).toBe(200);
    expect(me.json?.data.email).toBe(registered.email);
    expect(me.json?.data.role).toBe('landlord');

    const admin = await createAdmin(harness.prisma, 'auth-admin');
    const adminSession = await login(harness.baseUrl, admin.email);
    const adminMe = await requestJson<any>(harness.baseUrl, '/api/v1/auth/me', {
      token: adminSession.accessToken,
    });
    expect(adminMe.status).toBe(200);
    expect(adminMe.json?.data.role).toBe('admin');

    const refreshed = await requestJson<any>(harness.baseUrl, '/api/v1/auth/refresh', {
      method: 'POST',
      body: { refreshToken: session.refreshToken },
    });
    expect(refreshed.status).toBe(201);
    expect(refreshed.json?.data.refreshToken).not.toBe(session.refreshToken);

    const replay = await requestJson<any>(harness.baseUrl, '/api/v1/auth/refresh', {
      method: 'POST',
      body: { refreshToken: session.refreshToken },
    });
    expect(replay.status).toBe(401);
    expect(replay.json?.error.code).toBe('INVALID_REFRESH_TOKEN');

    const logout = await requestJson(harness.baseUrl, '/api/v1/auth/logout', {
      method: 'POST',
      body: { refreshToken: refreshed.json!.data.refreshToken },
    });
    expect(logout.status).toBe(204);

    const afterLogout = await requestJson<any>(harness.baseUrl, '/api/v1/auth/refresh', {
      method: 'POST',
      body: { refreshToken: refreshed.json!.data.refreshToken },
    });
    expect(afterLogout.status).toBe(401);
    expect(afterLogout.json?.error.code).toBe('INVALID_REFRESH_TOKEN');
  });
});
