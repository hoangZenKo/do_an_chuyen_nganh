import { BadRequestException, ConflictException, Injectable, Logger, NotFoundException, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListingsService } from './listings.service';
import { PublicListingsQuery, SavedSearchDto } from './listings.dto';

@Injectable()
export class SavedSearchesService implements OnModuleInit, OnModuleDestroy {
  constructor(private readonly prisma: PrismaService, private readonly listings: ListingsService) {}
  private readonly logger = new Logger(SavedSearchesService.name);
  private timer?: ReturnType<typeof setInterval>;
  private scanning = false;
  private cursor = '';
  onModuleInit() {
    if (process.env.NODE_ENV === 'test') return;
    this.timer = setInterval(() => {
      void this.scanAll().catch(() => this.logger.warn('Saved search batch failed; the next interval will retry.'));
    }, 15 * 60 * 1000);
    this.timer.unref();
  }
  onModuleDestroy() { if (this.timer) clearInterval(this.timer); }
  list(userId: string) {
    return this.prisma.savedSearch.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } }).then(data => ({ data }));
  }
  async create(userId: string, input: SavedSearchDto) {
    if (input.filters.campusId && !await this.prisma.schoolCampus.findFirst({ where: { id: input.filters.campusId, isActive: true } })) {
      throw new BadRequestException('Cơ sở trường không còn hoạt động.');
    }
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${userId} FOR UPDATE`;
      if (await tx.savedSearch.count({ where: { userId } }) >= 10) throw new ConflictException('Bạn chỉ có thể lưu tối đa 10 tìm kiếm.');
      const { page, limit, ...filters } = input.filters;
      const data = await tx.savedSearch.create({ data: { userId, name: input.name, filters: filters as Prisma.InputJsonObject } });
      return { data };
    });
  }
  async status(userId: string, id: string, enabled: boolean) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "SavedSearch" WHERE id = ${id} AND "userId" = ${userId} FOR UPDATE`;
      const search = await tx.savedSearch.findFirst({ where: { id, userId } });
      if (!search) throw new NotFoundException();
      await tx.savedSearch.update({ where: { id }, data: { enabled, ...(enabled && !search.enabled ? { checkedAt: new Date() } : {}) } });
      return { data: { id, enabled } };
    });
  }
  async remove(userId: string, id: string) {
    if (!(await this.prisma.savedSearch.deleteMany({ where: { id, userId } })).count) throw new NotFoundException();
    return { data: { id } };
  }
  async read(userId: string, id: string) {
    if (!(await this.prisma.savedSearchMatch.updateMany({ where: { id, search: { userId } }, data: { readAt: new Date() } })).count) throw new NotFoundException();
    return { data: { id } };
  }
  async alerts(userId: string, page: number) {
    await this.scanAll(userId);
    const where: Prisma.SavedSearchMatchWhereInput = { search: { userId }, listing: {
      status: 'PUBLISHED', room: { isActive: true, status: 'VACANT', property: { isArchived: false, landlord: { isActive: true } } },
    } };
    const [total, unread, data] = await this.prisma.$transaction([
      this.prisma.savedSearchMatch.count({ where }),
      this.prisma.savedSearchMatch.count({ where: { ...where, readAt: null } }),
      this.prisma.savedSearchMatch.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (page - 1) * 20, take: 20,
        select: { id: true, readAt: true, createdAt: true, search: { select: { name: true } }, listing: { select: { id: true, title: true, monthlyRent: true, publicAddress: true } } } }),
    ]);
    return { data, meta: { total, unread, page, limit: 20 } };
  }
  async scanAll(userId?: string) {
    if (!userId && this.scanning) return;
    if (!userId) this.scanning = true;
    try {
      const where: Prisma.SavedSearchWhereInput = { enabled: true, user: { isActive: true }, ...(userId ? { userId } : {}) };
      let searches = await this.prisma.savedSearch.findMany({ where: { ...where, ...(!userId && this.cursor ? { id: { gt: this.cursor } } : {}) }, orderBy: { id: 'asc' }, take: userId ? 10 : 100 });
      if (!userId && !searches.length && this.cursor) {
        this.cursor = '';
        searches = await this.prisma.savedSearch.findMany({ where, orderBy: { id: 'asc' }, take: 100 });
      }
      if (!userId && searches.length) this.cursor = searches[searches.length - 1].id;
      for (const search of searches) {
        const until = new Date();
        const filters = search.filters as unknown as PublicListingsQuery;
        try {
          if (filters.campusId && !await this.prisma.schoolCampus.findFirst({ where: { id: filters.campusId, isActive: true } })) continue;
          let page = 1;
          const listingIds: string[] = [];
          for (;;) {
            const matches = await this.listings.publicList(Object.assign(new PublicListingsQuery(), filters, { page, limit: 50 }), search.checkedAt, until);
            if (matches.data.length) {
              listingIds.push(...matches.data.map(item => item.id));
            }
            if (page * 50 >= matches.meta.total) break;
            page++;
          }
          await this.prisma.$transaction(async tx => {
            await tx.$queryRaw`SELECT id FROM "SavedSearch" WHERE id = ${search.id} FOR UPDATE`;
            if (!await tx.savedSearch.findFirst({ where: { id: search.id, enabled: true, checkedAt: search.checkedAt, user: { isActive: true } } })) return;
            if (listingIds.length) await tx.savedSearchMatch.createMany({ data: listingIds.map(listingId => ({ savedSearchId: search.id, listingId })), skipDuplicates: true });
            await tx.savedSearch.update({ where: { id: search.id }, data: { checkedAt: until } });
          });
        } catch (error) {
          this.logger.warn(`Saved search scan failed: ${search.id}`);
          if (userId) throw error;
        }
      }
    } finally { if (!userId) this.scanning = false; }
  }
}
