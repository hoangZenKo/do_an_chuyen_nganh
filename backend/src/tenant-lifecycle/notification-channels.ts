export const TENANT_REMINDER_CHANNELS = ['APP', 'EMAIL', 'ZALO'] as const;

export function tenantAllowsReminder(
  preference: { enabled: boolean; channels: string[] } | null | undefined,
  channel: string,
) {
  return (preference?.enabled ?? true) &&
    (preference?.channels ?? ['APP']).includes(channel) &&
    (TENANT_REMINDER_CHANNELS as readonly string[]).includes(channel);
}
