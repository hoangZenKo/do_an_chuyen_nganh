import 'dotenv/config';
import { PrismaClient, UserRole } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function main() {
  const email = process.env.ADMIN_BOOTSTRAP_EMAIL?.trim().toLowerCase();
  const fullName = process.env.ADMIN_BOOTSTRAP_NAME?.trim();
  const password = process.env.ADMIN_BOOTSTRAP_PASSWORD;

  if (!email || !fullName || !password) {
    throw new Error(
      'Set ADMIN_BOOTSTRAP_EMAIL, ADMIN_BOOTSTRAP_NAME, and ADMIN_BOOTSTRAP_PASSWORD before bootstrapping.',
    );
  }
  if (password.length < 12 || password === 'StrongAdminPassword!2026') {
    throw new Error('Use a unique admin password with at least 12 characters.');
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing && existing.role !== UserRole.ADMIN) {
    throw new Error('The email already belongs to a non-admin user; refusing role escalation.');
  }

  const passwordHash = await argon2.hash(password);
  const admin = await prisma.user.upsert({
    where: { email },
    create: { email, fullName, passwordHash, role: UserRole.ADMIN },
    update: { fullName, passwordHash, role: UserRole.ADMIN, isActive: true },
  });
  await prisma.adminProfile.upsert({
    where: { userId: admin.id },
    create: { userId: admin.id, preset: 'super_admin', permissions: [
      'admin.dashboard.view', 'admin.accounts.view', 'admin.accounts.manage', 'admin.accounts.suspend',
      'admin.sessions.revoke', 'admin.properties.view', 'admin.properties.manage', 'admin.support.read',
      'admin.pii.reveal', 'admin.listings.moderate', 'admin.reviews.moderate', 'admin.audit.view',
      'admin.campuses.manage', 'admin.admins.manage',
    ] },
    update: { preset: 'super_admin', permissions: [
      'admin.dashboard.view', 'admin.accounts.view', 'admin.accounts.manage', 'admin.accounts.suspend',
      'admin.sessions.revoke', 'admin.properties.view', 'admin.properties.manage', 'admin.support.read',
      'admin.pii.reveal', 'admin.listings.moderate', 'admin.reviews.moderate', 'admin.audit.view',
      'admin.campuses.manage', 'admin.admins.manage',
    ] },
  });

  console.log(`Admin ready: ${admin.email} (${admin.id})`);
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
