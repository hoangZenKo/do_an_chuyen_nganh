const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const req = require('node:module').createRequire(path.join(root, 'backend/package.json'));
const ts = req('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020, experimentalDecorators: true, emitDecoratorMetadata: true, esModuleInterop: true } }).outputText, filename);
req('reflect-metadata');
const { LeasesService } = req(path.join(root, 'backend/src/leases/leases.service.ts'));
const { HousingService } = req(path.join(root, 'backend/src/housing/housing.service.ts'));
const { CreateLeaseDto } = req(path.join(root, 'backend/src/leases/dto/create-lease.dto.ts'));
const { TenantLifecycleService } = req(path.join(root, 'backend/src/tenant-lifecycle/tenant-lifecycle.service.ts'));
const { AdminVerificationService } = req(path.join(root, 'backend/src/admin/admin-verification.service.ts'));
const { RoomsService } = req(path.join(root, 'backend/src/rooms/rooms.service.ts'));
const { validate } = req('class-validator');
const results = [];
async function check(name, action) { await action(); results.push({ name, passed: true }); }
function txForLease() {
  const collected = [];
  const tx = {
    $queryRaw: async () => [],
    room: { findFirst: async () => ({ id: 'room', isActive: true, status: 'VACANT', capacity: 1, property: { isArchived: false } }), update: async input => input.data },
    roomTurnover: { count: async () => 0 },
    tenant: { findFirst: async () => ({ id: 'tenant', isActive: true, fullName: 'Nguoi thue' }) },
    lease: { findFirst: async () => null, create: async input => ({ id: 'lease', ...input.data }) },
    depositTransaction: { create: async input => { collected.push(input.data); return input.data; } },
  };
  return { tx, collected };
}
(async () => {
  await check('UC-TNT-05: CreateLeaseDto rejects endDate as non-whitelisted input', async () => {
    const input = Object.assign(new CreateLeaseDto(), { roomId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', tenantId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', monthlyRent: 100, deposit: 50, endDate: '2026-12-31' });
    const errors = await validate(input, { whitelist: true, forbidNonWhitelisted: true });
    assert(errors.some(error => error.property === 'endDate' && error.constraints.whitelistValidation));
  });
  await check('UC-TNT-05: direct creation records positive deposit and has no capacity rule in this method', async () => {
    const { tx, collected } = txForLease();
    const created = await new LeasesService({}).createWithinTransaction(tx, 'owner', { roomId: 'room', tenantId: 'tenant', monthlyRent: 100, deposit: 50 });
    assert.equal(created.status, 'ACTIVE'); assert.equal(created.endDate, undefined);
    assert(!LeasesService.prototype.createWithinTransaction.toString().includes('.capacity'));
    assert.equal(collected.length, 1); assert.equal(collected[0].type, 'COLLECTED'); assert.equal(collected[0].amount, 50);
  });
  await check('UC-TNT-05: completed-viewing variant stores agreed deposit but creates no collected-deposit transaction', async () => {
    const { tx, collected } = txForLease();
    const viewing = { id: 'viewing', version: 1, status: 'COMPLETED', listingId: 'listing', studentId: 'student' };
    tx.roomViewing = { findFirst: async () => viewing, findUniqueOrThrow: async () => viewing, update: async () => ({}), findMany: async () => [], updateMany: async () => ({ count: 0 }) };
    tx.roomListing = { findFirst: async () => ({ id: 'listing', roomId: 'room', title: 'Tin phong' }), update: async () => ({}) };
    tx.user = { findUniqueOrThrow: async () => ({ id: 'student', isActive: true, fullName: 'Nguoi thue' }) };
    tx.tenant.findUnique = async () => ({ id: 'tenant', landlordId: 'owner', isActive: true });
    tx.housingNotification = { create: async () => ({}) }; tx.auditLog = { create: async () => ({}) };
    const housing = new HousingService({ $transaction: action => action(tx) }, new LeasesService({}), {});
    const result = await housing.createLease({ userId: 'owner', role: 'landlord' }, 'viewing', { version: 1, startDate: '2026-10-29', monthlyRent: 100, deposit: 50 });
    assert.equal(result.data.leaseId, 'lease'); assert.equal(collected.length, 0);
  });
  await check('UC-TNT-12.1: no occupant-update method exists in the actual service', async () => {
    const names = Object.getOwnPropertyNames(TenantLifecycleService.prototype);
    assert(names.includes('addOccupant')); assert(names.includes('removeOccupant'));
    assert(!names.some(name => /(?:update|edit|patch).*occupant/i.test(name)));
  });
  await check('UC-OPT-07.3: RoomsService.remove does not inspect assets or inspections before deleting', async () => {
    let deleted = false;
    const prisma = {
      room: { findFirst: async () => ({ id: 'room', isActive: true }), delete: async () => { deleted = true; } },
      lease: { findFirst: async () => null, count: async () => 0 },
      meterReading: { count: async () => 0 }, invoice: { count: async () => 0 }, roomViewing: { count: async () => 0 }, roomTurnover: { count: async () => 0 },
      roomAsset: { count: async () => { throw new Error('Unexpected asset check'); } },
      roomInspection: { count: async () => { throw new Error('Unexpected inspection check'); } },
      $transaction: actions => Promise.all(actions),
    };
    await new RoomsService(prisma).remove('owner', 'room'); assert(deleted);
    const schema = fs.readFileSync(path.join(root, 'backend/prisma/schema.prisma'), 'utf8');
    for (const model of ['RoomAsset', 'RoomInspection', 'RoomServiceFee']) {
      const block = schema.slice(schema.indexOf('model ' + model + ' {')).split('\n}')[0];
      assert(/references: \[id\], onDelete: Cascade/.test(block));
    }
  });
  await check('UC-ADM-18.1: same admin may submit then approve; only landlord-self review is explicitly rejected', async () => {
    let before = null;
    const tx = {
      $queryRaw: async () => [], user: { findFirst: async () => ({ id: 'owner' }) },
      supportTicket: { findFirst: async () => ({ id: 'ticket', attachments: [{ id: 'attachment' }] }) },
      landlordVerification: {
        findUnique: async input => input.include ? ({ ...before, landlord: { isActive: true }, ticket: { requesterId: 'owner', mergedIntoId: null, attachments: [{ id: 'attachment', sha256: 'abc', file: { purpose: 'SUPPORT_CLEAN' } }] } }) : before,
        create: async input => { before = { id: 'verification', version: 1, status: 'PENDING', ...input.data }; return before; },
        updateMany: async () => ({ count: 1 }),
      }, auditLog: { create: async () => ({}) },
    };
    const service = new AdminVerificationService({ $transaction: action => action(tx) });
    const actor = { userId: 'same-admin', role: 'admin' };
    await service.submit(actor, { landlordId: 'owner', ticketId: 'ticket', version: 0, reason: 'Valid reason for submitting' });
    const result = await service.review(actor, 'verification', { version: 1, status: 'APPROVED', reason: 'Valid reason for approval' });
    assert.equal(result.data.status, 'APPROVED'); assert.equal(result.data.reviewerId, actor.userId);
  });
  const output = { scope: 'Documentation discrepancy reproduction with real application service classes and mocked persistence; no real database, network, provider or application files changed.', results, passed: results.length };
  fs.writeFileSync(path.join(__dirname, '../data/semantic-probes.json'), JSON.stringify(output, null, 2) + '\n');
  console.log(JSON.stringify(output, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });

