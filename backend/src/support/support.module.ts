import { Module } from '@nestjs/common';
import { SupportController } from './support.controller';
import { PlatformNotificationService } from './platform-notification.service';
import { SupportService } from './support.service';
import { NotificationCenterController } from './notification-center.controller';
import { SupportToolsController } from './support-tools.controller';
import { SupportToolsService } from './support-tools.service';
import { SupportWorkflowController } from './support-workflow.controller';
import { SupportWorkflowService } from './support-workflow.service';
import { SupportAttachmentController } from './support-attachment.controller';
import { SupportAttachmentService } from './support-attachment.service';
import { MalwareScannerService } from '../uploads/malware-scanner.service';
import { NotificationDeliveryController } from './notification-delivery.controller';
import { NotificationDeliveryService } from './notification-delivery.service';
import { SupportSlaService } from './support-sla.service';
import { SupportSlaController } from './support-sla.controller';
import { SupportCaseService } from './support-case.service';
import { SupportCaseController } from './support-case.controller';

@Module({ controllers: [SupportController, NotificationCenterController, SupportToolsController, SupportWorkflowController, SupportAttachmentController, NotificationDeliveryController, SupportSlaController, SupportCaseController], providers: [PlatformNotificationService, SupportService, SupportToolsService, SupportWorkflowService, SupportAttachmentService, MalwareScannerService, NotificationDeliveryService, SupportSlaService, SupportCaseService], exports: [PlatformNotificationService, SupportService, SupportSlaService] })
export class SupportModule {}
