import { Type } from 'class-transformer';
import { IsIn, IsInt, IsISO8601, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';
import { AdminStatusDto } from '../admin/admin-console.dto';

export class ModerationQualityQuery {
  @IsOptional() @IsISO8601({ strict: true }) @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/)
  from?: string;

  @IsOptional() @IsISO8601({ strict: true }) @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/)
  to?: string;

  @IsString() @MaxLength(80) timezone = 'Asia/Ho_Chi_Minh';
}

export class ModerationSampleQuery extends ModerationQualityQuery {
  @IsOptional() @IsIn(['LISTING', 'REPORT', 'REVIEW', 'REPLY']) kind?: string;
  @IsIn(['PENDING', 'REVIEWED', 'ALL']) state = 'PENDING';
  @Type(() => Number) @IsInt() @Min(1) @Max(100) page = 1;
  @Type(() => Number) @IsInt() @Min(1) @Max(25) limit = 10;
}

export class ModerationQualityReviewDto extends AdminStatusDto {
  @IsIn(['AGREE', 'DISAGREE', 'NEEDS_DISCUSSION']) outcome!: string;
}

export function qualityWindow(query: ModerationQualityQuery, now = new Date()) {
  if (!!query.from !== !!query.to) throw new Error('FROM_TO_PAIR');
  if ([query.from, query.to].some(value => value !== undefined && !/T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value))) throw new Error('INVALID_WINDOW');
  const to = query.to ? new Date(query.to) : now;
  const from = query.from ? new Date(query.from) : new Date(to.getTime() - 30 * 86400000);
  if (!Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) || from >= to || to > now || to.getTime() - from.getTime() > 93 * 86400000) {
    throw new Error('INVALID_WINDOW');
  }
  const timezone = query.timezone ?? 'Asia/Ho_Chi_Minh';
  let formatter: Intl.DateTimeFormat;
  try { formatter = new Intl.DateTimeFormat('vi-VN', { timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZoneName: 'shortOffset' }); }
  catch { throw new Error('INVALID_TIMEZONE'); }
  return { from, to, timezone, displayFrom: formatter.format(from), displayTo: formatter.format(to), generatedAt: now.toISOString() };
}
