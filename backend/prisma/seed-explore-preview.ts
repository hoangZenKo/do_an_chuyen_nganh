import 'dotenv/config';
import { constants } from 'node:fs';
import { copyFile, mkdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { ListingStatus, Prisma, PrismaClient, RoomStatus, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();
const marker = '[explore-preview]';
const email = 'explore-landlord@demo.com';
const roomsPerProperty = 10;

const locations = [
  { city: 'TP. Hồ Chí Minh', adjustment: 600000, districts: ['Thủ Đức', 'Bình Thạnh', 'Gò Vấp', 'Tân Bình', 'Phú Nhuận', 'Quận 1', 'Quận 3', 'Quận 7', 'Quận 10', 'Bình Tân'] },
  { city: 'Hà Nội', adjustment: 500000, districts: ['Cầu Giấy', 'Đống Đa', 'Hai Bà Trưng', 'Thanh Xuân', 'Hoàng Mai', 'Long Biên', 'Hà Đông', 'Nam Từ Liêm', 'Bắc Từ Liêm', 'Tây Hồ'] },
  { city: 'Đà Nẵng', adjustment: 200000, districts: ['Hải Châu', 'Thanh Khê', 'Sơn Trà', 'Ngũ Hành Sơn', 'Liên Chiểu', 'Cẩm Lệ', 'Hòa Xuân', 'An Hải', 'Mỹ An', 'Hòa Khánh'] },
  { city: 'Cần Thơ', adjustment: 0, districts: ['Ninh Kiều', 'Bình Thủy', 'Cái Răng', 'Ô Môn', 'Thốt Nốt', 'An Khánh', 'Hưng Lợi', 'Xuân Khánh', 'An Bình', 'Trà Nóc'] },
  { city: 'Hải Phòng', adjustment: 100000, districts: ['Hồng Bàng', 'Ngô Quyền', 'Lê Chân', 'Hải An', 'Kiến An', 'Đồ Sơn', 'Dương Kinh', 'Thủy Nguyên', 'An Dương', 'Cát Hải'] },
  { city: 'Huế', adjustment: 0, districts: ['Phú Hội', 'Vĩnh Ninh', 'An Cựu', 'Phước Vĩnh', 'Thuận Hòa', 'Tây Lộc', 'Kim Long', 'Vỹ Dạ', 'Xuân Phú', 'An Đông'] },
];

const styles = [
  { name: 'Phòng mini tiết kiệm', rent: 1300000, area: 16, capacity: 1, amenities: ['Wifi', 'Nhà vệ sinh riêng', 'Giờ giấc tự do'] },
  { name: 'Phòng có gác lửng', rent: 2100000, area: 22, capacity: 2, amenities: ['Wifi', 'Gác lửng', 'Nhà vệ sinh riêng', 'Chỗ để xe'] },
  { name: 'Studio ngập ánh sáng', rent: 3600000, area: 28, capacity: 2, amenities: ['Wifi', 'Studio', 'Điều hòa', 'Bếp riêng', 'Cửa sổ', 'Nóng lạnh'] },
  { name: 'Phòng đủ nội thất', rent: 3200000, area: 25, capacity: 2, amenities: ['Wifi', 'Điều hòa', 'Tủ lạnh', 'Giường', 'Tủ quần áo', 'Máy giặt chung'] },
  { name: 'Studio ban công thoáng', rent: 4700000, area: 32, capacity: 2, amenities: ['Wifi', 'Studio', 'Điều hòa', 'Ban công', 'Bếp riêng', 'Tủ lạnh', 'Thang máy'] },
  { name: 'Phòng rộng cho nhóm bạn', rent: 2800000, area: 35, capacity: 4, amenities: ['Wifi', 'Gác lửng', 'Chỗ để xe', 'Bếp riêng', 'Giờ giấc tự do'] },
  { name: 'Căn hộ dịch vụ tiện nghi', rent: 6200000, area: 40, capacity: 3, amenities: ['Wifi', 'Điều hòa', 'Tủ lạnh', 'Máy giặt riêng', 'Thang máy', 'Bảo vệ 24/7', 'Dọn phòng'] },
  { name: 'Studio phong cách tối giản', rent: 4100000, area: 30, capacity: 2, amenities: ['Wifi', 'Studio', 'Điều hòa', 'Nóng lạnh', 'Giường', 'Tủ quần áo', 'Bếp riêng'] },
  { name: 'Căn hộ sân vườn riêng', rent: 7900000, area: 48, capacity: 4, amenities: ['Wifi', 'Điều hòa', 'Ban công', 'Sân vườn', 'Nuôi thú cưng', 'Máy giặt riêng', 'Tủ lạnh'] },
  { name: 'Phòng góc cửa sổ lớn', rent: 2500000, area: 24, capacity: 2, amenities: ['Wifi', 'Cửa sổ', 'Nóng lạnh', 'Nhà vệ sinh riêng', 'Khóa vân tay'] },
];

function idFor(key: string) {
  const digest = createHash('sha256').update(`${marker}:${key}`).digest('hex');
  return `${digest.slice(0, 8)}-${digest.slice(8, 12)}-4${digest.slice(13, 16)}-a${digest.slice(17, 20)}-${digest.slice(20, 32)}`;
}

async function main() {
  const database = new URL(process.env.DATABASE_URL ?? '');
  if (process.env.NODE_ENV === 'production' || !['localhost', '127.0.0.1', '[::1]'].includes(database.hostname)) {
    throw new Error('Explore preview data may only be added to a local database.');
  }

  const imageDirectory = resolve(process.env.SEED_ROOM_IMAGE_DIR ?? '../assets/images/rooms');
  const uploadDirectory = resolve(process.env.UPLOADS_DIR || 'uploads');
  const photos = Array.from({ length: 11 }, (_, index) => `room_${String(index + 1).padStart(2, '0')}.jpeg`);
  for (const photo of photos) {
    await readFile(resolve(imageDirectory, photo));
  }
  await mkdir(uploadDirectory, { recursive: true });
  for (const photo of photos) {
    try {
      await copyFile(resolve(imageDirectory, photo), resolve(uploadDirectory, `explore-preview-${photo}`), constants.COPYFILE_EXCL);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
    }
  }

  const existingOwner = await prisma.user.findUnique({ where: { email } });
  if (existingOwner && (existingOwner.id !== idFor('landlord') || existingOwner.role !== UserRole.LANDLORD || !existingOwner.isActive)) {
    throw new Error('The preview email is already used by another or inactive account; no account will be overwritten.');
  }
  const passwordHash = existingOwner ? existingOwner.passwordHash : await argon2.hash('DemoExplore!2026');
  const properties: Prisma.PropertyCreateManyInput[] = [];
  const rooms: Prisma.RoomCreateManyInput[] = [];
  const listings: (Prisma.RoomListingCreateManyInput & { id: string })[] = [];
  const publishedAt = Date.now();

  for (let districtIndex = 0; districtIndex < 10; districtIndex++) {
    for (const [cityIndex, location] of locations.entries()) {
      const district = location.districts[districtIndex];
      const propertyId = idFor(`property:${cityIndex}:${districtIndex}`);
      const propertyName = `Atrium Demo ${district} ${cityIndex + 1}`;
      const publicAddress = `${20 + districtIndex * 12 + cityIndex} Đường Hoa Nắng (địa chỉ mẫu), ${district}, ${location.city}`;
      properties.push({ id: propertyId, landlordId: idFor('landlord'), name: propertyName, address: publicAddress });

      for (let roomIndex = 0; roomIndex < roomsPerProperty; roomIndex++) {
        const ordinal = roomIndex * 60 + districtIndex * locations.length + cityIndex;
        const style = styles[(roomIndex + cityIndex + districtIndex) % styles.length];
        const roomId = idFor(`room:${cityIndex}:${districtIndex}:${roomIndex}`);
        const roomName = `P.${Math.floor(roomIndex / 2) + 1}0${roomIndex % 2 + 1}`;
        const monthlyRent = style.rent + location.adjustment + districtIndex * 100000 + (roomIndex % 3) * 50000;
        const areaSqm = style.area + districtIndex % 4;
        const imageUrls = Array.from({ length: 3 }, (_, index) => `/uploads/explore-preview-${photos[(ordinal + index * 3) % photos.length]}`);
        const electricityPrice = 3500 + roomIndex % 3 * 250;
        const waterPrice = 18000 + roomIndex % 4 * 2000;
        const serviceFee = 100000 + roomIndex % 5 * 50000;
        const deposit = monthlyRent * (style.rent >= 6000000 ? 2 : 1);
        rooms.push({
          id: roomId, propertyId, name: roomName, floor: Math.floor(roomIndex / 2) + 1,
          areaSqm, basePrice: monthlyRent, status: RoomStatus.VACANT, isActive: true,
          capacity: style.capacity, amenities: style.amenities, imageUrl: imageUrls[0], note: `${marker} Phòng mẫu cho màn Khám phá.`,
        });
        listings.push({
          id: idFor(`listing:${roomId}`), roomId,
          title: `${style.name} tại ${district} · ${roomName}`,
          description: `${style.name} ${areaSqm} m² tại ${district}, ${location.city}, phù hợp ${style.capacity} người. Không gian được bố trí riêng tư, có ${style.amenities.join(', ').toLowerCase()}.\n\nGiá thuê ${monthlyRent.toLocaleString('vi-VN')} đ/tháng; cọc ${deposit.toLocaleString('vi-VN')} đ. Điện ${electricityPrice.toLocaleString('vi-VN')} đ/kWh, nước ${waterPrice.toLocaleString('vi-VN')} đ/m³, phí dịch vụ ${serviceFee.toLocaleString('vi-VN')} đ/tháng. Có thể xem phòng theo lịch hẹn.\n\n${marker} Đây là tin phòng và địa chỉ giả lập để thử giao diện, tìm kiếm, bộ lọc và phân trang; không phải tin cho thuê thực tế.`,
          imageUrls, city: location.city, district, publicAddress, monthlyRent, deposit,
          electricityPrice, waterPrice, serviceFee, areaSqm, amenities: style.amenities,
          status: ListingStatus.PUBLISHED, publishedAt: new Date(publishedAt - ordinal * 60000),
          reviewNote: `${marker} Tin mẫu local, không phải tin đăng thực tế.`,
        });
      }
    }
  }

  const created = await prisma.$transaction(async (transaction) => {
    await transaction.user.upsert({
      where: { email }, update: {},
      create: { id: idFor('landlord'), email, fullName: 'Chủ trọ Khám phá Demo', role: UserRole.LANDLORD, passwordHash },
    });
    for (const photo of photos) {
      const filename = `explore-preview-${photo}`;
      const existingFile = await transaction.uploadedFile.findUnique({ where: { filename } });
      if (existingFile && existingFile.ownerId !== idFor('landlord')) {
        throw new Error('A preview filename is owned by another account; no file permissions will be changed.');
      }
      await transaction.uploadedFile.upsert({
        where: { filename },
        update: { mimeType: 'image/jpeg', purpose: 'PUBLIC_LISTING' },
        create: { filename, ownerId: idFor('landlord'), mimeType: 'image/jpeg', purpose: 'PUBLIC_LISTING' },
      });
    }
    const propertyResult = await transaction.property.createMany({ data: properties, skipDuplicates: true });
    const roomResult = await transaction.room.createMany({ data: rooms, skipDuplicates: true });
    const listingResult = await transaction.roomListing.createMany({ data: listings, skipDuplicates: true });
    return { properties: propertyResult.count, rooms: roomResult.count, listings: listingResult.count };
  }, { timeout: 30000 });

  const visible = await prisma.roomListing.count({ where: {
    id: { in: listings.map((listing) => listing.id) }, status: ListingStatus.PUBLISHED,
    room: { isActive: true, status: RoomStatus.VACANT, property: { isArchived: false, landlord: { isActive: true } } },
  } });
  console.log(JSON.stringify({ created, visiblePreviewListings: visible, cities: locations.map((location) => location.city), localPhotos: photos.length }));
}

main().catch((error: Error) => {
  console.error(error.message);
  process.exitCode = 1;
}).finally(() => prisma.$disconnect());
