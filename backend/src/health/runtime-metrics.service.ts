import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

type RouteMetric = { requests: number; errors: number; durationMs: number };

@Injectable()
export class RuntimeMetricsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RuntimeMetricsService.name);
  private readonly routes = new Map<string, RouteMetric>();
  private requests = 0;
  private errors = 0;
  private totalDurationMs = 0;
  private pending = { requests: 0, errors: 0, durationMs: 0, loginFailures: 0, mfaFailures: 0 };
  private flushing = false;
  private flushTimer?: NodeJS.Timeout;

  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    this.flushTimer = setInterval(() => void this.flush(), 15000);
    this.flushTimer.unref();
  }

  onModuleDestroy() {
    if (this.flushTimer) clearInterval(this.flushTimer);
  }

  record(method: string, route: string, status: number, durationMs: number, mfa = false) {
    durationMs = Math.max(0, Math.min(600000, durationMs));
    this.requests += 1;
    if (status >= 500) this.errors += 1;
    this.totalDurationMs += durationMs;
    this.pending.requests++;
    this.pending.errors += status >= 500 ? 1 : 0;
    this.pending.durationMs += durationMs;
    this.pending.loginFailures += route === '/api/v1/auth/login' && status === 401 ? 1 : 0;
    this.pending.mfaFailures += mfa && status === 401 ? 1 : 0;
    const key = `${method} ${route}`;
    const metric = this.routes.get(key) ?? { requests: 0, errors: 0, durationMs: 0 };
    metric.requests += 1;
    metric.errors += status >= 500 ? 1 : 0;
    metric.durationMs += durationMs;
    this.routes.set(key, metric);
    if (this.routes.size > 250) this.routes.delete(this.routes.keys().next().value as string);
  }

  snapshot() {
    const routes = [...this.routes.entries()].map(([route, metric]) => ({
      route, requests: metric.requests, errors: metric.errors,
      averageDurationMs: metric.requests ? Math.round(metric.durationMs / metric.requests) : 0,
    })).sort((a, b) => b.requests - a.requests).slice(0, 25);
    return { requests: this.requests, errors: this.errors,
      errorRate: this.requests ? Number((this.errors / this.requests).toFixed(4)) : 0,
      averageDurationMs: this.requests ? Math.round(this.totalDurationMs / this.requests) : 0, routes };
  }

  async flush() {
    if (!this.pending.requests || this.flushing) return;
    this.flushing = true;
    const minute = new Date();
    minute.setSeconds(0, 0);
    const snapshot = this.pending;
    this.pending = { requests: 0, errors: 0, durationMs: 0, loginFailures: 0, mfaFailures: 0 };
    try {
      await this.prisma.operationsMetric.upsert({ where: { minute }, create: { minute, ...snapshot }, update: {
        requests: { increment: snapshot.requests }, errors: { increment: snapshot.errors }, durationMs: { increment: snapshot.durationMs },
        loginFailures: { increment: snapshot.loginFailures }, mfaFailures: { increment: snapshot.mfaFailures },
      } });
    } catch { this.logger.warn('Could not persist runtime metrics; this interval was dropped.'); }
    finally { this.flushing = false; }
  }
}
