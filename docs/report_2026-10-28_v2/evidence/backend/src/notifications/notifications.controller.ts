import { Body, Controller, Get, Param, Post, Query } from "@nestjs/common";

import { AuthRole } from "../common/auth-role";
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from "../common/current-user.decorator";
import { RequirePermissions } from "../common/permissions.decorator";
import { Roles } from "../common/roles.decorator";
import { NotificationsService } from "./notifications.service";

@Controller("notifications")
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @RequirePermissions("notification.view")
  list(@CurrentUser() user: AuthUser) {
    return this.notifications.list(landlordScopeId(user), user.userId);
  }

  @Post(":id/read")
  @RequirePermissions("notification.view")
  markRead(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.notifications.markRead(user.userId, id);
  }

  @Get("deliveries")
  @RequirePermissions("notification.view")
  deliveryLogs(@CurrentUser() user: AuthUser, @Query("take") take?: string) {
    return this.notifications.deliveryLogs(
      landlordScopeId(user),
      Number.parseInt(take ?? "50", 10) || 50,
    );
  }

  @Post("zalo/invoice-reminders")
  @RequirePermissions("notification.view")
  sendInvoiceRemindersZalo(
    @CurrentUser() user: AuthUser,
    @Query("propertyId") propertyId?: string,
    @Query("dueSoonDays") dueSoonDays?: string,
  ) {
    return this.notifications.sendInvoiceRemindersZalo(
      landlordScopeId(user),
      propertyId,
      dueSoonDays,
    );
  }

  @Post("zalo/test-message")
  @RequirePermissions("notification.view")
  createZaloTestMessage(@CurrentUser() user: AuthUser) {
    return this.notifications.createZaloTestMessage(landlordScopeId(user));
  }

  @Post("zalo/manual-message")
  @RequirePermissions("notification.view")
  createZaloManualMessage(
    @CurrentUser() user: AuthUser,
    @Body() input: { tenantId?: string; invoiceId?: string; message?: string },
  ) {
    return this.notifications.createZaloManualMessage(
      landlordScopeId(user),
      input,
    );
  }
}
