export function parseDurationMs(value: string): number {
  const match = /^([0-9]+(?:\.[0-9]+)?)(ms|s|m|h|d)$/.exec(value.trim());
  if (!match) return 15 * 60 * 1000;
  const amount = Number(match[1]);
  const multipliers: Record<string, number> = {
    ms: 1,
    s: 1000,
    m: 60 * 1000,
    h: 60 * 60 * 1000,
    d: 24 * 60 * 60 * 1000,
  };
  return amount * multipliers[match[2]];
}
