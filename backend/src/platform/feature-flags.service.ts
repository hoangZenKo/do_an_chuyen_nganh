import { ConflictException, Global, Injectable, Module, ServiceUnavailableException } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/current-user.decorator';
import { AdminReasonDto } from '../admin/admin-console.dto';
import { platformAudit } from './platform-audit';
import { IsArray, IsBoolean, IsIn, IsInt, Max, Min, ArrayUnique } from 'class-validator';

export const FEATURE_KEYS = ['support.user_tickets', 'moderation.appeals', 'moderation.bulk', 'reports.scheduled'] as const;
export class FeatureFlagDto extends AdminReasonDto {
  @IsBoolean() enabled!: boolean;
  @IsInt() @Min(0) @Max(100) rollout!: number;
  @IsArray() @ArrayUnique() @IsIn(['admin', 'landlord', 'tenant', 'staff'], { each: true }) roles!: string[];
  @IsInt() @Min(0) version!: number;
}

export function flagEnabled(flag: { enabled: boolean; rollout: number; roles: string[] }, key: string, userId: string, role: string) {
  const bucket = createHash('sha256').update(`${key}:${userId}`).digest().readUInt32BE(0) % 100;
  return flag.enabled && (!flag.roles.length || flag.roles.includes(role)) && bucket < flag.rollout;
}

@Injectable()
export class FeatureFlagsService {
  constructor(private readonly prisma: PrismaService) {}
  async list() {
    const rows = await this.prisma.featureFlag.findMany();
    return { data: FEATURE_KEYS.map(key => rows.find(row => row.key === key) ?? { key, enabled: true, rollout: 100, roles: [], version: 0 }) };
  }
  async effective(actor: AuthUser) {
    const { data } = await this.list();
    return { data: Object.fromEntries(data.map(flag => [flag.key, flagEnabled(flag, flag.key, actor.userId, actor.role)])) };
  }
  async require(key: typeof FEATURE_KEYS[number], actor: AuthUser) {
    const row = await this.prisma.featureFlag.findUnique({ where: { key } });
    if (row && !flagEnabled(row, key, actor.userId, actor.role)) throw new ServiceUnavailableException('Chức năng đang tạm dừng cho nhóm tài khoản này.');
  }
  async update(actor: AuthUser, key: string, input: FeatureFlagDto) {
    if (!FEATURE_KEYS.includes(key as typeof FEATURE_KEYS[number])) throw new ConflictException('Không được thay đổi cờ bảo mật hoặc key ngoài danh mục.');
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${`flag:${key}`}))::text`;
      const previous = await tx.featureFlag.findUnique({ where: { key } });
      if ((previous?.version ?? 0) !== input.version) throw new ConflictException('Cờ đã thay đổi. Hãy tải lại.');
      const values = { enabled: input.enabled, rollout: input.rollout, roles: input.roles, updatedById: actor.userId };
      const data = await tx.featureFlag.upsert({ where: { key }, create: { key, ...values }, update: { ...values, version: { increment: 1 } } });
      await platformAudit(tx, actor, 'admin.feature_flag_update', 'feature_flag', key, input.reason,
        { enabled: data.enabled, rollout: data.rollout, roles: data.roles, version: data.version });
      return { data };
    });
  }
}

@Global()
@Module({ providers: [FeatureFlagsService], exports: [FeatureFlagsService] })
export class FeatureFlagsModule {}
