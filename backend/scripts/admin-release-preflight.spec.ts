import { adminReleasePreflight } from './admin-release-preflight';

describe('Read-only admin release preflight', () => {
  it('never promotes configured integrations to acceptance or includes secret values', async () => {
    const result = await adminReleasePreflight({ AUTH_DELIVERY_WEBHOOK_SECRET: 'private-secret', DATABASE_URL: 'postgres://user:password@database/working' });
    expect(result).toMatchObject({ status: 'BLOCKED', productionAccepted: false, databaseAccessed: false });
    expect(JSON.stringify(result)).not.toMatch(/private-secret|password|postgres:\/\//);
  });
});
