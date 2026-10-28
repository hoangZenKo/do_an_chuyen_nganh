import { AccountAccessService } from './account-access.service';

describe('AccountAccessService', () => {
  it('rate-limits repeated non-admin account access sends', async () => {
    const tx = {
      $queryRaw: jest.fn(),
      user: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'user', email: 'user@example.test', isActive: true, role: 'TENANT' }) },
      accountAccessToken: {
        findFirst: jest.fn().mockResolvedValue({ createdAt: new Date() }),
        count: jest.fn().mockResolvedValue(1),
      },
    } as any;
    const service = new AccountAccessService(
      {} as any,
      { get: jest.fn(() => 'https://app.example.test'), getOrThrow: jest.fn(() => 'https://app.example.test') } as any,
      { configured: jest.fn(() => true) } as any,
      {} as any,
    );
    await expect(service.enqueue(tx, 'user', 'PASSWORD_RESET')).rejects.toMatchObject({ status: 429 });
    expect(tx.accountAccessToken.findFirst).toHaveBeenCalled();
  });
});
