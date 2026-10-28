import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  InvoiceStatus,
  LeaseStatus,
  MaintenancePriority,
  MaintenanceStatus,
  NotificationDeliveryChannel,
  NotificationDeliveryStatus,
  PaymentProofStatus,
} from "@prisma/client";

import { PrismaService } from "../prisma/prisma.service";
import { ZaloZnsService } from "./zalo-zns.service";

export interface LandlordNotification {
  id: string;
  kind: string;
  severity: "info" | "warning" | "danger";
  title: string;
  body: string;
  resourceType: string;
  resourceId: string;
  actionRoute: string;
  dueAt?: Date | null;
  createdAt: Date;
}

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly zalo: ZaloZnsService,
  ) {}

  async list(landlordId: string, userId: string) {
    const items = await this.buildItems(landlordId);
    const reads = await this.prisma.notificationRead.findMany({
      where: { userId, notificationId: { in: items.map((item) => item.id) } },
    });
    const readIds = new Set(reads.map((read) => read.notificationId));
    return {
      data: items.map((item) => ({
        ...this.serialize(item),
        isRead: readIds.has(item.id),
      })),
      summary: {
        total: items.length,
        unread: items.filter((item) => !readIds.has(item.id)).length,
      },
    };
  }

  async markRead(userId: string, notificationId: string) {
    await this.prisma.notificationRead.upsert({
      where: { userId_notificationId: { userId, notificationId } },
      create: { userId, notificationId },
      update: { readAt: new Date() },
    });
    return { data: { notificationId, isRead: true } };
  }

  async deliveryLogs(landlordId: string, take = 50) {
    const deliveries = await this.prisma.notificationDelivery.findMany({
      where: { landlordId },
      orderBy: { createdAt: "desc" },
      take: Math.min(Math.max(take, 1), 100),
    });
    return {
      data: deliveries.map((delivery) => ({
        ...delivery,
        sentAt: delivery.sentAt?.toISOString() ?? null,
        createdAt: delivery.createdAt.toISOString(),
        updatedAt: delivery.updatedAt.toISOString(),
      })),
    };
  }

  async sendInvoiceRemindersZalo(
    landlordId: string,
    propertyId?: string,
    dueSoonDays?: string,
  ) {
    const templateId = this.zalo.invoiceReminderTemplateId;
    const candidates = await this.invoiceReminderCandidates(
      landlordId,
      propertyId,
      dueSoonDays,
    );
    const results = [];

    for (const invoice of candidates) {
      const rawPhone = invoice.tenant?.phone ?? "";
      const phone = this.normalizeVietnamPhone(rawPhone);
      const remainingAmount = Math.max(
        invoice.totalAmount - invoice.paidAmount,
        0,
      );
      const payload = {
        tenant_name: invoice.tenant?.fullName ?? "anh/chị",
        room_name: invoice.room?.name ?? invoice.roomId,
        billing_month: `${invoice.billingMonth.getUTCMonth() + 1}/${invoice.billingMonth.getUTCFullYear()}`,
        amount: remainingAmount,
        due_date: invoice.dueDate?.toISOString().slice(0, 10) ?? "",
        invoice_url: this.invoiceUrl(invoice.id),
      };
      const delivery = await this.prisma.notificationDelivery.create({
        data: {
          landlordId,
          tenantId: invoice.tenantId,
          invoiceId: invoice.id,
          channel: NotificationDeliveryChannel.ZALO,
          purpose: "invoice_reminder",
          recipient: phone ?? rawPhone,
          templateId,
          payload,
          status: NotificationDeliveryStatus.PENDING,
        },
      });

      if (!phone) {
        results.push(
          await this.markDeliverySkipped(
            delivery.id,
            "TENANT_PHONE_MISSING",
            "Tenant phone is missing or invalid.",
          ),
        );
        continue;
      }
      if (!templateId) {
        results.push(
          await this.markDeliverySkipped(
            delivery.id,
            "ZALO_ZNS_TEMPLATE_MISSING",
            "ZALO_ZNS_INVOICE_REMINDER_TEMPLATE_ID is missing.",
          ),
        );
        continue;
      }

      const result = await this.zalo.sendTemplate({
        phone,
        templateId,
        templateData: payload,
        trackingId: delivery.id,
      });
      results.push(
        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: result.ok
            ? {
                status: NotificationDeliveryStatus.SENT,
                providerMessageId: result.providerMessageId ?? null,
                sentAt: new Date(),
              }
            : {
                status: NotificationDeliveryStatus.FAILED,
                errorCode: result.errorCode ?? null,
                errorMessage: result.errorMessage ?? null,
              },
        }),
      );
    }

    return {
      data: {
        total: results.length,
        sent: results.filter(
          (item) => item.status === NotificationDeliveryStatus.SENT,
        ).length,
        failed: results.filter(
          (item) => item.status === NotificationDeliveryStatus.FAILED,
        ).length,
        skipped: results.filter(
          (item) => item.status === NotificationDeliveryStatus.SKIPPED,
        ).length,
        results: results.map((item) => ({
          id: item.id,
          invoiceId: item.invoiceId,
          tenantId: item.tenantId,
          recipient: item.recipient,
          status: item.status.toLowerCase(),
          errorCode: item.errorCode,
          errorMessage: item.errorMessage,
          sentAt: item.sentAt?.toISOString() ?? null,
        })),
      },
    };
  }

  async createZaloTestMessage(landlordId: string) {
    const tenant = await this.prisma.tenant.findFirst({
      where: {
        landlordId,
        isActive: true,
        userId: { not: null },
      },
      orderBy: { createdAt: "desc" },
      include: {
        leases: {
          orderBy: { startDate: "desc" },
          include: { room: { select: { id: true, name: true } } },
        },
      },
    });
    if (!tenant) {
      throw new ConflictException({
        error: {
          code: "TENANT_ACCOUNT_REQUIRED",
          message:
            "Create and activate a tenant account before creating a Zalo test message.",
        },
      });
    }

    const invoice = await this.prisma.invoice.findFirst({
      where: {
        tenantId: tenant.id,
        isDemo: false,
        status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
      },
      orderBy: [{ dueDate: "asc" }, { issuedAt: "desc" }],
      include: { room: { select: { id: true, name: true } } },
    });
    const lease =
      tenant.leases.find((item) => item.status === LeaseStatus.ACTIVE) ??
      tenant.leases[0];
    const dueDate = invoice?.dueDate ?? this.addDays(new Date(), 3);
    const billingMonth = invoice?.billingMonth ?? new Date();
    const remainingAmount = invoice
      ? Math.max(invoice.totalAmount - invoice.paidAmount, 0)
      : lease?.monthlyRent ?? 0;
    const payload = {
      tenant_name: tenant.fullName,
      room_name: invoice?.room?.name ?? lease?.room?.name ?? "Phòng",
      billing_month: `${billingMonth.getUTCMonth() + 1}/${billingMonth.getUTCFullYear()}`,
      amount: remainingAmount,
      due_date: dueDate.toISOString().slice(0, 10),
      invoice_url: invoice ? this.invoiceUrl(invoice.id) : "",
    };
    const recipient = this.normalizeVietnamPhone(tenant.phone ?? "") ??
      tenant.phone ??
      "zalo-mock";
    const delivery = await this.prisma.notificationDelivery.create({
      data: {
        landlordId,
        tenantId: tenant.id,
        invoiceId: invoice?.id ?? null,
        channel: NotificationDeliveryChannel.ZALO,
        purpose: "zalo_mock_test",
        recipient,
        payload,
        status: NotificationDeliveryStatus.SENT,
        providerMessageId: `mock-${Date.now()}`,
        sentAt: new Date(),
      },
    });
    return {
      data: {
        id: delivery.id,
        tenantId: delivery.tenantId,
        invoiceId: delivery.invoiceId,
        recipient: delivery.recipient,
        status: delivery.status.toLowerCase(),
        sentAt: delivery.sentAt?.toISOString() ?? null,
      },
    };
  }

  async createZaloManualMessage(
    landlordId: string,
    input: { tenantId?: string; invoiceId?: string; message?: string },
  ) {
    const message = input.message?.trim();
    if (!message) {
      throw new BadRequestException({
        error: {
          code: "MESSAGE_REQUIRED",
          message: "Message content is required.",
        },
      });
    }
    if (!input.tenantId) {
      throw new BadRequestException({
        error: {
          code: "TENANT_ID_REQUIRED",
          message: "Tenant id is required.",
        },
      });
    }

    const tenant = await this.prisma.tenant.findFirst({
      where: { id: input.tenantId, landlordId, isActive: true },
      include: {
        leases: {
          orderBy: { startDate: "desc" },
          include: { room: { select: { id: true, name: true } } },
        },
      },
    });
    if (!tenant) {
      throw new NotFoundException({
        error: {
          code: "TENANT_NOT_FOUND",
          message: "Tenant not found.",
        },
      });
    }

    const invoice = input.invoiceId
      ? await this.prisma.invoice.findFirst({
          where: { id: input.invoiceId, tenantId: tenant.id, isDemo: false },
          include: { room: { select: { id: true, name: true } } },
        })
      : await this.prisma.invoice.findFirst({
          where: { tenantId: tenant.id, isDemo: false },
          orderBy: [{ issuedAt: "desc" }],
          include: { room: { select: { id: true, name: true } } },
        });
    if (input.invoiceId && !invoice) {
      throw new NotFoundException('Không gửi nhắc tiền thật cho hóa đơn demo hoặc hóa đơn không thuộc người thuê.');
    }
    const lease =
      tenant.leases.find((item) => item.status === LeaseStatus.ACTIVE) ??
      tenant.leases[0];
    const billingMonth = invoice?.billingMonth ?? new Date();
    const dueDate = invoice?.dueDate ?? this.addDays(new Date(), 3);
    const payload = {
      message_text: message,
      tenant_name: tenant.fullName,
      room_name: invoice?.room?.name ?? lease?.room?.name ?? "Phòng",
      billing_month: `${billingMonth.getUTCMonth() + 1}/${billingMonth.getUTCFullYear()}`,
      amount: invoice
        ? Math.max(invoice.totalAmount - invoice.paidAmount, 0)
        : lease?.monthlyRent ?? 0,
      due_date: dueDate.toISOString().slice(0, 10),
      invoice_url: invoice ? this.invoiceUrl(invoice.id) : "",
    };
    const recipient = this.normalizeVietnamPhone(tenant.phone ?? "") ??
      tenant.phone ??
      "zalo-mock";
    const delivery = await this.prisma.notificationDelivery.create({
      data: {
        landlordId,
        tenantId: tenant.id,
        invoiceId: invoice?.id ?? null,
        channel: NotificationDeliveryChannel.ZALO,
        purpose: "zalo_manual_message",
        recipient,
        payload,
        status: NotificationDeliveryStatus.SENT,
        providerMessageId: `manual-${Date.now()}`,
        sentAt: new Date(),
      },
    });
    return {
      data: {
        ...delivery,
        sentAt: delivery.sentAt?.toISOString() ?? null,
        createdAt: delivery.createdAt.toISOString(),
        updatedAt: delivery.updatedAt.toISOString(),
      },
    };
  }

  async buildItems(landlordId: string): Promise<LandlordNotification[]> {
    const today = this.dayStart(new Date());
    const sevenDays = this.addDays(today, 7);
    const thirtyDays = this.addDays(today, 30);
    const [
      overdueInvoices,
      dueSoonInvoices,
      pendingProofs,
      urgentTickets,
      expiringLeases,
      dueInspections,
    ] = await this.prisma.$transaction([
      this.prisma.invoice.findMany({
        where: {
          isDemo: false,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
          dueDate: { lt: today },
          room: { property: { landlordId } },
        },
        include: {
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
        orderBy: { dueDate: "asc" },
        take: 20,
      }),
      this.prisma.invoice.findMany({
        where: {
          isDemo: false,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
          dueDate: { gte: today, lte: sevenDays },
          room: { property: { landlordId } },
        },
        include: {
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
        orderBy: { dueDate: "asc" },
        take: 20,
      }),
      this.prisma.paymentProof.findMany({
        where: {
          status: PaymentProofStatus.PENDING,
          invoice: { isDemo: false, room: { property: { landlordId } } },
        },
        include: {
          invoice: {
            select: {
              id: true,
              room: { select: { name: true } },
              tenant: { select: { fullName: true } },
            },
          },
        },
        orderBy: { submittedAt: "asc" },
        take: 20,
      }),
      this.prisma.maintenanceTicket.findMany({
        where: {
          landlordId,
          OR: [{ priority: MaintenancePriority.URGENT }, { dueAt: { lt: new Date() } }],
          status: {
            in: [MaintenanceStatus.OPEN, MaintenanceStatus.IN_PROGRESS],
          },
        },
        include: { room: { select: { name: true } } },
        orderBy: { reportedAt: "asc" },
        take: 20,
      }),
      this.prisma.lease.findMany({
        where: {
          status: "ACTIVE",
          endDate: { gte: today, lte: thirtyDays },
          room: { property: { landlordId } },
        },
        include: {
          room: { select: { name: true } },
          tenant: { select: { fullName: true } },
        },
        orderBy: { endDate: "asc" },
        take: 20,
      }),
      this.prisma.roomInspection.findMany({
        where: {
          completedAt: null,
          dueAt: { lte: sevenDays },
          room: { property: { landlordId } },
        },
        include: { room: { select: { name: true } } },
        orderBy: { dueAt: "asc" },
        take: 20,
      }),
    ]);

    const items: LandlordNotification[] = [
      ...overdueInvoices.map((invoice) => ({
        id: `invoice-overdue-${invoice.id}`,
        kind: "invoice_overdue",
        severity: "danger" as const,
        title: "Hóa đơn quá hạn",
        body: `${invoice.tenant?.fullName ?? "Tenant"} - ${invoice.room?.name ?? "Phòng"} còn ${Math.max(invoice.totalAmount - invoice.paidAmount, 0).toLocaleString("vi-VN")} đ`,
        resourceType: "invoice",
        resourceId: invoice.id,
        actionRoute: `/billing/${invoice.id}`,
        dueAt: invoice.dueDate,
        createdAt: invoice.dueDate ?? invoice.issuedAt,
      })),
      ...dueSoonInvoices.map((invoice) => ({
        id: `invoice-due-soon-${invoice.id}`,
        kind: "invoice_due_soon",
        severity: "warning" as const,
        title: "Hóa đơn sắp đến hạn",
        body: `${invoice.tenant?.fullName ?? "Tenant"} - ${invoice.room?.name ?? "Phòng"} còn ${Math.max(invoice.totalAmount - invoice.paidAmount, 0).toLocaleString("vi-VN")} đ`,
        resourceType: "invoice",
        resourceId: invoice.id,
        actionRoute: `/billing/${invoice.id}`,
        dueAt: invoice.dueDate,
        createdAt: invoice.dueDate ?? invoice.issuedAt,
      })),
      ...pendingProofs.map((proof) => ({
        id: `payment-proof-pending-${proof.id}`,
        kind: "payment_proof_pending",
        severity: "warning" as const,
        title: "Chứng từ thanh toán chờ duyệt",
        body: `${proof.invoice.tenant?.fullName ?? "Tenant"} gửi ${proof.amount.toLocaleString("vi-VN")} đ`,
        resourceType: "payment_proof",
        resourceId: proof.id,
        actionRoute: `/billing/${proof.invoice.id}`,
        dueAt: null,
        createdAt: proof.submittedAt,
      })),
      ...urgentTickets.map((ticket) => ({
        id: `${ticket.dueAt && ticket.dueAt < new Date() ? 'maintenance-sla' : 'maintenance-urgent'}-${ticket.id}`,
        kind: "maintenance_urgent",
        severity: "danger" as const,
        title: ticket.dueAt && ticket.dueAt < new Date() ? "Bảo trì quá hạn SLA" : "Bảo trì khẩn cấp",
        body: `${ticket.room?.name ?? "Phòng"} - ${ticket.title}`,
        resourceType: "maintenance_ticket",
        resourceId: ticket.id,
        actionRoute: "/maintenance",
        dueAt: ticket.dueAt,
        createdAt: ticket.reportedAt,
      })),
      ...expiringLeases.map((lease) => ({
        id: `lease-expiring-${lease.id}`,
        kind: "lease_expiring",
        severity: "warning" as const,
        title: "Hợp đồng sắp hết hạn",
        body: `${lease.tenant?.fullName ?? "Tenant"} - ${lease.room?.name ?? "Phòng"}`,
        resourceType: "lease",
        resourceId: lease.id,
        actionRoute: "/lease-expiry",
        dueAt: lease.endDate,
        createdAt: lease.endDate ?? lease.updatedAt,
      })),
      ...dueInspections.map((inspection) => ({
        id: `room-inspection-due-${inspection.id}`,
        kind: "room_inspection_due",
        severity:
          inspection.dueAt < today ? ("danger" as const) : ("info" as const),
        title:
          inspection.dueAt < today
            ? "Lịch kiểm tra quá hạn"
            : "Sắp đến lịch kiểm tra",
        body: `${inspection.room.name} - ${inspection.title}`,
        resourceType: "room_inspection",
        resourceId: inspection.id,
        actionRoute: `/rooms/${inspection.roomId}`,
        dueAt: inspection.dueAt,
        createdAt: inspection.dueAt,
      })),
    ];

    return items.sort((a, b) => {
      const severityOrder = { danger: 0, warning: 1, info: 2 };
      const severity = severityOrder[a.severity] - severityOrder[b.severity];
      if (severity !== 0) return severity;
      return (
        (a.dueAt ?? a.createdAt).getTime() - (b.dueAt ?? b.createdAt).getTime()
      );
    });
  }

  private serialize(item: LandlordNotification) {
    return {
      ...item,
      dueAt: item.dueAt?.toISOString() ?? null,
      createdAt: item.createdAt.toISOString(),
    };
  }

  private dayStart(date: Date) {
    return new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
  }

  private addDays(date: Date, days: number) {
    return new Date(
      Date.UTC(
        date.getUTCFullYear(),
        date.getUTCMonth(),
        date.getUTCDate() + days,
      ),
    );
  }

  private async invoiceReminderCandidates(
    landlordId: string,
    propertyId?: string,
    dueSoonDays?: string,
  ) {
    const today = this.dayStart(new Date());
    const windowDays = Math.min(
      Math.max(Number.parseInt(dueSoonDays ?? "7", 10) || 7, 0),
      60,
    );
    const dueSoonEnd = this.addDays(today, windowDays);
    return this.prisma.invoice.findMany({
      where: {
        isDemo: false,
        status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
        dueDate: { lte: dueSoonEnd },
        room: {
          property: {
            landlordId,
            ...(propertyId ? { id: propertyId } : {}),
          },
        },
      },
      include: {
        room: { select: { id: true, name: true } },
        tenant: { select: { id: true, fullName: true, phone: true } },
      },
      orderBy: [{ dueDate: "asc" }, { issuedAt: "desc" }],
      take: 100,
    });
  }

  private async markDeliverySkipped(
    id: string,
    errorCode: string,
    errorMessage: string,
  ) {
    return this.prisma.notificationDelivery.update({
      where: { id },
      data: {
        status: NotificationDeliveryStatus.SKIPPED,
        errorCode,
        errorMessage,
      },
    });
  }

  private normalizeVietnamPhone(phone: string) {
    const digits = phone.replace(/\D/g, "");
    if (!digits) return null;
    if (digits.startsWith("84") && digits.length >= 10) return digits;
    if (digits.startsWith("0") && digits.length >= 10) {
      return `84${digits.slice(1)}`;
    }
    if (digits.length >= 9) return digits;
    return null;
  }

  private invoiceUrl(invoiceId: string) {
    const baseUrl = process.env.APP_PUBLIC_BASE_URL?.trim();
    if (!baseUrl) return "";
    return `${baseUrl.replace(/\/$/, "")}/tenant/invoices/${invoiceId}`;
  }
}
