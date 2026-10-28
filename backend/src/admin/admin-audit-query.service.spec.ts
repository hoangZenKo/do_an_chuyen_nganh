import { BadRequestException } from '@nestjs/common';
import { auditMetadata, auditWhere, csvCell } from './admin-audit-query.service';
import { AdminAuditQuery } from './admin-console.dto';

describe('Admin audit safety', () => {
  it('escapes CSV delimiters, quotes, newlines and formula prefixes', () => {
    expect(csvCell('a,"b"')).toBe('"a,""b"""');
    for (const value of ['=SUM(1,2)', '+123', '-1', '@cmd', '  =cmd', '\tcmd']) {
      expect(csvCell(value).startsWith('"\'')).toBe(true);
    }
    expect(csvCell('Normal text')).toBe('"Normal text"');
  });
  it('redacts credentials, contact details and signed links recursively', () => {
    expect(auditMetadata({ before: { isActive: true, email: 'private@example.com' }, tokenHash: 'digest', secret: 'hidden', note: 'status update' }))
      .toEqual({ before: { isActive: true, email: '[redacted]' }, tokenHash: '[redacted]', secret: '[redacted]', note: 'status update' });
  });
  it('rejects reversed date ranges and composes filters rather than replacing ownership', () => {
    expect(() => auditWhere(Object.assign(new AdminAuditQuery(), { from: '2026-10-25', to: '2026-10-01' }))).toThrow(BadRequestException);
    expect(auditWhere(Object.assign(new AdminAuditQuery(), { actorId: 'actor', requestId: 'trace-1234', action: 'admin.account_suspend' })))
      .toMatchObject({ actorId: 'actor', requestId: 'trace-1234', action: 'admin.account_suspend' });
  });
});
