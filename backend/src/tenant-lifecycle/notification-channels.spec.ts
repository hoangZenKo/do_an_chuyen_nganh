import { tenantAllowsReminder } from './notification-channels';

describe('Tenant reminder consent', () => {
  it('defaults to in-app only, not external email or Zalo delivery', () => {
    expect(tenantAllowsReminder(null, 'APP')).toBe(true);
    expect(tenantAllowsReminder(null, 'EMAIL')).toBe(false);
    expect(tenantAllowsReminder(undefined, 'ZALO')).toBe(false);
  });

  it('requires both an enabled preference and an explicitly selected supported channel', () => {
    expect(tenantAllowsReminder({ enabled: false, channels: ['APP', 'EMAIL'] }, 'APP')).toBe(false);
    expect(tenantAllowsReminder({ enabled: true, channels: ['EMAIL'] }, 'EMAIL')).toBe(true);
    expect(tenantAllowsReminder({ enabled: true, channels: ['EMAIL'] }, 'APP')).toBe(false);
    expect(tenantAllowsReminder({ enabled: true, channels: ['SMS'] }, 'SMS')).toBe(false);
  });
});
