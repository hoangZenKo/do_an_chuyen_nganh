import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { AdminProfileDto } from './admin-console.dto';

describe('Explicit administrator permission validation', () => {
  const input = { preset: 'support', isActive: true, version: 0, mfaCode: '123456', reason: 'Approved access review' };

  it('preserves older preset commands and accepts a bounded explicit list', async () => {
    for (const data of [input, { ...input, permissions: ['admin.dashboard.view', 'admin.plans.view'] }]) {
      expect(await validate(plainToInstance(AdminProfileDto, data))).toEqual([]);
    }
  });

  it.each([null, [], 'admin.dashboard.view', ['admin.unknown'],
    ['admin.dashboard.view', 'admin.dashboard.view']])('rejects invalid grants %j', async permissions => {
    const errors = await validate(plainToInstance(AdminProfileDto, { ...input, permissions }));
    expect(errors.some(error => error.property === 'permissions')).toBe(true);
  });
});
