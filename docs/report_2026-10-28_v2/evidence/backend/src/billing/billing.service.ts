import { propertyWhere } from '../common/property-scope';
import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  BillingAutomation,
  Invoice,
  InvoiceStatus,
  LeaseStatus,
  MeterReading,
  Payment,
  PaymentMethod,
  PaymentProof,
  PaymentProofStatus,
  PaymentType,
  Prisma,
  UtilityType,
} from "@prisma/client";

import { PrismaService } from "../prisma/prisma.service";
import {
  BillingAutomationRunDto,
  UpdateBillingAutomationDto,
} from "./dto/billing-automation.dto";
import { CancelInvoiceDto } from "./dto/cancel-invoice.dto";
import {
  BulkInvoicePreflightDto,
  CreateBulkInvoicesDto,
} from "./dto/create-bulk-invoices.dto";
import {
  CreateInvoiceDto,
  InvoiceMeterReadingDto,
} from "./dto/create-invoice.dto";
import { CreateMeterReadingDto } from "./dto/create-meter-reading.dto";
import { RecordPaymentDto } from "./dto/record-payment.dto";
import { ReviewPaymentProofDto } from "./dto/review-payment-proof.dto";
import { ReversePaymentDto } from "./dto/reverse-payment.dto";
import { UpdateInvoiceDto } from "./dto/update-invoice.dto";
import { serializeInvoiceLines } from "./invoice-lines";
import { pricedInvoiceLines } from './priced-invoice-lines';
import { businessMonth, effectiveFeesByRoom } from "../rooms/service-tariff";
import { dueDays, requiredReason } from "./billing-rules";
import { AuthUser } from '../common/current-user.decorator';
import { billingAudit, billingEvent } from './billing-events';

type InvoiceWithRelations = Invoice & {
  adjustments?: import('@prisma/client').InvoiceAdjustment[];
  replacementInvoice?: { id: string } | null;
  room?: {
    id: string;
    name: string;
    property?: { id: string; name: string } | null;
  } | null;
  tenant?: { id: string; fullName: string } | null;
  lease?: { id: string; monthlyRent: number } | null;
  payments?: Payment[];
  paymentProofs?: PaymentProof[];
  lineItems?: import("@prisma/client").InvoiceLineItem[];
};

type PaymentProofWithRelations = PaymentProof & {
  invoice?: InvoiceWithRelations | null;
  tenant?: { id: string; fullName: string } | null;
  reviewedBy?: { id: string; fullName: string } | null;
};

type FixedServiceFee = {
  id: string;
  roomId: string;
  name: string;
  amount: number;
};

type BillingAutomationWithProperty = BillingAutomation & {
  property?: { id: string; name: string } | null;
};

type DueBillingAutomation = BillingAutomation & {
  property: { id: string; name: string; isArchived: boolean };
  landlord: { id: string; isActive: boolean };
};

const roomNotFound = () =>
  new NotFoundException({
    error: { code: "ROOM_NOT_FOUND", message: "Room not found." },
  });

const leaseNotFound = () =>
  new NotFoundException({
    error: { code: "LEASE_NOT_FOUND", message: "Lease not found." },
  });

const propertyNotFound = () =>
  new NotFoundException({
    error: { code: "PROPERTY_NOT_FOUND", message: "Property not found." },
  });

const invoiceNotFound = () =>
  new NotFoundException({
    error: { code: "INVOICE_NOT_FOUND", message: "Invoice not found." },
  });

const paymentNotFound = () =>
  new NotFoundException({
    error: { code: "PAYMENT_NOT_FOUND", message: "Payment not found." },
  });

@Injectable()
export class BillingService {
  constructor(private readonly prisma: PrismaService) {}

  async runDueBillingAutomations(now = new Date()) {
    const businessDate = this.vietnamBusinessDate(now);
    const billingMonth = this.monthStartForVietnamBusinessDate(businessDate);
    const automations = await this.prisma.billingAutomation.findMany({
      where: {
        isEnabled: true,
        invoiceDay: { lte: businessDate.day },
        OR: [
          { lastRunMonth: null },
          { lastRunMonth: { not: billingMonth } },
        ],
        property: { isArchived: false },
        landlord: { isActive: true },
      },
      include: {
        property: { select: { id: true, name: true, isArchived: true } },
        landlord: { select: { id: true, isActive: true } },
      },
      orderBy: [{ invoiceDay: "asc" }, { updatedAt: "asc" }],
      take: 100,
    });

    const results = [];
    for (const automation of automations) {
      try {
        const result = await this.runDueBillingAutomation(
          automation,
          billingMonth,
        );
        if (result.status === "skipped") {
          results.push({
            propertyId: automation.propertyId,
            landlordId: automation.landlordId,
            status: "skipped",
            reason: result.reason,
            missingReadingCount: result.missingReadingCount,
          });
          continue;
        }
        results.push({
          propertyId: automation.propertyId,
          landlordId: automation.landlordId,
          status: "created",
          createdCount: result.response.data.result.createdCount,
          existingCount: result.response.data.result.existingCount,
        });
      } catch (error) {
        results.push({
          propertyId: automation.propertyId,
          landlordId: automation.landlordId,
          status: "failed",
          error: this.errorCode(error),
        });
      }
    }

    return {
      data: {
        billingMonth: billingMonth.toISOString(),
        checkedCount: automations.length,
        createdCount: results
          .filter((item) => item.status === "created")
          .reduce((sum, item) => sum + (item.createdCount ?? 0), 0),
        existingCount: results
          .filter((item) => item.status === "created")
          .reduce((sum, item) => sum + (item.existingCount ?? 0), 0),
        skippedCount: results.filter((item) => item.status === "skipped")
          .length,
        failedCount: results.filter((item) => item.status === "failed").length,
        results,
      },
    };
  }

  async activeLeases(landlordId: string, month?: string) {
    const billingMonth = month ? this.monthStart(month) : businessMonth();
    const leases = await this.prisma.lease.findMany({
      where: {
        status: "ACTIVE",
        room: { isActive: true, property: { ...propertyWhere(landlordId), isArchived: false } },
      },
      orderBy: [{ room: { name: "asc" } }, { startDate: "desc" }],
      include: {
        room: { select: { id: true, name: true } },
        tenant: { select: { id: true, fullName: true } },
      },
    });
    const feesByRoom = await this.serviceFeesByRoom(
      leases.map((lease) => lease.roomId),
      billingMonth,
    );

    return {
      data: leases.map((lease) => {
        const fixedFee = this.fixedFeeSummary(
          feesByRoom.get(lease.roomId) ?? [],
        );
        return {
          id: lease.id,
          roomId: lease.roomId,
          roomName: lease.room.name,
          tenantId: lease.tenantId,
          tenantName: lease.tenant.fullName,
          monthlyRent: lease.monthlyRent,
          fixedFees: fixedFee.items,
          fixedFeeAmount: fixedFee.amount,
          startDate: lease.startDate.toISOString(),
        };
      }),
    };
  }

