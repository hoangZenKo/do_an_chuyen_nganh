import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Invoice,
  InvoiceStatus,
  LeaseStatus,
  MaintenancePriority,
  MaintenanceStatus,
  NotificationDeliveryChannel,
  NotificationDeliveryStatus,
  PaymentMethod,
  PaymentProofStatus,
  UserRole,
  MaintenanceTicket,
  Payment,
  Prisma,
} from "@prisma/client";

import { PrismaService } from "../prisma/prisma.service";
import { CreateMaintenanceCommentDto } from "../maintenance/dto/create-maintenance-comment.dto";
import { CreatePaymentProofDto } from "./dto/create-payment-proof.dto";
import { CreateTenantMaintenanceDto } from "./dto/create-tenant-maintenance.dto";
import { CreateTenantZaloMessageDto } from "./dto/create-tenant-zalo-message.dto";
import { serializeInvoiceLines } from "../billing/invoice-lines";
import { commandHash } from '../billing/billing-rules';

type TenantProfile = Awaited<ReturnType<TenantPortalService["tenantProfile"]>>;

type InvoiceWithRelations = Invoice & {
  lineItems?: import("@prisma/client").InvoiceLineItem[];
  payments?: Payment[];
  paymentProofs?: Array<{
    id: string;
    invoiceId: string;
    tenantId: string;
    amount: number;
    method: PaymentMethod;
    note: string | null;
    proofImageUrls: string[];
    status: PaymentProofStatus;
    submittedAt: Date;
    reviewedAt: Date | null;
    reviewedById: string | null;
    reviewNote: string | null;
  }>;
  room?: {
    id: string;
    name: string;
    property?: { id: string; name: string } | null;
  } | null;
  tenant?: { id: string; fullName: string } | null;
};

type TicketWithRelations = MaintenanceTicket & {
  property?: { id: string; name: string } | null;
  room?: { id: string; name: string } | null;
  comments?: Array<{
    id: string;
    ticketId: string;
    authorId: string;
    authorRole: UserRole;
    body: string;
    imageUrls: string[];
    createdAt: Date;
    author?: { id: string; fullName: string; role: UserRole } | null;
  }>;
};

const tenantProfileNotFound = () =>
  new NotFoundException({
    error: {
      code: "TENANT_PROFILE_NOT_FOUND",
      message: "Tenant profile not found for this account.",
    },
  });

const activeLeaseRequired = () =>
  new ConflictException({
    error: {
      code: "ACTIVE_LEASE_REQUIRED",
      message: "An active lease is required for this tenant action.",
    },
  });

@Injectable()
export class TenantPortalService {
  constructor(private readonly prisma: PrismaService) {}

  async me(userId: string) {
    const tenant = await this.tenantProfile(userId);
    return { data: this.serializeTenantProfile(tenant) };
  }

  async dashboard(userId: string) {
    const tenant = await this.tenantProfile(userId);
    const [invoices, tickets, notifications] = await Promise.all([
      this.prisma.invoice.findMany({
        where: {
          tenantId: tenant.id,
          isDemo: false,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
        },
        orderBy: [{ dueDate: "asc" }, { issuedAt: "desc" }],
        include: this.invoiceInclude,
      }),
      this.prisma.maintenanceTicket.findMany({
        where: {
          ...this.maintenanceScope(tenant),
          status: {
            in: [MaintenanceStatus.OPEN, MaintenanceStatus.IN_PROGRESS],
          },
        },
        orderBy: { updatedAt: "desc" },
        take: 5,
        include: this.ticketInclude,
      }),
      this.notifications(userId),
    ]);
    const notificationData = notifications as {
      data: Array<{ read?: boolean }>;
      summary?: { unreadCount?: number };
    };
    const outstandingAmount = invoices.reduce(
      (sum, invoice) =>
        sum + Math.max(invoice.totalAmount - invoice.paidAmount, 0),
      0,
    );
    return {
      data: {
        profile: this.serializeTenantProfile(tenant),
        outstandingAmount,
        openInvoiceCount: invoices.length,
        overdueInvoiceCount: invoices.filter(
          (invoice) => this.daysOverdue(invoice) > 0,
        ).length,
        dueSoonInvoiceCount: invoices.filter((invoice) => {
          const days = this.daysUntilDue(invoice);
          return days !== null && days >= 0 && days <= 7;
        }).length,
        openMaintenanceCount: tickets.length,
        unreadNotificationCount:
          notificationData.summary?.unreadCount ??
          notificationData.data.filter((item) => item.read !== true).length,
        nextInvoice: invoices[0] ? this.serializeInvoice(invoices[0]) : null,
        recentMaintenance: tickets.map((ticket) =>
          this.serializeTicket(ticket),
        ),
      },
    };
  }

