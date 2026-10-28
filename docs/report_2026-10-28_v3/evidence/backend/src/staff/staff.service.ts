import {
  ConflictException,
  HttpException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma, StaffInvite, StaffProfile, UserRole } from '@prisma/client';
import { createHash, randomBytes } from 'node:crypto';
import * as argon2 from 'argon2';

import {
  STAFF_PERMISSION_SET,
  StaffPermission,
} from '../common/permissions.constants';
import { AuthService } from '../auth/auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { AcceptStaffInviteDto } from './dto/accept-staff-invite.dto';
import { CreateStaffInviteDto } from './dto/create-staff-invite.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';
import { STAFF_PRESET_PERMISSIONS, StaffPreset } from './staff-presets';
import { scopedPropertyIds } from '../common/property-scope';
import { SimulateStaffPermissionDto } from './dto/simulate-staff-permission.dto';

const staffNotFound = () =>
  new NotFoundException({
    error: { code: 'STAFF_NOT_FOUND', message: 'Staff member not found.' },
  });

const emailAlreadyRegistered = () =>
  new ConflictException({
    error: {
      code: 'EMAIL_ALREADY_REGISTERED',
      message: 'Email is already registered.',
    },
  });

const invalidInvite = () =>
  new UnauthorizedException({
    error: {
      code: 'INVALID_STAFF_INVITE',
      message: 'Staff invite is invalid or expired.',
    },
  });

