import { Controller, Get, HttpException, HttpStatus } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { SchemaReadinessService } from './schema-readiness.service';

@Controller('health')
export class HealthController {
  constructor(private readonly prisma: PrismaService, private readonly schema: SchemaReadinessService) {}

  @Get()
  async check() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'ok', database: 'ok', uptimeSec: Math.floor(process.uptime()) };
    } catch {
      throw new HttpException(
        { status: 'error', database: 'unavailable' },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }

  @Get('live') live() { return { status: 'ok' }; }

  @Get('ready') async ready() {
    try {
      if (!(await this.schema.inspect()).ready) throw new Error();
      return { status: 'ok', database: 'ok' };
    }
    catch { throw new HttpException({ status: 'error', database: 'unavailable' }, HttpStatus.SERVICE_UNAVAILABLE); }
  }

}
