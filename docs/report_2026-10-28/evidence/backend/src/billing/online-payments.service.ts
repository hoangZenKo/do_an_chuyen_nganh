import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthRole } from '../common/auth-role';
import { AuthUser, landlordScopeId } from '../common/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { DemoCardGateway } from './demo-card.gateway';

@Injectable()
export class OnlinePaymentsService {
  constructor(private readonly prisma: PrismaService, private readonly gateway: DemoCardGateway) {}

  private async ownedInvoice(user: AuthUser, invoiceId: string) {
    const invoice = await this.prisma.invoice.findFirst({
      where: { id: invoiceId, ...(user.role === AuthRole.TENANT ? { tenant: { userId: user.userId } } : { room: { property: { landlordId: landlordScopeId(user) } } }) },
      include: { room: { include: { property: { select: { landlordId: true } } } } },
    });
    if (!invoice) throw new NotFoundException('Không tìm thấy hóa đơn.');
    return invoice;
  }

  async createDemoInvoice(user: AuthUser, invoiceId: string) {
    const source = await this.ownedInvoice(user, invoiceId);
    this.gateway.assertEnabled();
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Lease" WHERE id = ${source.leaseId} FOR UPDATE`;
      const existing = await tx.invoice.findFirst({ where: { leaseId: source.leaseId, tenantId: source.tenantId, isDemo: true, status: { in: ['UNPAID', 'PARTIAL'] } } });
      if (existing) return { data: { id: existing.id, isDemo: true } };
      const usedMonths = new Set((await tx.invoice.findMany({ where: { leaseId: source.leaseId, isDemo: true }, select: { billingMonth: true } })).map(invoice => invoice.billingMonth.toISOString()));
      const billingMonth = new Date(source.billingMonth);
      while (usedMonths.has(billingMonth.toISOString())) billingMonth.setUTCMonth(billingMonth.getUTCMonth() + 1);
      const invoice = await tx.invoice.create({ data: {
        leaseId: source.leaseId, roomId: source.roomId, tenantId: source.tenantId,
        billingMonth, rentAmount: 10000, totalAmount: 10000, isDemo: true,
        dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        note: 'Hóa đơn kiểm thử 10.000 VND, không phát sinh công nợ thực tế.',
      } });
      return { data: { id: invoice.id, isDemo: true } };
    });
  }

  async createLink(user: AuthUser, invoiceId: string) {
    const owned = await this.ownedInvoice(user, invoiceId);
    this.gateway.assertEnabled();
    if (!owned.isDemo) throw new ConflictException('Hóa đơn này chưa hỗ trợ thanh toán bằng thẻ. Vui lòng tạo hóa đơn kiểm thử riêng.');
    await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Invoice" WHERE id = ${invoiceId} FOR UPDATE`;
      const invoice = await tx.invoice.findUniqueOrThrow({ where: { id: invoiceId } });
      const amount = invoice.totalAmount - invoice.paidAmount;
      if (!invoice.isDemo || invoice.status === 'CANCELLED' || amount <= 0) throw new ConflictException('Hóa đơn đã thanh toán, đã hủy hoặc không phải dữ liệu demo.');
      const existing = await tx.paymentLink.findFirst({ where: { invoiceId, provider: 'DEMO_CARD', status: 'PENDING' }, include: { demoSession: true }, orderBy: { createdAt: 'desc' } });
      if (existing && existing.expiresAt > new Date() && existing.amount === amount && existing.demoSession?.status === 'PENDING' && existing.demoSession.tokenHash === this.gateway.hash(this.gateway.token(existing.demoSession.id))) return;
      await tx.paymentLink.updateMany({ where: { invoiceId, status: 'PENDING' }, data: { status: 'CANCELLED' } });
      await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
      const sessionId = randomUUID();
      this.gateway.checkoutUrl(sessionId);
      const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
      await tx.paymentLink.create({ data: {
        landlordId: owned.room.property.landlordId, propertyId: owned.room.propertyId, invoiceId, tenantId: invoice.tenantId,
        amount, provider: 'DEMO_CARD', expiresAt,
        demoSession: { create: { id: sessionId, tokenHash: this.gateway.hash(this.gateway.token(sessionId)), expiresAt } },
      } });
    });
    return this.status(user, invoiceId);
  }

  async status(user: AuthUser, invoiceId: string) {
    await this.ownedInvoice(user, invoiceId);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Invoice" WHERE id = ${invoiceId} FOR UPDATE`;
      const invoice = await tx.invoice.findUniqueOrThrow({ where: { id: invoiceId } });
      const remainingAmount = Math.max(0, invoice.totalAmount - invoice.paidAmount);
      await tx.paymentLink.updateMany({ where: { invoiceId, status: 'PENDING', expiresAt: { lte: new Date() } }, data: { status: 'EXPIRED' } });
      await tx.paymentLink.updateMany({ where: { invoiceId, status: 'PENDING', ...(invoice.status === 'CANCELLED' || remainingAmount === 0 ? {} : { amount: { not: remainingAmount } }) }, data: { status: 'CANCELLED' } });
      await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId, status: 'EXPIRED' }, status: 'PENDING' }, data: { status: 'EXPIRED' } });
      await tx.demoCheckoutSession.updateMany({ where: { paymentLink: { invoiceId, status: 'CANCELLED' }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
      const link = await tx.paymentLink.findFirst({ where: { invoiceId, provider: 'DEMO_CARD' }, include: { demoSession: true }, orderBy: { createdAt: 'desc' } });
      const canCreateLink = this.gateway.enabled && invoice.isDemo && invoice.status !== 'CANCELLED' && remainingAmount > 0;
      let checkoutUrl: string | null = null;
      if (canCreateLink && link?.status === 'PENDING' && link.demoSession?.status === 'PENDING' && link.demoSession.tokenHash === this.gateway.hash(this.gateway.token(link.demoSession.id))) checkoutUrl = this.gateway.checkoutUrl(link.demoSession.id);
      return { data: {
        id: link?.id, status: link?.status ?? 'NOT_CREATED', provider: 'DEMO_CARD', demo: true,
        amount: link?.amount ?? remainingAmount, currency: 'VND', expiresAt: link?.expiresAt, checkoutUrl, qrCode: checkoutUrl,
        invoice: { id: invoice.id, isDemo: invoice.isDemo, status: invoice.status, totalAmount: invoice.totalAmount, paidAmount: invoice.paidAmount, remainingAmount },
        reviewRequired: false, canCreateLink, canPay: canCreateLink && link?.amount === remainingAmount && Boolean(checkoutUrl),
        canCreateDemoInvoice: this.gateway.enabled && !invoice.isDemo,
        unavailableReason: !this.gateway.enabled ? 'Thanh toán trực tuyến đang tắt. Vui lòng thử lại sau.' : !invoice.isDemo ? 'Chọn tạo hóa đơn kiểm thử để trải nghiệm thanh toán, không ảnh hưởng công nợ hiện tại.' : null,
      } };
    });
  }

  private async findSession(token: string) {
    this.gateway.assertEnabled();
    if (!/^[A-Za-z0-9_-]{43}$/.test(token)) throw new NotFoundException('Không tìm thấy phiên thanh toán.');
    const session = await this.prisma.demoCheckoutSession.findUnique({ where: { tokenHash: this.gateway.hash(token) }, include: { paymentLink: { include: { invoice: true } } } });
    if (!session) throw new NotFoundException('Không tìm thấy phiên thanh toán.');
    return session;
  }

  async checkout(token: string) {
    const session = await this.findSession(token);
    const link = session.paymentLink;
    const invoice = link.invoice;
    const paid = session.status === 'PAID' && link.status === 'PAID';
    const remaining = invoice.totalAmount - invoice.paidAmount;
    const canSubmit = invoice.isDemo && session.status === 'PENDING' && link.status === 'PENDING' && session.expiresAt > new Date() && link.expiresAt > new Date() && invoice.status !== 'CANCELLED' && remaining > 0 && remaining === link.amount;
    return { amount: link.amount, paid, canSubmit, expiresAt: session.expiresAt };
  }

  async confirmDemo(token: string, input: unknown) {
    const session = await this.findSession(token);
    this.gateway.validateCard(input);
    return this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM "Invoice" WHERE id = ${session.paymentLink.invoiceId} FOR UPDATE`;
      const current = await tx.paymentLink.findUniqueOrThrow({ where: { id: session.paymentLinkId }, include: { demoSession: true, invoice: true } });
      const checkout = current.demoSession;
      const invoice = current.invoice;
      if (!checkout || !invoice.isDemo || current.provider !== 'DEMO_CARD') throw new ConflictException('Phiên thanh toán không hợp lệ.');
      if (checkout.status === 'PAID' && current.status === 'PAID') return { success: true, demo: true, duplicate: true };
      if (checkout.status !== 'PENDING' || current.status !== 'PENDING' || checkout.expiresAt <= new Date() || current.expiresAt <= new Date()) throw new ConflictException('Phiên đã hết hạn hoặc đã hủy. Tạo lại QR trong ứng dụng.');
      if (invoice.status === 'CANCELLED' || invoice.totalAmount - invoice.paidAmount !== current.amount || current.amount <= 0) throw new ConflictException('Hóa đơn đã thay đổi. Tạo lại QR trong ứng dụng.');
      const reference = `demo-${checkout.id}`;
      const payment = await tx.payment.create({ data: { invoiceId: invoice.id, amount: current.amount, method: 'OTHER', note: 'Thanh toán bằng thẻ •••• 4242 · Môi trường kiểm thử' } });
      const paidAmount = invoice.paidAmount + current.amount;
      const status = paidAmount >= invoice.totalAmount ? 'PAID' : 'PARTIAL';
      await tx.invoice.update({ where: { id: invoice.id }, data: { paidAmount, status } });
      await tx.paymentLink.update({ where: { id: current.id }, data: { status: 'PAID', paidAt: new Date() } });
      await tx.demoCheckoutSession.update({ where: { id: checkout.id }, data: { status: 'PAID', completedAt: new Date(), cardBrand: 'VISA', cardLast4: '4242' } });
      await tx.paymentWebhookEvent.create({ data: { landlordId: current.landlordId, paymentLinkId: current.id, reference, amount: current.amount, status: 'RECONCILED', paymentId: payment.id } });
      await tx.auditLog.create({ data: { landlordId: current.landlordId, actorRole: 'TENANT', action: 'billing.demo_card_payment', resourceType: 'invoice', resourceId: invoice.id, summary: 'Thanh toán mô phỏng, không phát sinh tiền thật', metadata: { demo: true, paymentId: payment.id, reference, amount: current.amount } } });
      return { success: true, demo: true, duplicate: false, invoiceStatus: status };
    });
  }

  async events(user: AuthUser, invoiceId: string) {
    await this.ownedInvoice(user, invoiceId);
    return { data: await this.prisma.paymentWebhookEvent.findMany({ where: { paymentLink: { invoiceId, landlordId: landlordScopeId(user) } }, orderBy: { createdAt: 'desc' }, take: 100 }) };
  }

  async reconcile(user: AuthUser, invoiceId: string, eventId: string) {
    await this.ownedInvoice(user, invoiceId);
    const event = await this.prisma.paymentWebhookEvent.findFirst({ where: { id: eventId, landlordId: landlordScopeId(user), paymentLink: { invoiceId } } });
    if (!event) throw new NotFoundException('Không tìm thấy giao dịch.');
    if (event.status === 'RECONCILED') return { data: event };
    throw new ConflictException('Không thể đối soát giao dịch ngân hàng tại đây. Vui lòng kiểm tra chứng từ thanh toán.');
  }
}
