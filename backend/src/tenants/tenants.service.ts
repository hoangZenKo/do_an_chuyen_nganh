import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Invoice,
  InvoiceStatus,
  Lease,
  LeaseStatus,
  MaintenanceStatus,
  MaintenanceTicket,
  Payment,
  PaymentProof,
  PaymentProofStatus,
  Prisma,
  Room,
  Tenant,
  User,
  UserRole,
} from "@prisma/client";
import * as argon2 from "argon2";

import { PrismaService } from "../prisma/prisma.service";
import { tenantScope } from '../common/property-scope';
import { CreateTenantAccountDto } from "./dto/create-tenant-account.dto";
import { CreateTenantDto } from "./dto/create-tenant.dto";
import { ListTenantsQueryDto } from "./dto/list-tenants-query.dto";
import { UpdateTenantDto } from "./dto/update-tenant.dto";
import { UpdateTenantStatusDto } from "./dto/update-tenant-status.dto";

type LeaseWithRoom = Lease & { room?: Pick<Room, "id" | "name"> | null };
type TenantWithLeases = Tenant & {
  leases?: LeaseWithRoom[];
  user?: { id: string; email: string } | null;
};
type TenantAccount = Pick<
  User,
  "id" | "email" | "isActive" | "createdAt"
> | null;
type TenantOverviewLease = Lease & {
  room?: Pick<Room, "id" | "name"> | null;
  depositTransactions?: Array<{
    id: string;
    type: string;
    amount: number;
    occurredAt: Date;
    note: string | null;
  }>;
  changes?: Array<{
    id: string;
    changeType: string;
    createdAt: Date;
    note: string | null;
  }>;
};
type TenantOverviewInvoice = Invoice & {
  room?: Pick<Room, "id" | "name"> | null;
  payments?: Payment[];
  paymentProofs?: PaymentProof[];
};
type TenantOverviewTicket = MaintenanceTicket & {
  room?: Pick<Room, "id" | "name"> | null;
};

const tenantNotFound = () =>
  new NotFoundException({
    error: { code: "TENANT_NOT_FOUND", message: "Tenant not found." },
  });

const tenantHasActiveLease = () =>
  new ConflictException({
    error: {
      code: "TENANT_HAS_ACTIVE_LEASE",
      message:
        "End the active lease before deactivating or deleting this tenant.",
    },
  });

const tenantHasHistory = () =>
  new ConflictException({
    error: {
      code: "TENANT_HAS_HISTORY",
      message: "Only tenants without leases or invoices can be deleted.",
    },
  });

const tenantInactive = () =>
  new ConflictException({
    error: {
      code: "TENANT_INACTIVE",
      message: "Inactive tenants cannot be updated for operational use.",
    },
  });

const tenantAccountExists = () =>
  new ConflictException({
    error: {
      code: "TENANT_ACCOUNT_EXISTS",
      message: "This tenant already has a login account.",
    },
  });

const emailAlreadyRegistered = () =>
  new ConflictException({
    error: {
      code: "EMAIL_ALREADY_REGISTERED",
      message: "Email is already registered.",
    },
  });

