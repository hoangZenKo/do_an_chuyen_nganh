import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const database = new URL(process.env.DATABASE_URL ?? '');
  if (process.env.NODE_ENV === 'production' || !['localhost', '127.0.0.1', '[::1]'].includes(database.hostname)) {
    throw new Error('Demo payment preparation is allowed only for a local database.');
  }
  const tenant = await prisma.tenant.findFirst({
    where: { user: { email: 'tenant@demo.com', role: 'TENANT' } },
    include: { leases: { where: { status: 'ACTIVE' }, orderBy: { createdAt: 'desc' }, take: 1 } },
  });
  const lease = tenant?.leases[0];
  if (!tenant || !lease) throw new Error('An active lease for tenant@demo.com is required. You can also create a separate demo invoice from the app.');
  const existing = await prisma.invoice.findFirst({ where: { tenantId: tenant.id, isDemo: true, status: { in: ['UNPAID', 'PARTIAL'] } } });
  if (existing) { console.log('An unpaid demo invoice already exists. No original invoice was modified.'); return; }
  const now = new Date();
  const billingMonth = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const invoices = await prisma.invoice.findMany({ where: { leaseId: lease.id, isDemo: true }, select: { billingMonth: true } });
  const occupied = new Set(invoices.map(invoice => invoice.billingMonth.toISOString()));
  while (occupied.has(billingMonth.toISOString())) billingMonth.setUTCMonth(billingMonth.getUTCMonth() + 1);
  await prisma.invoice.create({ data: {
    leaseId: lease.id, tenantId: tenant.id, roomId: lease.roomId, billingMonth,
    rentAmount: 10000, totalAmount: 10000, isDemo: true,
    dueDate: new Date(now.getTime() + 7 * 86400000),
    note: 'DEMO CARD - Hoa don thu nghiem 10.000 VND, khong phat sinh cong no that.',
  } });
  console.log('Created a separate 10,000 VND demo invoice for tenant@demo.com. No original invoice was modified.');
}

main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => prisma.$disconnect());
