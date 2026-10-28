import { execFile } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { closeE2eHarness, createE2eHarness, E2eHarness, requestJson } from './e2e-app';
import { resetDatabase } from './e2e-fixtures';

const executeFile = promisify(execFile);
const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q==', 'base64');

describe('Explore preview image registration', () => {
  let harness: E2eHarness;
  let sourceDirectory: string;
  const filenames = Array.from({ length: 11 }, (_, index) =>
    'room_' + String(index + 1).padStart(2, '0') + '.jpeg');

  beforeAll(async () => {
    harness = await createE2eHarness();
    sourceDirectory = join(harness.uploadDirectory, 'source');
    await mkdir(sourceDirectory);
    await Promise.all(filenames.map(filename => writeFile(join(sourceDirectory, filename), jpeg)));
  });
  afterAll(async () => { await closeE2eHarness(harness); });
  beforeEach(async () => { await resetDatabase(harness.prisma); });

  const seed = () => executeFile(process.execPath, [require.resolve('tsx/cli'), 'prisma/seed-explore-preview.ts'], {
    cwd: process.cwd(),
    env: { ...process.env, UPLOADS_DIR: harness.uploadDirectory, SEED_ROOM_IMAGE_DIR: sourceDirectory },
    timeout: 20000,
  });

  async function expectPublicPhotos() {
    const response = await requestJson(harness.baseUrl, '/api/v1/public/listings?limit=50');
    expect(response.status).toBe(200);
    expect(response.json.meta.total).toBe(600);
    const paths = new Set<string>(response.json.data.flatMap((listing: { imageUrls: string[] }) => listing.imageUrls));
    expect(paths.size).toBe(11);
    for (const path of paths) {
      const image = await fetch(harness.baseUrl + path);
      expect(image.status).toBe(200);
      expect(image.headers.get('content-type')).toBe('image/jpeg');
      expect(Buffer.from(await image.arrayBuffer())).toEqual(jpeg);
    }
  }

  it('serves seeded photos and repairs legacy private or missing metadata without publishing private files', async () => {
    await seed();
    await expectPublicPhotos();
    const owner = await harness.prisma.user.findUniqueOrThrow({ where: { email: 'explore-landlord@demo.com' } });
    await harness.prisma.uploadedFile.update({ where: { filename: 'explore-preview-room_01.jpeg' }, data: { purpose: 'PRIVATE' } });
    await harness.prisma.uploadedFile.delete({ where: { filename: 'explore-preview-room_02.jpeg' } });
    await harness.prisma.uploadedFile.create({ data: {
      filename: 'private-receipt.jpeg', ownerId: owner.id, mimeType: 'image/jpeg', purpose: 'PRIVATE',
    } });
    await writeFile(join(harness.uploadDirectory, 'private-receipt.jpeg'), jpeg);
    expect((await fetch(harness.baseUrl + '/uploads/explore-preview-room_01.jpeg')).status).toBe(404);
    expect((await fetch(harness.baseUrl + '/uploads/explore-preview-room_02.jpeg')).status).toBe(404);

    const rerun = await seed();
    expect(JSON.parse(rerun.stdout).created).toEqual({ properties: 0, rooms: 0, listings: 0 });
    await expectPublicPhotos();
    expect(await harness.prisma.uploadedFile.count({ where: { purpose: 'PUBLIC_LISTING' } })).toBe(11);
    expect((await fetch(harness.baseUrl + '/uploads/private-receipt.jpeg')).status).toBe(404);
    expect((await harness.prisma.uploadedFile.findUniqueOrThrow({ where: { filename: 'private-receipt.jpeg' } })).purpose).toBe('PRIVATE');
  });

  it('backfills only published listing photos owned by the landlord and never private attachments', async () => {
    await seed();
    const owner = await harness.prisma.user.findUniqueOrThrow({ where: { email: 'explore-landlord@demo.com' } });
    const other = await harness.prisma.user.create({ data: {
      email: 'migration-other@example.test', fullName: 'Other account', role: 'LANDLORD', passwordHash: owner.passwordHash,
    } });
    const listings = await harness.prisma.roomListing.findMany({ take: 2, include: { room: true }, orderBy: { id: 'asc' } });
    await harness.prisma.roomListing.updateMany({ data: { imageUrls: [], status: 'DRAFT' } });
    await harness.prisma.uploadedFile.updateMany({ data: { purpose: 'PRIVATE' } });
    await harness.prisma.uploadedFile.delete({ where: { filename: 'explore-preview-room_02.jpeg' } });
    await harness.prisma.uploadedFile.update({ where: { filename: 'explore-preview-room_05.jpeg' }, data: { ownerId: other.id } });
    const path = (index: number) => '/uploads/explore-preview-room_0' + index + '.jpeg';
    await harness.prisma.roomListing.update({ where: { id: listings[0].id }, data: {
      status: 'PUBLISHED', imageUrls: [path(1), path(2), path(4), path(5)],
    } });
    await harness.prisma.roomListing.update({ where: { id: listings[1].id }, data: { imageUrls: [path(3)], status: 'DRAFT' } });
    await harness.prisma.maintenanceTicket.create({ data: {
      landlordId: owner.id, propertyId: listings[0].room.propertyId, roomId: listings[0].roomId,
      title: 'Private maintenance evidence', imageUrls: [path(4)],
    } });
    expect((await fetch(harness.baseUrl + path(1))).status).toBe(404);
    expect((await fetch(harness.baseUrl + path(2))).status).toBe(404);

    const migration = await readFile(join(process.cwd(), 'prisma/migrations/20261025113000_repair_public_listing_images/migration.sql'), 'utf8');
    await harness.prisma.$executeRawUnsafe(migration);
    await harness.prisma.$executeRawUnsafe(migration);
    for (const index of [1, 2]) {
      const image = await fetch(harness.baseUrl + path(index));
      expect(image.status).toBe(200);
      expect(image.headers.get('content-type')).toBe('image/jpeg');
    }
    for (const index of [3, 4, 5, 6]) {
      expect((await fetch(harness.baseUrl + path(index))).status).toBe(404);
    }
    expect((await harness.prisma.uploadedFile.findUniqueOrThrow({ where: { filename: 'explore-preview-room_05.jpeg' } })).ownerId).toBe(other.id);
    expect(await harness.prisma.uploadedFile.count({ where: { purpose: 'PUBLIC_LISTING' } })).toBe(2);
  });

  it('refuses to change permissions on a preview filename owned by another account', async () => {
    await seed();
    const owner = await harness.prisma.user.findUniqueOrThrow({ where: { email: 'explore-landlord@demo.com' } });
    const other = await harness.prisma.user.create({ data: {
      email: 'other-preview@example.test', fullName: 'Other account', role: 'LANDLORD', passwordHash: owner.passwordHash,
    } });
    await harness.prisma.uploadedFile.update({ where: { filename: 'explore-preview-room_01.jpeg' }, data: { ownerId: other.id, purpose: 'PRIVATE' } });
    await expect(seed()).rejects.toMatchObject({ stderr: expect.stringContaining('owned by another account') });
    expect(await harness.prisma.uploadedFile.findUniqueOrThrow({ where: { filename: 'explore-preview-room_01.jpeg' } })).toMatchObject({ ownerId: other.id, purpose: 'PRIVATE' });
    expect((await fetch(harness.baseUrl + '/uploads/explore-preview-room_01.jpeg')).status).toBe(404);
  });
});

