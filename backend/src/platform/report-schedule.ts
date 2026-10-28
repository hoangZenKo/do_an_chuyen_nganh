import { BadRequestException } from '@nestjs/common';

export function nextReportAt(reference: Date, cadence: string, hourUtc: number, initial = false, timezone = 'UTC'): Date {
  if (timezone !== 'UTC') return zonedNext(reference, cadence, hourUtc, initial, timezone);
  const next = new Date(reference);
  next.setUTCHours(hourUtc, 0, 0, 0);
  if (initial) {
    if (next <= reference) next.setUTCDate(next.getUTCDate() + 1);
    return next;
  }
  if (cadence === 'MONTHLY') {
    const day = next.getUTCDate();
    next.setUTCDate(1);
    next.setUTCMonth(next.getUTCMonth() + 1);
    const lastDay = new Date(Date.UTC(next.getUTCFullYear(), next.getUTCMonth() + 1, 0)).getUTCDate();
    next.setUTCDate(Math.min(day, lastDay));
  } else {
    next.setUTCDate(next.getUTCDate() + (cadence === 'WEEKLY' ? 7 : 1));
  }
  return next;
}

function zonedNext(reference: Date, cadence: string, hour: number, initial: boolean, timezone: string): Date {
  let formatter: Intl.DateTimeFormat;
  try {
    formatter = new Intl.DateTimeFormat('en-GB', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
  } catch { throw new BadRequestException('Invalid IANA report timezone.'); }
  const parts = (date: Date) => Object.fromEntries(formatter.formatToParts(date).filter(part => part.type !== 'literal').map(part => [part.type, Number(part.value)]));
  const local = parts(reference);
  let wall = new Date(Date.UTC(local.year, local.month - 1, local.day, hour));
  const advance = () => {
    if (!initial && cadence === 'MONTHLY') {
      const day = wall.getUTCDate(); wall.setUTCDate(1); wall.setUTCMonth(wall.getUTCMonth() + 1);
      wall.setUTCDate(Math.min(day, new Date(Date.UTC(wall.getUTCFullYear(), wall.getUTCMonth() + 1, 0)).getUTCDate()));
    } else wall.setUTCDate(wall.getUTCDate() + (!initial && cadence === 'WEEKLY' ? 7 : 1));
  };
  if (!initial) advance();
  for (let attempt = 0; attempt < 4; attempt++) {
    const offsets = new Set<number>();
    for (const delta of [-36, -12, 0, 12, 36]) {
      const sample = new Date(wall.getTime() + delta * 3600000), sampleParts = parts(sample);
      offsets.add(Date.UTC(sampleParts.year, sampleParts.month - 1, sampleParts.day, sampleParts.hour, sampleParts.minute) - sample.getTime());
    }
    const instants = [...offsets].map(offset => new Date(wall.getTime() - offset)).filter(date => {
      const candidate = parts(date);
      return candidate.year === wall.getUTCFullYear() && candidate.month === wall.getUTCMonth() + 1 && candidate.day === wall.getUTCDate() && candidate.hour === hour && candidate.minute === 0;
    }).sort((left, right) => left.getTime() - right.getTime());
    const next = instants.find(date => date > reference);
    if (next) return next;
    advance();
  }
  throw new BadRequestException('No report occurrence found in timezone.');
}
