import { createHash } from 'node:crypto';

export type ReviewProperty = { id: string; landlordId: string; name: string; address: string; isArchived: boolean };
export function propertyReviewHash(property: ReviewProperty) {
  return createHash('sha256').update(JSON.stringify({ id: property.id, landlordId: property.landlordId,
    name: property.name, address: property.address, isArchived: property.isArchived })).digest('hex');
}
export const propertyApprovalSelect = { id: true, status: true, version: true, snapshotHash: true, reviewedAt: true } as const;
export function propertyApprovalState(property: ReviewProperty, review?: { id: string; status: string; version: number; snapshotHash: string; reviewedAt: Date | null } | null) {
  const informationChanged = !!review && review.snapshotHash !== propertyReviewHash(property);
  return { id: review?.id ?? null, status: informationChanged ? 'NEEDS_INFO' : review?.status ?? 'NOT_SUBMITTED',
    version: review?.version ?? 0, reviewedAt: review?.reviewedAt ?? null, informationChanged };
}
