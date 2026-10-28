import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { createHash, createHmac } from 'node:crypto';

export type DemoCardInput = { cardNumber: string; expiry: string; cvc: string };

@Injectable()
export class DemoCardGateway {
  get enabled() {
    return process.env.NODE_ENV !== 'production' && process.env.DEMO_PAYMENTS_ENABLED === 'true';
  }

  assertEnabled() {
    if (!this.enabled) throw new ServiceUnavailableException('Thanh toán trực tuyến chưa khả dụng. Vui lòng liên hệ người quản lý.');
    this.secret();
  }

  private secret() {
    const secret = process.env.DEMO_CHECKOUT_SECRET ?? process.env.JWT_ACCESS_SECRET;
    if (!secret || secret.length < 32) throw new ServiceUnavailableException('Cần khóa ký local ít nhất 32 ký tự để bảo vệ trang thanh toán.');
    return secret;
  }

  token(sessionId: string) {
    return createHmac('sha256', this.secret()).update(`demo-card-checkout:v1:${sessionId}`).digest('base64url');
  }

  hash(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  checkoutUrl(sessionId: string) {
    let base: URL;
    try { base = new URL(process.env.DEMO_PAYMENT_BASE_URL ?? process.env.APP_PUBLIC_BASE_URL ?? 'http://localhost:3000'); }
    catch { throw new ServiceUnavailableException('Địa chỉ thanh toán không hợp lệ.'); }
    if (!['http:', 'https:'].includes(base.protocol) || base.username || base.password || base.search || base.hash || !['', '/', '/api/v1', '/api/v1/'].includes(base.pathname)) {
      throw new ServiceUnavailableException('Địa chỉ checkout phải là origin của backend.');
    }
    return `${base.origin}/api/v1/payments/demo/checkout/${this.token(sessionId)}`;
  }

  validateCard(input: unknown): DemoCardInput {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new BadRequestException('Thông tin thẻ không hợp lệ.');
    const fields = input as Record<string, unknown>;
    if (Object.keys(fields).some(key => !['cardNumber', 'expiry', 'cvc'].includes(key)) || !['cardNumber', 'expiry', 'cvc'].every(key => typeof fields[key] === 'string' && (fields[key] as string).length <= 24)) {
      throw new BadRequestException('Thông tin thẻ không hợp lệ.');
    }
    const cardNumber = (fields.cardNumber as string).replace(/ /g, '');
    const expiry = (fields.expiry as string).trim();
    const cvc = (fields.cvc as string).trim();
    const match = /^(0[1-9]|1[0-2])\/(\d{2})$/.exec(expiry);
    if (cardNumber !== '4242424242424242' || !match || !/^\d{3}$/.test(cvc)) {
      throw new BadRequestException('Vui lòng dùng thông tin thẻ được cung cấp, ngày hết hạn hợp lệ và CVC 3 số. Không nhập thẻ ngân hàng thật.');
    }
    const now = new Date();
    const month = Number(match[1]);
    const year = 2000 + Number(match[2]);
    if (year < now.getUTCFullYear() || (year === now.getUTCFullYear() && month < now.getUTCMonth() + 1)) throw new BadRequestException('Ngày hết hạn thẻ phải là tháng hiện tại hoặc tương lai.');
    return { cardNumber, expiry, cvc };
  }
}
