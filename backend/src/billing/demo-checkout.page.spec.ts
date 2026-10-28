import { demoCheckoutPage } from './demo-checkout.page';

describe('Payment checkout copy', () => {
  const token = 'a'.repeat(43);

  it('uses product labels while clearly identifying the test environment', () => {
    const html = demoCheckoutPage({ token, amount: 10000, canSubmit: true });
    const visibleText = html.replace(/<[^>]*>/g, ' ');
    expect(html).toContain('<title>Thanh toán bằng thẻ | Rental Room Management</title>');
    expect(html).toContain('>Số thẻ</label>');
    expect(html).toContain('>CVC</label>');
    expect(html).toContain('>Xác nhận thanh toán</button>');
    expect(visibleText).not.toMatch(/demo/i);
    expect(visibleText).toContain('Môi trường kiểm thử — không thu tiền thật.');
    expect(visibleText).toContain('Không nhập thông tin thẻ ngân hàng đang sử dụng.');
    expect(html).toContain('/api/v1/payments/demo/checkout/' + token + '/confirm');
  });

  it('shows a completed payment without leaving a payment form', () => {
    const html = demoCheckoutPage({ token, amount: 10000, paid: true });
    expect(html).toContain('Thanh toán đã hoàn tất.');
    expect(html).not.toContain('<form');
    expect(html).toContain('Môi trường kiểm thử — không thu tiền thật.');
  });

  it('escapes server error messages and rejects invalid form tokens', () => {
    const html = demoCheckoutPage({ token: '"><script>alert(1)</script>', canSubmit: true, error: '<script>alert(2)</script>' });
    expect(html).not.toContain('<script>');
    expect(html).toContain('&lt;script&gt;alert(2)&lt;/script&gt;');
    expect(html).not.toContain('<form');
  });
});
