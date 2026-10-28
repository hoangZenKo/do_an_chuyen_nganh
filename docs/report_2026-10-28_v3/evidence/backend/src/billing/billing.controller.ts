import { Body, Controller, Get, Param, Patch, Post, Put, Query } from "@nestjs/common";

import { AuditService } from "../audit/audit.service";
import { AuthRole } from "../common/auth-role";
import {
  AuthUser,
  CurrentUser,
  landlordScopeId,
} from "../common/current-user.decorator";
import { RequirePermissions } from "../common/permissions.decorator";
import { Roles } from "../common/roles.decorator";
import { NotificationsService } from "../notifications/notifications.service";
import { BillingService } from "./billing.service";
import {
  BillingAutomationPropertyDto,
  BillingAutomationRunDto,
  UpdateBillingAutomationDto,
} from "./dto/billing-automation.dto";
import { CancelInvoiceDto } from "./dto/cancel-invoice.dto";
import {
  BulkInvoicePreflightDto,
  CreateBulkInvoicesDto,
} from "./dto/create-bulk-invoices.dto";
import { CreateInvoiceDto } from "./dto/create-invoice.dto";
import { CreateMeterReadingDto } from "./dto/create-meter-reading.dto";
import { RecordPaymentDto } from "./dto/record-payment.dto";
import { UpdateInvoiceDto } from "./dto/update-invoice.dto";
import { ReviewPaymentProofDto } from "./dto/review-payment-proof.dto";
import { ReversePaymentDto } from "./dto/reverse-payment.dto";
import { AdjustmentDto, AgingQueryDto, AllocateReceiptDto, BillingReasonDto, CreateReceiptDto, RefundReceiptDto, ReminderPolicyDto, ReplaceInvoiceDto } from './dto/billing-ledger.dto';
import { BillingLedgerService } from './billing-ledger.service';
import { BillingRemindersService } from './billing-reminders.service';
import { BillingOutboxService } from './billing-outbox.service';
import { BillingTariffsService } from './billing-tariffs.service';
import { InvoicePreviewDto, LockBillingPeriodDto, ProposeTariffDto, ReviewTariffDto } from './dto/billing-tariffs.dto';

@Controller("billing")
@Roles(AuthRole.LANDLORD, AuthRole.STAFF)
export class BillingController {
  constructor(
    private readonly billing: BillingService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly ledger: BillingLedgerService,
    private readonly reminderPolicies: BillingRemindersService,
    private readonly outbox: BillingOutboxService,
    private readonly tariffs: BillingTariffsService,
  ) {}

  @Get("active-leases")
  @RequirePermissions("billing.view")
  activeLeases(@CurrentUser() user: AuthUser, @Query('month') month?: string) {
    return this.billing.activeLeases(landlordScopeId(user), month);
  }

  @Get("meter-readings")
  @RequirePermissions("billing.view")
  meterReadings(
    @CurrentUser() user: AuthUser,
    @Query("roomId") roomId?: string,
    @Query("month") month?: string,
  ) {
    return this.billing.listMeterReadings(landlordScopeId(user), roomId, month);
  }