@Injectable()
export class TenantsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(landlordId: string, query: ListTenantsQueryDto = {}) {
    const lifecycle = query.lifecycle ?? "active";
    const tenants = await this.prisma.tenant.findMany({
      where: {
        landlordId,
        ...tenantScope(),
        ...(lifecycle === "active" ? { isActive: true } : {}),
        ...(lifecycle === "inactive" ? { isActive: false } : {}),
      },
      orderBy: { createdAt: "asc" },
      include: {
        leases: {
          where: { status: LeaseStatus.ACTIVE },
          include: { room: { select: { id: true, name: true } } },
        },
      },
    });
    return { data: tenants.map((t) => this.serialize(t)) };
  }

  async getById(landlordId: string, id: string) {
    const tenant = await this.findOwned(landlordId, id);
    return { data: this.serialize(tenant) };
  }

  async overview(landlordId: string, id: string) {
    const tenant = await this.prisma.tenant.findFirst({
      where: { id, landlordId, ...tenantScope() },
      include: {
        user: {
          select: { id: true, email: true, isActive: true, createdAt: true },
        },
      },
    });
    if (!tenant) throw tenantNotFound();

    const leases = await this.prisma.lease.findMany({
      where: { tenantId: tenant.id },
      orderBy: { startDate: "desc" },
      include: {
        room: { select: { id: true, name: true } },
        depositTransactions: {
          orderBy: { occurredAt: "desc" },
          select: {
            id: true,
            type: true,
            amount: true,
            occurredAt: true,
            note: true,
          },
        },
        changes: {
          orderBy: { createdAt: "desc" },
          select: { id: true, changeType: true, createdAt: true, note: true },
        },
      },
    });
    const [invoices, tickets] = await Promise.all([
      this.prisma.invoice.findMany({
        where: { tenantId: tenant.id, isDemo: false },
        orderBy: [{ billingMonth: "desc" }, { issuedAt: "desc" }],
        include: {
          room: { select: { id: true, name: true } },
          payments: { orderBy: { paidAt: "desc" } },
          paymentProofs: { orderBy: { submittedAt: "desc" } },
        },
      }),
      this.prisma.maintenanceTicket.findMany({
        where: {
          landlordId,
          roomId: { in: [...new Set(leases.map((lease) => lease.roomId))] },
        },
        orderBy: [{ reportedAt: "desc" }, { updatedAt: "desc" }],
        include: { room: { select: { id: true, name: true } } },
      }),
    ]);

    const scopedTickets = tickets.filter((ticket) =>
      this.ticketBelongsToTenantLease(ticket, leases),
    );

    return {
      data: {
        financial: this.tenantFinancialSummary(invoices, leases, scopedTickets),
        account: this.serializeTenantAccount(tenant.user),
        timeline: this.tenantTimeline(leases, invoices, scopedTickets).slice(
          0,
          60,
        ),
      },
    };
  }

  async create(landlordId: string, input: CreateTenantDto) {
    const tenant = await this.prisma.tenant.create({
      data: {
        landlordId,
        fullName: input.fullName.trim(),
        phone: input.phone?.trim() || null,
        idNumber: input.idNumber?.trim() || null,
        note: input.note?.trim() || null,
      },
    });
    return { data: this.serialize(tenant) };
  }

  async createAccount(
    landlordId: string,
    id: string,
    input: CreateTenantAccountDto,
  ) {
    const current = await this.findOwned(landlordId, id);
    if (current.userId) throw tenantAccountExists();
    const email = input.email.trim().toLowerCase();

    try {
      const tenant = await this.prisma.$transaction(async (tx) => {
        const user = await tx.user.create({
          data: {
            fullName: current.fullName,
            email,
            phone: current.phone,
            passwordHash: await argon2.hash(input.password),
            role: UserRole.TENANT,
          },
        });
        return tx.tenant.update({
          where: { id: current.id },
          data: { userId: user.id },
          include: this.tenantInclude,
        });
      });
      return { data: this.serialize(tenant) };
    } catch (error) {
      if (this.isUniqueViolation(error)) throw emailAlreadyRegistered();
      throw error;
    }
  }

  async update(landlordId: string, id: string, input: UpdateTenantDto) {
    const current = await this.findOwned(landlordId, id);
    if (!current.isActive) throw tenantInactive();
    const tenant = await this.prisma.tenant.update({
      where: { id },
      data: {
        ...(input.fullName !== undefined
          ? { fullName: input.fullName.trim() }
          : {}),
        ...(input.phone !== undefined
          ? { phone: input.phone.trim() || null }
          : {}),
        ...(input.idNumber !== undefined
          ? { idNumber: input.idNumber.trim() || null }
          : {}),
        ...(input.note !== undefined
          ? { note: input.note.trim() || null }
          : {}),
      },
      include: this.tenantInclude,
    });
    return { data: this.serialize(tenant) };
  }

  async updateStatus(
    landlordId: string,
    id: string,
    input: UpdateTenantStatusDto,
  ) {
    await this.findOwned(landlordId, id);
    if (!input.isActive) {
      await this.assertNoActiveLease(id);
    }
    const tenant = await this.prisma.tenant.update({
      where: { id },
      data: { isActive: input.isActive },
      include: this.tenantInclude,
    });
    return { data: this.serialize(tenant) };
  }

  async remove(landlordId: string, id: string): Promise<void> {
    await this.findOwned(landlordId, id);
    await this.assertNoActiveLease(id);
    const [leases, invoices] = await this.prisma.$transaction([
      this.prisma.lease.count({ where: { tenantId: id } }),
      this.prisma.invoice.count({ where: { tenantId: id } }),
    ]);
    if (leases > 0 || invoices > 0) throw tenantHasHistory();
    await this.prisma.tenant.delete({ where: { id } });
  }

  /** Throws unless the tenant exists and belongs to this landlord. */
  async findOwned(landlordId: string, id: string) {
    const tenant = await this.prisma.tenant.findFirst({
      where: { id, landlordId, ...tenantScope() },
      include: this.tenantInclude,
    });
    if (!tenant) throw tenantNotFound();
    return tenant;
  }

  private async assertNoActiveLease(tenantId: string) {
    const activeLease = await this.prisma.lease.findFirst({
      where: { tenantId, status: LeaseStatus.ACTIVE },
      select: { id: true },
    });
    if (activeLease) throw tenantHasActiveLease();
  }

  private readonly tenantInclude = {
    user: { select: { id: true, email: true } },
    leases: {
      where: { status: LeaseStatus.ACTIVE },
      include: { room: { select: { id: true, name: true } } },
    },
  };

  private isUniqueViolation(error: unknown) {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === "P2002"
    );
  }

  serialize(tenant: TenantWithLeases) {
    const active = tenant.leases?.[0];
    return {
      id: tenant.id,
      fullName: tenant.fullName,
      phone: tenant.phone,
      idNumber: tenant.idNumber,
      note: tenant.note,
      isActive: tenant.isActive,
      userId: tenant.userId,
      accountEmail: tenant.user?.email ?? null,
      activeLease: active
        ? {
            id: active.id,
            roomId: active.roomId,
            roomName: active.room?.name ?? null,
            monthlyRent: active.monthlyRent,
            startDate: active.startDate.toISOString(),
          }
        : null,
    };
  }

  private tenantFinancialSummary(
    invoices: TenantOverviewInvoice[],
    leases: TenantOverviewLease[],
    tickets: TenantOverviewTicket[],
  ) {
    const activeInvoices = invoices.filter(
      (invoice) => invoice.status !== InvoiceStatus.CANCELLED,
    );
    const outstandingAmount = activeInvoices.reduce(
      (sum, invoice) =>
        sum + Math.max(invoice.totalAmount - invoice.paidAmount, 0),
      0,
    );
    const overdueAmount = activeInvoices.reduce(
      (sum, invoice) =>
        sum +
        (this.daysOverdue(invoice) > 0
          ? Math.max(invoice.totalAmount - invoice.paidAmount, 0)
          : 0),
      0,
    );
    return {
      invoiceCount: activeInvoices.length,
      totalBilled: activeInvoices.reduce(
        (sum, invoice) => sum + invoice.totalAmount,
        0,
      ),
      totalPaid: activeInvoices.reduce(
        (sum, invoice) => sum + invoice.paidAmount,
        0,
      ),
      outstandingAmount,
      overdueAmount,
      openInvoiceCount: activeInvoices.filter(
        (invoice) => invoice.totalAmount > invoice.paidAmount,
      ).length,
      overdueInvoiceCount: activeInvoices.filter(
        (invoice) => this.daysOverdue(invoice) > 0,
      ).length,
      pendingProofCount: invoices.reduce(
        (sum, invoice) =>
          sum +
          (invoice.paymentProofs?.filter(
            (proof) => proof.status === PaymentProofStatus.PENDING,
          ).length ?? 0),
        0,
      ),
      depositBalance: leases.reduce(
        (sum, lease) => sum + this.depositBalance(lease),
        0,
      ),
      activeLeaseCount: leases.filter(
        (lease) => lease.status === LeaseStatus.ACTIVE,
      ).length,
      maintenanceOpenCount: tickets.filter(
        (ticket) =>
          ticket.status === MaintenanceStatus.OPEN ||
          ticket.status === MaintenanceStatus.IN_PROGRESS,
      ).length,
    };
  }

  private serializeTenantAccount(account: TenantAccount) {
    return account
      ? {
          id: account.id,
          email: account.email,
          isActive: account.isActive,
          createdAt: account.createdAt.toISOString(),
        }
      : null;
  }

  private tenantTimeline(
    leases: TenantOverviewLease[],
    invoices: TenantOverviewInvoice[],
    tickets: TenantOverviewTicket[],
  ) {
    const events: Array<{
      id: string;
      type: string;
      title: string;
      description: string;
      occurredAt: string;
      amount?: number;
      status?: string;
      roomName?: string | null;
      resourceId?: string;
    }> = [];

    for (const lease of leases) {
      events.push({
        id: `lease-start-${lease.id}`,
        type: "lease_started",
        title: "Bắt đầu hợp đồng",
        description: `Phòng ${lease.room?.name ?? lease.roomId}`,
        occurredAt: lease.startDate.toISOString(),
        amount: lease.monthlyRent,
        status: lease.status.toLowerCase(),
        roomName: lease.room?.name ?? null,
        resourceId: lease.id,
      });
      if (lease.endDate) {
        events.push({
          id: `lease-end-${lease.id}`,
          type: "lease_ended",
          title: "Kết thúc hợp đồng",
          description: `Phòng ${lease.room?.name ?? lease.roomId}`,
          occurredAt: lease.endDate.toISOString(),
          status: lease.status.toLowerCase(),
          roomName: lease.room?.name ?? null,
          resourceId: lease.id,
        });
      }
      for (const change of lease.changes ?? []) {
        events.push({
          id: `lease-change-${change.id}`,
          type: "lease_changed",
          title: "Cập nhật hợp đồng",
          description: change.note || change.changeType,
          occurredAt: change.createdAt.toISOString(),
          roomName: lease.room?.name ?? null,
          resourceId: lease.id,
        });
      }
      for (const deposit of lease.depositTransactions ?? []) {
        events.push({
          id: `deposit-${deposit.id}`,
          type: "deposit",
          title: "Giao dịch tiền cọc",
          description: deposit.note || deposit.type.toLowerCase(),
          occurredAt: deposit.occurredAt.toISOString(),
          amount: deposit.amount,
          status: deposit.type.toLowerCase(),
          roomName: lease.room?.name ?? null,
          resourceId: deposit.id,
        });
      }
    }

    for (const invoice of invoices) {
      events.push({
        id: `invoice-${invoice.id}`,
        type: "invoice_created",
        title: "Tạo hóa đơn",
        description: `Tháng ${invoice.billingMonth.toISOString().slice(0, 7)}`,
        occurredAt: invoice.issuedAt.toISOString(),
        amount: invoice.totalAmount,
        status: invoice.status.toLowerCase(),
        roomName: invoice.room?.name ?? null,
        resourceId: invoice.id,
      });
      for (const payment of invoice.payments ?? []) {
        events.push({
          id: `payment-${payment.id}`,
          type: "payment",
          title: payment.type === "REVERSAL" ? "Đảo thanh toán" : "Thanh toán",
          description: payment.note || payment.method.toLowerCase(),
          occurredAt: payment.paidAt.toISOString(),
          amount: payment.amount,
          status: payment.type.toLowerCase(),
          roomName: invoice.room?.name ?? null,
          resourceId: payment.id,
        });
      }
      for (const proof of invoice.paymentProofs ?? []) {
        events.push({
          id: `payment-proof-${proof.id}`,
          type: "payment_proof",
          title: "Tenant gửi chứng từ",
          description: proof.note || proof.status.toLowerCase(),
          occurredAt: proof.submittedAt.toISOString(),
          amount: proof.amount,
          status: proof.status.toLowerCase(),
          roomName: invoice.room?.name ?? null,
          resourceId: proof.id,
        });
      }
    }

    for (const ticket of tickets) {
      events.push({
        id: `maintenance-${ticket.id}`,
        type: "maintenance",
        title: "Yêu cầu sửa chữa",
        description: ticket.title,
        occurredAt: ticket.reportedAt.toISOString(),
        amount: ticket.actualCost ?? ticket.estimatedCost ?? undefined,
        status: ticket.status.toLowerCase(),
        roomName: ticket.room?.name ?? null,
        resourceId: ticket.id,
      });
    }

    return events.sort(
      (a, b) =>
        new Date(b.occurredAt).getTime() - new Date(a.occurredAt).getTime(),
    );
  }

  private ticketBelongsToTenantLease(
    ticket: TenantOverviewTicket,
    leases: TenantOverviewLease[],
  ) {
    return leases.some((lease) => {
      if (lease.roomId !== ticket.roomId) return false;
      const reportedAt = ticket.reportedAt.getTime();
      const startAt = lease.startDate.getTime();
      const endAt = lease.endDate?.getTime() ?? Number.POSITIVE_INFINITY;
      return reportedAt >= startAt && reportedAt <= endAt;
    });
  }

  private depositBalance(lease: TenantOverviewLease) {
    return (lease.depositTransactions ?? []).reduce((sum, item) => {
      if (item.type === "REFUNDED" || item.type === "DEDUCTED") {
        return sum - item.amount;
      }
      return sum + item.amount;
    }, 0);
  }

  private daysOverdue(invoice: Invoice) {
    if (
      !invoice.dueDate ||
      invoice.status === InvoiceStatus.PAID ||
      invoice.status === InvoiceStatus.CANCELLED ||
      invoice.totalAmount <= invoice.paidAmount
    ) {
      return 0;
    }
    const today = this.utcDateOnly(new Date());
    const due = this.utcDateOnly(invoice.dueDate);
    return Math.max(
      0,
      Math.floor((today.getTime() - due.getTime()) / 86_400_000),
    );
  }

  private utcDateOnly(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }
}
