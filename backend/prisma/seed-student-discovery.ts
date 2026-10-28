import 'dotenv/config';
import { createHash } from 'node:crypto';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const cities = [
  { city: 'TP. Hồ Chí Minh', latitude: 10.85, longitude: 106.76 },
  { city: 'Hà Nội', latitude: 21.035, longitude: 105.79 },
  { city: 'Đà Nẵng', latitude: 16.06, longitude: 108.20 },
  { city: 'Cần Thơ', latitude: 10.03, longitude: 105.77 },
  { city: 'Hải Phòng', latitude: 20.84, longitude: 106.68 },
  { city: 'Huế', latitude: 16.45, longitude: 107.60 },
];

async function main() {
  const database = new URL(process.env.DATABASE_URL ?? '');
  if (process.env.NODE_ENV === 'production' || !['localhost', '127.0.0.1', '[::1]'].includes(database.hostname)) {
    throw new Error('Student discovery fixtures require a local database.');
  }
  let updated = 0;
  for (const location of cities) {
    const digest = createHash('sha256').update(`student-campus:${location.city}`).digest('hex');
    const id = `${digest.slice(0, 8)}-${digest.slice(8, 12)}-4${digest.slice(13, 16)}-a${digest.slice(17, 20)}-${digest.slice(20, 32)}`;
    await prisma.schoolCampus.upsert({ where: { id }, update: {}, create: {
      id, name: `Trường mẫu ${location.city}`, campus: 'Cơ sở mô phỏng', city: location.city,
      address: 'Vị trí giả lập phục vụ kiểm thử, không phải địa chỉ trường thực tế.',
      latitude: location.latitude, longitude: location.longitude, isDemo: true,
    } });
    const listings = await prisma.roomListing.findMany({ where: {
      city: location.city, description: { contains: '[explore-preview]' }, latitude: null, longitude: null,
      room: { property: { landlord: { email: 'explore-landlord@demo.com' } } },
    }, orderBy: { id: 'asc' }, select: { id: true } });
    await prisma.$transaction(listings.map((listing, index) => {
      const angle = index * 2.399963;
      const radius = 0.3 + index % 20 * 0.4;
      return prisma.roomListing.update({ where: { id: listing.id }, data: {
        latitude: location.latitude + Math.sin(angle) * radius / 111,
        longitude: location.longitude + Math.cos(angle) * radius / (111 * Math.cos(location.latitude * Math.PI / 180)),
      } });
    }));
    updated += listings.length;
  }
  console.log(JSON.stringify({ demoCampuses: cities.length, demoListingCoordinatesAdded: updated, warning: 'All campus names and coordinates are illustrative, not real university data.' }));
}
main().catch((error: Error) => { console.error(error.message); process.exitCode = 1; }).finally(() => prisma.$disconnect());
