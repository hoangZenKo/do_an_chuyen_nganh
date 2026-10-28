import { adminRequestFingerprint, sensitiveAdminAction } from './admin-step-up.policy';

describe('admin step-up request policy', () => {
  it.each([
    ['/admin/landlord-verifications/id/review', 'verification.review'],
    ['/admin/property-reviews/id/review', 'property.review'],
    ['/admin/service-plans', 'plan.save'],
    ['/admin/landlords/id/subscription', 'subscription.assign'],
    ['/admin/subscriptions/id/cancel', 'subscription.cancel'],
  ])('protects registry mutations: %s', (path, action) => {
    expect(sensitiveAdminAction('POST', path)?.action).toBe(action);
    expect(sensitiveAdminAction('GET', path)).toBeUndefined();
  });
  it('matches only sensitive admin routes', () => {
    expect(sensitiveAdminAction('POST', '/api/v1/admin/audit-logs/export')?.action).toBe('audit.export');
    expect(sensitiveAdminAction('POST', '/api/v1/admin/accounts/id/reveal')?.action).toBe('pii.reveal');
    expect(sensitiveAdminAction('PATCH', '/api/v1/admin/landlords/id/status')?.action).toBe('landlord.status');
    expect(sensitiveAdminAction('GET', '/api/v1/admin/audit-logs')).toBeUndefined();
    expect(sensitiveAdminAction('POST', '/api/v1/admin/audit-logs/export/')).toBeDefined();
  });

  it('canonicalizes payload key order for single-request grants', () => {
    expect(adminRequestFingerprint('POST', '/api/v1/admin/audit-logs/export', { b: 2, a: 1 }))
      .toBe(adminRequestFingerprint('post', '/admin/audit-logs/export', { a: 1, b: 2 }));
    expect(adminRequestFingerprint('POST', '/admin/audit-logs/export', { a: 1 }))
      .not.toBe(adminRequestFingerprint('POST', '/admin/audit-logs/export', { a: 2 }));
  });

  it('protects case-insensitive and percent-encoded Express route aliases', () => {
    for (const path of ['/API/V1/ADMIN/accounts/id/REVEAL/', '/admin/accounts/id/%72eveal']) {
      expect(sensitiveAdminAction('POST', path)?.action).toBe('pii.reveal');
      expect(adminRequestFingerprint('POST', path, { reason: 'Review case' }))
        .toBe(adminRequestFingerprint('POST', '/admin/accounts/id/reveal', { reason: 'Review case' }));
    }
    expect(sensitiveAdminAction('POST', '/admin/accounts/id/%XX')).toBeUndefined();
  });
});
