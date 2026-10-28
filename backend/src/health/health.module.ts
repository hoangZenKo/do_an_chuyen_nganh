import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { RuntimeMetricsService } from './runtime-metrics.service';
import { PrismaModule } from '../prisma/prisma.module';
import { OperationsHealthService } from './operations-health.service';
import { IncidentWorkflowService } from './incident-workflow.service';
import { IncidentWorkflowController } from './incident-workflow.controller';
import { SchemaReadinessService } from './schema-readiness.service';
import { OperationsQueueController } from './operations-queue.controller';
import { OperationsQueueService } from './operations-queue.service';
import { BackupTelemetryService } from './backup-telemetry.service';

@Module({ imports: [PrismaModule], controllers: [HealthController, IncidentWorkflowController, OperationsQueueController], providers: [RuntimeMetricsService, OperationsHealthService, IncidentWorkflowService, SchemaReadinessService, OperationsQueueService, BackupTelemetryService], exports: [RuntimeMetricsService, OperationsHealthService] })
export class HealthModule {}
