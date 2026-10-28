import { BadRequestException, ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuthRole } from '../common/auth-role';
import { AuthUser } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { SaveTransferAccountDto } from './manual-transfer.dto';

@Injectable()
export class ManualTransferService {
  constructor(private readonly prisma: PrismaService) {}

  async account(actor: AuthUser, propertyId: string) {
    if (actor.role !== AuthRole.LANDLORD) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      const property = await tx.property.findFirst({ where: { id: propertyId, landlordId: actor.userId } });
      if (!property) throw new NotFoundException();
      return { data: await tx.propertyPaymentAccount.findUnique({ where: { propertyId } }) ?? { propertyId, version: 0, enabled: false } };
    }, { isolationLevel: 'RepeatableRead' });
  }

  async save(actor: AuthUser, propertyId: string, input: SaveTransferAccountDto) {
    if (actor.role !== AuthRole.LANDLORD) throw new ForbiddenException();
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Property" WHERE id = ${propertyId} AND "landlordId" = ${actor.userId} FOR UPDATE`;
      const property = await tx.property.findFirst({ where: { id: propertyId, landlordId: actor.userId, isArchived: false } });
      if (!property) throw new NotFoundException();
      const previous = await tx.propertyPaymentAccount.findUnique({ where: { propertyId } });
      if ((previous?.version ?? 0) !== input.version) throw new ConflictException('Thông tin nhận tiền đã thay đổi. Tải lại trước khi lưu.');
      const qrImagePath = input.qrImagePath === undefined ? previous?.qrImagePath ?? null : input.qrImagePath;
      if (qrImagePath) {
        if (!/^\/uploads\/[a-zA-Z0-9_-]+\.(png|jpg|jpeg|webp|heic|heif)$/i.test(qrImagePath)) throw new BadRequestException('Chỉ dùng ảnh QR được tải lên bởi chủ trọ.');
        const image = await tx.uploadedFile.findFirst({ where: { filename: qrImagePath.slice('/uploads/'.length), ownerId: actor.userId,
          purpose: 'PRIVATE', mimeType: { startsWith: 'image/' } }, select: { filename: true } });
        if (!image) throw new BadRequestException('Không tìm thấy ảnh QR riêng tư của bạn.');
      }
      const fields = { bankName: input.bankName, accountName: input.accountName, accountNumber: input.accountNumber, enabled: input.enabled, qrImagePath };
      const data = await tx.propertyPaymentAccount.upsert({ where: { propertyId },
        create: { propertyId, ...fields, version: 1 }, update: { ...fields, version: { increment: 1 } } });
      await tx.auditLog.create({ data: { landlordId: actor.userId, actorId: actor.userId, actorRole: 'LANDLORD',
        action: 'billing.transfer_account.update', resourceType: 'property', resourceId: propertyId,
        summary: 'Cập nhật tài khoản nhận chuyển khoản; người thuê chờ chủ trọ xác nhận.',
        metadata: { beforeVersion: previous?.version ?? 0, afterVersion: data.version, enabled: input.enabled, hasQrImage: !!qrImagePath } } });
      return { data };
    });
  }

  async instructions(userId: string, invoiceId: string) {
    return this.prisma.$transaction(async tx => {
      const invoice = await tx.invoice.findFirst({ where: { id: invoiceId, tenant: { userId } },
        include: { room: { include: { property: { include: { paymentAccount: true } } } } } });
      if (!invoice) throw new NotFoundException();
      const pending = await tx.paymentProof.aggregate({ where: { invoiceId, status: 'PENDING' }, _sum: { amount: true } });
      const remainingAmount = Math.max(0, invoice.totalAmount - invoice.paidAmount);
      const pendingAmount = pending._sum.amount ?? 0;
      const eligible = !invoice.isDemo && invoice.status !== 'CANCELLED' && remainingAmount > 0 && !invoice.room.property.isArchived;
      const configured = invoice.room.property.paymentAccount;
      const account = eligible && configured?.enabled ? { bankName: configured.bankName, accountName: configured.accountName,
        accountNumber: configured.accountNumber, qrImagePath: configured.qrImagePath, version: configured.version } : null;
      const availableAmount = eligible ? Math.max(0, remainingAmount - pendingAmount) : 0;
      return { data: { mode: 'MANUAL_BANK_TRANSFER', invoiceId, reference: `HD ${invoiceId}`,
        remainingAmount, pendingAmount, availableAmount, canSubmit: !!account && availableAmount > 0, account } };
    }, { isolationLevel: 'RepeatableRead' });
  }
}
