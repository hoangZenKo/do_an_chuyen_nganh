import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { AssignSubscriptionDto, RegistryPageDto, SaveServicePlanDto } from './admin-registry.dto';

@Injectable()
export class AdminPlansService {
  constructor(private readonly prisma: PrismaService) {}

  private conflict(error: unknown): never {
    if (error instanceof Prisma.PrismaClientKnownRequestError && ['P2002', 'P2034'].includes(error.code)) {
      throw new ConflictException('Configuration changed. Reload before retrying.');
    }
    throw error;
  }

  async plans(query: RegistryPageDto) {
    return this.prisma.$transaction(async tx => {
      const [data, total] = await Promise.all([
        tx.servicePlan.findMany({ orderBy: [{ price: 'asc' }, { code: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
        tx.servicePlan.count(),
      ]);
      return { data, meta: { page: query.page, limit: query.limit, total }, billingMode: 'ADMINISTRATIVE_ENTITLEMENTS', platformRevenueAvailable: false };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async save(actor: AuthUser, input: SaveServicePlanDto) {
    if (input.code === 'FREE' && input.price !== 0) throw new BadRequestException('Free plan must have zero price.');
    try {
      return await this.prisma.$transaction(async tx => {
        const before = await tx.servicePlan.findUnique({ where: { code: input.code } });
        if ((before?.version ?? 0) !== input.version) throw new ConflictException('Plan changed. Reload.');
        const content = { name: input.name.trim(), price: input.price, maxProperties: input.maxProperties, maxRooms: input.maxRooms, isActive: input.isActive };
        let data;
        if (before) {
          const updated = await tx.servicePlan.updateMany({ where: { id: before.id, version: input.version }, data: { ...content, version: { increment: 1 } } });
          if (updated.count !== 1) throw new ConflictException('Plan changed. Reload.');
          data = await tx.servicePlan.findUniqueOrThrow({ where: { id: before.id } });
        } else {
          data = await tx.servicePlan.create({ data: { code: input.code, ...content } });
        }
        await platformAudit(tx, actor, 'admin.service_plan_save', 'service_plan', data.id, input.reason,
          { before: before ? { version: before.version, price: before.price, maxRooms: before.maxRooms, maxProperties: before.maxProperties, isActive: before.isActive } : null,
            after: { version: data.version, price: data.price, maxRooms: data.maxRooms, maxProperties: data.maxProperties, isActive: data.isActive } });
        return { data };
      });
    } catch (error) { return this.conflict(error); }
  }

  async subscriptions(query: RegistryPageDto) {
    return this.prisma.$transaction(async tx => {
      const [data, total] = await Promise.all([
        tx.landlordSubscription.findMany({ orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
        tx.landlordSubscription.count(),
      ]);
      return { data, meta: { page: query.page, limit: query.limit, total } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async history(id: string, query: RegistryPageDto) {
    if (!await this.prisma.landlordSubscription.findUnique({ where: { id }, select: { id: true } })) throw new NotFoundException();
    return this.prisma.$transaction(async tx => {
      const where = { subscriptionId: id };
      const [data, total] = await Promise.all([
        tx.subscriptionEvent.findMany({ where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
        tx.subscriptionEvent.count({ where }),
      ]);
      return { data, meta: { page: query.page, limit: query.limit, total } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async assign(actor: AuthUser, landlordId: string, input: AssignSubscriptionDto) {
    const endsAt = input.endsAt ? new Date(input.endsAt) : null;
    if (endsAt && endsAt.getTime() <= Date.now()) throw new BadRequestException('Subscription expiry must be in the future.');
    try {
      return await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT id FROM "User" WHERE id = ${landlordId} FOR UPDATE`;
        await tx.$queryRaw`SELECT id FROM "ServicePlan" WHERE id = ${input.planId} FOR SHARE`;
        if (!await tx.user.findFirst({ where: { id: landlordId, role: 'LANDLORD', isActive: true }, select: { id: true } })) throw new NotFoundException('Active landlord not found.');
        const plan = await tx.servicePlan.findUnique({ where: { id: input.planId } });
        if (!plan || !plan.isActive) throw new BadRequestException('Plan is not active.');
        if (plan.version !== input.planVersion) throw new ConflictException('Plan changed. Reload.');
        const before = await tx.landlordSubscription.findUnique({ where: { landlordId } });
        if ((before?.version ?? 0) !== input.version) throw new ConflictException('Subscription changed. Reload.');
        const [properties, rooms] = await Promise.all([
          tx.property.count({ where: { landlordId, isArchived: false } }),
          tx.room.count({ where: { isActive: true, property: { landlordId, isArchived: false } } }),
        ]);
        if (properties > plan.maxProperties || rooms > plan.maxRooms) throw new ConflictException('Current inventory exceeds the selected plan. Existing data will not be deleted.');
        const planSnapshot = { code: plan.code, name: plan.name, price: plan.price, currency: 'VND', interval: 'MONTHLY',
          maxProperties: plan.maxProperties, maxRooms: plan.maxRooms, planVersion: plan.version };
        const content = { planId: plan.id, planSnapshot, startsAt: new Date(), endsAt };
        const data = before
          ? await tx.landlordSubscription.update({ where: { id: before.id }, data: { ...content, version: { increment: 1 } } })
          : await tx.landlordSubscription.create({ data: { landlordId, ...content } });
        await tx.subscriptionEvent.create({ data: { subscriptionId: data.id, actorId: actor.userId,
          action: before ? 'REASSIGNED' : 'ASSIGNED', reason: input.reason, snapshot: { ...planSnapshot, subscriptionVersion: data.version,
            startsAt: content.startsAt.toISOString(), endsAt: endsAt?.toISOString() ?? null } } });
        await platformAudit(tx, actor, 'admin.subscription_assign', 'landlord_subscription', data.id, input.reason,
          { landlordId, before: before ? { version: before.version, planId: before.planId } : null,
            after: { version: data.version, planId: plan.id, terms: planSnapshot }, financialEffect: 'NONE' });
        return { data };
      });
    } catch (error) { return this.conflict(error); }
  }
}
