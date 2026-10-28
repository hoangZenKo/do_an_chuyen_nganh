import { billingError, money } from './billing-rules';

export interface UtilityTier { upTo?: number | null; unitPrice: number }

export function validateTiers(tiers: UtilityTier[]) {
  let previous = 0;
  for (const [index, tier] of tiers.entries()) {
    money(tier.unitPrice, true);
    if (tier.upTo == null) {
      if (index !== tiers.length - 1) billingError('INVALID_UTILITY_TIERS', 'Only the final tier may be unbounded.');
    } else {
      money(tier.upTo);
      if (tier.upTo <= previous) billingError('INVALID_UTILITY_TIERS', 'Tier upper bounds must be strictly increasing.');
      previous = tier.upTo;
    }
  }
  if (tiers.length && tiers[tiers.length - 1].upTo != null) billingError('INVALID_UTILITY_TIERS', 'The final tier must be unbounded.');
}

export function utilityCharges(usage: number, amount: number, tiers: UtilityTier[]) {
  money(usage, true); money(amount, true); validateTiers(tiers);
  if (!tiers.length) return [{ quantity: usage, unitPrice: amount, amount: money(usage * amount, true) }];
  let previous = 0;
  let remaining = usage;
  const lines = [];
  for (const tier of tiers) {
    if (remaining <= 0) break;
    const quantity = Math.min(remaining, tier.upTo == null ? remaining : tier.upTo - previous);
    lines.push({ quantity, unitPrice: tier.unitPrice, amount: money(quantity * tier.unitPrice, true) });
    remaining -= quantity;
    if (tier.upTo != null) previous = tier.upTo;
  }
  money(lines.reduce((sum, line) => sum + line.amount, 0), true);
  return lines;
}
