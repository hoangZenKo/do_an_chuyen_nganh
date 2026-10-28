import 'dotenv/config';
import { LeaseStatus, PrismaClient, RoomStatus, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

// Demo landlord credentials — override via env if desired.
const DEMO_EMAIL =
  process.env.SEED_LANDLORD_EMAIL?.trim().toLowerCase() ?? 'landlord@demo.com';
const DEMO_NAME = process.env.SEED_LANDLORD_NAME?.trim() ?? 'Chủ trọ Demo';
const DEMO_PASSWORD =
  process.env.SEED_LANDLORD_PASSWORD ?? 'DemoLandlord!2026';

const ROOMS: {
  name: string;
  floor: number;
  areaSqm: number;
  basePrice: number;
  status: RoomStatus;
  tenantName?: string;
  capacity: number;
  amenities: string[];
  note?: string;
}[] = [
  { name: 'P.101', floor: 1, areaSqm: 18, basePrice: 2150000, status: RoomStatus.OCCUPIED, tenantName: 'Nguyễn Văn D', capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Ban công', 'Gác lửng'], note: 'Phòng góc, view thoáng, đã lắp máy nước nóng mới.' },
  { name: 'P.102', floor: 1, areaSqm: 22, basePrice: 3200000, status: RoomStatus.VACANT, capacity: 2, amenities: ['Nóng lạnh', 'Wifi'] },
  { name: 'P.201', floor: 2, areaSqm: 25, basePrice: 3500000, status: RoomStatus.OCCUPIED, tenantName: 'Nguyễn Văn A', capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Ban công'] },
  { name: 'P.202', floor: 2, areaSqm: 28, basePrice: 3800000, status: RoomStatus.VACANT, capacity: 3, amenities: ['Wifi', 'Máy lạnh', 'Tủ lạnh'] },
  { name: 'P.302', floor: 3, areaSqm: 30, basePrice: 4000000, status: RoomStatus.MAINTENANCE, tenantName: 'Lê Văn C', capacity: 4, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh'] },
  { name: 'P.103', floor: 1, areaSqm: 20, basePrice: 2800000, status: RoomStatus.VACANT, capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Tủ quần áo'] },
  { name: 'P.104', floor: 1, areaSqm: 24, basePrice: 3100000, status: RoomStatus.OCCUPIED, tenantName: 'Phạm Minh K', capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh'], note: 'Đã thay khóa cửa điện tử.' },
  { name: 'P.105', floor: 1, areaSqm: 16, basePrice: 2400000, status: RoomStatus.VACANT, capacity: 1, amenities: ['Wifi', 'Tủ lạnh mini'] },
  { name: 'P.203', floor: 2, areaSqm: 21, basePrice: 2900000, status: RoomStatus.OCCUPIED, tenantName: 'Đỗ Thu H', capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Ban công'] },
  { name: 'P.204', floor: 2, areaSqm: 26, basePrice: 3600000, status: RoomStatus.VACANT, capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Ban công'] },
  { name: 'P.205', floor: 2, areaSqm: 18, basePrice: 2700000, status: RoomStatus.MAINTENANCE, capacity: 2, amenities: ['Wifi', 'Máy lạnh'], note: 'Đang sơn lại tường và kiểm tra điều hòa.' },
  { name: 'P.206', floor: 2, areaSqm: 23, basePrice: 3300000, status: RoomStatus.VACANT, capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Tủ lạnh mini'] },
  { name: 'P.301', floor: 3, areaSqm: 22, basePrice: 3200000, status: RoomStatus.OCCUPIED, tenantName: 'Võ Quốc T', capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Máy giặt chung'] },
  { name: 'P.303', floor: 3, areaSqm: 27, basePrice: 3700000, status: RoomStatus.VACANT, capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Tủ lạnh'] },
  { name: 'P.304', floor: 3, areaSqm: 19, basePrice: 2850000, status: RoomStatus.OCCUPIED, tenantName: 'Ngô Hà M', capacity: 2, amenities: ['Wifi', 'Ban công', 'Tủ quần áo'] },
  { name: 'P.305', floor: 3, areaSqm: 31, basePrice: 4200000, status: RoomStatus.VACANT, capacity: 4, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Ban công', 'Gác lửng'] },
  { name: 'P.306', floor: 3, areaSqm: 17, basePrice: 2500000, status: RoomStatus.VACANT, capacity: 1, amenities: ['Wifi', 'Tủ quần áo'] },
  { name: 'P.401', floor: 4, areaSqm: 20, basePrice: 3000000, status: RoomStatus.OCCUPIED, tenantName: 'Bùi Gia P', capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh'] },
  { name: 'P.402', floor: 4, areaSqm: 25, basePrice: 3500000, status: RoomStatus.VACANT, capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Ban công'] },
  { name: 'P.403', floor: 4, areaSqm: 29, basePrice: 4100000, status: RoomStatus.VACANT, capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Tủ lạnh', 'Ban công'] },
  { name: 'P.404', floor: 4, areaSqm: 18, basePrice: 2750000, status: RoomStatus.MAINTENANCE, capacity: 2, amenities: ['Wifi', 'Máy lạnh'], note: 'Chờ thay máy nước nóng.' },
  { name: 'P.405', floor: 4, areaSqm: 33, basePrice: 4500000, status: RoomStatus.OCCUPIED, tenantName: 'Trương Anh Q', capacity: 4, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Gác lửng', 'Ban công'] },
  { name: 'P.501', floor: 5, areaSqm: 22, basePrice: 3400000, status: RoomStatus.VACANT, capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Ban công'] },
  { name: 'P.502', floor: 5, areaSqm: 28, basePrice: 3900000, status: RoomStatus.OCCUPIED, tenantName: 'Lý Thanh N', capacity: 3, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Tủ lạnh'] },
  { name: 'P.503', floor: 5, areaSqm: 24, basePrice: 3600000, status: RoomStatus.VACANT, capacity: 2, amenities: ['Nóng lạnh', 'Wifi', 'Máy lạnh', 'Ban công'] },
  { name: 'P.504', floor: 5, areaSqm: 30, basePrice: 4300000, status: RoomStatus.MAINTENANCE, capacity: 3, amenities: ['Wifi', 'Máy lạnh', 'Tủ lạnh'], note: 'Đang xử lý thấm trần sau mưa.' },
];

async function main() {
  const passwordHash = await argon2.hash(DEMO_PASSWORD);
  const landlord = await prisma.user.upsert({
    where: { email: DEMO_EMAIL },
    create: {
      email: DEMO_EMAIL,
      fullName: DEMO_NAME,
      phone: '+84901234567',
      passwordHash,
      role: UserRole.LANDLORD,
    },
    update: { fullName: DEMO_NAME },
  });

  // Reuse an existing demo property by name, else create it.
  const existing = await prisma.property.findFirst({
    where: { landlordId: landlord.id, name: 'Nhà trọ An Bình' },
  });
  const property =
    existing ??
    (await prisma.property.create({
      data: {
        landlordId: landlord.id,
        name: 'Nhà trọ An Bình',
        address: '123 Đường số 8, P. Linh Xuân, TP. Thủ Đức',
      },
    }));

  for (const room of ROOMS) {
    const found = await prisma.room.findFirst({
      where: { propertyId: property.id, name: room.name },
    });
    if (found) {
      // Backfill the new detail fields on rooms seeded before this migration.
      await prisma.room.update({
        where: { id: found.id },
        data: {
          floor: room.floor,
          areaSqm: room.areaSqm,
          basePrice: room.basePrice,
          capacity: room.capacity,
          amenities: room.amenities,
          note: room.note ?? found.note,
        },
      });
      continue;
    }
    await prisma.room.create({
      data: {
        propertyId: property.id,
        name: room.name,
        floor: room.floor,
        areaSqm: room.areaSqm,
        basePrice: room.basePrice,
        status: room.status,
        tenantName: room.tenantName ?? null,
        capacity: room.capacity,
        amenities: room.amenities,
        note: room.note ?? null,
      },
    });
  }

  // Demo tenants.
  const tenantSeeds = [
    { fullName: 'Nguyễn Văn A', phone: '+84901111111', idNumber: '079090001111' },
    { fullName: 'Trần Thị B', phone: '+84902222222', idNumber: '079090002222' },
  ];
  const tenants = [] as { id: string; fullName: string }[];
  for (const t of tenantSeeds) {
    const existingT = await prisma.tenant.findFirst({
      where: { landlordId: landlord.id, fullName: t.fullName },
    });
    const tenant =
      existingT ??
      (await prisma.tenant.create({
        data: { landlordId: landlord.id, ...t },
      }));
    tenants.push({ id: tenant.id, fullName: tenant.fullName });
  }

  // Give P.201 an active lease with tenant "Nguyễn Văn A" to match its status.
  const p201 = await prisma.room.findFirst({
    where: { propertyId: property.id, name: 'P.201' },
  });
  if (p201) {
    const hasActive = await prisma.lease.findFirst({
      where: { roomId: p201.id, status: LeaseStatus.ACTIVE },
    });
    if (!hasActive) {
      await prisma.lease.create({
        data: {
          roomId: p201.id,
          tenantId: tenants[0].id,
          startDate: new Date('2025-01-01'),
          monthlyRent: p201.basePrice,
          deposit: p201.basePrice,
          status: LeaseStatus.ACTIVE,
        },
      });
      await prisma.room.update({
        where: { id: p201.id },
        data: { status: RoomStatus.OCCUPIED, tenantName: tenants[0].fullName },
      });
    }
  }

  const roomCount = await prisma.room.count({ where: { propertyId: property.id } });
  const tenantCount = await prisma.tenant.count({ where: { landlordId: landlord.id } });
  const leaseCount = await prisma.lease.count();
  console.log(`Seed ready:`);
  console.log(`  Landlord: ${DEMO_EMAIL} / ${DEMO_PASSWORD}`);
  console.log(`  Property: ${property.name} (${property.id})`);
  console.log(`  Rooms: ${roomCount} | Tenants: ${tenantCount} | Leases: ${leaseCount}`);
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
