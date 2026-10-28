import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AdminService } from './admin.service';

describe('Admin property and room inventory', () => {
  const owner = { id: 'owner', fullName: 'Owner', email: 'private@example.test', phone: '0901234567', isActive: false };
  const room = { id: 'room', name: 'A.101', status: 'VACANT', isActive: true, basePrice: 3500000,
    floor: 2, areaSqm: 24, propertyId: 'property', property: { id: 'property', name: 'Building', address: 'Address', isArchived: true, landlord: owner },
    listing: { id: 'listing', title: 'Public title', status: 'PENDING', version: 3, monthlyRent: 4000000 } };
  let tx: any;
  let service: AdminService;
  beforeEach(() => {
    const { property, propertyId, ...preview } = room;
    tx = { property: { findUnique: jest.fn().mockResolvedValue({ ...property, rooms: [preview], _count: { rooms: 25 } }),
      findMany: jest.fn().mockResolvedValue([]), count: jest.fn().mockResolvedValue(0) },
      room: { count: jest.fn().mockResolvedValue(21), findMany: jest.fn().mockResolvedValue([room]),
        groupBy: jest.fn().mockResolvedValue([{ status: 'VACANT', _count: { _all: 25 } }]) } };
    service = new AdminService({ ...tx, $transaction: jest.fn(work => work(tx)) } as any, {} as any);
  });

  it('bounds the property preview while retaining full counts and lifecycle fields', async () => {
    const result = await service.getProperty('property');
    expect(result.data).toMatchObject({ isArchived: true, roomCount: 25, vacantCount: 25,
      rooms: [expect.objectContaining({ basePrice: 3500000, isActive: true, listing: { id: 'listing', title: 'Public title', status: 'PENDING', version: 3, monthlyRent: 4000000 } })] });
    expect(tx.property.findUnique).toHaveBeenCalledWith(expect.objectContaining({ select: expect.objectContaining({
      rooms: expect.objectContaining({ take: 20, orderBy: [{ name: 'asc' }, { id: 'asc' }] }),
    }) }));
    expect(JSON.stringify(result)).not.toContain(owner.email);
    expect(JSON.stringify(result)).not.toContain(owner.phone);
  });

  it('returns stable page metadata and masks owner contacts without exposing tenant data', async () => {
    const result = await (service as any).rooms({ page: 2, limit: 20, status: 'VACANT', activity: 'active', propertyId: 'property',
      landlordId: 'owner', minPrice: 1000000, maxPrice: 4000000, listingStatus: 'PENDING', search: 'A.101' });
    expect(result.meta).toEqual({ total: 21, page: 2, limit: 20, pages: 2 });
    expect(result.data[0]).toMatchObject({ basePrice: 3500000, property: { isArchived: true, landlord: { email: 'p***@example.test', phone: '***567' } } });
    expect(tx.room.findMany).toHaveBeenCalledWith(expect.objectContaining({ skip: 20, take: 20,
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], where: expect.objectContaining({ propertyId: 'property', status: 'VACANT',
        isActive: true, basePrice: { gte: 1000000, lte: 4000000 }, listing: { is: { status: 'PENDING' } } }) }));
    const selection = tx.room.findMany.mock.calls[0][0].select;
    for (const privateField of ['tenantName', 'note', 'leases', 'invoices']) expect(selection[privateField]).toBeUndefined();
    expect(JSON.stringify(result)).not.toContain(owner.email);
  });

  it('rejects reversed prices before persistence and supports rooms without listings', async () => {
    await expect((service as any).rooms({ page: 1, limit: 20, minPrice: 2, maxPrice: 1 })).rejects.toThrow(BadRequestException);
    expect(tx.room.findMany).not.toHaveBeenCalled();
    await (service as any).rooms({ page: 1, limit: 20, listingStatus: 'NONE' });
    expect(tx.room.count).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({ listing: { is: null } }) }));
  });

  it('returns 404 for a missing property', async () => {
    tx.property.findUnique.mockResolvedValue(null);
    await expect(service.getProperty('missing')).rejects.toThrow(NotFoundException);
  });
});
