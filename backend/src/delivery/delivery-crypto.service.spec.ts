import { ConfigService } from '@nestjs/config';
import { DeliveryCryptoService } from './delivery-crypto.service';
import { httpsEndpoint } from './delivery.service';

describe('Encrypted delivery', () => {
  it('requires a dedicated 256-bit key and authenticates ciphertext', () => {
    const crypto = new DeliveryCryptoService(new ConfigService({ DELIVERY_ENCRYPTION_KEY: Buffer.alloc(32, 1).toString('base64') }));
    const encrypted = crypto.encrypt({ token: 'super-private', email: 'person@example.com' });
    expect(encrypted).not.toContain('super-private');
    expect(JSON.parse(crypto.decrypt(encrypted))).toEqual({ token: 'super-private', email: 'person@example.com' });
    const wrong = new DeliveryCryptoService(new ConfigService({ DELIVERY_ENCRYPTION_KEY: Buffer.alloc(32, 2).toString('base64') }));
    expect(() => wrong.decrypt(encrypted)).toThrow();
    expect(new DeliveryCryptoService(new ConfigService()).ready()).toBe(false);
  });
  it('rejects insecure endpoints and embedded credentials', () => {
    for (const input of ['http://example.com', 'https://user:pass@example.com', 'https://example.com/#secret', 'bad']) expect(httpsEndpoint(input)).toBeNull();
    expect(httpsEndpoint('https://notify.example.com/events')).toBe('https://notify.example.com/events');
  });
});
