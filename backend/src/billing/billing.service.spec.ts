import { BadRequestException, ConflictException } from '@nestjs/common';
import { InvoiceStatus, LeaseStatus, PaymentMethod, PaymentType, UtilityType } from '@prisma/client';

import { BillingService } from './billing.service';

const landlordId = 'landlord-1';
const billingMonth = new Date('2026-08-01T00:00:00.000Z');

const lease = {
  id: 'lease-1',
  roomId: 'room-1',
  tenantId: 'tenant-1',
  startDate: new Date('2026-01-01T00:00:00.000Z'),
  endDate: null,
  monthlyRent: 3_000_000,
  deposit: 3_000_000,
  status: LeaseStatus.ACTIVE,
  createdAt: new Date(),
  updatedAt: new Date(),
  room: { id: 'room-1', name: '201' },
  tenant: { id: 'tenant-1', fullName: 'Nguyễn Văn A' },
};

function payment(overrides: Record<string, unknown> = {}) {
  return {
    id: 'payment-1',
    invoiceId: 'invoice-1',
    amount: 1_000_000,
    method: PaymentMethod.CASH,
    type: PaymentType.PAYMENT,
    reversalOfPaymentId: null,
    paidAt: new Date('2026-08-08T00:00:00.000Z'),
    note: null,
    createdAt: new Date('2026-08-08T00:00:00.000Z'),
    reversalPayment: null,
    ...overrides,
  };
}

function invoice(overrides: Record<string, unknown> = {}) {
  return {
    id: 'invoice-1',
    leaseId: lease.id,
    roomId: lease.roomId,
    tenantId: lease.tenantId,
    billingMonth,
    rentAmount: 3_000_000,
    electricityAmount: 210_000,
    waterAmount: 150_000,
    otherAmount: 0,
    totalAmount: 3_360_000,
    paidAmount: 0,
    status: InvoiceStatus.UNPAID,
    dueDate: new Date('2026-08-10T00:00:00.000Z'),
    issuedAt: new Date('2026-08-05T00:00:00.000Z'),
    note: null,
    cancelledAt: null,
    cancelledNote: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    room: lease.room,
    tenant: lease.tenant,
    lease: { id: lease.id, monthlyRent: lease.monthlyRent },
    payments: [],
    ...overrides,
  };
}

function createPrismaMock() {
  const tx = {
    room: { findUnique: jest.fn().mockResolvedValue({ propertyId: 'property-1' }) },
    billingPeriodLock: { findUnique: jest.fn().mockResolvedValue(null) },
    $queryRaw: jest.fn().mockImplementation((query: TemplateStringsArray) => Promise.resolve(query.join('').includes('BillingPeriodLock') ? [] : [{ id: 'invoice-1' }])),
    lease: { findFirst: jest.fn().mockResolvedValue({ id: lease.id }), update: jest.fn() },
    meterReading: { create: jest.fn(), findMany: jest.fn() },
    invoice: {
      create: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn().mockResolvedValue(invoice()),
      update: jest.fn(),
    },
    roomServiceFee: { findMany: jest.fn().mockResolvedValue([]) },
    payment: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      count: jest.fn(),
    },
  };
  return {
    lease: { findFirst: jest.fn(), findMany: jest.fn() },
    room: { findFirst: jest.fn() },
    meterReading: { create: jest.fn(), findMany: jest.fn() },
    roomServiceFee: { findMany: jest.fn().mockResolvedValue([]) },
    invoice: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), update: jest.fn() },
    property: { findFirst: jest.fn() },
    billingAutomation: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
      upsert: jest.fn(),
    },
    payment: { create: jest.fn(), findMany: jest.fn(), findFirst: jest.fn(), count: jest.fn() },
    $transaction: jest.fn((arg) => (typeof arg === 'function' ? arg(tx) : Promise.all(arg))),
    __tx: tx,
  } as any;
}

async function expectErrorCode(promise: Promise<unknown>, code: string) {
  try {
    await promise;
    throw new Error(`Expected ${code}`);
  } catch (error: any) {
    expect(error.getResponse?.()).toMatchObject({ error: { code } });
  }
}