  async invoices(userId: string) {
    const tenant = await this.tenantProfile(userId);
    const invoices = await this.prisma.invoice.findMany({
      where: { tenantId: tenant.id },
      orderBy: [{ billingMonth: "desc" }, { issuedAt: "desc" }],
      include: this.invoiceInclude,
    });
    return { data: invoices.map((invoice) => this.serializeInvoice(invoice)) };
  }

  async invoice(userId: string, invoiceId: string) {
    const tenant = await this.tenantProfile(userId);
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: invoiceId, tenantId: tenant.id },
      include: this.invoiceInclude,
    });
    if (!invoice) {
      throw new NotFoundException({
        error: { code: "INVOICE_NOT_FOUND", message: "Invoice not found." },
      });
    }
    return { data: this.serializeInvoice(invoice) };
  }

  async leases(userId: string) {
    const tenant = await this.tenantProfile(userId);
    return {
      data: tenant.leases.map((lease) => this.serializeLease(lease)),
    };
  }

  async notifications(userId: string) {
    const tenant = await this.tenantProfile(userId);
    const [invoices, tickets, reads, billingNotifications] = await this.prisma.$transaction([
      this.prisma.invoice.findMany({
        where: {
          tenantId: tenant.id,
          isDemo: false,
          status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
        },
        orderBy: [{ dueDate: "asc" }, { issuedAt: "desc" }],
      }),
      this.prisma.maintenanceTicket.findMany({
        where: this.maintenanceScope(tenant),
        orderBy: { updatedAt: "desc" },
        take: 5,
      }),
      this.prisma.notificationRead.findMany({ where: { userId } }),
      this.prisma.billingNotification.findMany({
        where: { tenantId: tenant.id },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
    ]);
    const readIds = new Set(reads.map((item) => item.notificationId));
    const notifications = [
      ...invoices
        .filter((invoice) => this.daysOverdue(invoice) > 0)
        .map((invoice) => ({
          id: `invoice-overdue-${invoice.id}`,
          kind: "invoice_overdue",
          title: "Hóa đơn quá hạn",
          body: `Còn nợ ${Math.max(invoice.totalAmount - invoice.paidAmount, 0)} đ`,
          invoiceId: invoice.id,
          createdAt: (invoice.dueDate ?? invoice.issuedAt).toISOString(),
        })),
      ...invoices
        .filter((invoice) => {
          const days = this.daysUntilDue(invoice);
          return days !== null && days >= 0 && days <= 7;
        })
        .map((invoice) => ({
          id: `invoice-due-${invoice.id}`,
          kind: "invoice_due_soon",
          title: "Hóa đơn sắp đến hạn",
          body: `Hạn thanh toán ${invoice.dueDate?.toISOString() ?? ""}`,
          invoiceId: invoice.id,
          createdAt: invoice.issuedAt.toISOString(),
        })),
      ...tickets.map((ticket) => ({
        id: `maintenance-${ticket.id}`,
        kind: "maintenance_status",
        title: ticket.title,
        body: ticket.status.toLowerCase(),
        maintenanceId: ticket.id,
        createdAt: ticket.updatedAt.toISOString(),
      })),
      ...billingNotifications.map((notification) => ({
        id: notification.eventKey,
        kind: 'billing_reminder',
        title: notification.title,
        body: notification.body,
        invoiceId: notification.invoiceId,
        createdAt: notification.createdAt.toISOString(),
        read: notification.readAt !== null,
      })),
    ]
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt))
      .slice(0, 12)
      .map((item) => ({ ...item, read: ('read' in item && item.read === true) || readIds.has(item.id) }));
    return {
      data: notifications,
      summary: {
        count: notifications.length,
        unreadCount: notifications.filter((item) => !item.read).length,
      },
    };
  }

  async markNotificationRead(userId: string, notificationId: string) {
    await this.prisma.billingNotification.updateMany({
      where: { eventKey: notificationId, tenant: { userId } },
      data: { readAt: new Date() },
    });
    await this.prisma.notificationRead.upsert({
      where: { userId_notificationId: { userId, notificationId } },
      create: { userId, notificationId },
      update: { readAt: new Date() },
    });
    return { data: { notificationId, read: true } };
  }

  async zaloMessages(userId: string) {
    const tenant = await this.tenantProfile(userId);
    const deliveries = await this.prisma.notificationDelivery.findMany({
      where: { tenantId: tenant.id, channel: NotificationDeliveryChannel.ZALO },
      orderBy: { createdAt: "desc" },
      take: 100,
    });
    const reads = await this.prisma.notificationRead.findMany({
      where: {
        userId,
        notificationId: { in: deliveries.map((delivery) => delivery.id) },
      },
    });
    const readIds = new Set(reads.map((read) => read.notificationId));
    return {
      data: deliveries.map((delivery) =>
        this.serializeZaloDelivery(delivery, tenant, readIds),
      ),
      summary: {
        total: deliveries.length,
        unread: deliveries.filter(
          (delivery) =>
            !this.isTenantZaloMessage(delivery) && !readIds.has(delivery.id),
        ).length,
      },
      contact: {
        landlordName: tenant.landlord.fullName,
        tenantZaloPhone: tenant.phone,
      },
    };
  }

  async createZaloMessage(userId: string, input: CreateTenantZaloMessageDto) {
    const tenant = await this.tenantProfile(userId);
    const activeLease = tenant.leases.find(
      (lease) => lease.status === LeaseStatus.ACTIVE,
    );
    const message = input.message.trim();
    const delivery = await this.prisma.notificationDelivery.create({
      data: {
        landlordId: tenant.landlordId,
        tenantId: tenant.id,
        invoiceId: null,
        channel: NotificationDeliveryChannel.ZALO,
        purpose: "tenant_manual_message",
        recipient: tenant.landlord.phone ?? tenant.landlord.email,
        payload: {
          message_text: message,
          tenant_name: tenant.fullName,
          room_name: activeLease?.room?.name ?? "Phòng",
          billing_month: "",
          amount: 0,
          due_date: "",
          invoice_url: "",
          sender_role: "tenant",
          direction: "tenant_to_landlord",
        },
        status: NotificationDeliveryStatus.SENT,
        providerMessageId: `tenant-${Date.now()}`,
        sentAt: new Date(),
      },
    });
    return {
      data: this.serializeZaloDelivery(delivery, tenant, new Set([delivery.id])),
    };
  }

  async markZaloMessageRead(userId: string, deliveryId: string) {
    const tenant = await this.tenantProfile(userId);
    const delivery = await this.prisma.notificationDelivery.findFirst({
      where: {
        id: deliveryId,
        tenantId: tenant.id,
        channel: NotificationDeliveryChannel.ZALO,
      },
    });
    if (!delivery) {
      throw new NotFoundException({
        error: {
          code: "ZALO_MESSAGE_NOT_FOUND",
          message: "Zalo message not found.",
        },
      });
    }
    await this.prisma.notificationRead.upsert({
      where: { userId_notificationId: { userId, notificationId: deliveryId } },
      create: { userId, notificationId: deliveryId },
      update: { readAt: new Date() },
    });
    return { data: { id: deliveryId, read: true } };
  }

  async maintenance(userId: string) {
    const tenant = await this.tenantProfile(userId);
    const tickets = await this.prisma.maintenanceTicket.findMany({
      where: this.maintenanceScope(tenant),
      orderBy: [{ reportedAt: "desc" }, { createdAt: "desc" }],
      include: this.ticketInclude,
    });
    return { data: tickets.map((ticket) => this.serializeTicket(ticket)) };
  }

  async createMaintenance(userId: string, input: CreateTenantMaintenanceDto) {
    const tenant = await this.tenantProfile(userId);
    const activeLease = tenant.leases.find(
      (lease) => lease.status === LeaseStatus.ACTIVE,
    );
    if (!activeLease) throw activeLeaseRequired();
    const ticket = await this.prisma.maintenanceTicket.create({
      data: {
        landlordId: tenant.landlordId,
        propertyId: activeLease.room.propertyId,
        roomId: activeLease.roomId,
        status: MaintenanceStatus.OPEN,
        priority: this.priority(input.priority ?? "medium"),
        title: input.title.trim(),
        description: input.description?.trim(),
        imageUrls: this.imageUrls(input.imageUrls),
        note: `Tenant: ${tenant.fullName}`,
      },
      include: this.ticketInclude,
    });
    return { data: this.serializeTicket(ticket) };
  }

  async addMaintenanceComment(
    userId: string,
    ticketId: string,
    input: CreateMaintenanceCommentDto,
  ) {
    await this.tenantOwnedTicket(userId, ticketId);
    const comment = await this.prisma.maintenanceComment.create({
      data: {
        ticketId,
        authorId: userId,
        authorRole: UserRole.TENANT,
        body: input.body.trim(),
        imageUrls: this.imageUrls(input.imageUrls),
      },
      include: this.commentInclude,
    });
    return { data: this.serializeComment(comment) };
  }

  async submitPaymentProof(
    userId: string,
    invoiceId: string,
    input: CreatePaymentProofDto,
  ) {
    const tenant = await this.tenantProfile(userId);
    const proof = await this.prisma.$transaction(async (tx) => {
      const requestHash = commandHash({ invoiceId, tenantId: tenant.id, amount: input.amount,
        method: this.paymentMethod(input.method), note: input.note?.trim() || null,
        proofImageUrls: this.imageUrls(input.proofImageUrls) });
      if (input.requestKey) {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`payment-proof:${input.requestKey}`}, 0))::text`;
        const previous = await tx.paymentProof.findUnique({ where: { requestKey: input.requestKey } });
        if (previous) {
          if (previous.requestHash !== requestHash) throw new ConflictException('Mã gửi chứng từ đã dùng cho nội dung khác.');
          return previous;
        }
      }
      const rows = await tx.$queryRaw<{ id: string }[]>`
        SELECT i."id"
        FROM "Invoice" i
        WHERE i."id" = ${invoiceId}
          AND i."tenantId" = ${tenant.id}
        FOR UPDATE OF i
      `;
      if (!rows.length) {
        throw new NotFoundException({
          error: { code: "INVOICE_NOT_FOUND", message: "Invoice not found." },
        });
      }
      const invoice = await tx.invoice.findUnique({
        where: { id: invoiceId },
      });
      if (!invoice) {
        throw new NotFoundException({
          error: { code: "INVOICE_NOT_FOUND", message: "Invoice not found." },
        });
      }
      if (invoice.isDemo) {
        throw new ConflictException('Hóa đơn demo chỉ dùng trang thanh toán thẻ demo, không nhận chứng từ chuyển khoản.');
      }
      if (invoice.status === InvoiceStatus.CANCELLED) {
        throw new ConflictException({
          error: {
            code: "INVOICE_CANCELLED",
            message: "Cannot submit payment proof for a cancelled invoice.",
          },
        });
      }
      const remainingAmount = invoice.totalAmount - invoice.paidAmount;
      if (remainingAmount <= 0) {
        throw new ConflictException({
          error: {
            code: "INVOICE_ALREADY_PAID",
            message: "Invoice is already fully paid.",
          },
        });
      }
      const pending = await tx.paymentProof.aggregate({
        where: { invoiceId: invoice.id, status: PaymentProofStatus.PENDING },
        _sum: { amount: true },
      });
      const pendingAmount = pending._sum.amount ?? 0;
      if (input.amount > remainingAmount - pendingAmount) {
        throw new ConflictException({
          error: {
            code: "PAYMENT_PROOF_EXCEEDS_REMAINING",
            message: "Payment proofs already pending reserve the remaining balance.",
          },
        });
      }

      return tx.paymentProof.create({
        data: {
          invoiceId: invoice.id,
          tenantId: tenant.id,
          amount: input.amount,
          method: this.paymentMethod(input.method),
          note: input.note?.trim(),
          proofImageUrls: this.imageUrls(input.proofImageUrls),
          requestKey: input.requestKey,
          requestHash: input.requestKey ? requestHash : null,
        },
      });
    });
    return { data: this.serializePaymentProof(proof) };
  }

  private async tenantOwnedTicket(userId: string, ticketId: string) {
    const tenant = await this.tenantProfile(userId);
    const ticket = await this.prisma.maintenanceTicket.findFirst({
      where: { id: ticketId, ...this.maintenanceScope(tenant) },
      include: this.ticketInclude,
    });
    if (!ticket) {
      throw new NotFoundException({
        error: {
          code: "MAINTENANCE_TICKET_NOT_FOUND",
          message: "Maintenance ticket not found.",
        },
      });
    }
    return ticket;
  }

  private maintenanceScope(tenant: TenantProfile): Prisma.MaintenanceTicketWhereInput {
    return {
      landlordId: tenant.landlordId,
      OR: tenant.leases
        .filter((lease) => lease.status === LeaseStatus.ACTIVE)
        .map((lease) => ({ roomId: lease.roomId, createdAt: { gte: lease.startDate } })),
    };
  }

  private tenantProfile(userId: string) {
    return this.prisma.tenant
      .findFirst({
        where: { userId, isActive: true },
        include: {
          landlord: {
            select: { id: true, fullName: true, email: true, phone: true },
          },
          leases: {
            orderBy: { startDate: "desc" },
            include: {
              viewing: { select: { id: true } },
              handover: { select: { acceptedAt: true } },
              depositTransactions: { orderBy: [{ occurredAt: "desc" }, { id: "asc" }] },
              room: {
                select: {
                  id: true,
                  name: true,
                  propertyId: true,
                  property: { select: { id: true, name: true, address: true } },
                },
              },
            },
          },
        },
      })
      .then((tenant) => {
        if (!tenant) throw tenantProfileNotFound();
        return tenant;
      });
  }

  private readonly ticketInclude = {
    property: { select: { id: true, name: true } },
    room: { select: { id: true, name: true } },
    comments: {
      orderBy: { createdAt: "asc" as const },
      include: {
        author: { select: { id: true, fullName: true, role: true } },
      },
    },
  };

  private readonly invoiceInclude = {
    room: {
      select: {
        id: true,
        name: true,
        property: { select: { id: true, name: true } },
      },
    },
    tenant: { select: { id: true, fullName: true } },
    payments: { orderBy: { paidAt: "desc" as const } },
    paymentProofs: { orderBy: { submittedAt: "desc" as const } },
    lineItems: { orderBy: { position: "asc" as const } },
  };

  private readonly commentInclude = {
    author: { select: { id: true, fullName: true, role: true } },
  };

  private serializeTenantProfile(tenant: NonNullable<TenantProfile>) {
    const activeLease = tenant.leases.find(
      (lease) => lease.status === LeaseStatus.ACTIVE,
    );
    return {
      id: tenant.id,
      fullName: tenant.fullName,
      phone: tenant.phone,
      landlordId: tenant.landlordId,
      landlordName: tenant.landlord.fullName,
      activeLease: activeLease ? this.serializeLease(activeLease) : null,
    };
  }

  private serializeLease(lease: NonNullable<TenantProfile>["leases"][number]) {
    return {
      id: lease.id,
      roomId: lease.roomId,
      roomName: lease.room.name,
      propertyId: lease.room.propertyId,
      propertyName: lease.room.property.name,
      propertyAddress: lease.room.property.address,
      monthlyRent: lease.monthlyRent,
      deposit: lease.deposit,
      depositBalance: (lease.depositTransactions ?? []).reduce((balance, entry) =>
        balance + (entry.type === 'REFUNDED' || entry.type === 'DEDUCTED' ? -entry.amount : entry.amount), 0),
      depositTransactions: (lease.depositTransactions ?? []).map((entry) => ({
        id: entry.id, leaseId: entry.leaseId, type: entry.type.toLowerCase(), amount: entry.amount,
        note: entry.note, occurredAt: entry.occurredAt.toISOString(), createdAt: entry.createdAt.toISOString(),
      })),
      status: lease.status.toLowerCase(),
      requiresHandover: !!lease.viewing,
      handedOverAt: lease.handover?.acceptedAt?.toISOString() ?? null,
      startDate: lease.startDate.toISOString(),
      endDate: lease.endDate?.toISOString() ?? null,
      createdAt: lease.createdAt.toISOString(),
      updatedAt: lease.updatedAt.toISOString(),
    };
  }

  private serializeInvoice(invoice: InvoiceWithRelations) {
    const daysOverdue = this.daysOverdue(invoice);
    const daysUntilDue = this.daysUntilDue(invoice);
    return {
      id: invoice.id,
      isDemo: invoice.isDemo ?? false,
      leaseId: invoice.leaseId,
      roomId: invoice.roomId,
      tenantId: invoice.tenantId,
      roomName: invoice.room?.name ?? null,
      propertyId: invoice.room?.property?.id ?? null,
      propertyName: invoice.room?.property?.name ?? null,
      tenantName: invoice.tenant?.fullName ?? null,
      billingMonth: invoice.billingMonth.toISOString(),
      rentAmount: invoice.rentAmount,
      electricityAmount: invoice.electricityAmount,
      waterAmount: invoice.waterAmount,
      otherAmount: invoice.otherAmount,
      totalAmount: invoice.totalAmount,
      paidAmount: invoice.paidAmount,
      remainingAmount: Math.max(invoice.totalAmount - invoice.paidAmount, 0),
      status: invoice.status.toLowerCase(),
      dueDate: invoice.dueDate?.toISOString() ?? null,
      isOverdue: daysOverdue > 0,
      isDueSoon:
        daysUntilDue !== null && daysUntilDue >= 0 && daysUntilDue <= 7,
      daysOverdue,
      daysUntilDue,
      issuedAt: invoice.issuedAt.toISOString(),
      note: invoice.note,
      lineItems: serializeInvoiceLines(invoice),
      payments:
        invoice.payments?.map((payment) => ({
          id: payment.id,
          invoiceId: payment.invoiceId,
          amount: payment.amount,
          method: payment.method.toLowerCase(),
          type: payment.type.toLowerCase(),
          reversalOfPaymentId: payment.reversalOfPaymentId ?? null,
          paidAt: payment.paidAt.toISOString(),
          note: payment.note,
        })) ?? [],
      paymentProofs:
        invoice.paymentProofs?.map((proof) => ({
          id: proof.id,
          invoiceId: proof.invoiceId,
          tenantId: proof.tenantId,
          amount: proof.amount,
          method: proof.method.toLowerCase(),
          status: proof.status.toLowerCase(),
          note: proof.note,
          proofImageUrls: proof.proofImageUrls,
          submittedAt: proof.submittedAt.toISOString(),
          reviewedAt: proof.reviewedAt?.toISOString() ?? null,
          reviewedById: proof.reviewedById ?? null,
          reviewNote: proof.reviewNote ?? null,
        })) ?? [],
    };
  }

  private serializeTicket(ticket: TicketWithRelations) {
    return {
      id: ticket.id,
      propertyId: ticket.propertyId,
      propertyName: ticket.property?.name ?? null,
      roomId: ticket.roomId,
      roomName: ticket.room?.name ?? null,
      status: ticket.status.toLowerCase(),
      priority: ticket.priority.toLowerCase(),
      title: ticket.title,
      description: ticket.description,
      reportedAt: ticket.reportedAt.toISOString(),
      startedAt: ticket.startedAt?.toISOString() ?? null,
      completedAt: ticket.completedAt?.toISOString() ?? null,
      estimatedCost: ticket.estimatedCost,
      actualCost: ticket.actualCost,
      imageUrls: ticket.imageUrls,
      comments:
        ticket.comments?.map((comment) => this.serializeComment(comment)) ?? [],
      expenseId: ticket.expenseId,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
    };
  }

  private serializeComment(
    comment: NonNullable<TicketWithRelations["comments"]>[number],
  ) {
    return {
      id: comment.id,
      ticketId: comment.ticketId,
      authorId: comment.authorId,
      authorName: comment.author?.fullName ?? null,
      authorRole: comment.authorRole.toLowerCase(),
      body: comment.body,
      imageUrls: comment.imageUrls,
      createdAt: comment.createdAt.toISOString(),
    };
  }

  private serializePaymentProof(proof: {
    id: string;
    invoiceId: string;
    tenantId: string;
    amount: number;
    method: PaymentMethod;
    note: string | null;
    proofImageUrls: string[];
    status: string;
    submittedAt: Date;
    reviewedAt?: Date | null;
    reviewedById?: string | null;
    reviewNote?: string | null;
  }) {
    return {
      id: proof.id,
      invoiceId: proof.invoiceId,
      tenantId: proof.tenantId,
      amount: proof.amount,
      method: proof.method.toLowerCase(),
      note: proof.note,
      proofImageUrls: proof.proofImageUrls,
      status: proof.status.toLowerCase(),
      submittedAt: proof.submittedAt.toISOString(),
      reviewedAt: proof.reviewedAt?.toISOString() ?? null,
      reviewedById: proof.reviewedById ?? null,
      reviewNote: proof.reviewNote ?? null,
    };
  }

  private serializeZaloDelivery(
    delivery: {
      id: string;
      purpose: string;
      sentAt: Date | null;
      createdAt: Date;
      updatedAt: Date;
      payload: unknown;
    },
    tenant: NonNullable<TenantProfile>,
    readIds: Set<string>,
  ) {
    return {
      ...delivery,
      read: this.isTenantZaloMessage(delivery) || readIds.has(delivery.id),
      contact: {
        landlordName: tenant.landlord.fullName,
        tenantZaloPhone: tenant.phone,
      },
      sentAt: delivery.sentAt?.toISOString() ?? null,
      createdAt: delivery.createdAt.toISOString(),
      updatedAt: delivery.updatedAt.toISOString(),
    };
  }

  private isTenantZaloMessage(delivery: { purpose: string; payload: unknown }) {
    const payload =
      delivery.payload && typeof delivery.payload === "object"
        ? (delivery.payload as Record<string, unknown>)
        : {};
    return (
      delivery.purpose === "tenant_manual_message" ||
      payload.sender_role === "tenant" ||
      payload.direction === "tenant_to_landlord"
    );
  }

  private paymentMethod(value?: string) {
    const normalized = (value ?? "bank_transfer").toUpperCase();
    if (normalized === "CASH") return PaymentMethod.CASH;
    if (normalized === "OTHER") return PaymentMethod.OTHER;
    return PaymentMethod.BANK_TRANSFER;
  }

  private priority(value: string) {
    const normalized = value.toUpperCase();
    return normalized in MaintenancePriority
      ? MaintenancePriority[normalized as keyof typeof MaintenancePriority]
      : MaintenancePriority.MEDIUM;
  }

  private imageUrls(values?: string[]) {
    return (
      values
        ?.map((value) => value.trim())
        .filter((value) => value.length > 0) ?? []
    );
  }

  private isCollectible(invoice: Invoice) {
    return (
      !invoice.isDemo &&
      invoice.status !== InvoiceStatus.PAID &&
      invoice.status !== InvoiceStatus.CANCELLED &&
      invoice.totalAmount - invoice.paidAmount > 0
    );
  }

  private daysOverdue(invoice: Invoice) {
    if (!invoice.dueDate || !this.isCollectible(invoice)) return 0;
    return Math.max(
      0,
      Math.floor(
        (this.utcDateOnly(new Date()).getTime() -
          this.utcDateOnly(invoice.dueDate).getTime()) /
          86_400_000,
      ),
    );
  }

  private daysUntilDue(invoice: Invoice) {
    if (!invoice.dueDate || !this.isCollectible(invoice)) return null;
    return Math.floor(
      (this.utcDateOnly(invoice.dueDate).getTime() -
        this.utcDateOnly(new Date()).getTime()) /
        86_400_000,
    );
  }

  private utcDateOnly(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }
}
