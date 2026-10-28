import { NotFoundException } from '@nestjs/common';
import { InvoiceStatus, RoomStatus } from '@prisma/client';

import { DashboardService } from './dashboard.service';

const landlordId = 'landlord-1';

function createPrismaMock() {
  return {
    property: { findFirst: jest.fn() },
    room: { groupBy: jest.fn(), findMany: jest.fn() },
    lease: { count: jest.fn() },
    invoice: { findMany: jest.fn() },
    payment: { findMany: jest.fn() },
    $transaction: jest.fn(),
  } as any;
}

describe('DashboardService', () => {
  beforeAll(() => {
    jest.useFakeTimers().setSystemTime(new Date('2026-08-06T10:00:00.000Z'));
  });

  afterAll(() => jest.useRealTimers());

  beforeEach(() => jest.clearAllMocks());

  it('scopes every aggregate query to the authenticated landlord', async () => {
    const prisma = createPrismaMock();
    prisma.room.groupBy.mockReturnValue('room-groups');
    prisma.lease.count.mockReturnValue('lease-count');
    prisma.invoice.findMany
      .mockReturnValueOnce('current-invoices')
      .mockReturnValueOnce('overdue-invoices')
      .mockReturnValueOnce('due-soon-invoices')
      .mockReturnValueOnce('recent-invoices');
    prisma.payment.findMany.mockReturnValue('payments');
    prisma.room.findMany.mockReturnValue('maintenance-rooms');
    prisma.$transaction.mockResolvedValue([[], 0, [], [], [], [], [], []]);

    const service = new DashboardService(prisma);
    await service.metrics(landlordId, { months: 6 });

    const roomScope = {
      isActive: true,
      property: { landlordId, isArchived: false },
    };
    expect(prisma.room.groupBy).toHaveBeenCalledWith(
      expect.objectContaining({ where: roomScope }),
    );
    expect(prisma.lease.count).toHaveBeenCalledWith({
      where: { status: 'ACTIVE', room: roomScope },
    });
    expect(prisma.invoice.findMany).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({ where: expect.objectContaining({ room: roomScope }) }),
    );
    expect(prisma.payment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          invoice: expect.objectContaining({ room: roomScope }),
        }),
      }),
    );
    expect(prisma.room.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { ...roomScope, status: RoomStatus.MAINTENANCE },
      }),
    );
  });

  it('rejects a property that is not owned by the landlord', async () => {
    const prisma = createPrismaMock();
    prisma.property.findFirst.mockResolvedValue(null);

    const service = new DashboardService(prisma);
    await expect(
      service.metrics(landlordId, { propertyId: 'property-1' }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.property.findFirst).toHaveBeenCalledWith({
      where: { id: 'property-1', landlordId, isArchived: false },
      select: { id: true },
    });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('maps counts, outstanding totals, revenue buckets, attention and invoices', async () => {
    const prisma = createPrismaMock();
    prisma.room.groupBy.mockReturnValue('room-groups');
    prisma.lease.count.mockReturnValue('lease-count');
    prisma.invoice.findMany
      .mockReturnValueOnce('current-invoices')
      .mockReturnValueOnce('overdue-invoices')
      .mockReturnValueOnce('due-soon-invoices')
      .mockReturnValueOnce('recent-invoices');
    prisma.payment.findMany.mockReturnValue('payments');
    prisma.room.findMany.mockReturnValue('maintenance-rooms');
    prisma.$transaction.mockResolvedValue([
      [
        { status: RoomStatus.OCCUPIED, _count: { _all: 2 } },
        { status: RoomStatus.VACANT, _count: { _all: 1 } },
        { status: RoomStatus.MAINTENANCE, _count: { _all: 1 } },
      ],
      2,
      [
        { totalAmount: 4_000_000, paidAmount: 4_500_000 },
        { totalAmount: 3_000_000, paidAmount: 1_000_000 },
      ],
      [
        { amount: 1_000_000, paidAt: new Date('2026-07-20T00:00:00.000Z') },
        { amount: 2_500_000, paidAt: new Date('2026-08-02T00:00:00.000Z') },
      ],
      [
        {
          id: 'invoice-overdue',
          roomId: 'room-201',
          tenantId: 'tenant-1',
          totalAmount: 3_000_000,
          paidAmount: 1_000_000,
          dueDate: new Date('2026-08-01T00:00:00.000Z'),
          room: { name: '201' },
          tenant: { fullName: 'Nguyễn Văn A' },
        },
      ],
      [
        {
          id: 'invoice-due-soon',
          roomId: 'room-202',
          tenantId: 'tenant-3',
          totalAmount: 3_200_000,
          paidAmount: 1_200_000,
          dueDate: new Date('2026-08-10T00:00:00.000Z'),
          room: { name: '202' },
          tenant: { fullName: 'Nguyễn Văn C' },
        },
      ],
      [
        {
          id: 'room-302',
          name: '302',
          propertyId: 'property-1',
          updatedAt: new Date('2026-08-04T00:00:00.000Z'),
          property: { name: 'Nhà trọ A' },
        },
      ],
      [
        {
          id: 'invoice-new',
          roomId: 'room-101',
          tenantId: 'tenant-2',
          billingMonth: new Date('2026-08-01T00:00:00.000Z'),
          totalAmount: 3_500_000,
          paidAmount: 3_500_000,
          status: InvoiceStatus.PAID,
          dueDate: new Date('2026-08-10T00:00:00.000Z'),
          issuedAt: new Date('2026-08-05T00:00:00.000Z'),
          room: { name: '101' },
          tenant: { fullName: 'Nguyễn Văn B' },
        },
      ],
    ]);

    const service = new DashboardService(prisma);
    const result = await service.metrics(landlordId, { months: 3 });

    expect(result.data.roomStats).toEqual({
      total: 4,
      occupied: 2,
      vacant: 1,
      maintenance: 1,
      occupancyRate: 50,
    });
    expect(result.data.currentMonth).toEqual({
      invoiceCount: 2,
      billedAmount: 7_000_000,
      receivedAmount: 2_500_000,
      outstandingInvoiceCount: 1,
      outstandingAmount: 2_000_000,
    });
    expect(result.data.revenueTrend).toEqual([
      { month: '2026-06-01T00:00:00.000Z', amount: 0 },
      { month: '2026-07-01T00:00:00.000Z', amount: 1_000_000 },
      { month: '2026-08-01T00:00:00.000Z', amount: 2_500_000 },
    ]);
    expect(result.data.attentionItems).toEqual([
      expect.objectContaining({
        kind: 'overdue_invoice',
        invoiceId: 'invoice-overdue',
        remainingAmount: 2_000_000,
      }),
      expect.objectContaining({
        kind: 'due_soon_invoice',
        invoiceId: 'invoice-due-soon',
        remainingAmount: 2_000_000,
      }),
      expect.objectContaining({
        kind: 'maintenance_room',
        roomId: 'room-302',
        propertyName: 'Nhà trọ A',
      }),
    ]);
    expect(result.data.recentInvoices).toEqual([
      expect.objectContaining({
        id: 'invoice-new',
        remainingAmount: 0,
        status: 'paid',
      }),
    ]);
  });
});
