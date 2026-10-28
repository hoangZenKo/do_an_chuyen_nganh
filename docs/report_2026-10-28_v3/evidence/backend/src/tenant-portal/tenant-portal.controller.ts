import { Body, Controller, Get, Param, Post } from "@nestjs/common";

import { AuthRole } from "../common/auth-role";
import { AuthUser, CurrentUser } from "../common/current-user.decorator";
import { Roles } from "../common/roles.decorator";
import { CreateTenantMaintenanceDto } from "./dto/create-tenant-maintenance.dto";
import { CreateTenantZaloMessageDto } from "./dto/create-tenant-zalo-message.dto";
import { CreateMaintenanceCommentDto } from "../maintenance/dto/create-maintenance-comment.dto";
import { CreatePaymentProofDto } from "./dto/create-payment-proof.dto";
import { TenantPortalService } from "./tenant-portal.service";

@Controller("tenant")
@Roles(AuthRole.TENANT)
export class TenantPortalController {
  constructor(private readonly portal: TenantPortalService) {}

  @Get("me")
  me(@CurrentUser() user: AuthUser) {
    return this.portal.me(user.userId);
  }

  @Get("dashboard")
  dashboard(@CurrentUser() user: AuthUser) {
    return this.portal.dashboard(user.userId);
  }

  @Get("invoices")
  invoices(@CurrentUser() user: AuthUser) {
    return this.portal.invoices(user.userId);
  }

  @Get("leases")
  leases(@CurrentUser() user: AuthUser) {
    return this.portal.leases(user.userId);
  }

  @Get("invoices/:id")
  invoice(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.portal.invoice(user.userId, id);
  }

  @Get("notifications")
  notifications(@CurrentUser() user: AuthUser) {
    return this.portal.notifications(user.userId);
  }

  @Post("notifications/:id/read")
  markNotificationRead(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.portal.markNotificationRead(user.userId, id);
  }

  @Get("zalo-messages")
  zaloMessages(@CurrentUser() user: AuthUser) {
    return this.portal.zaloMessages(user.userId);
  }

  @Post("zalo-messages")
  createZaloMessage(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateTenantZaloMessageDto,
  ) {
    return this.portal.createZaloMessage(user.userId, input);
  }

  @Post("zalo-messages/:id/read")
  markZaloMessageRead(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.portal.markZaloMessageRead(user.userId, id);
  }

  @Post("invoices/:id/payment-proofs")
  submitPaymentProof(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: CreatePaymentProofDto,
  ) {
    return this.portal.submitPaymentProof(user.userId, id, input);
  }

  @Get("maintenance")
  maintenance(@CurrentUser() user: AuthUser) {
    return this.portal.maintenance(user.userId);
  }

  @Post("maintenance")
  createMaintenance(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateTenantMaintenanceDto,
  ) {
    return this.portal.createMaintenance(user.userId, input);
  }

  @Post("maintenance/:id/comments")
  addMaintenanceComment(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: CreateMaintenanceCommentDto,
  ) {
    return this.portal.addMaintenanceComment(user.userId, id, input);
  }
}