  async createMeterReading(landlordId: string, input: CreateMeterReadingDto) {
    const room = await this.prisma.room.findFirst({
      where: { id: input.roomId, property: propertyWhere(landlordId) },
    });
    if (!room) throw roomNotFound();

    this.validateMeterReadingValues(
      input.currentReading,
      input.previousReading,
      input.unitPrice,
    );

    const usage = input.currentReading - input.previousReading;
    try {
      const reading = await this.prisma.meterReading.create({
        data: {
          roomId: room.id,
          utilityType: this.utilityType(input.utilityType),
          billingMonth: this.monthStart(input.billingMonth),
          previousReading: input.previousReading,
          currentReading: input.currentReading,
          unitPrice: input.unitPrice,
          usage,
          amount: usage * input.unitPrice,
          note: input.note,
        },
      });
      return { data: this.serializeMeterReading(reading) };
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw new ConflictException({
          error: {
            code: "METER_READING_EXISTS",
            message:
              "A reading already exists for this room, month and utility.",
          },
        });
      }
      throw error;
    }
  }

  async listMeterReadings(landlordId: string, roomId?: string, month?: string) {
    if (roomId) {
      const room = await this.prisma.room.findFirst({
        where: { id: roomId, property: propertyWhere(landlordId) },
      });
      if (!room) throw roomNotFound();
    }

    const readings = await this.prisma.meterReading.findMany({
      where: {
        room: { property: propertyWhere(landlordId) },
        ...(roomId ? { roomId } : {}),
        ...(month ? { billingMonth: this.monthStart(month) } : {}),
      },
      orderBy: [{ billingMonth: "desc" }, { utilityType: "asc" }],
    });

    return {
      data: readings.map((reading) => this.serializeMeterReading(reading)),
    };
  }

  async createInvoice(landlordId: string, input: CreateInvoiceDto) {
    const lease = await this.prisma.lease.findFirst({
      where: { id: input.leaseId, room: { property: propertyWhere(landlordId) } },
      include: {
        room: { select: { id: true, name: true } },
        tenant: { select: { id: true, fullName: true } },
      },
    });
    if (!lease) throw leaseNotFound();
    if (lease.status !== LeaseStatus.ACTIVE) {
      throw new ConflictException({
        error: {
          code: "LEASE_NOT_ACTIVE",
          message: "Cannot create an invoice for an inactive lease.",
        },
      });
    }

    const billingMonth = this.monthStart(input.billingMonth);
    this.assertBillingMonthWithinLease(
      billingMonth,
      lease.startDate,
      lease.endDate,
    );
    const dueDate = input.dueDate
      ? this.parseDate(
          input.dueDate,
          "INVALID_DUE_DATE",
          "Due date must be valid.",
        )
      : null;
    const readingInputs = this.invoiceMeterReadings(input);

    try {
      const invoice = await this.prisma.$transaction(async (tx) => {
        await this.lockBillableLease(tx, lease, billingMonth);
        for (const reading of readingInputs) {
          await tx.meterReading.create({
            data: {
              roomId: lease.roomId,
              utilityType: reading.utilityType,
              billingMonth,
              previousReading: reading.previousReading,
              currentReading: reading.currentReading,
              unitPrice: reading.unitPrice,
              usage: reading.currentReading - reading.previousReading,
              amount:
                (reading.currentReading - reading.previousReading) *
                reading.unitPrice,
            },
          });
        }

        const readings = await tx.meterReading.findMany({
          where: { roomId: lease.roomId, billingMonth },
        });
        const calculated = await pricedInvoiceLines(
          tx,
          lease,
          readings,
          billingMonth,
          input.otherAmount ?? 0,
        );
        const note = this.mergeInvoiceNote(input.note, null);

        return tx.invoice.create({
          data: {
            leaseId: lease.id,
            roomId: lease.roomId,
            tenantId: lease.tenantId,
            billingMonth,
            rentAmount: calculated.rentAmount,
            electricityAmount: calculated.electricityAmount,
            waterAmount: calculated.waterAmount,
            otherAmount: calculated.otherAmount,
            totalAmount: calculated.totalAmount,
            status: InvoiceStatus.UNPAID,
            dueDate,
            note,
            lineItems: { create: calculated.lines },
          },
          include: this.invoiceInclude,
        });
      });
      return { data: this.serializeInvoice(invoice) };
    } catch (error) {
      if (this.isUniqueViolation(error)) {
        throw this.uniqueViolation(error);
      }
      throw error;
    }
  }

  async bulkInvoicePreflight(
    landlordId: string,
    input: BulkInvoicePreflightDto,
  ) {
    const billingMonth = this.monthStart(input.billingMonth);
    await this.assertActiveOwnedProperty(landlordId, input.propertyId);

    const leases = await this.bulkInvoiceLeases(input.propertyId, billingMonth);
    const invoices = await this.prisma.invoice.findMany({
      where: {
        leaseId: { in: leases.map((lease) => lease.id) },
        billingMonth,
        isDemo: false,
      },
      include: this.invoiceInclude,
    });
    const readings = await this.prisma.meterReading.findMany({
      where: {
        roomId: { in: leases.map((lease) => lease.roomId) },
        billingMonth,
      },
      orderBy: { utilityType: "asc" },
    });
    const previousReadings = await this.prisma.meterReading.findMany({
      where: {
        roomId: { in: leases.map((lease) => lease.roomId) },
        billingMonth: this.previousMonthStart(billingMonth),
      },
      orderBy: { utilityType: "asc" },
    });

    const invoiceByLease = new Map(
      invoices.map((invoice) => [invoice.leaseId, invoice]),
    );
    const readingsByRoom = this.readingsByRoom(readings);
    const previousReadingsByRoom = this.readingsByRoom(previousReadings);
    const feesByRoom = await this.serviceFeesByRoom(
      leases.map((lease) => lease.roomId),
      billingMonth,
    );
    const items = leases.map((lease) => {
      const existing = invoiceByLease.get(lease.id);
      const fixedFee = this.fixedFeeSummary(feesByRoom.get(lease.roomId) ?? []);
      return {
        leaseId: lease.id,
        roomId: lease.roomId,
        roomName: lease.room.name,
        tenantId: lease.tenantId,
        tenantName: lease.tenant.fullName,
        monthlyRent: lease.monthlyRent,
        status: existing ? "existing" : "ready",
        invoice: existing ? this.serializeInvoice(existing) : null,
        meterReadings: this.serializeUtilityReadings(
          readingsByRoom.get(lease.roomId) ?? [],
        ),
        suggestedMeterReadings: this.serializeUtilityReadings(
          previousReadingsByRoom.get(lease.roomId) ?? [],
        ),
        fixedFees: fixedFee.items,
        fixedFeeAmount: fixedFee.amount,
      };
    });

    return {
      data: {
        propertyId: input.propertyId,
        billingMonth: billingMonth.toISOString(),
        totalCount: items.length,
        readyCount: items.filter((item) => item.status === "ready").length,
        existingCount: items.filter((item) => item.status === "existing")
          .length,
        items,
      },
    };
  }

  async createBulkInvoices(landlordId: string, input: CreateBulkInvoicesDto) {
    const billingMonth = this.monthStart(input.billingMonth);
    const dueDate = input.dueDate
      ? this.parseDate(
          input.dueDate,
          "INVALID_DUE_DATE",
          "Due date must be valid.",
        )
      : null;
    await this.assertActiveOwnedProperty(landlordId, input.propertyId);

    const leases = await this.bulkInvoiceLeases(input.propertyId, billingMonth);
    const readingInputs = this.bulkReadingInputs(input);
    const leaseIds = new Set(leases.map((lease) => lease.id));
    for (const leaseId of readingInputs.keys()) {
      if (!leaseIds.has(leaseId)) {
        throw new BadRequestException({
          error: {
            code: "INVALID_BULK_READING_LEASE",
            message:
              "Reading input references a lease outside the selected property.",
          },
        });
      }
    }

    try {
      const results = await this.prisma.$transaction(async (tx) => {
        const existingInvoices = await tx.invoice.findMany({
          where: {
            leaseId: { in: leases.map((lease) => lease.id) },
            billingMonth,
            isDemo: false,
          },
          include: this.invoiceInclude,
        });
        const invoiceByLease = new Map(
          existingInvoices.map((invoice) => [invoice.leaseId, invoice]),
        );
        const existingReadings = await tx.meterReading.findMany({
          where: {
            roomId: { in: leases.map((lease) => lease.roomId) },
            billingMonth,
          },
        });
        const readingsByRoom = this.readingsByRoom(existingReadings);
        const output: Array<{
          leaseId: string;
          status: string;
          invoice: unknown;
        }> = [];

        for (const lease of leases) {
          const existingInvoice = invoiceByLease.get(lease.id);
          if (existingInvoice) {
            output.push({
              leaseId: lease.id,
              status: "existing",
              invoice: this.serializeInvoice(existingInvoice),
            });
            continue;
          }

          await this.lockBillableLease(tx, lease, billingMonth);
          const currentReadings = readingsByRoom.get(lease.roomId) ?? [];
          const currentUtilities = new Set(
            currentReadings.map((reading) => reading.utilityType),
          );
          for (const reading of readingInputs.get(lease.id) ?? []) {
            if (currentUtilities.has(reading.utilityType)) continue;
            const created = await tx.meterReading.create({
              data: {
                roomId: lease.roomId,
                utilityType: reading.utilityType,
                billingMonth,
                previousReading: reading.previousReading,
                currentReading: reading.currentReading,
                unitPrice: reading.unitPrice,
                usage: reading.currentReading - reading.previousReading,
                amount:
                  (reading.currentReading - reading.previousReading) *
                  reading.unitPrice,
              },
            });
            currentReadings.push(created);
            currentUtilities.add(created.utilityType);
          }

          const calculated = await pricedInvoiceLines(
            tx,
            lease,
            currentReadings,
            billingMonth,
          );
          const createdInvoice = await tx.invoice.create({
            data: {
              leaseId: lease.id,
              roomId: lease.roomId,
              tenantId: lease.tenantId,
              billingMonth,
              rentAmount: calculated.rentAmount,
              electricityAmount: calculated.electricityAmount,
              waterAmount: calculated.waterAmount,
              otherAmount: calculated.otherAmount,
              totalAmount: calculated.totalAmount,
              status: InvoiceStatus.UNPAID,
              dueDate,
              lineItems: { create: calculated.lines },
            },
            include: this.invoiceInclude,
          });
          output.push({
            leaseId: lease.id,
            status: "created",
            invoice: this.serializeInvoice(createdInvoice),
          });
        }

        return output;
      });

      return {
        data: {
          propertyId: input.propertyId,
          billingMonth: billingMonth.toISOString(),
          totalCount: results.length,
          createdCount: results.filter((item) => item.status === "created")
            .length,
          existingCount: results.filter((item) => item.status === "existing")
            .length,
          results,
        },
      };
    } catch (error) {
      if (this.isUniqueViolation(error)) throw this.uniqueViolation(error);
      throw error;
    }
  }

  async billingAutomation(landlordId: string, propertyId: string) {
    const property = await this.assertActiveOwnedProperty(
      landlordId,
      propertyId,
    );
    const automation = await this.prisma.billingAutomation.findUnique({
      where: { propertyId },
      include: { property: { select: { id: true, name: true } } },
    });
    return {
      data: this.serializeBillingAutomation(
        automation ?? this.defaultBillingAutomation(landlordId, property.id),
      ),
    };
  }

  async updateBillingAutomation(
    landlordId: string,
    input: UpdateBillingAutomationDto,
  ) {
    const property = await this.assertActiveOwnedProperty(
      landlordId,
      input.propertyId,
    );
    const automation = await this.prisma.billingAutomation.upsert({
      where: { propertyId: property.id },
      create: {
        landlordId,
        propertyId: property.id,
        isEnabled: input.isEnabled,
        invoiceDay: input.invoiceDay,
        dueDay: input.dueDay,
      },
      update: {
        isEnabled: input.isEnabled,
        invoiceDay: input.invoiceDay,
        dueDay: input.dueDay,
      },
      include: { property: { select: { id: true, name: true } } },
    });
    return { data: this.serializeBillingAutomation(automation) };
  }

  async billingAutomationPreview(
    landlordId: string,
    input: BillingAutomationRunDto,
  ) {
    const automation = await this.automationOrDefault(
      landlordId,
      input.propertyId,
    );
    const billingMonth = input.billingMonth
      ? this.monthStart(input.billingMonth)
      : this.currentBillingMonth();
    const preflight = await this.bulkInvoicePreflight(landlordId, {
      propertyId: input.propertyId,
      billingMonth: billingMonth.toISOString(),
    });
    return {
      data: {
        automation: this.serializeBillingAutomation(automation),
        dueDate: this.automationDueDate(
          billingMonth,
          automation.dueDay,
        ).toISOString(),
        preflight: preflight.data,
      },
    };
  }

  async runBillingAutomation(
    landlordId: string,
    input: BillingAutomationRunDto,
  ) {
    const automation = await this.automationOrDefault(
      landlordId,
      input.propertyId,
    );
    if (!automation.isEnabled) {
      throw new ConflictException({
        error: {
          code: "BILLING_AUTOMATION_DISABLED",
          message: "Billing automation is disabled for this property.",
        },
      });
    }
    const billingMonth = input.billingMonth
      ? this.monthStart(input.billingMonth)
      : this.currentBillingMonth();
    const dueDate = this.automationDueDate(billingMonth, automation.dueDay);
    const result = await this.createBulkInvoices(landlordId, {
      propertyId: input.propertyId,
      billingMonth: billingMonth.toISOString(),
      dueDate: dueDate.toISOString(),
      readings: input.readings,
    });
    const saved = await this.prisma.billingAutomation.update({
      where: { propertyId: input.propertyId },
      data: { lastRunMonth: billingMonth, lastRunAt: new Date() },
      include: { property: { select: { id: true, name: true } } },
    });
    return {
      data: {
        automation: this.serializeBillingAutomation(saved),
        dueDate: dueDate.toISOString(),
        result: result.data,
      },
    };
  }

  private async runDueBillingAutomation(
    automation: DueBillingAutomation,
    billingMonth: Date,
  ) {
    const preflight = await this.bulkInvoicePreflight(automation.landlordId, {
      propertyId: automation.propertyId,
      billingMonth: billingMonth.toISOString(),
    });
    const missingReadingCount = this.missingCurrentReadingCount(
      preflight.data.items,
    );
    if (missingReadingCount > 0) {
      return {
        status: "skipped" as const,
        reason: "MISSING_METER_READINGS",
        missingReadingCount,
      };
    }

    const claimed = await this.prisma.billingAutomation.updateMany({
      where: {
        id: automation.id,
        isEnabled: true,
        OR: [
          { lastRunMonth: null },
          { lastRunMonth: { not: billingMonth } },
        ],
      },
      data: { lastRunMonth: billingMonth, lastRunAt: new Date() },
    });
    if (claimed.count === 0) {
      return {
        status: "created" as const,
        response: { data: {
          automation: this.serializeBillingAutomation(automation),
          dueDate: this.automationDueDate(
            billingMonth,
            automation.dueDay,
          ).toISOString(),
          result: {
            propertyId: automation.propertyId,
            billingMonth: billingMonth.toISOString(),
            totalCount: 0,
            createdCount: 0,
            existingCount: 0,
            results: [],
          },
        } },
      };
    }

    try {
      return {
        status: "created" as const,
        response: await this.runBillingAutomation(automation.landlordId, {
          propertyId: automation.propertyId,
          billingMonth: billingMonth.toISOString(),
          readings: [],
        }),
      };
    } catch (error) {
      await this.prisma.billingAutomation.updateMany({
        where: { id: automation.id, lastRunMonth: billingMonth },
        data: { lastRunMonth: automation.lastRunMonth, lastRunAt: automation.lastRunAt },
      });
      throw error;
    }
  }

  private missingCurrentReadingCount(
    items: Array<{ hasInvoice?: boolean; status?: string; meterReadings: unknown }>,
  ) {
    let count = 0;
    for (const item of items) {
      if (item.status === "existing" || item.hasInvoice) continue;
      const readings = item.meterReadings as {
        electricity?: MeterReading | null;
        water?: MeterReading | null;
      };
      if (!readings.electricity) count += 1;
      if (!readings.water) count += 1;
    }
    return count;
  }

  async listInvoices(
    landlordId: string,
    status?: string,
    month?: string,
    propertyId?: string,
    aging?: string,
    dueSoonDays?: string,
  ) {
    if (propertyId) {
      await this.assertActiveOwnedProperty(landlordId, propertyId);
    }
    const normalizedAging = this.invoiceAgingFilter(aging);
    const dueSoonWindow = this.dueSoonDays(dueSoonDays);
    const invoices = await this.prisma.invoice.findMany({
      where: {
        room: {
          property: { ...propertyWhere(landlordId), ...(propertyId ? { id: propertyId } : {}) },
        },
        ...(status ? { status: this.invoiceStatus(status) } : {}),
        ...(month ? { billingMonth: this.monthStart(month) } : {}),
      },
      orderBy: [{ billingMonth: "desc" }, { issuedAt: "desc" }],
      include: this.invoiceInclude,
    });
    const visible = normalizedAging
      ? invoices.filter((invoice) =>
          this.matchesInvoiceAging(invoice, normalizedAging, dueSoonWindow),
        )
      : invoices;

    return {
      data: visible.map((invoice) => this.serializeInvoice(invoice)),
      summary: this.invoiceCollectionSummary(visible, dueSoonWindow),
    };
  }

  async reminders(
    landlordId: string,
    propertyId?: string,
    dueSoonDays?: string,
  ) {
    if (propertyId) {
      await this.assertActiveOwnedProperty(landlordId, propertyId);
    }
    const today = this.dayStart(new Date());
    const windowDays = this.dueSoonDays(dueSoonDays);
    const dueSoonEnd = new Date(
      Date.UTC(
        today.getUTCFullYear(),
        today.getUTCMonth(),
        today.getUTCDate() + windowDays,
      ),
    );
    const invoices = await this.prisma.invoice.findMany({
      where: {
        isDemo: false,
        status: { in: [InvoiceStatus.UNPAID, InvoiceStatus.PARTIAL] },
        dueDate: { lte: dueSoonEnd },
        room: {
          property: { ...propertyWhere(landlordId), ...(propertyId ? { id: propertyId } : {}) },
        },
      },
      orderBy: [{ dueDate: "asc" }, { issuedAt: "desc" }],
      include: this.invoiceInclude,
    });
    const items = invoices
      .filter((invoice) => invoice.totalAmount > invoice.paidAmount)
      .map((invoice) => {
        const remainingAmount = Math.max(
          invoice.totalAmount - invoice.paidAmount,
          0,
        );
        const daysOverdue = this.daysOverdue(invoice);
        const daysUntilDue = this.daysUntilDue(invoice);
        const kind =
          daysOverdue > 0
            ? "overdue"
            : daysUntilDue === 0
              ? "due_today"
              : "due_soon";
        return {
          id: `reminder-${invoice.id}`,
          kind,
          invoiceId: invoice.id,
          tenantId: invoice.tenantId,
          tenantName: invoice.tenant?.fullName ?? null,
          roomId: invoice.roomId,
          roomName: invoice.room?.name ?? null,
          propertyId: invoice.room?.property?.id ?? null,
          propertyName: invoice.room?.property?.name ?? null,
          billingMonth: invoice.billingMonth.toISOString(),
          dueDate: invoice.dueDate?.toISOString() ?? null,
          remainingAmount,
          daysOverdue,
          daysUntilDue,
          suggestedMessage:
            `Chào ${invoice.tenant?.fullName ?? "anh/chị"}, hóa đơn phòng ` +
            `${invoice.room?.name ?? invoice.roomId} tháng ${invoice.billingMonth.getUTCMonth() + 1}/${invoice.billingMonth.getUTCFullYear()} ` +
            `còn ${remainingAmount.toLocaleString("vi-VN")} đ. ` +
            `Hạn thanh toán: ${invoice.dueDate ? invoice.dueDate.toISOString().slice(0, 10) : "chưa đặt"}.`,
        };
      });
    return {
      data: items,
      summary: {
        count: items.length,
        overdueCount: items.filter((item) => item.kind === "overdue").length,
        dueTodayCount: items.filter((item) => item.kind === "due_today").length,
        dueSoonCount: items.filter((item) => item.kind === "due_soon").length,
      },
    };
  }

  async getInvoice(landlordId: string, id: string) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id, room: { property: propertyWhere(landlordId) } },
      include: this.invoiceInclude,
    });
    if (!invoice) throw invoiceNotFound();
    return { data: this.serializeInvoice(invoice) };
  }

  async updateInvoice(
    landlordId: string,
    invoiceId: string,
    input: UpdateInvoiceDto,
  ) {
    const dueDate = input.dueDate
      ? this.parseDate(
          input.dueDate,
          "INVALID_DUE_DATE",
          "Due date must be valid.",
        )
      : input.dueDate === undefined
        ? undefined
        : null;
    const updated = await this.prisma.$transaction(async (tx) => {
      const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
      if (invoice.status === InvoiceStatus.CANCELLED) {
        throw new ConflictException({
          error: {
            code: "INVOICE_CANCELLED",
            message: "Cannot update a cancelled invoice.",
          },
        });
      }
      if (invoice.paidAmount > 0 || invoice.status !== InvoiceStatus.UNPAID) {
        throw new ConflictException({
          error: {
            code: "INVOICE_NOT_EDITABLE",
            message: "Only unpaid invoices without payments can be updated.",
          },
        });
      }
      return tx.invoice.update({
        where: { id: invoice.id },
        data: {
          ...(dueDate !== undefined ? { dueDate } : {}),
          ...(input.note !== undefined ? { note: input.note.trim() || null } : {}),
        },
        include: this.invoiceInclude,
      });
    });
    return { data: this.serializeInvoice(updated) };
  }

  async recordPayment(
    landlordId: string,
    invoiceId: string,
    input: RecordPaymentDto,
  ) {
    const paidAt = input.paidAt
      ? this.parseDate(
          input.paidAt,
          "INVALID_PAID_AT",
          "Paid at must be valid.",
        )
      : new Date();

    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
        if (invoice.isDemo) {
          throw new ConflictException('Hóa đơn kiểm thử chỉ hỗ trợ thanh toán trực tuyến, không ghi nhận tiền thật.');
        }
        if (invoice.status === InvoiceStatus.CANCELLED) {
          throw new BadRequestException({
            error: {
              code: "INVOICE_CANCELLED",
              message: "Cannot record a payment for a cancelled invoice.",
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
        if (input.amount > remainingAmount) {
          throw new ConflictException({
            error: {
              code: "PAYMENT_EXCEEDS_REMAINING",
              message: "Payment amount exceeds the remaining invoice balance.",
            },
          });
        }

        const paidAmount = invoice.paidAmount + input.amount;
        await tx.payment.create({
          data: {
            invoiceId: invoice.id,
            amount: input.amount,
            method: this.paymentMethod(input.method),
            type: PaymentType.PAYMENT,
            paidAt,
            note: input.note,
          },
        });

        return tx.invoice.update({
          where: { id: invoice.id },
          data: {
            paidAmount,
            status: this.invoiceStatusForBalance(
              paidAmount,
              invoice.totalAmount,
            ),
          },
          include: this.invoiceInclude,
        });
      });

      return { data: this.serializeInvoice(updated) };
    } catch (error) {
      if (this.isUniqueViolation(error)) throw this.paymentAlreadyReversed();
      throw error;
    }
  }

  async listPaymentProofs(landlordId: string, status?: string) {
    const normalizedStatus = status
      ? this.paymentProofStatus(status)
      : undefined;
    const proofs = await this.prisma.paymentProof.findMany({
      where: {
        ...(normalizedStatus ? { status: normalizedStatus } : {}),
        invoice: { room: { property: propertyWhere(landlordId) } },
      },
      orderBy: [{ submittedAt: "desc" }],
      include: this.paymentProofInclude,
    });
    return { data: proofs.map((proof) => this.serializePaymentProof(proof)) };
  }

  async reviewPaymentProof(
    landlordId: string,
    proofId: string,
    reviewerId: string,
    input: ReviewPaymentProofDto,
  ) {
    const decision = this.paymentProofStatus(input.status);
    if (decision === PaymentProofStatus.REJECTED) requiredReason(input.note ?? '');
    if (decision === PaymentProofStatus.PENDING) {
      throw new BadRequestException({
        error: {
          code: "INVALID_PAYMENT_PROOF_STATUS",
          message: "Payment proof review must approve or reject.",
        },
      });
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT p.id FROM "PaymentProof" p
        JOIN "Invoice" i ON i.id = p."invoiceId"
        JOIN "Room" r ON r.id = i."roomId"
        JOIN "Property" property ON property.id = r."propertyId"
        WHERE p.id = ${proofId} AND property."landlordId" = ${landlordId} FOR UPDATE OF p`;
      const proof = await tx.paymentProof.findFirst({
        where: { id: proofId, invoice: { room: { property: propertyWhere(landlordId) } } },
      });
      if (!proof) {
        throw new NotFoundException({
          error: {
            code: "PAYMENT_PROOF_NOT_FOUND",
            message: "Payment proof not found.",
          },
        });
      }
      if (proof.status !== PaymentProofStatus.PENDING) {
        throw new ConflictException({
          error: {
            code: "PAYMENT_PROOF_ALREADY_REVIEWED",
            message: "Payment proof has already been reviewed.",
          },
        });
      }

      if (decision === PaymentProofStatus.APPROVED) {
        const invoice = await this.lockOwnedInvoice(
          tx,
          landlordId,
          proof.invoiceId,
        );
        if (invoice.isDemo) throw new ConflictException('Không duyệt chứng từ tiền thật cho hóa đơn demo.');
        if (invoice.status === InvoiceStatus.CANCELLED) {
          throw new ConflictException({
            error: {
              code: "INVOICE_CANCELLED",
              message: "Cannot approve payment proof for a cancelled invoice.",
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
        if (proof.amount > remainingAmount) {
          throw new ConflictException({
            error: {
              code: "PAYMENT_EXCEEDS_REMAINING",
              message: "Payment amount exceeds the remaining invoice balance.",
            },
          });
        }
        const paidAmount = invoice.paidAmount + proof.amount;
        const paidAt = new Date();
        const receipt = await tx.billingReceipt.create({
          data: {
            landlordId,
            tenantId: proof.tenantId,
            amount: proof.amount,
            availableAmount: 0,
            method: proof.method,
            reference: `Payment proof ${proof.id}`,
            paidAt,
            actorId: reviewerId,
          },
        });
        const payment = await tx.payment.create({
          data: {
            invoiceId: invoice.id,
            amount: proof.amount,
            method: proof.method,
            type: PaymentType.PAYMENT,
            paidAt,
            note: input.note?.trim() || proof.note || "Tenant payment proof",
          },
        });
        await tx.paymentAllocation.create({ data: { receiptId: receipt.id, paymentId: payment.id, amount: proof.amount } });
        await billingEvent(tx, landlordId, 'payment.receipt.created', receipt.id, `payment-proof:${proof.id}`, {
          amount: proof.amount, tenantId: proof.tenantId, invoiceId: invoice.id, source: 'PAYMENT_PROOF', proofId: proof.id,
        });
        await tx.invoice.update({
          where: { id: invoice.id },
          data: {
            paidAmount,
            status: this.invoiceStatusForBalance(
              paidAmount,
              invoice.totalAmount,
            ),
          },
        });
        await tx.paymentLink.updateMany({ where: { invoiceId: invoice.id, status: 'PENDING' }, data: { status: 'CANCELLED' } });
        await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId: invoice.id }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
      }

      return tx.paymentProof.update({
        where: { id: proof.id },
        data: {
          status: decision,
          reviewedAt: new Date(),
          reviewedById: reviewerId,
          reviewNote: input.note?.trim() || null,
        },
        include: this.paymentProofInclude,
      });
    });

    return { data: this.serializePaymentProof(updated) };
  }

  async reversePayment(
    landlordId: string,
    invoiceId: string,
    paymentId: string,
    input: ReversePaymentDto,
  ) {
    try {
      const updated = await this.prisma.$transaction(async (tx) => {
        const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
        const payment = await tx.payment.findFirst({
          where: { id: paymentId, invoiceId: invoice.id },
          include: { reversalPayment: true, allocation: true },
        });
        if (!payment) throw paymentNotFound();
        if (payment.allocation) {
          throw new ConflictException({ error: { code: 'PAYMENT_ALLOCATION_MANAGED', message: 'Release the receipt allocation instead of reversing this payment directly.' } });
        }
        if (payment.type === PaymentType.REVERSAL) {
          throw new ConflictException({
            error: {
              code: "PAYMENT_REVERSAL_NOT_ALLOWED",
              message: "Cannot reverse a reversal payment.",
            },
          });
        }
        if (payment.reversalPayment) throw this.paymentAlreadyReversed();

        const paidAmount = invoice.paidAmount - payment.amount;
        await tx.payment.create({
          data: {
            invoiceId: invoice.id,
            amount: -payment.amount,
            method: payment.method,
            type: PaymentType.REVERSAL,
            reversalOfPaymentId: payment.id,
            paidAt: new Date(),
            note: input.note,
          },
        });

        return tx.invoice.update({
          where: { id: invoice.id },
          data: {
            paidAmount,
            status: this.invoiceStatusForBalance(
              paidAmount,
              invoice.totalAmount,
            ),
          },
          include: this.invoiceInclude,
        });
      });

      return { data: this.serializeInvoice(updated) };
    } catch (error) {
      if (this.isUniqueViolation(error)) throw this.paymentAlreadyReversed();
      throw error;
    }
  }

  async cancelInvoice(
    landlordId: string,
    invoiceId: string,
    input: CancelInvoiceDto,
    actor?: AuthUser,
  ) {
    requiredReason(input.note);
    const updated = await this.prisma.$transaction(async (tx) => {
      const invoice = await this.lockOwnedInvoice(tx, landlordId, invoiceId);
      if (invoice.status === InvoiceStatus.CANCELLED) {
        throw new ConflictException({
          error: {
            code: "INVOICE_ALREADY_CANCELLED",
            message: "Invoice is already cancelled.",
          },
        });
      }

      const paymentCount = await tx.payment.count({
        where: { invoiceId: invoice.id },
      });
      if (paymentCount > 0) {
        throw new ConflictException({
          error: {
            code: "INVOICE_HAS_PAYMENTS",
            message: "Cannot cancel an invoice that has payments.",
          },
        });
      }

      const cancelled = await tx.invoice.update({
        where: { id: invoice.id },
        data: {
          status: InvoiceStatus.CANCELLED,
          cancelledAt: new Date(),
          cancelledNote: input.note.trim(),
        },
        include: this.invoiceInclude,
      });
      if (actor) {
        await tx.paymentLink.updateMany({ where: { invoiceId, status: 'PENDING' }, data: { status: 'CANCELLED' } });
        await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
        await billingAudit(tx, actor, 'billing.invoice_cancel', 'invoice', invoiceId, { reason: input.note.trim() });
        await billingEvent(tx, landlordId, 'invoice.cancelled', invoiceId, `invoice.cancelled:${invoiceId}`, { reason: input.note.trim() });
      }
      return cancelled;
    });

    return { data: this.serializeInvoice(updated) };
  }

  private async lockBillableLease(
    tx: Prisma.TransactionClient,
    lease: { id: string; roomId: string; updatedAt: Date },
    billingMonth: Date,
  ) {
    await tx.$queryRaw`SELECT p.id FROM "Property" p JOIN "Room" r ON r."propertyId" = p.id WHERE r.id = ${lease.roomId} FOR UPDATE OF p`;
    const room = await tx.room.findUnique({ where: { id: lease.roomId }, select: { propertyId: true } });
    const lock = room ? await tx.billingPeriodLock.findUnique({ where: { propertyId_month: { propertyId: room.propertyId, month: billingMonth } }, select: { id: true } }) : null;
    if (lock) throw new ConflictException({ error: { code: 'BILLING_PERIOD_LOCKED', message: 'This billing period is locked.' } });
    await tx.$queryRaw`SELECT id FROM "Room" WHERE id = ${lease.roomId} FOR UPDATE`;
    await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${lease.id} FOR UPDATE`;
    const current = await tx.lease.findFirst({
      where: { id: lease.id, roomId: lease.roomId, status: LeaseStatus.ACTIVE, updatedAt: lease.updatedAt },
      select: { id: true },
    });
    if (!current) {
      throw new ConflictException({ error: { code: "LEASE_CHANGED", message: "Lease changed or ended. Reload before creating invoices." } });
    }
    await tx.lease.update({ where: { id: lease.id }, data: { updatedAt: new Date() } });
  }

  private async assertActiveOwnedProperty(
    landlordId: string,
    propertyId: string,
  ) {
    const property = await this.prisma.property.findFirst({
      where: { id: propertyId, ...propertyWhere(landlordId), isArchived: false },
      select: { id: true },
    });
    if (!property) throw propertyNotFound();
    return property;
  }

  private async automationOrDefault(landlordId: string, propertyId: string) {
    const property = await this.assertActiveOwnedProperty(
      landlordId,
      propertyId,
    );
    const automation = await this.prisma.billingAutomation.findUnique({
      where: { propertyId },
      include: { property: { select: { id: true, name: true } } },
    });
    return automation ?? this.defaultBillingAutomation(landlordId, property.id);
  }

  private defaultBillingAutomation(
    landlordId: string,
    propertyId: string,
  ): BillingAutomationWithProperty {
    const now = new Date();
    return {
      id: "",
      landlordId,
      propertyId,
      isEnabled: false,
      invoiceDay: 1,
      dueDay: 10,
      lastRunMonth: null,
      lastRunAt: null,
      property: null,
      createdAt: now,
      updatedAt: now,
    };
  }

  private serializeBillingAutomation(
    automation: BillingAutomationWithProperty,
  ) {
    return {
      id: automation.id,
      landlordId: automation.landlordId,
      propertyId: automation.propertyId,
      propertyName: automation.property?.name ?? null,
      isEnabled: automation.isEnabled,
      invoiceDay: automation.invoiceDay,
      dueDay: automation.dueDay,
      lastRunMonth: automation.lastRunMonth?.toISOString() ?? null,
      lastRunAt: automation.lastRunAt?.toISOString() ?? null,
      createdAt: automation.createdAt.toISOString(),
      updatedAt: automation.updatedAt.toISOString(),
    };
  }

  private currentBillingMonth() {
    return this.monthStart(new Date().toISOString());
  }

  private previousMonthStart(month: Date) {
    return new Date(
      Date.UTC(month.getUTCFullYear(), month.getUTCMonth() - 1, 1),
    );
  }

  private vietnamBusinessDate(now: Date) {
    const shifted = new Date(now.getTime() + 7 * 60 * 60 * 1000);
    return {
      year: shifted.getUTCFullYear(),
      month: shifted.getUTCMonth(),
      day: shifted.getUTCDate(),
    };
  }

  private monthStartForVietnamBusinessDate(date: {
    year: number;
    month: number;
  }) {
    return new Date(Date.UTC(date.year, date.month, 1));
  }

  private automationDueDate(billingMonth: Date, dueDay: number) {
    return new Date(
      Date.UTC(
        billingMonth.getUTCFullYear(),
        billingMonth.getUTCMonth(),
        dueDay,
      ),
    );
  }

  private bulkInvoiceLeases(propertyId: string, billingMonth: Date) {
    const nextMonth = new Date(
      Date.UTC(
        billingMonth.getUTCFullYear(),
        billingMonth.getUTCMonth() + 1,
        1,
      ),
    );
    return this.prisma.lease.findMany({
      where: {
        status: LeaseStatus.ACTIVE,
        startDate: { lt: nextMonth },
        OR: [{ endDate: null }, { endDate: { gte: billingMonth } }],
        room: { propertyId, isActive: true },
      },
      orderBy: [{ room: { name: "asc" } }, { startDate: "desc" }],
      include: {
        room: { select: { id: true, name: true } },
        tenant: { select: { id: true, fullName: true } },
      },
    });
  }

  private readingsByRoom(readings: MeterReading[]) {
    const grouped = new Map<string, MeterReading[]>();
    for (const reading of readings) {
      const roomReadings = grouped.get(reading.roomId) ?? [];
      roomReadings.push(reading);
      grouped.set(reading.roomId, roomReadings);
    }
    return grouped;
  }

  private async serviceFeesByRoom(roomIds: string[], month = businessMonth()) {
    return effectiveFeesByRoom(this.prisma, roomIds, month);
  }

  private fixedFeeSummary(fees: FixedServiceFee[]) {
    const amount = fees.reduce((sum, fee) => sum + fee.amount, 0);
    return {
      amount,
      items: fees.map((fee) => ({
        id: fee.id,
        name: fee.name,
        amount: fee.amount,
      })),
      note:
        fees.length > 0
          ? `Phí cố định: ${fees.map((fee) => `${fee.name} ${fee.amount.toLocaleString("vi-VN")} đ`).join(", ")}`
          : null,
    };
  }

  private mergeInvoiceNote(note?: string | null, fixedFeeNote?: string | null) {
    const parts = [note?.trim(), fixedFeeNote?.trim()].filter(Boolean);
    return parts.length ? parts.join("\n") : null;
  }

  private serializeUtilityReadings(readings: MeterReading[]) {
    const readingFor = (utilityType: UtilityType) =>
      readings.find((reading) => reading.utilityType === utilityType);
    return {
      electricity: readingFor(UtilityType.ELECTRICITY)
        ? this.serializeMeterReading(readingFor(UtilityType.ELECTRICITY)!)
        : null,
      water: readingFor(UtilityType.WATER)
        ? this.serializeMeterReading(readingFor(UtilityType.WATER)!)
        : null,
    };
  }

  private bulkReadingInputs(input: CreateBulkInvoicesDto) {
    const byLease = new Map<
      string,
      Array<{
        utilityType: UtilityType;
        previousReading: number;
        currentReading: number;
        unitPrice: number;
      }>
    >();
    for (const item of input.readings ?? []) {
      if (byLease.has(item.leaseId)) {
        throw new BadRequestException({
          error: {
            code: "DUPLICATE_BULK_READING_LEASE",
            message: "Only one reading group per lease is allowed.",
          },
        });
      }
      const seen = new Set<UtilityType>();
      const readings = (item.meterReadings ?? []).map((reading) => {
        const normalized = this.normalizedMeterReading(reading);
        if (seen.has(normalized.utilityType)) {
          throw new BadRequestException({
            error: {
              code: "DUPLICATE_UTILITY_READING",
              message: "Only one reading per utility is allowed.",
            },
          });
        }
        seen.add(normalized.utilityType);
        return normalized;
      });
      byLease.set(item.leaseId, readings);
    }
    return byLease;
  }

  private normalizedMeterReading(reading: InvoiceMeterReadingDto) {
    const utilityType = this.utilityType(reading.utilityType);
    this.validateMeterReadingValues(
      reading.currentReading,
      reading.previousReading,
      reading.unitPrice,
    );
    return { ...reading, utilityType };
  }

  private readonly invoiceInclude = {
    adjustments: { orderBy: { createdAt: 'asc' as const } },
    replacementInvoice: { select: { id: true } },
    room: {
      select: {
        id: true,
        name: true,
        property: { select: { id: true, name: true } },
      },
    },
    tenant: { select: { id: true, fullName: true } },
    lease: { select: { id: true, monthlyRent: true } },
    payments: { orderBy: { paidAt: "desc" as const } },
    paymentProofs: { orderBy: { submittedAt: "desc" as const } },
    lineItems: { orderBy: { position: "asc" as const } },
  };

  private readonly paymentProofInclude = {
    invoice: {
      include: {
        room: {
          select: {
            id: true,
            name: true,
            property: { select: { id: true, name: true } },
          },
        },
        tenant: { select: { id: true, fullName: true } },
        lease: { select: { id: true, monthlyRent: true } },
        payments: { orderBy: { paidAt: "desc" as const } },
        lineItems: { orderBy: { position: "asc" as const } },
        paymentProofs: {
        orderBy: { submittedAt: "desc" as const },
      },
      },
    },
    tenant: { select: { id: true, fullName: true } },
    reviewedBy: { select: { id: true, fullName: true } },
  };

  private async lockOwnedInvoice(
    tx: Prisma.TransactionClient,
    landlordId: string,
    invoiceId: string,
  ) {
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT i."id"
      FROM "Invoice" i
      JOIN "Room" r ON r."id" = i."roomId"
      JOIN "Property" p ON p."id" = r."propertyId"
      WHERE i."id" = ${invoiceId}
        AND p."landlordId" = ${landlordId}
      FOR UPDATE OF i
    `;
    if (!rows.length) throw invoiceNotFound();

    const invoice = await tx.invoice.findUnique({ where: { id: rows[0].id } });
    if (!invoice) throw invoiceNotFound();
    return invoice;
  }

  private monthStart(value?: string | Date) {
    const date = value ? new Date(value) : new Date();
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException({
        error: {
          code: "INVALID_BILLING_MONTH",
          message: "Billing month must be a valid date.",
        },
      });
    }
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
  }

  private dayStart(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }

  private parseDate(value: string, code: string, message: string) {
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new BadRequestException({ error: { code, message } });
    }
    return date;
  }

  private invoiceAgingFilter(value?: string) {
    if (!value) return null;
    const normalized = value.toLowerCase().trim();
    if (["open", "overdue", "due_soon"].includes(normalized)) {
      return normalized as "open" | "overdue" | "due_soon";
    }
    throw new BadRequestException({
      error: {
        code: "INVALID_INVOICE_AGING",
        message: "Invoice aging filter must be open, overdue or due_soon.",
      },
    });
  }

  private dueSoonDays(value?: string) {
    if (!value) return 7;
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 0 || parsed > 60) {
      throw new BadRequestException({
        error: {
          code: "INVALID_DUE_SOON_DAYS",
          message: "Due soon days must be an integer from 0 to 60.",
        },
      });
    }
    return parsed;
  }

  private matchesInvoiceAging(
    invoice: Invoice,
    aging: "open" | "overdue" | "due_soon",
    dueSoonDays: number,
  ) {
    if (!this.isCollectible(invoice)) return false;
    if (aging === "open") return true;
    if (aging === "overdue") return this.daysOverdue(invoice) > 0;
    return (
      this.daysUntilDue(invoice) !== null &&
      this.daysUntilDue(invoice)! >= 0 &&
      this.daysUntilDue(invoice)! <= dueSoonDays
    );
  }

  private invoiceCollectionSummary(invoices: Invoice[], dueSoonDays: number) {
    return invoices.reduce(
      (summary, invoice) => {
        if (invoice.isDemo) return summary;
        const remainingAmount = Math.max(
          invoice.totalAmount - invoice.paidAmount,
          0,
        );
        if (invoice.status !== InvoiceStatus.CANCELLED) {
          summary.totalAmount += invoice.totalAmount;
          summary.paidAmount += invoice.paidAmount;
          summary.remainingAmount += remainingAmount;
        }
        if (this.isCollectible(invoice)) {
          summary.openCount++;
          if (this.daysOverdue(invoice) > 0) {
            summary.overdueCount++;
            summary.overdueAmount += remainingAmount;
          } else {
            const daysUntilDue = this.daysUntilDue(invoice);
            if (
              daysUntilDue !== null &&
              daysUntilDue >= 0 &&
              daysUntilDue <= dueSoonDays
            ) {
              summary.dueSoonCount++;
              summary.dueSoonAmount += remainingAmount;
            }
          }
        }
        return summary;
      },
      {
        count: invoices.length,
        openCount: 0,
        overdueCount: 0,
        dueSoonCount: 0,
        totalAmount: 0,
        paidAmount: 0,
        remainingAmount: 0,
        overdueAmount: 0,
        dueSoonAmount: 0,
      },
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
    return Math.max(0, dueDays(invoice.dueDate));
  }

  private daysUntilDue(invoice: Invoice) {
    if (!invoice.dueDate || !this.isCollectible(invoice)) return null;
    return -dueDays(invoice.dueDate);
  }

  private utcDateOnly(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }

  private assertBillingMonthWithinLease(
    billingMonth: Date,
    startDate: Date,
    endDate: Date | null,
  ) {
    const startMonth = this.monthStart(startDate);
    const endMonth = endDate ? this.monthStart(endDate) : null;
    if (billingMonth < startMonth || (endMonth && billingMonth > endMonth)) {
      throw new BadRequestException({
        error: {
          code: "BILLING_MONTH_OUTSIDE_LEASE",
          message: "Billing month must be within the lease period.",
        },
      });
    }
  }

  private invoiceMeterReadings(input: CreateInvoiceDto) {
    const readings = input.meterReadings ?? [];
    const seen = new Set<UtilityType>();
    return readings.map((reading) => {
      const utilityType = this.utilityType(reading.utilityType);
      if (seen.has(utilityType)) {
        throw new BadRequestException({
          error: {
            code: "DUPLICATE_UTILITY_READING",
            message: "Only one reading per utility is allowed.",
          },
        });
      }
      seen.add(utilityType);
      this.validateMeterReadingValues(
        reading.currentReading,
        reading.previousReading,
        reading.unitPrice,
      );
      return { ...reading, utilityType };
    });
  }

  private validateMeterReadingValues(
    currentReading: number,
    previousReading: number,
    unitPrice: number,
  ) {
    if (currentReading < previousReading) {
      throw new BadRequestException({
        error: {
          code: "INVALID_METER_READING",
          message:
            "Current reading must be greater than or equal to previous reading.",
        },
      });
    }
    if (unitPrice <= 0) {
      throw new BadRequestException({
        error: {
          code: "INVALID_UNIT_PRICE",
          message: "Unit price must be greater than zero.",
        },
      });
    }
  }

  private amountFor(readings: MeterReading[], utilityType: UtilityType) {
    return readings
      .filter((reading) => reading.utilityType === utilityType)
      .reduce((sum, reading) => sum + reading.amount, 0);
  }

  private utilityType(value: string) {
    return value.toUpperCase() === "WATER"
      ? UtilityType.WATER
      : UtilityType.ELECTRICITY;
  }

  private invoiceStatus(value: string) {
    const normalized = value.toUpperCase();
    if (!Object.values(InvoiceStatus).includes(normalized as InvoiceStatus)) {
      throw new BadRequestException({
        error: {
          code: "INVALID_INVOICE_STATUS",
          message: "Invalid invoice status.",
        },
      });
    }
    return normalized as InvoiceStatus;
  }

  private invoiceStatusForBalance(paidAmount: number, totalAmount: number) {
    if (paidAmount >= totalAmount) return InvoiceStatus.PAID;
    if (paidAmount > 0) return InvoiceStatus.PARTIAL;
    return InvoiceStatus.UNPAID;
  }

  private paymentMethod(value?: string) {
    const normalized = (value ?? "cash").toUpperCase();
    if (normalized === "BANK_TRANSFER") return PaymentMethod.BANK_TRANSFER;
    if (normalized === "OTHER") return PaymentMethod.OTHER;
    return PaymentMethod.CASH;
  }

  private paymentProofStatus(value: string) {
    const normalized = value.toUpperCase();
    if (
      !Object.values(PaymentProofStatus).includes(
        normalized as PaymentProofStatus,
      )
    ) {
      throw new BadRequestException({
        error: {
          code: "INVALID_PAYMENT_PROOF_STATUS",
          message: "Invalid payment proof status.",
        },
      });
    }
    return normalized as PaymentProofStatus;
  }

  private paymentAlreadyReversed() {
    return new ConflictException({
      error: {
        code: "PAYMENT_ALREADY_REVERSED",
        message: "Payment has already been reversed.",
      },
    });
  }

  private isUniqueViolation(error: unknown) {
    return (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      error.code === "P2002"
    );
  }

  private uniqueViolation(error: unknown) {
    const target =
      typeof error === "object" &&
      error !== null &&
      "meta" in error &&
      typeof error.meta === "object" &&
      error.meta !== null &&
      "target" in error.meta &&
      Array.isArray(error.meta.target)
        ? error.meta.target.map((item) => item.toString())
        : [];
    const isMeterReading =
      target.includes("roomId") &&
      target.includes("utilityType") &&
      target.includes("billingMonth");
    return new ConflictException({
      error: isMeterReading
        ? {
            code: "METER_READING_EXISTS",
            message:
              "A reading already exists for this room, month and utility.",
          }
        : {
            code: "INVOICE_EXISTS",
            message: "An invoice already exists for this lease and month.",
          },
    });
  }

  private serializeMeterReading(reading: MeterReading) {
    return {
      id: reading.id,
      roomId: reading.roomId,
      utilityType: reading.utilityType.toLowerCase(),
      billingMonth: reading.billingMonth.toISOString(),
      previousReading: reading.previousReading,
      currentReading: reading.currentReading,
      unitPrice: reading.unitPrice,
      usage: reading.usage,
      amount: reading.amount,
      note: reading.note,
    };
  }

  serializeInvoice(invoice: InvoiceWithRelations) {
    const daysOverdue = this.daysOverdue(invoice);
    const daysUntilDue = this.daysUntilDue(invoice);
    return {
      id: invoice.id,
      isDemo: invoice.isDemo ?? false,
      revision: invoice.revision ?? 1,
      replacesInvoiceId: invoice.replacesInvoiceId ?? null,
      replacementInvoiceId: invoice.replacementInvoice?.id ?? null,
      adjustments: invoice.adjustments ?? [],
      leaseId: invoice.leaseId,
      roomId: invoice.roomId,
      roomName: invoice.room?.name ?? null,
      propertyId: invoice.room?.property?.id ?? null,
      propertyName: invoice.room?.property?.name ?? null,
      tenantId: invoice.tenantId,
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
      cancelledAt: invoice.cancelledAt?.toISOString() ?? null,
      cancelledNote: invoice.cancelledNote ?? null,
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
          tenantName: invoice.tenant?.fullName ?? null,
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

  private serializePaymentProof(proof: PaymentProofWithRelations) {
    return {
      id: proof.id,
      invoiceId: proof.invoiceId,
      tenantId: proof.tenantId,
      tenantName:
        proof.tenant?.fullName ?? proof.invoice?.tenant?.fullName ?? null,
      roomName: proof.invoice?.room?.name ?? null,
      billingMonth: proof.invoice?.billingMonth.toISOString() ?? null,
      amount: proof.amount,
      method: proof.method.toLowerCase(),
      note: proof.note,
      proofImageUrls: proof.proofImageUrls,
      status: proof.status.toLowerCase(),
      submittedAt: proof.submittedAt.toISOString(),
      reviewedAt: proof.reviewedAt?.toISOString() ?? null,
      reviewedById: proof.reviewedById,
      reviewedByName: proof.reviewedBy?.fullName ?? null,
      reviewNote: proof.reviewNote,
      invoice: proof.invoice ? this.serializeInvoice(proof.invoice) : null,
    };
  }

  private errorCode(error: unknown) {
    if (
      error &&
      typeof error === "object" &&
      "getResponse" in error &&
      typeof error.getResponse === "function"
    ) {
      const response = error.getResponse() as {
        error?: { code?: string };
      };
      return response.error?.code ?? "UNKNOWN_ERROR";
    }
    return "UNKNOWN_ERROR";
  }
}