@Injectable()
export class StaffService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async list(landlordId: string) {
    const propertyIds = scopedPropertyIds();
    const staff = await this.prisma.staffProfile.findMany({
      where: { landlordId, ...(propertyIds ? { propertyScopes: { some: { propertyId: { in: propertyIds } } } } : {}) },
      orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
      include: { user: { select: { id: true, email: true, isActive: true } }, propertyScopes: { ...(propertyIds ? { where: { propertyId: { in: propertyIds } } } : {}), select: { propertyId: true } } },
    });
    return { data: staff.map((item) => this.serializeStaff(item)) };
  }

  async createInvite(landlordId: string, input: CreateStaffInviteDto) {
    const email = input.email.trim().toLowerCase();
    return this.prisma.$transaction(async tx => {
    await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtextextended(${`staff-invite:${landlordId}:${email}`}, 0))::text`;
    const existingUser = await tx.user.findUnique({ where: { email } });
    if (existingUser) throw emailAlreadyRegistered();
    const now = new Date();
    const latest = await tx.staffInvite.findFirst({ where: { landlordId, email }, orderBy: { createdAt: 'desc' } });
    const count = await tx.staffInvite.count({ where: { landlordId, email, createdAt: { gte: new Date(now.getTime() - 3_600_000) } } });
    if ((latest && latest.createdAt.getTime() > now.getTime() - 60_000) || count >= 5) throw new HttpException('Chờ ít nhất 60 giây giữa các lời mời, tối đa 5 lần mỗi giờ.', 429);
    await tx.staffInvite.updateMany({ where: { landlordId, email, acceptedAt: null, expiresAt: { gt: now } }, data: { expiresAt: now } });

    const inviteCode = randomBytes(32).toString('base64url');
    const preset = input.preset ?? 'viewer';
    const permissions = this.resolvePermissions(preset, input.permissions);
    const propertyIds = await this.validPropertyIds(landlordId, input.propertyIds);
    const invite = await tx.staffInvite.create({
      data: {
        landlordId,
        email,
        fullName: input.fullName.trim(),
        phone: input.phone?.trim() || null,
        preset,
        permissions,
        propertyIds,
        tokenHash: this.hashInvite(inviteCode),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return {
      data: {
        ...this.serializeInvite(invite),
        inviteCode,
        activationPath: `/staff/activate?code=${inviteCode}`,
      },
    };
    });
  }

  async accept(input: AcceptStaffInviteDto) {
    const now = new Date();
    const tokenHash = this.hashInvite(input.inviteCode);
    try {
      const user = await this.prisma.$transaction(async (tx) => {
        let invite = await tx.staffInvite.findUnique({ where: { tokenHash } });
        if (invite) {
          await tx.$queryRaw`SELECT "id" FROM "StaffInvite" WHERE "id" = ${invite.id} FOR UPDATE`;
          invite = await tx.staffInvite.findUnique({ where: { tokenHash } });
        }
        if (!invite || invite.acceptedAt || invite.expiresAt <= now) {
          throw invalidInvite();
        }
        if (!await tx.user.findFirst({ where: { id: invite.landlordId, isActive: true }, select: { id: true } })) throw invalidInvite();
        const created = await tx.user.create({
          data: {
            fullName: invite.fullName,
            email: invite.email,
            phone: invite.phone,
            passwordHash: await argon2.hash(input.password),
            role: UserRole.STAFF,
          },
        });
        if (await tx.property.count({ where: { landlordId: invite.landlordId, id: { in: invite.propertyIds }, isArchived: false } }) !== invite.propertyIds.length) throw invalidInvite();
        const profile = await tx.staffProfile.create({
          data: {
            userId: created.id,
            landlordId: invite.landlordId,
            fullName: invite.fullName,
            phone: invite.phone,
            preset: invite.preset,
            permissions: invite.permissions,
          },
        });
        if (invite.propertyIds.length) await tx.staffPropertyScope.createMany({
          data: invite.propertyIds.map((propertyId) => ({ staffProfileId: profile.id, propertyId, landlordId: invite.landlordId })),
          skipDuplicates: true,
        });
        await tx.auditLog.create({ data: { landlordId: invite.landlordId, actorId: invite.landlordId, actorRole: 'LANDLORD', action: 'staff.property_scope.grant', resourceType: 'staff_profile', resourceId: profile.id, summary: 'Apply property access from accepted staff invitation', metadata: { propertyIds: invite.propertyIds, inviteId: invite.id } } });
        await tx.staffInvite.update({
          where: { id: invite.id },
          data: { acceptedAt: now },
        });
        return created;
      });
      return this.auth.issueSession(user);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw emailAlreadyRegistered();
      }
      throw error;
    }
  }

  async update(landlordId: string, staffId: string, input: UpdateStaffDto, actor?: AuthUser) {
    const existing = await this.prisma.staffProfile.findFirst({
      where: { id: staffId, landlordId },
    });
    if (!existing) throw staffNotFound();

    const preset = input.preset ?? existing.preset;
    const permissions =
      input.permissions || input.preset
        ? this.resolvePermissions(preset as StaffPreset | null, input.permissions)
        : undefined;
    const propertyIds = input.propertyIds === undefined ? undefined : await this.validPropertyIds(landlordId, input.propertyIds);
    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "StaffProfile" WHERE id = ${existing.id} FOR UPDATE`;
      const previous = await tx.staffPropertyScope.findMany({ where: { staffProfileId: existing.id }, select: { propertyId: true } });
      const result = await tx.staffProfile.update({
      where: { id: existing.id },
      data: {
        ...(input.fullName !== undefined ? { fullName: input.fullName.trim() } : {}),
        ...(input.phone !== undefined ? { phone: input.phone?.trim() || null } : {}),
        ...(input.preset !== undefined ? { preset: input.preset } : {}),
        ...(permissions !== undefined ? { permissions } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        ...(input.isActive !== undefined
          ? { user: { update: { isActive: input.isActive } } }
          : {}),
      },
      include: { user: { select: { id: true, email: true, isActive: true } }, propertyScopes: { select: { propertyId: true } } },
      });
      if (propertyIds !== undefined) {
        await tx.staffPropertyScope.deleteMany({ where: { staffProfileId: existing.id } });
        if (propertyIds.length) await tx.staffPropertyScope.createMany({ data: propertyIds.map((propertyId) => ({ staffProfileId: existing.id, propertyId, landlordId })) });
        await tx.auditLog.create({ data: { landlordId, actorId: actor?.userId ?? landlordId, actorRole: (actor?.role.toUpperCase() ?? 'LANDLORD') as UserRole, action: 'staff.property_scope.update', resourceType: 'staff_profile', resourceId: existing.id, summary: 'Update staff property access', metadata: { previousPropertyIds: previous.map((scope) => scope.propertyId), propertyIds } } });
      }
      return { ...result, propertyScopes: propertyIds?.map((propertyId) => ({ propertyId })) ?? result.propertyScopes };
    });
    return { data: this.serializeStaff(updated) };
  }

  presets() {
    return {
      data: Object.entries(STAFF_PRESET_PERMISSIONS).map(
        ([preset, permissions]) => ({
          preset,
          permissions,
        }),
      ),
    };
  }

  async simulate(landlordId: string, staffId: string, input: SimulateStaffPermissionDto) {
    const [staff, property] = await Promise.all([
      this.prisma.staffProfile.findFirst({ where: { id: staffId, landlordId }, include: { user: { select: { isActive: true } }, propertyScopes: { select: { propertyId: true } } } }),
      this.prisma.property.findFirst({ where: { id: input.propertyId, landlordId }, select: { id: true, isArchived: true } }),
    ]);
    if (!staff || !property) throw staffNotFound();
    const reasons = [
      ...(!staff.isActive || !staff.user.isActive ? ['STAFF_INACTIVE'] : []),
      ...(!staff.permissions.includes(input.permission) ? ['MODULE_PERMISSION_MISSING'] : []),
      ...(!staff.propertyScopes.some((scope) => scope.propertyId === property.id) ? ['PROPERTY_NOT_ASSIGNED'] : []),
      ...(property.isArchived ? ['PROPERTY_ARCHIVED'] : []),
      ...(input.permission.startsWith('staff.') && input.permission.endsWith('manage') ? ['LANDLORD_ONLY_ACTION'] : []),
    ];
    return { data: { staffId, propertyId: property.id, permission: input.permission, allowed: reasons.length === 0, reasons, scope: 'module-and-property', additionalActionChecksApply: true } };
  }

  private resolvePermissions(
    preset?: StaffPreset | null,
    explicit?: StaffPermission[],
  ) {
    const source =
      explicit !== undefined
        ? explicit
        : preset
          ? STAFF_PRESET_PERMISSIONS[preset] ?? []
          : [];
    return Array.from(
      new Set(source.filter((permission) => STAFF_PERMISSION_SET.has(permission))),
    ).sort();
  }

  private serializeStaff(
    staff: StaffProfile & {
      user?: { id: string; email: string; isActive: boolean } | null;
    },
  ) {
    return {
      id: staff.id,
      userId: staff.userId,
      landlordId: staff.landlordId,
      fullName: staff.fullName,
      email: staff.user?.email ?? null,
      phone: staff.phone,
      preset: staff.preset,
      permissions: staff.permissions,
      propertyIds: 'propertyScopes' in staff ? ((staff as StaffProfile & { propertyScopes?: { propertyId: string }[] }).propertyScopes ?? []).map((scope) => scope.propertyId) : [],
      isActive: staff.isActive && (staff.user?.isActive ?? true),
      createdAt: staff.createdAt.toISOString(),
      updatedAt: staff.updatedAt.toISOString(),
    };
  }

  private serializeInvite(invite: StaffInvite) {
    return {
      id: invite.id,
      landlordId: invite.landlordId,
      email: invite.email,
      fullName: invite.fullName,
      phone: invite.phone,
      preset: invite.preset,
      permissions: invite.permissions,
      propertyIds: invite.propertyIds,
      expiresAt: invite.expiresAt.toISOString(),
      acceptedAt: invite.acceptedAt?.toISOString() ?? null,
      createdAt: invite.createdAt.toISOString(),
    };
  }

  private hashInvite(value: string) {
    return createHash('sha256').update(value).digest('hex');
  }

  private async validPropertyIds(landlordId: string, propertyIds: string[] = []) {
    const unique = [...new Set(propertyIds)];
    if (!unique.length) return [];
    const count = await this.prisma.property.count({ where: { landlordId, id: { in: unique }, isArchived: false } });
    if (count !== unique.length) throw new NotFoundException('One or more properties are not owned by this landlord.');
    return unique;
  }
}
