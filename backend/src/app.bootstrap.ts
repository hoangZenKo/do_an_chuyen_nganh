import { ValidationPipe } from '@nestjs/common';
import { INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Request, Response } from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import { UploadsService } from './uploads/uploads.service';
import { requestContext } from './common/request-context';
import { RuntimeMetricsService } from './health/runtime-metrics.service';
import { ApiErrorFilter } from './common/api-error.filter';

export function configureApp(app: INestApplication) {
  app.setGlobalPrefix('api/v1');
  app.use(helmet());
  app.use((req: Request, res: Response, next: () => void) => {
    const supplied = req.header('x-request-id');
    const requestId = supplied && /^[A-Za-z0-9._:-]{8,128}$/.test(supplied) ? supplied : randomUUID();
    res.setHeader('X-Request-ID', requestId);
    const started = Date.now();
    res.once('finish', () => {
      if (req.path.startsWith('/api/v1/health') || req.path.startsWith('/api/v1/admin/operations')) return;
      const route = req.route?.path ?? 'unmatched';
      const mfa = req.path === '/api/v1/auth/login' && typeof req.body?.mfaCode === 'string';
      app.get(RuntimeMetricsService).record(req.method, route, res.statusCode, Date.now() - started, mfa);
    });
    requestContext.run({ requestId, device: req.header('user-agent')?.slice(0, 256), ip: req.ip }, next);
  });
  app.use('/api/v1/admin', (_req: Request, res: Response, next: () => void) => { res.set('Cache-Control', 'private, no-store'); next(); });
  app.use('/api/v1/auth', (_req: Request, res: Response, next: () => void) => { res.set('Cache-Control', 'private, no-store'); next(); });
  app.use('/uploads', async (req: Request, res: Response) => {
    try {
      if (req.method !== 'GET' || !/^\/[a-zA-Z0-9_.-]+$/.test(req.path)) return res.sendStatus(404);
      const file = await app.get(UploadsService).read(req.path.slice(1), typeof req.query.access === 'string' ? req.query.access : undefined);
      res.set('Cache-Control', 'private, no-store');
      res.set('X-Content-Type-Options', 'nosniff');
      res.set('Content-Security-Policy', "default-src 'none'; sandbox");
      if (file.mime === 'application/pdf') res.set('Content-Disposition', `attachment; filename="${req.path.slice(1)}"`);
      res.type(file.mime).send(file.bytes);
    } catch { res.sendStatus(404); }
  });
  const origins = process.env.CORS_ORIGINS
    ?.split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (!origins?.length && process.env.NODE_ENV === 'production') {
    throw new Error('CORS_ORIGINS must be configured in production.');
  }
  app.enableCors({
    origin: origins?.length ? origins : true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new ApiErrorFilter());
  if (process.env.NODE_ENV !== 'production' || process.env.SWAGGER_ENABLED === 'true') {
    const document = SwaggerModule.createDocument(app, new DocumentBuilder()
      .setTitle('Rental Room Management API')
      .setDescription('API contract for rental operations and administration.')
      .setVersion('1.0')
      .addBearerAuth()
      .build());
    SwaggerModule.setup('docs', app, document, { jsonDocumentUrl: 'docs-json' });
  }
  return app;
}
