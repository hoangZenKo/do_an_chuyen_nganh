import { DemoCardGateway } from './demo-card.gateway';

describe('DemoCardGateway', () => {
  const gateway = new DemoCardGateway();
  const original = { ...process.env };
  beforeEach(() => {
    process.env.NODE_ENV = 'test';
    process.env.DEMO_PAYMENTS_ENABLED = 'true';
    process.env.DEMO_CHECKOUT_SECRET = 'unit-test-only-demo-checkout-secret-2026';
    process.env.DEMO_PAYMENT_BASE_URL = 'http://localhost:3000';
  });
  afterEach(() => { process.env = { ...original }; });

  it('derives an opaque token that cannot be reconstructed from its database hash', () => {
    const token = gateway.token('session-one');
    expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(gateway.hash(token)).not.toBe(token);
    expect(gateway.token('session-one')).toBe(token);
    expect(gateway.token('session-two')).not.toBe(token);
  });
  it('rejects production even when the demo flag is set', () => {
    process.env.NODE_ENV = 'production';
    expect(gateway.enabled).toBe(false);
    expect(() => gateway.assertEnabled()).toThrow();
  });
  it('requires explicit local opt in', () => {
    delete process.env.DEMO_PAYMENTS_ENABLED;
    expect(() => gateway.assertEnabled()).toThrow();
  });
  it('accepts only the documented internal demo card', () => {
    expect(gateway.validateCard({ cardNumber: '4242 4242 4242 4242', expiry: '12/99', cvc: '123' })).toMatchObject({ cardNumber: '4242424242424242' });
  });
  it.each([
    null, [], {}, { cardNumber: 4242424242424242, expiry: '12/99', cvc: '123' },
    { cardNumber: '5555555555554444', expiry: '12/99', cvc: '123' },
    { cardNumber: '4242424242424242', expiry: '01/20', cvc: '123' },
    { cardNumber: '4242424242424242', expiry: '00/99', cvc: '123' },
    { cardNumber: '4242424242424242', expiry: '12/99', cvc: '1234' },
    { cardNumber: '4242424242424242', expiry: '12/99', cvc: '123', amount: 1 },
  ])('rejects invalid or tampered input without echoing sensitive values', input => {
    expect(() => gateway.validateCard(input)).toThrow();
  });
  it.each(['javascript:alert(1)', 'https://user:password@example.com', 'https://example.com?redirect=evil', 'https://example.com/wrong'])('rejects unsafe checkout origins: %s', base => {
    process.env.DEMO_PAYMENT_BASE_URL = base;
    expect(() => gateway.checkoutUrl('session-one')).toThrow();
  });
  it('normalizes API base paths and supports LAN addresses', () => {
    process.env.DEMO_PAYMENT_BASE_URL = 'http://192.168.1.8:3000/api/v1';
    expect(gateway.checkoutUrl('session-one')).toBe(`http://192.168.1.8:3000/api/v1/payments/demo/checkout/${gateway.token('session-one')}`);
  });
});
