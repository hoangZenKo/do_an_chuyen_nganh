import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { propertyReviewHash as snapshotHash } from './property-review-state';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { platformAudit } from '../platform/platform-audit';
import { RegistryPageDto, ReviewRegistryDto, SubmitPropertyReviewDto } from './admin-registry.dto';

const reviewSelect = { id: true, propertyId: true, status: true, version: true, reviewerId: true,
  reviewNote: true, reviewedAt: true, submittedAt: true, updatedAt: true } as const;
const propertySelect = { id: true, landlordId: true, name: true, address: true, isArchived: true } as const;

@Injectable()
export class AdminPropertyReviewService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: RegistryPageDto) {
    const where = query.status ? { status: query.status } : {};
    return this.prisma.$transaction(async tx => {
      const [data, total] = await Promise.all([
        tx.propertyApprovalReview.findMany({ where, select: { ...reviewSelect, snapshotHash: true, property: { select: propertySelect } },
          orderBy: [{ submittedAt: 'desc' }, { id: 'asc' }], skip: (query.page - 1) * query.limit, take: query.limit }),
        tx.propertyApprovalReview.count({ where }),
      ]);
      return { data: data.map(({ snapshotHash: storedHash, ...row }) => ({ ...row,
        informationChanged: row.property.isArchived || storedHash !== snapshotHash(row.property) })), meta: { page: query.page, limit: query.limit, total } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async submit(actor: AuthUser, propertyId: string, input: SubmitPropertyReviewDto) {
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Property" WHERE id = ${propertyId} FOR UPDATE`;
      const property = await tx.property.findUnique({ where: { id: propertyId }, select: propertySelect });
      if (!property || property.isArchived) throw new NotFoundException('Active property not found.');
      const before = await tx.propertyApprovalReview.findUnique({ where: { propertyId } });
      if ((before?.version ?? 0) !== input.version || (before?.status === 'PENDING' && before.snapshotHash === snapshotHash(property)) ||
        (before?.status === 'APPROVED' && before.snapshotHash === snapshotHash(property))) throw new ConflictException('Review already submitted or changed.');
      const content = { snapshotHash: snapshotHash(property), status: 'PENDING', reviewNote: '', reviewerId: null,
        reviewedAt: null, submittedAt: new Date() };
      const data = before
        ? await tx.propertyApprovalReview.update({ where: { id: before.id }, data: { ...content, version: { increment: 1 } }, select: reviewSelect })
        : await tx.propertyApprovalReview.create({ data: { propertyId, ...content }, select: reviewSelect });
      await platformAudit(tx, actor, 'admin.property_review_submit', 'property_approval', data.id, input.reason,
        { propertyId, before: before ? { status: before.status, version: before.version } : null, after: { status: data.status, version: data.version } });
      return { data };
    });
  }

  async review(actor: AuthUser, id: string, input: ReviewRegistryDto) {
    return this.prisma.$transaction(async tx => {
      const before = await tx.propertyApprovalReview.findUnique({ where: { id }, include: { property: { select: propertySelect } } });
      if (!before) throw new NotFoundException();
      await tx.$queryRaw`SELECT id FROM "Property" WHERE id = ${before.propertyId} FOR UPDATE`;
      const property = await tx.property.findUnique({ where: { id: before.propertyId }, select: propertySelect });
      if (before.version !== input.version || before.status !== 'PENDING' || !property || property.isArchived ||
        before.snapshotHash !== snapshotHash(property)) throw new ConflictException('Property or review changed. Resubmit current information.');
      const reviewedAt = new Date();
      const updated = await tx.propertyApprovalReview.updateMany({ where: { id, version: input.version, status: 'PENDING' },
        data: { status: input.status, version: { increment: 1 }, reviewNote: input.reason, reviewerId: actor.userId, reviewedAt } });
      if (updated.count !== 1) throw new ConflictException('Review changed.');
      await platformAudit(tx, actor, 'admin.property_review', 'property_approval', id, input.reason,
        { propertyId: before.propertyId, before: { status: before.status, version: before.version }, after: { status: input.status, version: input.version + 1 } });
      return { data: { id, propertyId: before.propertyId, status: input.status, version: input.version + 1, reviewedAt } };
    });
  }
}