describe('BillingService', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects a lease ended or changed after invoice preflight', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);
    prisma.__tx.lease.findFirst.mockResolvedValue(null);
    await expectErrorCode(new BillingService(prisma).createInvoice(landlordId, {
      leaseId: lease.id, billingMonth: '2026-08-01',
    }), 'LEASE_CHANGED');
    expect(prisma.__tx.invoice.create).not.toHaveBeenCalled();
    expect(prisma.__tx.meterReading.create).not.toHaveBeenCalled();
    expect(prisma.__tx.lease.update).not.toHaveBeenCalled();
  });

  it('revalidates bulk billing leases under lock before any new charges', async () => {
    const prisma = createPrismaMock();
    prisma.property.findFirst.mockResolvedValue({ id: 'property-1' });
    prisma.lease.findMany.mockResolvedValue([lease]);
    prisma.__tx.invoice.findMany.mockResolvedValue([]);
    prisma.__tx.meterReading.findMany.mockResolvedValue([]);
    prisma.__tx.lease.findFirst.mockResolvedValue(null);
    await expectErrorCode(new BillingService(prisma).createBulkInvoices(landlordId, {
      propertyId: 'property-1', billingMonth: '2026-08-01',
    }), 'LEASE_CHANGED');
    expect(prisma.__tx.invoice.create).not.toHaveBeenCalled();
  });

  it('creates invoice and meter readings in one transaction', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);
    prisma.__tx.meterReading.findMany.mockResolvedValue([
      { id: 'electricity-1', utilityType: UtilityType.ELECTRICITY, usage: 60, unitPrice: 3500, amount: 210_000 },
      { id: 'water-1', utilityType: UtilityType.WATER, usage: 10, unitPrice: 15000, amount: 150_000 },
    ]);
    prisma.__tx.invoice.create.mockResolvedValue(invoice());

    const service = new BillingService(prisma);
    const result = await service.createInvoice(landlordId, {
      leaseId: lease.id,
      billingMonth: '2026-08-01',
      dueDate: '2026-08-10',
      meterReadings: [
        {
          utilityType: 'electricity',
          previousReading: 120,
          currentReading: 180,
          unitPrice: 3500,
        },
        {
          utilityType: 'water',
          previousReading: 20,
          currentReading: 30,
          unitPrice: 15000,
        },
      ],
    });

    expect(prisma.$transaction).toHaveBeenCalled();
    expect(prisma.__tx.meterReading.create).toHaveBeenCalledTimes(2);
    expect(prisma.__tx.invoice.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          electricityAmount: 210_000,
          waterAmount: 150_000,
          totalAmount: 3_360_000,
        }),
      }),
    );
    expect(result.data.totalAmount).toBe(3_360_000);
  });

  it('keeps legacy invoice payload working', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);
    prisma.__tx.meterReading.findMany.mockResolvedValue([]);
    prisma.__tx.invoice.create.mockResolvedValue(
      invoice({ electricityAmount: 0, waterAmount: 0, totalAmount: 3_000_000 }),
    );

    const service = new BillingService(prisma);
    const result = await service.createInvoice(landlordId, {
      leaseId: lease.id,
      billingMonth: '2026-08-01',
    });

    expect(prisma.__tx.meterReading.create).not.toHaveBeenCalled();
    expect(result.data.totalAmount).toBe(3_000_000);
  });

  it('rejects invalid meter readings before writing', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);

    const service = new BillingService(prisma);
    await expect(
      service.createInvoice(landlordId, {
        leaseId: lease.id,
        billingMonth: '2026-08-01',
        meterReadings: [
          {
            utilityType: 'electricity',
            previousReading: 200,
            currentReading: 100,
            unitPrice: 3500,
          },
        ],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects inactive leases when creating invoices', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue({ ...lease, status: LeaseStatus.ENDED });

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.createInvoice(landlordId, {
        leaseId: lease.id,
        billingMonth: '2026-08-01',
      }),
      'LEASE_NOT_ACTIVE',
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('rejects billing months outside the lease period', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue({
      ...lease,
      startDate: new Date('2026-08-15T00:00:00.000Z'),
      endDate: new Date('2026-09-15T00:00:00.000Z'),
    });

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.createInvoice(landlordId, {
        leaseId: lease.id,
        billingMonth: '2026-10-01',
      }),
      'BILLING_MONTH_OUTSIDE_LEASE',
    );
  });

  it('maps invoice unique violations to INVOICE_EXISTS', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);
    prisma.__tx.meterReading.findMany.mockResolvedValue([]);
    prisma.__tx.invoice.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['leaseId', 'billingMonth'] },
    });

    const service = new BillingService(prisma);
    await expect(
      service.createInvoice(landlordId, {
        leaseId: lease.id,
        billingMonth: '2026-08-01',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('maps meter reading unique violations to METER_READING_EXISTS', async () => {
    const prisma = createPrismaMock();
    prisma.lease.findFirst.mockResolvedValue(lease);
    prisma.__tx.meterReading.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['roomId', 'utilityType', 'billingMonth'] },
    });

    const service = new BillingService(prisma);
    await expect(
      service.createInvoice(landlordId, {
        leaseId: lease.id,
        billingMonth: '2026-08-01',
        meterReadings: [
          {
            utilityType: 'electricity',
            previousReading: 120,
            currentReading: 180,
            unitPrice: 3500,
          },
        ],
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('preflights bulk invoices for an owned property', async () => {
    const prisma = createPrismaMock();
    prisma.property.findFirst.mockResolvedValue({ id: 'property-1' });
    prisma.lease.findMany.mockResolvedValue([
      lease,
      {
        ...lease,
        id: 'lease-2',
        roomId: 'room-2',
        tenantId: 'tenant-2',
        room: { id: 'room-2', name: '202' },
        tenant: { id: 'tenant-2', fullName: 'Nguyễn Văn B' },
      },
    ]);
    prisma.invoice.findMany.mockResolvedValue([invoice()]);
    prisma.meterReading.findMany
      .mockResolvedValueOnce([
        {
          id: 'meter-1',
          roomId: 'room-2',
          utilityType: UtilityType.ELECTRICITY,
          billingMonth,
          previousReading: 100,
          currentReading: 150,
          unitPrice: 3500,
          usage: 50,
          amount: 175_000,
          note: null,
        },
      ])
      .mockResolvedValueOnce([
        {
          id: 'meter-previous',
          roomId: 'room-1',
          utilityType: UtilityType.WATER,
          billingMonth: new Date('2026-07-01T00:00:00.000Z'),
          previousReading: 40,
          currentReading: 45,
          unitPrice: 15000,
          usage: 5,
          amount: 75_000,
          note: null,
        },
      ]);

    const service = new BillingService(prisma);
    const result = await service.bulkInvoicePreflight(landlordId, {
      propertyId: 'property-1',
      billingMonth: '2026-08-01',
    });

    expect(prisma.property.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'property-1', landlordId, isArchived: false },
      }),
    );
    expect(result.data.totalCount).toBe(2);
    expect(result.data.existingCount).toBe(1);
    expect(result.data.readyCount).toBe(1);
    expect(result.data.items[0].status).toBe('existing');
    expect(result.data.items[0].suggestedMeterReadings.water).toMatchObject({
      currentReading: 45,
    });
    expect(result.data.items[1].meterReadings.electricity).toMatchObject({
      amount: 175_000,
    });
  });

  it('skips due billing automation until current meter readings exist', async () => {
    const prisma = createPrismaMock();
    prisma.billingAutomation.findMany.mockResolvedValue([
      {
        id: 'automation-1',
        landlordId,
        propertyId: 'property-1',
        isEnabled: true,
        invoiceDay: 1,
        dueDay: 10,
        lastRunMonth: null,
        lastRunAt: null,
        createdAt: new Date(),
        updatedAt: new Date(),
        property: { id: 'property-1', name: 'A', isArchived: false },
        landlord: { id: landlordId, isActive: true },
      },
    ]);
    prisma.property.findFirst.mockResolvedValue({ id: 'property-1' });
    prisma.lease.findMany.mockResolvedValue([lease]);
    prisma.invoice.findMany.mockResolvedValue([]);
    prisma.meterReading.findMany.mockResolvedValue([]);

    const service = new BillingService(prisma);
    const result = await service.runDueBillingAutomations(
      new Date('2026-08-01T03:00:00.000Z'),
    );

    expect(result.data.checkedCount).toBe(1);
    expect(result.data.skippedCount).toBe(1);
    expect(result.data.results[0]).toMatchObject({
      status: 'skipped',
      reason: 'MISSING_METER_READINGS',
      missingReadingCount: 2,
    });
    expect(prisma.billingAutomation.updateMany).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('runs due billing automation once readings are ready', async () => {
    const prisma = createPrismaMock();
    const automation = {
      id: 'automation-1',
      landlordId,
      propertyId: 'property-1',
      isEnabled: true,
      invoiceDay: 1,
      dueDay: 10,
      lastRunMonth: null,
      lastRunAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      property: { id: 'property-1', name: 'A', isArchived: false },
      landlord: { id: landlordId, isActive: true },
    };
    prisma.billingAutomation.findMany.mockResolvedValue([automation]);
    prisma.billingAutomation.findUnique.mockResolvedValue(automation);
    prisma.billingAutomation.updateMany.mockResolvedValue({ count: 1 });
    prisma.billingAutomation.update.mockResolvedValue({
      ...automation,
      lastRunMonth: billingMonth,
      lastRunAt: new Date('2026-08-01T03:00:00.000Z'),
    });
    prisma.property.findFirst.mockResolvedValue({ id: 'property-1' });
    prisma.lease.findMany.mockResolvedValue([lease]);
    prisma.invoice.findMany.mockResolvedValue([]);
    prisma.meterReading.findMany
      .mockResolvedValueOnce([
        {
          id: 'meter-1',
          roomId: lease.roomId,
          utilityType: UtilityType.ELECTRICITY,
          billingMonth,
          previousReading: 100,
          currentReading: 150,
          unitPrice: 3500,
          usage: 50,
          amount: 175_000,
          note: null,
        },
        {
          id: 'meter-2',
          roomId: lease.roomId,
          utilityType: UtilityType.WATER,
          billingMonth,
          previousReading: 20,
          currentReading: 30,
          unitPrice: 15000,
          usage: 10,
          amount: 150_000,
          note: null,
        },
      ])
      .mockResolvedValueOnce([]);
    prisma.__tx.invoice.findMany.mockResolvedValue([]);
    prisma.__tx.meterReading.findMany.mockResolvedValue([
      {
        id: 'meter-1',
        roomId: lease.roomId,
        utilityType: UtilityType.ELECTRICITY,
        billingMonth,
        previousReading: 100,
        currentReading: 150,
        unitPrice: 3500,
        usage: 50,
        amount: 175_000,
        note: null,
      },
      {
        id: 'meter-2',
        roomId: lease.roomId,
        utilityType: UtilityType.WATER,
        billingMonth,
        previousReading: 20,
        currentReading: 30,
        unitPrice: 15000,
        usage: 10,
        amount: 150_000,
        note: null,
      },
    ]);
    prisma.__tx.invoice.create.mockResolvedValue(
      invoice({
        electricityAmount: 175_000,
        waterAmount: 150_000,
        totalAmount: 3_325_000,
      }),
    );

    const service = new BillingService(prisma);
    const result = await service.runDueBillingAutomations(
      new Date('2026-08-01T03:00:00.000Z'),
    );

    expect(prisma.billingAutomation.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          isEnabled: true,
          invoiceDay: { lte: 1 },
        }),
      }),
    );
    expect(prisma.billingAutomation.updateMany).toHaveBeenCalled();
    expect(prisma.__tx.invoice.create).toHaveBeenCalled();
    expect(result.data.createdCount).toBe(1);
    expect(result.data.results[0]).toMatchObject({
      status: 'created',
      createdCount: 1,
    });
  });

  it('creates bulk invoices and reuses existing meter readings', async () => {
    const prisma = createPrismaMock();
    prisma.property.findFirst.mockResolvedValue({ id: 'property-1' });
    prisma.lease.findMany.mockResolvedValue([lease]);
    prisma.__tx.invoice.findMany.mockResolvedValue([]);
    prisma.__tx.meterReading.findMany.mockResolvedValue([
      {
        id: 'meter-1',
        roomId: lease.roomId,
        utilityType: UtilityType.ELECTRICITY,
        billingMonth,
        previousReading: 100,
        currentReading: 150,
        unitPrice: 3500,
        usage: 50,
        amount: 175_000,
        note: null,
      },
    ]);
    prisma.__tx.meterReading.create.mockResolvedValue({
      id: 'meter-2',
      roomId: lease.roomId,
      utilityType: UtilityType.WATER,
      billingMonth,
      previousReading: 20,
      currentReading: 30,
      unitPrice: 15000,
      usage: 10,
      amount: 150_000,
      note: null,
    });
    prisma.__tx.invoice.create.mockResolvedValue(
      invoice({
        electricityAmount: 175_000,
        waterAmount: 150_000,
        totalAmount: 3_325_000,
      }),
    );

    const service = new BillingService(prisma);
    const result = await service.createBulkInvoices(landlordId, {
      propertyId: 'property-1',
      billingMonth: '2026-08-01',
      dueDate: '2026-08-10',
      readings: [
        {
          leaseId: lease.id,
          meterReadings: [
            {
              utilityType: 'water',
              previousReading: 20,
              currentReading: 30,
              unitPrice: 15000,
            },
          ],
        },
      ],
    });

    expect(prisma.__tx.meterReading.create).toHaveBeenCalledTimes(1);
    expect(prisma.__tx.invoice.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          electricityAmount: 175_000,
          waterAmount: 150_000,
          totalAmount: 3_325_000,
        }),
      }),
    );
    expect(result.data.createdCount).toBe(1);
    expect(result.data.existingCount).toBe(0);
    expect(result.data.results[0].status).toBe('created');
  });

  it('rejects bulk invoice generation for foreign or archived properties', async () => {
    const prisma = createPrismaMock();
    prisma.property.findFirst.mockResolvedValue(null);

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.createBulkInvoices(landlordId, {
        propertyId: 'property-1',
        billingMonth: '2026-08-01',
      }),
      'PROPERTY_NOT_FOUND',
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('updates an unpaid invoice without payment history', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(invoice());
    prisma.__tx.invoice.update.mockResolvedValue(
      invoice({ note: 'Đổi hạn', dueDate: new Date('2026-08-12T00:00:00.000Z') }),
    );

    const service = new BillingService(prisma);
    const result = await service.updateInvoice(landlordId, 'invoice-1', {
      dueDate: '2026-08-12',
      note: 'Đổi hạn',
    });

    expect(prisma.__tx.$queryRaw).toHaveBeenCalled();
    expect(prisma.__tx.invoice.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { dueDate: new Date('2026-08-12'), note: 'Đổi hạn' },
      }),
    );
    expect(result.data.note).toBe('Đổi hạn');
  });

  it('rejects invoice updates after payment', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(
      invoice({ paidAmount: 1_000_000, status: InvoiceStatus.PARTIAL }),
    );

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.updateInvoice(landlordId, 'invoice-1', { note: 'Không sửa' }),
      'INVOICE_NOT_EDITABLE',
    );
    expect(prisma.__tx.invoice.update).not.toHaveBeenCalled();
  });

  it('records a partial payment using an invoice row lock', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(invoice());
    prisma.__tx.invoice.update.mockResolvedValue(
      invoice({
        paidAmount: 1_000_000,
        status: InvoiceStatus.PARTIAL,
        payments: [payment()],
      }),
    );

    const service = new BillingService(prisma);
    const result = await service.recordPayment(landlordId, 'invoice-1', {
      amount: 1_000_000,
      method: 'cash',
      paidAt: '2026-08-08T00:00:00.000Z',
    });

    expect(prisma.__tx.$queryRaw).toHaveBeenCalled();
    expect(prisma.__tx.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          amount: 1_000_000,
          type: PaymentType.PAYMENT,
        }),
      }),
    );
    expect(prisma.__tx.invoice.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { paidAmount: 1_000_000, status: InvoiceStatus.PARTIAL },
      }),
    );
    expect(result.data.status).toBe('partial');
  });

  it('marks invoice as paid when a payment exactly matches remaining amount', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(
      invoice({ paidAmount: 1_000_000, status: InvoiceStatus.PARTIAL }),
    );
    prisma.__tx.invoice.update.mockResolvedValue(
      invoice({ paidAmount: 3_360_000, status: InvoiceStatus.PAID }),
    );

    const service = new BillingService(prisma);
    const result = await service.recordPayment(landlordId, 'invoice-1', {
      amount: 2_360_000,
    });

    expect(result.data.status).toBe('paid');
    expect(prisma.__tx.invoice.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { paidAmount: 3_360_000, status: InvoiceStatus.PAID },
      }),
    );
  });

  it('rejects payments greater than the remaining amount', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(invoice({ paidAmount: 3_000_000 }));

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.recordPayment(landlordId, 'invoice-1', { amount: 500_000 }),
      'PAYMENT_EXCEEDS_REMAINING',
    );
    expect(prisma.__tx.payment.create).not.toHaveBeenCalled();
  });

  it('rejects additional payments for already paid invoices', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(
      invoice({ paidAmount: 3_360_000, status: InvoiceStatus.PAID }),
    );

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.recordPayment(landlordId, 'invoice-1', { amount: 1 }),
      'INVOICE_ALREADY_PAID',
    );
  });

  it('rejects payments for cancelled invoices', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(invoice({ status: InvoiceStatus.CANCELLED }));

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.recordPayment(landlordId, 'invoice-1', { amount: 1 }),
      'INVOICE_CANCELLED',
    );
  });

  it('rejects invalid paidAt values at service level', async () => {
    const prisma = createPrismaMock();
    const service = new BillingService(prisma);

    await expectErrorCode(
      service.recordPayment(landlordId, 'invoice-1', {
        amount: 1,
        paidAt: 'not-a-date',
      }),
      'INVALID_PAID_AT',
    );
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('reverses a payment with a signed reversal ledger entry', async () => {
    const prisma = createPrismaMock();
    const original = payment({ amount: 1_000_000 });
    prisma.__tx.invoice.findUnique.mockResolvedValue(
      invoice({ paidAmount: 1_000_000, status: InvoiceStatus.PARTIAL }),
    );
    prisma.__tx.payment.findFirst.mockResolvedValue(original);
    prisma.__tx.invoice.update.mockResolvedValue(
      invoice({
        paidAmount: 0,
        status: InvoiceStatus.UNPAID,
        payments: [payment({ id: 'reversal-1', amount: -1_000_000, type: PaymentType.REVERSAL, reversalOfPaymentId: original.id }), original],
      }),
    );

    const service = new BillingService(prisma);
    const result = await service.reversePayment(landlordId, 'invoice-1', original.id, {
      note: 'Sai giao dịch',
    });

    expect(prisma.__tx.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          amount: -1_000_000,
          type: PaymentType.REVERSAL,
          reversalOfPaymentId: original.id,
          note: 'Sai giao dịch',
        }),
      }),
    );
    expect(result.data.paidAmount).toBe(0);
    expect(result.data.status).toBe('unpaid');
  });

  it('does not reverse the same payment twice', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.payment.findFirst.mockResolvedValue(
      payment({ reversalPayment: payment({ id: 'reversal-1', type: PaymentType.REVERSAL }) }),
    );

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.reversePayment(landlordId, 'invoice-1', 'payment-1', { note: 'duplicate' }),
      'PAYMENT_ALREADY_REVERSED',
    );
  });

  it('does not reverse reversal payments', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.payment.findFirst.mockResolvedValue(
      payment({ type: PaymentType.REVERSAL, amount: -1_000_000 }),
    );

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.reversePayment(landlordId, 'invoice-1', 'reversal-1', { note: 'bad' }),
      'PAYMENT_REVERSAL_NOT_ALLOWED',
    );
  });

  it('returns PAYMENT_NOT_FOUND when the payment is not on the invoice', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.payment.findFirst.mockResolvedValue(null);

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.reversePayment(landlordId, 'invoice-1', 'missing-payment', { note: 'bad' }),
      'PAYMENT_NOT_FOUND',
    );
  });

  it('cancels invoices that have no payment history', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.payment.count.mockResolvedValue(0);
    prisma.__tx.invoice.update.mockResolvedValue(
      invoice({
        status: InvoiceStatus.CANCELLED,
        cancelledAt: new Date('2026-08-09T00:00:00.000Z'),
        cancelledNote: 'Lập nhầm',
      }),
    );

    const service = new BillingService(prisma);
    const result = await service.cancelInvoice(landlordId, 'invoice-1', {
      note: 'Lập nhầm',
    });

    expect(result.data.status).toBe('cancelled');
    expect(result.data.cancelledNote).toBe('Lập nhầm');
  });

  it('does not cancel invoices with any payment history', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.payment.count.mockResolvedValue(1);

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.cancelInvoice(landlordId, 'invoice-1', { note: 'Không dùng' }),
      'INVOICE_HAS_PAYMENTS',
    );
    expect(prisma.__tx.invoice.update).not.toHaveBeenCalled();
  });

  it('does not cancel an already cancelled invoice again', async () => {
    const prisma = createPrismaMock();
    prisma.__tx.invoice.findUnique.mockResolvedValue(invoice({ status: InvoiceStatus.CANCELLED }));

    const service = new BillingService(prisma);
    await expectErrorCode(
      service.cancelInvoice(landlordId, 'invoice-1', { note: 'again' }),
      'INVOICE_ALREADY_CANCELLED',
    );
  });
});