  @Post("meter-readings")
  @RequirePermissions("billing.create")
  async createMeterReading(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateMeterReadingDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.createMeterReading(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.meter_reading_create",
      resourceType: "meter_reading",
      resourceId: result.data.id,
      summary: "Tạo chỉ số điện/nước",
      metadata: {
        roomId: result.data.roomId,
        utilityType: result.data.utilityType,
        amount: result.data.amount,
      },
    });
    return result;
  }

  @Get("invoices")
  @RequirePermissions("billing.view")
  invoices(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
    @Query("month") month?: string,
    @Query("propertyId") propertyId?: string,
    @Query("aging") aging?: string,
    @Query("dueSoonDays") dueSoonDays?: string,
  ) {
    return this.billing.listInvoices(
      landlordScopeId(user),
      status,
      month,
      propertyId,
      aging,
      dueSoonDays,
    );
  }

  @Get("reminders")
  @RequirePermissions("billing.view")
  reminders(
    @CurrentUser() user: AuthUser,
    @Query("propertyId") propertyId?: string,
    @Query("dueSoonDays") dueSoonDays?: string,
  ) {
    return this.billing.reminders(
      landlordScopeId(user),
      propertyId,
      dueSoonDays,
    );
  }

  @Post("reminders/run")
  @RequirePermissions("billing.policy")
  async runReminders(
    @CurrentUser() user: AuthUser,
    @Query("propertyId") propertyId?: string,
    @Query("dueSoonDays") dueSoonDays?: string,
  ) {
    const result = await this.reminderPolicies.enqueue(new Date(), landlordScopeId(user), propertyId);
    return { data: { total: result.data.queued, sent: 0, failed: 0, skipped: 0, queued: result.data.queued, results: [] } };
  }

  @Post("invoices/bulk/preflight")
  @RequirePermissions("billing.create")
  bulkInvoicePreflight(
    @CurrentUser() user: AuthUser,
    @Body() input: BulkInvoicePreflightDto,
  ) {
    return this.billing.bulkInvoicePreflight(landlordScopeId(user), input);
  }

  @Post("invoices/bulk")
  @RequirePermissions("billing.create")
  async createBulkInvoices(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateBulkInvoicesDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.createBulkInvoices(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.invoice_bulk_create",
      resourceType: "invoice",
      summary: `Tạo hàng loạt ${result.data.createdCount} hóa đơn`,
      metadata: {
        propertyId: result.data.propertyId,
        billingMonth: result.data.billingMonth,
        createdCount: result.data.createdCount,
        existingCount: result.data.existingCount,
      },
    });
    return result;
  }

  @Get("automation")
  @RequirePermissions("billing.view")
  billingAutomation(
    @CurrentUser() user: AuthUser,
    @Query() query: BillingAutomationPropertyDto,
  ) {
    return this.billing.billingAutomation(
      landlordScopeId(user),
      query.propertyId,
    );
  }

  @Put("automation")
  @RequirePermissions("billing.create")
  async updateBillingAutomation(
    @CurrentUser() user: AuthUser,
    @Body() input: UpdateBillingAutomationDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.updateBillingAutomation(
      landlordId,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.automation_update",
      resourceType: "billing_automation",
      resourceId: result.data.id || input.propertyId,
      summary: `${input.isEnabled ? "Bật" : "Tắt"} tự động lập hóa đơn`,
      metadata: {
        propertyId: input.propertyId,
        isEnabled: input.isEnabled,
        invoiceDay: input.invoiceDay,
        dueDay: input.dueDay,
      },
    });
    return result;
  }

  @Post("automation/preview")
  @RequirePermissions("billing.create")
  billingAutomationPreview(
    @CurrentUser() user: AuthUser,
    @Body() input: BillingAutomationRunDto,
  ) {
    return this.billing.billingAutomationPreview(landlordScopeId(user), input);
  }

  @Post("automation/run")
  @RequirePermissions("billing.create")
  async runBillingAutomation(
    @CurrentUser() user: AuthUser,
    @Body() input: BillingAutomationRunDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.runBillingAutomation(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.automation_run",
      resourceType: "invoice",
      summary: `Chạy tự động lập ${result.data.result.createdCount} hóa đơn`,
      metadata: {
        propertyId: input.propertyId,
        billingMonth: result.data.result.billingMonth,
        createdCount: result.data.result.createdCount,
        existingCount: result.data.result.existingCount,
      },
    });
    return result;
  }

  @Post("invoices")
  @RequirePermissions("billing.create")
  async createInvoice(
    @CurrentUser() user: AuthUser,
    @Body() input: CreateInvoiceDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.createInvoice(landlordId, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.invoice_create",
      resourceType: "invoice",
      resourceId: result.data.id,
      summary: `Tạo hóa đơn ${result.data.tenantName ?? ""}`.trim(),
      metadata: {
        leaseId: result.data.leaseId,
        totalAmount: result.data.totalAmount,
      },
    });
    return result;
  }

  @Get("invoices/:id")
  @RequirePermissions("billing.view")
  invoice(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.billing.getInvoice(landlordScopeId(user), id);
  }

  @Patch("invoices/:id")
  @RequirePermissions("billing.create")
  async updateInvoice(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: UpdateInvoiceDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.updateInvoice(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.invoice_update",
      resourceType: "invoice",
      resourceId: id,
      summary: "Cập nhật hóa đơn",
      metadata: { dueDate: input.dueDate ?? null },
    });
    return result;
  }

  @Post("invoices/:id/cancel")
  @RequirePermissions("billing.cancel")

  async cancelInvoice(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: CancelInvoiceDto,
  ) {
    const landlordId = landlordScopeId(user);
    return this.billing.cancelInvoice(landlordId, id, input, user);
  }

  @Post('invoices/:id/replacement')
  @RequirePermissions('billing.adjust')
  replaceInvoice(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: ReplaceInvoiceDto) {
    return this.ledger.replace(user, id, input);
  }

  @Post('invoices/:id/adjustments')
  @RequirePermissions('billing.adjust')
  adjustInvoice(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: AdjustmentDto) {
    return this.ledger.adjust(user, id, input);
  }

  @Get('aging')
  @RequirePermissions('billing.view')
  aging(@CurrentUser() user: AuthUser, @Query() query: AgingQueryDto) {
    return this.ledger.aging(user, query);
  }

  @Get('receipts')
  @RequirePermissions('billing.view')
  receipts(@CurrentUser() user: AuthUser, @Query('tenantId') tenantId?: string) {
    return this.ledger.receipts(user, tenantId);
  }

  @Post('receipts')
  @RequirePermissions('billing.record_payment')
  createReceipt(@CurrentUser() user: AuthUser, @Body() input: CreateReceiptDto) {
    return this.ledger.createReceipt(user, input);
  }

  @Post('receipts/:id/allocations')
  @RequirePermissions('billing.record_payment')
  allocateReceipt(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: AllocateReceiptDto) {
    return this.ledger.allocate(user, id, input);
  }

  @Post('receipts/:id/allocations/:allocationId/release')
  @RequirePermissions('billing.reverse_payment')
  releaseAllocation(@CurrentUser() user: AuthUser, @Param('id') id: string, @Param('allocationId') allocationId: string, @Body() input: BillingReasonDto) {
    return this.ledger.release(user, id, allocationId, input);
  }

  @Post('receipts/:id/refunds')
  @RequirePermissions('billing.refund')
  refundReceipt(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: RefundReceiptDto) {
    return this.ledger.refund(user, id, input);
  }

  @Get('reminder-policy')
  @RequirePermissions('billing.policy')
  reminderPolicy(@CurrentUser() user: AuthUser, @Query('propertyId') propertyId?: string) {
    return this.reminderPolicies.policy(user, propertyId);
  }

  @Put('reminder-policy')
  @RequirePermissions('billing.policy')
  updateReminderPolicy(@CurrentUser() user: AuthUser, @Body() input: ReminderPolicyDto) {
    return this.reminderPolicies.save(user, input);
  }

  @Post('reminders/enqueue')
  @RequirePermissions('billing.policy')
  enqueueReminders(@CurrentUser() user: AuthUser, @Query('propertyId') propertyId?: string) {
    return this.reminderPolicies.enqueue(new Date(), landlordScopeId(user), propertyId);
  }

  @Get('outbox')
  @RequirePermissions('billing.view')
  outboxEvents(@CurrentUser() user: AuthUser) {
    return this.outbox.list(user);
  }

  @Post('outbox/:id/retry')
  @RequirePermissions('billing.policy')
  retryOutbox(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: BillingReasonDto) {
    return this.outbox.retry(user, id, input);
  }

  @Get('tariffs')
  @RequirePermissions('billing.view')
  tariffsList(@CurrentUser() user: AuthUser, @Query('propertyId') propertyId: string) {
    return this.tariffs.list(user, propertyId);
  }

  @Post('tariffs/proposals')
  @RequirePermissions('billing.create')
  proposeTariff(@CurrentUser() user: AuthUser, @Body() input: ProposeTariffDto) {
    return this.tariffs.propose(user, input);
  }

  @Get('tariffs/:id/impact')
  @RequirePermissions('billing.view')
  tariffImpact(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.tariffs.impact(user, id);
  }

  @Post('tariffs/:id/review')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('billing.tariff_approve')
  reviewTariff(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() input: ReviewTariffDto) {
    return this.tariffs.review(user, id, input);
  }

  @Post('period-locks')
  @Roles(AuthRole.LANDLORD)
  @RequirePermissions('billing.tariff_approve')
  lockPeriod(@CurrentUser() user: AuthUser, @Body() input: LockBillingPeriodDto) {
    return this.tariffs.lockPeriod(user, input);
  }

  @Post('invoices/preview')
  @RequirePermissions('billing.view')
  previewInvoice(@CurrentUser() user: AuthUser, @Body() input: InvoicePreviewDto) {
    return this.tariffs.preview(user, input);
  }

  @Post("invoices/:id/payments")
  @RequirePermissions("billing.record_payment")
  async recordPayment(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: RecordPaymentDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.recordPayment(landlordId, id, input);
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.payment_record",
      resourceType: "invoice",
      resourceId: id,
      summary: `Ghi nhận thanh toán ${input.amount}`,
      metadata: { amount: input.amount, method: input.method },
    });
    return result;
  }

  @Get("payment-proofs")
  @RequirePermissions("billing.view")
  paymentProofs(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
  ) {
    return this.billing.listPaymentProofs(landlordScopeId(user), status);
  }

  @Post("payment-proofs/:id/review")
  @RequirePermissions("billing.approve_payment_proof")
  async reviewPaymentProof(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() input: ReviewPaymentProofDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.reviewPaymentProof(
      landlordId,
      id,
      user.userId,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.payment_proof_review",
      resourceType: "payment_proof",
      resourceId: id,
      summary: `${input.status === "approved" ? "Duyệt" : "Từ chối"} bằng chứng thanh toán`,
      metadata: { status: input.status },
    });
    return result;
  }

  @Post("invoices/:invoiceId/payments/:paymentId/reverse")
  @RequirePermissions("billing.reverse_payment")
  async reversePayment(
    @CurrentUser() user: AuthUser,
    @Param("invoiceId") invoiceId: string,
    @Param("paymentId") paymentId: string,
    @Body() input: ReversePaymentDto,
  ) {
    const landlordId = landlordScopeId(user);
    const result = await this.billing.reversePayment(
      landlordId,
      invoiceId,
      paymentId,
      input,
    );
    await this.audit.recordSafe({
      landlordId,
      actor: user,
      action: "billing.payment_reverse",
      resourceType: "invoice",
      resourceId: invoiceId,
      summary: "Đảo thanh toán",
      metadata: { paymentId, note: input.note ?? null },
    });
    return result;
  }
}
