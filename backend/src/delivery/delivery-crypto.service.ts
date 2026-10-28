import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

@Injectable()
export class DeliveryCryptoService {
  constructor(private readonly config: ConfigService) {}

  ready() {
    return Buffer.from(this.config.get<string>('DELIVERY_ENCRYPTION_KEY', ''), 'base64').length === 32;
  }

  private key() {
    if (!this.ready()) throw new ServiceUnavailableException('Delivery encryption key is not configured.');
    return Buffer.from(this.config.getOrThrow<string>('DELIVERY_ENCRYPTION_KEY'), 'base64');
  }

  encrypt(payload: unknown) {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key(), nonce);
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(payload), 'utf8'), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), encrypted]).toString('base64');
  }

  decrypt(payload: string): string {
    const bytes = Buffer.from(payload, 'base64');
    const decipher = createDecipheriv('aes-256-gcm', this.key(), bytes.subarray(0, 12));
    decipher.setAuthTag(bytes.subarray(12, 28));
    return Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString('utf8');
  }
}
