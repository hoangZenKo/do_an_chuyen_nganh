import { Module } from "@nestjs/common";

import { PrismaModule } from "../prisma/prisma.module";
import { NotificationsController } from "./notifications.controller";
import { NotificationsService } from "./notifications.service";
import { ZaloZnsService } from "./zalo-zns.service";
import { AnnouncementsController, TenantAnnouncementsController } from './announcements.controller';
import { AnnouncementsService } from './announcements.service';

@Module({
  imports: [PrismaModule],
  controllers: [NotificationsController, AnnouncementsController, TenantAnnouncementsController],
  providers: [NotificationsService, ZaloZnsService, AnnouncementsService],
  exports: [NotificationsService, AnnouncementsService],
})
export class NotificationsModule {}
